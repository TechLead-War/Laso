import Foundation

/// Configuration constants for `ReadinessScorer`. All values are heuristic
/// and not clinically validated; treat outputs as informational signals.
///
/// HEURISTIC — unvalidated, needs clinical review.
enum ReadinessScorerConfig {

    // MARK: - Signal Weights (sum is 1.0 across the full set)

    /// Weight assigned to the HRV signal in the weighted score.
    static let hrvSignalWeight: Double = 0.40
    /// Weight assigned to the RHR signal in the weighted score.
    static let rhrSignalWeight: Double = 0.35
    /// Weight assigned to total sleep duration in the weighted score.
    static let sleepDurationSignalWeight: Double = 0.15
    /// Weight assigned to deep + REM sleep stage breakdown.
    static let sleepStageSignalWeight: Double = 0.06
    /// Weight assigned to recent workout recovery.
    static let workoutSignalWeight: Double = 0.04

    // MARK: - Confidence Caps & Defaults

    /// Sample-count denominator used to scale baseline confidence into [0, 1].
    static let baselineConfidenceSampleCap: Double = 21.0
    /// Default baseline confidence when no baseline has been computed yet.
    static let defaultBaselineConfidence: Double = 0.55
    /// Confidence assigned to the sleep-stage signal when present.
    static let sleepStageConfidence: Double = 0.85
    /// Sleep-duration confidence floor — even a short night still contributes.
    static let sleepDurationConfidenceFloor: Double = 0.5
    /// Sleep-duration target hours used to scale confidence toward 1.0.
    static let sleepDurationConfidenceTargetHours: Double = 7.0

    // MARK: - Freshness

    /// Default cardiac sample age (seconds) when timestamp is missing.
    static let missingCardiacAgeSeconds: TimeInterval = 72 * 3600
    /// Maximum cardiac sample age (seconds) used by the freshness curve.
    static let cardiacFreshnessHorizonSeconds: TimeInterval = 48 * 3600

    /// Floor confidence for invalid / extremely stale freshness inputs.
    static let freshnessFloor: Double = 0.35
    /// Slope of the freshness ramp; ratio is multiplied by this and subtracted from 1.
    static let freshnessRatioWeight: Double = 0.65
    /// Upper-bound clamp applied to the age/maxAge ratio inside `freshnessConfidence`.
    static let freshnessRatioClampMax: Double = 2

    // MARK: - Score Reshape

    /// Center of the reshaped weighted score (kept at 50 — the gauge midpoint).
    static let scoreCenter: Double = 50
    /// Confidence-blended floor applied when reshaping the weighted score.
    static let scoreConfidenceFloor: Double = 0.35
    /// Slope of the confidence-driven reshape applied to (weighted - 50).
    static let scoreConfidenceSlope: Double = 0.65

    // MARK: - Cardiac Staleness Penalty

    /// Sample age (hours) above which the cardiac-staleness penalty kicks in.
    static let cardiacStalenessOnsetHours: Double = 24.0
    /// Penalty per hour past the staleness onset.
    static let cardiacStalenessPenaltyPerHour: Double = 0.5
    /// Cap on the cardiac-staleness penalty.
    static let cardiacStalenessMaxPenalty: Double = 12.0

    // MARK: - HRV / RHR Score Curves

    /// Tanh divisor applied to the z-score before stretching into the band.
    static let hrvRhrTanhDivisor: Double = 1.8
    /// Center of the band-stretched HRV/RHR score (matches gauge mid).
    static let hrvRhrScoreCenter: Double = 55
    /// Half-width of the band-stretched HRV/RHR score.
    static let hrvRhrScoreSpread: Double = 35

    /// Anchor used by the no-baseline HRV fallback score.
    static let hrvFallbackAnchor: Double = 15
    /// Range used by the no-baseline HRV fallback score.
    static let hrvFallbackRange: Double = 55
    /// Anchor used by the no-baseline RHR fallback score.
    static let rhrFallbackAnchor: Double = 85
    /// Range used by the no-baseline RHR fallback score.
    static let rhrFallbackRange: Double = 40

    // MARK: - Sleep Curves

    /// Target sleep duration (hours) used to anchor the duration-score curve.
    static let sleepTargetHours: Double = 7.5
    /// Per-hour deficit penalty applied below the target.
    static let sleepDeficitLinearPenalty: Double = 13
    /// Quadratic coefficient applied to the deficit penalty below target.
    static let sleepDeficitQuadraticPenalty: Double = 4
    /// Per-hour excess penalty applied above the target.
    static let sleepExcessLinearPenalty: Double = 7
    /// Quadratic coefficient applied to the excess penalty above target.
    static let sleepExcessQuadraticPenalty: Double = 2
    /// Floor sleep score when the user is short on sleep.
    static let sleepDurationDeficitFloor: Double = 10
    /// Floor sleep score when the user is over on sleep.
    static let sleepDurationExcessFloor: Double = 35

    /// Lower bound of the restorative ratio (deep + REM as fraction of total sleep).
    static let sleepRestorativeRatioFloor: Double = 0.16
    /// Width of the restorative ratio above the floor that maps to a full score.
    static let sleepRestorativeRatioRange: Double = 0.24

    // MARK: - Workout Recovery

    /// Workout duration (minutes) that maps to load = 1.0.
    static let workoutLoadDurationCap: Double = 75.0
    /// Workout calories that map to load = 1.0.
    static let workoutLoadCalorieCap: Double = 600.0
    /// Hours since workout for the "recent" recovery band.
    static let workoutRecoveryRecentBandHours: Double = 6
    /// Hours since workout for the "mid" recovery band.
    static let workoutRecoveryMidBandHours: Double = 18
    /// Recent-band base score and load penalty.
    static let workoutRecoveryRecentBase: Double = 85
    static let workoutRecoveryRecentLoadPenalty: Double = 35
    /// Mid-band base score and load penalty.
    static let workoutRecoveryMidBase: Double = 92
    static let workoutRecoveryMidLoadPenalty: Double = 25
    /// Late-band base score and load penalty.
    static let workoutRecoveryLateBase: Double = 96
    static let workoutRecoveryLateLoadPenalty: Double = 12
    /// Workout-recovery confidence floor (used when sample is stale).
    static let workoutRecoveryConfidenceFloor: Double = 0.4
    /// Hours past which workout-recovery confidence starts to decay.
    static let workoutRecoveryConfidenceOnsetHours: Double = 36.0
    /// Per-24-hour decay multiplier for workout-recovery confidence.
    static let workoutRecoveryConfidenceDecayHours: Double = 24.0

    // MARK: - Stress Sub-Score

    /// HRV anchor used when computing the stress sub-score (lower HRV → more stress).
    static let stressHRVAnchor: Double = 60
    /// HRV range used when computing the stress sub-score.
    static let stressHRVRange: Double = 40
    /// RHR anchor used when computing the stress sub-score (higher RHR → more stress).
    static let stressRHRAnchor: Double = 50
    /// RHR range used when computing the stress sub-score.
    static let stressRHRRange: Double = 30
    /// Per-channel stress component cap (HRV + RHR sum to 100).
    static let stressChannelCap: Double = 50
}
