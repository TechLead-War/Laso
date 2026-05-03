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

        static let sourcePredictive = "trend signal"
        static let sourceCausal = "pattern signal"
        static let sourceCircadian = "body clock signal"
        static let sourceState = "today's snapshot"
        static let sourceAnomaly = "change alert"
        static let sourceTrend = "trend signal"
        static let sourceBaseline = "compared to your usual"
        static let sourceCounterfactual = "what-if check"

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

        // MARK: - Decision Engine Reasoning

        static let effectStrong = "strong"
        static let effectNotable = "notable"
        static let effectMeasurable = "measurable"
        static let rateRapidly = "rapidly"
        static let rateSteadily = "steadily"
        static let rateGradually = "gradually"
        static let rateSlightly = "slightly"

        static func predictiveWithFactor(prob: Int, factorMetric: String) -> String {
            "Your risk score for tomorrow is elevated (\(prob)% model confidence). The #1 driver is your \(factorMetric). this action directly targets it."
        }
        static func predictiveDefault(prob: Int) -> String {
            "Your risk score for tomorrow is elevated (\(prob)% confidence). This targets the top risk factor."
        }
        static func causalWithLag(effectLabel: String, metric: String, lag: Int) -> String {
            "Your data shows a \(effectLabel) causal link: changes in \(metric) predict downstream health changes \(lag) day\(lag == 1 ? "" : "s") later. This isn't just correlation. it's a directional cause."
        }
        static func causalDefault(metric: String, effectLabel: String) -> String {
            "Causal analysis identified \(metric) as a \(effectLabel) upstream driver of your overall health."
        }
        static func stateTransition(days: Int, metricName: String) -> String {
            "Your body has been in its current state for \(days) days. \(metricName) is the key metric differentiating this state from a healthier one. improving it accelerates the transition."
        }
        static func anomalyWithDeviation(metric: String, devPct: Int) -> String {
            "Your \(metric) is \(devPct)% outside your normal range. Unusual readings that persist can affect sleep, recovery, and next-day performance."
        }
        static func anomalyDefault(metric: String) -> String {
            "An unusual reading in \(metric) was detected. Addressing it early prevents cascading effects."
        }
        static func trendDeclining(metric: String, rate: String, wowPct: Int) -> String {
            "Your \(metric) has been \(rate) declining (\(wowPct)% per week). Early intervention requires far less effort than reversing a deep decline."
        }
        static let trendDecliningDefault = "Stopping a negative trend early requires less effort than reversing a well-established decline."
        static func circadianTiming(metric: String) -> String {
            "Your biological rhythms make this window 2-3x more effective for \(metric) improvement. Working with your circadian clock, not against it."
        }
        static func baselineRecovery(gap: String, unit: String, baseline: String) -> String {
            "You're \(gap) \(unit) below your personal baseline. Your body performs best near \(baseline) \(unit). closing this gap yields the biggest payoff right now."
        }
        static let baselineRecoveryDefault = "Being below your personal baseline means your body isn't operating at its best. Returning to baseline is the highest-ROI action right now."
        static func counterfactualWithDelta(delta: Int) -> String {
            "Simulated scenario: making this change could shift your overall score by \(delta) points tomorrow. the largest single-action impact available."
        }
        static let counterfactualDefault = "Scenario analysis shows this is the single change most likely to improve your overall score tomorrow."
    }
}
