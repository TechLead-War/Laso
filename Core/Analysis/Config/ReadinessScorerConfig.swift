import Foundation

/// Configuration constants for `ReadinessScorer`. All values are heuristic
/// and not clinically validated; treat outputs as informational signals.
///
/// HEURISTIC — unvalidated, needs clinical review.
///
/// Every tunable value lives in Firebase Remote Config (see `RC.readiness*`
/// in `RemoteConfigSchema.swift`). Bundled defaults inside the binary
/// match the historical hard-coded values, so behaviour is bit-identical
/// until an operator overrides a key.
///
/// Operator invariant: HRV + RHR + sleep-duration + sleep-stage + workout
/// signal weights must sum to 1.0. The admin panel must enforce this; if
/// not, `ReadinessScorer` re-normalises by effective weight at scoring time
/// so a small drift cannot break the gauge.
enum ReadinessScorerConfig {

    private static var rc: RemoteConfigManager { .shared }

    // MARK: - Signal Weights (sum is 1.0 across the full set)

    static var hrvSignalWeight: Double            { rc.readinessHrvWeight }
    static var rhrSignalWeight: Double            { rc.readinessRhrWeight }
    static var sleepDurationSignalWeight: Double  { rc.readinessSleepDurationWeight }
    static var sleepStageSignalWeight: Double     { rc.readinessSleepStageWeight }
    static var workoutSignalWeight: Double        { rc.readinessWorkoutWeight }

    /// Weight of every signal the score can be built from, present or not.
    ///
    /// Confidence has to divide by this, not by the weight of the signals that
    /// happened to report. Dividing by what arrived meant a day carrying HRV
    /// alone scored 100% confident, so the centre-pull never engaged and Home
    /// printed a bold "96 Ready" off one reading.
    static var allSignalWeightTotal: Double {
        hrvSignalWeight + rhrSignalWeight + sleepDurationSignalWeight
            + sleepStageSignalWeight + workoutSignalWeight
    }

    // MARK: - Confidence Caps & Defaults

    static var baselineConfidenceSampleCap: Double { rc.readinessBaselineSampleCap }
    static var defaultBaselineConfidence: Double  { rc.readinessDefaultBaselineConfidence }
    static var sleepStageConfidence: Double       { rc.readinessSleepStageConfidence }
    static var sleepDurationConfidenceFloor: Double { rc.readinessSleepDurationConfFloor }
    static var sleepDurationConfidenceTargetHours: Double { rc.readinessSleepDurationTargetHours }

    // MARK: - Freshness

    static var missingCardiacAgeSeconds: TimeInterval { rc.readinessMissingCardiacAgeSeconds }
    static var cardiacFreshnessHorizonSeconds: TimeInterval { rc.readinessCardiacFreshnessHorizonSeconds }
    static var freshnessFloor: Double             { rc.readinessFreshnessFloor }
    static var freshnessRatioWeight: Double       { rc.readinessFreshnessRatioWeight }
    static var freshnessRatioClampMax: Double     { rc.readinessFreshnessRatioClampMax }

    // MARK: - Score Reshape

    static var scoreCenter: Double                { rc.readinessScoreCenter }
    static var scoreConfidenceFloor: Double       { rc.readinessScoreConfidenceFloor }
    static var scoreConfidenceSlope: Double       { rc.readinessScoreConfidenceSlope }

    // MARK: - Cardiac Staleness Penalty

    static var cardiacStalenessOnsetHours: Double { rc.readinessCardiacStalenessOnsetHours }
    static var cardiacStalenessPenaltyPerHour: Double { rc.readinessCardiacStalenessPenaltyPerHour }
    static var cardiacStalenessMaxPenalty: Double { rc.readinessCardiacStalenessMaxPenalty }

    // MARK: - HRV / RHR Score Curves

    static var hrvRhrTanhDivisor: Double          { rc.readinessHrvRhrTanhDivisor }
    static var hrvRhrScoreCenter: Double          { rc.readinessHrvRhrScoreCenter }
    static var hrvRhrScoreSpread: Double          { rc.readinessHrvRhrScoreSpread }
    static var hrvFallbackAnchor: Double          { rc.readinessHrvFallbackAnchor }
    static var hrvFallbackRange: Double           { rc.readinessHrvFallbackRange }
    static var rhrFallbackAnchor: Double          { rc.readinessRhrFallbackAnchor }
    static var rhrFallbackRange: Double           { rc.readinessRhrFallbackRange }

    // MARK: - Sleep Curves

