import Foundation

/// Configuration constants for `SleepNeedCalculator`.
///
/// HEURISTIC — unvalidated. The hour adjustments and bracket cutoffs below
/// are informed by widely cited sleep guidance (NSF, AASM) but are not
/// anchored to a specific source DOI. Treat outputs as recommendations.
enum SleepNeedConfig {

    // MARK: - Sample-Size Gates

    static let minimumDaysRequired: Int = 7
    static let baselineWindowDays: Int = 30
    static let wakeTimeWindowDays: Int = 14
    static let wakeTimeMinSamples: Int = 3

    // MARK: - Hard Bounds (hours)

    static let floorHours: Double = 6.5
    static let ceilingHours: Double = 9.0

    // MARK: - Age Bracket Adjustments (years → hours)

    static let ageYoungAdultUpper: Int = 26
    static let ageOlderAdultLower: Int = 64
    static let ageYoungAdultAdjustment: Double = 0.25
    static let ageOlderAdultAdjustment: Double = -0.25

    // MARK: - Recovery Adjustments (recovery score → hours)

    static let recoveryLowCeiling: Double = 40
    static let recoveryModerateCeiling: Double = 60
    static let recoveryGoodCeiling: Double = 80
    static let recoveryLowAdjustment: Double = 0.5
    static let recoveryModerateAdjustment: Double = 0.25
    static let recoveryExcellentAdjustment: Double = -0.25

    // MARK: - Strain Adjustments (strain score → hours)

    static let strainHeavyFloor: Double = 15
    static let strainModerateFloor: Double = 10
    static let strainHeavyAdjustment: Double = 0.5
    static let strainModerateAdjustment: Double = 0.25

    // MARK: - Debt Adjustment

    /// Maximum upward shift applied when the user is carrying any sleep debt.
    static let maxDebtAdjustment: Double = 0.5

    // MARK: - Quality-Trend Adjustment

    static let qualityTrendRecentWindowDays: Int = 7
    static let qualityTrendBaselineWindowDays: Int = 30
    static let qualityTrendRecentMinSamples: Int = 5
    static let qualityTrendBaselineMinSamples: Int = 14

    /// Minimum recent-vs-baseline gap (hours) that flags "declining quality".
    static let qualityTrendDecliningGapHours: Double = 0.5
    static let qualityTrendAdjustment: Double = 0.25

    // MARK: - Consistency Score

    /// Coefficient of variation that maps to a 0% consistency score.
    static let consistencyCVZeroScoreThreshold: Double = 0.3
    static let consistencyMaxScore: Double = 100
    static let consistencyMinScore: Double = 0

    /// Bedtime standard deviation (minutes) that maps to a 0% timing score.
    static let timingStdDevZeroScoreMinutes: Double = 90

    /// Blend weights for the duration vs timing component of the consistency score.
    static let consistencyDurationWeight: Double = 0.4
    static let consistencyTimingWeight: Double = 0.6

    /// Threshold (minutes from midnight) above which a bedtime is treated as
    /// "before midnight yesterday" so the value normalises to a negative offset.
    static let bedtimeWrapAroundThresholdMinutes: Double = 1080
    static let minutesPerDay: Double = 1440
}
