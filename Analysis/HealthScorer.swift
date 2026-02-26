import Foundation

/// Computes health scores (0-100) based on anomalies, trends, and normal ranges
struct HealthScorer {

    /// Compute score for a single metric using proportional deductions scaled by z-score magnitude
    static func scoreMetric(
        metric: HealthMetric,
        anomaly: AnomalyDetector.AnomalyResult?,
        trend: TrendAnalyzer.TrendResult?
    ) -> (score: Int, components: [ScoreComponent]) {
        var score = 100
        var components: [ScoreComponent] = []

        // Anomaly deductions — proportional to z-score magnitude
        if let anomaly {
            let absZ = abs(anomaly.zScore)

            switch anomaly.severity {
            case .critical:
                // Scale: z=2.5 → -30, z=3.0 → -36, z=4.0 → -48 (capped at -50)
                let deduction = -min(50, Int(absZ * 12))
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Critical deviation (z=\(String(format: "%.1f", absZ)), \(String(format: "%.1f", anomaly.deviationPercent))% from baseline)"
                ))
            case .warning:
                // Scale: z=1.5 → -12, z=2.0 → -16, z=2.4 → -19
                let deduction = -min(25, Int(absZ * 8))
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Warning deviation (z=\(String(format: "%.1f", absZ)), \(String(format: "%.1f", anomaly.deviationPercent))% from baseline)"
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

        // Trend adjustments — proportional to rate of change
        if let trend {
            switch trend.direction {
            case .declining:
                let absWoW = abs(trend.weekOverWeekChange)
                // Scale: 2% → -5, 5% → -8, 10% → -15, 20% → -25 (capped at -30)
                let deduction = -min(30, Int(absWoW * 1.3 + 2))
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "\(trend.rateOfChange.displayLabel.capitalized) declining (\(String(format: "%.1f", trend.weekOverWeekChange))% week-over-week)"
                ))
            case .improving:
                let absWoW = abs(trend.weekOverWeekChange)
                // Improving bonus scales too: 2% → +3, 5% → +5, 10%+ → +8
                let bonus = min(8, Int(absWoW * 0.6 + 2))
                score += bonus
                components.append(ScoreComponent(
                    metric: metric,
                    points: bonus,
                    reason: "\(trend.rateOfChange.displayLabel.capitalized) improving"
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
        let avgScore = Int((Double(totalScore) / Double(metricScores.count)).rounded())
        let allComponents = metricScores.flatMap(\.components)

        return HealthScore(category: category, score: avgScore, breakdown: allComponents)
    }

    /// Compute overall score from category scores
    static func overallScore(categoryScores: [HealthScore]) -> HealthScore {
        guard !categoryScores.isEmpty else {
            return HealthScore(score: 100)
        }

        let totalScore = categoryScores.map(\.score).reduce(0, +)
        let avgScore = Int((Double(totalScore) / Double(categoryScores.count)).rounded())
        let allComponents = categoryScores.flatMap(\.breakdown)

        return HealthScore(score: avgScore, breakdown: allComponents)
    }
}
