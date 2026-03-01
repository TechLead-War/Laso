import Foundation
import HealthKit
import UserNotifications

/// Monitors Apple Watch wearing status via HealthKit heart rate data freshness
/// and provides low-battery notification support.
final class WatchMonitor {
    static let shared = WatchMonitor()

    private var healthStore: HKHealthStore?
    private var observerQuery: HKObserverQuery?

    // MARK: - UserDefaults Keys

    private let lastWatchDataKey = AppKeys.Watch.lastWatchDataTime
    private let lastNotWornNotificationKey = AppKeys.Watch.lastNotWornNotification
    private let lowBatteryAlertShownKey = AppKeys.Watch.lowBatteryAlertShown

    /// Minimum hours between repeated "not worn" notifications
    private var notWornCooldownHours: Double { RemoteConfigManager.shared.watchNotWornCooldownHours }

    /// Cached preferences to avoid repeated Keychain + AES-GCM decryption
    private var cachedPreferences: NotificationPreferences?
    private var preferencesLoadedAt: Date?

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
    }

    func stopMonitoring() {
        if let query = observerQuery, let store = healthStore {
            store.stop(query)
            observerQuery = nil
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [scheduledNotWornIdentifier])
    }

    // MARK: - Heart Rate Observer (Watch Wearing Detection)

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
            self?.checkLatestHeartRateSource()
            completionHandler()
        }

        healthStore.execute(query)
        observerQuery = query

        // Enable background delivery so the observer fires even when the app is suspended
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .hourly) { _, _ in }

        // Also check immediately
        checkLatestHeartRateSource()
    }

    /// Query the most recent heart rate sample and check if it came from an Apple Watch
    private func checkLatestHeartRateSource() {
        guard let healthStore,
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Only look at samples from the last 2 hours
        let twHoursAgo = Date().addingTimeInterval(-RemoteConfigManager.shared.watchDataFreshnessHours * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: twHoursAgo, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 5,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self, let samples, error == nil else { return }

            for sample in samples {
                if self.isFromAppleWatch(sample: sample) {
                    UserDefaults.standard.set(
                        sample.startDate.timeIntervalSince1970,
                        forKey: self.lastWatchDataKey
                    )
                    // Watch is actively sending data — push the "not worn" notification forward
                    self.rescheduleNotWornReminder()
                    return
                }
            }
        }

        healthStore.execute(query)
    }

    /// Determine if a sample originated from an Apple Watch
    private func isFromAppleWatch(sample: HKSample) -> Bool {
        // Check HKDevice metadata
        if let device = sample.device {
            if device.manufacturer == "Apple Inc.",
               let model = device.model, model.contains("Watch") {
                return true
            }
            if let name = device.name, name.contains("Apple Watch") {
                return true
            }
        }

        // Check source bundle identifier
        let bundleId = sample.sourceRevision.source.bundleIdentifier
        let watchPrefixes = ["com.apple.health", "com.apple.watch"]
        for prefix in watchPrefixes {
            if bundleId.hasPrefix(prefix) {
                // Distinguish Apple Watch from iPhone health data
                if let device = sample.device, device.model?.contains("Watch") == true {
                    return true
                }
                // If no device metadata, check if source name hints at watch
                if sample.sourceRevision.source.name.contains("Watch") {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Foreground Check

    /// Called on foreground return — evaluates all watch-related alerts.
    /// No periodic timer needed: the HKObserverQuery + scheduled UNNotification handle detection.
    func evaluateWatchStatus() {
        let preferences = loadCachedPreferences()

        if preferences.watchNotWornReminderEnabled {
            checkWatchNotWorn(maxPerDay: preferences.maxNotificationsPerDay)
        }
    }

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

    // MARK: - Scheduled "Not Worn" Notification (Background-capable)

    private let scheduledNotWornIdentifier = "healthpulse.watch.notWorn.scheduled"

    /// Cancels any pending scheduled "not worn" notification, then schedules a new one
    /// to fire after `thresholdHours`. Each time fresh Apple Watch data arrives, this
    /// gets called — pushing the notification forward. If data stops (watch removed or
    /// battery dead), the notification fires automatically even if the app is killed.
    private func rescheduleNotWornReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [scheduledNotWornIdentifier])

        let preferences = loadCachedPreferences()
        guard preferences.watchNotWornReminderEnabled else { return }

        let thresholdSeconds = RemoteConfigManager.shared.watchNotWornThresholdHours * 3600

        let content = UNMutableNotificationContent()
        content.title = "Wear Your Watch"
        content.body = "Your Apple Watch hasn't recorded data for a while. Put it on to keep tracking, or charge it if the battery is low."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: thresholdSeconds, repeats: false)
        let request = UNNotificationRequest(identifier: scheduledNotWornIdentifier, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    // MARK: - Watch Not Worn Check (Foreground Fallback)

    private func checkWatchNotWorn(maxPerDay: Int) {
        let defaults = UserDefaults.standard
        let lastDataTime = defaults.double(forKey: lastWatchDataKey)

        // If we've never received watch data, don't alert (user might not have a watch)
        guard lastDataTime > 0 else { return }

        let elapsed = Date().timeIntervalSince1970 - lastDataTime
        let threshold: TimeInterval = RemoteConfigManager.shared.watchNotWornThresholdHours * 3600

        // Only alert if more than threshold without data
        guard elapsed > threshold else { return }

        // Enforce cooldown between repeated notifications
        let lastNotification = defaults.double(forKey: lastNotWornNotificationKey)
        if lastNotification > 0 {
            let sinceLastNotification = Date().timeIntervalSince1970 - lastNotification
            guard sinceLastNotification > notWornCooldownHours * 3600 else { return }
        }

        let hours = Int(elapsed / 3600)
        let minutes = Int(elapsed.truncatingRemainder(dividingBy: 3600) / 60)

        let body: String
        if hours >= 1 {
            body = "Your Apple Watch hasn't recorded data for \(hours)h \(minutes)m. Put it on to keep tracking, or charge it if the battery is low."
        } else {
            body = "Your Apple Watch hasn't recorded data recently. Put it on to keep tracking, or charge it if the battery is low."
        }

        NotificationManager.shared.scheduleNotification(
            title: "Wear Your Watch",
            body: body,
            identifier: "healthpulse.watch.notWorn",
            maxPerDay: maxPerDay
        )
        AppAnalytics.shared.trackNotificationSent(type: "watch_not_worn")

        defaults.set(Date().timeIntervalSince1970, forKey: lastNotWornNotificationKey)
    }

    // MARK: - Battery Level

    /// Call this when battery level data becomes available (e.g. via WatchConnectivity companion).
    /// `level` is 0.0–1.0 (e.g. 0.08 = 8%).
    func handleBatteryLevel(_ level: Double) {
        let preferences = loadCachedPreferences()
        guard preferences.lowBatteryReminderEnabled else { return }

        let defaults = UserDefaults.standard

        if level < RemoteConfigManager.shared.watchBatteryLowThreshold {
            // Only show once per low-battery cycle
            guard !defaults.bool(forKey: lowBatteryAlertShownKey) else { return }

            NotificationManager.shared.scheduleNotification(
                title: "Watch Battery Low",
                body: "Your Apple Watch battery is at \(Int(level * 100))%. Charge it soon to avoid missing health data.",
                identifier: "healthpulse.watch.lowBattery",
                maxPerDay: preferences.maxNotificationsPerDay
            )
            AppAnalytics.shared.trackNotificationSent(type: "battery_low")

            defaults.set(true, forKey: lowBatteryAlertShownKey)
        } else {
            // Battery recovered above 10% — reset so we can alert again next cycle
            defaults.set(false, forKey: lowBatteryAlertShownKey)
        }
    }

    /// Reset low battery alert flag (e.g. when user manually charges watch)
    func resetLowBatteryAlert() {
        UserDefaults.standard.set(false, forKey: lowBatteryAlertShownKey)
    }
}
