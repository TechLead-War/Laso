import Foundation

extension Copy {
    enum Journal {

        // MARK: - Daily Check-in

        static var logEntryTitle: String { RemoteConfigManager.shared.copyString("copy_journal_log_entry_title", default: "Log Entry") }
        static var whatToLog: String { RemoteConfigManager.shared.copyString("copy_journal_what_to_log", default: "What would you like to log?") }
        static var amount: String { RemoteConfigManager.shared.copyString("copy_journal_amount", default: "Amount") }
        static var notes: String { RemoteConfigManager.shared.copyString("copy_journal_notes", default: "Notes") }
        static var notesPlaceholder: String { RemoteConfigManager.shared.copyString("copy_journal_notes_placeholder", default: "Optional notes...") }
        static var logged: String { RemoteConfigManager.shared.copyString("copy_journal_logged", default: "Logged") }
        static func logEntry(displayName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_journal_log_entry", default: "Log %@"), displayName)
        }

        // MARK: - Lifted view literals
        static var adjustTheAmountYouLoggedHint: String { RemoteConfigManager.shared.copyString("copy_journal_adjust_the_amount_you_logged_hint", default: "Adjust the amount you logged") }

        // MARK: - Lifted interpolated view literals
        static func valueWithUnitText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_value_with_unit_text", default: "%@ %@"), p0, p1) }
        static func decreaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decrease_label", default: "Decrease %@"), p0) }
        static func increaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increase_label", default: "Increase %@"), p0) }
        static func decreasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decreases_the_value_by_hint", default: "Decreases the value by %g %@"), p0, p1) }
        static func increasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increases_the_value_by_hint", default: "Increases the value by %g %@"), p0, p1) }
        static func amountLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_amount_label", default: "%@ amount"), p0) }
        static func xValue(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_x_value", default: "%@ %@"), p0, p1) }
    }
}
