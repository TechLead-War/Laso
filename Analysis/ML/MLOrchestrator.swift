import Foundation
import Observation
import os

/// Manages all ML component lifecycle, sequential execution, incremental training, and periodic retraining.
@Observable
final class MLOrchestrator {

    private let logger = Logger(subsystem: "com.healthpulse.ml", category: "MLOrchestrator")

    // MARK: - ML Components (Core)

    let featureEngine = FeatureEngine()
    let forecaster = TimeSeriesForecaster()
    let anomalyDetector = AdaptiveAnomalyDetector()
    let patternMiner = PatternMiner()
    let correlationDiscovery = CorrelationDiscovery()
    let stateClassifier = HealthStateClassifier()
    let predictiveScorer = PredictiveScorer()
    let adherenceTracker = AdherenceTracker()
    let circadianAnalyzer = CircadianAnalyzer()

    // MARK: - ML Components (New)

    let decisionPolicyEngine = DecisionPolicyEngine()
    let mlEvaluator = MLEvaluator()
    let conformalCalibrator = ConformalCalibrator()

    // MARK: - ML Components (Intelligence Layer)

    let interactionEngine = InteractionEffectEngine()
    let temporalMiner = TemporalSequenceMiner()
    let changePointDetector = ChangePointDetector()
    let personalOptimizer = PersonalOptimizer()
    let compoundInsightEngine = CompoundInsightEngine()

    // MARK: - Delegates

    private let pipelineRunner = MLPipelineRunner()
    private let resultAggregator = MLResultAggregator()
    private let calibrationManager = MLCalibrationManager()

    // MARK: - State

    /// Whether ML analysis has been run at least once
    var hasRunOnce = false
    /// Whether ML is currently running
    var isRunning = false
    /// Last full retrain date
    var lastFullRetrain: Date?

    // MARK: - Results (for AnalysisEngine to consume)

    /// ML-powered anomalies (from forecaster + isolation forest)
    var mlAnomalies: [TimeSeriesForecaster.ForecastAnomaly] = []
    /// Adaptive anomaly results
    var adaptiveAnomalies: [AdaptiveAnomalyDetector.AdaptiveAnomaly] = []
    /// Discovered patterns
    var discoveredPatterns: [DiscoveredPattern] = []
    /// ML-discovered correlations
    var mlCorrelations: [MLCorrelation] = []
    /// Current health state
    var currentHealthState: HealthState?
    /// Tomorrow risk prediction
    var tomorrowRiskPrediction: MLPrediction?

    // MARK: - New ML Results

