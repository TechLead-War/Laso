import Foundation

extension Copy {
    enum Policy {

        // MARK: - Prescriptive Headlines (Excellent)

        static let excellentHeadlines = [
            "Recovery metrics are well above baseline",
            "All key metrics recovered -- above baseline across the board",
            "Full recovery -- metrics are in the green",
            "Recovery metrics at their strongest this week"
        ]

        // MARK: - Prescriptive Headlines (Good)

        static let goodHeadlines = [
            "Recovery metrics are above baseline",
            "Metrics bounced back -- sitting above baseline",
            "Good recovery signal -- most metrics above baseline",
            "Recovery metrics trending positive"
        ]

        // MARK: - Prescriptive Headlines (Moderate)

        static let moderateHeadlines = [
            "Recovery metrics are near baseline",
            "Metrics are mixed -- some above, some below baseline",
            "Moderate recovery -- metrics hovering around baseline",
            "Recovery metrics are partially restored"
        ]

        // MARK: - Prescriptive Headlines (Poor)

        static let poorHeadlines = [
            "Recovery metrics are below baseline",
            "Multiple metrics sitting below baseline",
            "Recovery is low -- metrics are off baseline",
            "Several metrics are below your normal range"
        ]

        // MARK: - Prescriptive Headlines (Depleted)

        static let depletedHeadlines = [
            "Recovery metrics are significantly below baseline",
            "Metrics show deep deficit -- well below baseline",
            "Multiple metrics at their lowest this week",
            "Low recovery signal across all key metrics"
        ]

        // MARK: - Strain Budget

        static let highIntensityOK = "High intensity OK"
        static let moderateEffort = "Moderate effort recommended"
        static let lightActivityOnly = "Light activity only"

        // MARK: - Source Descriptions

        static let sourcePredictive = "predictive model (GBT risk scorer)"
        static let sourceCausal = "Granger causal analysis"
        static let sourceCircadian = "circadian rhythm analysis"
        static let sourceState = "health state classification"
        static let sourceAnomaly = "anomaly detection"
        static let sourceTrend = "trend analysis"
        static let sourceBaseline = "baseline deviation detection"
        static let sourceCounterfactual = "counterfactual simulation"

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
