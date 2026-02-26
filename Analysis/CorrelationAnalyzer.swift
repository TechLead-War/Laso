import Foundation

/// Discovers cross-metric correlations and generates insights about how health behaviors connect
struct CorrelationAnalyzer {

    /// A pre-defined metric pair to test for correlation
    private struct MetricPair {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let dayOffset: Int          // 0 = same day, 1 = A day N -> B day N+1
        let causeLabel: String      // "More deep sleep"
        let effectLabel: String     // "Higher HRV next day"
    }

    // MARK: - Comprehensive Pair Registry (~35 physiologically-plausible pairs)

    private static let pairs: [MetricPair] = [
        // Sleep -> Recovery (next-day offsets)
        MetricPair(metricA: .sleepDuration, metricB: .restingHeartRate, dayOffset: 1,
                   causeLabel: "More sleep", effectLabel: "Lower resting HR next day"),
        MetricPair(metricA: .sleepDuration, metricB: .heartRateVariability, dayOffset: 1,
                   causeLabel: "More sleep", effectLabel: "Higher HRV next day"),
        MetricPair(metricA: .sleepDeep, metricB: .heartRateVariability, dayOffset: 1,
                   causeLabel: "More deep sleep", effectLabel: "Higher HRV next day"),
        MetricPair(metricA: .sleepREM, metricB: .heartRateVariability, dayOffset: 1,
                   causeLabel: "More REM sleep", effectLabel: "Higher HRV next day"),
        MetricPair(metricA: .sleepDuration, metricB: .bloodOxygen, dayOffset: 1,
                   causeLabel: "More sleep", effectLabel: "Better blood oxygen next day"),

        // Exercise -> Recovery
        MetricPair(metricA: .exerciseMinutes, metricB: .heartRateVariability, dayOffset: 1,
                   causeLabel: "More exercise", effectLabel: "Higher HRV next day"),
        MetricPair(metricA: .activeCalories, metricB: .restingHeartRate, dayOffset: 1,
                   causeLabel: "More active calories", effectLabel: "Lower resting HR next day"),
        MetricPair(metricA: .activeCalories, metricB: .sleepDeep, dayOffset: 0,
                   causeLabel: "More active calories", effectLabel: "More deep sleep"),
        MetricPair(metricA: .exerciseMinutes, metricB: .sleepDuration, dayOffset: 0,
                   causeLabel: "More exercise", effectLabel: "Longer sleep"),
        MetricPair(metricA: .steps, metricB: .sleepDuration, dayOffset: 0,
                   causeLabel: "More steps", effectLabel: "Longer sleep"),
        MetricPair(metricA: .vo2Max, metricB: .restingHeartRate, dayOffset: 0,
                   causeLabel: "Higher VO2 Max", effectLabel: "Lower resting HR"),

        // Activity -> Body
        MetricPair(metricA: .steps, metricB: .activeCalories, dayOffset: 0,
                   causeLabel: "More steps", effectLabel: "More calories burned"),
        MetricPair(metricA: .standHours, metricB: .activeCalories, dayOffset: 0,
                   causeLabel: "More stand hours", effectLabel: "More calories burned"),
        MetricPair(metricA: .exerciseMinutes, metricB: .bodyFatPercentage, dayOffset: 0,
                   causeLabel: "More exercise", effectLabel: "Lower body fat"),
        MetricPair(metricA: .steps, metricB: .weight, dayOffset: 0,
                   causeLabel: "More steps", effectLabel: "Lower weight"),

        // Heart -> Stress / Mindfulness
        MetricPair(metricA: .mindfulMinutes, metricB: .heartRateVariability, dayOffset: 0,
                   causeLabel: "More mindfulness", effectLabel: "Higher HRV"),
        MetricPair(metricA: .mindfulMinutes, metricB: .restingHeartRate, dayOffset: 0,
                   causeLabel: "More mindfulness", effectLabel: "Lower resting HR"),
        MetricPair(metricA: .respiratoryRate, metricB: .heartRateVariability, dayOffset: 0,
                   causeLabel: "Lower respiratory rate", effectLabel: "Higher HRV"),

        // Sleep -> Activity (next-day)
        MetricPair(metricA: .sleepDuration, metricB: .steps, dayOffset: 1,
                   causeLabel: "More sleep", effectLabel: "More steps next day"),
        MetricPair(metricA: .sleepDuration, metricB: .exerciseMinutes, dayOffset: 1,
                   causeLabel: "More sleep", effectLabel: "More exercise next day"),
        MetricPair(metricA: .sleepDeep, metricB: .activeCalories, dayOffset: 1,
                   causeLabel: "More deep sleep", effectLabel: "More calories burned next day"),

        // Body -> Activity
        MetricPair(metricA: .weight, metricB: .restingHeartRate, dayOffset: 0,
                   causeLabel: "Higher weight", effectLabel: "Higher resting HR"),
        MetricPair(metricA: .bmi, metricB: .bloodPressureSystolic, dayOffset: 0,
                   causeLabel: "Higher BMI", effectLabel: "Higher blood pressure"),
        MetricPair(metricA: .bodyFatPercentage, metricB: .vo2Max, dayOffset: 0,
                   causeLabel: "Lower body fat", effectLabel: "Higher VO2 Max"),

        // Respiratory -> Sleep
        MetricPair(metricA: .respiratoryRate, metricB: .sleepDeep, dayOffset: 0,
                   causeLabel: "Lower respiratory rate", effectLabel: "More deep sleep"),
        MetricPair(metricA: .bloodOxygen, metricB: .sleepDeep, dayOffset: 0,
                   causeLabel: "Better blood oxygen", effectLabel: "More deep sleep"),

        // Additional cross-domain pairs
        MetricPair(metricA: .sleepDuration, metricB: .restingHeartRate, dayOffset: 0,
                   causeLabel: "More sleep", effectLabel: "Lower resting HR"),
        MetricPair(metricA: .sleepDeep, metricB: .restingHeartRate, dayOffset: 1,
                   causeLabel: "More deep sleep", effectLabel: "Lower resting HR next day"),
        MetricPair(metricA: .exerciseMinutes, metricB: .sleepDeep, dayOffset: 0,
                   causeLabel: "More exercise", effectLabel: "More deep sleep"),
        MetricPair(metricA: .steps, metricB: .heartRateVariability, dayOffset: 0,
                   causeLabel: "More steps", effectLabel: "Higher HRV"),
        MetricPair(metricA: .activeCalories, metricB: .heartRateVariability, dayOffset: 1,
                   causeLabel: "More active calories", effectLabel: "Higher HRV next day"),
        MetricPair(metricA: .sleepREM, metricB: .restingHeartRate, dayOffset: 1,
                   causeLabel: "More REM sleep", effectLabel: "Lower resting HR next day"),
        MetricPair(metricA: .vo2Max, metricB: .heartRateVariability, dayOffset: 0,
                   causeLabel: "Higher VO2 Max", effectLabel: "Higher HRV"),
        MetricPair(metricA: .exerciseMinutes, metricB: .restingHeartRate, dayOffset: 1,
                   causeLabel: "More exercise", effectLabel: "Lower resting HR next day"),
    ]