    /// Enriched feature vectors with composite features
    var enrichedVectors: [EnrichedDailyFeatureVector] = []
    /// Predictive health signal report (fatigue, burnout, overtraining, insomnia, immune, inactivity)
    var healthSignalReport: PredictiveHealthSignals.HealthSignalReport?
    /// Policy-based recommendation decision — single source of truth for daily action
    var policyDecision: PolicyDecision?
    /// Personalization status for the user
    var personalizationStatus: PersonalizationBlender.PersonalizationStatus?
    /// Data sufficiency assessment
    var dataSufficiency: UncertaintyEstimator.DataSufficiency?
    /// Component readiness
    var componentReadiness: [UncertaintyEstimator.ComponentReadiness] = []
    /// HMM-smoothed state history
    var smoothedStates: [SmoothedHealthState] = []
    /// Multi-horizon forecasts (1d, 3d, 7d) per metric
    var multiHorizonForecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast] = [:]
    /// Multivariate regression results (omitted-variable-reduced causality)
    var multivariateResults: [MultivariateRegressionResult] = []
    /// Latest evaluation summary per component
    var evaluationSummaries: [String: ComponentEvaluation] = [:]
    /// Model drift alerts
    var driftAlerts: [DriftReport] = []
    /// Interaction effects (dose-response, conditional, moderation)
    var interactionEffects: [InteractionEffectEngine.InteractionEffect] = []
    /// Dose-response curves
    var doseResponseCurves: [InteractionEffectEngine.DoseResponseCurve] = []
    /// Temporal sequences (multi-step causal chains)
    var temporalSequences: [TemporalSequenceMiner.TemporalSequence] = []
    /// Precursor warning patterns
    var precursorPatterns: [TemporalSequenceMiner.PrecursorPattern] = []
    /// Compounding effects
    var compoundingEffects: [TemporalSequenceMiner.CompoundingEffect] = []
    /// Detected changepoints (regime shifts)
    var changePoints: [ChangePointDetector.ChangePoint] = []
    /// Regime comparisons per metric
    var regimeComparisons: [ChangePointDetector.RegimeComparison] = []
    /// Personal optimal profile
    var optimalProfile: PersonalOptimizer.OptimalProfile?
    /// Ideal day targets
    var idealDay: PersonalOptimizer.IdealDay?
    /// Score sensitivities per metric
    var scoreSensitivities: [PersonalOptimizer.SensitivityResult] = []
    /// Compound insights (cross-component synthesis)
    var compoundInsights: [CompoundInsightEngine.CompoundInsight] = []

    // MARK: - Cached Feature Vectors

    private let vectorLock = NSLock()
    private var _cachedVectors: [DailyFeatureVector] = []
    private var cachedVectors: [DailyFeatureVector] {
        get { vectorLock.withLock { _cachedVectors } }
        set { vectorLock.withLock { _cachedVectors = newValue } }
    }

    /// Latest feature vector (for simulation engine)
    var latestVector: DailyFeatureVector? { cachedVectors.last }

    /// Full state history from classifier (for Health State Timeline)
    var stateHistory: [(date: Date, label: String)] {
        stateClassifier.isReady ? stateClassifier.stateHistory : []
    }

    /// Transition matrix from classifier (for Health State Timeline)
    var stateTransitionMatrix: [String: [String: Double]] {
        stateClassifier.isReady ? stateClassifier.transitionMatrix : [:]
    }

    /// All identified health states from classifier
    var healthStates: [HealthState] {
        stateClassifier.isReady ? stateClassifier.states : []
    }

    /// Circadian profile (chronotype, peak times)
    var circadianProfile: CircadianAnalyzer.CircadianProfile? { circadianAnalyzer.profile }

    /// Timing recommendations from circadian analysis
    var timingRecommendations: [CircadianAnalyzer.TimingRecommendation] { circadianAnalyzer.recommendations }

    /// Whether circadian analysis should run
    var needsCircadianAnalysis: Bool { circadianAnalyzer.needsAnalysis }

    // MARK: - Run ML Analysis

    /// Run all ML components that are ready. Called from AnalysisEngine after rule-based analysis.
    /// Components run sequentially (one at a time) to avoid CPU spikes, ordered by priority.
    /// Thermal state is checked before starting and between each component.
    func runMLAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        ruleBasedAnomalies: [AnomalyDetector.AnomalyResult],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int],
        focusCategories: Set<HealthCategory> = []
    ) async {
        // Bail out entirely if device is already under thermal pressure
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical {
            return
        }

        isRunning = true
        let pipelineStart = Date()
        var componentsRunCount = 0
        defer {
            isRunning = false
            hasRunOnce = true
            if componentsRunCount > 0 {
                let pipelineDurationMs = Int(Date().timeIntervalSince(pipelineStart) * 1000)
                let totalDataPoints = timeSeries.values.reduce(0) { $0 + $1.samples.count }
                Task { @MainActor in
                    AppAnalytics.shared.trackMLAnalysisPerformance(
                        durationMs: pipelineDurationMs,
                        componentsRun: componentsRunCount,
                        dataPointsUsed: totalDataPoints
                    )
                }
            }
        }

        let input = MLPipelineRunner.PipelineInput(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            ruleBasedAnomalies: ruleBasedAnomalies,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts,
            focusCategories: focusCategories
        )

        let components = makeComponents()

        guard let pipelineOutput = await pipelineRunner.run(
            input: input,
            components: components,
            needsFullRetrain: needsFullRetrain,
            cachedVectorsSetter: { [self] vectors in cachedVectors = vectors }
        ) else {
            return
        }
        componentsRunCount = pipelineOutput.componentsRunCount

        let vectors = pipelineOutput.vectors
        guard !vectors.isEmpty else { return }

        // Apply pipeline output to observable state
        applyPipelineOutput(pipelineOutput)

        if !pipelineOutput.stoppedEarly {
            // Step 13: CompoundInsightEngine (uses current self.* state from previous run)
            compoundInsights = resultAggregator.synthesizeCompoundInsights(
                timeSeries: timeSeries,
                baselines: baselines,
                currentAdaptiveAnomalies: adaptiveAnomalies,
                currentMLCorrelations: mlCorrelations,
                currentDiscoveredPatterns: discoveredPatterns,
                currentTomorrowRiskPrediction: tomorrowRiskPrediction,
                smoothedStates: smoothedStates,
                scoreHistory: scoreHistory,
                components: components
            )
        }

        // Collect all results and compute policy decision
        let aggregated = resultAggregator.collectResults(
            timeSeries: timeSeries,
            vectors: vectors,
            baselines: baselines,
            trends: trends,
            ruleBasedAnomalies: ruleBasedAnomalies,
            scoreHistory: scoreHistory,
            focusCategories: focusCategories,
            components: components,
            calibrationManager: calibrationManager,
            evaluationSummaries: evaluationSummaries,
            dataSufficiency: dataSufficiency,
            smoothedStates: smoothedStates,
            timingRecommendations: timingRecommendations
        )
        applyAggregatedResults(aggregated)
    }

    // MARK: - Incremental Training

    /// Lightweight daily update without full retrain
    func trainIncremental(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        todayScore: Int,
        todayAnomalyCount: Int
    ) {
        pipelineRunner.trainIncremental(
            timeSeries: timeSeries,
            baselines: baselines,
            todayScore: todayScore,
            todayAnomalyCount: todayAnomalyCount,
            components: makeComponents(),
            cachedVectors: cachedVectors
        )
    }

    // MARK: - Full Retrain

    /// Full retrain of all components (expensive, every 30 days)
    var needsFullRetrain: Bool {
        guard let lastRetrain = lastFullRetrain else { return hasRunOnce }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    func markFullRetrainComplete() {
        lastFullRetrain = Date()
    }

    // MARK: - Circadian Analysis (separate pipeline, runs weekly)

    /// Run circadian analysis using hourly data. Called separately from the main ML pipeline.
    func runCircadianAnalysis(hourlyData: [HealthMetric: [[Double]]]) {
        guard !hourlyData.isEmpty else { return }
        circadianAnalyzer.analyze(hourlyData: hourlyData)
    }

    // MARK: - Insight Generation

    /// Convert ML results into Insight objects for the insights pipeline
    func generateInsights() -> [Insight] {
        resultAggregator.generateInsights(
            discoveredPatterns: discoveredPatterns,
            currentHealthState: currentHealthState,
            tomorrowRiskPrediction: tomorrowRiskPrediction,
            healthSignalReport: healthSignalReport,
            interactionEffects: interactionEffects,
            precursorPatterns: precursorPatterns,
            temporalSequences: temporalSequences,
            changePoints: changePoints,
            optimalProfile: optimalProfile,
            idealDay: idealDay,
            mlCorrelations: mlCorrelations,
            compoundInsightEngine: compoundInsightEngine,
            circadianAnalyzer: circadianAnalyzer,
            cachedVectorCount: cachedVectors.count
        )
    }

    // MARK: - Private Helpers

    private func makeComponents() -> MLPipelineRunner.Components {
        MLPipelineRunner.Components(
            featureEngine: featureEngine,
            forecaster: forecaster,
            anomalyDetector: anomalyDetector,
            patternMiner: patternMiner,
            correlationDiscovery: correlationDiscovery,
            stateClassifier: stateClassifier,
            predictiveScorer: predictiveScorer,
            interactionEngine: interactionEngine,
            temporalMiner: temporalMiner,
            changePointDetector: changePointDetector,
            personalOptimizer: personalOptimizer,
            compoundInsightEngine: compoundInsightEngine,
            mlEvaluator: mlEvaluator,
            conformalCalibrator: conformalCalibrator,
            decisionPolicyEngine: decisionPolicyEngine
        )
    }

    private func applyPipelineOutput(_ output: MLPipelineRunner.PipelineOutput) {
        enrichedVectors = output.enrichedVectors
        dataSufficiency = output.dataSufficiency
        componentReadiness = output.componentReadiness
        personalizationStatus = output.personalizationStatus
        smoothedStates = output.smoothedStates
        multiHorizonForecasts = output.multiHorizonForecasts
        multivariateResults = output.multivariateResults
        healthSignalReport = output.healthSignalReport
        driftAlerts = output.driftAlerts
        evaluationSummaries = output.evaluationSummaries
        interactionEffects = output.interactionEffects
        doseResponseCurves = output.doseResponseCurves
        temporalSequences = output.temporalSequences
        precursorPatterns = output.precursorPatterns
        compoundingEffects = output.compoundingEffects
        changePoints = output.changePoints
        regimeComparisons = output.regimeComparisons
        optimalProfile = output.optimalProfile
        idealDay = output.idealDay
        scoreSensitivities = output.scoreSensitivities
    }

    private func applyAggregatedResults(_ results: MLResultAggregator.AggregatedResults) {
        mlAnomalies = results.mlAnomalies
        adaptiveAnomalies = results.adaptiveAnomalies
        discoveredPatterns = results.discoveredPatterns
        mlCorrelations = results.mlCorrelations
        currentHealthState = results.currentHealthState
        tomorrowRiskPrediction = results.tomorrowRiskPrediction
        policyDecision = results.policyDecision
    }
}
