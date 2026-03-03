import Foundation

/// Counterfactual engine: "What if I change metric X by Y?"
/// Two prediction paths — rule-based (always available) and ML-based (30+ days),
/// blended by ML confidence to ensure ML never dominates.
struct SimulationEngine {

    // MARK: - Types

    /// A single metric adjustment from the user
    struct MetricDelta {
        let metric: HealthMetric
        let absoluteChange: Double   // signed: +500 steps, -1 bpm RHR
        let newValue: Double         // the target value after adjustment
    }

    /// Per-metric impact breakdown
    struct MetricImpact: Identifiable {
        let id = UUID()
        let metric: HealthMetric
        let scoreDelta: Double       // how much this metric change contributes to overall delta
        let explanation: String
    }

    /// Result of a simulation run
    struct SimulationResult {
        let currentScore: Int
        let predictedScore: Int
        let scoreDelta: Int
        let perMetricImpact: [MetricImpact]
        let confidence: Double       // 0-1
        let explanation: String
    }

    /// Snapshot of the current analysis state needed for simulation
    struct SimulationState {
        let overallScore: Int
        let baselines: [HealthMetric: UserBaseline]
        let anomalies: [AnomalyDetector.AnomalyResult]
        let trends: [HealthMetric: TrendAnalyzer.TrendResult]
        let categoryScores: [HealthScore]
        let categoryWeights: [HealthCategory: Double]
        let latestValues: [HealthMetric: Double]
        // ML fields (optional — only available with 30+ days)
        let todayVector: DailyFeatureVector?
        let predictiveScorerWeights: [Double]?
        let predictiveScorerKeys: [FeatureKey]?
        let predictiveScorerConfidence: Double
        let welfordStats: [HealthMetric: FeatureEngine.WelfordState]?
    }

    // MARK: - Simulate

    /// Run a counterfactual simulation with the given metric adjustments.
    static func simulate(
        deltas: [MetricDelta],
        state: SimulationState
    ) -> SimulationResult {
        guard !deltas.isEmpty else {
            return SimulationResult(
                currentScore: state.overallScore,
                predictedScore: state.overallScore,
                scoreDelta: 0,
                perMetricImpact: [],
                confidence: 1.0,
                explanation: "No changes selected."
            )
        }

        // Path 1: Rule-based prediction (always available)
        let ruleResult = simulateRuleBased(deltas: deltas, state: state)

        // Path 2: ML-based prediction (requires trained model)
        let mlResult = simulateMLBased(deltas: deltas, state: state)

        // Blend results
        let blendWeight: Double
        if let mlDelta = mlResult {
            blendWeight = min(state.predictiveScorerConfidence * 0.7, 0.5)
            let blendedDelta = Double(ruleResult.scoreDelta) * (1.0 - blendWeight) + mlDelta * blendWeight
            let predictedScore = max(0, min(100, state.overallScore + Int(blendedDelta.rounded())))

            return SimulationResult(
                currentScore: state.overallScore,
                predictedScore: predictedScore,
                scoreDelta: predictedScore - state.overallScore,
                perMetricImpact: ruleResult.perMetricImpact,
                confidence: 0.5 + state.predictiveScorerConfidence * 0.3,
                explanation: buildExplanation(deltas: deltas, scoreDelta: predictedScore - state.overallScore)
            )
        } else {
            blendWeight = 0
            let predictedScore = max(0, min(100, state.overallScore + ruleResult.scoreDelta))

            return SimulationResult(
                currentScore: state.overallScore,
                predictedScore: predictedScore,
                scoreDelta: predictedScore - state.overallScore,
                perMetricImpact: ruleResult.perMetricImpact,
                confidence: 0.4,
                explanation: buildExplanation(deltas: deltas, scoreDelta: predictedScore - state.overallScore)
            )
        }
    }

    // MARK: - Rule-Based Path

    private struct RuleBasedResult {
        let scoreDelta: Int
        let perMetricImpact: [MetricImpact]
    }

