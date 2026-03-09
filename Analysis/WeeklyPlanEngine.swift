import Foundation
import SwiftUI

// MARK: - Plan Goal

/// Preset weekly plan archetypes that shape daily targets
enum PlanGoal: String, CaseIterable, Identifiable, Sendable {
    case sleepDeeper
    case boostFitness
    case feelBetter
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleepDeeper:  "Sleep Deeper"
        case .boostFitness: "Boost Fitness"
        case .feelBetter:   "Feel Better"
        case .custom:       "Custom Plan"
        }
    }

    var description: String {
        switch self {
        case .sleepDeeper:
            "Focus on improving sleep quality and duration. Moderate activity with strategic rest days to promote deeper, more restorative sleep."
        case .boostFitness:
            "Progressive training targets to build fitness. Every day is an active day with adequate sleep to support recovery."
        case .feelBetter:
            "Balanced focus on recovery and stress reduction. Lower strain targets, consistent sleep, and plenty of rest days."
        case .custom:
            "Set your own daily targets for strain, sleep, and steps."
        }
    }

    var icon: String {
        switch self {
        case .sleepDeeper:  "moon.zzz.fill"
        case .boostFitness: "figure.run"
        case .feelBetter:   "heart.circle.fill"
        case .custom:       "slider.horizontal.3"
        }
    }

    var color: Color {
        switch self {
        case .sleepDeeper:  .indigo
        case .boostFitness: .orange
        case .feelBetter:   .green
        case .custom:       .blue
        }
    }
}

// MARK: - Daily Target

/// A single day's targets and actual performance within a weekly plan
struct DailyTarget: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    var targetStrain: ClosedRange<Double>
    var targetSleepHours: Double
    var targetSteps: Int
    var isRestDay: Bool
    var isCompleted: Bool
    var actualStrain: Double?
    var actualSleep: Double?
    var actualSteps: Int?

    /// Whether the user met at least 2 of 3 targets for this day
    var metTargets: Bool {
        guard isCompleted else { return false }
        var hits = 0
        if let strain = actualStrain, targetStrain.contains(strain) { hits += 1 }
        if let sleep = actualSleep, sleep >= targetSleepHours * 0.9 { hits += 1 }
        if let steps = actualSteps, steps >= Int(Double(targetSteps) * 0.85) { hits += 1 }
        return hits >= 2
    }
}

// MARK: - Weekly Plan

/// A full 7-day plan with targets, actuals, and adherence tracking
struct WeeklyPlan: Identifiable, Sendable {
    let id = UUID()
    let goal: PlanGoal
    let weekStartDate: Date
    var dailyTargets: [DailyTarget]
    var adherenceScore: Double
    var daysCompleted: Int

    /// Human-readable date range label (e.g., "Mar 9 – Mar 15")
    var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        guard let last = dailyTargets.last else {
            return formatter.string(from: weekStartDate)
        }
        return "\(formatter.string(from: weekStartDate)) – \(formatter.string(from: last.date))"
    }

    /// Fraction of the week completed (0.0 to 1.0)
    var progress: Double {
        Double(daysCompleted) / 7.0
    }
}

// MARK: - Weekly Plan Engine

/// Generates dynamic weekly plans with per-day targets based on the user's goal,
/// recovery state, and recent health data. Tracks adherence as the week progresses.
@Observable
final class WeeklyPlanEngine {

    // MARK: - State

    /// The active weekly plan, nil until generated
    private(set) var currentPlan: WeeklyPlan?

    /// Whether a plan has been generated and is ready
    var isReady: Bool { currentPlan != nil }

    /// The user's selected goal for plan generation
    var selectedGoal: PlanGoal = .feelBetter

    // MARK: - Constants

    /// Minimum days of historical data required for personalized targets
    private static let minDaysForPersonalization = 7

    /// Default step target when no data is available
    private static let defaultSteps = 8000

    /// Default sleep target when no data is available
    private static let defaultSleepHours: Double = 7.5

    /// Default strain midpoint when no data is available
    private static let defaultStrain: Double = 12.0

    // MARK: - Plan Generation

