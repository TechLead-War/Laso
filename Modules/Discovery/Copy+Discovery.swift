import Foundation

extension Copy {
    enum Discovery {

        // MARK: - Engine Templates

        static func conditionalHeadline(effect: String, direction: String, diff: String, unit: String, thresholdLabel: String) -> String {
            "Your \(effect) \(direction) by \(diff) \(unit) when \(thresholdLabel)"
        }
        static func evidenceMonths(days: Int, months: Int) -> String {
            "Based on \(days) days over \(months) month\(months == 1 ? "" : "s")"
        }
        static func ladderHeadline(causeFormatted: String, causeUnit: String, effect: String, direction: String, diff: String, effectUnit: String) -> String {
            "The magic number is \(causeFormatted) \(causeUnit). Your \(effect) \(direction) by \(diff) \(effectUnit) past that point"
        }
        static func ladderDetail(causeFormatted: String, causeUnit: String, effect: String) -> String {
            "Below \(causeFormatted) \(causeUnit), your \(effect) stays flat. Above it, there's a clear jump."
        }
        static func evidenceDataPoints(samples: Int, periodLabel: String) -> String {
            "Based on \(samples) data points over \(periodLabel)"
        }
        static func quietShiftHeadline(metric: String, direction: String, percent: String, periodLabel: String) -> String {
            "Your \(metric) has quietly \(direction) \(percent)% over the \(periodLabel)"
        }
        static func quietShiftDetail(absoluteDetail: String) -> String {
            "This is a gradual shift you might not notice day to day\(absoluteDetail)."
        }
        static func bracketHeadline(metric: String, bracket: String) -> String {
            "Your \(metric) this month is in your \(bracket) of all time"
        }
        static func bracketDetailExceptional(metric: String) -> String {
            "This is an exceptional period for your \(metric). Keep doing what you're doing."
        }
        static func bracketDetailUnusual(metric: String) -> String {
            "Your \(metric) is at an unusual level. Worth paying attention to."
        }
        static func compoundHeadline(condA: String, condB: String, outcome: String, percent: String, direction: String) -> String {
            "When you \(condA) AND \(condB), your \(outcome) is \(percent)% \(direction)"
        }
        static func compoundDetail(outcome: String, bothFormatted: String, neitherFormatted: String, unit: String) -> String {
            "The combination matters more than either habit alone. On days you do both, \(outcome) averages \(bothFormatted) \(unit) vs \(neitherFormatted) \(unit)."
        }
        static func averageEffectDetail(effect: String, aboveFormatted: String, belowFormatted: String, unit: String) -> String {
            "Average \(effect): \(aboveFormatted) \(unit) (with) vs \(belowFormatted) \(unit) (without)."
        }
        static func consistentDayDetail(topDayName: String, metric: String) -> String {
            "Your weekly pattern is consistent. \(topDayName)s tend to be your strongest day for \(metric)."
        }

        // MARK: - Opening Page

        static let openingTitle = "We looked at your health history"
        static let openingHere = "Here is what we found."
        static let openingSwipeHint = "Swipe to explore"
        static let labelOfHealthData = "of health data"
        static let labelDataPoints = "data points"
        static let labelHealthMetrics = "health metrics"

        // MARK: - CTA Page

        static let ctaTitle = "Your Dashboard is Ready"
        static let ctaSubtitle = "Track these patterns and more. Updated every time you open the app."
        static let ctaContinue = "Continue"

        // MARK: - Accessibility

        static let continueToDashboard = "Continue to dashboard"

        // MARK: - Soft Variants (legacy literal text used in DiscoveryView)

        static let analyzedHistory = "We analyzed your health history"
        static let hereWhatWeFound = "Here is what we found"
        static let swipeToExplore = "Swipe to explore"
        static let trackPatterns = "Track these patterns and more..."
    }
}
