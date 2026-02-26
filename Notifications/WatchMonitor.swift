import Foundation
import HealthKit

/// Monitors Apple Watch wearing status via HealthKit heart rate data freshness
/// and provides low-battery notification support.
final class WatchMonitor {
    static let shared = WatchMonitor()

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var checkTimer: Timer?

    // MARK: - UserDefaults Keys

    private let lastWatchDataKey = "healthpulse.watchMonitor.lastWatchDataTime"
    private let lastNotWornNotificationKey = "healthpulse.watchMonitor.lastNotWornNotification"
    private let lowBatteryAlertShownKey = "healthpulse.watchMonitor.lowBatteryAlertShown"

    /// Minimum hours between repeated "not worn" notifications
    private let notWornCooldownHours: Double = 4

    private init() {}

    // MARK: - Start / Stop

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        startHeartRateObserver()
        startPeriodicCheck()
    }

    func stopMonitoring() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Heart Rate Observer (Watch Wearing Detection)

    private func startHeartRateObserver() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

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

        // Also check immediately
        checkLatestHeartRateSource()
    }

    /// Query the most recent heart rate sample and check if it came from an Apple Watch
    private func checkLatestHeartRateSource() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Only look at samples from the last 2 hours
        let twHoursAgo = Date().addingTimeInterval(-2 * 3600)
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

    // MARK: - Periodic Check

    private func startPeriodicCheck() {
        checkTimer?.invalidate()
        // Check every 15 minutes
        checkTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.evaluateWatchStatus()
        }
        // Run immediately
        evaluateWatchStatus()
    }

    /// Called on foreground or by timer — evaluates all watch-related alerts
    func evaluateWatchStatus() {
        let preferences = PersistenceManager().loadPreferences()

        if preferences.watchNotWornReminderEnabled {
            checkWatchNotWorn(maxPerDay: preferences.maxNotificationsPerDay)
        }
    }

    // MARK: - Watch Not Worn Check

    private func checkWatchNotWorn(maxPerDay: Int) {
        let defaults = UserDefaults.standard
        let lastDataTime = defaults.double(forKey: lastWatchDataKey)

        // If we've never received watch data, don't alert (user might not have a watch)
        guard lastDataTime > 0 else { return }

        let elapsed = Date().timeIntervalSince1970 - lastDataTime
        let oneHour: TimeInterval = 3600

        // Only alert if more than 1 hour without data
        guard elapsed > oneHour else { return }

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
            body = "Your Apple Watch hasn't recorded data for \(hours)h \(minutes)m. Put it on to keep tracking your health."
        } else {
            body = "Your Apple Watch hasn't recorded data recently. Put it on to keep tracking your health."
        }

        NotificationManager.shared.scheduleNotification(
            title: "Wear Your Watch",
            body: body,
            identifier: "healthpulse.watch.notWorn",
            maxPerDay: maxPerDay
        )

        defaults.set(Date().timeIntervalSince1970, forKey: lastNotWornNotificationKey)
    }

    // MARK: - Battery Level

    /// Call this when battery level data becomes available (e.g. via WatchConnectivity companion).
    /// `level` is 0.0–1.0 (e.g. 0.08 = 8%).
    func handleBatteryLevel(_ level: Double) {
        let preferences = PersistenceManager().loadPreferences()
        guard preferences.lowBatteryReminderEnabled else { return }

        let defaults = UserDefaults.standard

        if level < 0.10 {
            // Only show once per low-battery cycle
            guard !defaults.bool(forKey: lowBatteryAlertShownKey) else { return }

            NotificationManager.shared.scheduleNotification(
                title: "Watch Battery Low",
                body: "Your Apple Watch battery is at \(Int(level * 100))%. Charge it soon to avoid missing health data.",
                identifier: "healthpulse.watch.lowBattery",
                maxPerDay: preferences.maxNotificationsPerDay
            )

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
