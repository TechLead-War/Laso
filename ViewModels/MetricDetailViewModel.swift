import Foundation
import Observation

/// ViewModel for the metric detail deep-dive view with charts, stats, moving averages, and baseline data
@Observable
final class MetricDetailViewModel {
    let metric: HealthMetric
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine

    var selectedTimeRange: Int = 30 // days

    var timeSeries: MetricTimeSeries? {
        healthKitManager.timeSeries[metric]
    }

    /// Period-aware trend computed from the selected time range
    var trend: TrendAnalyzer.TrendResult? {
        guard let series = timeSeries, series.values.count >= 3 else { return nil }
        return TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter, days: selectedTimeRange)
    }

    var anomaly: AnomalyDetector.AnomalyResult? {
        analysisEngine.anomaly(for: metric)
    }

    var baseline: UserBaseline? {
        analysisEngine.baselines[metric]
    }

    var insights: [Insight] {
        analysisEngine.insights(for: metric)
    }

    var chartSamples: [MetricSample] {
        guard let series = timeSeries else { return [] }
        return series.samples(lastDays: selectedTimeRange)
    }

    var currentValue: String {
        guard let series = timeSeries, let value = series.latestValue else { return "--" }
        return formatValue(value)
    }

    var averageValue: String {
        guard let series = timeSeries else { return "--" }
        let avg = series.mean(lastDays: selectedTimeRange)
        return formatValue(avg)
    }

    var trendDirection: TrendDirection {
        trend?.direction ?? .stable
    }

    var periodChangeLabel: String {
        switch selectedTimeRange {
        case 7: return "WoW Change"
        case 30: return "vs Prior 30D"
        case 90: return "vs Prior 3M"
        case 180: return "vs Prior 6M"
        default: return "Change"
        }
    }

    var weekOverWeekChange: String {
        guard let trend else { return "--" }
        let change = trend.weekOverWeekChange
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change))%"
    }

    var normalRange: RulesConfiguration.NormalRange {
        RulesConfiguration.normalRange(for: metric)
    }

    var deviationFromBaseline: String {
        guard let anomaly else { return "--" }
        let sign = anomaly.deviationPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", anomaly.deviationPercent))%"
    }

    var isOutsideNormalRange: Bool {
        anomaly?.outsideNormalRange ?? false
    }

    // MARK: - Score Breakdown

    var scoreBreakdown: [ScoreComponent] {
        guard let categoryScore = analysisEngine.score(for: metric.category) else { return [] }
        return categoryScore.breakdown.filter { $0.metric == metric }
    }

    init(metric: HealthMetric, healthKitManager: HealthKitManager, analysisEngine: AnalysisEngine) {
        self.metric = metric
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
    }

    func formatValue(_ value: Double) -> String {
        switch metric {
        case .steps, .activeCalories, .basalCalories, .flightsClimbed:
            return String(format: "%.0f", value)
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateRecovery,
             .bloodPressureSystolic, .bloodPressureDiastolic:
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
}
