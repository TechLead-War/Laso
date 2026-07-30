import Foundation
import Observation

/// ViewModel for category detail view showing all metrics, analytics, and trends in a category
@MainActor @Observable
final class CategoryDetailViewModel {

    let category: HealthCategory
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine

    /// Cached trend results for the current `selectedTimeRange`. Cleared on
    /// range change so a tap recomputes once instead of every row × method.
    @ObservationIgnored
    private var trendCache: [HealthMetric: TrendAnalyzer.TrendResult]?

    /// Cached `valueForRange` strings — each row asks twice (visible text and
    /// accessibility label), so the memo halves the work outright.
    @ObservationIgnored
    private var valueCache: [HealthMetric: String] = [:]

    var selectedTimeRange: Int = TrendAnalyzer.homeTrendDays {
        didSet {
            if oldValue != selectedTimeRange {
                trendCache = nil
                valueCache.removeAll()
            }
        }
    }

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
            guard let trend = trendResult(for: metric) else { continue }
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

            let aTrend = trendResult(for: a)?.direction ?? .stable
            let bTrend = trendResult(for: b)?.direction ?? .stable
            if aTrend == .declining && bTrend != .declining { return true }
            if bTrend == .declining && aTrend != .declining { return false }
            return false
        }
    }

    /// Period change for a metric (period-aware)
    func weekOverWeekChange(for metric: HealthMetric) -> String {
        guard let trend = trendResult(for: metric) else { return "--" }
        return TrendAnalyzer.formattedPercentChange(trend.weekOverWeekChange)
    }

    /// Numeric period change for a metric — used to drive arrow direction in
    /// `TrendBadge` so the arrow follows the value, not sentiment.
    func numericWeekOverWeekChange(for metric: HealthMetric) -> Double? {
        trendResult(for: metric)?.weekOverWeekChange
    }

    /// Historical highlights for metrics in this category
    var historicalHighlights: [(metric: HealthMetric, text: String, icon: String)] {
        var results: [(metric: HealthMetric, text: String, icon: String, significance: Double)] = []
        let monthName = Date.cal.monthSymbols[Date.cal.component(.month, from: Date()) - 1]

        for metric in metrics {
            guard let ctx = analysisEngine.historicalContext[metric] else { continue }

            if let yoy = ctx.yearOverYearChange, abs(yoy) > 5 {
                let improving = metric.higherIsBetter ? yoy > 0 : yoy < 0
                results.append((
                    metric: metric,
                    text: "\(String(format: "%.0f", abs(yoy)))% \(improving ? "better" : "worse") than last \(monthName)",
                    icon: "calendar.badge.clock",
                    significance: abs(yoy)
                ))
            }

            if ctx.isAllTimeExtreme, ctx.totalDataPoints >= 180 {
                let isHigh = ctx.allTimePercentile >= 95
                results.append((
                    metric: metric,
                    text: "Near all-time \(isHigh ? "high" : "low")",
                    icon: "trophy.fill",
                    significance: 90
                ))
            }

            if let change = ctx.longTermChangePercent, abs(change) > 10, ctx.yearsOfData >= 1 {
                let improving = metric.higherIsBetter ? change > 0 : change < 0
                let period = "1 year"
                results.append((
                    metric: metric,
                    text: "\(improving ? "Up" : "Down") \(String(format: "%.0f", abs(change)))% over \(period)",
                    icon: "chart.line.uptrend.xyaxis",
                    significance: abs(change)
                ))
            }
        }

        results.sort { $0.significance > $1.significance }
        return Array(results.prefix(3)).map { ($0.metric, $0.text, $0.icon) }
    }

    init(category: HealthCategory, healthKitManager: HealthKitManager, analysisEngine: AnalysisEngine) {
        self.category = category
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
    }

    /// Get trend for a metric (period-aware)
    func trend(for metric: HealthMetric) -> TrendDirection? {
        trendResult(for: metric)?.direction
    }

    /// Get anomaly severity for a metric (if any)
    func severity(for metric: HealthMetric) -> Severity? {
        let anomaly = analysisEngine.anomaly(for: metric)
        guard let anomaly, anomaly.severity != .info else { return nil }
        return anomaly.severity
    }

    private func trendResult(for metric: HealthMetric) -> TrendAnalyzer.TrendResult? {
        if trendCache == nil {
            var dict: [HealthMetric: TrendAnalyzer.TrendResult] = [:]
            for m in metrics {
                if let result = TrendAnalyzer.canonicalTrend(
                    metric: m,
                    series: healthKitManager.timeSeries[m],
                    analysisEngine: analysisEngine,
                    days: selectedTimeRange
                ) {
                    dict[m] = result
                }
            }
            trendCache = dict
        }
        return trendCache?[metric]
    }

    /// Period-aware display value: average of samples within the selected
    /// range. Falls back to the latest sample when the range has no data.
    func valueForRange(for metric: HealthMetric) -> String {
        if let cached = valueCache[metric] { return cached }
        let value = computeValueForRange(for: metric)
        valueCache[metric] = value
        return value
    }

    private func computeValueForRange(for metric: HealthMetric) -> String {
        guard let series = healthKitManager.timeSeries[metric], !series.samples.isEmpty else {
            return "--"
        }
        let cutoff = Date.cal.date(byAdding: .day, value: -selectedTimeRange, to: Date()) ?? Date()
        // Binary-searched window; samples are sorted by the series init, so this
        // is the same set the linear filter produced.
        let inRange = series.samples(from: cutoff, until: .distantFuture)
        if inRange.isEmpty {
            return metric.formatValue(series.latestValue ?? 0)
        }
        let avg = inRange.map(\.value).reduce(0, +) / Double(inRange.count)
        return metric.formatValue(avg)
    }
}
