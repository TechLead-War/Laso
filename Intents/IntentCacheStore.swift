import Foundation

struct IntentCacheSnapshot: Equatable {
    let score: Int
    let grade: String
    let summary: String
}

/// Typed cache for the lightweight values App Intents need when the full app stack is unavailable.
final class IntentCacheStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveHealthSummary(score: Int, grade: String, summary: String) {
        userDefaults.set(score, forKey: AppKeys.Intent.score)
        userDefaults.set(grade, forKey: AppKeys.Intent.grade)
        userDefaults.set(summary, forKey: AppKeys.Intent.summary)
    }

    func loadHealthSummary() -> IntentCacheSnapshot? {
        let score = userDefaults.integer(forKey: AppKeys.Intent.score)
        guard score > 0 else { return nil }

        return IntentCacheSnapshot(
            score: score,
            grade: userDefaults.string(forKey: AppKeys.Intent.grade) ?? "?",
            summary: userDefaults.string(forKey: AppKeys.Intent.summary) ?? ""
        )
    }

    func loadTrendsSummary() -> String? {
        guard let summary = userDefaults.string(forKey: AppKeys.Intent.summary),
              !summary.isEmpty else {
            return nil
        }
        return summary
    }

    func clear() {
        userDefaults.removeObject(forKey: AppKeys.Intent.score)
        userDefaults.removeObject(forKey: AppKeys.Intent.grade)
        userDefaults.removeObject(forKey: AppKeys.Intent.summary)
    }
}
