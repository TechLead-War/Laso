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
    static var fallbackTodayCaloriesUpperCap: Double { rc.strainFallbackTodayCalorieCap }
    static var defaultRestingHeartRate: Double    { rc.strainDefaultRestingHeartRate }
}
