import Foundation

/// Tracks rolling personal records, milestones, and activity streaks
struct PersonalRecordAnalyzer {

    private struct TrackedMetric {
        let metric: HealthMetric
        let lowerIsBetter: Bool
        let milestoneThreshold: Double?
        let milestoneLabel: String?
        let streakThreshold: Double?
        let streakLabel: String?
    }

    private static let trackedMetrics: [TrackedMetric] = [
        TrackedMetric(metric: .steps, lowerIsBetter: false,
                      milestoneThreshold: 10000, milestoneLabel: "10K Step Day",
                      streakThreshold: 8000, streakLabel: "8K+ Steps"),
        TrackedMetric(metric: .activeCalories, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .exerciseMinutes, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: 30, streakLabel: "30+ Min Exercise"),
        TrackedMetric(metric: .vo2Max, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .heartRateVariability, lowerIsBetter: false,
                      milestoneThreshold: 50, milestoneLabel: "HRV Above 50ms",
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .sleepDuration, lowerIsBetter: false,
                      milestoneThreshold: 8, milestoneLabel: "8-Hour Sleep Night",
                      streakThreshold: 7, streakLabel: "7+ Hr Sleep"),
        TrackedMetric(metric: .restingHeartRate, lowerIsBetter: true,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .standHours, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: 10, streakLabel: "10+ Stand Hours"),
    ]

    /// Analyze personal records, milestones, and streaks
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        // --- Rolling PRs ---
        insights.append(contentsOf: findRollingPRs(timeSeries: timeSeries))

        // --- Active Streaks ---
        insights.append(contentsOf: findStreaks(timeSeries: timeSeries))

        // --- Milestones ---
        insights.append(contentsOf: findMilestones(timeSeries: timeSeries))

        return insights
    }

    // MARK: - Rolling PRs

    private static func findRollingPRs(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        for tracked in trackedMetrics {
            guard let series = timeSeries[tracked.metric] else { continue }
            let sorted = series.sortedSamples
            guard sorted.count >= 30 else { continue }

            let values = sorted.map(\.value)

            // 7-day rolling average PR
            if let prInsight = checkRollingPR(
                metric: tracked.metric,
                values: values,
                window: 7,
                windowLabel: "7-day",
                lowerIsBetter: tracked.lowerIsBetter
            ) {
                insights.append(prInsight)
            }

            // 30-day rolling average PR
            if let prInsight = checkRollingPR(
                metric: tracked.metric,
                values: values,
                window: 30,
                windowLabel: "30-day",
                lowerIsBetter: tracked.lowerIsBetter
            ) {
                insights.append(prInsight)
            }
        }

        return insights
    }

    private static func checkRollingPR(
        metric: HealthMetric,
        values: [Double],
        window: Int,
        windowLabel: String,
        lowerIsBetter: Bool
    ) -> Insight? {
        guard values.count >= window else { return nil }

        let movingAverages = values.movingAverage(window: window)
        guard !movingAverages.isEmpty else { return nil }

        guard let currentAvg = movingAverages.last else { return nil }
        let bestPrevious: Double
        if lowerIsBetter {
            bestPrevious = movingAverages.dropLast().min() ?? currentAvg
        } else {
            bestPrevious = movingAverages.dropLast().max() ?? currentAvg
        }

        let isPR: Bool
        if lowerIsBetter {
            isPR = currentAvg <= bestPrevious && movingAverages.count > 1
        } else {
            isPR = currentAvg >= bestPrevious && movingAverages.count > 1
        }

        guard isPR else { return nil }

        let improvement: Double
        if bestPrevious != 0 {
            improvement = abs((currentAvg - bestPrevious) / bestPrevious) * 100
        } else {
            improvement = 0
        }

        // Only report if it's a meaningful PR (within 2% of previous best counts as "tied")
        guard improvement < 2 || movingAverages.count <= window + 1 else {
            // It's a new PR with real improvement
            return Insight(
                metric: metric,
                title: "New \(windowLabel) PR: \(metric.displayName)",
                summary: "Your \(windowLabel) average \(metric.displayName.lowercased()) hit a personal record: \(String(format: "%.1f", currentAvg)) \(metric.unit). Previous best: \(String(format: "%.1f", bestPrevious)) \(metric.unit).",
                recommendation: "You're at your all-time best! Keep the momentum going while ensuring adequate recovery.",
                severity: .info,
                trend: .improving,
                currentValue: currentAvg,
                baselineValue: bestPrevious,
                deviationPercent: improvement,
                category: .personalRecord,
                relatedMetrics: [metric]
            )
        }

        // First window ever or tied with previous best
        return nil
    }

    // MARK: - Streaks

    private static func findStreaks(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        for tracked in trackedMetrics {
            guard let threshold = tracked.streakThreshold,
                  let label = tracked.streakLabel,
                  let series = timeSeries[tracked.metric] else { continue }

            let valueMap = TimeSeriesAligner.dailyValueMap(series)
            var currentStreak = 0
            var today = Date().startOfDay

            // Count consecutive days backward from today
            while true {
                if let value = valueMap[today], value >= threshold {
                    currentStreak += 1
                    today = Calendar.current.date(byAdding: .day, value: -1, to: today)?.startOfDay ?? today
                } else {
                    break
                }
            }

            guard currentStreak >= 3 else { continue }

            insights.append(Insight(
                metric: tracked.metric,
                title: "\(currentStreak)-Day \(label) Streak",
                summary: "You've hit \(label.lowercased()) for \(currentStreak) consecutive days. Keep the streak alive!",
                recommendation: currentStreak >= 7 ?
                    "Incredible consistency! This streak is building lasting habits." :
                    "You're building momentum — aim for 7 days to lock in the habit.",
                severity: .info,
                trend: .improving,
                currentValue: Double(currentStreak),
                baselineValue: 3,
                deviationPercent: Double(currentStreak - 3) / 3.0 * 100,
                category: .personalRecord,
                relatedMetrics: [tracked.metric]
            ))
        }

        return insights
    }

    // MARK: - Milestones

    private static func findMilestones(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        for tracked in trackedMetrics {
            guard let threshold = tracked.milestoneThreshold,
                  let label = tracked.milestoneLabel,
                  let series = timeSeries[tracked.metric] else { continue }

            let recent = series.samples(lastDays: 7)
            let achieved = recent.contains { sample in
                tracked.lowerIsBetter ? sample.value <= threshold : sample.value >= threshold
            }

            // Check if this is the first time (not in older data)
            let older = series.samples(lastDays: 90).filter { sample in
                sample.date < Date().daysAgo(7)
            }
            let previouslyAchieved = older.contains { sample in
                tracked.lowerIsBetter ? sample.value <= threshold : sample.value >= threshold
            }

            guard achieved, !previouslyAchieved else { continue }

            insights.append(Insight(
                metric: tracked.metric,
                title: "Milestone: \(label)",
                summary: "You achieved \(label.lowercased()) for the first time this week! This is a significant milestone in your health journey.",
                recommendation: "Celebrate this achievement! Now work on making it consistent.",
                severity: .info,
                trend: .improving,
                currentValue: threshold,
                baselineValue: 0,
                deviationPercent: 100,
                category: .personalRecord,
                relatedMetrics: [tracked.metric]
            ))
        }

        return insights
    }
}
