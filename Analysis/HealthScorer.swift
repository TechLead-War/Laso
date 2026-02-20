import Foundation

/// Computes health scores (0-100) based on anomalies, trends, and normal ranges
struct HealthScorer {

    /// Compute score for a single metric
    static func scoreMetric(
        metric: HealthMetric,
        anomaly: AnomalyDetector.AnomalyResult?,
        trend: TrendAnalyzer.TrendResult?
    ) -> (score: Int, components: [ScoreComponent]) {
        var score = 100
        var components: [ScoreComponent] = []

        // Anomaly deductions
        if let anomaly {
            switch anomaly.severity {
            case .critical:
                let deduction = RulesConfiguration.anomalyCriticalDeduction
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Critical deviation (\(String(format: "%.1f", anomaly.deviationPercent))%) from baseline"
                ))
            case .warning:
                let deduction = RulesConfiguration.anomalyWarningDeduction
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Warning deviation (\(String(format: "%.1f", anomaly.deviationPercent))%) from baseline"
                ))
            case .info:
                break
            }

            if anomaly.outsideNormalRange {
                let deduction = RulesConfiguration.outsideNormalRangeDeduction
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Outside normal population range"
                ))
            }
        }

        // Trend adjustments
        if let trend {
            switch trend.direction {
            case .declining:
                let deduction = abs(trend.weekOverWeekChange) > 10
                    ? RulesConfiguration.strongDecliningTrendDeduction
                    : RulesConfiguration.decliningTrendDeduction
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Declining trend (week-over-week: \(String(format: "%.1f", trend.weekOverWeekChange))%)"
                ))
            case .improving:
                let bonus = RulesConfiguration.improvingTrendBonus
                score += bonus
                components.append(ScoreComponent(
                    metric: metric,
                    points: bonus,
                    reason: "Improving trend"
                ))
            case .stable:
                break
            }
        }

        return (max(0, min(100, score)), components)
    }

    /// Compute category score from metric scores
    static func scoreCategory(
        category: HealthCategory,
        metricScores: [(metric: HealthMetric, score: Int, components: [ScoreComponent])]
    ) -> HealthScore {
        guard !metricScores.isEmpty else {
            return HealthScore(category: category, score: 100)
        }

        let totalScore = metricScores.map(\.score).reduce(0, +)
        let avgScore = totalScore / metricScores.count
        let allComponents = metricScores.flatMap(\.components)

        return HealthScore(category: category, score: avgScore, breakdown: allComponents)
    }

    /// Compute overall score from category scores
    static func overallScore(categoryScores: [HealthScore]) -> HealthScore {
        guard !categoryScores.isEmpty else {
            return HealthScore(score: 100)
        }

        let totalScore = categoryScores.map(\.score).reduce(0, +)
        let avgScore = totalScore / categoryScores.count
        let allComponents = categoryScores.flatMap(\.breakdown)

        return HealthScore(score: avgScore, breakdown: allComponents)
    }
}
