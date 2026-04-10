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

        var bestInsight: Insight?
        var bestDeviation: Double = 0

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

            if abs(percentDiff) > abs(bestDeviation) {
                bestDeviation = percentDiff
                bestInsight = Insight(
                    metric: .sleepDuration,
                    title: Copy.Analysis.Sleep.sleepDrives(performanceMetric.displayName),
                    summary: "Good sleep (7+ hrs) boosts your next-day \(performanceMetric.displayName.lowercased()) by \(String(format: "%.0f", abs(percentDiff)))%. averaging \(String(format: "%.0f", avgGood)) \(performanceMetric.unit) vs \(String(format: "%.0f", avgPoor)) on shorter nights.",
                    recommendation: "Your data shows a \(String(format: "%.0f", abs(percentDiff)))% difference in next-day \(performanceMetric.displayName.lowercased()) between 7+ hr sleep nights (\(String(format: "%.0f", avgGood)) \(performanceMetric.unit)) and <6 hr nights (\(String(format: "%.0f", avgPoor)) \(performanceMetric.unit)) across \(goodSleep.count + poorSleep.count) measured nights.",
                    severity: abs(percentDiff) >= 25 ? .warning : .info,
                    trend: .stable,
                    currentValue: avgGood,
                    baselineValue: avgPoor,
                    deviationPercent: percentDiff,
                    category: .sleepPerformance,
                    relatedMetrics: [.sleepDuration, performanceMetric]
                )
            }
        }
        return bestInsight
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
            title: Copy.Analysis.Sleep.sleepQualityToActivity,
            summary: "High-quality sleep nights (>30% deep+REM) lead to \(String(format: "%.0f", abs(diff)))% \(diff > 0 ? "more" : "fewer") active calories the next day.",
            recommendation: "Nights with >30% deep+REM correlate with \(String(format: "%.0f", abs(diff)))% \(diff > 0 ? "higher" : "lower") next-day active calories (\(String(format: "%.0f", avgHigh)) vs \(String(format: "%.0f", avgLow)) kcal) across \(highQualityCals.count + lowQualityCals.count) measured nights.",
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
        let last30Samples = sleepSeries.samples(lastDays: 30)
        let last30 = last30Samples.map(\.value)
        guard last30.count >= 14 else { return nil }

        let stdDev = last30.standardDeviation
        let mean = last30.mean

        guard mean > 0 else { return nil }

        let cv = stdDev / mean  // coefficient of variation

        // Weekday vs weekend split
        let calendar = Calendar.current
        let weekdaySamples = last30Samples.filter { sample in
            let weekday = calendar.component(.weekday, from: sample.date)
            return weekday >= 2 && weekday <= 6 // Mon-Fri
        }.map(\.value)
        let weekendSamples = last30Samples.filter { sample in
            let weekday = calendar.component(.weekday, from: sample.date)
            return weekday == 1 || weekday == 7 // Sun, Sat
        }.map(\.value)

        let weekdayAvg = weekdaySamples.isEmpty ? 0 : weekdaySamples.mean
        let weekendAvg = weekendSamples.isEmpty ? 0 : weekendSamples.mean
        let hasWeekdayWeekendData = !weekdaySamples.isEmpty && !weekendSamples.isEmpty

        // Find worst nights
        let sortedByValue = last30Samples.sorted { $0.value < $1.value }
        let worstNights = sortedByValue.prefix(3)
        let worstDays = worstNights.compactMap { sample -> String? in
            let weekday = calendar.component(.weekday, from: sample.date)
            return calendar.shortWeekdaySymbols[weekday - 1]
        }

        let isConsistent = cv < 0.15
        let severity: Severity = cv > 0.25 ? .warning : .info

        var summaryParts: [String] = []
        if isConsistent {
            summaryParts.append("Your sleep schedule is consistent (\u{00B1}\(String(format: "%.0f", stdDev * 60)) min variation)")
        } else {
            summaryParts.append("Your sleep varies by \u{00B1}\(String(format: "%.1f", stdDev)) hours night to night")
        }
        if hasWeekdayWeekendData {
            summaryParts.append("Weekday avg: \(String(format: "%.1f", weekdayAvg)) hrs, weekend avg: \(String(format: "%.1f", weekendAvg)) hrs")
        }
        if !worstDays.isEmpty && !isConsistent {
            summaryParts.append("Worst nights tend to fall on \(worstDays.joined(separator: ", "))")
        }

        let gapNote: String
        if hasWeekdayWeekendData && abs(weekdayAvg - weekendAvg) > 0.5 {
            let shorter = weekdayAvg < weekendAvg ? "weekday" : "weekend"
            gapNote = " Your \(shorter) sleep is \(String(format: "%.1f", abs(weekdayAvg - weekendAvg))) hrs shorter than your \(weekdayAvg < weekendAvg ? "weekend" : "weekday") average."
        } else {
            gapNote = ""
        }

        return Insight(
            metric: .sleepDuration,
            title: Copy.Analysis.Sleep.sleepConsistency,
            summary: summaryParts.joined(separator: ". ") + ".",
            recommendation: isConsistent ?
                "Sleep variation is \u{00B1}\(String(format: "%.0f", stdDev * 60)) min around your \(String(format: "%.1f", mean)) hr average (CV: \(String(format: "%.0f", cv * 100))%).\(gapNote)" :
                "Sleep varies by \u{00B1}\(String(format: "%.1f", stdDev)) hrs night to night (CV: \(String(format: "%.0f", cv * 100))%). Weekday avg: \(String(format: "%.1f", weekdayAvg)) hrs, weekend avg: \(String(format: "%.1f", weekendAvg)) hrs.\(gapNote)",
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

// MARK: - InsightAnalyzer Conformance

extension SleepPerformanceAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "sleepPerformance" }
    static var insightCategory: InsightCategory { .sleepPerformance }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(timeSeries: context.timeSeries)
    }
}
