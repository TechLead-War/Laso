import Foundation

/// Computes health scores (0-100) based on anomalies, trends, and normal ranges.
/// Supports both equal weighting (legacy) and adaptive weighting (WHOOP 5.0-style).
struct HealthScorer {

    // MARK: - Score Transparency Models

    /// Explains how the overall score was computed, including per-category weights and top factors
    struct ScoreExplanation {
        let totalScore: Int
        let categoryContributions: [CategoryContribution]
        let topFactors: [ScoreFactor]  // top 3 factors affecting score
    }

    /// A single category's weighted contribution to the overall score
    struct CategoryContribution {
        let category: HealthCategory
        let score: Int
        let weight: Double  // 0-1
        let weightedContribution: Double  // score * weight
    }

    /// A single metric-level factor that moved the score up or down
    struct ScoreFactor {
        let metric: HealthMetric
        let impact: Int  // positive or negative points
        let reason: String  // e.g. "HRV dropped 15% this week"
        let isPositive: Bool
    }

    // MARK: - Metric Scoring (unchanged)

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

    // MARK: - Category Scoring

    /// Compute category score from metric scores (equal weighting — backward compatible)
    static func scoreCategory(
        category: HealthCategory,
        metricScores: [(metric: HealthMetric, score: Int, components: [ScoreComponent])]
    ) -> HealthScore {
        return scoreCategory(category: category, metricScores: metricScores, metricWeights: nil)
    }

    /// Compute category score from metric scores with optional per-metric weights.
    /// When metricWeights is nil, falls back to equal weighting.
    static func scoreCategory(
        category: HealthCategory,
        metricScores: [(metric: HealthMetric, score: Int, components: [ScoreComponent])],
        metricWeights: [HealthMetric: Double]?
    ) -> HealthScore {
        guard !metricScores.isEmpty else {
            return HealthScore(category: category, score: 100)
        }

        let avgScore: Int
        if let weights = metricWeights {
            // Weighted average using provided per-metric weights
            var weightedSum = 0.0
            var totalWeight = 0.0
            for ms in metricScores {
                let w = weights[ms.metric] ?? 1.0
                weightedSum += Double(ms.score) * w
                totalWeight += w
            }
            avgScore = totalWeight > 0
                ? Int((weightedSum / totalWeight).rounded())
                : Int((Double(metricScores.map(\.score).reduce(0, +)) / Double(metricScores.count)).rounded())
        } else {
            // Equal weighting (original behavior)
            let totalScore = metricScores.map(\.score).reduce(0, +)
            avgScore = Int((Double(totalScore) / Double(metricScores.count)).rounded())
        }

        let allComponents = metricScores.flatMap(\.components)
        return HealthScore(category: category, score: avgScore, breakdown: allComponents)
    }

    // MARK: - Overall Score

    /// Compute overall score from category scores (backward compatible — equal weighting)
    static func overallScore(categoryScores: [HealthScore]) -> HealthScore {
        return overallScore(categoryScores: categoryScores, weights: nil)
    }

    /// Compute overall score from category scores with optional adaptive weights.
    /// When weights is nil, falls back to equal weighting (backward compatible).
    static func overallScore(
        categoryScores: [HealthScore],
        weights: [HealthCategory: Double]?
    ) -> HealthScore {
        guard !categoryScores.isEmpty else {
            return HealthScore(score: 100)
        }

        let avgScore: Int
        if let weights {
            // Weighted average using adaptive category weights
            var weightedSum = 0.0
            var totalWeight = 0.0
            for cs in categoryScores {
                guard let cat = cs.category else { continue }
                let w = weights[cat] ?? (1.0 / Double(categoryScores.count))
                weightedSum += Double(cs.score) * w
                totalWeight += w
            }
            // Normalize in case weights don't perfectly sum to 1.0 for the present categories
            avgScore = totalWeight > 0
                ? Int((weightedSum / totalWeight).rounded())
                : Int((Double(categoryScores.map(\.score).reduce(0, +)) / Double(categoryScores.count)).rounded())
        } else {
            // Equal weighting (original behavior)
            let totalScore = categoryScores.map(\.score).reduce(0, +)
            avgScore = Int((Double(totalScore) / Double(categoryScores.count)).rounded())
        }

        let allComponents = categoryScores.flatMap(\.breakdown)
        return HealthScore(score: avgScore, breakdown: allComponents)
    }

