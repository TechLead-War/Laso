import Foundation

struct ReadinessCacheSnapshot: Equatable {
    let score: Int
    let timestamp: Date?
}

/// Typed cache for the latest readiness score used during cold launch and background refresh.
final class ReadinessStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadCachedSnapshot() -> ReadinessCacheSnapshot? {
        let score = userDefaults.integer(forKey: AppKeys.Readiness.cachedScore)
        guard score > 0 else { return nil }

        let timestampInterval = userDefaults.double(forKey: AppKeys.Readiness.cachedTimestamp)
        let timestamp = timestampInterval > 0 ? Date(timeIntervalSince1970: timestampInterval) : nil
        return ReadinessCacheSnapshot(score: score, timestamp: timestamp)
    }

    func loadCachedScore() -> Int? {
        loadCachedSnapshot()?.score
    }

    func saveCachedScore(_ score: Int, at timestamp: Date = Date()) {
        userDefaults.set(score, forKey: AppKeys.Readiness.cachedScore)
        userDefaults.set(timestamp.timeIntervalSince1970, forKey: AppKeys.Readiness.cachedTimestamp)
    }

    func clear() {
        userDefaults.removeObject(forKey: AppKeys.Readiness.cachedScore)
        userDefaults.removeObject(forKey: AppKeys.Readiness.cachedTimestamp)
    }
}
