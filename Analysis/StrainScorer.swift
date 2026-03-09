import Foundation
import SwiftUI

// MARK: - Strain Level

/// Categorizes strain intensity into discrete levels
enum StrainLevel: String, CaseIterable {
    case low
    case light
    case moderate
    case high
    case overreaching
    case allOut

    init(strain: Double) {
        switch strain {
        case ..<6:   self = .low
        case ..<10:  self = .light
        case ..<14:  self = .moderate
        case ..<18:  self = .high
        case ..<20:  self = .overreaching
        default:     self = .allOut
        }
    }

    var displayName: String {
        switch self {
        case .low:          return "Low"
        case .light:        return "Light"
        case .moderate:     return "Moderate"
        case .high:         return "High"
        case .overreaching: return "Overreaching"
        case .allOut:       return "All Out"
        }
    }

    var color: Color {
        switch self {
        case .low:          return .blue
        case .light:        return .green
        case .moderate:     return .yellow
        case .high:         return .orange
        case .overreaching: return .red
        case .allOut:       return .red
        }
    }
}

// MARK: - StrainScorer

/// Computes a daily Strain Score on a 0-21 logarithmic scale,
/// where each additional point requires exponentially more effort.
/// Inspired by WHOOP's strain model: combines calorie expenditure,
/// heart rate zone time, exercise duration, and movement data.
@Observable
final class StrainScorer {

    // MARK: - Outputs

    /// Current day's strain score (0-21 logarithmic scale)
    private(set) var currentStrain: Double = 0

    /// Categorical strain level derived from currentStrain
    var strainLevel: StrainLevel { StrainLevel(strain: currentStrain) }

