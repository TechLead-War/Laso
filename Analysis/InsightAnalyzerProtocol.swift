import Foundation

protocol InsightAnalyzer {
    static var analyzerID: String { get }
    static var insightCategory: InsightCategory { get }
    static func generateInsights(context: AnalysisContext) -> [Insight]
}

/// Shared data bag passed to every InsightAnalyzer.
/// Core fields are always populated; heavy fields are empty until Phase 2B completes.
struct AnalysisContext {

    // MARK: Core (always available after Phase 1)

    let timeSeries: [HealthMetric: MetricTimeSeries]
    let baselines: [HealthMetric: UserBaseline]
    let trends: [HealthMetric: TrendAnalyzer.TrendResult]
    let anomalies: [AnomalyDetector.AnomalyResult]

    // MARK: Heavy Results (empty in essential phase, filled after heavy phase)

    let correlations: [HealthCorrelation]
    let historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext]
    let crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly]
    let causalChains: [CausalChain]

    // MARK: Specialized Inputs

    let cycleFlowSamples: [HealthKitManager.MenstrualFlowSample]
    let illnessWarnings: [IllnessEarlyWarning.Warning]
    let scoreHistory: [(date: Date, score: Int)]
    let categoryScores: [HealthScore]
    let baselineHistory: [HealthMetric: [(date: Date, baseline: UserBaseline)]]

    init(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        anomalies: [AnomalyDetector.AnomalyResult],
        correlations: [HealthCorrelation] = [],
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] = [:],
        crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] = [],
        causalChains: [CausalChain] = [],
        cycleFlowSamples: [HealthKitManager.MenstrualFlowSample] = [],
        illnessWarnings: [IllnessEarlyWarning.Warning] = [],
        scoreHistory: [(date: Date, score: Int)] = [],
        categoryScores: [HealthScore] = [],
        baselineHistory: [HealthMetric: [(date: Date, baseline: UserBaseline)]] = [:]
    ) {
        self.timeSeries = timeSeries
        self.baselines = baselines
        self.trends = trends
        self.anomalies = anomalies
        self.correlations = correlations
        self.historicalContext = historicalContext
        self.crossMetricAnomalies = crossMetricAnomalies
        self.causalChains = causalChains
        self.cycleFlowSamples = cycleFlowSamples
        self.illnessWarnings = illnessWarnings
        self.scoreHistory = scoreHistory
        self.categoryScores = categoryScores
        self.baselineHistory = baselineHistory
    }
}
