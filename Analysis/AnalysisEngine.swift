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

    init() {
        baselines = persistence.loadBaselines()
        lastAnalysis = persistence.loadLastAnalysisDate()
    }

    /// Run the full analysis pipeline on the given time series data
    func runFullAnalysis(timeSeries: [HealthMetric: MetricTimeSeries]) {
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastAnalysis = Date()
            persistence.saveLastAnalysisDate(Date())
        }

        // Step 1: Update baselines
        baselines = BaselineCalculator.updateBaselines(
            existing: baselines,
            timeSeries: timeSeries
        )
        persistence.saveBaselines(baselines)

        // Step 2: Analyze trends for each metric
        var newTrends: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
        for (metric, series) in timeSeries {
            guard series.values.count >= 3 else { continue }
            let trend = TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter)
            newTrends[metric] = trend
        }
        trends = newTrends

        // Step 3: Detect anomalies
        anomalies = AnomalyDetector.detectAll(timeSeries: timeSeries, baselines: baselines)

        // Step 4: Compute health scores
        var metricScoresByCategory: [HealthCategory: [(metric: HealthMetric, score: Int, components: [ScoreComponent])]] = [:]

        for category in HealthCategory.allCases {
            metricScoresByCategory[category] = []
        }

        for metric in HealthMetric.allCases {
            let anomaly = anomalies.first { $0.metric == metric }
            let trend = trends[metric]

            guard anomaly != nil || trend != nil else { continue }

            let (score, components) = HealthScorer.scoreMetric(
                metric: metric,
                anomaly: anomaly,
                trend: trend
            )

            metricScoresByCategory[metric.category, default: []].append(
                (metric: metric, score: score, components: components)
            )
        }

        // Step 5: Category scores — only for categories that have actual data
        var newCategoryScores: [HealthScore] = []
        for category in HealthCategory.allCases {
            let metricScores = metricScoresByCategory[category] ?? []
            guard !metricScores.isEmpty else { continue }
            let categoryScore = HealthScorer.scoreCategory(category: category, metricScores: metricScores)
            newCategoryScores.append(categoryScore)
        }
        categoryScores = newCategoryScores

        // Step 6: Overall score with adaptive weights
        let adaptiveWeights = HealthScorer.adaptiveCategoryWeights(
            categoryScores: categoryScores,
            anomalies: anomalies,
            baselines: baselines
        )
        overallScore = HealthScorer.overallScore(categoryScores: categoryScores, weights: adaptiveWeights)

        // Score explanation for transparency
        scoreExplanation = HealthScorer.explainOverallScore(
            categoryScores: categoryScores,
            weights: adaptiveWeights,
            anomalies: anomalies,
            trends: trends
        )

        // Step 7: Compute correlations early (needed by InsightGenerator for context)
        correlations = CorrelationAnalyzer.analyzeAll(timeSeries: timeSeries)

        // Step 7a: Historical context (needed by InsightGenerator)
        historicalContext = HistoricalAnalyzer.analyzeAll(
            timeSeries: timeSeries,
            baselines: baselines
        )

        // Step 7b: Generate base insights with full context
        insights = InsightGenerator.generate(
            anomalies: anomalies,
            trends: trends,
            baselines: baselines,
            historicalContext: historicalContext,
            correlations: correlations,
            timeSeries: timeSeries
        )

        // Step 7c: Correlation insights
        let correlationInsights = CorrelationAnalyzer.generateInsights(from: correlations)
        insights.append(contentsOf: correlationInsights)

        // Step 7d: Recovery insights
        let recoveryInsights = RecoveryAnalyzer.generateInsights(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends
        )
        insights.append(contentsOf: recoveryInsights)

        // Step 7e: Workout effectiveness insights
        let workoutInsights = WorkoutEffectivenessAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: workoutInsights)

        // Step 7f: Sleep-performance insights
        let sleepPerfInsights = SleepPerformanceAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: sleepPerfInsights)

        // Step 7g: Weekly pattern insights
        let weeklyInsights = WeeklyPatternAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: weeklyInsights)

        // Step 7h: Personal record insights
        let prInsights = PersonalRecordAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: prInsights)

        // Step 7i: Multi-metric cluster insights (with baselines for actual values)
        let clusterInsights = MultiMetricClusterAnalyzer.generateInsights(
            anomalies: anomalies,
            trends: trends,
            baselines: baselines
        )
        insights.append(contentsOf: clusterInsights)

        // Step 7j: Cognitive & Energy insights
        let cognitiveInsights = CognitiveEnergyAnalyzer.generateInsights(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            correlations: correlations
        )
        insights.append(contentsOf: cognitiveInsights)

        // Step 7h: Deep historical insights (leverages ALL available data — years, not days)
        // historicalContext was already computed in Step 7 for enriching base insights.
        let historicalInsights = HistoricalAnalyzer.generateInsights(
            historicalContext: historicalContext,
            baselines: baselines
        )
        insights.append(contentsOf: historicalInsights)

        // Step 8: Assess health risks
        healthRisks = HealthRiskEngine.assessAllRisks(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            anomalies: anomalies
        )

        // Step 9: Illness early warning
        illnessWarnings = IllnessEarlyWarning.evaluate(
            timeSeries: timeSeries,
            baselines: baselines
        )
        let illnessInsights = IllnessEarlyWarning.generateInsights(from: illnessWarnings)
        insights.append(contentsOf: illnessInsights)

        // Step 10: Cross-metric anomaly detection
        crossMetricAnomalies = CrossMetricAnomalyDetector.detect(
            timeSeries: timeSeries,
            baselines: baselines
        )
        let crossMetricInsights = CrossMetricAnomalyDetector.generateInsights(from: crossMetricAnomalies)
        insights.append(contentsOf: crossMetricInsights)

        // Step 11: Causal chain narratives
        causalChains = CausalChainEngine.buildChains(
            correlations: correlations,
            anomalies: anomalies,
            trends: trends,
            timeSeries: timeSeries,
            baselines: baselines
        )
        let causalInsights = CausalChainEngine.generateInsights(from: causalChains)
        insights.append(contentsOf: causalInsights)

        // Final: deduplicate and re-sort all insights
        insights.sort { $0.priorityScore > $1.priorityScore }
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
