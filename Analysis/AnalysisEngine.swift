import Foundation
import Observation

/// Orchestrates the full analysis pipeline: baselines → trends → anomalies → scores → insights
@Observable
final class AnalysisEngine {
    private let persistence = PersistenceManager()

    var baselines: [HealthMetric: UserBaseline] = [:]
    var trends: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
    var anomalies: [AnomalyDetector.AnomalyResult] = []
    var insights: [Insight] = []
    var healthRisks: [HealthRisk] = []
    var overallScore: HealthScore = HealthScore(score: 100)
    var categoryScores: [HealthScore] = []
    var correlations: [HealthCorrelation] = []
    var historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] = [:]
    var illnessWarnings: [IllnessEarlyWarning.Warning] = []
    var crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] = []
    var causalChains: [CausalChain] = []
    var scoreExplanation: HealthScorer.ScoreExplanation?
    var isAnalyzing = false
    var lastAnalysis: Date?

    // MARK: - ML Integration
    let mlOrchestrator = MLOrchestrator()
    /// ML-predicted risk for tomorrow
    var tomorrowRiskPrediction: MLPrediction? { mlOrchestrator.tomorrowRiskPrediction }
    /// Current ML-classified health state
    var currentHealthState: HealthState? { mlOrchestrator.currentHealthState }
    /// Periodic patterns discovered by ML
    var discoveredPatterns: [DiscoveredPattern] { mlOrchestrator.discoveredPatterns }

    init() {
        baselines = persistence.loadBaselines()
        lastAnalysis = persistence.loadLastAnalysisDate()
    }

    /// Run the full analysis pipeline on the given time series data.
    /// Split into two phases:
    /// - `runCoreAnalysis`: baselines, trends, anomalies, scores, correlations (blocks UI)
    /// - `runDeferredAnalysis`: insight generators, health risks, illness, causal chains (background)
    func runFullAnalysis(timeSeries: [HealthMetric: MetricTimeSeries]) {
        runCoreAnalysis(timeSeries: timeSeries)
        runDeferredAnalysis(timeSeries: timeSeries)
    }

    // MARK: - Phase 1: Core Analysis (required before UI renders)

    /// Computes baselines, trends, anomalies, and scores — the minimum needed to render the UI.
    /// Correlations, historical context, insights, and risks are deferred to `runDeferredAnalysis`.
    /// All computation uses local variables; @Observable properties are batch-updated at the end
    /// to minimize UI re-render cascades.
    func runCoreAnalysis(timeSeries: [HealthMetric: MetricTimeSeries]) {
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

        // Step 6: Overall score with adaptive weights
        let adaptiveWeights = HealthScorer.adaptiveCategoryWeights(
            categoryScores: newCategoryScores,
            anomalies: newAnomalies,
            baselines: newBaselines
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

    // MARK: - Phase 2: Deferred Analysis (runs after UI renders)

    /// Runs correlations, historical analysis, all insight generators, health risk assessment,
    /// illness warnings, cross-metric anomaly detection, and causal chain analysis.
    /// Uses local variables and batch-applies results to minimize re-renders.
    func runDeferredAnalysis(timeSeries: [HealthMetric: MetricTimeSeries]) {
        // Snapshot core results (already set by runCoreAnalysis)
        let coreBaselines = baselines
        let coreTrends = trends
        let coreAnomalies = anomalies

        // ── Correlations + Historical context (moved from core for faster startup) ──
        let newCorrelations = CorrelationAnalyzer.analyzeAll(timeSeries: timeSeries)
        let newHistoricalContext = HistoricalAnalyzer.analyzeAll(
            timeSeries: timeSeries,
            baselines: coreBaselines
        )

        // ── Insight generators ──
        var allInsights = InsightGenerator.generate(
            anomalies: coreAnomalies,
            trends: coreTrends,
            baselines: coreBaselines,
            historicalContext: newHistoricalContext,
            correlations: newCorrelations,
            timeSeries: timeSeries
        )
        allInsights.append(contentsOf: CorrelationAnalyzer.generateInsights(from: newCorrelations))
        allInsights.append(contentsOf: RecoveryAnalyzer.generateInsights(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends
        ))
        allInsights.append(contentsOf: WorkoutEffectivenessAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: SleepPerformanceAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: WeeklyPatternAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: PersonalRecordAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: MultiMetricClusterAnalyzer.generateInsights(
            anomalies: coreAnomalies, trends: coreTrends, baselines: coreBaselines
        ))
        allInsights.append(contentsOf: CognitiveEnergyAnalyzer.generateInsights(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends, correlations: newCorrelations
        ))
        allInsights.append(contentsOf: HistoricalAnalyzer.generateInsights(
            historicalContext: newHistoricalContext, baselines: coreBaselines
        ))

        // ── Heavy secondary analyzers ──
        let newHealthRisks = HealthRiskEngine.assessAllRisks(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends, anomalies: coreAnomalies
        )

        let newIllnessWarnings = IllnessEarlyWarning.evaluate(timeSeries: timeSeries, baselines: coreBaselines)
        allInsights.append(contentsOf: IllnessEarlyWarning.generateInsights(from: newIllnessWarnings))

        let newCrossMetricAnomalies = CrossMetricAnomalyDetector.detect(timeSeries: timeSeries, baselines: coreBaselines)
        allInsights.append(contentsOf: CrossMetricAnomalyDetector.generateInsights(from: newCrossMetricAnomalies))

        let newCausalChains = CausalChainEngine.buildChains(
            correlations: newCorrelations, anomalies: coreAnomalies,
            trends: coreTrends, timeSeries: timeSeries, baselines: coreBaselines
        )
        allInsights.append(contentsOf: CausalChainEngine.generateInsights(from: newCausalChains))

        // ML insights
        if mlOrchestrator.hasRunOnce {
            allInsights.append(contentsOf: mlOrchestrator.generateInsights())
        }

        allInsights.sort { $0.priorityScore > $1.priorityScore }

        // ── Batch apply all deferred results ──
        correlations = newCorrelations
        historicalContext = newHistoricalContext
        insights = allInsights
        healthRisks = newHealthRisks
        illnessWarnings = newIllnessWarnings
        crossMetricAnomalies = newCrossMetricAnomalies
        causalChains = newCausalChains
        isAnalyzing = false
    }

    // MARK: - ML Pipeline

    /// Run the ML analysis pipeline asynchronously after rule-based analysis.
    /// Call this after `runFullAnalysis` with the same timeSeries data.
    func runMLAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int]
    ) async {
        await mlOrchestrator.runMLAnalysis(
            timeSeries: timeSeries,
            baselines: baselines,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts
        )

        // After ML completes, regenerate ML insights and re-sort
        let mlInsights = mlOrchestrator.generateInsights()
        insights.append(contentsOf: mlInsights)
        insights.sort { $0.priorityScore > $1.priorityScore }

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
        insights.filter { $0.metric.category == category }
    }
}
