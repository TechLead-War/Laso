import Foundation

/// Analyzes trends in metric time series data using statistical methods
struct TrendAnalyzer {
    /// Canonical period used by Home "Your Trends" and default metric detail.
    static let homeTrendDays = 30

    // MARK: - Rate-of-change WoW % thresholds (named so reviewers can audit them)
    /// Above this WoW % change, the trend is classified as `.rapid`.
    static let rapidWoWPercent: Double = 15
    /// Above this WoW % change (and below `rapidWoWPercent`), the trend is `.moderate`.
    static let moderateWoWPercent: Double = 8
    /// Above this WoW % change (and below `moderateWoWPercent`), the trend is `.gradual`.
    static let gradualWoWPercent: Double = 2
    /// % difference between 30d and 365d moving averages above which the long-term trend tips improving/declining.
    static let longTermTrendPercent: Double = 3

    /// Bound applied to every period-over-period % change this analyzer reports.
    ///
    /// Metrics whose usual value sits near zero (walking asymmetry, double-support %,
    /// mindful minutes) make percent-of-mean explode for a tiny real change, and an
    /// unbounded result once surfaced "24606% off your usual" to a user. Same bound
    /// UserBaseline.deviationPercent already applies for the same reason, so both
    /// producers saturate at the same value and callers can detect it with one check.
    static let maxPercentChange: Double = 500

    // MARK: - Inflection slope thresholds (named so reviewers can audit them)

