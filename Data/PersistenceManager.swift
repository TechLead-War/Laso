import Foundation
import Observation

/// Manages persistent storage for baselines and user preferences.
/// Sensitive health data is encrypted via EncryptedStore (AES-GCM + Keychain key).
/// Only non-sensitive preferences sync to iCloud KVS.
@Observable
final class PersistenceManager {
    private let defaults = UserDefaults.standard
    private let encrypted = EncryptedStore.shared
    private let cloud = NSUbiquitousKeyValueStore.default

    private let baselinesKey = AppKeys.Data.baselines
    private let preferencesKey = AppKeys.Data.preferences
    private let lastAnalysisKey = AppKeys.Data.lastAnalysis

    private static let encoderKey = "Laso.PersistenceManager.encoder"
    private static let decoderKey = "Laso.PersistenceManager.decoder"

    /// Only non-sensitive keys sync to iCloud
    private static let syncKeys: Set<String> = [
        AppKeys.App.onboardingCompleted
    ]

    /// Sensitive keys that use encrypted storage
    private static let encryptedKeys: Set<String> = [
        AppKeys.Data.baselines,
        AppKeys.Data.preferences,
        AppKeys.Data.healthFocuses,
        AppKeys.Data.previousWeekScore,
        AppKeys.Data.currentScore
    ]

    init() {
        startCloudSync()
        migratePlaintextData()
        migrateCriticalAlertsDefault()
    }

    // MARK: - Migration

    /// One-time migration of any existing plaintext health data to encrypted storage
    private func migratePlaintextData() {
        for key in Self.encryptedKeys {
            encrypted.migrateIfNeeded(forKey: key)
        }
    }

    /// One-time migration: enable critical + heart rate alerts for existing users.
    /// Only runs once; skips if user already has them enabled.
    private func migrateCriticalAlertsDefault() {
        let migrationKey = "healthpulse.migration.criticalAlertsDefault"
        guard !defaults.bool(forKey: migrationKey) else { return }
        defaults.set(true, forKey: migrationKey)

        var prefs = loadPreferences()
        // Only flip if the user never enabled them (still at old defaults)
        if !prefs.criticalAlertsEnabled {
            prefs.criticalAlertsEnabled = true
        }
        if !prefs.heartRateSpikeAlertsEnabled {
            prefs.heartRateSpikeAlertsEnabled = true
        }
        if prefs.maxNotificationsPerDay < 2 {
            prefs.maxNotificationsPerDay = 2
        }
        savePreferences(prefs)
    }

    // MARK: - iCloud Sync (non-sensitive only)

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

