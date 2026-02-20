import Foundation

/// Synthesizes analysis results into prioritized actionable insights
struct InsightGenerator {

    /// Generate insights from anomalies and trends
    static func generate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Insight] {
        var insights: [Insight] = []

        for anomaly in anomalies {
            let trend = trends[anomaly.metric]?.direction ?? .stable

            // Only generate insights for non-trivial findings
            guard anomaly.severity >= .warning || trend == .declining else { continue }

            let insight = createInsight(
                metric: anomaly.metric,
                severity: anomaly.severity,
                trend: trend,
                currentValue: anomaly.currentValue,
                baselineValue: anomaly.baselineValue,
                deviationPercent: anomaly.deviationPercent
            )
            insights.append(insight)
        }

        // Also check for declining trends without anomalies
        for (metric, trendResult) in trends {
            guard trendResult.direction == .declining else { continue }

            // Skip if we already generated an insight from anomaly detection
            guard !insights.contains(where: { $0.metric == metric }) else { continue }

            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .declining,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            )
            insights.append(insight)
        }

        // Also add positive insights for significantly improving metrics
        for (metric, trendResult) in trends {
            guard trendResult.direction == .improving,
                  abs(trendResult.weekOverWeekChange) > 5 else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .improving,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            )
            insights.append(insight)
        }

        // Sort by priority
        return insights.sorted { $0.priorityScore > $1.priorityScore }
    }

    private static func createInsight(
        metric: HealthMetric,
        severity: Severity,
        trend: TrendDirection,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double
    ) -> Insight {
        let title = generateTitle(metric: metric, trend: trend, severity: severity)
        let summary = generateSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend
        )
        let recommendation = RulesConfiguration.recommendation(for: metric, severity: severity, trend: trend)

        return Insight(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent
        )
    }

    private static func generateTitle(metric: HealthMetric, trend: TrendDirection, severity: Severity) -> String {
        let metricName = metric.displayName
        switch (trend, severity) {
        case (.declining, .critical): return "\(metricName) Critically Low" + (metric.higherIsBetter ? "" : " — Elevated")
        case (.declining, .warning): return "\(metricName) Needs Attention"
        case (.declining, .info): return "\(metricName) Declining"
        case (.improving, _): return "\(metricName) Improving"
        case (.stable, .critical): return "\(metricName) Outside Safe Range"
        case (.stable, .warning): return "\(metricName) Elevated"
        case (.stable, .info): return "\(metricName) Stable"
        }
    }

    private static func generateSummary(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        trend: TrendDirection
    ) -> String {
        let formattedCurrent = formatValue(currentValue, metric: metric)
        let formattedBaseline = formatValue(baselineValue, metric: metric)
        let absDeviation = String(format: "%.1f", abs(deviationPercent))
        let direction = deviationPercent > 0 ? "above" : "below"

        switch trend {
        case .declining:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit)). Current: \(formattedCurrent) \(metric.unit)."
        case .improving:
            return "Your \(metric.displayName.lowercased()) has improved \(absDeviation)% from your baseline. Current: \(formattedCurrent) \(metric.unit)."
        case .stable:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit))."
        }
    }

    private static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps, .activeCalories, .basalCalories:
            return String(format: "%.0f", value)
        case .bloodOxygen, .bodyFatPercentage, .walkingAsymmetry:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
}
