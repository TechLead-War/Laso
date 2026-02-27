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
                title: "\(category.displayName): Multiple Metrics Declining",
                summary: "\(decliningMetrics.count) metrics declining together in \(category.displayName): \(metricDetails).",
                recommendation: recommendationForCluster(category: category, count: decliningMetrics.count),
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
            title: "Widespread Health Decline",
            summary: "\(totalDeclining) metrics across \(categoriesWithDecline.count) categories are declining: \(categoryNames). This may indicate a systemic issue like poor sleep, high stress, or illness.",
            recommendation: "When declines span multiple categories, look for a root cause: Are you sleeping enough? Under unusual stress? Coming down with something? Address the root cause rather than individual metrics.",
            severity: .warning,
            trend: .declining,
            currentValue: Double(totalDeclining),
            baselineValue: 0,
            deviationPercent: Double(totalDeclining * 10),
            category: .multiMetricCluster
        )
    }

    // MARK: - Cluster Recommendations

    private static func recommendationForCluster(category: HealthCategory, count: Int) -> String {
        switch category {
        case .heart:
            return "Multiple heart metrics declining together warrants attention. Prioritize stress reduction, quality sleep, and moderate cardio. If symptoms persist, consult your doctor."
        case .sleep:
            return "Your sleep profile is deteriorating across \(count) dimensions. Set a strict bedtime, reduce screen time 1 hour before bed, and keep your bedroom cool and dark."
        case .activity:
            return "Activity levels are dropping across the board. Start with a 15-minute walk daily and build from there. Consistency matters more than intensity."
        case .body:
            return "Multiple body composition metrics shifting together. Review your nutrition habits and ensure you're eating enough protein and maintaining consistent meal timing."
        case .respiratory:
            return "Multiple respiratory metrics declining simultaneously. Monitor for illness symptoms. If you're congested or coughing, rest and hydrate."
        case .mindfulness:
            return "Stress and mindfulness metrics are declining together. Build in 10 minutes of intentional breathing or meditation daily."
        case .mobility:
            return "Multiple mobility metrics declining together. Prioritize stretching, balance exercises, and regular walking to maintain functional fitness."
        }
    }
}
