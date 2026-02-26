import Foundation

/// Detects anomalies using z-score analysis against personal baselines.
/// Z-scores adapt to each metric's natural variability — a 10% deviation
/// matters more when σ is small (stable metric) than when σ is large (volatile metric).
struct AnomalyDetector {

    struct AnomalyResult {
        let metric: HealthMetric
        let severity: Severity
        let deviationPercent: Double
        let zScore: Double
        let currentValue: Double
        let baselineValue: Double
        let isAboveBaseline: Bool
        let outsideNormalRange: Bool
        let allTimePercentile: Double   // 0-100: where this value sits in all-time data
    }

    /// Z-score thresholds (adaptive to each metric's variability)
    private static let warningZScore: Double = 1.5
    private static let criticalZScore: Double = 2.5

    /// Check a metric's current value against its baseline using z-score
    static func detect(
        metric: HealthMetric,
        currentValue: Double,
        baseline: UserBaseline
    ) -> AnomalyResult {
        let deviation = baseline.deviationPercent(for: currentValue)

        // Z-score: how many standard deviations from baseline mean
        let zScore: Double
        if baseline.standardDeviation > 0 && baseline.sampleCount >= 7 {
            zScore = (currentValue - baseline.mean) / baseline.standardDeviation
        } else {
            // Fall back to percentage-based when we lack enough data for reliable σ
            zScore = abs(deviation) / 100.0 * 2.0  // map 10%→0.2, 50%→1.0
        }

        let absZ = abs(zScore)

        let severity: Severity
        if absZ >= criticalZScore {
            severity = .critical
        } else if absZ >= warningZScore {
            severity = .warning
        } else {
            severity = .info
        }

        let normalRange = RulesConfiguration.normalRange(for: metric)
        let outsideNormal = !normalRange.contains(currentValue)

        return AnomalyResult(
            metric: metric,
            severity: severity,
            deviationPercent: deviation,
            zScore: zScore,
            currentValue: currentValue,
            baselineValue: baseline.mean,
            isAboveBaseline: currentValue > baseline.mean,
            outsideNormalRange: outsideNormal,
            allTimePercentile: 50  // Default; enriched in detectAll with full series data
        )
    }

    /// Batch detect anomalies for all metrics with available data
    static func detectAll(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [AnomalyResult] {
        var results: [AnomalyResult] = []

        for (metric, series) in timeSeries {
            let recentSamples = series.samples(lastDays: 3)
            guard let baseline = baselines[metric],
                  !recentSamples.isEmpty else {
                continue
            }
            let currentValue = recentSamples.map(\.value).mean

            var result = detect(metric: metric, currentValue: currentValue, baseline: baseline)
            // Enrich with all-time percentile from full historical data
            result = AnomalyResult(
                metric: result.metric,
                severity: result.severity,
                deviationPercent: result.deviationPercent,
                zScore: result.zScore,
                currentValue: result.currentValue,
                baselineValue: result.baselineValue,
                isAboveBaseline: result.isAboveBaseline,
                outsideNormalRange: result.outsideNormalRange,
                allTimePercentile: series.percentile(of: currentValue)
            )
            results.append(result)
        }

        return results.sorted { $0.severity > $1.severity }
    }
}
