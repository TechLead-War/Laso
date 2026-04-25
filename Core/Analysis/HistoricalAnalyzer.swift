import Foundation

/// Deep historical analysis that leverages up to 1 year of HealthKit data.
/// Produces per-metric context: YoY change, all-time percentile, seasonal norms,
/// long-term trajectory, and historical rarity. none of which exist in the
/// 90-day-capped baseline/trend pipeline.
struct HistoricalAnalyzer {

    /// Pass 12 BE perf: cached current calendar. Insight builders below call
    /// `Calendar.current.monthSymbols[...component(.month)...]` per metric in
    /// `analyzeAll(...)`, which fans out across every tracked metric.
    private static let cal: Calendar = Calendar.current

    /// Rich historical context for a single metric
    struct HistoricalContext {
        let metric: HealthMetric

        // Year-over-Year
        let yearOverYearChange: Double?        // % change vs same month last year
        let yearOverYearValue: Double?          // same month last year's average

        // All-Time Percentile
        let allTimePercentile: Double           // 0-100: where current value sits in all-time data
        let allTimeHigh: Double?
        let allTimeLow: Double?

        // Seasonal Norm
        let seasonalAverage: Double?            // average for this calendar month across all years
        let seasonalDeviation: Double?          // % above/below seasonal norm

        // Long-Term Trajectory
        let longTermSlope: Double?              // slope over up to 365 days (per day)
        let longTermChangePercent: Double?      // total % change over longest available period

        // Historical Rarity
        let daysSinceLastSimilar: Int?          // days since value was last at this level (±5%)
        let occurrencesInLastYear: Int?         // how many times current level occurred in past year
        let isAllTimeExtreme: Bool              // within 5% of all-time high or low

        // Data Depth
        let yearsOfData: Int
        let totalDataPoints: Int
    }

    // MARK: - Batch Analysis

