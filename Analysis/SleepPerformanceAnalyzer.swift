import Foundation

/// Analyzes how sleep duration and quality affect next-day activity performance
struct SleepPerformanceAnalyzer {

    /// Analyze sleep-performance links and generate insights
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        guard let sleepSeries = timeSeries[.sleepDuration] else { return [] }

        // --- Duration Impact ---
        if let durationInsight = analyzeDurationImpact(sleepSeries: sleepSeries, timeSeries: timeSeries) {
            insights.append(durationInsight)
        }

        // --- Sleep Quality Impact ---
        if let qualityInsight = analyzeQualityImpact(timeSeries: timeSeries) {
            insights.append(qualityInsight)
        }

        // --- Bedtime Consistency ---
        if let consistencyInsight = analyzeConsistency(sleepSeries: sleepSeries, timeSeries: timeSeries) {
            insights.append(consistencyInsight)
        }

        return insights
    }

    // MARK: - Duration Impact

    private static func analyzeDurationImpact(
        sleepSeries: MetricTimeSeries,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Insight? {
        // Compare next-day activity on good sleep (>=7hr) vs poor sleep (<6hr)
        let performanceMetrics: [HealthMetric] = [.activeCalories, .steps, .exerciseMinutes]

        for performanceMetric in performanceMetrics {
            guard let perfSeries = timeSeries[performanceMetric] else { continue }

            let aligned = TimeSeriesAligner.alignWithOffset(sleepSeries, perfSeries, dayOffset: 1)
            guard aligned.count >= 14 else { continue }

            let goodSleep = aligned.filter { $0.valueA >= 7.0 }
            let poorSleep = aligned.filter { $0.valueA < 6.0 }

            guard goodSleep.count >= 5, poorSleep.count >= 3 else { continue }

            let avgGood = goodSleep.map(\.valueB).mean
            let avgPoor = poorSleep.map(\.valueB).mean

            guard avgPoor > 0 else { continue }

            let percentDiff = ((avgGood - avgPoor) / avgPoor) * 100

            guard abs(percentDiff) >= 10 else { continue }

            return Insight(
                metric: .sleepDuration,
                title: "Sleep Drives \(performanceMetric.displayName)",
                summary: "On 7+ hour sleep nights, your next-day \(performanceMetric.displayName.lowercased()) is \(String(format: "%.0f", abs(percentDiff)))% \(percentDiff > 0 ? "higher" : "lower") (\(String(format: "%.0f", avgGood)) vs \(String(format: "%.0f", avgPoor)) \(performanceMetric.unit)).",
                recommendation: "Prioritize 7+ hours of sleep to maximize your \(performanceMetric.displayName.lowercased()). Even one good night makes a measurable difference.",
                severity: abs(percentDiff) >= 25 ? .warning : .info,
                trend: .stable,
                currentValue: avgGood,
                baselineValue: avgPoor,
                deviationPercent: percentDiff,
                category: .sleepPerformance,
                relatedMetrics: [.sleepDuration, performanceMetric]
            )
        }
        return nil
    }

    // MARK: - Quality Impact

    private static func analyzeQualityImpact(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        guard let deepSeries = timeSeries[.sleepDeep],
              let remSeries = timeSeries[.sleepREM],
              let totalSeries = timeSeries[.sleepDuration] else { return nil }

        // Compute sleep quality ratio: (deep + REM) / total
        let deepMap = TimeSeriesAligner.dailyValueMap(deepSeries)
        let remMap = TimeSeriesAligner.dailyValueMap(remSeries)
        let totalMap = TimeSeriesAligner.dailyValueMap(totalSeries)

        var highQualityDays: [Date] = []
        var lowQualityDays: [Date] = []

        for (date, total) in totalMap {
            guard total > 0,
                  let deep = deepMap[date],
                  let rem = remMap[date] else { continue }
            let qualityRatio = (deep + rem) / total
            if qualityRatio > 0.30 {
                highQualityDays.append(date)
            } else if qualityRatio < 0.25 {
                lowQualityDays.append(date)
            }
        }

        guard highQualityDays.count >= 5, lowQualityDays.count >= 3 else { return nil }

        // Compare next-day active calories
        guard let calSeries = timeSeries[.activeCalories] else { return nil }
        let calMap = TimeSeriesAligner.dailyValueMap(calSeries)

        let highQualityCals = highQualityDays.compactMap { day -> Double? in
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)?.startOfDay ?? day
            return calMap[nextDay]
        }
        let lowQualityCals = lowQualityDays.compactMap { day -> Double? in
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)?.startOfDay ?? day
            return calMap[nextDay]
        }

        guard highQualityCals.count >= 3, lowQualityCals.count >= 3 else { return nil }

        let avgHigh = highQualityCals.mean
        let avgLow = lowQualityCals.mean
        guard avgLow > 0 else { return nil }

        let diff = ((avgHigh - avgLow) / avgLow) * 100
        guard abs(diff) >= 8 else { return nil }

        return Insight(
            metric: .sleepDeep,
            title: "Sleep Quality → Activity",
            summary: "High-quality sleep nights (>30% deep+REM) lead to \(String(format: "%.0f", abs(diff)))% \(diff > 0 ? "more" : "fewer") active calories the next day.",
            recommendation: "Boost deep sleep with a cool bedroom (65-68°F), no alcohol 3hrs before bed, and consistent bedtime.",
            severity: .info,
            trend: .stable,
            currentValue: avgHigh,
            baselineValue: avgLow,
            deviationPercent: diff,
            category: .sleepPerformance,
            relatedMetrics: [.sleepDeep, .sleepREM, .activeCalories]
        )
    }

    // MARK: - Consistency

    private static func analyzeConsistency(
        sleepSeries: MetricTimeSeries,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Insight? {
        let last30 = sleepSeries.samples(lastDays: 30).map(\.value)
        guard last30.count >= 14 else { return nil }

        let stdDev = last30.standardDeviation
        let mean = last30.mean

        guard mean > 0 else { return nil }

        let cv = stdDev / mean  // coefficient of variation

        let isConsistent = cv < 0.15
        let severity: Severity = cv > 0.25 ? .warning : .info

        return Insight(
            metric: .sleepDuration,
            title: "Sleep Consistency",
            summary: isConsistent ?
                "Your sleep schedule is consistent (±\(String(format: "%.1f", stdDev * 60)) min variation). Consistent sleepers get more deep sleep." :
                "Your sleep varies by ±\(String(format: "%.1f", stdDev)) hours night to night. Irregular sleep reduces deep sleep quality.",
            recommendation: isConsistent ?
                "Keep it up! A consistent sleep schedule is one of the best things you can do for recovery." :
                "Try setting a fixed bedtime and wake time, even on weekends. Your body's circadian rhythm thrives on consistency.",
            severity: severity,
            trend: isConsistent ? .improving : .declining,
            currentValue: cv * 100,
            baselineValue: 15,
            deviationPercent: (cv - 0.15) / 0.15 * 100,
            category: .sleepPerformance,
            relatedMetrics: [.sleepDuration, .sleepDeep]
        )
    }
}
