import Foundation

/// Configuration constants for `StrainScorer`. The strain model is a
/// derivative of the WHOOP-style 0-21 logarithmic load curve.
///
/// HEURISTIC — calibrated against internal targets, not externally validated.
///
/// Every tunable value lives in Firebase Remote Config (see `RC.strain*` in
/// `RemoteConfigSchema.swift`). Bundled defaults match the historical
/// hard-coded values, so behaviour is bit-identical until an operator
/// overrides a key.
enum StrainScorerConfig {

    private static var rc: RemoteConfigManager { .shared }

    /// Top of the strain scale. The curve is defined to land here at
    /// `maxExpectedLoad`, so anything showing strain as a fraction has to
    /// divide by this and not by a locally typed 21.
    static let strainScaleMax: Double = 21

    // MARK: - StrainLevel Bucket Boundaries (0-21 strain units)

    static var lowUpperExclusive: Double          { rc.strainLowUpper }
    static var lightUpperExclusive: Double        { rc.strainLightUpper }
    static var moderateUpperExclusive: Double     { rc.strainModerateUpper }
    static var highUpperExclusive: Double         { rc.strainHighUpper }
    static var overreachingUpperExclusive: Double { rc.strainOverreachingUpper }

    // MARK: - HR Zone Multipliers
    //
    // Higher zones contribute disproportionately more strain.
    // Z1 light · Z2 moderate · Z3 vigorous · Z4 high · Z5 max.
    static var zoneMultipliers: [Int: Double]     { rc.strainZoneMultipliers }

    // MARK: - Load Components

    /// Maximum expected physiological load used to normalise the log scale.
    /// Calibrated so an elite training day (~1200 kcal active, 90 min Z4-5)
    /// maps to ~20-21 on the 0-21 strain scale.
    static var maxExpectedLoad: Double            { rc.strainMaxExpectedLoad }
    static var minimumDaysForBaseline: Int        { rc.strainMinDaysForBaseline }

    /// Ceiling on how much elapsed time a single heart rate reading may stand
    /// for. A watch workout session writes HR every few seconds while
    /// background sampling can skip an hour, so an uncapped gap would invent
    /// zone time that never happened.
    static let hrSampleCoverageCapMinutes: Double = 2

    /// Only the calorie surplus over the personal baseline counts as load: a
    /// day that merely matches your own 28-day average is ordinary by
    /// definition and must not land in a hard-day bucket.
    static let calorieExcessWeight: Double = 150

    /// Caps the calorie term so a user with a very low baseline cannot reach
    /// the top of the scale on calories alone.
    static let calorieExcessCap: Double = 150

    /// Floor on the personal calorie baseline. Prevents a near-empty history
    /// from turning a normal day into a huge ratio.
    static let minCalorieBaseline: Double = 100

    /// Weight on the square-root of active minutes, used only as a stand-in
    /// when no heart rate zone time was recorded.
    static let durationLoadWeight: Double = 10
}
