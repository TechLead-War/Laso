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

    // MARK: - Generic Encrypted Persistence

    private func saveEncryptedValue<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? Self.threadEncoder().encode(value) else { return }
        saveEncrypted(data, forKey: key)
    }

    private func loadEncryptedValue<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = loadEncrypted(forKey: key) else { return nil }
        return try? Self.threadDecoder().decode(type, from: data)
    }

    // MARK: - Baselines

    func saveBaselines(_ baselines: [HealthMetric: UserBaseline]) {
        let dict = Dictionary(uniqueKeysWithValues: baselines.map { ($0.key.rawValue, $0.value) })
        saveEncryptedValue(dict, forKey: baselinesKey)
    }

    func loadBaselines() -> [HealthMetric: UserBaseline] {
        guard let dict = loadEncryptedValue([String: UserBaseline].self, forKey: baselinesKey) else { return [:] }
        return dict.reduce(into: [:]) { result, pair in
            if let metric = HealthMetric(rawValue: pair.key) {
                result[metric] = pair.value
            }
        }
    }

    // MARK: - Preferences

    func savePreferences(_ preferences: NotificationPreferences) {
        saveEncryptedValue(preferences, forKey: preferencesKey)
    }

    func loadPreferences() -> NotificationPreferences {
        loadEncryptedValue(NotificationPreferences.self, forKey: preferencesKey) ?? .default
    }

    // MARK: - Last Analysis Date

    func saveLastAnalysisDate(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastAnalysisKey)
    }

    func loadLastAnalysisDate() -> Date? {
        let interval = defaults.double(forKey: lastAnalysisKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    // MARK: - Weekly Score Tracking

    private let previousWeekScoreKey = AppKeys.Data.previousWeekScore
    private let currentScoreKey = AppKeys.Data.currentScore
    private let scoreDateKey = AppKeys.Data.scoreDate
    private let progressiveCoachStateKey = AppKeys.Data.progressiveCoachState

    func recordWeeklyScore(_ score: Int) {
        let now = Date()
        if let savedDate = scoreDate(),
           !Calendar.current.isDate(savedDate, equalTo: now, toGranularity: .weekOfYear),
           let oldScore = loadEncryptedValue(Int.self, forKey: currentScoreKey),
           oldScore > 0 {
            saveEncryptedValue(oldScore, forKey: previousWeekScoreKey)
        }
        saveEncryptedValue(score, forKey: currentScoreKey)
        defaults.set(now.timeIntervalSince1970, forKey: scoreDateKey)
    }

    func loadPreviousWeekScore() -> Int? {
        guard let val = loadEncryptedValue(Int.self, forKey: previousWeekScoreKey), val > 0 else { return nil }
        return val
    }

    private func scoreDate() -> Date? {
        let interval = defaults.double(forKey: scoreDateKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    // MARK: - Progressive Coach

    func saveProgressiveCoachState(_ state: ProgressiveCoachState) {
        saveEncryptedValue(state, forKey: progressiveCoachStateKey)
    }

    func loadProgressiveCoachState() -> ProgressiveCoachState? {
        loadEncryptedValue(ProgressiveCoachState.self, forKey: progressiveCoachStateKey)
    }

    // MARK: - Health Focuses

    private let healthFocusesKey = AppKeys.Data.healthFocuses

    func saveHealthFocuses(_ focuses: Set<HealthFocus>) {
        saveEncryptedValue(Array(focuses), forKey: healthFocusesKey)
    }

    func loadHealthFocuses() -> Set<HealthFocus> {
        guard let array = loadEncryptedValue([HealthFocus].self, forKey: healthFocusesKey) else {
            return Set(HealthFocus.allCases)
        }
        return Set(array)
    }
}
