import Foundation

extension Copy {
    enum Policy {

        // MARK: - Prescriptive Headlines (Excellent)

        static let excellentHeadlines = [
            "Recovery metrics are well above baseline",
            "All key metrics recovered. Above baseline across the board.",
            "Full recovery. Metrics are in the green.",
            "Recovery metrics at their strongest this week"
        ]

        // MARK: - Prescriptive Headlines (Good)

        static let goodHeadlines = [
            "Recovery metrics are above baseline",
            "Metrics bounced back. Sitting above baseline.",
            "Good recovery signal. Most metrics above baseline.",
            "Recovery metrics trending positive"
        ]

        // MARK: - Prescriptive Headlines (Moderate)

        static let moderateHeadlines = [
            "Recovery metrics are near baseline",
            "Metrics are mixed. Some above, some below baseline.",
            "Moderate recovery. Metrics hovering around baseline.",
            "Recovery metrics are partially restored"
        ]

        // MARK: - Prescriptive Headlines (Poor)

        static let poorHeadlines = [
            "Recovery numbers are below your usual",
            "Several numbers sitting below your usual",
            "Recovery is low. Numbers are off from normal.",
            "A few numbers are below your normal range"
        ]

        // MARK: - Prescriptive Headlines (Depleted)

        static let depletedHeadlines = [
            "Recovery numbers are well below your usual",
            "Numbers show a big drop. Well below normal.",
            "Several numbers at their lowest this week",
            "Low recovery across all key numbers"
        ]

        // MARK: - Strain Budget

        static let highIntensityOK = "High intensity OK"
        static let moderateEffort = "Moderate effort recommended"
        static let lightActivityOnly = "Light activity only"

        // MARK: - Source Descriptions

        static let sourcePredictive = "wellness trend analysis"
        static let sourceCausal = "pattern analysis"
        static let sourceCircadian = "circadian rhythm analysis"
        static let sourceState = "health state analysis"
        static let sourceAnomaly = "pattern change notification"
        static let sourceTrend = "trend analysis"
        static let sourceBaseline = "baseline comparison"
        static let sourceCounterfactual = "what-if analysis"

        // MARK: - Time to Benefit

        static let benefitImmediate = "the same day"
        static let benefitNextDay = "tomorrow"
        static let benefitTwoDays = "2 days"
        static let benefitThreeDays = "3 days"
        static let benefitOneWeek = "about a week"
        static let benefitTwoWeeks = "about 2 weeks"

        // MARK: - Timeframe Labels (for generateExpectedBenefit)

        static let timeframeToday = "today"
        static let timeframeByTomorrow = "by tomorrow"
        static let timeframeWithin2Days = "within 2 days"
        static let timeframeWithin3Days = "within 3 days"
        static let timeframeOverNextWeek = "over the next week"
        static let timeframeOver2Weeks = "over the next 2 weeks"
    }
}
