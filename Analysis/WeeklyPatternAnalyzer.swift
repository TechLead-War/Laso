import Foundation

/// Identifies day-of-week patterns, best/worst days, and weekday vs weekend gaps
struct WeeklyPatternAnalyzer {

    private static let keyMetrics: [HealthMetric] = [
        .steps, .activeCalories, .exerciseMinutes, .sleepDuration, .restingHeartRate, .heartRateVariability
    ]

    /// Analyze weekly patterns and generate insights
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        // --- Weakest Day Insight ---
        if let weakestDayInsight = findWeakestDay(timeSeries: timeSeries) {
            insights.append(weakestDayInsight)
        }

        // --- Weekend vs Weekday Gap ---
        if let gapInsight = analyzeWeekendGap(timeSeries: timeSeries) {
            insights.append(gapInsight)
        }

        // --- Consistency Score ---
        if let consistencyInsight = analyzeWeeklyConsistency(timeSeries: timeSeries) {
            insights.append(consistencyInsight)
        }

        return insights
    }

    // MARK: - Weakest Day

    private static func findWeakestDay(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Focus on steps — most universally tracked activity metric
        guard let stepSeries = timeSeries[.steps] else { return nil }

        let groups = TimeSeriesAligner.groupByDayOfWeek(stepSeries)

        var dayAverages: [(day: Int, avg: Double)] = []
        for (day, values) in groups {
            guard values.count >= 2 else { continue }
            dayAverages.append((day: day, avg: values.mean))
        }

        guard dayAverages.count >= 5 else { return nil }

        dayAverages.sort { $0.avg < $1.avg }
        let overallAvg = dayAverages.map(\.avg).mean

        guard let weakest = dayAverages.first,
              let strongest = dayAverages.last,
              overallAvg > 0 else { return nil }

        let weakestName = dayName(for: weakest.day)
        let strongestName = dayName(for: strongest.day)
        let deficit = ((overallAvg - weakest.avg) / overallAvg) * 100

        guard deficit >= 10 else { return nil }

        return Insight(
            metric: .steps,
            title: "Weakest Day: \(weakestName)",
            summary: "\(weakestName) is your least active day with \(String(format: "%.0f", weakest.avg)) avg steps — \(String(format: "%.0f", deficit))% below your daily average. \(strongestName) is your strongest (\(String(format: "%.0f", strongest.avg)) steps).",
            recommendation: "Schedule a walk or light activity on \(weakestName)s to close the gap. Even 15 minutes can make a difference.",
            severity: deficit >= 25 ? .warning : .info,
            trend: .stable,
            currentValue: weakest.avg,
            baselineValue: overallAvg,
            deviationPercent: -deficit,
            category: .weeklyPattern,
            relatedMetrics: [.steps]
        )
    }

    // MARK: - Weekend Gap

    private static func analyzeWeekendGap(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        guard let stepSeries = timeSeries[.steps] else { return nil }

        let groups = TimeSeriesAligner.groupByDayOfWeek(stepSeries)

        // Weekday: Mon(2) - Fri(6), Weekend: Sat(7), Sun(1)
        let weekdayValues = [2, 3, 4, 5, 6].flatMap { groups[$0] ?? [] }
        let weekendValues = [1, 7].flatMap { groups[$0] ?? [] }

        guard weekdayValues.count >= 5, weekendValues.count >= 2 else { return nil }

        let weekdayAvg = weekdayValues.mean
        let weekendAvg = weekendValues.mean

        guard weekdayAvg > 0 else { return nil }

        let gap = ((weekdayAvg - weekendAvg) / weekdayAvg) * 100

        guard abs(gap) >= 10 else { return nil }

        let moreActive = gap > 0 ? "weekdays" : "weekends"

        return Insight(
            metric: .steps,
            title: "Weekday vs Weekend",
            summary: "You're \(String(format: "%.0f", abs(gap)))% more active on \(moreActive). Weekday avg: \(String(format: "%.0f", weekdayAvg)) steps, weekend avg: \(String(format: "%.0f", weekendAvg)) steps.",
            recommendation: gap > 20 ?
                "Try adding a weekend activity — a hike, bike ride, or long walk can close the gap." :
                "Your activity levels are fairly balanced across the week. Keep it up!",
            severity: abs(gap) >= 30 ? .warning : .info,
            trend: .stable,
            currentValue: weekendAvg,
            baselineValue: weekdayAvg,
            deviationPercent: -gap,
            category: .weeklyPattern,
            relatedMetrics: [.steps, .activeCalories]
        )
    }

    // MARK: - Weekly Consistency

    private static func analyzeWeeklyConsistency(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        guard let stepSeries = timeSeries[.steps] else { return nil }

        let groups = TimeSeriesAligner.groupByDayOfWeek(stepSeries)

        let dayAverages = (1...7).compactMap { day -> Double? in
            let values = groups[day] ?? []
            guard values.count >= 2 else { return nil }
            return values.mean
        }

        guard dayAverages.count >= 5 else { return nil }

        let mean = dayAverages.mean
        guard mean > 0 else { return nil }

        let cv = dayAverages.standardDeviation / mean * 100  // coefficient of variation as percentage

        let isConsistent = cv < 20

        return Insight(
            metric: .steps,
            title: "Weekly Activity Consistency",
            summary: isConsistent ?
                "Your daily step counts are consistent across the week (variation: \(String(format: "%.0f", cv))%). Balanced activity supports better recovery." :
                "Your step counts vary \(String(format: "%.0f", cv))% across the week. Large swings can impact recovery and sleep.",
            recommendation: isConsistent ?
                "Great balance! Consistent daily activity is better for your body than feast-or-famine patterns." :
                "Try to maintain a baseline of activity every day, even on rest days. A 20-minute walk counts.",
            severity: cv > 35 ? .warning : .info,
            trend: isConsistent ? .improving : .stable,
            currentValue: cv,
            baselineValue: 20,
            deviationPercent: cv - 20,
            category: .weeklyPattern,
            relatedMetrics: [.steps]
        )
    }

    // MARK: - Helpers

    private static func dayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[weekday - 1]  // weekday is 1-indexed
    }
}
