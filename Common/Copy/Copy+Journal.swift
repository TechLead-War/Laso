import Foundation

extension Copy {
    enum Journal {

        // MARK: - Correlation Narratives

        enum Correlation {
            static func caffeineSleep(cups: String, metric: String, percent: String, days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_caffeine_sleep", default: "When you have %@+ cups of coffee, your %@ drops %@%%. Based on %d days of your data."), cups, metric, percent, days)
            }
            static func caffeineGeneric(cups: String, percent: String, direction: String, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_caffeine_generic", default: "Days with %@+ cups of caffeine show %@%% %@ %@ the next day."), cups, percent, direction, metric)
            }
            static func alcoholSleep(drinks: String, metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_alcohol_sleep", default: "Nights with %@+ drinks reduce your %@ by %@%%. Your body needs alcohol-free evenings for quality sleep."), drinks, metric, percent)
            }
            static func alcoholGeneric(drinks: String, metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_alcohol_generic", default: "%@+ drinks impact your next-day %@ by %@%%."), drinks, metric, percent)
            }
            static func stressImpact(level: String, metric: String, percent: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_stress_impact", default: "When your stress is %@+ out of 10, your %@ is %@%% %@. Stress management directly impacts your recovery."), level, metric, percent, direction)
            }
            static func meditationImpact(mins: String, metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_meditation_impact", default: "%@+ minutes of meditation boosts your %@ by %@%%. Consistency matters more than duration."), mins, metric, percent)
            }
            static func screenTimeImpact(hrs: String, percent: String, direction: String, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_screen_time_impact", default: "Days with %@+ hrs of screen time show %@%% %@ %@. Consider a screen curfew before bed."), hrs, percent, direction, metric)
            }
            static func mealTimingImpact(hrs: String, metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_meal_timing_impact", default: "Eating %@+ hrs before bed improves your %@ by %@%%. Earlier dinners support better sleep."), hrs, metric, percent)
            }
            static func waterImpact(glasses: String, percent: String, direction: String, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_water_impact", default: "Drinking %@+ glasses of water leads to %@%% %@ %@ the next day."), glasses, percent, direction, metric)
            }
            static func moodImpact(rating: String, metric: String, percent: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_mood_impact", default: "On days when your mood is %@+, your %@ averages %@%% %@."), rating, metric, percent, direction)
            }
            static func supplementsImpact(percent: String, direction: String, metric: String, observations: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_journal_journal_correlation_supplements_impact", default: "Days with supplements show %@%% %@ next-day %@. Based on %d observations."), percent, direction, metric, observations)
            }
        }

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

        static var dailyCheckInTitle: String { RemoteConfigManager.shared.copyString("copy_journal_daily_check_in_title", default: "Daily Check-in") }
        static var logEntryTitle: String { RemoteConfigManager.shared.copyString("copy_journal_log_entry_title", default: "Log Entry") }
        static var whatToLog: String { RemoteConfigManager.shared.copyString("copy_journal_what_to_log", default: "What would you like to log?") }
        static var amount: String { RemoteConfigManager.shared.copyString("copy_journal_amount", default: "Amount") }
        static var notes: String { RemoteConfigManager.shared.copyString("copy_journal_notes", default: "Notes") }
        static var logged: String { RemoteConfigManager.shared.copyString("copy_journal_logged", default: "Logged") }
        static func logCount(_ count: Int) -> String {
            let unit = count == 1
                ? RemoteConfigManager.shared.copyString("copy_journal_behavior_singular_caps", default: "Behavior")
                : RemoteConfigManager.shared.copyString("copy_journal_behavior_plural_caps", default: "Behaviors")
            return String(format: RemoteConfigManager.shared.copyString("copy_journal_log_count", default: "Log %d %@"), count, unit)
        }
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
        static var savesTheSelectedBehaviorsAndDismissesHint: String { RemoteConfigManager.shared.copyString("copy_journal_saves_the_selected_behaviors_and_dismisses_hint", default: "Saves the selected behaviors and dismisses this sheet") }
        static var adjustTheAmountYouLoggedHint: String { RemoteConfigManager.shared.copyString("copy_journal_adjust_the_amount_you_logged_hint", default: "Adjust the amount you logged") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_x_text", default: "%d"), p0) }
        static func valueWithUnitText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_value_with_unit_text", default: "%@ %@"), p0, p1) }
        static func toggleToLogOrUnlogHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_toggle_to_log_or_unlog_hint", default: "Toggle to log or unlog %@ today"), p0) }
        static func decreaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decrease_label", default: "Decrease %@"), p0) }
        static func decreasesTheLoggedAmountByHint(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decreases_the_logged_amount_by_hint", default: "Decreases the logged amount by %@ %@"), p0, p1) }
        static func increaseLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increase_label", default: "Increase %@"), p0) }
        static func increasesTheLoggedAmountByHint(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increases_the_logged_amount_by_hint", default: "Increases the logged amount by %@ %@"), p0, p1) }
        static func ratingOfLabel(_ p0: String, _ p1: Int, _ p2: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_rating_of_label", default: "%@ rating %d of %d"), p0, p1, p2) }
        static func selectsRatingOutOfHint(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_selects_rating_out_of_hint", default: "Selects rating %d out of %d"), p0, p1) }
        static func daysText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_days_text", default: "%d days"), p0) }
        static func affectsLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_affects_label", default: "%@ affects %@"), p0, p1) }
        static func correlationDaysOfDataValue(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_correlation_days_of_data_value", default: "%@ correlation, %d days of data"), p0, p1) }
        static func decreasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_decreases_the_value_by_hint", default: "Decreases the value by %g %@"), p0, p1) }
        static func increasesTheValueByHint(_ p0: Double, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_increases_the_value_by_hint", default: "Increases the value by %g %@"), p0, p1) }
        static func amountLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_amount_label", default: "%@ amount"), p0) }
        static func xValue(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_journal_x_value", default: "%@ %@"), p0, p1) }
    }
}
