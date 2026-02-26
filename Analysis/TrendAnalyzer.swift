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
        let movingAverage180d: Double   // 6-month average
        let movingAverage365d: Double   // 1-year average
        let inflection: Inflection      // Whether the trend is accelerating, decelerating, or reversing

        /// Rate-of-change classification: how fast is the metric changing?
        var rateOfChange: RateOfChange {
            let absWoW = abs(weekOverWeekChange)
            if absWoW > 15 { return .rapid }
            if absWoW > 8 { return .moderate }
            if absWoW > 2 { return .gradual }
            return .negligible
        }

        /// Whether the current value is above or below the long-term (1-year) average
        var longTermTrend: TrendDirection {
            guard movingAverage365d > 0 else { return .stable }
            let diff = (movingAverage30d - movingAverage365d) / movingAverage365d * 100
            if diff > 3 { return .improving }
            if diff < -3 { return .declining }
            return .stable
        }
    }

    /// Inflection detection: is the trend accelerating, decelerating, or reversing?
    enum Inflection: String {
        case accelerating   // Getting worse/better faster
        case decelerating   // Rate of change is slowing down
        case reversing      // Direction is flipping (decline → recovery or vice versa)
        case steady         // No significant change in rate
    }

    enum RateOfChange: String, Comparable {
        case negligible, gradual, moderate, rapid

        static func < (lhs: RateOfChange, rhs: RateOfChange) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }

        var sortOrder: Int {
            switch self {
            case .negligible: return 0
            case .gradual: return 1
            case .moderate: return 2
            case .rapid: return 3
            }
        }

        var displayLabel: String {
            switch self {
            case .negligible: return "stable"
            case .gradual: return "gradually"
            case .moderate: return "noticeably"
            case .rapid: return "rapidly"
            }
        }
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
            return TrendResult(direction: .stable, slope: 0, weekOverWeekChange: 0, movingAverage7d: 0, movingAverage30d: 0, movingAverage90d: 0, movingAverage180d: 0, movingAverage365d: 0, inflection: .steady)
        }

        // Linear regression on the period's data (use last 1/3 of period for slope)
        let regressionDays = max((days ?? 30) / 3, 7)
        let regressionSamples = series.samples(lastDays: regressionDays).map(\.value)
        let slope = regressionSamples.linearRegression.slope

        // Moving averages (always from full dataset for comparison)
        let ma7 = series.mean(lastDays: 7)
        let ma30 = series.mean(lastDays: 30)
        let ma90 = series.mean(lastDays: 90)
        let ma180 = series.mean(lastDays: 180)
        let ma365 = series.mean(lastDays: 365)

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

        // Inflection detection: compare recent slope vs older slope
        let inflection = detectInflection(series: series, currentSlope: slope, higherIsBetter: higherIsBetter)

        return TrendResult(
            direction: direction,
            slope: slope,
            weekOverWeekChange: periodChange,
            movingAverage7d: ma7,
            movingAverage30d: ma30,
            movingAverage90d: ma90,
            movingAverage180d: ma180,
            movingAverage365d: ma365,
            inflection: inflection
        )
    }

    /// Detect inflection by comparing recent 7-day slope to previous 7-14 day slope
    private static func detectInflection(series: MetricTimeSeries, currentSlope: Double, higherIsBetter: Bool) -> Inflection {
        let recentSamples = series.samples(lastDays: 7).map(\.value)
        let olderSamples = series.sortedSamples.filter { sample in
            let daysAgo = Calendar.current.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
            return daysAgo >= 7 && daysAgo < 14
        }.map(\.value)

        guard recentSamples.count >= 3, olderSamples.count >= 3 else { return .steady }

        let recentSlope = recentSamples.linearRegression.slope
        let olderSlope = olderSamples.linearRegression.slope

        // Normalize: positive slope = "good direction" for the metric
        let effectiveRecent = higherIsBetter ? recentSlope : -recentSlope
        let effectiveOlder = higherIsBetter ? olderSlope : -olderSlope

        // Reversal: slopes in opposite directions with sufficient magnitude
        if effectiveRecent > 0.01 && effectiveOlder < -0.01 { return .reversing }
        if effectiveRecent < -0.01 && effectiveOlder > 0.01 { return .reversing }

        // Acceleration: same direction but getting steeper
        if abs(effectiveRecent) > abs(effectiveOlder) * 1.5 && abs(effectiveRecent) > 0.01 {
            return .accelerating
        }

        // Deceleration: same direction but flattening out
        if abs(effectiveRecent) < abs(effectiveOlder) * 0.5 && abs(effectiveOlder) > 0.01 {
            return .decelerating
        }

        return .steady
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
