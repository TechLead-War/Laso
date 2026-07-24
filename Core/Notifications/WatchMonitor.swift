import Foundation
import HealthKit
import UserNotifications

/// Monitors Apple Watch wearing status and battery via HealthKit background delivery.
///
/// **How it works (all background-capable, no foreground required):**
///
/// 1. An `HKObserverQuery` with `enableBackgroundDelivery(.immediate)` fires whenever
///    new heart rate data arrives. even when the app is suspended or killed.
///
/// 2. Each time fresh Apple Watch data arrives, a local notification is **scheduled**
///    to fire after `watchNotWornThresholdHours` (default 1h). This pushes the
///    notification forward. as long as data keeps flowing, it never fires.
///
/// 3. When data stops (watch removed, battery dead, out of range), no more pushes
///    happen and the scheduled notification fires automatically. no app needed.
///
/// 4. Battery: checked from HealthKit sample metadata on each background delivery.
///    If available and below threshold, a notification is sent immediately.
@MainActor
final class WatchMonitor {
    static let shared = WatchMonitor()

    private var healthStore: HKHealthStore?
    private var observerQuery: HKObserverQuery?

    // MARK: - UserDefaults Keys

    private let lastWatchDataKey = AppKeys.Watch.lastWatchDataTime
    private let lastObserverProcessingKey = AppKeys.Watch.lastObserverProcessing
    private let lastScheduleRefreshKey = AppKeys.Watch.lastScheduleRefresh

    /// Cached preferences to avoid repeated Keychain + AES-GCM decryption
    private var cachedPreferences: NotificationPreferences?
    private var preferencesLoadedAt: Date?

    private var observerProcessingInterval: TimeInterval {
        ThermalManager.shared.watchMonitorQueryInterval
    }

    private var scheduleRefreshInterval: TimeInterval {
        ThermalManager.shared.watchNotificationRefreshInterval
    }

    private let scheduledNotWornIdentifier = AppConstants.NotificationID.watchNotWornScheduled

    private init() {}

    // MARK: - Start / Stop

    /// Configure with a shared HKHealthStore to avoid creating duplicate instances
    func configure(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Use shared store, or create one as fallback
        if healthStore == nil { healthStore = HKHealthStore() }
        startHeartRateObserver()

        // If we previously saw watch data, ensure a "not worn" notification
        // is scheduled so it fires if the watch is currently off.
        let lastDataTime = UserDefaults.standard.double(forKey: lastWatchDataKey)
        if lastDataTime > 0 {
            ensureNotWornScheduled()
        }
    }

    func stopMonitoring() {
        if let store = healthStore {
            if let query = observerQuery {
                store.stop(query)
                observerQuery = nil
            }
            // Also stop background delivery, otherwise the app keeps getting woken
            // for HR after monitoring is off (e.g. after the user deletes their data).
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                store.disableBackgroundDelivery(for: heartRateType) { _, _ in }
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [scheduledNotWornIdentifier])
    }

    // MARK: - Heart Rate Observer (Background-Capable)

