import Foundation

/// Detects anomalies by comparing current values to personal baselines
struct AnomalyDetector {

    struct AnomalyResult {
        let metric: HealthMetric
        let severity: Severity
        let deviationPercent: Double
        let currentValue: Double
        let baselineValue: Double
        let isAboveBaseline: Bool
        let outsideNormalRange: Bool
    }

    /// Check a metric's current value against its baseline
    static func detect(
        metric: HealthMetric,
        currentValue: Double,
        baseline: UserBaseline
    ) -> AnomalyResult {
        let deviation = baseline.deviationPercent(for: currentValue)
        let absDeviation = abs(deviation) / 100.0

        let severity: Severity
        if absDeviation >= RulesConfiguration.criticalDeviationThreshold {
            severity = .critical
        } else if absDeviation >= RulesConfiguration.warningDeviationThreshold {
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
            currentValue: currentValue,
            baselineValue: baseline.mean,
            isAboveBaseline: currentValue > baseline.mean,
            outsideNormalRange: outsideNormal
        )
    }

    /// Batch detect anomalies for all metrics with available data
    static func detectAll(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [AnomalyResult] {
        var results: [AnomalyResult] = []

        for (metric, series) in timeSeries {
            guard let baseline = baselines[metric],
                  let currentValue = series.mean(lastDays: 3) as Double?,
                  currentValue > 0 else {
                continue
            }

            let result = detect(metric: metric, currentValue: currentValue, baseline: baseline)
            results.append(result)
        }

        return results.sorted { $0.severity > $1.severity }
    }
}