    /// Absolute slope (units per day) below which the recent/older slope is treated as effectively flat.
    static let inflectionSlopeEpsilon: Double = 0.01
    /// Multiplier on the older slope above which the recent slope counts as "accelerating".
    static let acceleratingSlopeRatio: Double = 1.5
    /// Multiplier on the older slope below which the recent slope counts as "decelerating".
    static let deceleratingSlopeRatio: Double = 0.5
    /// % WoW agreement threshold required (alongside slope) before classifying a clear improving/declining direction.
    static let directionWoWConfirmPercent: Double = 2

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
            if absWoW > TrendAnalyzer.rapidWoWPercent { return .rapid }
            if absWoW > TrendAnalyzer.moderateWoWPercent { return .moderate }
            if absWoW > TrendAnalyzer.gradualWoWPercent { return .gradual }
            return .negligible
        }

        /// Whether the current value is above or below the long-term (1-year) average
        var longTermTrend: TrendDirection {
            guard movingAverage365d > 0 else { return .stable }
            let diff = (movingAverage30d - movingAverage365d) / movingAverage365d * 100
            if diff > TrendAnalyzer.longTermTrendPercent { return .improving }
            if diff < -TrendAnalyzer.longTermTrendPercent { return .declining }
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

    /// Canonical trend resolver used by UI surfaces that must stay consistent.
    /// Uses cached analysis-engine trends for the home default period to avoid value drift.
    static func canonicalTrend(
        metric: HealthMetric,
        series: MetricTimeSeries?,
        analysisEngine: AnalysisEngine?,
        days: Int
    ) -> TrendResult? {
        guard let series, series.samples.count >= 3 else { return nil }
        if days == homeTrendDays, let cachedTrend = analysisEngine?.trend(for: metric) {
            return cachedTrend
        }
        return analyze(series: series, higherIsBetter: metric.higherIsBetter, days: days)
    }

    static func formattedPercentChange(_ change: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change))%"
    }

    /// Analyze trend for a metric's time series within a specific time range.
    ///
    /// Computes all moving averages, regression slope, period-over-period change,
    /// and inflection in a single reverse pass through the sorted samples, avoiding
    /// repeated O(n) scans for each statistic.
    static func analyze(series: MetricTimeSeries, higherIsBetter: Bool, days: Int?) -> TrendResult {
        let allSamples = series.sortedSamples  // already sorted chronologically
        guard !allSamples.isEmpty else {
            return TrendResult(direction: .stable, slope: 0, weekOverWeekChange: 0, movingAverage7d: 0, movingAverage30d: 0, movingAverage90d: 0, movingAverage180d: 0, movingAverage365d: 0, inflection: .steady)
        }

        let calendar = Date.cal
        // Anchor at start-of-day so cutoffs are stable across refreshes within
        // the same calendar day. Using raw Date() makes every window slide by
        // seconds, which causes 7D/30D/90D values to flicker between opens.
        let now = calendar.startOfDay(for: Date())

        // Pre-compute all day-boundary cutoffs once
        let periodDays = days ?? 30
        let halfPeriod = periodDays / 2
        let regressionDays = max(periodDays / 3, 7)

        let cutoff7   = calendar.date(byAdding: .day, value: -7,   to: now) ?? now
        let cutoff14  = calendar.date(byAdding: .day, value: -14,  to: now) ?? now
        let cutoff30  = calendar.date(byAdding: .day, value: -30,  to: now) ?? now
        let cutoff90  = calendar.date(byAdding: .day, value: -90,  to: now) ?? now
        let cutoff180 = calendar.date(byAdding: .day, value: -180, to: now) ?? now
        let cutoff365 = calendar.date(byAdding: .day, value: -365, to: now) ?? now

        let cutoffHalfPeriod = calendar.date(byAdding: .day, value: -halfPeriod,  to: now) ?? now
        let cutoffFullPeriod = calendar.date(byAdding: .day, value: -periodDays,  to: now) ?? now
        let cutoffRegression = calendar.date(byAdding: .day, value: -regressionDays, to: now) ?? now

        // Accumulators for moving averages
        var sum7   = 0.0, count7   = 0
        var sum30  = 0.0, count30  = 0
        var sum90  = 0.0, count90  = 0
        var sum180 = 0.0, count180 = 0
        var sum365 = 0.0, count365 = 0

        // Accumulators for period halves
        var sumRecentHalf = 0.0, countRecentHalf = 0
        var sumOlderHalf  = 0.0, countOlderHalf  = 0

        // Collect regression and inflection values (reversed, will flip for regression)
        var regressionValues: [Double] = []
        var recent7Values: [Double] = []   // last 7 days (for inflection)
        var older7to14Values: [Double] = [] // 7-14 days ago (for inflection)

        var hasPeriodSample = false

        // Hoist per-iteration period check outside the loop
        let cutoffPeriod: Date? = days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }

        // Single reverse pass: walk from newest to oldest, stop at 365-day boundary
        for i in stride(from: allSamples.count - 1, through: 0, by: -1) {
            let sample = allSamples[i]
            let date = sample.date
            let value = sample.value

            // Stop early if we're past the widest window we need
            if date < cutoff365 { break }

            // Moving averages — each bucket includes all narrower ones
            sum365 += value; count365 += 1
            if date >= cutoff180 { sum180 += value; count180 += 1 }
            if date >= cutoff90  { sum90  += value; count90  += 1 }
            if date >= cutoff30  { sum30  += value; count30  += 1 }
            if date >= cutoff7   { sum7   += value; count7   += 1 }

            // Period half buckets (recentHalf = last halfPeriod days, olderHalf = halfPeriod..fullPeriod days ago)
            if date >= cutoffHalfPeriod {
                sumRecentHalf += value; countRecentHalf += 1
            } else if date >= cutoffFullPeriod {
                sumOlderHalf += value; countOlderHalf += 1
            }

            // Regression values (last regressionDays)
            if date >= cutoffRegression {
                regressionValues.append(value)
            }

            // Inflection buckets
            if date >= cutoff7 {
                recent7Values.append(value)
            } else if date >= cutoff14 {
                older7to14Values.append(value)
            }

            // Check if any sample falls within the requested period
            if let cp = cutoffPeriod {
                if date >= cp { hasPeriodSample = true }
            } else {
                hasPeriodSample = true
            }
        }

        guard hasPeriodSample else {
            return TrendResult(direction: .stable, slope: 0, weekOverWeekChange: 0, movingAverage7d: 0, movingAverage30d: 0, movingAverage90d: 0, movingAverage180d: 0, movingAverage365d: 0, inflection: .steady)
        }

        // Compute moving averages
        let ma7   = count7   > 0 ? sum7   / Double(count7)   : 0
        let ma30  = count30  > 0 ? sum30  / Double(count30)  : 0
        let ma90  = count90  > 0 ? sum90  / Double(count90)  : 0
        let ma180 = count180 > 0 ? sum180 / Double(count180) : 0
        let ma365 = count365 > 0 ? sum365 / Double(count365) : 0

        // Compute regression slope (values were collected newest-first, reverse for chronological order)
        regressionValues.reverse()
        let slope = regressionValues.linearRegression.slope

        // Period-over-period change
        let periodChange: Double
        if countOlderHalf > 0 {
            let olderMean = sumOlderHalf / Double(countOlderHalf)
            if olderMean != 0 {
                let recentMean = countRecentHalf > 0 ? sumRecentHalf / Double(countRecentHalf) : 0
                let raw = ((recentMean - olderMean) / olderMean) * 100
                periodChange = max(-maxPercentChange, min(maxPercentChange, raw))
            } else {
                periodChange = 0
            }
        } else {
            periodChange = 0
        }

        let direction = classifyDirection(
            slope: slope,
            weekOverWeekChange: periodChange,
            higherIsBetter: higherIsBetter
        )

        // Inflection detection (inline, using already-collected buckets)
        let inflection: Inflection
        // Values were collected newest-first; reverse for chronological regression
        recent7Values.reverse()
        older7to14Values.reverse()
        if recent7Values.count >= 3, older7to14Values.count >= 3 {
            let recentSlope = slope  // regression is already on recent data
            let olderSlope = older7to14Values.linearRegression.slope

            let effectiveRecent = higherIsBetter ? recentSlope : -recentSlope
            let effectiveOlder = higherIsBetter ? olderSlope : -olderSlope

            let eps = TrendAnalyzer.inflectionSlopeEpsilon
            if effectiveRecent > eps && effectiveOlder < -eps {
                inflection = .reversing
            } else if effectiveRecent < -eps && effectiveOlder > eps {
                inflection = .reversing
            } else if abs(effectiveRecent) > abs(effectiveOlder) * TrendAnalyzer.acceleratingSlopeRatio && abs(effectiveRecent) > eps {
                inflection = .accelerating
            } else if abs(effectiveRecent) < abs(effectiveOlder) * TrendAnalyzer.deceleratingSlopeRatio && abs(effectiveOlder) > eps {
                inflection = .decelerating
            } else {
                inflection = .steady
            }
        } else {
            inflection = .steady
        }

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

    private static func classifyDirection(slope: Double, weekOverWeekChange: Double, higherIsBetter: Bool) -> TrendDirection {
        let threshold = RulesConfiguration.trendSlopeThreshold

        // Normalize slope direction based on whether higher is better
        let effectiveSlope = higherIsBetter ? slope : -slope
        let effectiveWoW = higherIsBetter ? weekOverWeekChange : -weekOverWeekChange

        // Both slope and week-over-week should agree for a clear trend
        if effectiveSlope > threshold && effectiveWoW > directionWoWConfirmPercent {
            return .improving
        } else if effectiveSlope < -threshold && effectiveWoW < -directionWoWConfirmPercent {
            return .declining
        } else {
            return .stable
        }
    }
}