    /// Generate a weekly plan starting from next Monday (or today if Monday).
    ///
    /// - Parameters:
    ///   - goal: The plan archetype to follow
    ///   - recoveryState: Current recovery classification
    ///   - recentData: The health data store for pulling recent averages
    ///   - daysOfData: Total days of data the user has (for cold-start gating)
    /// - Returns: A fully populated `WeeklyPlan` with 7 daily targets
    func generatePlan(
        goal: PlanGoal,
        recoveryState: DashboardViewModel.RecoveryState,
        recentData: HealthDataStore,
        daysOfData: Int
    ) -> WeeklyPlan {
        let calendar = Calendar.current
        let weekStart = nextMonday()

        // Pull recent averages from the store
        let recentAverages = computeRecentAverages(from: recentData, daysOfData: daysOfData)

        // Build 7 daily targets (Mon through Sun)
        var dailyTargets: [DailyTarget] = []
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon, ..., 7=Sat
            let target = buildDailyTarget(
                date: date,
                weekday: weekday,
                dayIndex: dayOffset,
                goal: goal,
                recoveryState: recoveryState,
                averages: recentAverages,
                daysOfData: daysOfData
            )
            dailyTargets.append(target)
        }

        let plan = WeeklyPlan(
            goal: goal,
            weekStartDate: weekStart,
            dailyTargets: dailyTargets,
            adherenceScore: 0,
            daysCompleted: 0
        )

