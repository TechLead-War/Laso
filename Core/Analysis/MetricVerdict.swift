import SwiftUI

/// Plain answer to the question "is this reading OK": below the normal band, inside it, or above it.
///
/// Single implementation for every screen. Two screens computing their own idea of normal is how
/// a metric ends up called healthy in one place and flagged in another.
struct MetricVerdict {

    enum Standing {
        case belowNormal
        case normal
        case aboveNormal
    }

    /// Where the band came from. The copy must never call a population table the user's own history.
    enum Source {
        case personalBaseline
        case populationRange
    }

    let metric: HealthMetric
    let standing: Standing
    let low: Double
    let high: Double
    let source: Source

    /// Verdict for one value. Prefers the user's own baseline and falls back to the population table.
    /// Returns nil when neither gives a usable band, so callers show nothing instead of guessing.
    static func make(metric: HealthMetric, value: Double, baseline: UserBaseline?) -> MetricVerdict? {
        if let band = personalBand(from: baseline) {
            return MetricVerdict(
                metric: metric,
                standing: standing(for: value, low: band.low, high: band.high),
                low: band.low,
                high: band.high,
                source: .personalBaseline
            )
        }

        guard let range = RulesConfiguration.verdictPopulationRange(for: metric) else { return nil }
        return MetricVerdict(
            metric: metric,
            standing: standing(for: value, low: range.low, high: range.high),
            low: range.low,
            high: range.high,
            source: .populationRange
        )
    }

    /// Verdict for the latest value in a series, for callers that hold samples but no stored baseline.
    static func make(metric: HealthMetric, series: MetricTimeSeries) -> MetricVerdict? {
        guard let value = series.latestValue else { return nil }
        return make(metric: metric, value: value, baseline: BaselineCalculator.compute(series: series))
    }

    /// Personal band around the baseline mean. Nil when the baseline is too thin to trust, or when
    /// the user's readings never move: a zero spread band would call every single reading abnormal.
    private static func personalBand(from baseline: UserBaseline?) -> (low: Double, high: Double)? {
        guard let baseline,
              baseline.sampleCount >= RulesConfiguration.minimumDaysForPersonalBand,
              baseline.standardDeviation > 0 else { return nil }

        let spread = baseline.standardDeviation * RulesConfiguration.personalNormalBandDeviations
        return (baseline.mean - spread, baseline.mean + spread)
    }

    private static func standing(for value: Double, low: Double, high: Double) -> Standing {
        if value < low { return .belowNormal }
        if value > high { return .aboveNormal }
        return .normal
    }
}

// MARK: - Display

extension MetricVerdict {

    var label: String {
        switch standing {
        case .belowNormal: return Copy.Common.Verdict.belowNormal
        case .normal: return Copy.Common.Verdict.normal
        case .aboveNormal: return Copy.Common.Verdict.aboveNormal
        }
    }

    /// Amber rather than red for anything outside the band. Outside is worth reading, not alarming:
    /// severity is the anomaly detector's job, this only answers where the value sits.
    var color: Color {
        standing == .normal ? AppColour.success : AppColour.warning
    }

    /// The bounds spelled out in the units the user sees, for example "Your usual range 58 to 72 bpm".
    var rangeText: String {
        let lowText = metric.formatValue(low)
        let highText = metric.formatWithUnit(high)
        switch source {
        case .personalBaseline: return Copy.Common.Verdict.yourUsualRange(lowText, highText)
        case .populationRange: return Copy.Common.Verdict.typicalRange(lowText, highText)
        }
    }
}
