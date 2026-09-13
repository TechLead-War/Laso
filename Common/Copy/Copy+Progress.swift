import Foundation

extension Copy {
    /// Every string on the Progress tab. Defaults are the approved reference
    /// strings from `LASO_DIRECTION_PROPOSAL.html`.
    enum Progress {
        static var title: String { RemoteConfigManager.shared.copyString("copy_progress_title", default: "Progress") }
        static var subtitle: String { RemoteConfigManager.shared.copyString("copy_progress_subtitle", default: "What you worked on, and whether it worked") }
        /// %@ is the focus start date, e.g. "8 Sep 2026".
        static func since(_ date: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_since", default: "since %@"), date)
        }
        static var pastFocuses: String { RemoteConfigManager.shared.copyString("copy_progress_past_focuses", default: "Past focuses") }
        static var changesSlowly: String { RemoteConfigManager.shared.copyString("copy_progress_changes_slowly", default: "Changes slowly") }
        static var achievements: String { RemoteConfigManager.shared.copyString("copy_progress_achievements", default: "Achievements") }
        static var emptyTitle: String { RemoteConfigManager.shared.copyString("copy_progress_empty_title", default: "No focus yet") }
        static var emptyMessage: String { RemoteConfigManager.shared.copyString("copy_progress_empty_message", default: "Laso starts a three-week focus from the first driver that is off your usual. Come back when Today shows one.") }

        // MARK: - Vitality row

        static func vitalityRow(_ age: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_vitality_row", default: "Vitality age %d"), age)
        }
        static func vitalityYouAre(_ age: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_vitality_you_are", default: "you are %d"), age)
        }
        static func vitalityPace(_ text: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_vitality_pace", default: "%@"), text)
        }
        /// %d is `VitalityScorer.minimumPaceDays`; %@ is the first day of next month, e.g. "1 October".
        static func vitalityNeedsHistory(days: Int, nextCheck: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_vitality_needs_history", default: "Needs %d days of history to show a pace. Next check %@."), days, nextCheck)
        }

        // MARK: - Focus rows

        static func dateRange(_ from: String, _ to: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_date_range", default: "%@ to %@"), from, to)
        }
        /// KPI label, day-1 value, latest value, e.g. "deep sleep 48 min → 66 min".
        static func outcomeLine(_ kind: String, _ from: String, _ to: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_outcome_line", default: "%@ %@ → %@"), kind, from, to)
        }
        static func driverLineBounceBack(_ from: String, _ to: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_progress_driver_line_bounce_back", default: "Heart rate bounce-back %@ → %@. Moving back toward usual."), from, to)
        }
    }
}
