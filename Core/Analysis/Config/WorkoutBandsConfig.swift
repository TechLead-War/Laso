import Foundation

/// Configuration constants for `WorkoutProgrammer` and `WorkoutRecoveryBand`.
///
/// HEURISTIC — unvalidated. The recovery-score thresholds and HR zone
/// fractions below are common training-zone conventions, not anchored to
/// a specific peer-reviewed dataset. Treat outputs as coaching guidance.
///
/// The band thresholds, seeds, ceilings, and default max-HR live in Firebase
/// Remote Config (see `RC.workout*` in `RemoteConfigSchema.swift`). HR zone
/// fractions stay code-side because they are exercise-physiology convention,
/// not a product-tuning knob — changing them would invalidate every cached
/// workout zone classification.
enum WorkoutBandsConfig {

    private static var rc: RemoteConfigManager { .shared }

    // MARK: - Recovery Bands (recovery score → band)

    static var greenBandScoreFloor: Int           { rc.workoutGreenBandFloor }
    static var yellowBandScoreFloor: Int          { rc.workoutYellowBandFloor }

    // MARK: - Recovery Score Seeds (band → seed score)

    static var redBandSeed: Int                   { rc.workoutRedBandSeed }
    static var yellowBandSeed: Int                { rc.workoutYellowBandSeed }
    static var greenBandSeed: Int                 { rc.workoutGreenBandSeed }

    // MARK: - Recovery → Training Zone

    static var zoneRestoringScoreCeiling: Int     { rc.workoutZoneRestoringCeiling }
    static var zoneMaintainingScoreCeiling: Int   { rc.workoutZoneMaintainingCeiling }
    static var zoneBuildingScoreCeiling: Int      { rc.workoutZoneBuildingCeiling }

    // MARK: - Default Athlete Profile

    static var defaultEstimatedMaxHR: Int         { rc.workoutDefaultMaxHR }

    // MARK: - HR Zone Fractions (% of max HR) — locked
    //
    // Standard exercise-physiology convention (Karvonen / ACSM zone bands).
    // Not a product knob — changing any of these would invalidate every
    // cached workout zone classification across the app history.

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
