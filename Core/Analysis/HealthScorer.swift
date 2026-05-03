import Foundation

/// Computes health scores (0-100) based on anomalies, trends, and normal ranges.
/// Uses adaptive weighting that promotes high-signal categories and damps stale ones.
/// Deduction ladders, adaptive-weight factors, and the coverage curve live in
/// `HealthScorerConfig`.
struct HealthScorer {

    private typealias Cfg = HealthScorerConfig

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
        var score = Cfg.perfectScore
        var components: [ScoreComponent] = []

        if let anomaly {
            let absZ = abs(anomaly.zScore)

            switch anomaly.severity {
            case .critical:
                let deduction = -min(Cfg.criticalDeductionCap, Int(absZ * Cfg.criticalDeductionPerZ))
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "Critical deviation (z=\(String(format: "%.1f", absZ)), \(String(format: "%.1f", anomaly.deviationPercent))% from baseline)"
                ))
            case .warning:
                let deduction = -min(Cfg.warningDeductionCap, Int(absZ * Cfg.warningDeductionPerZ))
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

        if let trend {
            switch trend.direction {
            case .declining:
                let absWoW = abs(trend.weekOverWeekChange)
                let deduction = -min(Cfg.decliningDeductionCap, Int(absWoW * Cfg.decliningDeductionPerPercent + Cfg.decliningDeductionOffset))
                score += deduction
                components.append(ScoreComponent(
                    metric: metric,
                    points: deduction,
                    reason: "\(trend.rateOfChange.displayLabel.capitalized) declining (\(String(format: "%.1f", trend.weekOverWeekChange))% week-over-week)"
                ))
            case .improving:
                let absWoW = abs(trend.weekOverWeekChange)
                let bonus = min(Cfg.improvingBonusCap, Int(absWoW * Cfg.improvingBonusPerPercent + Cfg.improvingBonusOffset))
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

        return (max(Cfg.minScore, min(Cfg.perfectScore, score)), components)
    }

    // MARK: - Category Scoring

    /// Compute category score from metric scores (equal weighting. backward compatible)
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
            return HealthScore(category: category, score: Cfg.perfectScore)
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

    /// Compute overall score from category scores (backward compatible. equal weighting)
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
            return HealthScore(score: Cfg.perfectScore)
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
    /// anomaly density, and user focus preferences from onboarding.
    ///
    /// Weight formula per category:
    ///   rawWeight = volatilityFactor + richnessFactor + anomalyFactor + focusBoost
    /// All weights are normalized to sum to 1.0, with a 0.05 floor per category.
    static func adaptiveCategoryWeights(
        categoryScores: [HealthScore],
        anomalies: [AnomalyDetector.AnomalyResult],
        baselines: [HealthMetric: UserBaseline],
        focusCategories: Set<HealthCategory> = []
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
            let volatilityFactor = min(Cfg.volatilityFactorCap, Cfg.volatilityFactorBase + avgCV * Cfg.volatilityFactorSlope)

            // --- Factor 2: Data richness (number of measured metrics) ---
            let metricCount = Double(categoryBaselines.count)
            let totalMetricsInCategory = Double(category.metrics.count)
            let coverage = totalMetricsInCategory > 0 ? metricCount / totalMetricsInCategory : 0.0
            let richnessFactor = Cfg.richnessFactorBase + coverage * Cfg.richnessFactorRange

            // --- Factor 3: Anomaly density ---
            let activeAnomalies = categoryAnomalies.filter { $0.severity != .info }
            let anomalyDensity = metricCount > 0 ? Double(activeAnomalies.count) / metricCount : 0.0
            let anomalyFactor = Cfg.anomalyFactorBase + anomalyDensity * Cfg.anomalyFactorSlope

            // --- Factor 4: User focus boost (from onboarding selection) ---
            let focusBoost: Double = focusCategories.contains(category) ? Cfg.focusBoost : 0.0

            rawWeights[category] = volatilityFactor + richnessFactor + anomalyFactor + focusBoost
        }

        return normalizeWeights(rawWeights, minimumWeight: Cfg.categoryWeightFloor)
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
                rawWeights[metric] = Cfg.noBaselineWeight
                continue
            }

            let cv: Double
            if baseline.mean != 0 {
                cv = baseline.standardDeviation / abs(baseline.mean)
            } else {
                cv = 0.0
            }
            let variabilityFactor = min(Cfg.volatilityFactorCap, Cfg.volatilityFactorBase + cv * Cfg.volatilityFactorSlope)

