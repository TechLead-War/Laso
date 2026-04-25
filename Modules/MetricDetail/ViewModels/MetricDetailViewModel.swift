import Foundation
import Observation

/// ViewModel for the metric detail deep-dive view with charts, stats, moving averages, and baseline data
@MainActor @Observable
final class MetricDetailViewModel {
    /// Pass 12 BE perf: cached current calendar. `historicalFacts` reads
    /// `Calendar.current.monthSymbols[component(.month, ...)]` on every render
    /// of the metric detail historical-context section.
    private static let cal: Calendar = Calendar.current

    let metric: HealthMetric
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine

    var selectedTimeRange: Int = TrendAnalyzer.homeTrendDays

    var timeSeries: MetricTimeSeries? {
        healthKitManager.timeSeries[metric]
    }

    /// Period-aware trend computed from the selected time range
    var trend: TrendAnalyzer.TrendResult? {
        TrendAnalyzer.canonicalTrend(
            metric: metric,
            series: timeSeries,
            analysisEngine: analysisEngine,
            days: selectedTimeRange
        )
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
        return metric.formatValue(value)
    }

    var averageValue: String {
        guard let series = timeSeries else { return "--" }
        let avg = series.mean(lastDays: selectedTimeRange)
        return metric.formatValue(avg)
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
        return TrendAnalyzer.formattedPercentChange(trend.weekOverWeekChange)
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

    // MARK: - Historical Context

    var historicalContext: HistoricalAnalyzer.HistoricalContext? {
        analysisEngine.historicalContext[metric]
    }

    /// Formatted historical facts for display (non-empty only when history is meaningful)
    var historicalFacts: [HistoricalFact] {
        guard let ctx = historicalContext else { return [] }
        var facts: [HistoricalFact] = []
        let monthName = Self.cal.monthSymbols[Self.cal.component(.month, from: Date()) - 1]

        // All-time percentile
        if ctx.totalDataPoints >= 90 {
            let pct = Int(ctx.allTimePercentile.rounded())
            let label: String
            if pct >= 90 { label = "Top \(100 - pct)% of your history" }
            else if pct <= 10 { label = "Bottom \(pct)% of your history" }
            else { label = "\(ordinal(pct)) percentile in your history" }
            facts.append(HistoricalFact(icon: "chart.bar.fill", text: label))
        }

        // Year-over-year
        if let yoy = ctx.yearOverYearChange, abs(yoy) > 3 {
            let direction = yoy > 0 ? "up" : "down"
            facts.append(HistoricalFact(
                icon: "calendar.badge.clock",
                text: "\(String(format: "%.0f", abs(yoy)))% \(direction) vs \(monthName) last year"
            ))
        }

        // Seasonal
        if let seasonalDev = ctx.seasonalDeviation, abs(seasonalDev) > 8, ctx.yearsOfData >= 1 {
            let direction = seasonalDev > 0 ? "above" : "below"
            facts.append(HistoricalFact(
                icon: "leaf.fill",
                text: "\(String(format: "%.0f", abs(seasonalDev)))% \(direction) your typical \(monthName)"
            ))
        }

        // Long-term trajectory
        if let change = ctx.longTermChangePercent, abs(change) > 5, ctx.totalDataPoints >= 180 {
            let direction = change > 0 ? "up" : "down"
            let period = "the past year"
            facts.append(HistoricalFact(
                icon: "chart.line.uptrend.xyaxis",
                text: "\(String(format: "%.0f", abs(change)))% \(direction) over \(period)"
            ))
        }

        // All-time extreme
        if ctx.isAllTimeExtreme, ctx.totalDataPoints >= 180 {
            let isHigh = ctx.allTimePercentile >= 95
            facts.append(HistoricalFact(
                icon: "trophy.fill",
                text: "Near all-time \(isHigh ? "high" : "low")"
            ))
        }

        return facts
    }

    struct HistoricalFact: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = n % 100
        if tens >= 11 && tens <= 13 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }

    // MARK: - Trend Overlay Line

    /// Moving average trend line for chart overlay, computed from selected time range
    var trendLineSamples: [MetricSample] {
        guard let series = timeSeries else { return [] }
        let samples = series.samples(lastDays: selectedTimeRange)
        guard samples.count >= 7 else { return [] }

        // Compute 7-day rolling average for the trend line
        let windowSize = min(7, max(3, samples.count / 5))
        var trendPoints: [MetricSample] = []
        for i in (windowSize - 1)..<samples.count {
            let window = samples[(i - windowSize + 1)...i]
            let avg = window.map(\.value).reduce(0, +) / Double(windowSize)
            trendPoints.append(MetricSample(date: samples[i].date, value: avg))
        }
        return trendPoints
    }

    // MARK: - Forecast Points

    /// Forecast extension from MLOrchestrator (1d, 3d, 7d horizons)
    var forecastSamples: [MetricSample] {
        guard let forecast = analysisEngine.mlOrchestrator.multiHorizonForecasts[metric] else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return forecast.horizons.compactMap { horizon in
            guard let futureDate = cal.date(byAdding: .day, value: horizon.horizon, to: today) else { return nil }
            return MetricSample(date: futureDate, value: horizon.value)
        }
    }

    // MARK: - This Month vs Last Month Comparison

    struct MonthComparison {
        let thisMonthAvg: Double
        let lastMonthAvg: Double
        let changePercent: Double
        let thisMonthLabel: String
        let lastMonthLabel: String
        let improving: Bool
    }

    var monthComparison: MonthComparison? {
        guard let series = timeSeries else { return nil }
        let cal = Calendar.current
        let now = Date()

        // This month: from start of current month to today
        guard let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return nil }
        let thisMonthSamples = series.samples(from: startOfThisMonth, to: now)

        // Last month: full previous month
        guard let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth),
              let endOfLastMonth = cal.date(byAdding: .day, value: -1, to: startOfThisMonth) else { return nil }
        let lastMonthSamples = series.samples(from: startOfLastMonth, to: endOfLastMonth)

        guard !thisMonthSamples.isEmpty, !lastMonthSamples.isEmpty else { return nil }

        let thisAvg = thisMonthSamples.valueMean
        let lastAvg = lastMonthSamples.valueMean
        guard lastAvg != 0 else { return nil }

        let change = ((thisAvg - lastAvg) / lastAvg) * 100
        let improving = metric.higherIsBetter ? change > 0 : change < 0

        let thisLabel = cal.monthSymbols[cal.component(.month, from: now) - 1]
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let lastLabel = cal.monthSymbols[cal.component(.month, from: lastMonthDate) - 1]

        return MonthComparison(
            thisMonthAvg: thisAvg,
            lastMonthAvg: lastAvg,
            changePercent: change,
            thisMonthLabel: thisLabel,
            lastMonthLabel: lastLabel,
            improving: improving
        )
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
}