    /// Sets up HKObserverQuery + background delivery. This is the engine that drives
    /// everything. it runs even when the app is suspended.
    private func startHeartRateObserver() {
        guard let healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Stop any existing observer
        if let existing = observerQuery {
            healthStore.stop(existing)
        }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }
            // Fires in BACKGROUND. hop to MainActor to call isolated state.
            Task { @MainActor [weak self] in
                self?.onHeartRateDelivery()
                completionHandler()
            }
        }

        healthStore.execute(query)
        observerQuery = query

        // .immediate = wake app as soon as new data arrives (not hourly batched)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, _ in }

        // Also check right now
        onHeartRateDelivery()
    }

    // MARK: - Background Delivery Handler

    /// Called every time HealthKit delivers new heart rate data. foreground OR background.
    /// This is the single entry point for all watch monitoring logic.
    private func onHeartRateDelivery() {
        guard let healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let now = Date()
        let freshnessWindow = RemoteConfigManager.shared.watchDataFreshnessHours * 3600
        let defaults = UserDefaults.standard

        if canUseRecentWatchConfirmation(now: now, defaults: defaults, freshnessWindow: freshnessWindow) {
            let lastScheduleRefresh = defaults.double(forKey: lastScheduleRefreshKey)
            let shouldRefreshSchedule = lastScheduleRefresh == 0 ||
                now.timeIntervalSince(Date(timeIntervalSince1970: lastScheduleRefresh)) >= scheduleRefreshInterval

            // Refresh the pending alarm but do NOT re-stamp lastWatchDataKey:
            // this path has not verified a fresh watch sample (any HR observer
            // wake lands here), and stamping `now` made a watch that was
            // actually off look freshly worn, suppressing the alert forever.
            if shouldRefreshSchedule {
                scheduleNotWornNotification()
            }

            let lastProcessed = defaults.double(forKey: lastObserverProcessingKey)
            let processedRecently = lastProcessed > 0 &&
                now.timeIntervalSince(Date(timeIntervalSince1970: lastProcessed)) < observerProcessingInterval
            if processedRecently {
                return
            }
        }

        defaults.set(now.timeIntervalSince1970, forKey: lastObserverProcessingKey)

        let windowStart = now.addingTimeInterval(-freshnessWindow)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 3,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let samples, error == nil else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                for sample in samples {
                    if self.isFromAppleWatch(sample: sample) {
                        UserDefaults.standard.set(sample.startDate.timeIntervalSince1970, forKey: self.lastWatchDataKey)
                        self.scheduleNotWornNotification()
                        return
                    }
                }
                let lastDataTime = UserDefaults.standard.double(forKey: self.lastWatchDataKey)
                if lastDataTime > 0 {
                    self.ensureNotWornScheduled()
                }
            }
        }

        healthStore.execute(query)
    }

    private func canUseRecentWatchConfirmation(
        now: Date,
        defaults: UserDefaults,
        freshnessWindow: TimeInterval
    ) -> Bool {
        let lastConfirmedWatchData = defaults.double(forKey: lastWatchDataKey)
        guard lastConfirmedWatchData > 0 else { return false }
        return now.timeIntervalSince(Date(timeIntervalSince1970: lastConfirmedWatchData)) < freshnessWindow
    }

    // MARK: - Watch Detection

    /// Determine if a sample originated from an Apple Watch
    private func isFromAppleWatch(sample: HKSample) -> Bool {
        if let device = sample.device {
            if device.manufacturer == "Apple Inc.",
               let model = device.model, model.contains("Watch") {
                return true
            }
            if let name = device.name, name.contains("Apple Watch") {
                return true
            }
        }

        let bundleId = sample.sourceRevision.source.bundleIdentifier
        let watchPrefixes = ["com.apple.health", "com.apple.watch"]
        for prefix in watchPrefixes {
            if bundleId.hasPrefix(prefix) {
                if let device = sample.device, device.model?.contains("Watch") == true {
                    return true
                }
                if sample.sourceRevision.source.name.contains("Watch") {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Not Worn Notification (Background-Capable)

    /// Replaces the pending "not worn" notification with one anchored to the last
    /// confirmed watch sample plus `thresholdHours`. As long as watch data keeps
    /// arriving the anchor advances and the alarm never fires; the moment data
    /// stops, it fires threshold-after-last-wear. no app needed.
    private func scheduleNotWornNotification() {
        let preferences = loadCachedPreferences()
        guard preferences.watchNotWornReminderEnabled else {
            // Only an explicit opt-out removes the pending alarm. No
            // cancel-before-reschedule: center.add with the same identifier
            // replaces the pending request atomically, so a suppressed
            // reschedule (e.g. cold auth cache at launch) leaves the previous
            // alarm armed instead of deleting it.
            NotificationManager.shared.cancelNotification(identifier: scheduledNotWornIdentifier)
            return
        }

        let thresholdSeconds = RemoteConfigManager.shared.watchNotWornThresholdHours * 3600

        // Anchor the alarm to the LAST CONFIRMED WATCH SAMPLE, not to now.
        // Scheduling `now + threshold` on every observer wake / app open let
        // routine app usage push the alert forward forever even when the watch
        // had been off for most of the freshness window. iOS rejects a
        // non-positive interval, so an already-overdue alarm fires in a minute.
        let lastSeen = UserDefaults.standard.double(forKey: lastWatchDataKey)
        var fireIn = thresholdSeconds
        if lastSeen > 0 {
            let elapsed = Date().timeIntervalSince(Date(timeIntervalSince1970: lastSeen))
            fireIn = max(thresholdSeconds - elapsed, 60)
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
        let scheduled = NotificationManager.shared.scheduleNotification(
            title: DeviceMessaging.wearPromptTitle,
            body: Copy.Notifications.watchNotWornScheduled(device: DeviceMessaging.deviceName, wearToTrack: DeviceMessaging.wearToTrackMessage),
            identifier: scheduledNotWornIdentifier,
            trigger: trigger,
            maxPerDay: 1,
            bypassCap: true
        )
        // Stamp the refresh throttle only for a schedule that happened, so a
        // suppressed attempt retries on the next delivery instead of waiting
        // out the full refresh interval.
        if scheduled {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastScheduleRefreshKey)
        }
    }

    /// Ensures a "not worn" notification is pending without cancelling an existing one.
    /// Used at startup and when no fresh data is found. we don't want to reset the
    /// timer, just make sure one is scheduled.
    private func ensureNotWornScheduled() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let hasPending = requests.contains { $0.identifier == self.scheduledNotWornIdentifier }
                if !hasPending {
                    self.scheduleNotWornNotification()
                }
            }
        }
    }

    // MARK: - Battery Check (Background-Capable)

    // MARK: - Foreground Re-evaluation

    /// Called on foreground return. supplementary check, not the primary mechanism.
    /// The real work happens via background delivery above.
    func evaluateWatchStatus() {
        onHeartRateDelivery()
    }

    // MARK: - Preferences

    /// Load preferences with a 5-minute cache to avoid repeated Keychain + AES-GCM decryption
    private func loadCachedPreferences() -> NotificationPreferences {
        if let cached = cachedPreferences,
           let loadedAt = preferencesLoadedAt,
           Date().timeIntervalSince(loadedAt) < 300 {
            return cached
        }
        let prefs = PersistenceManager().loadPreferences()
        cachedPreferences = prefs
        preferencesLoadedAt = Date()
        return prefs
    }

    /// Invalidate cached preferences (call when user changes settings)
    func invalidatePreferencesCache() {
        cachedPreferences = nil
        preferencesLoadedAt = nil
    }
}
