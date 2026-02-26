import Foundation
import Observation

/// Manages persistent storage for baselines and user preferences via UserDefaults,
/// with iCloud Key-Value Store sync for cross-device consistency.
@Observable
final class PersistenceManager {
    private let defaults = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default

    private let baselinesKey = AppKeys.Data.baselines
    private let preferencesKey = AppKeys.Data.preferences
    private let lastAnalysisKey = AppKeys.Data.lastAnalysis

    /// Keys that should sync to iCloud KVS for cross-device consistency
    private static let syncKeys: Set<String> = [
        AppKeys.Data.baselines,
        AppKeys.Data.preferences,
        AppKeys.Data.healthFocuses,
        AppKeys.Data.previousWeekScore,
        AppKeys.Data.currentScore,
        AppKeys.Data.scoreDate,
        AppKeys.App.onboardingCompleted
    ]

    init() {
        startCloudSync()
    }

    // MARK: - iCloud Sync

    /// Start observing iCloud KVS changes from other devices
    private func startCloudSync() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudChange(notification)
        }
        cloud.synchronize()
    }

    /// Pull cloud values into local defaults when changed externally
    private func handleCloudChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        for key in changedKeys where Self.syncKeys.contains(key) {
            if let cloudValue = cloud.object(forKey: key) {
                defaults.set(cloudValue, forKey: key)
            }
        }
    }

    /// Write to both local defaults and iCloud KVS
    private func save(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        if Self.syncKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    /// Write Data to both stores
    private func saveData(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
        if Self.syncKeys.contains(key) {
            cloud.set(data, forKey: key)
        }
    }

    // MARK: - Baselines

    func saveBaselines(_ baselines: [HealthMetric: UserBaseline]) {
        let dict = Dictionary(uniqueKeysWithValues: baselines.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            saveData(data, forKey: baselinesKey)
        }
    }

    func loadBaselines() -> [HealthMetric: UserBaseline] {
        guard let data = defaults.data(forKey: baselinesKey),
              let dict = try? JSONDecoder().decode([String: UserBaseline].self, from: data) else {
            return [:]
        }
        var result: [HealthMetric: UserBaseline] = [:]
        for (key, value) in dict {
            if let metric = HealthMetric(rawValue: key) {
                result[metric] = value
            }
        }
        return result
    }

    // MARK: - Preferences

    func savePreferences(_ preferences: NotificationPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            saveData(data, forKey: preferencesKey)
        }
    }

    func loadPreferences() -> NotificationPreferences {
        guard let data = defaults.data(forKey: preferencesKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }

    // MARK: - Last Analysis Date

    func saveLastAnalysisDate(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastAnalysisKey)
    }

    func loadLastAnalysisDate() -> Date? {
        let interval = defaults.double(forKey: lastAnalysisKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Weekly Score Tracking

    private let previousWeekScoreKey = AppKeys.Data.previousWeekScore
    private let currentScoreKey = AppKeys.Data.currentScore
    private let scoreDateKey = AppKeys.Data.scoreDate

    /// Record the current health score. Rotates current → previous when a new calendar week begins.
    func recordWeeklyScore(_ score: Int) {
        let calendar = Calendar.current
        let now = Date()

        if let savedDate = scoreDate(),
           !calendar.isDate(savedDate, equalTo: now, toGranularity: .weekOfYear) {
            let oldScore = defaults.integer(forKey: currentScoreKey)
            if oldScore > 0 {
                save(oldScore, forKey: previousWeekScoreKey)
            }
        }

        save(score, forKey: currentScoreKey)
        save(now.timeIntervalSince1970, forKey: scoreDateKey)
    }

    /// Load the score from the previous calendar week, if available
    func loadPreviousWeekScore() -> Int? {
        let val = defaults.integer(forKey: previousWeekScoreKey)
        return val > 0 ? val : nil
    }

    private func scoreDate() -> Date? {
        let interval = defaults.double(forKey: scoreDateKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    // MARK: - Health Focuses

    private let healthFocusesKey = AppKeys.Data.healthFocuses

    func saveHealthFocuses(_ focuses: Set<HealthFocus>) {
        if let data = try? JSONEncoder().encode(Array(focuses)) {
            saveData(data, forKey: healthFocusesKey)
        }
    }

    func loadHealthFocuses() -> Set<HealthFocus> {
        guard let data = defaults.data(forKey: healthFocusesKey),
              let array = try? JSONDecoder().decode([HealthFocus].self, from: data) else {
            return Set(HealthFocus.allCases)
        }
        return Set(array)
    }
}
