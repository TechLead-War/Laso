import Foundation

/// Remembers which master-streak milestones have already been offered for
/// sharing. A share card travels when it is attached to a moment the user just
/// crossed, so the offer fires at a milestone and then never again — a
/// permanent share button asks novelty to carry a daily habit.
enum StreakMilestoneStore {

    /// Threshold shares: the streak lengths people already say out loud. The
    /// floor matches `ShareTemplateGates.minMasterStreak`, below which the
    /// streak card is not even in the share tray, so offering it would open an
    /// empty sheet.
    static let milestones = [7, 14, 30, 60, 100]

    // Local key rather than `AppKeys.Data`, same as `PhoneWatchSession`. Stores
    // the highest milestone celebrated, so a plain Int is the whole state.
    private static let key = "healthpulse.streakMilestoneCelebrated"
    // UserDefaults serialises its own reads and writes and this store keeps no
    // state of its own, so a background streak recompute cannot corrupt a read.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    /// The milestone worth celebrating right now, or nil when there is none.
    /// A fresh install that syncs a year of history qualifies for every
    /// milestone at once, so only the highest one crossed is returned and
    /// `markCelebrated` retires the lower ones along with it.
    static func pending(streak: Int) -> Int? {
        guard let highest = milestones.last(where: { $0 <= streak }) else { return nil }
        return highest > defaults.integer(forKey: key) ? highest : nil
    }

    static func markCelebrated(_ milestone: Int) {
        defaults.set(milestone, forKey: key)
    }
}
