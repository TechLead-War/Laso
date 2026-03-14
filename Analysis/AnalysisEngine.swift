import Foundation
import Observation

/// Orchestrates the full analysis pipeline: baselines → trends → anomalies → scores → insights
@Observable
final class AnalysisEngine {
    private let persistence = PersistenceManager()

    // MARK: - Nested Observable State Groups

    let baselineState = BaselineState()
    let trendState = TrendState()
    let anomalyState = AnomalyState()
    let scoreState = ScoreState()
    let insightState = InsightState()
    let correlationState = CorrelationState()
    let historicalState = HistoricalState()

    var isAnalyzing = false
    var lastAnalysis: Date?

    // MARK: - Nested @Observable Classes

    @Observable
    final class BaselineState {
        var baselines: [HealthMetric: UserBaseline] = [:]
    }

    @Observable
    final class TrendState {
        var trends: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
    }

    @Observable
    final class AnomalyState {
        var anomalies: [AnomalyDetector.AnomalyResult] = []
        var crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] = []
    }

    @Observable
    final class ScoreState {
        var overallScore: HealthScore = HealthScore(score: 100)
        var categoryScores: [HealthScore] = []
        var scoreExplanation: HealthScorer.ScoreExplanation?
    }

    @Observable
    final class InsightState {
        var insights: [Insight] = []
        var healthRisks: [HealthRisk] = []
        var illnessWarnings: [IllnessEarlyWarning.Warning] = []
        var causalChains: [CausalChain] = []
    }

    @Observable
    final class CorrelationState {
        var correlations: [HealthCorrelation] = []
    }

    @Observable
    final class HistoricalState {
        var historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] = [:]
    }

    // MARK: - Convenience Accessors (keep short call-sites working)

    var baselines: [HealthMetric: UserBaseline] {
        get { baselineState.baselines }
        set { baselineState.baselines = newValue }
    }
    var trends: [HealthMetric: TrendAnalyzer.TrendResult] {
        get { trendState.trends }
        set { trendState.trends = newValue }
    }
    var anomalies: [AnomalyDetector.AnomalyResult] {
        get { anomalyState.anomalies }
        set { anomalyState.anomalies = newValue }
    }
    var crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] {
        get { anomalyState.crossMetricAnomalies }
        set { anomalyState.crossMetricAnomalies = newValue }
    }
    var overallScore: HealthScore {
        get { scoreState.overallScore }
        set { scoreState.overallScore = newValue }
    }
    var categoryScores: [HealthScore] {
        get { scoreState.categoryScores }
        set { scoreState.categoryScores = newValue }
    }
    var scoreExplanation: HealthScorer.ScoreExplanation? {
        get { scoreState.scoreExplanation }
        set { scoreState.scoreExplanation = newValue }
    }
    var insights: [Insight] {
        get { insightState.insights }
        set { insightState.insights = newValue }
    }
    var healthRisks: [HealthRisk] {
        get { insightState.healthRisks }
        set { insightState.healthRisks = newValue }
    }
    var illnessWarnings: [IllnessEarlyWarning.Warning] {
        get { insightState.illnessWarnings }
        set { insightState.illnessWarnings = newValue }
    }
    var causalChains: [CausalChain] {
        get { insightState.causalChains }
        set { insightState.causalChains = newValue }
    }
    var correlations: [HealthCorrelation] {
        get { correlationState.correlations }
        set { correlationState.correlations = newValue }
    }
    var historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] {
        get { historicalState.historicalContext }
        set { historicalState.historicalContext = newValue }
    }

    // MARK: - Deferred Analysis Caching

    /// Tracks when the heavy analysis tier last ran so we can skip it if fresh.
    private var lastHeavyAnalysisDate: Date?
    /// TTL for heavy analysis — correlations/historical/cross-metric change slowly.
    private static let heavyAnalysisTTL: TimeInterval = 3600  // 1 hour

    /// Whether the heavy analysis phase needs to run (expired or never ran).
    var needsHeavyAnalysis: Bool {
        guard let last = lastHeavyAnalysisDate else { return true }
        return Date().timeIntervalSince(last) >= Self.heavyAnalysisTTL
    }

    // MARK: - ML Integration
    let mlOrchestrator = MLOrchestrator()
    /// ML-predicted risk for tomorrow
    var tomorrowRiskPrediction: MLPrediction? { mlOrchestrator.tomorrowRiskPrediction }
    /// Current ML-classified health state
    var currentHealthState: HealthState? { mlOrchestrator.currentHealthState }
    /// Periodic patterns discovered by ML
    var discoveredPatterns: [DiscoveredPattern] { mlOrchestrator.discoveredPatterns }
    /// Predictive health signal report
    var healthSignalReport: PredictiveHealthSignals.HealthSignalReport? { mlOrchestrator.healthSignalReport }
    /// Personalization status
    var personalizationStatus: PersonalizationBlender.PersonalizationStatus? { mlOrchestrator.personalizationStatus }
    /// Data sufficiency for ML components
    var dataSufficiency: UncertaintyEstimator.DataSufficiency? { mlOrchestrator.dataSufficiency }
    /// Component readiness
    var componentReadiness: [UncertaintyEstimator.ComponentReadiness] { mlOrchestrator.componentReadiness }

    init() {
        baselines = persistence.loadBaselines()
        lastAnalysis = persistence.loadLastAnalysisDate()
    }

    /// Run the full analysis pipeline on the given time series data.
    /// Split into phases:
    /// - `runCoreAnalysis`: baselines, trends, anomalies, scores (blocks UI)
    /// - `runDeferredEssentials`: lightweight insight generators, health risks, illness warnings
    /// - `runDeferredHeavy`: correlations, historical, cross-metric anomalies, causal chains
    func runFullAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = [],
        focusCategories: Set<HealthCategory> = []
    ) {
        runCoreAnalysis(timeSeries: timeSeries, focusCategories: focusCategories)
        runDeferredEssentials(timeSeries: timeSeries, cycleFlowSamples: cycleFlowSamples)
        runDeferredHeavy(timeSeries: timeSeries)
    }

    // MARK: - Phase 1: Core Analysis (required before UI renders)

    /// Computes baselines, trends, anomalies, and scores — the minimum needed to render the UI.
    /// All computation uses local variables; @Observable properties are batch-updated at the end
    /// to minimize UI re-render cascades.
    /// `focusCategories` from onboarding are used to boost focused categories in scoring weights.
    func runCoreAnalysis(timeSeries: [HealthMetric: MetricTimeSeries], focusCategories: Set<HealthCategory> = []) {
        isAnalyzing = true

        // Step 1: Update baselines
        let newBaselines = BaselineCalculator.updateBaselines(
            existing: baselines,
            timeSeries: timeSeries
        )
        persistence.saveBaselines(newBaselines)

        // Step 2: Analyze trends for each metric
        var newTrends: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
        for (metric, series) in timeSeries {
            guard series.values.count >= 3 else { continue }
            newTrends[metric] = TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter)
        }

        // Step 3: Detect anomalies (rule-based as foundation)
        var newAnomalies = AnomalyDetector.detectAll(timeSeries: timeSeries, baselines: newBaselines)

        // Step 3a: Merge ML forecast-based anomalies when available
        if mlOrchestrator.forecaster.isReady {
            let forecastAnomalies = mlOrchestrator.forecaster.detectAnomalies(timeSeries: timeSeries)
            let existingMetrics = Set(newAnomalies.map(\.metric))
            for mlAnomaly in forecastAnomalies where !existingMetrics.contains(mlAnomaly.metric) {
                newAnomalies.append(AnomalyDetector.AnomalyResult(
                    metric: mlAnomaly.metric,
                    severity: mlAnomaly.severity,
                    deviationPercent: mlAnomaly.deviationPercent,
                    zScore: mlAnomaly.normalizedResidual,
                    currentValue: mlAnomaly.currentValue,
                    baselineValue: mlAnomaly.predictedValue,
                    isAboveBaseline: mlAnomaly.residual > 0,
                    outsideNormalRange: mlAnomaly.normalizedResidual > 2.0,
                    allTimePercentile: timeSeries[mlAnomaly.metric]?.percentile(of: mlAnomaly.currentValue) ?? 50
                ))
            }
        }

        // Step 4: Compute health scores
        var metricScoresByCategory: [HealthCategory: [(metric: HealthMetric, score: Int, components: [ScoreComponent])]] = [:]
        for category in HealthCategory.allCases {
            metricScoresByCategory[category] = []
        }
        for metric in HealthMetric.allCases {
            let anomaly = newAnomalies.first { $0.metric == metric }
            let trend = newTrends[metric]
            guard anomaly != nil || trend != nil else { continue }
            let (score, components) = HealthScorer.scoreMetric(metric: metric, anomaly: anomaly, trend: trend)
            metricScoresByCategory[metric.category, default: []].append(
                (metric: metric, score: score, components: components)
            )
        }

        // Step 5: Category scores
        var newCategoryScores: [HealthScore] = []
        for category in HealthCategory.allCases {
            let metricScores = metricScoresByCategory[category] ?? []
            guard !metricScores.isEmpty else { continue }
            newCategoryScores.append(HealthScorer.scoreCategory(category: category, metricScores: metricScores))
        }

        // Step 6: Overall score with adaptive weights (boosted by onboarding focus selection)
        let adaptiveWeights = HealthScorer.adaptiveCategoryWeights(
            categoryScores: newCategoryScores,
            anomalies: newAnomalies,
            baselines: newBaselines,
            focusCategories: focusCategories
        )
        let newOverallScore = HealthScorer.overallScore(categoryScores: newCategoryScores, weights: adaptiveWeights)
        let newScoreExplanation = HealthScorer.explainOverallScore(
            categoryScores: newCategoryScores,
            weights: adaptiveWeights,
            anomalies: newAnomalies,
            trends: newTrends
        )

        // ── Batch apply all core results to @Observable properties ──
        baselines = newBaselines
        trends = newTrends
        anomalies = newAnomalies
        categoryScores = newCategoryScores
        overallScore = newOverallScore
        scoreExplanation = newScoreExplanation
        lastAnalysis = Date()
        persistence.saveLastAnalysisDate(Date())
    }

    // MARK: - Analyzer Registry

    /// Essential-phase analyzers — lightweight, run immediately after core analysis.
    private static let essentialAnalyzers: [any InsightAnalyzer.Type] = [
        InsightGenerator.self,
        RecoveryAnalyzer.self,
        WorkoutEffectivenessAnalyzer.self,
        SleepPerformanceAnalyzer.self,
        WeeklyPatternAnalyzer.self,
        PersonalRecordAnalyzer.self,
        CyclePhaseAnalyzer.self,
        MultiMetricClusterAnalyzer.self,
        ClinicalIntelligence.self,
        IllnessEarlyWarning.self,
    ]

    /// Heavy-phase analyzers — expensive, run with TTL caching.
    private static let heavyAnalyzers: [any InsightAnalyzer.Type] = [
        CorrelationAnalyzer.self,
        HistoricalAnalyzer.self,
        CognitiveEnergyAnalyzer.self,
        CrossMetricAnomalyDetector.self,
        NutritionCorrelationAnalyzer.self,
        CausalChainEngine.self,
    ]

    // MARK: - Phase 2A: Deferred Essentials (lightweight, runs immediately after core)

    /// Runs all essential insight analyzers via the unified `InsightAnalyzer` protocol,
    /// then coordinates the results to remove contradictions before showing to the user.
    func runDeferredEssentials(
        timeSeries: [HealthMetric: MetricTimeSeries],
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = []
    ) {
        // Pre-compute results needed by specific analyzers and stored on engine
        let newHealthRisks = HealthRiskEngine.assessAllRisks(
            timeSeries: timeSeries, baselines: baselines, trends: trends, anomalies: anomalies
        )
        let newIllnessWarnings = IllnessEarlyWarning.evaluate(
            timeSeries: timeSeries, baselines: baselines
        )

        // Build shared context for all essential analyzers
        let context = AnalysisContext(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            anomalies: anomalies,
            cycleFlowSamples: cycleFlowSamples,
            illnessWarnings: newIllnessWarnings
        )

        // Run all essential analyzers through unified protocol.
        // Insights are collected without intermediate dedup — a single dedup pass
        // happens via InsightCoordinator.coordinate() at the end.
        var allInsights: [Insight] = []
        for analyzer in Self.essentialAnalyzers {
            allInsights.append(contentsOf: analyzer.generateInsights(context: context))
        }

        // ML insights (components have their own isReady guards)
        let mlInsights = mlOrchestrator.generateInsights()
        if !mlInsights.isEmpty {
            allInsights.append(contentsOf: mlInsights)
        }

        // Single coordination pass: infer directives, resolve contradictions, deduplicate
        allInsights = InsightCoordinator.coordinate(allInsights)

        // ── Batch apply essentials ──
        insights = allInsights
        healthRisks = newHealthRisks
        illnessWarnings = newIllnessWarnings
    }

    // MARK: - Phase 2B: Deferred Heavy (expensive, runs with delay)

    /// Runs correlations, historical analysis, cross-metric anomaly detection, and causal chains.
    /// Heavy analysis results are stored on the engine, then all heavy-phase analyzers run
    /// through the unified protocol. The full insight set (essential + heavy) is re-coordinated.
    func runDeferredHeavy(timeSeries: [HealthMetric: MetricTimeSeries], force: Bool = false) {
        guard force || needsHeavyAnalysis else {
            isAnalyzing = false
            return
        }

        // ── Heavy cross-metric computation (results stored on engine) ──
        let newCorrelations = CorrelationAnalyzer.analyzeAll(timeSeries: timeSeries)
        let newHistoricalContext = HistoricalAnalyzer.analyzeAll(
            timeSeries: timeSeries, baselines: baselines
        )
        let newCrossMetricAnomalies = CrossMetricAnomalyDetector.detect(
            timeSeries: timeSeries, baselines: baselines
        )
        let newCausalChains = CausalChainEngine.buildChains(
            correlations: newCorrelations, anomalies: anomalies,
            trends: trends, timeSeries: timeSeries, baselines: baselines
        )

        // Build context with heavy results included
        let context = AnalysisContext(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            anomalies: anomalies,
            correlations: newCorrelations,
            historicalContext: newHistoricalContext,
            crossMetricAnomalies: newCrossMetricAnomalies,
            causalChains: newCausalChains
        )

        // Run all heavy analyzers through unified protocol
        var heavyInsights: [Insight] = []
        for analyzer in Self.heavyAnalyzers {
            heavyInsights.append(contentsOf: analyzer.generateInsights(context: context))
        }

        // Merge heavy insights with essentials and re-coordinate the full set.
        // This single InsightCoordinator.coordinate() pass handles all dedup.
        var mergedInsights = insights
        mergedInsights.append(contentsOf: heavyInsights)
        mergedInsights = InsightCoordinator.coordinate(mergedInsights)

        // ── Batch apply heavy results ──
        correlations = newCorrelations
        historicalContext = newHistoricalContext
        crossMetricAnomalies = newCrossMetricAnomalies
        causalChains = newCausalChains
        insights = mergedInsights
        lastHeavyAnalysisDate = Date()
        isAnalyzing = false
    }

    // MARK: - Legacy Compatibility

    /// Old single-method deferred analysis — calls both tiers sequentially.
    func runDeferredAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = []
    ) {
        runDeferredEssentials(timeSeries: timeSeries, cycleFlowSamples: cycleFlowSamples)
        runDeferredHeavy(timeSeries: timeSeries, force: true)
    }

    // MARK: - ML Pipeline

    /// Run the ML analysis pipeline asynchronously after rule-based analysis.
    /// Call this after `runFullAnalysis` with the same timeSeries data.
    func runMLAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int],
        focusCategories: Set<HealthCategory> = []
    ) async {
        await mlOrchestrator.runMLAnalysis(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            ruleBasedAnomalies: anomalies,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts,
            focusCategories: focusCategories
        )

        // After ML completes, regenerate ML insights and re-coordinate.
        // Single dedup pass via InsightCoordinator.coordinate().
        let mlInsights = mlOrchestrator.generateInsights()
        insights.append(contentsOf: mlInsights)
        insights = InsightCoordinator.coordinate(insights)

        // Incremental training for next run
        mlOrchestrator.trainIncremental(
            timeSeries: timeSeries,
            baselines: baselines,
            todayScore: overallScore.score,
            todayAnomalyCount: anomalies.count
        )
    }

    /// Get the top N insights
    func topInsights(_ count: Int = 3) -> [Insight] {
        Array(insights.prefix(count))
    }

    /// Get score for a specific category
    func score(for category: HealthCategory) -> HealthScore? {
        categoryScores.first { $0.category == category }
    }

    /// Get trend for a specific metric
    func trend(for metric: HealthMetric) -> TrendAnalyzer.TrendResult? {
        trends[metric]
    }

    /// Get anomaly for a specific metric
    func anomaly(for metric: HealthMetric) -> AnomalyDetector.AnomalyResult? {
        anomalies.first { $0.metric == metric }
    }

    /// Get insights for a specific metric
    func insights(for metric: HealthMetric) -> [Insight] {
        insights.filter { $0.metric == metric }
    }

    /// Get insights for a specific category
    func insights(for category: HealthCategory) -> [Insight] {
        InsightCoordinator.coordinate(insights.filter { $0.metric.category == category })
    }

    // MARK: - Global Insight Deduplication

    /// Remove duplicate insights about the same metric across all analyzers.
    /// Keeps max 2 per metric: best causal-chain + best other (by priority score).
    static func deduplicateInsights(_ insights: [Insight]) -> [Insight] {
        var grouped: [HealthMetric: [Insight]] = [:]
        for insight in insights {
            grouped[insight.metric, default: []].append(insight)
        }

        var result: [Insight] = []
        for (_, metricInsights) in grouped {
            if metricInsights.count <= 1 {
                result.append(contentsOf: metricInsights)
                continue
            }

            let causalChains = metricInsights.filter { $0.category == .causalChain }
            let others = metricInsights.filter { $0.category != .causalChain }

            // Keep the best causal chain if any
            if let bestCausal = causalChains.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestCausal)
            }

            // Keep the single best non-causal insight
            if let bestOther = others.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestOther)
            }
        }

        return result.sorted { $0.priorityScore > $1.priorityScore }
    }
}
