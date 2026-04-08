import Foundation

extension Copy {
    enum Insights {

        // MARK: - Inflection Notes

        static let accelerating = " The rate of change is accelerating."
        static let decelerating = " The decline is slowing. A recovery may be starting."
        static let reversing = " The trend has recently reversed direction."

        // MARK: - Inflection Suffixes (for titles)

        static let andAccelerating = " & Accelerating"
        static let slowing = " (Slowing)"
        static let dashReversing = " (Reversing)"
        static let andGainingMomentum = " & Gaining Momentum"

        // MARK: - Title Patterns

        static func criticallyLow(_ metric: String, suffix: String) -> String {
            "\(metric) Critically Low\(suffix)"
        }
        static func needsAttention(_ metric: String, prefix: String, suffix: String) -> String {
            "\(metric) \(prefix)Needs Attention\(suffix)"
        }
        static func declining(_ metric: String, prefix: String, suffix: String) -> String {
            "\(metric) \(prefix)Declining\(suffix)"
        }
        static func improving(_ metric: String, prefix: String, momentum: String) -> String {
            "\(metric) \(prefix)Improving\(momentum)"
        }
        static func outsideSafeRange(_ metric: String) -> String {
            "\(metric) Outside Safe Range"
        }
        static func elevated(_ metric: String) -> String {
            "\(metric) Elevated"
        }
        static func stable(_ metric: String) -> String {
            "\(metric) Stable"
        }

        // MARK: - Follow-Up Sentences

        static let recheckIn48Hours = "Follow-up: recheck in 48 hours to confirm this is stabilizing before it reaches warning range."
        static let reviewIn3Days = "Follow-up: review this trend again in 3 days to verify the direction has improved."

        // MARK: - Lead Time Labels

        static let sameDaySignal = "same-day signal"
        static let nextDaySignal = "next-day signal"
        static func dayLeadSignal(_ days: Int) -> String { "\(days)-day lead signal" }

        // MARK: - Evidence Labels

        static let evidenceHigh = "high"
        static let evidenceMedium = "medium"
        static let evidenceEarly = "early"

        // MARK: - Projection

        static func projectedWarning(days: Int) -> String {
            " At the current rate, this could reach warning level in ~\(days) days."
        }

        // MARK: - Historical Context

        static func yoyChange(direction: String, percent: String) -> String {
            "\(direction) \(percent)% vs this time last year"
        }
        static func percentileLabel(label: String) -> String {
            "in the \(label) of your history"
        }
        static func seasonalDeviation(direction: String, month: String, percent: String) -> String {
            "\(direction) your typical \(month) by \(percent)%"
        }

        // MARK: - Causal Hints

        static let causalHintHRV = "Based on your history, this level typically follows nights with less than 6 hours of sleep."
        static let causalHintRHR = "Based on your history, elevated resting heart rate often follows periods of reduced sleep or high stress."
        static let causalHintBloodOxygen = "Based on your history, lower blood oxygen typically correlates with disrupted sleep patterns."
        static let causalHintSleepDuration = "Based on your history, shorter sleep often follows days with low physical activity or late exercise."
        static let causalHintSleepDeep = "Based on your history, deep sleep decreases often correlate with higher stress or inconsistent bedtimes."
        static let causalHintVO2Max = "Based on your history, VO2 Max changes tend to follow shifts in exercise consistency over 2-4 weeks."
        static let causalHintActiveCalories = "Based on your history, lower calorie burn typically follows reduced step count and exercise minutes."
        static let causalHintExercise = "Based on your history, exercise dips often cluster with disrupted sleep patterns."
        static let causalHintBodyTemp = "Based on your history, temperature shifts often accompany changes in sleep duration and HRV."
        static let causalHintRespiratoryRate = "Based on your history, respiratory rate changes often track with sleep quality and stress levels."

        // MARK: - Action Protocol Strings

        static func sleepMetricsOff(dev: Int) -> String {
            "your sleep metrics are \(dev)% off your baseline"
        }
        static func activityDeviation(dev: Int, direction: String) -> String {
            "your activity is \(dev)% \(direction) your recent average"
        }
        static func hrvTrending(direction: String, dev: Int) -> String {
            "your HRV is trending \(direction), \(dev)% from baseline"
        }
        static func rhrShifted(dev: Int) -> String {
            "your resting heart rate shifted \(dev)% from baseline"
        }
        static func mindfulnessDeviation(dev: Int, direction: String) -> String {
            "your mindfulness time is \(dev)% \(direction) your average"
        }
        static func daylightDeviation(dev: Int, direction: String) -> String {
            "your daylight exposure is \(dev)% \(direction) your average"
        }
        static let bpOutsideRange = "your blood pressure reading is outside your typical range"
        static let recheckSingleReading = "recheck to confirm, since single readings can vary"
        static let readingOutsideRange = "this reading is outside your typical range. Monitor for changes."
        static let recheckMetricTrend = "recheck this metric to confirm the trend"
        static func bodyMetricsShifted(dev: Int) -> String {
            "your body metrics shifted \(dev)% from baseline"
        }
        static func vo2MaxTrending(direction: String, dev: Int) -> String {
            "your VO2 max is trending \(direction), \(dev)% from baseline"
        }
        static func mobilityMetricsOff(dev: Int) -> String {
            "your mobility metrics are \(dev)% off baseline"
        }
        static func genericMetricDeviation(metricName: String, dev: Int) -> String {
            "your \(metricName) is \(dev)% from your baseline"
        }
    }
}
