import Foundation

/// Configuration constants for `WorkoutProgrammer` and `WorkoutRecoveryBand`.
///
/// HEURISTIC — unvalidated. The recovery-score thresholds below are common
/// training-zone conventions, not anchored to a specific peer-reviewed
/// dataset. Treat outputs as coaching guidance.
///
/// The band thresholds, seeds, and ceilings live in Firebase Remote Config
/// (see `RC.workout*` in `RemoteConfigSchema.swift`).
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
}
