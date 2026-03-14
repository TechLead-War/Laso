import Foundation

// MARK: - InsightAnalyzer Protocol

/// Unified interface for all insight-producing analyzers.
///
/// Conforming types receive a single `AnalysisContext` containing all available
/// data and return `[Insight]`. This replaces the previous pattern where each
/// analyzer had a unique parameter signature, making orchestration and
/// coordination impossible without hard-coding every call site.
///
/// Conformance is added via extensions so existing static methods stay intact.
protocol InsightAnalyzer {
    /// Stable identifier for logging and debugging
    static var analyzerID: String { get }

    /// The primary InsightCategory this analyzer produces
    static var insightCategory: InsightCategory { get }

    /// Generate insights from the shared analysis context.
    /// Each analyzer pulls only the data it needs from the context.
    static func generateInsights(context: AnalysisContext) -> [Insight]
}

// MARK: - AnalysisContext

/// All data available for insight generation, passed to every `InsightAnalyzer`.
///
/// Core fields (timeSeries, baselines, trends, anomalies) are always populated.
/// Heavy fields (correlations, historicalContext, etc.) are empty during Phase 2A
/// and filled after Phase 2B computation completes.
/// Specialized fields (cycleFlowSamples, scoreHistory, etc.) are populated when
/// the data source is available.
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
