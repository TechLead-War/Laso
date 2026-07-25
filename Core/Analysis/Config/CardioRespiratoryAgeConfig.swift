import Foundation

/// Configuration constants for `CardioRespiratoryAgeAnalyzer`.
///
/// HEURISTIC — unvalidated. The percentile brackets below are approximated
/// from published population averages; they are not anchored to a specific
/// peer-reviewed dataset. Treat outputs as informational signals only.
enum CardioRespiratoryAgeConfig {

    // MARK: - Percentile Bracket

    struct AgeBracket: Sendable {
        let p10: Double
        let p25: Double
        let p50: Double
        let p75: Double
        let p90: Double
        let p95: Double
    }

    /// VO2max percentile brackets by age (mL/kg/min), combined sex averages.
    /// Row order is the age order and must stay aligned with `bracketAgeMidpoints`.
    static let brackets: [AgeBracket] = [
        AgeBracket(p10: 28, p25: 32, p50: 35, p75: 40, p90: 45, p95: 50),  // 18-29
        AgeBracket(p10: 26, p25: 30, p50: 33, p75: 37, p90: 42, p95: 47),  // 30-39
        AgeBracket(p10: 24, p25: 28, p50: 31, p75: 35, p90: 39, p95: 44),  // 40-49
        AgeBracket(p10: 22, p25: 26, p50: 29, p75: 33, p90: 37, p95: 41),  // 50-59
        AgeBracket(p10: 20, p25: 24, p50: 27, p75: 30, p90: 34, p95: 38),  // 60-69
        AgeBracket(p10: 18, p25: 22, p50: 25, p75: 28, p90: 31, p95: 35),  // 70-79
        AgeBracket(p10: 16, p25: 20, p50: 24, p75: 27, p90: 30, p95: 33)   // 80+
    ]

    /// Index of the bracket used as the percentile reference when the
    /// user's actual age is unknown (40-49).
    static let referenceBracketIndex: Int = 2

    /// Midpoint ages that anchor each bracket for fitness-age interpolation.
    static let bracketAgeMidpoints: [Double] = [24, 35, 45, 55, 65, 75, 85]

    // MARK: - Sample-Size Gates

    static let minSamplesForAnalysis: Int = 3
    static let recentVO2WindowDays: Int = 90
    static let trajectoryWindowDays: Int = 365
    static let recentVO2MeanWindow: Int = 5
    static let trajectoryMinSamples: Int = 5

    /// Minimum tail-window size used when slicing the trajectory series
    /// into "first" vs "last" segments.
    static let trajectorySegmentMinSize: Int = 3
    static let trajectorySegmentDivisor: Int = 4

    // MARK: - Trajectory Thresholds (mL/kg/min)

    /// Magnitude that flips the trajectory from `.stable` to improving / declining.
    static let trajectoryStableBand: Double = 0.5

    /// Minimum monthly observation window before reporting trajectory insights.
    static let minMonthsTrackedForInsight: Int = 3

    /// Magnitude required to publish an "improving" or "declining" insight.
    static let trajectoryReportableChange: Double = 1.0

    /// Decline magnitude that escalates severity from info → warning.
    static let warningDeclineMagnitude: Double = 2.0

    // MARK: - Confidence

    /// Sample count at which the analyzer treats confidence as 1.0.
    static let confidenceFullSampleCount: Double = 10.0

    // MARK: - Very-Low VO2 Warning

    /// VO2max below this absolute floor triggers a medical-advice insight
    /// regardless of age.
    static let veryLowVO2Threshold: Double = 20

    // MARK: - Percentile Mapping

    /// Synthetic floor below the lowest measured percentile (p10 - this).
    static let lowestPercentileOffset: Double = 3
    static let percentileFloor: Double = 5
    static let percentileCeiling: Double = 97
    static let percentileMidpointFallback: Double = 50

    /// Smoothing constant used when interpolating across percentile bands
    /// to avoid divide-by-zero when adjacent values are equal.
    static let percentileInterpolationEpsilon: Double = 0.1

    // MARK: - Fitness-Age Mapping

    /// Years subtracted per unit of "excess fitness" above the youngest p50,
    /// when extrapolating below the youngest measured bracket.
    static let extrapolatedYearsPerExcessUnit: Double = 10
    static let minExtrapolatedAge: Double = 15
    static let maxExtrapolatedAge: Double = 90

    /// Years added beyond the oldest bracket midpoint when VO2max is below
    /// every measured bracket.
    static let belowAllBracketsAgeOffset: Double = 5

    /// Default delta used as a denominator floor when extrapolating below
    /// the youngest bracket and only one bracket exists.
    static let singleBracketFallbackDelta: Double = 5
}
