import Foundation

/// Closes the daily-action loop. When a user marks the "Next Up" action done,
/// we record the action and that morning's readiness score. The next morning,
/// once a fresh score exists, `resultToShow` reports how the score moved so the
/// home screen can say "you did X yesterday, here is what happened" — the proof
/// the Next Up card already promises ("we check the result in tomorrow's score").
enum DailyActionResultStore {

    struct Record: Codable {
        let doneDate: Date
        let actionTitle: String
        let actionIcon: String
        let scoreOnDoneDay: Int
    }

    struct Result {
        enum Direction { case up, steady, down }
        let record: Record
        let todayScore: Int
        var delta: Int { todayScore - record.scoreOnDoneDay }
        var direction: Direction {
            // ±2 keeps normal day-to-day noise out of the "it moved" claim.
            if delta >= 2 { return .up }
            if delta <= -2 { return .down }
            return .steady
        }
    }

    private static let key = AppKeys.Data.dailyActionResult
    private static let defaults = UserDefaults.standard

    static func save(actionTitle: String, actionIcon: String, score: Int) {
        let record = Record(doneDate: Date(), actionTitle: actionTitle,
                            actionIcon: actionIcon, scoreOnDoneDay: score)
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear() { defaults.removeObject(forKey: key) }

    static var pending: Record? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    /// The result to surface today, or nil when it is not yet meaningful. Only
    /// fires on a day AFTER the action was done (the score needs a night to
    /// move), requires a real morning score, and expires records older than two
    /// days so a stale claim never shows.
    static func resultToShow(todayScore: Int) -> Result? {
        guard todayScore > 0, let record = pending else { return nil }
        guard !Date.cal.isDateInToday(record.doneDate) else { return nil }
        let days = Date.cal.dateComponents([.day], from: record.doneDate, to: Date()).day ?? 0
        guard (1...2).contains(days) else {
            if days > 2 { clear() }
            return nil
        }
        return Result(record: record, todayScore: todayScore)
    }
}
