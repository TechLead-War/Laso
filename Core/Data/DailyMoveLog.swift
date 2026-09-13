import Foundation

/// The two moves the brief showed each day and whether the person did them.
///
/// One record per calendar day, kept as a bounded JSON array in UserDefaults
/// like the morning check-in history. Phone, wrist and lock screen all write
/// through here so "did they do it" has one answer, and the next morning's
/// verdict reads yesterday from here.
@MainActor
enum DailyMoveLog {

    enum MoveKind: String, Codable { case day, night }

    struct Move: Codable, Equatable {
        var title: String
        var icon: String
        var source: String
        var shownAt: Date
        var doneAt: Date?
        var bedtimeTarget: Date?
        var sleepDebtHoursAtShow: Double?
    }

    struct Entry: Codable, Equatable {
        /// Start of the calendar day, so a night move done after midnight still
        /// belongs to the evening it was shown on.
        var day: Date
        var dayMove: Move?
        var nightMove: Move?
    }

    /// Where the log lives. Tests point this at a throwaway suite.
    static var defaults: UserDefaults = .standard

    /// Bumped on every write so the brief can tell the log changed without
    /// diffing entries.
    private(set) static var revision = 0

    private static let key = AppKeys.Data.dailyMoveLog

    /// Upserts today's moves. A move already on file keeps its first sighting
    /// and its tick; only the text follows the advisor when it changes its
    /// mind before the person acts.
    static func recordShown(day: Date = Date(), dayMove: Move?, nightMove: Move?) {
        var history = loadHistory()
        let dayStart = Date.cal.startOfDay(for: day)
        let index = history.firstIndex { $0.day == dayStart }
        var entry = index.map { history[$0] } ?? Entry(day: dayStart, dayMove: nil, nightMove: nil)
        entry.dayMove = merged(existing: entry.dayMove, shown: dayMove)
        entry.nightMove = merged(existing: entry.nightMove, shown: nightMove)
        if let index { history[index] = entry } else { history.append(entry) }
        persist(history)
    }

    private static func merged(existing: Move?, shown: Move?) -> Move? {
        guard let shown else { return existing }
        guard var existing else { return shown }
        // A done move keeps the text the person actually acted on.
        guard existing.doneAt == nil else { return existing }
        existing.title = shown.title
        existing.icon = shown.icon
        existing.source = shown.source
        existing.bedtimeTarget = shown.bedtimeTarget
        return existing
    }

    /// False when nothing was shown for that day or it is already done, so a
    /// redelivered wrist tap cannot move the time the person did it.
    @discardableResult
    static func markDone(_ kind: MoveKind, at: Date = Date(), day: Date = Date()) -> Bool {
        var history = loadHistory()
        let dayStart = Date.cal.startOfDay(for: day)
        guard let index = history.firstIndex(where: { $0.day == dayStart }) else { return false }
        let path = keyPath(for: kind)
        guard let move = history[index][keyPath: path], move.doneAt == nil else { return false }
        history[index][keyPath: path]?.doneAt = at
        persist(history)
        return true
    }

    static func entry(for day: Date) -> Entry? {
        let dayStart = Date.cal.startOfDay(for: day)
        return loadHistory().first { $0.day == dayStart }
    }

    static func yesterday(relativeTo now: Date = Date()) -> Entry? {
        guard let day = Date.cal.date(byAdding: .day, value: -1, to: now) else { return nil }
        return entry(for: day)
    }

    static func isDone(_ kind: MoveKind, on day: Date = Date()) -> Bool {
        entry(for: day)?[keyPath: keyPath(for: kind)]?.doneAt != nil
    }

    /// Everything still inside the retention window. Older days are dropped on
    /// read so the blob cannot grow forever.
    static func loadHistory() -> [Entry] {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        guard let cutoff = Date.cal.date(byAdding: .day, value: -DailyBriefConfig.moveLogRetentionDays,
                                         to: Date.cal.startOfDay(for: Date())) else { return history }
        return history.filter { $0.day >= cutoff }
    }

    static func clear() {
        defaults.removeObject(forKey: key)
        revision &+= 1
    }

    private static func keyPath(for kind: MoveKind) -> WritableKeyPath<Entry, Move?> {
        kind == .day ? \.dayMove : \.nightMove
    }

    private static func persist(_ history: [Entry]) {
        guard let data = try? JSONEncoder().encode(history) else {
            AnalyticsBackend.provider.captureError(
                "Failed to encode the daily move log",
                context: "daily_move_log_encode")
            return
        }
        defaults.set(data, forKey: key)
        revision &+= 1
    }
}