    static var sleepTargetHours: Double           { rc.readinessSleepTargetHours }
    static var sleepDeficitLinearPenalty: Double  { rc.readinessSleepDeficitLinear }
    static var sleepDeficitQuadraticPenalty: Double { rc.readinessSleepDeficitQuadratic }
    static var sleepExcessLinearPenalty: Double   { rc.readinessSleepExcessLinear }
    static var sleepExcessQuadraticPenalty: Double { rc.readinessSleepExcessQuadratic }
    static var sleepDurationDeficitFloor: Double  { rc.readinessSleepDeficitFloor }
    static var sleepDurationExcessFloor: Double   { rc.readinessSleepExcessFloor }
    static var sleepRestorativeRatioFloor: Double { rc.readinessSleepRestorativeFloor }
    static var sleepRestorativeRatioRange: Double { rc.readinessSleepRestorativeRange }

    // MARK: - Workout Recovery

    static var workoutLoadDurationCap: Double     { rc.readinessWorkoutLoadDurationCap }
    static var workoutLoadCalorieCap: Double      { rc.readinessWorkoutLoadCalorieCap }
    static var workoutRecoveryRecentBandHours: Double { rc.readinessWorkoutRecentBandHours }
    static var workoutRecoveryMidBandHours: Double { rc.readinessWorkoutMidBandHours }
    static var workoutRecoveryRecentBase: Double  { rc.readinessWorkoutRecentBase }
    static var workoutRecoveryRecentLoadPenalty: Double { rc.readinessWorkoutRecentLoadPenalty }
    static var workoutRecoveryMidBase: Double     { rc.readinessWorkoutMidBase }
    static var workoutRecoveryMidLoadPenalty: Double { rc.readinessWorkoutMidLoadPenalty }
    static var workoutRecoveryLateBase: Double    { rc.readinessWorkoutLateBase }
    static var workoutRecoveryLateLoadPenalty: Double { rc.readinessWorkoutLateLoadPenalty }
    static var workoutRecoveryConfidenceFloor: Double { rc.readinessWorkoutConfFloor }
    static var workoutRecoveryConfidenceOnsetHours: Double { rc.readinessWorkoutConfOnsetHours }
    static var workoutRecoveryConfidenceDecayHours: Double { rc.readinessWorkoutConfDecayHours }

    // MARK: - Stress Sub-Score

    static var stressHRVAnchor: Double            { rc.readinessStressHrvAnchor }
    static var stressHRVRange: Double             { rc.readinessStressHrvRange }
    static var stressRHRAnchor: Double            { rc.readinessStressRhrAnchor }
    static var stressRHRRange: Double             { rc.readinessStressRhrRange }
    static var stressChannelCap: Double           { rc.readinessStressChannelCap }

    // MARK: - Live Energy

    /// Heart rate older than this means the watch is currently off the wrist;
    /// the live ring should drop the live label and (when no morning lock
    /// exists) blank itself.
    static var onWristMaxAgeSeconds: TimeInterval { rc.energyOnWristMaxAgeSeconds }
    /// HRV and RHR samples older than this cannot anchor today's morning lock;
    /// without a fresh overnight reading the lock would silently report stale
    /// recovery as "this morning".
    static var morningLockFreshnessHours: Double  { rc.energyMorningLockFreshnessHours }
    /// kcal of active energy that drains one Energy point. Tuning: 50 keeps a
    /// hard 60-min run (~600 kcal) at roughly 12 points of drain so an 80
    /// Recovery still ends the day above the 60 mid-band.
    static var kcalPerStrainPoint: Double         { rc.energyKcalPerStrainPoint }
    /// Cap on total strain drain so a single very heavy day cannot push Energy
    /// to zero from a healthy morning anchor.
    static var maxStrainDrain: Double             { rc.energyMaxStrainDrain }
    /// Floor for live Energy so the ring never reads zero while the watch is
    /// still streaming live data — zero would imply no signal at all.
    static var energyFloor: Double                { rc.energyFloor }
    /// Below this much strain drain, the ring still reads "Recovery" — the
    /// number is essentially the morning anchor. Above it, switch to "Energy".
    static var energyLabelStrainThreshold: Double { rc.energyLabelStrainThreshold }
    /// Minimum number of recent daily HRV averages needed before we will call
    /// the 7-day trend; below this the caption is hidden.
    static var weeklyTrendMinDays: Int            { rc.recoveryWeeklyTrendMinDays }
    /// Recent mean must move beyond this many baseline standard deviations to
    /// qualify as improving or declining; smaller swings stay "stable".
    static var weeklyTrendThresholdSDMultiplier: Double { rc.recoveryWeeklyTrendThresholdSDMultiplier }
}
