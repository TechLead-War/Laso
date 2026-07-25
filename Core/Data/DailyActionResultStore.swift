import Foundation

/// Closes the daily-action loop. When a user marks the "Next Up" action done,
/// we record the action and that day's morning recovery lock. The next morning,
/// once a fresh lock exists, `resultToShow` reports how the score moved so the
/// home screen can say "you did X yesterday, here is what happened" — the proof
/// the Next Up card already promises ("we check the result in tomorrow's score").
///
/// Both sides of the comparison are morning locks on purpose. The number on
/// Home is the lock minus the day's active-calorie drain, so recording that
/// number in the evening and comparing it to an undrained morning lock would
/// manufacture a gain out of nothing but the hour the user tapped done.
enum DailyActionResultStore {

    struct Record: Codable {
        let doneDate: Date
        let actionTitle: String
        let actionIcon: String
        /// Morning lock of the day the action was done, never the live drained score.
        let morningLockOnDoneDay: Int
    }

    struct Result {
        enum Direction { case up, steady, down }
        let record: Record
        let todayMorningLock: Int
        var delta: Int { todayMorningLock - record.morningLockOnDoneDay }
        var direction: Direction {
            // ±2 keeps normal day-to-day noise out of the "it moved" claim.
            if delta >= 2 { return .up }
            if delta <= -2 { return .down }
            return .steady
        }
    }

    private static let key = AppKeys.Data.dailyActionResult
    private static let defaults = UserDefaults.standard
    private static let readinessStore = ReadinessStore()

    /// Records the action against today's morning lock. The baseline is read here
    /// rather than passed in: a caller's live on-screen number drains through the
    /// day, so it is not comparable to the morning lock it would be measured
    /// against tomorrow, and a caller with no score at all handed over a zero.
    static func save(actionTitle: String, actionIcon: String) {
        guard let lock = readinessStore.loadMorningLock(for: Date()) else {
            // No comparable baseline today, so tomorrow shows no result card at
            // all rather than a delta we cannot stand behind. Any older record
            // goes too: it no longer describes the latest action the user did.
            clear()
            AnalyticsBackend.provider.captureError(
                "Action marked done with no morning lock for today, result card skipped",
                context: "daily_action_result_no_baseline")
            return
        }

        let record = Record(doneDate: Date(), actionTitle: actionTitle,
                            actionIcon: actionIcon, morningLockOnDoneDay: lock)
        guard let data = try? JSONEncoder().encode(record) else {
            AnalyticsBackend.provider.captureError(
                "Failed to encode daily action result record",
                context: "daily_action_result_encode")
            return
        }
        defaults.set(data, forKey: key)
    }

    static func clear() { defaults.removeObject(forKey: key) }

    static var pending: Record? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    /// The result to surface today, or nil when it is not yet meaningful. Only
    /// fires on a day AFTER the action was done (the score needs a night to
    /// move), requires today's morning lock, and expires records older than two
    /// days so a stale claim never shows.
    static func resultToShow() -> Result? {
        guard let record = pending else {
            // Records written before the baseline became the morning lock cannot
            // decode. Drop the blob so it does not sit in defaults forever.
            if defaults.data(forKey: key) != nil { clear() }
            return nil
        }
        guard !Date.cal.isDateInToday(record.doneDate) else { return nil }
        // Compare calendar days, not 24h spans: an action done at 11pm must count
        // as "yesterday" by 8am, so normalize both ends to start of day first.
        let days = Date.cal.dateComponents([.day], from: Date.cal.startOfDay(for: record.doneDate), to: Date.cal.startOfDay(for: Date())).day ?? 0
        guard (1...2).contains(days) else {
            if days > 2 { clear() }
            return nil
        }
        // Wait for today's lock rather than falling back to the live number:
        // later in the day that number is drained and would understate the move.
        guard let todayLock = readinessStore.loadMorningLock(for: Date()) else { return nil }
        return Result(record: record, todayMorningLock: todayLock)
    }
}