    private func handleCloudChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }

        for key in changedKeys where Self.syncKeys.contains(key) {
            if let cloudValue = cloud.object(forKey: key) {
                defaults.set(cloudValue, forKey: key)
            }
        }
    }

    /// Write non-sensitive value to UserDefaults + iCloud if applicable
    private func save(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        if Self.syncKeys.contains(key) {
            cloud.set(value, forKey: key)
        }
    }

    /// Write sensitive Data — encrypts before storing, never syncs to iCloud
    private func saveEncrypted(_ data: Data, forKey key: String) {
        encrypted.save(data, forKey: key)
    }

    /// Load sensitive Data — decrypts from storage
    private func loadEncrypted(forKey key: String) -> Data? {
        encrypted.load(forKey: key)
    }

    private static func threadEncoder() -> JSONEncoder {
        let dictionary = Thread.current.threadDictionary
        if let encoder = dictionary[encoderKey] as? JSONEncoder {
            return encoder
        }

        let encoder = JSONEncoder()
        dictionary[encoderKey] = encoder
        return encoder
    }

    private static func threadDecoder() -> JSONDecoder {
        let dictionary = Thread.current.threadDictionary
        if let decoder = dictionary[decoderKey] as? JSONDecoder {
            return decoder
        }

        let decoder = JSONDecoder()
        dictionary[decoderKey] = decoder
        return decoder
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> Data? {
        try? Self.threadEncoder().encode(value)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? Self.threadDecoder().decode(type, from: data)
    }

    // MARK: - Baselines (Encrypted)

    func saveBaselines(_ baselines: [HealthMetric: UserBaseline]) {
        let dict = Dictionary(uniqueKeysWithValues: baselines.map { ($0.key.rawValue, $0.value) })
        if let data = encodeJSON(dict) {
            saveEncrypted(data, forKey: baselinesKey)
        }
    }

    func loadBaselines() -> [HealthMetric: UserBaseline] {
        guard let data = loadEncrypted(forKey: baselinesKey),
              let dict = decodeJSON([String: UserBaseline].self, from: data) else {
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

    // MARK: - Preferences (Encrypted)

    func savePreferences(_ preferences: NotificationPreferences) {
        if let data = encodeJSON(preferences) {
            saveEncrypted(data, forKey: preferencesKey)
        }
    }

    func loadPreferences() -> NotificationPreferences {
        guard let data = loadEncrypted(forKey: preferencesKey),
              let prefs = decodeJSON(NotificationPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }

    // MARK: - Last Analysis Date (Non-sensitive)

    func saveLastAnalysisDate(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastAnalysisKey)
    }

    func loadLastAnalysisDate() -> Date? {
        let interval = defaults.double(forKey: lastAnalysisKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Weekly Score Tracking (Encrypted)

    private let previousWeekScoreKey = AppKeys.Data.previousWeekScore
    private let currentScoreKey = AppKeys.Data.currentScore
    private let scoreDateKey = AppKeys.Data.scoreDate
    private let progressiveCoachStateKey = AppKeys.Data.progressiveCoachState

    func recordWeeklyScore(_ score: Int) {
        let calendar = Calendar.current
        let now = Date()

        if let savedDate = scoreDate(),
           !calendar.isDate(savedDate, equalTo: now, toGranularity: .weekOfYear) {
            if let currentData = loadEncrypted(forKey: currentScoreKey),
               let oldScore = decodeJSON(Int.self, from: currentData),
               oldScore > 0 {
                if let data = encodeJSON(oldScore) {
                    saveEncrypted(data, forKey: previousWeekScoreKey)
                }
            }
        }

        if let data = encodeJSON(score) {
            saveEncrypted(data, forKey: currentScoreKey)
        }
        defaults.set(now.timeIntervalSince1970, forKey: scoreDateKey)
    }

    func loadPreviousWeekScore() -> Int? {
        guard let data = loadEncrypted(forKey: previousWeekScoreKey),
              let val = decodeJSON(Int.self, from: data) else { return nil }
        return val > 0 ? val : nil
    }

    private func scoreDate() -> Date? {
        let interval = defaults.double(forKey: scoreDateKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    // MARK: - Progressive Coach (Encrypted)

    func saveProgressiveCoachState(_ state: ProgressiveCoachState) {
        if let data = encodeJSON(state) {
            saveEncrypted(data, forKey: progressiveCoachStateKey)
        }
    }

    func loadProgressiveCoachState() -> ProgressiveCoachState? {
        guard let data = loadEncrypted(forKey: progressiveCoachStateKey) else { return nil }
        return decodeJSON(ProgressiveCoachState.self, from: data)
    }

    // MARK: - Health Focuses (Encrypted)

    private let healthFocusesKey = AppKeys.Data.healthFocuses

    func saveHealthFocuses(_ focuses: Set<HealthFocus>) {
        if let data = encodeJSON(Array(focuses)) {
            saveEncrypted(data, forKey: healthFocusesKey)
        }
    }

    func loadHealthFocuses() -> Set<HealthFocus> {
        guard let data = loadEncrypted(forKey: healthFocusesKey),
              let array = decodeJSON([HealthFocus].self, from: data) else {
            return Set(HealthFocus.allCases)
        }
        return Set(array)
    }
}
