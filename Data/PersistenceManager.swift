import Foundation
import Observation

/// Manages persistent storage for baselines and user preferences via UserDefaults
@Observable
final class PersistenceManager {
    private let defaults = UserDefaults.standard

    private let baselinesKey = "healthpulse.baselines"
    private let preferencesKey = "healthpulse.preferences"
    private let lastAnalysisKey = "healthpulse.lastAnalysis"

    // MARK: - Baselines

    func saveBaselines(_ baselines: [HealthMetric: UserBaseline]) {
        let dict = Dictionary(uniqueKeysWithValues: baselines.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: baselinesKey)
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
            defaults.set(data, forKey: preferencesKey)
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
}
