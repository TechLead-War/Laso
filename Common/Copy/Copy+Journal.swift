import Foundation

extension Copy {
    enum Journal {

        // MARK: - Journal Insights

        enum Insights {
            static var title: String { RemoteConfigManager.shared.copyString("copy_journal_insights_title", default: "Journal Insights") }
            static var topDiscoveries: String { RemoteConfigManager.shared.copyString("copy_journal_insights_top_discoveries", default: "Your Top Discoveries") }
            static var topDiscoveriesSubtitle: String { RemoteConfigManager.shared.copyString("copy_journal_insights_top_discoveries_subtitle", default: "Patterns we found in your journal entries and health data") }
            static var insightsUnlocking: String { RemoteConfigManager.shared.copyString("copy_journal_insights_insights_unlocking", default: "Insights Unlocking...") }
            static var emptyStateDescription: String { RemoteConfigManager.shared.copyString("copy_journal_insights_empty_state_description", default: "Log 14 or more days of journal entries to see how your habits affect your health. The more you log, the more patterns we can find.") }
            static var startLogging: String { RemoteConfigManager.shared.copyString("copy_journal_insights_start_logging", default: "Start logging to see connections") }
        }

        // MARK: - Daily Check-in

        static var logEntryTitle: String { RemoteConfigManager.shared.copyString("copy_journal_log_entry_title", default: "Log Entry") }
        static var whatToLog: String { RemoteConfigManager.shared.copyString("copy_journal_what_to_log", default: "What would you like to log?") }
        static var amount: String { RemoteConfigManager.shared.copyString("copy_journal_amount", default: "Amount") }
        static var notes: String { RemoteConfigManager.shared.copyString("copy_journal_notes", default: "Notes") }
        static var notesPlaceholder: String { RemoteConfigManager.shared.copyString("copy_journal_notes_placeholder", default: "Optional notes...") }
        static var logged: String { RemoteConfigManager.shared.copyString("copy_journal_logged", default: "Logged") }
        static func loggedCount(_ count: Int) -> String {
            let unit = count == 1
                ? RemoteConfigManager.shared.copyString("copy_journal_behavior_singular", default: "behavior")
                : RemoteConfigManager.shared.copyString("copy_journal_behavior_plural", default: "behaviors")
            return String(format: RemoteConfigManager.shared.copyString("copy_journal_logged_count", default: "Logged %d %@"), count, unit)
        }
        static func logEntry(displayName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_journal_log_entry", default: "Log %@"), displayName)
        }

        // MARK: - Correlation Strength

        static var correlationStrong: String { RemoteConfigManager.shared.copyString("copy_journal_correlation_strong", default: "Strong") }
        static var correlationModerate: String { RemoteConfigManager.shared.copyString("copy_journal_correlation_moderate", default: "Moderate") }
        static var correlationMild: String { RemoteConfigManager.shared.copyString("copy_journal_correlation_mild", default: "Mild") }

        // MARK: - Lifted view literals
        static var adjustTheAmountYouLoggedHint: String { RemoteConfigManager.shared.copyString("copy_journal_adjust_the_amount_you_logged_hint", default: "Adjust the amount you logged") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_x_text", default: "%d"), p0) }
        static func valueWithUnitText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_value_with_unit_text", default: "%@ %@"), p0, p1) }
        static func decreaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decrease_label", default: "Decrease %@"), p0) }
        static func increaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increase_label", default: "Increase %@"), p0) }
        static func daysText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_days_text", default: "%d days"), p0) }
        static func affectsLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_affects_label", default: "%@ affects %@"), p0, p1) }
        static func decreasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decreases_the_value_by_hint", default: "Decreases the value by %g %@"), p0, p1) }
        static func increasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increases_the_value_by_hint", default: "Increases the value by %g %@"), p0, p1) }
        static func amountLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_amount_label", default: "%@ amount"), p0) }
        static func xValue(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_x_value", default: "%@ %@"), p0, p1) }
    }
}