    /// Replay HealthScorer.scoreMetric() with synthetic anomaly/trend values for each delta.
    private static func simulateRuleBased(
        deltas: [MetricDelta],
        state: SimulationState
    ) -> RuleBasedResult {
        // Build modified anomalies and trends by adjusting existing ones
        var modifiedAnomalies = state.anomalies
        var modifiedTrends = state.trends
        var perMetricImpact: [MetricImpact] = []

        for delta in deltas {
            guard let baseline = state.baselines[delta.metric] else { continue }
            let sd = baseline.standardDeviation
            guard sd > 0 else { continue }

            // Compute new z-score for the modified value
            let newZScore = (delta.newValue - baseline.mean) / sd
            let newDeviationPercent = baseline.mean != 0
                ? ((delta.newValue - baseline.mean) / baseline.mean) * 100
                : 0

            // Determine new severity based on z-score
            let newSeverity: Severity
            let absZ = abs(newZScore)
            if absZ >= 2.5 {
                newSeverity = .critical
            } else if absZ >= 1.5 {
                newSeverity = .warning
            } else {
                newSeverity = .info
            }

            let normalRange = RulesConfiguration.normalRange(for: delta.metric)
            let isOutsideNormal = !normalRange.contains(delta.newValue)
            let isAboveBaseline = delta.newValue > baseline.mean

            // Replace or add the anomaly for this metric
            modifiedAnomalies.removeAll { $0.metric == delta.metric }
            if newSeverity != .info || isOutsideNormal {
                modifiedAnomalies.append(AnomalyDetector.AnomalyResult(
                    metric: delta.metric,
                    severity: newSeverity,
                    deviationPercent: newDeviationPercent,
                    zScore: newZScore,
                    currentValue: delta.newValue,
                    baselineValue: baseline.mean,
                    isAboveBaseline: isAboveBaseline,
                    outsideNormalRange: isOutsideNormal,
                    allTimePercentile: 50
                ))
            }

            // Adjust trend proportionally
            if let existingTrend = state.trends[delta.metric] {
                let changeRatio = baseline.mean != 0 ? delta.absoluteChange / baseline.mean : 0
                let adjustedWoW = existingTrend.weekOverWeekChange + changeRatio * 100
                let newDirection: TrendDirection
                if adjustedWoW > 2 {
                    newDirection = delta.metric.higherIsBetter ? .improving : .declining
                } else if adjustedWoW < -2 {
                    newDirection = delta.metric.higherIsBetter ? .declining : .improving
                } else {
                    newDirection = .stable
                }

                modifiedTrends[delta.metric] = TrendAnalyzer.TrendResult(
                    direction: newDirection,
                    slope: existingTrend.slope,
                    weekOverWeekChange: adjustedWoW,
                    movingAverage7d: existingTrend.movingAverage7d,
                    movingAverage30d: existingTrend.movingAverage30d,
                    movingAverage90d: existingTrend.movingAverage90d,
                    movingAverage180d: existingTrend.movingAverage180d,
                    movingAverage365d: existingTrend.movingAverage365d,
                    inflection: existingTrend.inflection
                )
            }
        }

        // Re-score each category with modified data
        var newMetricScoresByCategory: [HealthCategory: [(metric: HealthMetric, score: Int, components: [ScoreComponent])]] = [:]
        for category in HealthCategory.allCases {
            newMetricScoresByCategory[category] = []
        }

        for metric in HealthMetric.allCases {
            let anomaly = modifiedAnomalies.first { $0.metric == metric }
            let trend = modifiedTrends[metric]
            guard anomaly != nil || trend != nil else { continue }
            let (score, components) = HealthScorer.scoreMetric(metric: metric, anomaly: anomaly, trend: trend)
            newMetricScoresByCategory[metric.category, default: []].append(
                (metric: metric, score: score, components: components)
            )
        }

        var newCategoryScores: [HealthScore] = []
        for category in HealthCategory.allCases {
            let metricScores = newMetricScoresByCategory[category] ?? []
            guard !metricScores.isEmpty else { continue }
            newCategoryScores.append(HealthScorer.scoreCategory(category: category, metricScores: metricScores))
        }

        let newOverall = HealthScorer.overallScore(categoryScores: newCategoryScores, weights: state.categoryWeights)
        let scoreDelta = newOverall.score - state.overallScore

        // Compute per-metric impact
        for delta in deltas {
            let originalAnomaly = state.anomalies.first { $0.metric == delta.metric }
            let originalTrend = state.trends[delta.metric]
            let (originalScore, _) = HealthScorer.scoreMetric(metric: delta.metric, anomaly: originalAnomaly, trend: originalTrend)

            let modifiedAnomaly = modifiedAnomalies.first { $0.metric == delta.metric }
            let modifiedTrend = modifiedTrends[delta.metric]
            let (modifiedScore, _) = HealthScorer.scoreMetric(metric: delta.metric, anomaly: modifiedAnomaly, trend: modifiedTrend)

            let metricDelta = Double(modifiedScore - originalScore)
            let changeDirection = delta.absoluteChange > 0 ? "increasing" : "decreasing"
            let formattedChange = delta.metric.formatValue(abs(delta.absoluteChange))

            perMetricImpact.append(MetricImpact(
                metric: delta.metric,
                scoreDelta: metricDelta,
                explanation: "\(changeDirection.capitalized) \(delta.metric.displayName) by \(formattedChange) \(delta.metric.unit)"
            ))
        }

        return RuleBasedResult(scoreDelta: scoreDelta, perMetricImpact: perMetricImpact)
    }

