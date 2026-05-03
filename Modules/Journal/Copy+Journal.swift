import Foundation

extension Copy {
    enum Journal {

        // MARK: - Correlation Narratives

        enum Correlation {
            static func caffeineSleep(cups: String, metric: String, percent: String, days: Int) -> String {
                "When you have \(cups)+ cups of coffee, your \(metric) drops \(percent)%. Based on \(days) days of your data."
            }
            static func caffeineGeneric(cups: String, percent: String, direction: String, metric: String) -> String {
                "Days with \(cups)+ cups of caffeine show \(percent)% \(direction) \(metric) the next day."
            }
            static func alcoholSleep(drinks: String, metric: String, percent: String) -> String {
                "Nights with \(drinks)+ drinks reduce your \(metric) by \(percent)%. Your body needs alcohol-free evenings for quality sleep."
            }
            static func alcoholGeneric(drinks: String, metric: String, percent: String) -> String {
                "\(drinks)+ drinks impact your next-day \(metric) by \(percent)%."
            }
            static func stressImpact(level: String, metric: String, percent: String, direction: String) -> String {
                "When your stress is \(level)+ out of 10, your \(metric) is \(percent)% \(direction). Stress management directly impacts your recovery."
            }
            static func meditationImpact(mins: String, metric: String, percent: String) -> String {
                "\(mins)+ minutes of meditation boosts your \(metric) by \(percent)%. Consistency matters more than duration."
            }
            static func screenTimeImpact(hrs: String, percent: String, direction: String, metric: String) -> String {
                "Days with \(hrs)+ hrs of screen time show \(percent)% \(direction) \(metric). Consider a screen curfew before bed."
            }
            static func mealTimingImpact(hrs: String, metric: String, percent: String) -> String {
                "Eating \(hrs)+ hrs before bed improves your \(metric) by \(percent)%. Earlier dinners support better sleep."
            }
            static func waterImpact(glasses: String, percent: String, direction: String, metric: String) -> String {
                "Drinking \(glasses)+ glasses of water leads to \(percent)% \(direction) \(metric) the next day."
            }
            static func moodImpact(rating: String, metric: String, percent: String, direction: String) -> String {
                "On days when your mood is \(rating)+, your \(metric) averages \(percent)% \(direction)."
            }
            static func supplementsImpact(percent: String, direction: String, metric: String, observations: Int) -> String {
                "Days with supplements show \(percent)% \(direction) next-day \(metric). Based on \(observations) observations."
            }
        }

        // MARK: - Journal Insights

        enum Insights {
            static let title = "Journal Insights"
            static let topDiscoveries = "Your Top Discoveries"
            static let topDiscoveriesSubtitle = "Patterns we found in your journal entries and health data"
            static let insightsUnlocking = "Insights Unlocking..."
            static let emptyStateDescription = "Log 14 or more days of journal entries to see how your habits affect your health. The more you log, the more patterns we can find."
            static let startLogging = "Start logging to see connections"
        }

        // MARK: - Daily Check-in

        static let dailyCheckInTitle = "Daily Check-in"
        static let logEntryTitle = "Log Entry"
        static let whatToLog = "What would you like to log?"
        static let amount = "Amount"
        static let notes = "Notes"
        static let logged = "Logged"
        static func logCount(_ count: Int) -> String {
            "Log \(count) Behavior\(count == 1 ? "" : "s")"
        }
        static func loggedCount(_ count: Int) -> String {
            "Logged \(count) behavior\(count == 1 ? "" : "s")"
        }
        static func logEntry(displayName: String) -> String {
            "Log \(displayName)"
        }

        // MARK: - Correlation Strength

        static let correlationStrong = "Strong"
        static let correlationModerate = "Moderate"
        static let correlationMild = "Mild"
    }
}
