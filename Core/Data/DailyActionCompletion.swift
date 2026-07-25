import Foundation

/// Single place where today's action is marked done.
///
/// The Home button and the wrist button both route here. The already-done guard
/// lives inside `markDone` rather than in either caller, because the caller-side
/// guard on Home is view state: a wrist tap after a phone tap would otherwise
/// overwrite the recorded baseline score and break tomorrow's result card.
@MainActor
enum DailyActionCompletion {

    private static let defaults = UserDefaults.standard

    /// Whether today's action has already been marked done.
    static var isDoneToday: Bool {
        guard let stored = defaults.object(forKey: AppKeys.Data.dailyActionDoneDay) as? Date else {
            return false
        }
        return Date.cal.isDateInToday(stored)
    }

    /// Marks today's action done and records the score it was done at, so tomorrow
    /// morning can report whether the score moved.
    ///
    /// Returns false when today was already marked, in which case nothing is
    /// written. A mark cannot be undone; it resets on the next calendar day.
    @discardableResult
    static func markDone(
        actionTitle: String,
        actionIcon: String,
        score: Int,
        source: String
    ) -> Bool {
        guard !isDoneToday else { return false }

        defaults.set(Date(), forKey: AppKeys.Data.dailyActionDoneDay)
        DailyActionResultStore.save(actionTitle: actionTitle, actionIcon: actionIcon, score: score)
        AppAnalytics.shared.trackBlockTap(
            title: actionTitle,
            type: .homeDailyAction,
            screen: .home,
            metadata: ["source": source, "done": "true"]
        )
        return true
    }
}