    // MARK: - Adaptive Category Weights

    /// Compute dynamic per-category weights based on baseline volatility, data richness,
    /// and anomaly density. Categories that carry more signal get higher weight.
    ///
    /// Weight formula per category:
    ///   rawWeight = volatilityFactor + richnessFactor + anomalyFactor
    /// All weights are normalized to sum to 1.0, with a 0.05 floor per category.
    static func adaptiveCategoryWeights(
        categoryScores: [HealthScore],
        anomalies: [AnomalyDetector.AnomalyResult],
        baselines: [HealthMetric: UserBaseline]
    ) -> [HealthCategory: Double] {
        let presentCategories = categoryScores.compactMap(\.category)
        guard !presentCategories.isEmpty else { return [:] }

        // Group baselines and anomalies by category
        let baselinesByCategory = Dictionary(grouping: baselines.values, by: { $0.metric.category })
        let anomaliesByCategory = Dictionary(grouping: anomalies, by: { $0.metric.category })

        var rawWeights: [HealthCategory: Double] = [:]

        for category in presentCategories {
            let categoryBaselines = baselinesByCategory[category] ?? []
            let categoryAnomalies = anomaliesByCategory[category] ?? []

            // --- Factor 1: Baseline volatility (coefficient of variation) ---
            // Higher CV = more variable = more informational signal.
            // Average the CV across metrics in this category.
            var avgCV = 0.0
            if !categoryBaselines.isEmpty {
                let cvValues = categoryBaselines.compactMap { baseline -> Double? in
                    guard baseline.mean != 0 else { return nil }
                    return baseline.standardDeviation / abs(baseline.mean)
                }
                avgCV = cvValues.isEmpty ? 0.0 : cvValues.reduce(0, +) / Double(cvValues.count)
            }
            // Normalize: CV of 0.0 → 0.5, CV of 0.1 → 1.0, CV of 0.3+ → 2.0 (capped)
            let volatilityFactor = min(2.0, 0.5 + avgCV * 5.0)

            // --- Factor 2: Data richness (number of measured metrics) ---
            // More metrics measured = richer signal for this category.
            let metricCount = Double(categoryBaselines.count)
            let totalMetricsInCategory = Double(category.metrics.count)
            // Coverage ratio: 0-1 representing how many of the possible metrics have data
            let coverage = totalMetricsInCategory > 0 ? metricCount / totalMetricsInCategory : 0.0
            // Scale: 0% coverage → 0.3, 50% → 0.65, 100% → 1.0
            let richnessFactor = 0.3 + coverage * 0.7

            // --- Factor 3: Anomaly density (active anomalies / measured metrics) ---
            // More anomalies = more relevant to current health state.
            let activeAnomalies = categoryAnomalies.filter { $0.severity != .info }
            let anomalyDensity = metricCount > 0 ? Double(activeAnomalies.count) / metricCount : 0.0
            // Scale: 0 anomalies → 0.5, 50% density → 1.25, 100% density → 2.0
            let anomalyFactor = 0.5 + anomalyDensity * 1.5

            rawWeights[category] = volatilityFactor + richnessFactor + anomalyFactor
        }

        // Apply minimum floor of 0.05 per category, then normalize to sum to 1.0
        return normalizeWeights(rawWeights, minimumWeight: 0.05)
    }

    // MARK: - Adaptive Metric Weights Within Category

