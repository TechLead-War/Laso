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
                      milestoneThreshold: 10000, milestoneLabel: Copy.Analysis.PersonalRecord.tenKStepDay,
                      streakThreshold: 8000, streakLabel: Copy.Analysis.PersonalRecord.eightKPlusSteps),
        TrackedMetric(metric: .activeCalories, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .exerciseMinutes, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: 30, streakLabel: Copy.Analysis.PersonalRecord.thirtyPlusMinExercise),
        TrackedMetric(metric: .vo2Max, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .heartRateVariability, lowerIsBetter: false,
                      milestoneThreshold: 50, milestoneLabel: Copy.Analysis.PersonalRecord.hrvAbove50ms,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .sleepDuration, lowerIsBetter: false,
                      milestoneThreshold: 8, milestoneLabel: Copy.Analysis.PersonalRecord.eightHourSleepNight,
                      streakThreshold: 7, streakLabel: Copy.Analysis.PersonalRecord.sevenPlusHrSleep),
        TrackedMetric(metric: .restingHeartRate, lowerIsBetter: true,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: nil, streakLabel: nil),
        TrackedMetric(metric: .standHours, lowerIsBetter: false,
                      milestoneThreshold: nil, milestoneLabel: nil,
                      streakThreshold: 10, streakLabel: Copy.Analysis.PersonalRecord.tenPlusStandHours),
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
            // Calculate how long the previous record stood
            let previousBestIndex: Int
            if lowerIsBetter {
                previousBestIndex = movingAverages.dropLast().enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            } else {
                previousBestIndex = movingAverages.dropLast().enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            }
            let recordAgeDays = movingAverages.count - 1 - previousBestIndex
            let recordAgeNote = recordAgeDays > 7 ? " You beat a record that stood for \(recordAgeDays) days." : ""

            // It's a new PR with real improvement. use variable templates for copy variety
            let templateVariant = metric.rawValue.count % 3
            let prSummary: String
            let prRecommendation: String
            switch templateVariant {
            case 1:
                prSummary = "New personal best! Your \(windowLabel) \(metric.displayName.lowercased()) just reached \(String(format: "%.1f", currentAvg)) \(metric.unit) \u{2014} that's \(String(format: "%.1f", improvement))% above your previous record.\(recordAgeNote)"
                prRecommendation = "New \(windowLabel) record for \(metric.displayName.lowercased()): \(String(format: "%.1f", currentAvg)) \(metric.unit), surpassing previous best of \(String(format: "%.1f", bestPrevious)) \(metric.unit)."
            case 2:
                prSummary = "Record broken: \(metric.displayName.lowercased()) at \(String(format: "%.1f", currentAvg)) \(metric.unit). Keep this trajectory going.\(recordAgeNote)"
                prRecommendation = "New \(windowLabel) record for \(metric.displayName.lowercased()): \(String(format: "%.1f", currentAvg)) \(metric.unit), surpassing previous best of \(String(format: "%.1f", bestPrevious)) \(metric.unit)."
            default:
                prSummary = "Your \(windowLabel) average \(metric.displayName.lowercased()) hit a personal record: \(String(format: "%.1f", currentAvg)) \(metric.unit). Previous best: \(String(format: "%.1f", bestPrevious)) \(metric.unit) (\(String(format: "%.1f", improvement))% improvement). You're building real momentum.\(recordAgeNote)"
                prRecommendation = "New \(windowLabel) record for \(metric.displayName.lowercased()): \(String(format: "%.1f", currentAvg)) \(metric.unit), surpassing previous best of \(String(format: "%.1f", bestPrevious)) \(metric.unit)."
            }

            return Insight(
                metric: metric,
                title: Copy.Analysis.PersonalRecord.newPR(windowLabel: windowLabel, metricName: metric.displayName),
                summary: prSummary,
                recommendation: prRecommendation,
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
                title: Copy.Analysis.PersonalRecord.streakTitle(days: currentStreak, label: label),
                summary: Copy.Analysis.PersonalRecord.streakSummary(label: label, days: currentStreak),
                recommendation: currentStreak >= 7 ?
                    "\(currentStreak)-day streak of \(label.lowercased()). This is your longest active run." :
                    "Current streak: \(currentStreak) consecutive days of \(label.lowercased()).",
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

            // Check if this is the first time (not in any older data)
            let older = series.sortedSamples.filter { sample in
                sample.date < Date().daysAgo(7)
            }
            let previouslyAchieved = older.contains { sample in
                tracked.lowerIsBetter ? sample.value <= threshold : sample.value >= threshold
            }

            guard achieved, !previouslyAchieved else { continue }

            insights.append(Insight(
                metric: tracked.metric,
                title: Copy.Analysis.PersonalRecord.milestoneTitle(label),
                summary: Copy.Analysis.PersonalRecord.milestoneSummary(label),
                recommendation: Copy.Analysis.PersonalRecord.milestoneRecommendation(label),
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

// MARK: - InsightAnalyzer Conformance

extension PersonalRecordAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "personalRecord" }
    static var insightCategory: InsightCategory { .personalRecord }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(timeSeries: context.timeSeries)
    }
}
