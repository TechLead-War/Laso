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

        // Step 6: Overall score — only from categories with data
        overallScore = HealthScorer.overallScore(categoryScores: categoryScores)

        // Step 7: Generate insights
        insights = InsightGenerator.generate(
            anomalies: anomalies,
            trends: trends,
            baselines: baselines
        )

        // Step 7a: Correlation analysis + insights
        correlations = CorrelationAnalyzer.analyzeAll(timeSeries: timeSeries)
        let correlationInsights = CorrelationAnalyzer.generateInsights(from: correlations)
        insights.append(contentsOf: correlationInsights)

        // Step 7b: Recovery insights
        let recoveryInsights = RecoveryAnalyzer.generateInsights(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends
        )
        insights.append(contentsOf: recoveryInsights)

        // Step 7c: Workout effectiveness insights
        let workoutInsights = WorkoutEffectivenessAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: workoutInsights)

        // Step 7d: Sleep-performance insights
        let sleepPerfInsights = SleepPerformanceAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: sleepPerfInsights)

        // Step 7e: Weekly pattern insights
        let weeklyInsights = WeeklyPatternAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: weeklyInsights)

        // Step 7f: Personal record insights
        let prInsights = PersonalRecordAnalyzer.generateInsights(timeSeries: timeSeries)
        insights.append(contentsOf: prInsights)

        // Step 7g: Multi-metric cluster insights
        let clusterInsights = MultiMetricClusterAnalyzer.generateInsights(
            anomalies: anomalies,
            trends: trends
        )
        insights.append(contentsOf: clusterInsights)

        // Re-sort combined insights by priority
        insights.sort { $0.priorityScore > $1.priorityScore }

        // Step 8: Assess health risks
        healthRisks = HealthRiskEngine.assessAllRisks(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            anomalies: anomalies
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