    /// Compute per-metric weights within a category based on coefficient of variation
    /// and data freshness. More variable and fresher metrics carry more weight.
    static func adaptiveMetricWeights(
        for metrics: [HealthMetric],
        baselines: [HealthMetric: UserBaseline]
    ) -> [HealthMetric: Double] {
        guard !metrics.isEmpty else { return [:] }

        let now = Date()
        var rawWeights: [HealthMetric: Double] = [:]

        for metric in metrics {
            guard let baseline = baselines[metric] else {
                // No baseline → minimal weight (will be floored)
                rawWeights[metric] = 0.1
                continue
            }

            // --- Factor 1: Coefficient of variation ---
            let cv: Double
            if baseline.mean != 0 {
                cv = baseline.standardDeviation / abs(baseline.mean)
            } else {
                cv = 0.0
            }
            // Scale: CV of 0 → 0.5, CV of 0.1 → 1.0, CV of 0.3+ → 2.0 (capped)
            let variabilityFactor = min(2.0, 0.5 + cv * 5.0)

            // --- Factor 2: Data freshness ---
            // How recently was the baseline updated? More recent = higher weight.
            let daysSinceUpdate = Calendar.current.dateComponents([.day], from: baseline.lastUpdated, to: now).day ?? 0
            // Scale: 0 days → 1.0, 7 days → 0.7, 30+ days → 0.3
            let freshnessFactor: Double
            if daysSinceUpdate <= 1 {
                freshnessFactor = 1.0
            } else if daysSinceUpdate <= 7 {
                freshnessFactor = 1.0 - Double(daysSinceUpdate - 1) * 0.05  // 1.0 → 0.7
            } else {
                freshnessFactor = max(0.3, 0.7 - Double(daysSinceUpdate - 7) * 0.017)  // 0.7 → 0.3 over ~24 days
            }

            rawWeights[metric] = variabilityFactor * freshnessFactor
        }

        // Normalize to sum to 1.0 with a small floor per metric
        let minWeight = 1.0 / (Double(metrics.count) * 5.0)  // at least 20% of equal share
        return normalizeWeights(rawWeights, minimumWeight: max(0.02, minWeight))
    }

    // MARK: - Score Explanation