            let daysSinceUpdate = Date.cal.dateComponents([.day], from: baseline.lastUpdated, to: now).day ?? 0
            let freshnessFactor: Double
            if daysSinceUpdate <= Cfg.freshnessFreshDayCutoff {
                freshnessFactor = Cfg.freshnessFreshScore
            } else if daysSinceUpdate <= Cfg.freshnessRecentDayCutoff {
                freshnessFactor = Cfg.freshnessFreshScore - Double(daysSinceUpdate - Cfg.freshnessFreshDayCutoff) * Cfg.freshnessRecentDecayPerDay
            } else {
                freshnessFactor = max(Cfg.freshnessFloor, Cfg.freshnessLongTermBase - Double(daysSinceUpdate - Cfg.freshnessRecentDayCutoff) * Cfg.freshnessLongTermDecayPerDay)
            }

            rawWeights[metric] = variabilityFactor * freshnessFactor
        }

        let minWeight = 1.0 / (Double(metrics.count) * Cfg.metricWeightEqualShareDivisor)
        return normalizeWeights(rawWeights, minimumWeight: max(Cfg.metricWeightAbsoluteFloor, minWeight))
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
            : Cfg.perfectScore

        contributions.sort { $0.weightedContribution > $1.weightedContribution }

        var factors: [ScoreFactor] = []

        for anomaly in anomalies where anomaly.severity != .info {
            let absDeviation = abs(anomaly.deviationPercent)
            let direction = anomaly.isAboveBaseline ? "rose" : "dropped"
            let impact: Int
            switch anomaly.severity {
            case .critical:
                impact = -min(Cfg.criticalDeductionCap, Int(abs(anomaly.zScore) * Cfg.criticalDeductionPerZ))
            case .warning:
                impact = -min(Cfg.warningDeductionCap, Int(abs(anomaly.zScore) * Cfg.warningDeductionPerZ))
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

        for (metric, trend) in trends {
            switch trend.direction {
            case .declining:
                let absWoW = abs(trend.weekOverWeekChange)
                let impact = -min(Cfg.decliningDeductionCap, Int(absWoW * Cfg.decliningDeductionPerPercent + Cfg.decliningDeductionOffset))
                factors.append(ScoreFactor(
                    metric: metric,
                    impact: impact,
                    reason: "\(metric.displayName) \(trend.rateOfChange.displayLabel) declining (\(String(format: "%.1f", absWoW))% WoW)",
                    isPositive: false
                ))
            case .improving:
                let absWoW = abs(trend.weekOverWeekChange)
                let impact = min(Cfg.improvingBonusCap, Int(absWoW * Cfg.improvingBonusPerPercent + Cfg.improvingBonusOffset))
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

        let topFactors = Array(
            bestFactorByMetric.values
                .sorted { abs($0.impact) > abs($1.impact) }
                .prefix(Cfg.maxTopFactors)
        )

        return ScoreExplanation(
            totalScore: totalScore,
            categoryContributions: contributions,
            topFactors: topFactors
        )
    }

    // MARK: - Coverage-Adjusted Scoring

    /// Apply coverage-based shrinkage to prevent sparse data from producing
    /// misleadingly confident scores. With few data sources, the score is
    /// pulled toward a neutral midpoint (75). As coverage grows, the raw
    /// score is trusted more.
    ///
    /// Coverage formula:
    ///   For each category with data, weight = min(metricsInCategory / 2, 1)
    ///   weightedCoverage = sum(weights) / totalCategories
    ///   effectiveCoverage = pow(weightedCoverage, 0.6)
    ///   adjustedScore = effectiveCoverage * rawScore + (1 - effectiveCoverage) * 75
    static func applyCoverageAdjustment(
        rawScore: Int,
        baselines: [HealthMetric: UserBaseline]
    ) -> Int {
        let totalCategories = HealthCategory.allCases.count
        guard totalCategories > 0, !baselines.isEmpty else { return rawScore }

        // Count metrics per category from baselines (metrics with actual data)
        var metricsPerCategory: [HealthCategory: Int] = [:]
        for metric in baselines.keys {
            metricsPerCategory[metric.category, default: 0] += 1
        }

        var weightedCoverage = 0.0
        for (_, metricCount) in metricsPerCategory {
            weightedCoverage += min(Double(metricCount) / Cfg.coverageFullWeightMetrics, 1.0)
        }
        weightedCoverage /= Double(totalCategories)

        let effectiveCoverage = pow(weightedCoverage, Cfg.coveragePower)

        let adjusted = effectiveCoverage * Double(rawScore) + (1.0 - effectiveCoverage) * Cfg.neutralScore
        return max(Cfg.minScore, min(Cfg.perfectScore, Int(adjusted.rounded())))
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

        let finalSum = normalized.values.reduce(0, +)
        if finalSum > 0 && abs(finalSum - 1.0) > Cfg.weightSumTolerance {
            normalized = normalized.mapValues { $0 / finalSum }
        }

        return normalized
    }
}
