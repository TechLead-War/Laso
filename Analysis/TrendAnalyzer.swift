import Foundation

/// Analyzes trends in metric time series data using statistical methods
struct TrendAnalyzer {

    struct TrendResult {
        let direction: TrendDirection
        let slope: Double              // Rate of change per day
        let weekOverWeekChange: Double  // Percentage change this week vs last
        let movingAverage7d: Double
        let movingAverage30d: Double
        let movingAverage90d: Double
    }

    /// Analyze trend for a metric's time series (uses all data)
    static func analyze(series: MetricTimeSeries, higherIsBetter: Bool) -> TrendResult {
        return analyze(series: series, higherIsBetter: higherIsBetter, days: nil)
    }

    /// Analyze trend for a metric's time series within a specific time range
    static func analyze(series: MetricTimeSeries, higherIsBetter: Bool, days: Int?) -> TrendResult {
        // Filter samples to the requested period
        let periodSamples: [MetricSample]
        if let days {
            periodSamples = series.samples(lastDays: days)
        } else {
            periodSamples = series.sortedSamples
        }

        guard !periodSamples.isEmpty else {
            return TrendResult(direction: .stable, slope: 0, weekOverWeekChange: 0, movingAverage7d: 0, movingAverage30d: 0, movingAverage90d: 0)
        }

        // Linear regression on the period's data (use last 1/3 of period for slope)
        let regressionDays = max((days ?? 30) / 3, 7)
        let regressionSamples = series.samples(lastDays: regressionDays).map(\.value)
        let slope = regressionSamples.linearRegression.slope

        // Moving averages (always from full dataset for comparison)
        let ma7 = series.mean(lastDays: 7)
        let ma30 = series.mean(lastDays: 30)
        let ma90 = series.mean(lastDays: 90)

        // Period-over-period comparison (this period vs previous same-length period)
        let periodDays = days ?? 30
        let halfPeriod = periodDays / 2
        let recentHalf = series.samples(lastDays: halfPeriod).map(\.value)
        let olderHalfSamples = periodSamples.filter { sample in
            let daysAgo = Calendar.current.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
            return daysAgo >= halfPeriod && daysAgo < periodDays
        }
        let olderHalf = olderHalfSamples.map(\.value)

        let periodChange: Double
        if !olderHalf.isEmpty && olderHalf.mean != 0 {
            periodChange = ((recentHalf.mean - olderHalf.mean) / olderHalf.mean) * 100
        } else {
            periodChange = 0
        }

        let direction = classifyDirection(
            slope: slope,
            weekOverWeekChange: periodChange,
            higherIsBetter: higherIsBetter
        )

        return TrendResult(
            direction: direction,
            slope: slope,
            weekOverWeekChange: periodChange,
            movingAverage7d: ma7,
            movingAverage30d: ma30,
            movingAverage90d: ma90
        )
    }

    private static func classifyDirection(slope: Double, weekOverWeekChange: Double, higherIsBetter: Bool) -> TrendDirection {
        let threshold = RulesConfiguration.trendSlopeThreshold

        // Normalize slope direction based on whether higher is better
        let effectiveSlope = higherIsBetter ? slope : -slope
        let effectiveWoW = higherIsBetter ? weekOverWeekChange : -weekOverWeekChange

        // Both slope and week-over-week should agree for a clear trend
        if effectiveSlope > threshold && effectiveWoW > 2 {
            return .improving
        } else if effectiveSlope < -threshold && effectiveWoW < -2 {
            return .declining
        } else {
            return .stable
        }
    }
}
