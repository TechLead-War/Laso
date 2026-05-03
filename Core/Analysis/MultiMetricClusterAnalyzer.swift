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
                    let dir = item.deviation > 0 ? Copy.Analysis.MultiMetricCluster.directionAbove : Copy.Analysis.MultiMetricCluster.directionBelow
                    return Copy.Analysis.MultiMetricCluster.metricDetail(name: item.metric.displayName, formatted: formatted, unit: item.metric.unit, dev: devStr, dir: dir)
                }
                return Copy.Analysis.MultiMetricCluster.metricDeviation(name: item.metric.displayName, dev: String(format: "%.0f", abs(item.deviation)))
            }.joined(separator: ", ")

            let insight = Insight(
                metric: sorted[0].metric,
                title: Copy.Analysis.MultiMetricCluster.categoryDeclining(category.displayName),
                summary: Copy.Analysis.MultiMetricCluster.clusterSummary(count: decliningMetrics.count, categoryName: category.displayName, details: metricDetails),
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
            summary: Copy.Analysis.MultiMetricCluster.crossCategorySummary(total: totalDeclining, categoryCount: categoriesWithDecline.count, names: categoryNames),
            recommendation: Copy.Analysis.MultiMetricCluster.crossCategoryRecommendation(total: totalDeclining, categoryCount: categoriesWithDecline.count, names: categoryNames),
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
        case .heart:        return Copy.Analysis.MultiMetricCluster.heartCluster(count: count, names: metricNames, dev: devStr)
        case .sleep:        return Copy.Analysis.MultiMetricCluster.sleepCluster(count: count, names: metricNames, dev: devStr)
        case .activity:     return Copy.Analysis.MultiMetricCluster.activityCluster(count: count, names: metricNames, dev: devStr)
        case .body:         return Copy.Analysis.MultiMetricCluster.bodyCluster(count: count, names: metricNames, dev: devStr)
        case .respiratory:  return Copy.Analysis.MultiMetricCluster.respiratoryCluster(count: count, names: metricNames, dev: devStr)
        case .mindfulness:  return Copy.Analysis.MultiMetricCluster.mindfulnessCluster(count: count, names: metricNames, dev: devStr)
        case .mobility:     return Copy.Analysis.MultiMetricCluster.mobilityCluster(count: count, names: metricNames, dev: devStr)
        case .nutrition:    return Copy.Analysis.MultiMetricCluster.nutritionCluster(count: count, names: metricNames, dev: devStr)
        case .hearing:      return Copy.Analysis.MultiMetricCluster.hearingCluster(count: count, names: metricNames, dev: devStr)
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
