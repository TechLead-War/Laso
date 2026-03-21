import Foundation
import Observation

/// ViewModel for the What-If Simulation feature.
/// Manages slider adjustments, runs simulations, and computes ROI rankings.
@MainActor @Observable
final class SimulationViewModel {

    // MARK: - State

    /// Current user adjustments: metric → absolute change from current value
    var adjustments: [HealthMetric: Double] = [:]
    /// Latest simulation result
    var simulationResult: SimulationEngine.SimulationResult?
    /// ROI-ranked recommendations
    var rankedRecommendations: [ROIRanker.RankedRecommendation] = []
    /// Whether simulation is running
    var isSimulating = false

    // MARK: - Dependencies

    private let analysisEngine: AnalysisEngine

    init(analysisEngine: AnalysisEngine) {
        self.analysisEngine = analysisEngine
    }

    // MARK: - Actionable Metrics with Baselines

    /// Metrics available for simulation (have baselines)
    var availableMetrics: [HealthMetric] {
        ActionableMetric.all
            .filter { analysisEngine.baselines[$0] != nil }
            .sorted { $0.displayName < $1.displayName }
    }

    /// Get current/baseline value for a metric
    func currentValue(for metric: HealthMetric) -> Double {
        latestValues[metric] ?? analysisEngine.baselines[metric]?.mean ?? 0
    }

    /// Get simulation range for a metric
    func range(for metric: HealthMetric) -> ClosedRange<Double> {
        guard let baseline = analysisEngine.baselines[metric] else { return 0...100 }
        return ActionableMetric.simulationRange(for: metric, baseline: baseline)
    }

    /// Get slider step for a metric
    func step(for metric: HealthMetric) -> Double {
        ActionableMetric.sliderStep(for: metric)
    }

    // MARK: - Actions

    /// Run simulation with current adjustments
    func runSimulation() {
        isSimulating = true
        defer { isSimulating = false }

        let state = buildSimulationState()
        let deltas = adjustments.compactMap { (metric, change) -> SimulationEngine.MetricDelta? in
            guard abs(change) > 0.001 else { return nil }
            let current = currentValue(for: metric)
            return SimulationEngine.MetricDelta(
                metric: metric,
                absoluteChange: change,
                newValue: current + change
            )
        }

        simulationResult = SimulationEngine.simulate(deltas: deltas, state: state)
    }

    /// Compute ROI rankings
    func computeROIRankings() {
        let state = buildSimulationState()
        rankedRecommendations = ROIRanker.rank(state: state)
    }

    /// Apply a quick suggestion from ROI ranking
    func applyQuickSuggestion(_ recommendation: ROIRanker.RankedRecommendation) {
        adjustments[recommendation.metric] = recommendation.suggestedDelta
        runSimulation()
    }

    /// Reset all adjustments
    func reset() {
        adjustments.removeAll()
        simulationResult = nil
    }

    // MARK: - State Building

    private var latestValues: [HealthMetric: Double] {
        var values: [HealthMetric: Double] = [:]
        for (metric, baseline) in analysisEngine.baselines {
            values[metric] = baseline.mean  // Use baseline mean as proxy for latest
        }
        return values
    }

    private func buildSimulationState() -> SimulationEngine.SimulationState {
        let mlOrch = analysisEngine.mlOrchestrator

        // Get PredictiveScorer parameters if available
        let scorerParams = mlOrch.predictiveScorer.getParameters()
        let scorerKeys: [FeatureKey]?
        if let keysData = scorerParams?.featureKeysData {
            scorerKeys = try? JSONDecoder().decode([FeatureKey].self, from: keysData)
        } else {
            scorerKeys = nil
        }

        return SimulationEngine.SimulationState(
            overallScore: analysisEngine.overallScore.score,
            baselines: analysisEngine.baselines,
            anomalies: analysisEngine.anomalies,
            trends: analysisEngine.trends,
            categoryScores: analysisEngine.categoryScores,
            categoryWeights: HealthScorer.adaptiveCategoryWeights(
                categoryScores: analysisEngine.categoryScores,
                anomalies: analysisEngine.anomalies,
                baselines: analysisEngine.baselines
            ),
            latestValues: latestValues,
            todayVector: mlOrch.latestVector,
            predictiveScorer: mlOrch.predictiveScorer.isReady ? mlOrch.predictiveScorer : nil,
            predictiveScorerKeys: scorerKeys,
            predictiveScorerConfidence: mlOrch.predictiveScorer.isReady
                ? min(Double((scorerParams?.trainingCount ?? 0)) / 90.0, 1.0)
                : 0,
            welfordStats: mlOrch.featureEngine.getRunningStats()
        )
    }
}
