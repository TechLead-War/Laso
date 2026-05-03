import Foundation

/// Configuration constants for `HealthScorer`.
///
/// HEURISTIC — unvalidated. The deduction ladders, adaptive-weight factors,
/// and coverage curve below are tuned for product feel and are not anchored
/// to a specific peer-reviewed source. Treat outputs as informational.
enum HealthScorerConfig {

    // MARK: - Score Scale

    static let perfectScore: Int = 100
    static let minScore: Int = 0

    // MARK: - Anomaly Deductions

    /// Maximum deduction for a critical anomaly.
    static let criticalDeductionCap: Int = 50

    /// Multiplier applied to the absolute z-score for critical anomalies.
    static let criticalDeductionPerZ: Double = 12

    /// Maximum deduction for a warning anomaly.
    static let warningDeductionCap: Int = 25

    /// Multiplier applied to the absolute z-score for warning anomalies.
    static let warningDeductionPerZ: Double = 8

    // MARK: - Trend Adjustments

    static let decliningDeductionCap: Int = 30
    static let decliningDeductionPerPercent: Double = 1.3
    static let decliningDeductionOffset: Double = 2

    static let improvingBonusCap: Int = 8
    static let improvingBonusPerPercent: Double = 0.6
    static let improvingBonusOffset: Double = 2

    // MARK: - Adaptive Category Weights

    /// Coefficient-of-variation factor: rawWeight = base + cv * slope, capped.
    static let volatilityFactorBase: Double = 0.5
    static let volatilityFactorSlope: Double = 5.0
    static let volatilityFactorCap: Double = 2.0

    /// Coverage of measured metrics within a category: base + ratio * range.
    static let richnessFactorBase: Double = 0.3
    static let richnessFactorRange: Double = 0.7

    /// Anomaly density: base + density * slope.
    static let anomalyFactorBase: Double = 0.5
    static let anomalyFactorSlope: Double = 1.5

    /// Boost added when a category appears in the user's onboarding focus set.
    static let focusBoost: Double = 1.2

    /// Floor enforced per category after normalisation.
    static let categoryWeightFloor: Double = 0.05

    // MARK: - Adaptive Metric Weights

    /// Weight assigned when a metric has no baseline (will be floored).
    static let noBaselineWeight: Double = 0.1

    /// Freshness curve: ≤1d → fresh, 2-7d → linear decay, >7d → log decay.
    static let freshnessFreshDayCutoff: Int = 1
    static let freshnessFreshScore: Double = 1.0
    static let freshnessRecentDayCutoff: Int = 7
    static let freshnessRecentDecayPerDay: Double = 0.05
    static let freshnessLongTermBase: Double = 0.7
    static let freshnessLongTermDecayPerDay: Double = 0.017
    static let freshnessFloor: Double = 0.3

    /// Per-metric absolute floor (below which the metric is treated as floor weight).
    static let metricWeightAbsoluteFloor: Double = 0.02

    /// Floor expressed as a fraction of the equal-share weight.
    static let metricWeightEqualShareDivisor: Double = 5.0

    // MARK: - Coverage-Based Shrinkage

    /// Each category contributes min(metricCount / `coverageFullWeightMetrics`, 1).
    static let coverageFullWeightMetrics: Double = 2.0

    /// Power applied to weighted coverage to flatten diminishing returns.
    static let coveragePower: Double = 0.6

    /// Score the raw is shrunk toward when coverage is sparse.
    static let neutralScore: Double = 75.0

    // MARK: - Score Explanation

    /// Maximum number of factors surfaced in a score explanation.
    static let maxTopFactors: Int = 3

    /// Tolerance for the "weights sum to 1.0" final pass.
    static let weightSumTolerance: Double = 0.001
}