    /// Produce a transparent explanation of how the overall score was computed,
    /// including per-category contributions and the top 3 factors affecting the score.
    static func explainOverallScore(
        categoryScores: [HealthScore],
        weights: [HealthCategory: Double],
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> ScoreExplanation {
        // Build category contributions
        var contributions: [CategoryContribution] = []
        var totalWeightedScore = 0.0
        var totalWeight = 0.0

        for cs in categoryScores {
            guard let cat = cs.category else { continue }
            let w = weights[cat] ?? (1.0 / Double(categoryScores.count))
            let weighted = Double(cs.score) * w
            contributions.append(CategoryContribution(
                category: cat,
                score: cs.score,
                weight: w,
                weightedContribution: weighted
            ))
            totalWeightedScore += weighted
            totalWeight += w
        }

        let totalScore = totalWeight > 0
            ? Int((totalWeightedScore / totalWeight).rounded())
            : 100

        // Sort contributions by weighted impact (highest first)
        contributions.sort { $0.weightedContribution > $1.weightedContribution }

        // Build score factors from anomalies and trends
        var factors: [ScoreFactor] = []

        // Anomaly-based factors
        for anomaly in anomalies where anomaly.severity != .info {
            let absDeviation = abs(anomaly.deviationPercent)
            let direction = anomaly.isAboveBaseline ? "rose" : "dropped"
            let impact: Int
            switch anomaly.severity {
            case .critical:
                impact = -min(50, Int(abs(anomaly.zScore) * 12))
            case .warning:
                impact = -min(25, Int(abs(anomaly.zScore) * 8))
            case .info:
                impact = 0
            }

            factors.append(ScoreFactor(
                metric: anomaly.metric,
                impact: impact,
                reason: "\(anomaly.metric.displayName) \(direction) \(String(format: "%.0f", absDeviation))% from baseline",
                isPositive: false
            ))
        }

        // Trend-based factors
        for (metric, trend) in trends {
            switch trend.direction {
            case .declining:
                let absWoW = abs(trend.weekOverWeekChange)
                let impact = -min(30, Int(absWoW * 1.3 + 2))
                factors.append(ScoreFactor(
                    metric: metric,
                    impact: impact,
                    reason: "\(metric.displayName) \(trend.rateOfChange.displayLabel) declining (\(String(format: "%.1f", absWoW))% WoW)",
                    isPositive: false
                ))
            case .improving:
                let absWoW = abs(trend.weekOverWeekChange)
                let impact = min(8, Int(absWoW * 0.6 + 2))
                factors.append(ScoreFactor(
                    metric: metric,
                    impact: impact,
                    reason: "\(metric.displayName) \(trend.rateOfChange.displayLabel) improving",
                    isPositive: true
                ))
            case .stable:
                break
            }
        }

        // Deduplicate: if a metric has both an anomaly factor and a trend factor,
        // keep only the one with the larger absolute impact
        var bestFactorByMetric: [HealthMetric: ScoreFactor] = [:]
        for factor in factors {
            if let existing = bestFactorByMetric[factor.metric] {
                if abs(factor.impact) > abs(existing.impact) {
                    bestFactorByMetric[factor.metric] = factor
                }
            } else {
                bestFactorByMetric[factor.metric] = factor
            }
        }

        // Sort by absolute impact (largest first), take top 3
        let topFactors = Array(
            bestFactorByMetric.values
                .sorted { abs($0.impact) > abs($1.impact) }
                .prefix(3)
        )

        return ScoreExplanation(
            totalScore: totalScore,
            categoryContributions: contributions,
            topFactors: topFactors
        )
    }

    // MARK: - Private Helpers

    /// Normalize a dictionary of raw weights to sum to 1.0, enforcing a minimum floor per key.
    private static func normalizeWeights<K: Hashable>(
        _ rawWeights: [K: Double],
        minimumWeight: Double
    ) -> [K: Double] {
        guard !rawWeights.isEmpty else { return [:] }

        let count = rawWeights.count
        let totalMinimum = minimumWeight * Double(count)

        // If the floor alone exceeds 1.0 (too many categories), just use equal weights
        if totalMinimum >= 1.0 {
            let equal = 1.0 / Double(count)
            return rawWeights.mapValues { _ in equal }
        }

        // First pass: normalize raw weights to sum to 1.0
        let rawSum = rawWeights.values.reduce(0, +)
        guard rawSum > 0 else {
            let equal = 1.0 / Double(count)
            return rawWeights.mapValues { _ in equal }
        }

        var normalized = rawWeights.mapValues { $0 / rawSum }

        // Second pass: enforce minimum floor
        let distributableWeight = 1.0 - totalMinimum
        var belowFloor: [K] = []
        var aboveFloorSum = 0.0

        for (key, weight) in normalized {
            if weight < minimumWeight {
                belowFloor.append(key)
            } else {
                aboveFloorSum += weight
            }
        }

        if !belowFloor.isEmpty && aboveFloorSum > 0 {
            // Set below-floor keys to the minimum
            for key in belowFloor {
                normalized[key] = minimumWeight
            }
            // Re-distribute the remaining weight proportionally among above-floor keys
            let aboveFloorKeys = normalized.keys.filter { !belowFloor.contains($0) }
            let scaleFactor = distributableWeight / aboveFloorSum
            for key in aboveFloorKeys {
                // Use the original normalized weight (before floor adjustments) for proportional scaling
                if let original = normalized[key] {
                    normalized[key] = original * scaleFactor
                }
            }
        }

        // Final normalization pass to handle any floating-point drift
        let finalSum = normalized.values.reduce(0, +)
        if finalSum > 0 && abs(finalSum - 1.0) > 0.001 {
            normalized = normalized.mapValues { $0 / finalSum }
        }

        return normalized
    }
}
