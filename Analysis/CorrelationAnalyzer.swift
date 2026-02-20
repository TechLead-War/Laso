import Foundation

/// Discovers cross-metric correlations and generates insights about how health behaviors connect
struct CorrelationAnalyzer {

    /// A pre-defined metric pair to test for correlation
    private struct MetricPair {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let dayOffset: Int  // 0 = same day, 1 = A day N → B day N+1
        let label: String   // Human-readable description of the relationship
    }

    /// Result of a correlation analysis
    struct CorrelationResult {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let correlation: Double     // Pearson r (-1 to 1)
        let sampleCount: Int
        let label: String
        let effectSummary: String   // e.g. "HRV drops 18% after <6hr sleep"
    }

    private static let pairs: [MetricPair] = [
        MetricPair(metricA: .sleepDuration, metricB: .restingHeartRate, dayOffset: 1,
                   label: "Sleep Duration → Next-Day Resting HR"),
        MetricPair(metricA: .sleepDuration, metricB: .heartRateVariability, dayOffset: 1,
                   label: "Sleep Duration → Next-Day HRV"),
        MetricPair(metricA: .exerciseMinutes, metricB: .heartRateVariability, dayOffset: 1,
                   label: "Exercise → Next-Day HRV"),
        MetricPair(metricA: .steps, metricB: .sleepDuration, dayOffset: 0,
                   label: "Steps → Sleep Duration"),
        MetricPair(metricA: .activeCalories, metricB: .restingHeartRate, dayOffset: 1,
                   label: "Active Calories → Next-Day Resting HR"),
        MetricPair(metricA: .sleepDeep, metricB: .heartRateVariability, dayOffset: 1,
                   label: "Deep Sleep → Next-Day HRV"),
        MetricPair(metricA: .activeCalories, metricB: .sleepDeep, dayOffset: 0,
                   label: "Active Calories → Deep Sleep"),
        MetricPair(metricA: .mindfulMinutes, metricB: .heartRateVariability, dayOffset: 0,
                   label: "Mindfulness → HRV"),
    ]

    /// Analyze correlations across all pre-defined metric pairs
    static func analyze(timeSeries: [HealthMetric: MetricTimeSeries]) -> [CorrelationResult] {
        var results: [CorrelationResult] = []

        for pair in pairs {
            guard let seriesA = timeSeries[pair.metricA],
                  let seriesB = timeSeries[pair.metricB] else { continue }

            let aligned: [TimeSeriesAligner.AlignedPair]
            if pair.dayOffset == 0 {
                aligned = TimeSeriesAligner.alignByDate(seriesA, seriesB)
            } else {
                aligned = TimeSeriesAligner.alignWithOffset(seriesA, seriesB, dayOffset: pair.dayOffset)
            }

            guard aligned.count >= 14 else { continue }

            let xValues = aligned.map(\.valueA)
            let yValues = aligned.map(\.valueB)

            guard let r = [Double].pearsonCorrelation(xValues, yValues),
                  abs(r) >= 0.2 else { continue }

            let effectSummary = computeConditionalEffect(
                aligned: aligned,
                metricA: pair.metricA,
                metricB: pair.metricB
            )

            results.append(CorrelationResult(
                metricA: pair.metricA,
                metricB: pair.metricB,
                correlation: r,
                sampleCount: aligned.count,
                label: pair.label,
                effectSummary: effectSummary
            ))
        }

        // Sort by absolute correlation strength
        return results.sorted { abs($0.correlation) > abs($1.correlation) }
    }

    /// Generate insights from the top correlations
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        let results = analyze(timeSeries: timeSeries)
        let topResults = Array(results.prefix(3))

        return topResults.map { result in
            let severity: Severity = abs(result.correlation) >= 0.5 ? .warning : .info
            let direction: String = result.correlation > 0 ? "positive" : "inverse"

            return Insight(
                metric: result.metricA,
                title: result.label,
                summary: result.effectSummary,
                recommendation: "Pay attention to your \(result.metricA.displayName.lowercased()) — it has a \(direction) correlation with your \(result.metricB.displayName.lowercased()).",
                severity: severity,
                trend: .stable,
                currentValue: result.correlation,
                baselineValue: 0,
                deviationPercent: abs(result.correlation) * 100,
                category: .correlation,
                relatedMetrics: [result.metricA, result.metricB]
            )
        }
    }

    // MARK: - Private

    /// Partition by above/below baseline of metric A, compute average difference in metric B
    private static func computeConditionalEffect(
        aligned: [TimeSeriesAligner.AlignedPair],
        metricA: HealthMetric,
        metricB: HealthMetric
    ) -> String {
        let aValues = aligned.map(\.valueA)
        let baseline = aValues.mean

        let aboveBaseline = aligned.filter { $0.valueA >= baseline }
        let belowBaseline = aligned.filter { $0.valueA < baseline }

        guard !aboveBaseline.isEmpty, !belowBaseline.isEmpty else {
            return "\(metricA.displayName) correlates with \(metricB.displayName)."
        }

        let avgBAbove = aboveBaseline.map(\.valueB).mean
        let avgBBelow = belowBaseline.map(\.valueB).mean

        guard avgBBelow != 0 else {
            return "\(metricA.displayName) correlates with \(metricB.displayName)."
        }

        let percentDiff = ((avgBAbove - avgBBelow) / abs(avgBBelow)) * 100
        let direction = percentDiff > 0 ? "higher" : "lower"
        let absPercent = String(format: "%.0f", abs(percentDiff))

        return "When your \(metricA.displayName.lowercased()) is above average, your \(metricB.displayName.lowercased()) is \(absPercent)% \(direction)."
    }
}