    /// Analyze all metrics and produce historical context for each
    static func analyzeAll(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [HealthMetric: HistoricalContext] {
        var results: [HealthMetric: HistoricalContext] = [:]

        for (metric, series) in timeSeries {
            guard series.totalDataPoints >= 30 else { continue }
            let currentValue = series.samples(lastDays: 3).map(\.value).mean
            guard currentValue > 0 else { continue }

            let context = analyze(metric: metric, series: series, currentValue: currentValue)
            results[metric] = context
        }

        return results
    }

    // MARK: - Single Metric Analysis

    static func analyze(
        metric: HealthMetric,
        series: MetricTimeSeries,
        currentValue: Double
    ) -> HistoricalContext {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // ── Year-over-Year ──
        let lastYearSamples = series.samples(forMonth: currentMonth, year: currentYear - 1)
        let yearOverYearValue: Double? = lastYearSamples.isEmpty ? nil : lastYearSamples.map(\.value).mean
        let yearOverYearChange: Double? = yearOverYearValue.flatMap { lastYear in
            guard lastYear > 0 else { return nil }
            return ((currentValue - lastYear) / lastYear) * 100
        }

        // ── All-Time Percentile ──
        let allTimePercentile = series.percentile(of: currentValue)
        let allValues = series.values
        let allTimeHigh = allValues.max()
        let allTimeLow = allValues.min()

        // ── Seasonal Norm ──
        let seasonalSamples = series.samples(forMonth: currentMonth)
        let seasonalAverage: Double? = seasonalSamples.count >= 7 ? seasonalSamples.map(\.value).mean : nil
        let seasonalDeviation: Double? = seasonalAverage.flatMap { avg in
            guard avg > 0 else { return nil }
            return ((currentValue - avg) / avg) * 100
        }

        // ── Long-Term Trajectory (up to 365 days) ──
        let longTermSamples = series.sortedSamples
        var longTermSlope: Double? = nil
        var longTermChangePercent: Double? = nil

        if longTermSamples.count >= 90 {
            let longSamples = series.samples(lastDays: 365)
            if longSamples.count >= 60 {
                let values = longSamples.map(\.value)
                let slope = values.linearRegression.slope
                longTermSlope = slope

                // Median of the earliest samples as a robust baseline. A single
                // first-day value is often a partial-sync artifact that blows up the ratio.
                let earlySamples = Array(longSamples.prefix(14)).map(\.value)
                if earlySamples.count >= 7 {
                    let earlyBaseline = earlySamples.median
                    if earlyBaseline > 0 {
                        let change = ((currentValue - earlyBaseline) / earlyBaseline) * 100
                        // Clamp absurd swings; beyond this is almost always a data artifact,
                        // not real biological drift.
                        if abs(change) <= 200 {
                            longTermChangePercent = change
                        }
                    }
                }
            }
        }

        // ── Historical Rarity ──
        let tolerance = currentValue * 0.05  // within 5%
        let lowerBound = currentValue - tolerance
        let upperBound = currentValue + tolerance

        // Days since last similar value (looking beyond last 7 days)
        let olderSamples = longTermSamples.filter {
            let daysAgo = calendar.dateComponents([.day], from: $0.date, to: now).day ?? 0
            return daysAgo > 7
        }
        let lastSimilar = olderSamples.last { $0.value >= lowerBound && $0.value <= upperBound }
        let daysSinceLastSimilar: Int? = lastSimilar.flatMap {
            calendar.dateComponents([.day], from: $0.date, to: now).day
        }

        // Occurrences in last year
        let yearSamples = series.samples(lastDays: 365)
        let occurrencesInLastYear = yearSamples.filter {
            $0.value >= lowerBound && $0.value <= upperBound
        }.count

        // All-time extreme check
        let isExtreme: Bool
        if let high = allTimeHigh, let low = allTimeLow, high > low {
            let range = high - low
            isExtreme = currentValue >= (high - range * 0.05) || currentValue <= (low + range * 0.05)
        } else {
            isExtreme = false
        }

        return HistoricalContext(
            metric: metric,
            yearOverYearChange: yearOverYearChange,
            yearOverYearValue: yearOverYearValue,
            allTimePercentile: allTimePercentile,
            allTimeHigh: allTimeHigh,
            allTimeLow: allTimeLow,
            seasonalAverage: seasonalAverage,
            seasonalDeviation: seasonalDeviation,
            longTermSlope: longTermSlope,
            longTermChangePercent: longTermChangePercent,
            daysSinceLastSimilar: daysSinceLastSimilar,
            occurrencesInLastYear: occurrencesInLastYear,
            isAllTimeExtreme: isExtreme,
            yearsOfData: series.yearsOfData,
            totalDataPoints: series.totalDataPoints
        )
    }

    // MARK: - Insight Generation

    /// Generate deep historical insights that no 90-day analysis can produce
    static func generateInsights(
        historicalContext: [HealthMetric: HistoricalContext],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Insight] {
        var insights: [Insight] = []

        for (metric, ctx) in historicalContext {
            guard ctx.yearsOfData >= 1, ctx.totalDataPoints >= 90 else { continue }

            // 1. Year-over-Year insights (most impactful)
            if let yoyInsight = yearOverYearInsight(metric: metric, ctx: ctx) {
                insights.append(yoyInsight)
            }

            // 2. All-time extreme insights
            if let extremeInsight = allTimeExtremeInsight(metric: metric, ctx: ctx) {
                insights.append(extremeInsight)
            }

            // 3. Seasonal deviation insights
            if let seasonalInsight = seasonalInsight(metric: metric, ctx: ctx) {
                insights.append(seasonalInsight)
            }

            // 4. Long-term trajectory insights
            if let trajectoryInsight = longTermTrajectoryInsight(metric: metric, ctx: ctx) {
                insights.append(trajectoryInsight)
            }

            // 5. Historical rarity insights
            if let rarityInsight = rarityInsight(metric: metric, ctx: ctx) {
                insights.append(rarityInsight)
            }
        }

        return insights
    }

    // MARK: - Individual Insight Types

    private static func yearOverYearInsight(metric: HealthMetric, ctx: HistoricalContext) -> Insight? {
        guard let yoyChange = ctx.yearOverYearChange, abs(yoyChange) > 5,
              let lastYearValue = ctx.yearOverYearValue else { return nil }

        let improving = metric.higherIsBetter ? yoyChange > 0 : yoyChange < 0
        let absChange = String(format: "%.0f", abs(yoyChange))
        let lastYearFormatted = metric.formatValue(lastYearValue)

        let monthName = Self.cal.monthSymbols[Self.cal.component(.month, from: Date()) - 1]

        return Insight(
            metric: metric,
            title: Copy.Analysis.Historical.yearOverYear(metric: metric.displayName, change: absChange, comparison: improving ? "Better" : "Worse", month: monthName),
            summary: "Compared to \(monthName) last year (\(lastYearFormatted) \(metric.unit)), your \(metric.displayName.lowercased()) is \(absChange)% \(yoyChange > 0 ? "higher" : "lower").",
            recommendation: improving
                ? Copy.Analysis.Historical.betterShapeLongTerm
                : "Your \(metric.displayName.lowercased()) has declined since last year. Consider what changed in your routine over the past 12 months.",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: lastYearValue * (1 + yoyChange / 100),
            baselineValue: lastYearValue,
            deviationPercent: yoyChange,
            category: .baselineDrift
        )
    }

    private static func allTimeExtremeInsight(metric: HealthMetric, ctx: HistoricalContext) -> Insight? {
        guard ctx.isAllTimeExtreme, ctx.totalDataPoints >= 180 else { return nil }
        guard let high = ctx.allTimeHigh, let low = ctx.allTimeLow else { return nil }

        let isNearHigh = ctx.allTimePercentile >= 95
        let isNearLow = ctx.allTimePercentile <= 5

        guard isNearHigh || isNearLow else { return nil }

        let goodExtreme: Bool
        if isNearHigh {
            goodExtreme = metric.higherIsBetter
        } else {
            goodExtreme = !metric.higherIsBetter
        }

        return Insight(
            metric: metric,
            title: Copy.Analysis.Historical.nearAllTime(metric: metric.displayName, extreme: isNearHigh ? "High" : "Low"),
            summary: "Your \(metric.displayName.lowercased()) is in the \(isNearHigh ? "top" : "bottom") 5% of all values recorded over the past year (\(ctx.totalDataPoints) data points).",
            recommendation: goodExtreme
                ? Copy.Analysis.Historical.exceptionalPersonalBest
                : Copy.Analysis.Historical.rareLevelMayWarrantAttention,
            severity: goodExtreme ? .info : .warning,
            trend: goodExtreme ? .improving : .declining,
            currentValue: isNearHigh ? high : low,
            baselineValue: (high + low) / 2,
            deviationPercent: ctx.allTimePercentile - 50,
            category: .baselineDrift
        )
    }

    private static func seasonalInsight(metric: HealthMetric, ctx: HistoricalContext) -> Insight? {
        guard let seasonalDev = ctx.seasonalDeviation, abs(seasonalDev) > 10,
              let seasonalAvg = ctx.seasonalAverage,
              ctx.yearsOfData >= 1 else { return nil }

        let monthName = Self.cal.monthSymbols[Self.cal.component(.month, from: Date()) - 1]
        let absDev = String(format: "%.0f", abs(seasonalDev))
        let isAbove = seasonalDev > 0
        let improving = metric.higherIsBetter ? isAbove : !isAbove

        return Insight(
            metric: metric,
            title: Copy.Analysis.Historical.seasonalComparison(metric: metric.displayName, comparison: improving ? "Above" : "Below", month: monthName),
            summary: "Your \(metric.displayName.lowercased()) is \(absDev)% \(isAbove ? "above" : "below") your typical \(monthName) levels (historical average: \(metric.formatValue(seasonalAvg)) \(metric.unit) over the past year).",
            recommendation: improving
                ? Copy.Analysis.Historical.outperformingSeasonalNorm
                : "This is worse than your usual \(monthName) levels. While some seasonal variation is normal, a \(absDev)% deviation is significant.",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: seasonalAvg * (1 + seasonalDev / 100),
            baselineValue: seasonalAvg,
            deviationPercent: seasonalDev,
            category: .baselineDrift
        )
    }

    private static func longTermTrajectoryInsight(metric: HealthMetric, ctx: HistoricalContext) -> Insight? {
        guard let changePercent = ctx.longTermChangePercent, abs(changePercent) > 10,
              ctx.yearsOfData >= 1, ctx.totalDataPoints >= 180 else { return nil }

        let improving = metric.higherIsBetter ? changePercent > 0 : changePercent < 0
        let absChange = String(format: "%.0f", abs(changePercent))
        let periodLabel = "the past year"
        // Direction word stays literal so the title and summary agree. The
        // improving flag drives severity, tone, and recommendation separately.
        let directionWord = changePercent > 0 ? "Up" : "Down"

        return Insight(
            metric: metric,
            title: Copy.Analysis.Historical.longTermTrajectory(metric: metric.displayName, direction: directionWord, change: absChange, period: periodLabel.capitalized),
            summary: "Looking at \(ctx.totalDataPoints) data points over \(periodLabel), your \(metric.displayName.lowercased()) has \(changePercent > 0 ? "increased" : "decreased") \(absChange)% overall.",
            recommendation: improving
                ? Copy.Analysis.Historical.longTermImprovementReliable
                : Copy.Analysis.Historical.sustainedDeclineStructural,
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: ctx.longTermChangePercent ?? 0,
            baselineValue: 0,
            deviationPercent: changePercent,
            category: .baselineDrift
        )
    }

    private static func rarityInsight(metric: HealthMetric, ctx: HistoricalContext) -> Insight? {
        guard let daysSince = ctx.daysSinceLastSimilar, daysSince > 90,
              ctx.totalDataPoints >= 180 else { return nil }

        let monthsAgo = daysSince / 30

        return Insight(
            metric: metric,
            title: Copy.Analysis.Historical.rarityTitle(metric: metric.displayName, months: monthsAgo, extreme: ctx.allTimePercentile > 50 ? "High" : "Low"),
            summary: "Your current \(metric.displayName.lowercased()) level hasn't been seen in \(monthsAgo) months. It occurred only \(ctx.occurrencesInLastYear ?? 0) times in the past year.",
            recommendation: Copy.Analysis.Historical.unusualValuesMonitor,
            severity: .info,
            trend: .stable,
            currentValue: Double(daysSince),
            baselineValue: 0,
            deviationPercent: 0,
            category: .baselineDrift
        )
    }
}

// MARK: - InsightAnalyzer Conformance

extension HistoricalAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "historical" }
    static var insightCategory: InsightCategory { .trend }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(historicalContext: context.historicalContext, baselines: context.baselines)
    }
}
