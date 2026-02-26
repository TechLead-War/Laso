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

    // MARK: - Weakest Day (multi-metric)

    private static func findWeakestDay(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Find the weakest day across multiple metrics, not just steps
        let metricsToCheck: [(metric: HealthMetric, label: String)] = [
            (.steps, "steps"), (.activeCalories, "active calories"), (.exerciseMinutes, "exercise minutes")
        ]

        for entry in metricsToCheck {
            guard let series = timeSeries[entry.metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            var dayAverages: [(day: Int, avg: Double)] = []
            for (day, values) in groups {
                guard values.count >= 2 else { continue }
                dayAverages.append((day: day, avg: values.mean))
            }

            guard dayAverages.count >= 5 else { continue }

            dayAverages.sort { $0.avg < $1.avg }
            let overallAvg = dayAverages.map(\.avg).mean

            guard let weakest = dayAverages.first,
                  let strongest = dayAverages.last,
                  overallAvg > 0 else { continue }

            let weakestName = dayName(for: weakest.day)
            let strongestName = dayName(for: strongest.day)
            let deficit = ((overallAvg - weakest.avg) / overallAvg) * 100

            guard deficit >= 10 else { continue }

            return Insight(
                metric: entry.metric,
                title: "Weakest Day: \(weakestName)",
                summary: "\(weakestName) is your least active day with \(String(format: "%.0f", weakest.avg)) avg \(entry.label) — \(String(format: "%.0f", deficit))% below your daily average. \(strongestName) is your strongest (\(String(format: "%.0f", strongest.avg))).",
                recommendation: "Schedule a walk or light activity on \(weakestName)s to close the gap. Even 15 minutes can make a difference.",
                severity: deficit >= 25 ? .warning : .info,
                trend: .stable,
                currentValue: weakest.avg,
                baselineValue: overallAvg,
                deviationPercent: -deficit,
                category: .weeklyPattern,
                relatedMetrics: [entry.metric]
            )
        }
        return nil
    }

    // MARK: - Weekend Gap (multi-metric)

    private static func analyzeWeekendGap(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Check multiple metrics for weekend gaps
        let metricsToCheck: [(metric: HealthMetric, label: String, unit: String)] = [
            (.steps, "steps", "steps"),
            (.exerciseMinutes, "exercise", "min"),
            (.activeCalories, "active calories", "cal"),
            (.sleepDuration, "sleep", "hrs")
        ]

        for entry in metricsToCheck {
            guard let series = timeSeries[entry.metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            let weekdayValues = [2, 3, 4, 5, 6].flatMap { groups[$0] ?? [] }
            let weekendValues = [1, 7].flatMap { groups[$0] ?? [] }

            guard weekdayValues.count >= 5, weekendValues.count >= 2 else { continue }

            let weekdayAvg = weekdayValues.mean
            let weekendAvg = weekendValues.mean

            guard weekdayAvg > 0 else { continue }

            let gap = ((weekdayAvg - weekendAvg) / weekdayAvg) * 100

            guard abs(gap) >= 15 else { continue }

            let moreActive = gap > 0 ? "weekdays" : "weekends"

            return Insight(
                metric: entry.metric,
                title: "\(entry.metric.displayName): Weekday vs Weekend",
                summary: "Your \(entry.label) is \(String(format: "%.0f", abs(gap)))% higher on \(moreActive). Weekday avg: \(String(format: "%.0f", weekdayAvg)) \(entry.unit), weekend avg: \(String(format: "%.0f", weekendAvg)) \(entry.unit).",
                recommendation: gap > 20 ?
                    "Try adding a weekend activity — a hike, bike ride, or long walk can close the gap." :
                    "Your \(entry.label) levels are fairly balanced across the week. Keep it up!",
                severity: abs(gap) >= 30 ? .warning : .info,
                trend: .stable,
                currentValue: weekendAvg,
                baselineValue: weekdayAvg,
                deviationPercent: -gap,
                category: .weeklyPattern,
                relatedMetrics: [entry.metric]
            )
        }
        return nil
    }

    // MARK: - Weekly Consistency (multi-metric)

    private static func analyzeWeeklyConsistency(timeSeries: [HealthMetric: MetricTimeSeries]) -> Insight? {
        // Analyze consistency across the best available metric
        let metricsToCheck: [HealthMetric] = [.steps, .exerciseMinutes, .activeCalories, .sleepDuration]

        for metric in metricsToCheck {
            guard let series = timeSeries[metric] else { continue }

            let groups = TimeSeriesAligner.groupByDayOfWeek(series)

            let dayAverages = (1...7).compactMap { day -> Double? in
                let values = groups[day] ?? []
                guard values.count >= 2 else { return nil }
                return values.mean
            }

            guard dayAverages.count >= 5 else { continue }

            let mean = dayAverages.mean
            guard mean > 0 else { continue }

            let cv = dayAverages.standardDeviation / mean * 100

            let isConsistent = cv < 20

            return Insight(
                metric: metric,
                title: "\(metric.displayName) Consistency",
                summary: isConsistent ?
                    "Your \(metric.displayName.lowercased()) is consistent across the week (variation: \(String(format: "%.0f", cv))%). Balanced activity supports better recovery." :
                    "Your \(metric.displayName.lowercased()) varies \(String(format: "%.0f", cv))% across the week. Large swings can impact recovery and sleep.",
                recommendation: isConsistent ?
                    "Great balance! Consistency is better for your body than feast-or-famine patterns." :
                    "Try to maintain a baseline level every day, even on rest days. Small efforts count.",
                severity: cv > 35 ? .warning : .info,
                trend: isConsistent ? .improving : .stable,
                currentValue: cv,
                baselineValue: 20,
                deviationPercent: cv - 20,
                category: .weeklyPattern,
                relatedMetrics: [metric]
            )
        }
        return nil
    }

    // MARK: - Helpers

    private static func dayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[weekday - 1]  // weekday is 1-indexed
    }
}
