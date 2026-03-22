import Foundation
import Observation

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

    // MARK: - Convenience Accessors

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
    /// TTL for heavy analysis. correlations/historical/cross-metric change slowly.
    private static let heavyAnalysisTTL: TimeInterval = 21600  // 6 hours

    /// Whether the heavy analysis phase needs to run (expired or never ran).
    var needsHeavyAnalysis: Bool {
        guard let last = lastHeavyAnalysisDate else { return true }
        return Date().timeIntervalSince(last) >= Self.heavyAnalysisTTL
    }

    // MARK: - ML Integration
    let mlOrchestrator = MLOrchestrator()
    var tomorrowRiskPrediction: MLPrediction? { mlOrchestrator.tomorrowRiskPrediction }
    var currentHealthState: HealthState? { mlOrchestrator.currentHealthState }
    var discoveredPatterns: [DiscoveredPattern] { mlOrchestrator.discoveredPatterns }
    var healthSignalReport: PredictiveHealthSignals.HealthSignalReport? { mlOrchestrator.healthSignalReport }
    var personalizationStatus: PersonalizationBlender.PersonalizationStatus? { mlOrchestrator.personalizationStatus }
    var dataSufficiency: UncertaintyEstimator.DataSufficiency? { mlOrchestrator.dataSufficiency }
    var componentReadiness: [UncertaintyEstimator.ComponentReadiness] { mlOrchestrator.componentReadiness }

    init() {
        baselines = persistence.loadBaselines()
        lastAnalysis = persistence.loadLastAnalysisDate()
    }

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

    func runCoreAnalysis(timeSeries: [HealthMetric: MetricTimeSeries], focusCategories: Set<HealthCategory> = []) {
        isAnalyzing = true

        // Step 1: Update baselines
        let newBaselines = BaselineCalculator.updateBaselines(
            existing: baselines,
            timeSeries: timeSeries
        )
        persistence.saveBaselines(newBaselines)

        var newTrends: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
        for (metric, series) in timeSeries {
            guard series.values.count >= 3 else { continue }
            newTrends[metric] = TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter)
        }

        var newAnomalies = AnomalyDetector.detectAll(timeSeries: timeSeries, baselines: newBaselines)

        // Merge ML forecast-based anomalies for metrics not already flagged
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

        var newCategoryScores: [HealthScore] = []
        for category in HealthCategory.allCases {
            let metricScores = metricScoresByCategory[category] ?? []
            guard !metricScores.isEmpty else { continue }
            newCategoryScores.append(HealthScorer.scoreCategory(category: category, metricScores: metricScores))
        }

        let adaptiveWeights = HealthScorer.adaptiveCategoryWeights(
            categoryScores: newCategoryScores,
            anomalies: newAnomalies,
            baselines: newBaselines,
            focusCategories: focusCategories
        )
        let rawOverallScore = HealthScorer.overallScore(categoryScores: newCategoryScores, weights: adaptiveWeights)
        let newOverallScore = HealthScore(
            score: HealthScorer.applyCoverageAdjustment(rawScore: rawOverallScore.score, baselines: newBaselines),
            breakdown: rawOverallScore.breakdown,
            generatedAt: rawOverallScore.generatedAt
        )
        let newScoreExplanation = HealthScorer.explainOverallScore(
            categoryScores: newCategoryScores,
            weights: adaptiveWeights,
            anomalies: newAnomalies,
            trends: newTrends
        )

        baselines = newBaselines
        trends = newTrends
        anomalies = newAnomalies
        categoryScores = newCategoryScores
        overallScore = newOverallScore
        scoreExplanation = newScoreExplanation
        lastAnalysis = Date()
        persistence.saveLastAnalysisDate(Date())
    }

    // MARK: - Deferred Essentials

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

        let context = AnalysisContext(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            anomalies: anomalies,
            cycleFlowSamples: cycleFlowSamples,
            illnessWarnings: newIllnessWarnings
        )

        var allInsights = AnalyzerRegistry.runAll(AnalyzerRegistry.essential, context: context)

        // ML insights are appended exclusively in runMLAnalysis to avoid duplicates.
        allInsights = InsightCoordinator.coordinate(allInsights)

        insights = allInsights
        healthRisks = newHealthRisks
        illnessWarnings = newIllnessWarnings
    }

    // MARK: - Deferred Heavy

    func runDeferredHeavy(timeSeries: [HealthMetric: MetricTimeSeries], force: Bool = false) {
        guard force || needsHeavyAnalysis else {
            isAnalyzing = false
            return
        }

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

        let heavyInsights = AnalyzerRegistry.runAll(AnalyzerRegistry.heavy, context: context)

        var mergedInsights = insights
        mergedInsights.append(contentsOf: heavyInsights)
        mergedInsights = InsightCoordinator.coordinate(mergedInsights)

        correlations = newCorrelations
        historicalContext = newHistoricalContext
        crossMetricAnomalies = newCrossMetricAnomalies
        causalChains = newCausalChains
        insights = mergedInsights
        lastHeavyAnalysisDate = Date()
        isAnalyzing = false
    }

    // MARK: - ML Pipeline

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

        insights.append(contentsOf: mlOrchestrator.generateInsights())
        insights = InsightCoordinator.coordinate(insights)

        mlOrchestrator.trainIncremental(
            timeSeries: timeSeries,
            baselines: baselines,
            todayScore: overallScore.score,
            todayAnomalyCount: anomalies.count
        )
    }

    func topInsights(_ count: Int = 3) -> [Insight] {
        Array(insights.prefix(count))
    }

    func score(for category: HealthCategory) -> HealthScore? {
        categoryScores.first { $0.category == category }
    }

    func trend(for metric: HealthMetric) -> TrendAnalyzer.TrendResult? {
        trends[metric]
    }

    func anomaly(for metric: HealthMetric) -> AnomalyDetector.AnomalyResult? {
        anomalies.first { $0.metric == metric }
    }

    func insights(for metric: HealthMetric) -> [Insight] {
        insights.filter { $0.metric == metric }
    }

    func insights(for category: HealthCategory) -> [Insight] {
        InsightCoordinator.coordinate(insights.filter { $0.metric.category == category })
    }
}
