import Foundation

struct ReadinessCacheSnapshot: Equatable {
    let score: Int
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
        return ReadinessCacheSnapshot(score: score)
    }

    func loadCachedScore() -> Int? {
        loadCachedSnapshot()?.score
    }

    func saveCachedScore(_ score: Int) {
        userDefaults.set(score, forKey: AppKeys.Readiness.cachedScore)
    }

    // MARK: - Per-Day Morning Lock
    //
    // Recovery anchors are computed once each morning from last-night sleep +
    // overnight HRV/RHR vs the user's 60-day baseline (Plews/Altini). The lock
    // is keyed by yyyy-MM-dd in `Date.cal` calendar/timezone so a cold launch
    // or refresh later in the day re-uses today's morning anchor instead of
    // recomputing from drained mid-day signals.

    /// `yyyy-MM-dd` formatted in `Date.cal` calendar/timezone, locale `en_US_POSIX`.
    /// Stable across cold launches (no formatter allocation per call thanks to
    /// the thread-cached formatter) and never affected by user locale changes.
    private func dateKeySuffix(for date: Date) -> String {
        let formatter = Date.formatter(format: "yyyy-MM-dd")
        formatter.calendar = Date.cal
        formatter.timeZone = Date.cal.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    func loadMorningLock(for date: Date) -> Int? {
        let key = AppKeys.Readiness.morningLockScorePrefix + dateKeySuffix(for: date)
        let score = userDefaults.integer(forKey: key)
        return score > 0 ? score : nil
    }

    func saveMorningLock(_ score: Int, for date: Date) {
        let suffix = dateKeySuffix(for: date)
        userDefaults.set(score, forKey: AppKeys.Readiness.morningLockScorePrefix + suffix)
        userDefaults.set(date.timeIntervalSince1970, forKey: AppKeys.Readiness.morningLockDatePrefix + suffix)
    }

    func loadMorningLockConfidence(for date: Date) -> Int? {
        let key = AppKeys.Readiness.morningLockConfidencePrefix + dateKeySuffix(for: date)
        // `integer(forKey:)` returns 0 when the key is absent, which is also a
        // valid (unhelpful) confidence value. The score lock is the source of
        // truth for "lock exists today" — confidence is purely informational.
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.integer(forKey: key)
    }

    func saveMorningLockConfidence(_ confidence: Int, for date: Date) {
        let key = AppKeys.Readiness.morningLockConfidencePrefix + dateKeySuffix(for: date)
        userDefaults.set(confidence, forKey: key)
    }
}