    /// Minutes spent in each heart rate zone today (zone 1-5)
    private(set) var zoneMinutes: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]

    /// Today's active calorie expenditure
    private(set) var todayCalories: Double = 0

    /// Whether sufficient data exists to produce a valid strain score
    private(set) var isReady: Bool = false

    /// Rolling 7-day strain history for trend visualization
    private(set) var weeklyStrainHistory: [(date: Date, strain: Double)] = []

    /// Color representing the current strain level
    var strainColor: Color { strainLevel.color }

    /// Human-readable label for the current strain
    var strainLabel: String { strainLevel.displayName }

    // MARK: - Constants

    /// The maximum expected physiological load used to normalize the logarithmic scale.
    /// Calibrated so that an elite-level training day (~1200 kcal active, 90 min zone 4-5)
    /// maps to approximately strain 20-21.
    private static let maxExpectedLoad: Double = 800.0

    /// Minimum days of calorie data required before computing strain
    private static let minimumDaysForBaseline: Int = 7

    /// HR zone multipliers — higher zones contribute disproportionately more strain
    private static let zoneMultipliers: [Int: Double] = [
        1: 1.0,    // Light: minimal strain contribution
        2: 2.0,    // Moderate: steady aerobic
        3: 4.0,    // Vigorous: tempo / threshold
        4: 8.0,    // High: VO2 max intervals
        5: 14.0    // Max: anaerobic / sprint
    ]

    // MARK: - Compute

    /// Compute strain score from HealthKit data.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store containing metric time series.
    ///   - age: The user's age in years (used to estimate max heart rate).
    ///   - restingHR: Optional resting heart rate in bpm. If nil, falls back to
    ///     the most recent resting HR from HealthKit data.
    func compute(from store: HealthDataStore, age: Int, restingHR: Double?) {
        let allSeries = store.loadAllTimeSeries()

        // Resolve resting heart rate: parameter > HealthKit > population default
        let effectiveRestingHR = resolveRestingHR(restingHR, from: allSeries)
        let maxHR = 220.0 - Double(age)

        // Guard: need a valid HR range
        guard maxHR > effectiveRestingHR else {
            isReady = false
            return
        }

        // --- Active Calories ---
        let calorieSeries = allSeries[.activeCalories]
        let todaySamples = calorieSeries?.samples(lastDays: 1) ?? []
        todayCalories = todaySamples.reduce(0.0) { $0 + $1.value }

        // Compute personal calorie baseline from recent history
        let calorieBaseline = computeCalorieBaseline(from: calorieSeries)

        // Check minimum data: need at least 7 days of calorie data for a personal baseline,
        // or fall back to a population default
        let hasBaseline = (calorieSeries?.daysOfData ?? 0) >= Self.minimumDaysForBaseline

        // --- Heart Rate Zone Distribution ---
        let hrSamples = allSeries[.heartRate]?.samples(lastDays: 1) ?? []
        let zones = computeZoneMinutes(
            hrSamples: hrSamples,
            restingHR: effectiveRestingHR,
            maxHR: maxHR
        )
        zoneMinutes = zones

        // --- Exercise Duration ---
        let exerciseSamples = allSeries[.exerciseMinutes]?.samples(lastDays: 1) ?? []
        let todayExerciseMinutes = exerciseSamples.reduce(0.0) { $0 + $1.value }

        // --- Workout Duration ---
        let workoutSamples = allSeries[.workoutDuration]?.samples(lastDays: 1) ?? []
        let todayWorkoutMinutes = workoutSamples.reduce(0.0) { $0 + $1.value }

        // --- Steps ---
        let stepSamples = allSeries[.steps]?.samples(lastDays: 1) ?? []
        let todaySteps = stepSamples.reduce(0.0) { $0 + $1.value }

        // --- Distance ---
        let distanceSamples = allSeries[.distanceWalkingRunning]?.samples(lastDays: 1) ?? []
        let todayDistance = distanceSamples.reduce(0.0) { $0 + $1.value }

        // --- Compute Normalized Load ---
        let normalizedLoad = computeNormalizedLoad(
            calories: todayCalories,
            calorieBaseline: hasBaseline ? calorieBaseline : 400.0,
            zoneMinutes: zones,
            exerciseMinutes: todayExerciseMinutes,
            workoutMinutes: todayWorkoutMinutes,
            steps: todaySteps,
            distance: todayDistance
        )

        // --- Logarithmic Strain Score ---
        // strain = 21 * ln(1 + normalizedLoad) / ln(1 + maxExpectedLoad)
        let logNumerator = log(1.0 + normalizedLoad)
        let logDenominator = log(1.0 + Self.maxExpectedLoad)
        currentStrain = min(21.0, max(0.0, 21.0 * logNumerator / logDenominator))

        isReady = true

        // --- Weekly History ---
        computeWeeklyHistory(
            from: allSeries,
            age: age,
            restingHR: effectiveRestingHR,
            maxHR: maxHR,
            calorieBaseline: hasBaseline ? calorieBaseline : 400.0
        )
    }

    // MARK: - Private Helpers

    /// Resolve resting heart rate from parameter, HealthKit, or population default
    private func resolveRestingHR(_ provided: Double?, from allSeries: [HealthMetric: MetricTimeSeries]) -> Double {
        if let provided, provided > 30, provided < 120 {
            return provided
        }
        if let rhSeries = allSeries[.restingHeartRate] {
            let recent = rhSeries.samples(lastDays: 14)
            if recent.count >= 3 {
                return recent.mean(of: \.value)
            }
            if let latest = rhSeries.sortedSamples.last {
                return latest.value
            }
        }
        return 65.0 // Population average fallback
    }

    /// Compute personal calorie baseline from the 28-day rolling average,
    /// excluding the current day to avoid contaminating the baseline with today's partial data.
    private func computeCalorieBaseline(from series: MetricTimeSeries?) -> Double {
        guard let series else { return 400.0 }
        let historicalSamples = series.samples(lastDays: 28)

        // Exclude today's samples
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let pastSamples = historicalSamples.filter { $0.date < todayStart }

        guard pastSamples.count >= 5 else { return 400.0 }

        // Group by day, take daily totals, then average
        var dailyTotals: [Date: Double] = [:]
        for sample in pastSamples {
            let day = calendar.startOfDay(for: sample.date)
            dailyTotals[day, default: 0] += sample.value
        }

        guard !dailyTotals.isEmpty else { return 400.0 }
        let sum = dailyTotals.values.reduce(0, +)
        return sum / Double(dailyTotals.count)
    }

    /// Classify heart rate samples into zone minutes.
    /// Zones are based on percentage of heart rate reserve (Karvonen method):
    ///   Zone % = (HR - restingHR) / (maxHR - restingHR)
    /// Each sample is assumed to represent approximately 1 minute of data
    /// (HealthKit typically provides ~1 sample/min during workouts).
    private func computeZoneMinutes(
        hrSamples: [MetricSample],
        restingHR: Double,
        maxHR: Double
    ) -> [Int: Double] {
        var zones: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        let hrReserve = maxHR - restingHR
        guard hrReserve > 0 else { return zones }

        for sample in hrSamples {
            // Use heart rate reserve method for zone classification
            let intensityPct = (sample.value - restingHR) / hrReserve

            let zone: Int
            switch intensityPct {
            case ..<0.5:  zone = 1  // 50-60% max HR equivalent
            case ..<0.6:  zone = 2  // 60-70%
            case ..<0.7:  zone = 3  // 70-80%
            case ..<0.8:  zone = 4  // 80-90%
            default:      zone = 5  // 90-100%
            }

            // Below zone 1 threshold — negligible strain contribution
            if intensityPct >= 0.4 {
                zones[zone, default: 0] += 1.0
            }
        }

        return zones
    }

    /// Combine all physiological signals into a single normalized load value.
    ///
    /// Load components:
    /// 1. Calorie load: today's calories relative to personal baseline
    /// 2. HR zone load: weighted zone minutes (higher zones contribute exponentially more)
    /// 3. Duration load: total active minutes with diminishing returns
    /// 4. Movement load: minor contribution from steps and distance for non-exercise activity
    private func computeNormalizedLoad(
        calories: Double,
        calorieBaseline: Double,
        zoneMinutes: [Int: Double],
        exerciseMinutes: Double,
        workoutMinutes: Double,
        steps: Double,
        distance: Double
    ) -> Double {
        // 1. Calorie load — normalized to baseline, contributes ~40% of max load
        let calorieRatio = calories / max(calorieBaseline, 100.0)
        let calorieLoad = calorieRatio * 150.0

        // 2. HR zone load — weighted sum with exponential zone multipliers
        //    Contributes ~40% of max load at extreme efforts
        var zoneLoad: Double = 0
        for (zone, minutes) in zoneMinutes {
            let multiplier = Self.zoneMultipliers[zone] ?? 1.0
            zoneLoad += minutes * multiplier
        }

        // 3. Duration load — total exercise/workout time with square-root diminishing returns
        //    Prevents ultra-long low-intensity sessions from dominating
        let totalActiveMinutes = max(exerciseMinutes, workoutMinutes)
        let durationLoad = sqrt(totalActiveMinutes) * 10.0

        // 4. Movement load — minor NEAT contribution from daily movement
        //    Steps and distance contribute modestly for non-exercise days
        let stepsLoad = min(30.0, (steps / 10000.0) * 15.0)
        let distanceLoad = min(20.0, distance * 2.0)  // distance in km
        let movementLoad = (stepsLoad + distanceLoad) * 0.5

        return calorieLoad + zoneLoad + durationLoad + movementLoad
    }

    /// Build rolling 7-day strain history by recomputing strain for each past day.
    private func computeWeeklyHistory(
        from allSeries: [HealthMetric: MetricTimeSeries],
        age: Int,
        restingHR: Double,
        maxHR: Double,
        calorieBaseline: Double
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var history: [(date: Date, strain: Double)] = []

        let hrReserve = maxHR - restingHR
        guard hrReserve > 0 else {
            weeklyStrainHistory = []
            return
        }

        for dayOffset in (1...7).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? today

            // Extract samples for this specific day
            let dayCals = sumSamples(allSeries[.activeCalories], from: targetDate, to: nextDate)
            let dayExercise = sumSamples(allSeries[.exerciseMinutes], from: targetDate, to: nextDate)
            let dayWorkout = sumSamples(allSeries[.workoutDuration], from: targetDate, to: nextDate)
            let daySteps = sumSamples(allSeries[.steps], from: targetDate, to: nextDate)
            let dayDistance = sumSamples(allSeries[.distanceWalkingRunning], from: targetDate, to: nextDate)

            // HR zone distribution for this day
            let dayHRSamples = allSeries[.heartRate]?.samples(from: targetDate, to: nextDate) ?? []
            let dayZones = computeZoneMinutes(hrSamples: dayHRSamples, restingHR: restingHR, maxHR: maxHR)

            let load = computeNormalizedLoad(
                calories: dayCals,
                calorieBaseline: calorieBaseline,
                zoneMinutes: dayZones,
                exerciseMinutes: dayExercise,
                workoutMinutes: dayWorkout,
                steps: daySteps,
                distance: dayDistance
            )

            let logNumerator = log(1.0 + load)
            let logDenominator = log(1.0 + Self.maxExpectedLoad)
            let strain = min(21.0, max(0.0, 21.0 * logNumerator / logDenominator))

            history.append((date: targetDate, strain: strain))
        }

        // Append today
        history.append((date: today, strain: currentStrain))
        weeklyStrainHistory = history
    }

    /// Sum all sample values for a metric within a date range
    private func sumSamples(_ series: MetricTimeSeries?, from start: Date, to end: Date) -> Double {
        guard let series else { return 0 }
        return series.samples(from: start, to: end).reduce(0.0) { $0 + $1.value }
    }
}
