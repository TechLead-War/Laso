import Foundation

/// Configuration constants for `HealthScorer`.
///
/// HEURISTIC — unvalidated. The deduction ladders, adaptive-weight factors,
/// and coverage curve below are tuned for product feel and are not anchored
/// to a specific peer-reviewed source. Treat outputs as informational.
///
/// Every tunable value lives in Firebase Remote Config (see `RC.health*`
/// in `RemoteConfigSchema.swift`). The bundled defaults set inside the
/// binary are the same numbers that previously lived here as `static let`,
/// so behaviour is bit-identical until an operator overrides a key in the
/// Firebase Console. Keep the constant-shaped API (`HealthScorerConfig.foo`)
/// so existing call sites compile unchanged.
enum HealthScorerConfig {

    private static var rc: RemoteConfigManager { .shared }

    // MARK: - Score Scale (locked)
    //
    // The 0-100 scale is part of the public score contract. Never expose to
    // RC — changing the scale silently would corrupt every cached score and
    // render historical comparisons meaningless.
    static let perfectScore: Int = 100
    static let minScore: Int = 0

    // MARK: - Anomaly Deductions

    static var criticalDeductionCap: Int          { rc.healthCriticalDeductionCap }
    static var criticalDeductionPerZ: Double      { rc.healthCriticalDeductionPerZ }
    static var warningDeductionCap: Int           { rc.healthWarningDeductionCap }
    static var warningDeductionPerZ: Double       { rc.healthWarningDeductionPerZ }

    // MARK: - Trend Adjustments

    static var decliningDeductionCap: Int         { rc.healthDecliningDeductionCap }
    static var decliningDeductionPerPercent: Double { rc.healthDecliningDeductionPerPercent }
    static var decliningDeductionOffset: Double   { rc.healthDecliningDeductionOffset }
    static var improvingBonusCap: Int             { rc.healthImprovingBonusCap }
    static var improvingBonusPerPercent: Double   { rc.healthImprovingBonusPerPercent }
    static var improvingBonusOffset: Double       { rc.healthImprovingBonusOffset }

    // MARK: - Adaptive Category Weights

    static var volatilityFactorBase: Double       { rc.healthVolatilityFactorBase }
    static var volatilityFactorSlope: Double      { rc.healthVolatilityFactorSlope }
    static var volatilityFactorCap: Double        { rc.healthVolatilityFactorCap }
    static var richnessFactorBase: Double         { rc.healthRichnessFactorBase }
    static var richnessFactorRange: Double        { rc.healthRichnessFactorRange }
    static var anomalyFactorBase: Double          { rc.healthAnomalyFactorBase }
    static var anomalyFactorSlope: Double         { rc.healthAnomalyFactorSlope }
    static var focusBoost: Double                 { rc.healthFocusBoost }
    static var categoryWeightFloor: Double        { rc.healthCategoryWeightFloor }

    // MARK: - Adaptive Metric Weights

    static var noBaselineWeight: Double           { rc.healthNoBaselineWeight }
    static var freshnessFreshDayCutoff: Int       { rc.healthFreshnessFreshDayCutoff }
    static var freshnessFreshScore: Double        { rc.healthFreshnessFreshScore }
    static var freshnessRecentDayCutoff: Int      { rc.healthFreshnessRecentDayCutoff }
    static var freshnessRecentDecayPerDay: Double { rc.healthFreshnessRecentDecayPerDay }
    static var freshnessLongTermBase: Double      { rc.healthFreshnessLongTermBase }
    static var freshnessLongTermDecayPerDay: Double { rc.healthFreshnessLongTermDecayPerDay }
    static var freshnessFloor: Double             { rc.healthFreshnessFloor }
    static var metricWeightAbsoluteFloor: Double  { rc.healthMetricWeightAbsoluteFloor }
    static var metricWeightEqualShareDivisor: Double { rc.healthMetricWeightEqualShareDivisor }

    // MARK: - Coverage-Based Shrinkage

    static var coverageFullWeightMetrics: Double  { rc.healthCoverageFullWeightMetrics }
    static var coveragePower: Double              { rc.healthCoveragePower }
    static var neutralScore: Double               { rc.healthNeutralScore }

    // MARK: - Score Explanation (locked)

    /// Hard-coded — surfacing more than 3 factors clutters the explanation
    /// card and is a UI invariant, not a tuning knob.
    static let maxTopFactors: Int = 3

    /// Tolerance for the "weights sum to 1.0" final pass. Floating-point
    /// epsilon, not a product knob — locked.
    static let weightSumTolerance: Double = 0.001
}
