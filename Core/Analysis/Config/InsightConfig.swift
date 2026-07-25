import Foundation

/// Evidence bars shared by the onboarding verdict engine and the dashboard
/// analyzers. Both surfaces must judge "is this pattern real" against the
/// same thresholds, otherwise a claim confirmed during onboarding could be
/// contradicted by the dashboard a day later.
enum InsightConfig {

    // MARK: - Group-difference claims (weekday patterns)

    enum GroupDifference {
        /// Minimum day-level samples before any weekday comparison runs.
        /// 14 days = two full weeks, the floor for every weekday to appear twice.
        static let minSamples = 14
        /// Distinct weekdays that must have data. Below 5, the "rest of the
        /// week" baseline is mostly missing and the comparison is unanchored.
        static let minWeekdaysCovered = 5
        /// Samples each covered weekday needs. One observation per weekday is
        /// an anecdote, not a group.
        static let minSamplesPerWeekday = 2
        /// Smallest sleep-duration gap worth telling a user about. 20 minutes
        /// is the lower edge of a self-noticeable nightly change; below it the
        /// difference is real but experientially meaningless.
        static let sleepFloorMinutes = 20.0
        /// Smallest HRV gap, as percent of the personal mean. Day-to-day HRV
        /// noise is large, so 5 percent of own baseline is the floor where a
        /// dip is signal rather than noise.
        static let hrvFloorPercent = 5.0
        /// Smallest resting-heart-rate gap. RHR is stable day to day, so a
        /// 2 bpm shift against the personal mean is meaningful.
        static let rhrFloorBpm = 2.0
        /// The effect direction must hold in more than half of covered weeks,
        /// so a single bad week cannot manufacture a "pattern".
        static let requireMajorityWeeksConsistency = true
    }

    // MARK: - Refutation (evidence of absence, both claim types)

    enum Refutation {
        /// Days of observed data required before "no effect" can be claimed.
        /// 21 days = three full weeks, every weekday seen three times.
        static let refuteDensityDays = 21
        /// The observed effect must sit under this fraction of the metric
        /// floor to refute. Between half the floor and the floor, the honest
        /// verdict is inconclusive, never refuted.
        static let refuteEffectFraction = 0.5
    }

    // MARK: - Magnitude banding (verdict copy)

    enum Banding {
        /// Minute effects are rounded to this grain so copy reads
        /// "about 50 minutes", never a falsely precise "52 minutes".
        static let minutesRoundingGrain = 10.0
        /// Rounded minute gaps inside [lower, upper] read as "roughly an
        /// hour"; above the upper bound, "more than an hour".
        static let roughlyAnHourLowerMinutes = 50.0
        static let roughlyAnHourUpperMinutes = 70.0
    }

    // MARK: - Onboarding prediction mapping (symptom / goal → metric)

    /// Turns the user's picked symptom or goal into the single health metric
    /// the pre-registered prediction will test. Keyed by raw string so Core
    /// never imports the onboarding module (matches the String keys on
    /// PreRegisteredPrediction). Symptom wins over goal when both are present:
    /// the symptom is the felt complaint the user most wants explained.
    ///
    /// Clinical rationale: tired/restless mornings track nightly sleep
    /// duration; foggy/anxious/moody states track autonomic recovery (HRV);
    /// slow recovery after effort shows up first as an elevated resting heart
    /// rate. Low motivation has no single reliable physiological proxy, so it
    /// falls through to the goal mapping.
    enum PredictionMapping {
        /// OnbV2Symptom.rawValue → metric. Missing keys (.none, .lowMotivation)
        /// fall through to the goal map.
        static let symptomToMetric: [String: PredictionMetric] = [
            "tiredMorning": .sleepDuration,
            "restless": .sleepDuration,
            "foggy": .heartRateVariability,
            "anxious": .heartRateVariability,
            "moody": .heartRateVariability,
            "sore": .restingHeartRate
        ]

        /// OnbV2Goal.rawValue → metric. Used when the symptom has no mapping
        /// (or the user picked no symptom). Every goal resolves to a metric so
        /// a prediction can always be built once a goal exists.
        static let goalToMetric: [String: PredictionMetric] = [
            "sleep": .sleepDuration,
            "energy": .sleepDuration,
            "training": .restingHeartRate,
            "stress": .heartRateVariability,
            "longevity": .restingHeartRate,
            "weight": .sleepDuration
        ]
    }
}