    // MARK: - Public API

    /// Analyze all metric pairs with automatic lag discovery (tests lags 0-3 for each pair)
    /// and return significant correlations as HealthCorrelation objects
    static func analyzeAll(timeSeries: [HealthMetric: MetricTimeSeries]) -> [HealthCorrelation] {
        var results: [HealthCorrelation] = []

        for pair in pairs {
            guard let seriesA = timeSeries[pair.metricA],
                  let seriesB = timeSeries[pair.metricB] else { continue }

            // Test the predefined lag AND nearby lags to find the strongest correlation
            let lagsToTest = Set([pair.dayOffset, 0, 1, 2, 3])

            var bestResult: (r: Double, t: Double, lag: Int, aligned: [TimeSeriesAligner.AlignedPair])?

            for lag in lagsToTest {
                let aligned: [TimeSeriesAligner.AlignedPair]
                if lag == 0 {
                    aligned = TimeSeriesAligner.alignByDate(seriesA, seriesB)
                } else {
                    aligned = TimeSeriesAligner.alignWithOffset(seriesA, seriesB, dayOffset: lag)
                }

                guard aligned.count >= 14 else { continue }

                let xValues = aligned.map(\.valueA)
                let yValues = aligned.map(\.valueB)

                guard let r = [Double].pearsonCorrelation(xValues, yValues),
                      abs(r) >= 0.2 else { continue }

                let n = Double(aligned.count)
                let rSquared = r * r
                guard rSquared < 1.0 else { continue }
                let t = abs(r) * sqrt((n - 2) / (1 - rSquared))
                guard t >= 2.0 else { continue }

                if bestResult == nil || abs(r) > abs(bestResult!.r) {
                    bestResult = (r: r, t: t, lag: lag, aligned: aligned)
                }
            }

            guard let best = bestResult else { continue }

            // Effect size: require >= 8% difference between above/below baseline groups
            let effectResult = computeConditionalEffect(
                aligned: best.aligned,
                metricA: pair.metricA,
                metricB: pair.metricB
            )
            guard effectResult.percentDiff >= 8.0 else { continue }

            // Update labels if the discovered lag differs from the predefined one
            let effectLabel: String
            if best.lag != pair.dayOffset && best.lag > 0 {
                let baseName = pair.effectLabel.replacingOccurrences(of: " next day", with: "")
                effectLabel = best.lag == 1 ? "\(baseName) next day" : "\(baseName) after \(best.lag) days"
            } else {
                effectLabel = pair.effectLabel
            }

            let strengthLabel = Self.strengthLabel(for: abs(best.r))

            results.append(HealthCorrelation(
                metricA: pair.metricA,
                metricB: pair.metricB,
                correlation: best.r,
                sampleCount: best.aligned.count,
                strengthLabel: strengthLabel,
                causeLabel: pair.causeLabel,
                effectLabel: effectLabel,
                effectSummary: effectResult.summary,
                isPositive: best.r > 0,
                dayOffset: best.lag
            ))
        }

        return results.sorted { abs($0.correlation) > abs($1.correlation) }
    }