    // MARK: - ML-Based Path

    /// Uses PredictiveScorer weights to estimate score delta via feature modification.
    /// Returns the estimated score delta, or nil if ML is not available.
    private static func simulateMLBased(
        deltas: [MetricDelta],
        state: SimulationState
    ) -> Double? {
        guard let vector = state.todayVector,
              let weights = state.predictiveScorerWeights,
              let keys = state.predictiveScorerKeys,
              let welfordStats = state.welfordStats,
              !weights.isEmpty else {
            return nil
        }

        // Build the original feature array
        var features = keys.map { key -> Double in
            let v = vector.features[key] ?? FeatureKey.missingSentinel
            return v == FeatureKey.missingSentinel ? 0.0 : v
        }
        features.append(contentsOf: vector.context.asArray)
        features.append(1.0) // bias

        guard features.count == weights.count else { return nil }

        // Compute original P(bad day)
        let originalLogit = zip(weights, features).reduce(0.0) { $0 + $1.0 * $1.1 }
        let originalProb = 1.0 / (1.0 + exp(-originalLogit))

        // Modify features for each delta
        var modifiedFeatures = features
        for delta in deltas {
            guard let stats = welfordStats[delta.metric], stats.stdDev > 0 else { continue }
            let newZScore = stats.zScore(for: delta.newValue)

            // Update raw z-score feature
            let rawKey = FeatureKey(metric: delta.metric, type: .raw)
            if let idx = keys.firstIndex(of: rawKey), idx < modifiedFeatures.count {
                modifiedFeatures[idx] = newZScore
            }

            // Update baseline deviation feature
            let devKey = FeatureKey(metric: delta.metric, type: .devBaseline)
            if let idx = keys.firstIndex(of: devKey), idx < modifiedFeatures.count {
                modifiedFeatures[idx] = newZScore
            }
        }

        // Compute modified P(bad day)
        let modifiedLogit = zip(weights, modifiedFeatures).reduce(0.0) { $0 + $1.0 * $1.1 }
        let modifiedProb = 1.0 / (1.0 + exp(-modifiedLogit))

        // Convert probability delta to approximate score delta
        // Lower P(bad day) → higher score, scaled by ~50 points full range
        let probDelta = originalProb - modifiedProb  // positive = improvement
        let scoreDelta = probDelta * 50.0

        return scoreDelta
    }

    // MARK: - Explanation

    private static func buildExplanation(deltas: [MetricDelta], scoreDelta: Int) -> String {
        if scoreDelta > 0 {
            let topMetric = deltas.max(by: { abs($0.absoluteChange) < abs($1.absoluteChange) })
            let metricName = topMetric?.metric.displayName ?? "these changes"
            return "Improving \(metricName) could raise your score by \(scoreDelta) points."
        } else if scoreDelta < 0 {
            return "These changes would decrease your score by \(abs(scoreDelta)) points."
        } else {
            return "These changes would have minimal impact on your score."
        }
    }
}
