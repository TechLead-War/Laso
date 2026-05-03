import Foundation

/// Configuration constants for `StrainScorer`. The strain model is a
/// derivative of the WHOOP-style 0-21 logarithmic load curve.
///
/// HEURISTIC — calibrated against internal targets, not externally validated.
enum StrainScorerConfig {

    // MARK: - StrainLevel Bucket Boundaries (0-21 strain units)

    /// Upper bound (exclusive) of the `low` strain band.
    static let lowUpperExclusive: Double = 6
    /// Upper bound (exclusive) of the `light` strain band.
    static let lightUpperExclusive: Double = 10
    /// Upper bound (exclusive) of the `moderate` strain band.
    static let moderateUpperExclusive: Double = 14
    /// Upper bound (exclusive) of the `high` strain band.
    static let highUpperExclusive: Double = 18
    /// Upper bound (exclusive) of the `overreaching` (peak) strain band.
    static let overreachingUpperExclusive: Double = 20

    // MARK: - HR Zone Multipliers

    /// HR zone multipliers — higher zones contribute disproportionately more strain.
    /// Z1 light · Z2 moderate · Z3 vigorous · Z4 high · Z5 max.
    static let zoneMultipliers: [Int: Double] = [
        1: 1.0,
        2: 2.0,
        3: 4.0,
        4: 8.0,
        5: 14.0,
    ]

    // MARK: - Load Components

    /// Maximum expected physiological load used to normalise the log scale.
    /// Calibrated so an elite training day (~1200 kcal active, 90 min Z4-5) maps to ~20-21.
    static let maxExpectedLoad: Double = 800.0
    /// Minimum days of calorie data required before computing a strain score.
    static let minimumDaysForBaseline: Int = 7
    /// Fallback active calorie expenditure used when historical data is missing.
    static let fallbackTodayCaloriesUpperCap: Double = 400.0
    /// Population-default resting heart rate when none is available.
    static let defaultRestingHeartRate: Double = 65.0
}
