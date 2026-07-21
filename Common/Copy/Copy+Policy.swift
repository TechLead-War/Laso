import Foundation

extension Copy {
    enum Policy {

        // MARK: - Prescriptive Headlines (Excellent)

        static let excellentHeadlines = [
            "Recovery numbers are well above your usual",
            "All key numbers bounced back. Above your usual across the board.",
            "Fully recovered. Numbers are in the green.",
            "Recovery numbers at their strongest this week"
        ]

        // MARK: - Prescriptive Headlines (Good)

        static let goodHeadlines = [
            "Recovery numbers are above your usual",
            "Numbers bounced back. Sitting above your usual.",
            "Good recovery. Most numbers above your usual.",
            "Recovery numbers are heading up"
        ]

        // MARK: - Prescriptive Headlines (Moderate)

        static let moderateHeadlines = [
            "Recovery numbers are near your usual",
            "Numbers are mixed. Some above, some below your usual.",
            "So-so recovery. Numbers are hovering around your usual.",
            "Recovery numbers are partly back"
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

        static var highIntensityOK: String { RemoteConfigManager.shared.copyString("copy_policy_policy_high_intensity_ok", default: "A hard workout is fine") }
        static var moderateEffort: String { RemoteConfigManager.shared.copyString("copy_policy_policy_moderate_effort", default: "Aim for medium effort") }
        static var lightActivityOnly: String { RemoteConfigManager.shared.copyString("copy_policy_policy_light_activity_only", default: "Keep it light today") }

        // MARK: - Source Descriptions

        static var sourcePredictive: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_predictive", default: "trend signal") }
        static var sourceCausal: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_causal", default: "pattern signal") }
        static var sourceCircadian: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_circadian", default: "body clock signal") }
        static var sourceState: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_state", default: "today's snapshot") }
        static var sourceAnomaly: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_anomaly", default: "change alert") }
        static var sourceTrend: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_trend", default: "trend signal") }
        static var sourceBaseline: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_baseline", default: "compared to your usual") }
        static var sourceCounterfactual: String { RemoteConfigManager.shared.copyString("copy_policy_policy_source_counterfactual", default: "what-if check") }

        // MARK: - Time to Benefit

        static var benefitImmediate: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_immediate", default: "the same day") }
        static var benefitNextDay: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_next_day", default: "tomorrow") }
        static var benefitTwoDays: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_two_days", default: "2 days") }
        static var benefitThreeDays: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_three_days", default: "3 days") }
        static var benefitOneWeek: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_one_week", default: "about a week") }
        static var benefitTwoWeeks: String { RemoteConfigManager.shared.copyString("copy_policy_policy_benefit_two_weeks", default: "about 2 weeks") }

        // MARK: - Timeframe Labels (for generateExpectedBenefit)

        static var timeframeToday: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_today", default: "today") }
        static var timeframeByTomorrow: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_by_tomorrow", default: "by tomorrow") }
        static var timeframeWithin2Days: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_within2_days", default: "within 2 days") }
        static var timeframeWithin3Days: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_within3_days", default: "within 3 days") }
        static var timeframeOverNextWeek: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_over_next_week", default: "over the next week") }
        static var timeframeOver2Weeks: String { RemoteConfigManager.shared.copyString("copy_policy_policy_timeframe_over2_weeks", default: "over the next 2 weeks") }

        // MARK: - Decision Engine Reasoning

        static var effectStrong: String { RemoteConfigManager.shared.copyString("copy_policy_policy_effect_strong", default: "strong") }
        static var effectNotable: String { RemoteConfigManager.shared.copyString("copy_policy_policy_effect_notable", default: "notable") }
        static var effectMeasurable: String { RemoteConfigManager.shared.copyString("copy_policy_policy_effect_measurable", default: "measurable") }
        static var rateRapidly: String { RemoteConfigManager.shared.copyString("copy_policy_policy_rate_rapidly", default: "rapidly") }
        static var rateSteadily: String { RemoteConfigManager.shared.copyString("copy_policy_policy_rate_steadily", default: "steadily") }
        static var rateGradually: String { RemoteConfigManager.shared.copyString("copy_policy_policy_rate_gradually", default: "gradually") }
        static var rateSlightly: String { RemoteConfigManager.shared.copyString("copy_policy_policy_rate_slightly", default: "slightly") }

        static func predictiveWithFactor(prob: Int, factorMetric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_policy_predictive_with_factor", default: "Your risk for tomorrow is higher than usual (%d%% sure). The biggest cause is your %@, and this step fixes it directly."), prob, factorMetric)
        }
        static func predictiveDefault(prob: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_policy_predictive_default", default: "Your risk for tomorrow is higher than usual (%d%% sure). This tackles the biggest cause."), prob)
        }
        static func causalWithLag(effectLabel: String, metric: String, lag: Int) -> String {
            let unit = lag == 1
                ? RemoteConfigManager.shared.copyString("copy_policy_causal_lag_day_singular", default: "day")
                : RemoteConfigManager.shared.copyString("copy_policy_causal_lag_day_plural", default: "days")
            return String(format: RemoteConfigManager.shared.copyString("copy_policy_causal_with_lag", default: "Your data shows a %@ link: changes in %@ lead to health changes %d %@ later. This isn't just a coincidence, it's a real cause."), effectLabel, metric, lag, unit)
        }
        static func causalDefault(metric: String, effectLabel: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_causal_default", default: "Your data points to %@ as a %@ cause of your overall health."), metric, effectLabel)
        }
        static func stateTransition(days: Int, metricName: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_state_transition", default: "Your body has been in this state for %d days. %@ is the main thing keeping you from a healthier one, so improving it speeds up the change."), days, metricName)
        }
        static func anomalyWithDeviation(metric: String, devPct: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_anomaly_with_deviation", default: "Your %@ is %d%% outside your normal range. Odd readings that stick around can hurt sleep, recovery, and how you feel the next day."), metric, devPct)
        }
        static func anomalyDefault(metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_anomaly_default", default: "We spotted an odd reading in %@. Handling it early stops it from spreading."), metric)
        }
        static func trendDeclining(metric: String, rate: String, wowPct: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_trend_declining", default: "Your %@ has been %@ dropping (%d%% a week). Acting early takes far less effort than turning around a big drop."), metric, rate, wowPct)
        }
        static var trendDecliningDefault: String { RemoteConfigManager.shared.copyString("copy_policy_trend_declining_default", default: "Stopping a slide early takes less effort than turning around a long, deep drop.") }
        static func circadianTiming(metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_circadian_timing", default: "Your body clock makes right now 2-3x better for improving %@. This works with your body clock, not against it."), metric)
        }
        static func baselineRecovery(gap: String, unit: String, baseline: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_baseline_recovery", default: "You're %@ %@ below your usual. Your body feels best near %@ %@, so closing this gap gives you the biggest win right now."), gap, unit, baseline, unit)
        }
        static var baselineRecoveryDefault: String { RemoteConfigManager.shared.copyString("copy_policy_baseline_recovery_default", default: "Being below your usual means your body isn't at its best. Getting back to your usual is the most worthwhile thing to do right now.") }
        static func counterfactualWithDelta(delta: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_policy_counterfactual_with_delta", default: "What-if check: making this change could move your overall score by %d points tomorrow. That's the biggest boost one step can give."), delta)
        }
        static var counterfactualDefault: String { RemoteConfigManager.shared.copyString("copy_policy_counterfactual_default", default: "A what-if check shows this is the one change most likely to lift your overall score tomorrow.") }
    }
}
