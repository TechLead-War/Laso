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

    // MARK: - Weekly Score Tracking

    private let previousWeekScoreKey = "healthpulse.previousWeekScore"
    private let currentScoreKey = "healthpulse.currentScore"
    private let scoreDateKey = "healthpulse.scoreDate"

    /// Record the current health score. Rotates current → previous when a new calendar week begins.
    func recordWeeklyScore(_ score: Int) {
        let calendar = Calendar.current
        let now = Date()

        if let savedDate = scoreDate(),
           !calendar.isDate(savedDate, equalTo: now, toGranularity: .weekOfYear) {
            let oldScore = defaults.integer(forKey: currentScoreKey)
            if oldScore > 0 {
                defaults.set(oldScore, forKey: previousWeekScoreKey)
            }
        }

        defaults.set(score, forKey: currentScoreKey)
        defaults.set(now.timeIntervalSince1970, forKey: scoreDateKey)
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
}
