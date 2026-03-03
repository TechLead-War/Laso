import Foundation

/// Ranks all actionable metrics by predicted impact, confidence, and effort.
/// Uses SimulationEngine to evaluate each metric's potential contribution.
struct ROIRanker {

    /// A single ranked recommendation
    struct RankedRecommendation: Identifiable {
        let id = UUID()
        let metric: HealthMetric
        let actionDescription: String
        let suggestedDelta: Double       // signed change amount
        let predictedScoreGain: Double   // expected score improvement
        let confidence: Double           // 0-1
        let effortLevel: EffortLevel
        let roiScore: Double             // composite: (gain * confidence) / effort
        let explanation: String
    }

    // MARK: - Rank

    /// Rank all actionable metrics by ROI and return the top N.
    static func rank(
        state: SimulationEngine.SimulationState,
        topN: Int = 8
    ) -> [RankedRecommendation] {
        var recommendations: [RankedRecommendation] = []

        for metric in ActionableMetric.all {
            guard let baseline = state.baselines[metric] else { continue }
            guard baseline.standardDeviation > 0 else { continue }

            // Compute suggested delta: min(0.5σ, improvement headroom)
            let headroom = improvementHeadroom(metric: metric, baseline: baseline, latestValue: state.latestValues[metric])
            guard headroom > 0 else { continue }

            let suggestedDelta = min(0.5 * baseline.standardDeviation, headroom)
            let signedDelta = metric.higherIsBetter ? suggestedDelta : -suggestedDelta
            let newValue = (state.latestValues[metric] ?? baseline.mean) + signedDelta

            // Simulate score impact
            let delta = SimulationEngine.MetricDelta(
                metric: metric,
                absoluteChange: signedDelta,
                newValue: newValue
            )
            let result = SimulationEngine.simulate(deltas: [delta], state: state)

            let scoreGain = Double(result.scoreDelta)
            guard scoreGain > 0 else { continue }

            let effort = effortLevel(for: metric, delta: abs(signedDelta), baseline: baseline)
            let confidence = result.confidence
            let roiScore = (scoreGain * confidence) / Double(effort.rawValue)

            recommendations.append(RankedRecommendation(
                metric: metric,
                actionDescription: actionDescription(for: metric, delta: signedDelta),
                suggestedDelta: signedDelta,
                predictedScoreGain: scoreGain,
                confidence: confidence,
                effortLevel: effort,
                roiScore: roiScore,
                explanation: result.explanation
            ))
        }

        return recommendations
            .sorted { $0.roiScore > $1.roiScore }
            .prefix(topN)
            .map { $0 }
    }

    // MARK: - Effort Estimation

    /// Static effort lookup based on metric type and magnitude of change
    private static func effortLevel(for metric: HealthMetric, delta: Double, baseline: UserBaseline) -> EffortLevel {
        let relativeChange = baseline.mean != 0 ? delta / baseline.mean : 0

        switch metric {
        case .sleepDuration:
            return delta < 0.5 ? .low : delta < 1.0 ? .medium : .high
        case .sleepDeep, .sleepREM:
            return .medium  // Hard to control directly
        case .steps:
            return delta < 2000 ? .low : delta < 5000 ? .medium : .high
        case .activeCalories:
            return delta < 100 ? .low : delta < 300 ? .medium : .high
        case .exerciseMinutes:
            return delta < 15 ? .low : delta < 30 ? .medium : .high
        case .standHours:
            return delta < 2 ? .low : delta < 4 ? .medium : .high
        case .mindfulMinutes:
            return delta < 10 ? .low : delta < 20 ? .medium : .high
        case .timeInDaylight:
            return delta < 15 ? .low : delta < 30 ? .medium : .high
        case .waterIntake:
            return delta < 500 ? .low : delta < 1000 ? .medium : .high
        case .heartRateVariability:
            return .high  // Difficult to directly improve
        case .restingHeartRate:
            return delta < 3 ? .medium : .high
        case .weight, .bodyFatPercentage:
            return .high  // Long-term effort
        case .vo2Max:
            return .high  // Requires sustained training
        case .walkingSpeed:
            return relativeChange < 0.05 ? .low : .medium
        default:
            return .medium
        }
    }

    // MARK: - Improvement Headroom

    /// How much room there is to improve this metric toward normal range
    private static func improvementHeadroom(
        metric: HealthMetric,
        baseline: UserBaseline,
        latestValue: Double?
    ) -> Double {
        let current = latestValue ?? baseline.mean
        let normalRange = RulesConfiguration.normalRange(for: metric)

        if metric.higherIsBetter {
            // Headroom = distance from current to high end of normal
            return max(0, normalRange.high - current)
        } else {
            // Headroom = distance from current to low end of normal
            return max(0, current - normalRange.low)
        }
    }

    // MARK: - Action Description

    private static func actionDescription(for metric: HealthMetric, delta: Double) -> String {
        let formatted = metric.formatValue(abs(delta))
        let direction = delta > 0 ? "Increase" : "Decrease"
        return "\(direction) \(metric.displayName) by \(formatted) \(metric.unit)"
    }
}
