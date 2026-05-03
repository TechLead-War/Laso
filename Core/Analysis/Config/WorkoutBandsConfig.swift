import Foundation

/// Configuration constants for `WorkoutProgrammer` and `WorkoutRecoveryBand`.
///
/// HEURISTIC — unvalidated. The recovery-score thresholds and HR zone
/// fractions below are common training-zone conventions, not anchored to
/// a specific peer-reviewed dataset. Treat outputs as coaching guidance.
enum WorkoutBandsConfig {

    // MARK: - Recovery Bands (recovery score → band)

    /// Score above this falls in the green band.
    static let greenBandScoreFloor: Int = 75

    /// Score at or above this (and at or below `greenBandScoreFloor`) falls in yellow.
    static let yellowBandScoreFloor: Int = 50

    // MARK: - Recovery Score Seeds (band → seed score)

    static let redBandSeed: Int = 35
    static let yellowBandSeed: Int = 65
    static let greenBandSeed: Int = 82

    // MARK: - Recovery → Training Zone

    static let zoneRestoringScoreCeiling: Int = 50
    static let zoneMaintainingScoreCeiling: Int = 75
    static let zoneBuildingScoreCeiling: Int = 90

    // MARK: - Default Athlete Profile

    /// Default estimated max HR used when the caller has no measurement.
    static let defaultEstimatedMaxHR: Int = 190

    // MARK: - HR Zone Fractions (% of max HR)

    struct HRZoneRange: Sendable {
        let lowerFraction: Double
        let upperFraction: Double
        let label: String
    }

    /// Indexed 0..4 = HR zones 1..5.
    static let hrZones: [HRZoneRange] = [
        HRZoneRange(lowerFraction: 0.50, upperFraction: 0.60, label: "Active Recovery"),
        HRZoneRange(lowerFraction: 0.60, upperFraction: 0.70, label: "Fat Burn"),
        HRZoneRange(lowerFraction: 0.70, upperFraction: 0.80, label: "Aerobic"),
        HRZoneRange(lowerFraction: 0.80, upperFraction: 0.90, label: "Threshold"),
        HRZoneRange(lowerFraction: 0.90, upperFraction: 1.00, label: "Anaerobic")
    ]
}
