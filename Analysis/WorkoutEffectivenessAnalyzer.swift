import Foundation

/// Measures workout consistency, VO2 Max response, and calorie efficiency
struct WorkoutEffectivenessAnalyzer {

    /// Analyze workout effectiveness and generate insights
    static func generateInsights(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Insight] {
        var insights: [Insight] = []

        // --- Consistency Score ---
        if let workoutSeries = timeSeries[.workoutDuration] {
            if let consistencyInsight = analyzeConsistency(workoutSeries) {
                insights.append(consistencyInsight)
            }
        }

        // --- VO2 Max Response ---
        if let vo2Series = timeSeries[.vo2Max] {
            if let vo2Insight = analyzeVO2MaxResponse(vo2Series) {
                insights.append(vo2Insight)
            }
        }

        // --- Calorie Efficiency ---
        if let calSeries = timeSeries[.activeCalories],
           let exSeries = timeSeries[.exerciseMinutes] {
            if let efficiencyInsight = analyzeCalorieEfficiency(calSeries: calSeries, exerciseSeries: exSeries) {
                insights.append(efficiencyInsight)
            }
        }

        return insights
    }

    // MARK: - Consistency

    private static func analyzeConsistency(_ workoutSeries: MetricTimeSeries) -> Insight? {
        let last28 = workoutSeries.samples(lastDays: 28)
        guard last28.count >= 7 else { return nil }

        // Count workout days per week for the last 4 weeks
        var weekWorkoutCounts: [Int] = []
        for weekOffset in 0..<4 {
            let weekStart = Date().daysAgo(28 - weekOffset * 7)
            let weekEnd = Date().daysAgo(21 - weekOffset * 7)
            let weekWorkouts = last28.filter { sample in
                sample.value > 0 && sample.date >= weekStart && sample.date < weekEnd
            }.count
            weekWorkoutCounts.append(weekWorkouts)
        }

        let weeksWithTarget = weekWorkoutCounts.filter { $0 >= 3 }.count
        let consistencyScore = Double(weeksWithTarget) / 4.0 * 100
        let weeklyAvg = Double(weekWorkoutCounts.reduce(0, +)) / 4.0

        let severity: Severity = consistencyScore < 50 ? .warning : .info
        let trend: TrendDirection = weekWorkoutCounts.last ?? 0 >= weekWorkoutCounts.first ?? 0 ? .improving : .declining

        return Insight(
            metric: .workoutDuration,
            title: "Workout Consistency",
            summary: "\(Int(consistencyScore))% of the last 4 weeks had 3+ workout days. You're averaging \(String(format: "%.1f", weeklyAvg)) workouts per week.",
            recommendation: consistencyScore >= 75 ?
                "Excellent consistency! Maintain this routine for long-term fitness gains." :
                "Aim for at least 3 workout days per week. Scheduling workouts at the same time builds the habit.",
            severity: severity,
            trend: trend,
            currentValue: consistencyScore,
            baselineValue: 75,
            deviationPercent: consistencyScore - 75,
            category: .workoutEffectiveness,
            relatedMetrics: [.workoutDuration, .exerciseMinutes]
        )
    }

    // MARK: - VO2 Max Response

    private static func analyzeVO2MaxResponse(_ vo2Series: MetricTimeSeries) -> Insight? {
        let recent = vo2Series.samples(lastDays: 30)
        let older = vo2Series.samples(lastDays: 60).filter { sample in
            sample.date < Date().daysAgo(30)
        }

        guard recent.count >= 3, older.count >= 3 else { return nil }

        let recentAvg = recent.map(\.value).mean
        let olderAvg = older.map(\.value).mean
        guard olderAvg > 0 else { return nil }

        let change = ((recentAvg - olderAvg) / olderAvg) * 100
        let trend: TrendDirection = change > 2 ? .improving : (change < -2 ? .declining : .stable)

        return Insight(
            metric: .vo2Max,
            title: "VO2 Max Response",
            summary: "Your VO2 Max \(change > 0 ? "improved" : "decreased") \(String(format: "%.1f", abs(change)))% over the last 30 days (\(String(format: "%.1f", olderAvg)) → \(String(format: "%.1f", recentAvg)) \(HealthMetric.vo2Max.unit)).",
            recommendation: change > 0 ?
                "Your cardiovascular fitness is improving. Keep up your current training intensity." :
                "Consider adding more zone 2 cardio (conversational pace) to boost aerobic capacity.",
            severity: abs(change) > 5 ? .warning : .info,
            trend: trend,
            currentValue: recentAvg,
            baselineValue: olderAvg,
            deviationPercent: change,
            category: .workoutEffectiveness,
            relatedMetrics: [.vo2Max, .exerciseMinutes]
        )
    }

    // MARK: - Calorie Efficiency

    private static func analyzeCalorieEfficiency(
        calSeries: MetricTimeSeries,
        exerciseSeries: MetricTimeSeries
    ) -> Insight? {
        let aligned7d = TimeSeriesAligner.alignByDate(calSeries, exerciseSeries)
            .filter { $0.date >= Date().daysAgo(7) && $0.valueB > 0 }
        let aligned30d = TimeSeriesAligner.alignByDate(calSeries, exerciseSeries)
            .filter { $0.date >= Date().daysAgo(30) && $0.valueB > 0 }

        guard aligned7d.count >= 3, aligned30d.count >= 7 else { return nil }

        let efficiency7d = aligned7d.map { $0.valueA / $0.valueB }.mean
        let efficiency30d = aligned30d.map { $0.valueA / $0.valueB }.mean

        guard efficiency30d > 0 else { return nil }

        let change = ((efficiency7d - efficiency30d) / efficiency30d) * 100
        let trend: TrendDirection = change > 5 ? .improving : (change < -5 ? .declining : .stable)

        return Insight(
            metric: .activeCalories,
            title: "Calorie Efficiency",
            summary: "You're burning \(String(format: "%.1f", efficiency7d)) kcal/min this week vs \(String(format: "%.1f", efficiency30d)) kcal/min over 30 days (\(change > 0 ? "+" : "")\(String(format: "%.0f", change))%).",
            recommendation: change > 0 ?
                "Your workout intensity is increasing — great for fitness gains. Monitor recovery to avoid overtraining." :
                "Try increasing workout intensity with intervals or resistance training to boost calorie burn.",
            severity: .info,
            trend: trend,
            currentValue: efficiency7d,
            baselineValue: efficiency30d,
            deviationPercent: change,
            category: .workoutEffectiveness,
            relatedMetrics: [.activeCalories, .exerciseMinutes]
        )
    }
}
