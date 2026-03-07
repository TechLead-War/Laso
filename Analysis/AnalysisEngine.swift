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
    /// Single highest-impact daily action
    var dailyAction: DailyAction? { mlOrchestrator.dailyAction }
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
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = []
    ) {
        runCoreAnalysis(timeSeries: timeSeries)
        runDeferredEssentials(timeSeries: timeSeries, cycleFlowSamples: cycleFlowSamples)
        runDeferredHeavy(timeSeries: timeSeries)
    }

    // MARK: - Phase 1: Core Analysis (required before UI renders)

    /// Computes baselines, trends, anomalies, and scores — the minimum needed to render the UI.
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

    // MARK: - Phase 2A: Deferred Essentials (lightweight, runs immediately after core)

    /// Runs lightweight insight generators, health risks, and illness warnings.
    /// These are cheap (~15K operations total) and provide Home tab content quickly.
    func runDeferredEssentials(
        timeSeries: [HealthMetric: MetricTimeSeries],
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = []
    ) {
        let coreBaselines = baselines
        let coreTrends = trends
        let coreAnomalies = anomalies

        // ── Lightweight insight generators (no correlations/historical needed) ──
        var allInsights = InsightGenerator.generate(
            anomalies: coreAnomalies,
            trends: coreTrends,
            baselines: coreBaselines,
            historicalContext: [:],
            correlations: [],
            timeSeries: timeSeries
        )
        allInsights.append(contentsOf: RecoveryAnalyzer.generateInsights(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends
        ))
        allInsights.append(contentsOf: WorkoutEffectivenessAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: SleepPerformanceAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: WeeklyPatternAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: PersonalRecordAnalyzer.generateInsights(timeSeries: timeSeries))
        allInsights.append(contentsOf: CyclePhaseAnalyzer.generateInsights(
            timeSeries: timeSeries,
            menstrualFlowSamples: cycleFlowSamples
        ))
        allInsights.append(contentsOf: MultiMetricClusterAnalyzer.generateInsights(
            anomalies: coreAnomalies, trends: coreTrends, baselines: coreBaselines
        ))

        // ── Clinical intelligence (lightweight, single-metric) ──
        allInsights.append(contentsOf: ClinicalIntelligence.generateInsights(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends
        ))

        // ── Lightweight secondary analyzers ──
        let newHealthRisks = HealthRiskEngine.assessAllRisks(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends, anomalies: coreAnomalies
        )
        let newIllnessWarnings = IllnessEarlyWarning.evaluate(timeSeries: timeSeries, baselines: coreBaselines)
        allInsights.append(contentsOf: IllnessEarlyWarning.generateInsights(from: newIllnessWarnings))

        // ML insights (if previously computed — we don't trigger ML here)
        if mlOrchestrator.hasRunOnce {
            allInsights.append(contentsOf: mlOrchestrator.generateInsights())
        }

        allInsights.sort { $0.priorityScore > $1.priorityScore }

        // ── Batch apply essentials ──
        insights = allInsights
        healthRisks = newHealthRisks
        illnessWarnings = newIllnessWarnings
    }

    // MARK: - Phase 2B: Deferred Heavy (expensive, runs with delay)

    /// Runs correlations, historical analysis, cross-metric anomaly detection, and causal chains.
    /// These are the CPU-heavy operations (~300K+ operations) that should run with thermal breaks.
    /// Skips computation if results are fresh (within TTL) and `force` is false.
    func runDeferredHeavy(timeSeries: [HealthMetric: MetricTimeSeries], force: Bool = false) {
        guard force || needsHeavyAnalysis else {
            isAnalyzing = false
            return
        }

        let coreBaselines = baselines
        let coreTrends = trends
        let coreAnomalies = anomalies

        // ── Heavy cross-metric analysis ──
        let newCorrelations = CorrelationAnalyzer.analyzeAll(timeSeries: timeSeries)
        let newHistoricalContext = HistoricalAnalyzer.analyzeAll(
            timeSeries: timeSeries,
            baselines: coreBaselines
        )
        let newCrossMetricAnomalies = CrossMetricAnomalyDetector.detect(
            timeSeries: timeSeries, baselines: coreBaselines
        )

        // ── Insights that need correlations/historical ──
        var heavyInsights: [Insight] = []
        heavyInsights.append(contentsOf: CorrelationAnalyzer.generateInsights(from: newCorrelations))
        heavyInsights.append(contentsOf: HistoricalAnalyzer.generateInsights(
            historicalContext: newHistoricalContext, baselines: coreBaselines
        ))
        heavyInsights.append(contentsOf: CognitiveEnergyAnalyzer.generateInsights(
            timeSeries: timeSeries, baselines: coreBaselines, trends: coreTrends, correlations: newCorrelations
        ))
        heavyInsights.append(contentsOf: CrossMetricAnomalyDetector.generateInsights(from: newCrossMetricAnomalies))

        // ── Nutrition correlation analysis ──
        let nutritionCorrelations = NutritionCorrelationAnalyzer.analyze(timeSeries: timeSeries)
        heavyInsights.append(contentsOf: NutritionCorrelationAnalyzer.generateInsights(from: nutritionCorrelations))

        // ── Causal chains (needs correlations) ──
        let newCausalChains = CausalChainEngine.buildChains(
            correlations: newCorrelations, anomalies: coreAnomalies,
            trends: coreTrends, timeSeries: timeSeries, baselines: coreBaselines
        )
        heavyInsights.append(contentsOf: CausalChainEngine.generateInsights(from: newCausalChains))

        // Merge heavy insights into the existing insights from essentials (deduplicated)
        var mergedInsights = insights
        mergedInsights.append(contentsOf: heavyInsights)
        mergedInsights = Self.deduplicateInsights(mergedInsights)

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
        anomalyCounts: [Date: Int]
    ) async {
        await mlOrchestrator.runMLAnalysis(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            ruleBasedAnomalies: anomalies,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts
        )

        // After ML completes, regenerate ML insights and deduplicate
        let mlInsights = mlOrchestrator.generateInsights()
        insights.append(contentsOf: mlInsights)
        insights = Self.deduplicateInsights(insights)

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
        Self.deduplicateInsights(insights.filter { $0.metric.category == category })
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
