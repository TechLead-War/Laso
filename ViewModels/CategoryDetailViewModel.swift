import Foundation
import Observation

/// ViewModel for category detail view showing all metrics, analytics, and trends in a category
@Observable
final class CategoryDetailViewModel {
    let category: HealthCategory
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine

    var selectedTimeRange: Int = 30 // days

    var metrics: [HealthMetric] {
        category.metrics
    }

    var categoryScore: HealthScore? {
        analysisEngine.score(for: category)
    }

    var insights: [Insight] {
        analysisEngine.insights(for: category)
    }

    // MARK: - Category-Level Analytics

    /// Number of metrics with anomalies in this category
    var anomalousMetricCount: Int {
        metrics.filter { metric in
            guard let anomaly = analysisEngine.anomaly(for: metric) else { return false }
            return anomaly.severity >= .warning
        }.count
    }

    /// Number of metrics with data available
    var activeMetricCount: Int {
        metrics.filter { healthKitManager.timeSeries[$0] != nil }.count
    }

    /// Category trend summary: count of improving, stable, declining (period-aware)
    var trendSummary: (improving: Int, stable: Int, declining: Int) {
        var improving = 0
        var stable = 0
        var declining = 0
        for metric in metrics {
            guard let series = healthKitManager.timeSeries[metric], series.values.count >= 3 else { continue }
            let trend = TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter, days: selectedTimeRange)
            switch trend.direction {
            case .improving: improving += 1
            case .stable: stable += 1
            case .declining: declining += 1
            }
        }
        return (improving, stable, declining)
    }

    /// Metrics sorted by severity (critical first, then warning, then by trend)
    var metricsSortedBySeverity: [HealthMetric] {
        metrics.sorted { a, b in
            let aSeverity = analysisEngine.anomaly(for: a)?.severity ?? .info
            let bSeverity = analysisEngine.anomaly(for: b)?.severity ?? .info
            if aSeverity != bSeverity { return aSeverity > bSeverity }

            let aTrend = analysisEngine.trend(for: a)?.direction ?? .stable
            let bTrend = analysisEngine.trend(for: b)?.direction ?? .stable
            if aTrend == .declining && bTrend != .declining { return true }
            if bTrend == .declining && aTrend != .declining { return false }
            return false
        }
    }

    /// Period change for a metric (period-aware)
    func weekOverWeekChange(for metric: HealthMetric) -> String {
        guard let series = healthKitManager.timeSeries[metric], series.values.count >= 3 else { return "--" }
        let trend = TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter, days: selectedTimeRange)
        let change = trend.weekOverWeekChange
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change))%"
    }

    init(category: HealthCategory, healthKitManager: HealthKitManager, analysisEngine: AnalysisEngine) {
        self.category = category
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
    }

    /// Get time series for a metric
    func timeSeries(for metric: HealthMetric) -> MetricTimeSeries? {
        healthKitManager.timeSeries[metric]
    }

    /// Get trend for a metric (period-aware)
    func trend(for metric: HealthMetric) -> TrendDirection? {
        guard let series = healthKitManager.timeSeries[metric], series.values.count >= 3 else { return nil }
        return TrendAnalyzer.analyze(series: series, higherIsBetter: metric.higherIsBetter, days: selectedTimeRange).direction
    }

    /// Get latest value for a metric
    func latestValue(for metric: HealthMetric) -> String {
        guard let series = healthKitManager.timeSeries[metric],
              let value = series.latestValue else {
            return "--"
        }
        return formatValue(value, metric: metric)
    }

    /// Get anomaly severity for a metric (if any)
    func severity(for metric: HealthMetric) -> Severity? {
        let anomaly = analysisEngine.anomaly(for: metric)
        guard let anomaly, anomaly.severity != .info else { return nil }
        return anomaly.severity
    }

    private func formatValue(_ value: Double, metric: HealthMetric) -> String {
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
