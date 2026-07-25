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

    /// Marks today's action done and records the baseline tomorrow morning compares
    /// against.
    ///
    /// The baseline is not passed in: it is today's morning lock, which
    /// `DailyActionResultStore` reads for itself. A caller with no live score on
    /// screen, such as the wrist before the first sync of the day, used to hand over
    /// a zero here, and tomorrow reported the whole score as the gain.
    ///
    /// Returns false when today was already marked, in which case nothing is
    /// written. A mark cannot be undone; it resets on the next calendar day.
    @discardableResult
    static func markDone(
        actionTitle: String,
        actionIcon: String,
        source: String
    ) -> Bool {
        guard !isDoneToday else { return false }

        defaults.set(Date(), forKey: AppKeys.Data.dailyActionDoneDay)
        DailyActionResultStore.save(actionTitle: actionTitle, actionIcon: actionIcon)
        AppAnalytics.shared.trackBlockTap(
            title: actionTitle,
            type: .homeDailyAction,
            screen: .home,
            metadata: ["source": source, "done": "true"]
        )
        return true
    }
}
