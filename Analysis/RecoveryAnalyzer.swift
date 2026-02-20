import Foundation

/// Tracks post-workout HRV/RHR recovery, rest deficits, and overtraining signals
struct RecoveryAnalyzer {

    struct RecoveryProfile {
        let averageRecoveryDays: Double
        let recommendedRestDays: Int
        let actualRestDays: Int
        let restDeficit: Int
        let isOvertraining: Bool
    }

    /// Analyze recovery patterns and generate insights
    static func generateInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> [Insight] {
        var insights: [Insight] = []

        // Need workout data + at least one recovery metric
        guard let workoutSeries = timeSeries[.workoutDuration] else { return [] }

        let workoutDays = identifyWorkoutDays(workoutSeries)
        guard workoutDays.count >= 3 else { return [] }

        // Classify workout intensity
        let intensities = classifyIntensity(
            workoutDays: workoutDays,
            activeCalSeries: timeSeries[.activeCalories],
            baselines: baselines
        )

        // Track HRV recovery
        if let hrvSeries = timeSeries[.heartRateVariability],
           let hrvBaseline = baselines[.heartRateVariability] {
            let recoveryDays = computeRecoveryTime(
                workoutDays: workoutDays,
                recoverySeries: hrvSeries,
                baseline: hrvBaseline,
                higherIsBetter: true
            )
            if !recoveryDays.isEmpty {
                let avgRecovery = recoveryDays.map { Double($0) }.mean
                let trend: TrendDirection = avgRecovery > 2.5 ? .declining : .improving

                insights.append(Insight(
                    metric: .heartRateVariability,
                    title: "Post-Workout HRV Recovery",
                    summary: "Your HRV takes an average of \(String(format: "%.1f", avgRecovery)) days to return to baseline after workouts.",
                    recommendation: avgRecovery > 2 ?
                        "Consider adding more rest days or reducing workout intensity to improve recovery." :
                        "Your recovery is strong — your body bounces back quickly after workouts.",
                    severity: avgRecovery > 3 ? .warning : .info,
                    trend: trend,
                    currentValue: avgRecovery,
                    baselineValue: 2.0,
                    deviationPercent: ((avgRecovery - 2.0) / 2.0) * 100,
                    category: .recovery,
                    relatedMetrics: [.heartRateVariability, .workoutDuration]
                ))
            }
        }

        // Rest deficit analysis
        let last28 = workoutDays.filter { $0.timeIntervalSinceNow > -28 * 86400 }
        let workoutCount28 = last28.count
        let restDays28 = 28 - workoutCount28
        let highIntensityCount = intensities.filter { $0.value == .high }
            .filter { $0.key.timeIntervalSinceNow > -28 * 86400 }.count
        let recommendedRest = max(2, highIntensityCount)

        if restDays28 < recommendedRest * 4 {  // recommended per week * 4 weeks
            let weeklyRest = Double(restDays28) / 4.0
            insights.append(Insight(
                metric: .workoutDuration,
                title: "Rest Day Deficit",
                summary: "You're averaging \(String(format: "%.1f", weeklyRest)) rest days per week. With \(highIntensityCount) high-intensity sessions this month, you need more recovery time.",
                recommendation: "Schedule at least \(recommendedRest) rest days per week, especially after high-intensity sessions.",
                severity: .warning,
                trend: .declining,
                currentValue: weeklyRest,
                baselineValue: Double(recommendedRest),
                deviationPercent: ((weeklyRest - Double(recommendedRest)) / Double(recommendedRest)) * 100,
                category: .recovery,
                relatedMetrics: [.workoutDuration, .activeCalories]
            ))
        }

        // Overtraining detection: declining HRV + elevated RHR + declining sleep (all 3)
        let hrvDeclining = trends[.heartRateVariability]?.direction == .declining
        let rhrElevated = trends[.restingHeartRate]?.direction == .declining  // declining for RHR means getting worse (higher)
        let sleepDeclining = trends[.sleepDuration]?.direction == .declining

        if hrvDeclining && rhrElevated && sleepDeclining {
            insights.append(Insight(
                metric: .heartRateVariability,
                title: "Overtraining Warning",
                summary: "Multiple signals suggest overtraining: HRV is declining, resting heart rate is elevated, and sleep duration is dropping.",
                recommendation: "Take 2-3 complete rest days. Focus on sleep, hydration, and light movement like walking. Resume training at reduced intensity.",
                severity: .critical,
                trend: .declining,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: 25,
                category: .recovery,
                relatedMetrics: [.heartRateVariability, .restingHeartRate, .sleepDuration]
            ))
        }

        return insights
    }

    // MARK: - Private Helpers

    private enum WorkoutIntensity {
        case low, moderate, high
    }

    private static func identifyWorkoutDays(_ series: MetricTimeSeries) -> [Date] {
        series.samples
            .filter { $0.value > 0 }
            .map { $0.date.startOfDay }
    }

    private static func classifyIntensity(
        workoutDays: [Date],
        activeCalSeries: MetricTimeSeries?,
        baselines: [HealthMetric: UserBaseline]
    ) -> [Date: WorkoutIntensity] {
        guard let calSeries = activeCalSeries,
              let calBaseline = baselines[.activeCalories] else {
            return Dictionary(uniqueKeysWithValues: workoutDays.map { ($0, WorkoutIntensity.moderate) })
        }

        let calMap = TimeSeriesAligner.dailyValueMap(calSeries)
        var result: [Date: WorkoutIntensity] = [:]

        for day in workoutDays {
            guard let cals = calMap[day] else {
                result[day] = .moderate
                continue
            }
            let ratio = cals / calBaseline.mean
            if ratio > 1.5 {
                result[day] = .high
            } else if ratio > 1.0 {
                result[day] = .moderate
            } else {
                result[day] = .low
            }
        }
        return result
    }

    /// Compute days until recovery metric returns within 1 stddev of baseline after each workout
    private static func computeRecoveryTime(
        workoutDays: [Date],
        recoverySeries: MetricTimeSeries,
        baseline: UserBaseline,
        higherIsBetter: Bool
    ) -> [Int] {
        let valueMap = TimeSeriesAligner.dailyValueMap(recoverySeries)
        var recoveryDays: [Int] = []

        for workoutDay in workoutDays {
            for dayAfter in 1...7 {
                guard let checkDate = Calendar.current.date(byAdding: .day, value: dayAfter, to: workoutDay) else { break }
                let checkDay = checkDate.startOfDay
                guard let value = valueMap[checkDay] else { continue }

                let withinBaseline: Bool
                if higherIsBetter {
                    withinBaseline = value >= baseline.mean - baseline.standardDeviation
                } else {
                    withinBaseline = value <= baseline.mean + baseline.standardDeviation
                }

                if withinBaseline {
                    recoveryDays.append(dayAfter)
                    break
                }
            }
        }
        return recoveryDays
    }
}
