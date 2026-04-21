import Foundation

/// Detects when multiple metrics decline together, indicating compound health issues.
/// A cluster of 3+ declining metrics in the same category is a stronger signal than any single decline.
struct MultiMetricClusterAnalyzer {

    /// Generate cluster insights from current anomalies and trends, with optional baselines for actual values
    static func generateInsights(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline] = [:]
    ) -> [Insight] {
        var insights: [Insight] = []

        // 1. Category-level clusters: 3+ declining metrics in same category
        if let categoryCluster = detectCategoryClusters(anomalies: anomalies, trends: trends, baselines: baselines) {
            insights.append(contentsOf: categoryCluster)
        }

        // 2. Cross-category compound decline: declines across 3+ different categories
        if let crossCategory = detectCrossCategoryDecline(trends: trends) {
            insights.append(crossCategory)
        }

        return insights
    }

    // MARK: - Category Clusters

    private static func detectCategoryClusters(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline] = [:]
    ) -> [Insight]? {
        // Group declining metrics by category
        var decliningByCategory: [HealthCategory: [(metric: HealthMetric, severity: Severity, deviation: Double)]] = [:]

        for (metric, trend) in trends {
            guard trend.direction == .declining else { continue }

            let severity: Severity
            let deviation: Double
            if let anomaly = anomalies.first(where: { $0.metric == metric }) {
                severity = anomaly.severity
                deviation = anomaly.deviationPercent
            } else {
                severity = .info
                deviation = trend.weekOverWeekChange
            }

            decliningByCategory[metric.category, default: []].append(
                (metric: metric, severity: severity, deviation: deviation)
            )
        }

        var insights: [Insight] = []

        for (category, decliningMetrics) in decliningByCategory {
            guard decliningMetrics.count >= 3 else { continue }

            let sorted = decliningMetrics.sorted { $0.severity > $1.severity }
            let worstSeverity = sorted.first?.severity ?? .warning
            let avgDeviation = sorted.map { abs($0.deviation) }.reduce(0, +) / Double(sorted.count)

            // Build detailed metric descriptions with actual values and baseline deviations
            let metricDetails = sorted.prefix(4).map { item -> String in
                if let baseline = baselines[item.metric] {
                    let currentValue = baseline.mean * (1.0 + item.deviation / 100.0)
                    let formatted = item.metric.formatValue(currentValue)
                    let devStr = String(format: "%.0f", abs(item.deviation))
                    let dir = item.deviation > 0 ? "above" : "below"
                    return "\(item.metric.displayName): \(formatted) \(item.metric.unit) (\(devStr)% \(dir) baseline)"
                }
                return "\(item.metric.displayName) (\(String(format: "%.0f", abs(item.deviation)))% deviation)"
            }.joined(separator: ", ")

            let insight = Insight(
                metric: sorted[0].metric,
                title: Copy.Analysis.MultiMetricCluster.categoryDeclining(category.displayName),
                summary: "\(decliningMetrics.count) metrics declining together in \(category.displayName): \(metricDetails).",
                recommendation: recommendationForCluster(category: category, count: decliningMetrics.count, avgDeviation: avgDeviation, metrics: sorted.map(\.metric)),
                severity: worstSeverity >= .warning ? .critical : .warning,
                trend: .declining,
                currentValue: avgDeviation,
                baselineValue: 0,
                deviationPercent: avgDeviation,
                category: .multiMetricCluster,
                relatedMetrics: sorted.map(\.metric)
            )
            insights.append(insight)
        }

        return insights.isEmpty ? nil : insights
    }

    // MARK: - Cross-Category Decline

    private static func detectCrossCategoryDecline(
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        // Count categories with any declining metric
        var categoriesWithDecline: Set<HealthCategory> = []
        var totalDeclining = 0

        for (metric, trend) in trends {
            guard trend.direction == .declining else { continue }
            categoriesWithDecline.insert(metric.category)
            totalDeclining += 1
        }

        guard categoriesWithDecline.count >= 3 else { return nil }

        let categoryNames = categoriesWithDecline.prefix(4).map(\.displayName).joined(separator: ", ")

        return Insight(
            metric: .restingHeartRate,
            title: Copy.Analysis.MultiMetricCluster.widespreadHealthDecline,
            summary: "\(totalDeclining) metrics across \(categoriesWithDecline.count) categories are declining: \(categoryNames).",
            recommendation: "\(totalDeclining) metrics declining across \(categoriesWithDecline.count) categories: \(categoryNames).",
            severity: .warning,
            trend: .declining,
            currentValue: Double(totalDeclining),
            baselineValue: 0,
            deviationPercent: Double(totalDeclining * 10),
            category: .multiMetricCluster
        )
    }

    // MARK: - Cluster Recommendations

    private static func recommendationForCluster(category: HealthCategory, count: Int, avgDeviation: Double, metrics: [HealthMetric]) -> String {
        let devStr = String(format: "%.0f", avgDeviation)
        let metricNames = metrics.prefix(4).map(\.displayName).joined(separator: ", ")
        switch category {
        case .heart:
            return "Multiple heart metrics declining simultaneously \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% below baseline."
        case .sleep:
            return "Sleep deteriorating across \(count) dimensions \u{2014} \(metricNames). Avg \(devStr)% below baseline."
        case .activity:
            return "Activity declining across \(count) metrics \u{2014} \(metricNames). Avg \(devStr)% below baseline."
        case .body:
            return "Body composition metrics shifting \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% from baseline."
        case .respiratory:
            return "Respiratory metrics elevated \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% from baseline."
        case .mindfulness:
            return "Mindfulness metrics declining \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% below baseline."
        case .mobility:
            return "Mobility metrics declining across \(count) indicators \u{2014} \(metricNames). Avg \(devStr)% below baseline."
        case .nutrition:
            return "Nutrition metrics shifted from baseline \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% from baseline."
        case .hearing:
            return "Hearing metrics changed \u{2014} \(count) metrics affected: \(metricNames). Avg \(devStr)% from baseline."
        }
    }
}

// MARK: - InsightAnalyzer Conformance

extension MultiMetricClusterAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "multiMetricCluster" }
    static var insightCategory: InsightCategory { .multiMetricCluster }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(
            anomalies: context.anomalies,
            trends: context.trends,
            baselines: context.baselines
        )
    }
}