    /// Generate top correlation insights (for the Insights list)
    static func generateInsights(from correlations: [HealthCorrelation]) -> [Insight] {
        let topResults = Array(correlations.prefix(3))

        return topResults.map { result in
            let severity: Severity = abs(result.correlation) >= 0.5 ? .warning : .info
            let direction: String = result.isPositive ? "positive" : "inverse"

            return Insight(
                metric: result.metricA,
                title: "\(result.causeLabel) \u{2192} \(result.effectLabel)",
                summary: result.effectSummary,
                recommendation: "Pay attention to your \(result.metricA.displayName.lowercased()) \u{2014} it has a \(direction) correlation with your \(result.metricB.displayName.lowercased()).",
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

    /// Legacy entry point — kept for backward compatibility
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        let correlations = analyzeAll(timeSeries: timeSeries)
        return generateInsights(from: correlations)
    }

    // MARK: - Private

    /// Strength label based on |r|
    private static func strengthLabel(for absR: Double) -> String {
        if absR >= 0.6 { return "Strong" }
        if absR >= 0.4 { return "Moderate" }
        return "Mild"
    }

    private struct EffectResult {
        let percentDiff: Double
        let summary: String
    }

    /// Partition by above/below baseline of metric A, compute average difference in metric B
    private static func computeConditionalEffect(
        aligned: [TimeSeriesAligner.AlignedPair],
        metricA: HealthMetric,
        metricB: HealthMetric
    ) -> EffectResult {
        let aValues = aligned.map(\.valueA)
        let baseline = aValues.mean

        let aboveBaseline = aligned.filter { $0.valueA >= baseline }
        let belowBaseline = aligned.filter { $0.valueA < baseline }

        guard !aboveBaseline.isEmpty, !belowBaseline.isEmpty else {
            return EffectResult(
                percentDiff: 0,
                summary: "\(metricA.displayName) correlates with \(metricB.displayName)."
            )
        }

        let avgBAbove = aboveBaseline.map(\.valueB).mean
        let avgBBelow = belowBaseline.map(\.valueB).mean

        guard avgBBelow != 0 else {
            return EffectResult(
                percentDiff: 0,
                summary: "\(metricA.displayName) correlates with \(metricB.displayName)."
            )
        }

        let percentDiff = ((avgBAbove - avgBBelow) / abs(avgBBelow)) * 100
        let direction = percentDiff > 0 ? "higher" : "lower"
        let absPercent = String(format: "%.0f", abs(percentDiff))

        let summary = "When your \(metricA.displayName.lowercased()) is above average, your \(metricB.displayName.lowercased()) is \(absPercent)% \(direction)."

        return EffectResult(percentDiff: abs(percentDiff), summary: summary)
    }
}
