import Foundation

/// Synthesizes analysis results into prioritized actionable insights
struct InsightGenerator {

    /// Generate insights from anomalies and trends with inflection-aware context
    static func generate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Insight] {
        var insights: [Insight] = []

        for anomaly in anomalies {
            let trendResult = trends[anomaly.metric]
            let trend = trendResult?.direction ?? .stable
            let rateOfChange = trendResult?.rateOfChange ?? .negligible
            let inflection = trendResult?.inflection ?? .steady

            // Only generate insights for non-trivial findings
            guard anomaly.severity >= .warning || trend == .declining else { continue }

            // Escalate severity for rapid changes or accelerating declines
            let effectiveSeverity: Severity
            if rateOfChange == .rapid && anomaly.severity == .warning {
                effectiveSeverity = .critical
            } else if inflection == .accelerating && trend == .declining && anomaly.severity == .warning {
                effectiveSeverity = .critical
            } else {
                effectiveSeverity = anomaly.severity
            }

            let insight = createInsight(
                metric: anomaly.metric,
                severity: effectiveSeverity,
                trend: trend,
                rateOfChange: rateOfChange,
                inflection: inflection,
                currentValue: anomaly.currentValue,
                baselineValue: anomaly.baselineValue,
                deviationPercent: anomaly.deviationPercent
            )
            insights.append(insight)
        }

        // Also check for declining trends without anomalies
        for (metric, trendResult) in trends {
            guard trendResult.direction == .declining else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .declining,
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            )
            insights.append(insight)
        }

        // Add positive insights for significantly improving metrics
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
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            )
            insights.append(insight)
        }

        // Add reversal insights — these are high-signal events worth surfacing
        for (metric, trendResult) in trends {
            guard trendResult.inflection == .reversing else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)
            let isPositiveReversal = (trendResult.direction == .improving)

            insights.append(Insight(
                metric: metric,
                title: "\(metric.displayName) \(isPositiveReversal ? "Turning Around" : "Reversing Course")",
                summary: "Your \(metric.displayName.lowercased()) trend has reversed direction in the past week. \(isPositiveReversal ? "Previous decline is now recovering." : "Previous improvement is now declining.")",
                recommendation: isPositiveReversal
                    ? "Good news — your \(metric.displayName.lowercased()) is recovering. Keep doing what you changed recently."
                    : "Your \(metric.displayName.lowercased()) was improving but is now declining. Review any recent changes to your routine.",
                severity: isPositiveReversal ? .info : .warning,
                trend: trendResult.direction,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            ))
        }

        // Sort by priority
        return insights.sorted { $0.priorityScore > $1.priorityScore }
    }

    private static func createInsight(
        metric: HealthMetric,
        severity: Severity,
        trend: TrendDirection,
        rateOfChange: TrendAnalyzer.RateOfChange = .negligible,
        inflection: TrendAnalyzer.Inflection = .steady,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double
    ) -> Insight {
        let title = generateTitle(metric: metric, trend: trend, severity: severity, rateOfChange: rateOfChange, inflection: inflection)
        let summary = generateSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend,
            inflection: inflection
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

    private static func generateTitle(
        metric: HealthMetric,
        trend: TrendDirection,
        severity: Severity,
        rateOfChange: TrendAnalyzer.RateOfChange = .negligible,
        inflection: TrendAnalyzer.Inflection = .steady
    ) -> String {
        let metricName = metric.displayName
        let ratePrefix = rateOfChange >= .moderate ? "\(rateOfChange.displayLabel.capitalized) " : ""
        let inflectionSuffix: String
        switch inflection {
        case .accelerating where trend == .declining: inflectionSuffix = " & Accelerating"
        case .decelerating where trend == .declining: inflectionSuffix = " (Slowing)"
        case .reversing: inflectionSuffix = " — Reversing"
        default: inflectionSuffix = ""
        }

        switch (trend, severity) {
        case (.declining, .critical): return "\(metricName) Critically Low\(inflectionSuffix)"
        case (.declining, .warning): return "\(metricName) \(ratePrefix)Needs Attention\(inflectionSuffix)"
        case (.declining, .info): return "\(metricName) \(ratePrefix)Declining\(inflectionSuffix)"
        case (.improving, _): return "\(metricName) \(ratePrefix)Improving\(inflection == .accelerating ? " & Gaining Momentum" : "")"
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
        trend: TrendDirection,
        inflection: TrendAnalyzer.Inflection = .steady
    ) -> String {
        let formattedCurrent = formatValue(currentValue, metric: metric)
        let formattedBaseline = formatValue(baselineValue, metric: metric)
        let absDeviation = String(format: "%.1f", abs(deviationPercent))
        let direction = deviationPercent > 0 ? "above" : "below"

        let inflectionNote: String
        switch inflection {
        case .accelerating: inflectionNote = " The rate of change is accelerating."
        case .decelerating: inflectionNote = " The decline is slowing — a recovery may be starting."
        case .reversing: inflectionNote = " The trend has recently reversed direction."
        case .steady: inflectionNote = ""
        }

        switch trend {
        case .declining:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit)). Current: \(formattedCurrent) \(metric.unit).\(inflectionNote)"
        case .improving:
            return "Your \(metric.displayName.lowercased()) has improved \(absDeviation)% from your baseline. Current: \(formattedCurrent) \(metric.unit).\(inflectionNote)"
        case .stable:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit))."
        }
    }

    private static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        metric.formatValue(value)
    }
}
