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
        // Bucket boundaries are sourced from `StrainScorerConfig` and must
        // stay in sync with the named constants there.
        if strain < StrainScorerConfig.lowUpperExclusive {
            self = .low
        } else if strain < StrainScorerConfig.lightUpperExclusive {
            self = .light
        } else if strain < StrainScorerConfig.moderateUpperExclusive {
            self = .moderate
        } else if strain < StrainScorerConfig.highUpperExclusive {
            self = .high
        } else if strain < StrainScorerConfig.overreachingUpperExclusive {
            self = .overreaching
        } else {
            self = .allOut
        }
    }

    var displayName: String {
        switch self {
        case .low:          return Copy.Strain.strainLevelLow
        case .light:        return Copy.Strain.strainLevelLight
        case .moderate:     return Copy.Strain.strainLevelModerate
        case .high:         return Copy.Strain.strainLevelHigh
        case .overreaching: return Copy.Strain.strainLevelPeak
        case .allOut:       return Copy.Strain.strainLevelAllOut
        }
    }

    var color: Color {
        switch self {
        case .low:          return AppColour.info
        case .light:        return AppColour.scoreOptimal
        case .moderate:     return AppColour.scoreFair
        case .high:         return AppColour.scorePoor
        case .overreaching: return AppColour.scorePoor
        case .allOut:       return AppColour.scorePoor
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

    /// Longer strain history for the trend card. Persisted days only: the
    /// per-day recompute the weekly chart falls back on is far too expensive
    /// to run across a quarter, and a guessed day does not belong in a trend.
    private(set) var trendStrainHistory: [(date: Date, strain: Double)] = []

    /// Human-readable label for the current strain
    var strainLabel: String { strainLevel.displayName }

    // MARK: - Constants

    /// The maximum expected physiological load used to normalize the logarithmic scale.
    private static let maxExpectedLoad: Double = StrainScorerConfig.maxExpectedLoad

    /// Minimum days of calorie data required before computing strain.
    private static let minimumDaysForBaseline: Int = StrainScorerConfig.minimumDaysForBaseline

    /// HR zone multipliers. higher zones contribute disproportionately more strain.
    private static let zoneMultipliers: [Int: Double] = StrainScorerConfig.zoneMultipliers

    /// How far back the trend card looks for persisted strain days.
    private static let trendLookbackDays = 90

    // Hot-path caches: avoid per-compute allocations.
    // StrainScorer.compute runs on every Dashboard refresh; both the calendar
    // and JSON coders are cheap to instantiate but allocating per call adds up
    // over thousands of refreshes.
    private static let jsonEncoder: JSONEncoder = JSONEncoder()
    private static let jsonDecoder: JSONDecoder = JSONDecoder()

    // MARK: - Snapshot Persistence

    /// UserDefaults key for the last successfully computed strain snapshot.
    /// Restored in `init()` so the first render after launch shows the most
    /// recent known strain instead of 0.0/Low while async refresh is in flight.
    /// Bumped to v2 to discard any v1 snapshots that may have stored degraded
    /// (no-data) zeros from earlier builds.
    private static let snapshotKey = "StrainScorer.snapshot.v2"

    private struct Snapshot: Codable {
        var currentStrain: Double
        var todayCalories: Double
        var savedAt: Date
    }

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
            let snap = try? Self.jsonDecoder.decode(Snapshot.self, from: data)
        else { return }
        // Only restore if the snapshot is from today; strain is a daily metric
        // and showing yesterday's value with today's date would mislead.
        if Date.cal.isDateInToday(snap.savedAt) {
            currentStrain = snap.currentStrain
            todayCalories = snap.todayCalories
            isReady = true
        }
    }

    private func saveSnapshot() {
        // Guard against persisting degraded values. If neither calories nor
        // strain came back from compute, the input data was empty; saving 0.0
        // here would just paint zeros on the next launch and bury the last
        // real snapshot.
        guard todayCalories > 0 || currentStrain > 0 else { return }
        let snap = Snapshot(
            currentStrain: currentStrain,
            todayCalories: todayCalories,
            savedAt: Date()
        )
        if let data = try? Self.jsonEncoder.encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    // MARK: - Compute

    /// Compute strain score from HealthKit data.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store containing metric time series.
    ///   - age: The user's age in years (used to estimate max heart rate).
    ///   - restingHR: Optional resting heart rate in bpm. If nil, falls back to
    ///     the most recent resting HR from HealthKit data.
    ///   - todayHRSamples: Raw per-sample heart rate data for today. The sync pipeline
    ///     stores daily averages, which loses per-minute granularity needed for HR zone
    ///     classification. Pass raw samples from HealthKit for accurate zone computation.
    @MainActor
    func compute(from store: HealthDataStore, age: Int, restingHR: Double?, todayHRSamples: [MetricSample] = [], timeSeries: [HealthMetric: MetricTimeSeries]? = nil) {
        // Prefer in-memory time series from HealthKitManager (freshest data)
        // over re-reading from SwiftData (may lag behind). Defensive: an empty
        // dictionary (HealthKit fetch silently dropped keys, or compute fired
        // before sync populated anything) is treated the same as nil so we
        // don't render an empty Strain screen when the persisted store has
        // years of workout/HR history.
        let allSeries: [HealthMetric: MetricTimeSeries]
        if let timeSeries, !timeSeries.isEmpty {
            allSeries = timeSeries
        } else {
            allSeries = store.loadAllTimeSeries()
        }

        // Resolve resting heart rate: parameter > HealthKit > population default
        let effectiveRestingHR = resolveRestingHR(restingHR, from: allSeries)
        let maxHR = 220.0 - Double(max(1, min(age, 150)))
        let validHRRange = maxHR > effectiveRestingHR

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
        // Prefer raw per-sample HR for accurate zone classification;
        // fall back to daily-aggregated stored data if raw samples unavailable.
        // Only compute if we have a valid HR range; otherwise zones stay at zero.
        var zones: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        if validHRRange {
            let hrSamples = !todayHRSamples.isEmpty
                ? todayHRSamples
                : (allSeries[.heartRate]?.samples(lastDays: 1) ?? [])
            zones = computeZoneMinutes(
                hrSamples: hrSamples,
                restingHR: effectiveRestingHR,
                maxHR: maxHR
            )
        }
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
        saveSnapshot()

        // Persist today's computed strain so historical displays can rely on stored snapshots.
        store.saveDailyStrain(
            date: Date(),
            strain: currentStrain,
            level: strainLevel.rawValue,
            hrZoneMinutes: (1...5).map { zones[$0] ?? 0.0 }
        )

        // --- Weekly History ---
        computeWeeklyHistory(
            from: allSeries,
            store: store,
            restingHR: effectiveRestingHR,
            maxHR: maxHR,
            calorieBaseline: hasBaseline ? calorieBaseline : 400.0
        )
    }

    // MARK: - Private Helpers

    /// Resolve resting heart rate from parameter, HealthKit, or population default.
    /// Always clamps to physiological range (30–120 bpm) to prevent bad sensor data
    /// from invalidating the HR reserve calculation.
    private func resolveRestingHR(_ provided: Double?, from allSeries: [HealthMetric: MetricTimeSeries]) -> Double {
        if let provided, provided > 30, provided < 120 {
            return provided
        }
        if let rhSeries = allSeries[.restingHeartRate] {
            let recent = rhSeries.samples(lastDays: 14)
            if recent.count >= 3 {
                let mean = recent.mean(of: \.value)
                if mean > 30, mean < 120 { return mean }
            }
            if let latest = rhSeries.sortedSamples.last?.value, latest > 30, latest < 120 {
                return latest
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
        let todayStart = Date.cal.startOfDay(for: Date())
        let pastSamples = historicalSamples.filter { $0.date < todayStart }

        guard pastSamples.count >= 5 else { return 400.0 }

        // Group by day, take daily totals, then average
        var dailyTotals: [Date: Double] = [:]
        for sample in pastSamples {
            let day = Date.cal.startOfDay(for: sample.date)
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

            // Below zone 1 threshold. negligible strain contribution
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
        // 1. Calorie load. normalized to baseline, contributes ~40% of max load
        let calorieRatio = calories / max(calorieBaseline, 100.0)
        let calorieLoad = calorieRatio * 150.0

        // 2. HR zone load. weighted sum with exponential zone multipliers
        //    Contributes ~40% of max load at extreme efforts
        var zoneLoad: Double = 0
        for (zone, minutes) in zoneMinutes {
            let multiplier = Self.zoneMultipliers[zone] ?? 1.0
            zoneLoad += minutes * multiplier
        }

        // 3. Duration load. total exercise/workout time with square-root diminishing returns
        //    Prevents ultra-long low-intensity sessions from dominating
        let totalActiveMinutes = max(exerciseMinutes, workoutMinutes)
        let durationLoad = sqrt(totalActiveMinutes) * 10.0

        // 4. Movement load. minor NEAT contribution from daily movement
        //    Steps and distance contribute modestly for non-exercise days
        let stepsLoad = min(30.0, (steps / 10000.0) * 15.0)
        let distanceLoad = min(20.0, distance * 2.0)  // distance in km
        let movementLoad = (stepsLoad + distanceLoad) * 0.5

        return calorieLoad + zoneLoad + durationLoad + movementLoad
    }

    /// Build rolling strain history from persisted snapshots, with day-level recompute fallback for missing dates.
    @MainActor
    private func computeWeeklyHistory(
        from allSeries: [HealthMetric: MetricTimeSeries],
        store: HealthDataStore,
        restingHR: Double,
        maxHR: Double,
        calorieBaseline: Double
    ) {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let lookbackDays = 7
        var history: [(date: Date, strain: Double)] = []

        // One fetch covers both: the weekly loop only ever looks up the last
        // seven days, so the older entries in this map are simply never read.
        trendStrainHistory = store.loadDailyStrainHistory(lookbackDays: Self.trendLookbackDays)
            .map { (date: $0.date, strain: $0.strain) }

        var persistedByDate: [Date: Double] = [:]
        for entry in trendStrainHistory {
            persistedByDate[calendar.startOfDay(for: entry.date)] = entry.strain
        }

        // Half-open: offsets 0 through lookbackDays - 1 cover today plus the six
        // days before it. An inclusive range here yields eight columns in a
        // seven day chart.
        for dayOffset in (0..<lookbackDays).reversed() {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            if let persisted = persistedByDate[targetDate] {
                history.append((date: targetDate, strain: persisted))
                continue
            }

            if dayOffset == 0 {
                history.append((date: targetDate, strain: currentStrain))
                continue
            }

            let fallbackStrain = computeFallbackStrainForDay(
                targetDate,
                allSeries: allSeries,
                restingHR: restingHR,
                maxHR: maxHR,
                calorieBaseline: calorieBaseline
            )
            history.append((date: targetDate, strain: fallbackStrain))
        }

        weeklyStrainHistory = history
    }

    /// Recompute strain for a specific day when a persisted record is unavailable.
    private func computeFallbackStrainForDay(
        _ targetDate: Date,
        allSeries: [HealthMetric: MetricTimeSeries],
        restingHR: Double,
        maxHR: Double,
        calorieBaseline: Double
    ) -> Double {
        let nextDate = Date.cal.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate

        let dayCals = sumSamples(allSeries[.activeCalories], from: targetDate, to: nextDate)
        let dayExercise = sumSamples(allSeries[.exerciseMinutes], from: targetDate, to: nextDate)
        let dayWorkout = sumSamples(allSeries[.workoutDuration], from: targetDate, to: nextDate)
        let daySteps = sumSamples(allSeries[.steps], from: targetDate, to: nextDate)
        let dayDistance = sumSamples(allSeries[.distanceWalkingRunning], from: targetDate, to: nextDate)
        var dayZones: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        if maxHR > restingHR {
            let dayHRSamples = allSeries[.heartRate]?.samples(from: targetDate, to: nextDate) ?? []
            dayZones = computeZoneMinutes(hrSamples: dayHRSamples, restingHR: restingHR, maxHR: maxHR)
        }

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
        return min(21.0, max(0.0, 21.0 * logNumerator / logDenominator))
    }

    /// Sum all sample values for a metric within a date range
    private func sumSamples(_ series: MetricTimeSeries?, from start: Date, to end: Date) -> Double {
        guard let series else { return 0 }
        return series.samples(from: start, to: end).reduce(0.0) { $0 + $1.value }
    }
}