        selectedGoal = goal
        currentPlan = plan
        return plan
    }

    // MARK: - Adherence Tracking

    /// Update the current plan with actual values from the store and recompute adherence.
    ///
    /// - Parameters:
    ///   - plan: The plan to update (modified in place)
    ///   - store: The health data store to pull actual values from
    func updateAdherence(plan: inout WeeklyPlan, store: HealthDataStore) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Load relevant time series
        let strainSeries = store.loadTimeSeries(for: .activeCalories)
        let sleepSeries = store.loadTimeSeries(for: .sleepDuration)
        let stepsSeries = store.loadTimeSeries(for: .steps)

        var completed = 0
        var totalAdherence: Double = 0

        for i in plan.dailyTargets.indices {
            let targetDate = calendar.startOfDay(for: plan.dailyTargets[i].date)

            // Only fill in days that have passed
            guard targetDate <= today else { continue }

            // Find actual values for this day
            plan.dailyTargets[i].actualStrain = findValue(in: strainSeries, on: targetDate, calendar: calendar)
            plan.dailyTargets[i].actualSleep = findValue(in: sleepSeries, on: targetDate, calendar: calendar)

            if let stepValue = findValue(in: stepsSeries, on: targetDate, calendar: calendar) {
                plan.dailyTargets[i].actualSteps = Int(stepValue)
            }

            plan.dailyTargets[i].isCompleted = true
            completed += 1

            // Score this day's adherence (0 to 1)
            totalAdherence += computeDayAdherence(plan.dailyTargets[i])
        }

        plan.daysCompleted = completed
        plan.adherenceScore = completed > 0 ? (totalAdherence / Double(completed)) * 100.0 : 0

        currentPlan = plan
    }

    // MARK: - Private: Recent Averages

    private struct RecentAverages {
        let avgSleep: Double
        let avgSteps: Double
        let avgStrain: Double
    }

    private func computeRecentAverages(from store: HealthDataStore, daysOfData: Int) -> RecentAverages {
        let lookback = min(daysOfData, 14)
        guard lookback >= Self.minDaysForPersonalization else {
            return RecentAverages(
                avgSleep: Self.defaultSleepHours,
                avgSteps: Double(Self.defaultSteps),
                avgStrain: Self.defaultStrain
            )
        }

        let sleepAvg = store.loadTimeSeries(for: .sleepDuration)?.mean(lastDays: lookback) ?? Self.defaultSleepHours
        let stepsAvg = store.loadTimeSeries(for: .steps)?.mean(lastDays: lookback) ?? Double(Self.defaultSteps)
        let strainAvg = store.loadTimeSeries(for: .activeCalories)?.mean(lastDays: lookback) ?? Self.defaultStrain

        return RecentAverages(
            avgSleep: sleepAvg,
            avgSteps: stepsAvg,
            avgStrain: strainAvg
        )
    }

    // MARK: - Private: Daily Target Builder

    private func buildDailyTarget(
        date: Date,
        weekday: Int,
        dayIndex: Int,
        goal: PlanGoal,
        recoveryState: DashboardViewModel.RecoveryState,
        averages: RecentAverages,
        daysOfData: Int
    ) -> DailyTarget {
        switch goal {
        case .sleepDeeper:
            return buildSleepDeeperTarget(date: date, weekday: weekday, dayIndex: dayIndex, recoveryState: recoveryState, averages: averages)
        case .boostFitness:
            return buildBoostFitnessTarget(date: date, weekday: weekday, dayIndex: dayIndex, recoveryState: recoveryState, averages: averages)
        case .feelBetter:
            return buildFeelBetterTarget(date: date, weekday: weekday, dayIndex: dayIndex, recoveryState: recoveryState, averages: averages)
        case .custom:
            return buildCustomTarget(date: date, averages: averages)
        }
    }

    // MARK: Sleep Deeper

    /// Sleep 30min above current average, moderate strain on most days, 2 rest days (Wed + Sun)
    private func buildSleepDeeperTarget(
        date: Date,
        weekday: Int,
        dayIndex: Int,
        recoveryState: DashboardViewModel.RecoveryState,
        averages: RecentAverages
    ) -> DailyTarget {
        let restDays: Set<Int> = [1, 4] // Sunday, Wednesday
        let isRest = restDays.contains(weekday)

        let sleepTarget = averages.avgSleep + 0.5 // 30 min above average

        let strainRange: ClosedRange<Double>
        let stepTarget: Int

        if isRest {
            strainRange = 0...6
            stepTarget = max(4000, Int(averages.avgSteps * 0.5))
        } else {
            // Moderate strain — keep it controlled to promote sleep
            let baseMid = min(averages.avgStrain * 0.85, 14.0)
            let low = max(baseMid - 2, 4.0)
            let high = baseMid + 2
            strainRange = applyRecoveryAdjustment(low...high, recovery: recoveryState)
            stepTarget = max(6000, Int(averages.avgSteps * 0.9))
        }

        return DailyTarget(
            date: date,
            targetStrain: strainRange,
            targetSleepHours: sleepTarget,
            targetSteps: stepTarget,
            isRestDay: isRest,
            isCompleted: false
        )
    }

    // MARK: Boost Fitness

    /// Progressive strain (higher than recent average), adequate sleep, active every day
    private func buildBoostFitnessTarget(
        date: Date,
        weekday: Int,
        dayIndex: Int,
        recoveryState: DashboardViewModel.RecoveryState,
        averages: RecentAverages
    ) -> DailyTarget {
        // Progressive overload: strain increases slightly through the week, deload on day 6 (Sat)
        let progressionFactor: Double
        switch dayIndex {
        case 0: progressionFactor = 1.05  // Mon: slightly above average
        case 1: progressionFactor = 1.10  // Tue: building
        case 2: progressionFactor = 1.15  // Wed: peak mid-week
        case 3: progressionFactor = 1.05  // Thu: moderate
        case 4: progressionFactor = 1.15  // Fri: second peak
        case 5: progressionFactor = 0.80  // Sat: deload
        case 6: progressionFactor = 1.10  // Sun: moderate-high
        default: progressionFactor = 1.0
        }

        let baseMid = averages.avgStrain * progressionFactor
        let low = max(baseMid - 2, 4.0)
        let high = min(baseMid + 2, 21.0)
        let strainRange = applyRecoveryAdjustment(low...high, recovery: recoveryState)

        let sleepTarget = max(averages.avgSleep, 7.5) // At least 7.5h to support training
        let stepTarget = max(8000, Int(averages.avgSteps * 1.1))

        return DailyTarget(
            date: date,
            targetStrain: strainRange,
            targetSleepHours: sleepTarget,
            targetSteps: stepTarget,
            isRestDay: false, // No rest days for fitness plan
            isCompleted: false
        )
    }

    // MARK: Feel Better

    /// Lower strain, focus on sleep consistency, 3 rest days (Wed, Sat, Sun), meditation encouraged
    private func buildFeelBetterTarget(
        date: Date,
        weekday: Int,
        dayIndex: Int,
        recoveryState: DashboardViewModel.RecoveryState,
        averages: RecentAverages
    ) -> DailyTarget {
        let restDays: Set<Int> = [1, 4, 7] // Sunday, Wednesday, Saturday
        let isRest = restDays.contains(weekday)

        // Consistent sleep target slightly above average
        let sleepTarget = max(averages.avgSleep + 0.25, 7.5)

        let strainRange: ClosedRange<Double>
        let stepTarget: Int

        if isRest {
            strainRange = 0...5
            stepTarget = max(3000, Int(averages.avgSteps * 0.4))
        } else {
            // Lower strain than usual — recovery-focused
            let baseMid = averages.avgStrain * 0.75
            let low = max(baseMid - 2, 3.0)
            let high = min(baseMid + 2, 13.0)
            strainRange = applyRecoveryAdjustment(low...high, recovery: recoveryState)
            stepTarget = max(5000, Int(averages.avgSteps * 0.8))
        }

        return DailyTarget(
            date: date,
            targetStrain: strainRange,
            targetSleepHours: sleepTarget,
            targetSteps: stepTarget,
            isRestDay: isRest,
            isCompleted: false
        )
    }

    // MARK: Custom

    /// Balanced defaults that the user can override
    private func buildCustomTarget(date: Date, averages: RecentAverages) -> DailyTarget {
        let low = max(averages.avgStrain - 2, 2.0)
        let high = averages.avgStrain + 2

        return DailyTarget(
            date: date,
            targetStrain: low...high,
            targetSleepHours: averages.avgSleep,
            targetSteps: Int(averages.avgSteps),
            isRestDay: false,
            isCompleted: false
        )
    }

    // MARK: - Private: Recovery Adjustment

    /// Scale strain range down when recovery is yellow or red
    private func applyRecoveryAdjustment(
        _ range: ClosedRange<Double>,
        recovery: DashboardViewModel.RecoveryState
    ) -> ClosedRange<Double> {
        let scale: Double
        switch recovery {
        case .green:  scale = 1.0
        case .yellow: scale = 0.80
        case .red:    scale = 0.55
        }

        let adjustedLow = max(range.lowerBound * scale, 0)
        let adjustedHigh = range.upperBound * scale
        return adjustedLow...adjustedHigh
    }

    // MARK: - Private: Day Adherence

    /// Compute a 0-1 adherence score for a single day based on how close actuals are to targets
    private func computeDayAdherence(_ target: DailyTarget) -> Double {
        var components: [Double] = []

        // Strain adherence
        if let actual = target.actualStrain {
            if target.isRestDay {
                // Rest day: reward staying within or below range
                components.append(actual <= target.targetStrain.upperBound ? 1.0 : 0.5)
            } else {
                let mid = (target.targetStrain.lowerBound + target.targetStrain.upperBound) / 2
                let halfWidth = (target.targetStrain.upperBound - target.targetStrain.lowerBound) / 2
                let deviation = abs(actual - mid)
                components.append(max(0, 1.0 - deviation / max(halfWidth * 2, 1)))
            }
        }

        // Sleep adherence
        if let actual = target.actualSleep {
            let ratio = actual / max(target.targetSleepHours, 1)
            // Reward being at or above target, penalize being below
            if ratio >= 0.9 {
                components.append(min(ratio, 1.0))
            } else {
                components.append(ratio)
            }
        }

        // Steps adherence
        if let actual = target.actualSteps {
            let ratio = Double(actual) / max(Double(target.targetSteps), 1)
            components.append(min(ratio, 1.0))
        }

        guard !components.isEmpty else { return 0 }
        return components.reduce(0, +) / Double(components.count)
    }

    // MARK: - Private: Helpers

    /// Find the value in a time series for a specific calendar day
    private func findValue(
        in series: MetricTimeSeries?,
        on date: Date,
        calendar: Calendar
    ) -> Double? {
        guard let series else { return nil }
        return series.samples.first { calendar.isDate($0.date, inSameDayAs: date) }?.value
    }

    /// Compute the next Monday at midnight. If today is Monday, use today.
    private func nextMonday() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon

        if todayWeekday == 2 {
            return today
        }

        // Days until next Monday
        let daysUntilMonday = (9 - todayWeekday) % 7
        return calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: today) ?? today
    }
}
