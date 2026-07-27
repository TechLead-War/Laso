import Foundation
import Observation

// MARK: - Age-Adjusted Population Norms

/// Reference tables mapping metric values to the age at which that value
/// would be median. Heuristic — values approximate widely used population
/// norms but no specific source DOIs are linked; treat outputs as
/// informational signals only, not clinical measurements.
/// Each table maps age -> expected median value for that age group.
/// Module internal rather than file private so the reference tables can be tested
/// directly. The clamp at the youngest row silently made every metric report the
/// same age difference in a shipped build, which a test would have caught.
enum VitalityNorms {

    /// VO2 Max norms (mL/kg/min) by age. combined sex average.
    static let vo2Max: [(age: Int, value: Double)] = [
        (20, 46), (25, 45), (30, 43), (35, 41), (40, 39),
        (45, 37), (50, 35), (55, 33), (60, 31), (65, 29),
        (70, 27), (75, 25), (80, 23)
    ]

    /// Resting heart rate norms (bpm) by age. lower is better.
    static let restingHeartRate: [(age: Int, value: Double)] = [
        (20, 63), (25, 64), (30, 65), (35, 66), (40, 67),
        (45, 68), (50, 69), (55, 70), (60, 71), (65, 72),
        (70, 73), (75, 74), (80, 76)
    ]

    /// HRV (SDNN, ms) by age. higher is better.
    static let hrv: [(age: Int, value: Double)] = [
        (20, 62), (25, 58), (30, 54), (35, 50), (40, 46),
        (45, 42), (50, 38), (55, 34), (60, 30), (65, 27),
        (70, 24), (75, 22), (80, 20)
    ]

    /// Sleep efficiency (%) by age. % of time in bed asleep.
    static let sleepEfficiency: [(age: Int, value: Double)] = [
        (20, 92), (25, 91), (30, 90), (35, 89), (40, 88),
        (45, 87), (50, 86), (55, 85), (60, 83), (65, 81),
        (70, 79), (75, 77), (80, 75)
    ]

    /// Deep sleep % of total by age.
    static let deepSleepPercent: [(age: Int, value: Double)] = [
        (20, 22), (25, 20), (30, 18), (35, 17), (40, 16),
        (45, 15), (50, 14), (55, 13), (60, 12), (65, 11),
        (70, 10), (75, 9), (80, 8)
    ]

    /// Walking speed (km/h) by age.
    static let walkingSpeed: [(age: Int, value: Double)] = [
        (20, 5.4), (25, 5.3), (30, 5.2), (35, 5.1), (40, 5.0),
        (45, 4.9), (50, 4.8), (55, 4.7), (60, 4.5), (65, 4.3),
        (70, 4.1), (75, 3.9), (80, 3.6)
    ]

    /// Steps per day norms by age.
    static let steps: [(age: Int, value: Double)] = [
        (20, 10000), (25, 9800), (30, 9500), (35, 9000), (40, 8500),
        (45, 8000), (50, 7500), (55, 7000), (60, 6500), (65, 6000),
        (70, 5500), (75, 5000), (80, 4500)
    ]

    /// Exercise minutes per day norms by age.
    static let exerciseMinutes: [(age: Int, value: Double)] = [
        (20, 45), (25, 42), (30, 40), (35, 38), (40, 35),
        (45, 33), (50, 30), (55, 28), (60, 25), (65, 22),
        (70, 20), (75, 18), (80, 15)
    ]

    /// BMI norms by age. U-shaped relationship; 22-25 is optimal.
    /// For BMI we measure distance from optimal (22.5), so lower delta = younger.
    static let bmiOptimal: Double = 22.5

    /// Body fat % norms by age. combined sex average.
    static let bodyFatPercent: [(age: Int, value: Double)] = [
        (20, 18), (25, 19), (30, 20), (35, 21), (40, 22),
        (45, 23), (50, 24), (55, 25), (60, 26), (65, 27),
        (70, 28), (75, 29), (80, 30)
    ]

    // MARK: - Interpolation

    /// Given a value and a norm table, find the "metric age". the age at
    /// which this value would be the population median.
    /// Uses linear interpolation between reference points.
    ///
    /// - Parameters:
    ///   - value: The user's current metric value.
    ///   - table: Age-value reference table, sorted by age ascending.
    ///   - higherIsBetter: If true, higher values map to younger ages.
    /// - Returns: Interpolated metric age (clamped to 18...95) and whether the
    ///   value is better than the youngest row in the table.
    ///
    /// Values better than the youngest row are clamped to that row's age. We do
    /// not extrapolate past it: there is no reference data below age 20, so any
    /// number we produced there would be invented. The flag lets the UI say the
    /// value is top of range instead of printing a year gap we cannot support.
    /// The old end is left clamped and unflagged on purpose. Stopping at the
    /// oldest row understates how far off the value is, which errs against the
    /// user's favour, while an unflagged young clamp would overstate a benefit.
    static func metricAge(
        value: Double,
        table: [(age: Int, value: Double)],
        higherIsBetter: Bool
    ) -> (age: Int, isBeyondYoungestReference: Bool) {
        guard table.count >= 2 else { return (50, false) }

        // For "higher is better" metrics, the table values decrease with age.
        // For "lower is better" metrics, the table values increase with age.
        // We need to find where the user's value falls in the table.

        // Search direction depends on whether values increase or decrease with age.
        let sortedTable: [(age: Int, value: Double)]
        if higherIsBetter {
            // Values decrease with age; reverse so values ascend for interpolation
            sortedTable = table.reversed()
        } else {
            // Values increase with age; already in ascending value order
            sortedTable = table
        }

        guard let firstEntry = sortedTable.first, let lastEntry = sortedTable.last else { return (50, false) }

        // If value is below the minimum or above the maximum, clamp.
        // After the sort above, the youngest reference row sits at the end for
        // higher-is-better metrics and at the start for lower-is-better ones.
        if value <= firstEntry.value {
            return (firstEntry.age, !higherIsBetter && value < firstEntry.value)
        }
        if value >= lastEntry.value {
            return (lastEntry.age, higherIsBetter && value > lastEntry.value)
        }

        // Find the bracketing pair and interpolate
        for i in 0..<(sortedTable.count - 1) {
            let lower = sortedTable[i]
            let upper = sortedTable[i + 1]

            if value >= lower.value && value <= upper.value {
                let fraction: Double
                let valueDelta = upper.value - lower.value
                if abs(valueDelta) < 0.001 {
                    fraction = 0.5
                } else {
                    fraction = (value - lower.value) / valueDelta
                }
                let interpolatedAge = Double(lower.age) + fraction * Double(upper.age - lower.age)
                return (max(18, min(95, Int(interpolatedAge.rounded()))), false)
            }
        }

        return (50, false) // Fallback
    }
}

// MARK: - Vitality Component

/// A single metric's contribution to the vitality age
struct VitalityComponent: Identifiable {
    let id = UUID()
    let metric: String
    let metricAge: Int
    let currentValue: Double
    let unit: String
    let populationMedian: Double
    /// True when the value beats the youngest row of the reference table, so
    /// `metricAge` is a floor rather than a reading. The UI shows "top of
    /// range" for these instead of a year gap that has no data behind it.
    let isBeyondYoungestReference: Bool
    let healthMetric: HealthMetric?

    /// How many years this component adds (positive) or subtracts (negative) vs chronological age
    func delta(chronologicalAge: Int) -> Int {
        metricAge - chronologicalAge
    }

    /// Actionable suggestion to improve this metric age
    var improvementSuggestion: String {
        guard let hm = healthMetric else { return "" }
        switch hm {
        case .vo2Max:
            return Copy.Vitality.improveVO2Max
        case .restingHeartRate:
            return Copy.Vitality.improveRHR
        case .heartRateVariability:
            return Copy.Vitality.improveHRV
        case .sleepDuration, .sleepDeep:
            return Copy.Vitality.improveSleep
        case .walkingSpeed:
            return Copy.Vitality.improveWalkingSpeed
        case .steps:
            return Copy.Vitality.improveSteps
        case .exerciseMinutes:
            return Copy.Vitality.improveExercise
        case .bmi, .bodyFatPercentage:
            return Copy.Vitality.improveBodyComp
        default:
            return Copy.Vitality.improveDefault
        }
    }
}

enum VitalityPersonalizationStatus: String {
    case buildingProfile = "Building your profile"
    case earlyEstimate = "Early estimate"
    case personalized = "Personalized"
}

// MARK: - VitalityScorer

/// Computes a "Vitality Age" representing how old the user's body is performing,
/// based on key health metrics compared against age-adjusted population norms.
@Observable
final class VitalityScorer {

    // MARK: - Outputs

    /// The computed vitality age (biological performance age)
    private(set) var vitalityAge: Int = 0

    /// The same age before rounding. Only the trend and pace read this; every
    /// screen shows the whole number.
    private(set) var preciseVitalityAge: Double = 0

    /// The user's actual chronological age
    private(set) var chronologicalAge: Int = 0

    /// Difference: positive = older than chronological, negative = younger
    var delta: Int { vitalityAge - chronologicalAge }

    /// Raw biological age from the existing vitality model before confidence ramping.
    private(set) var computedBiologicalAge: Int = 0

    /// 0...1 personalization confidence used to blend chronological and computed age.
    private(set) var personalizationProgress: Double = 0

    /// Human-readable status for trust-aware vitality UI.
    var personalizationStatus: VitalityPersonalizationStatus {
        if personalizationProgress >= 1 { return .personalized }
        if availableDays <= Self.zeroDeltaDaysBeforeRamp || personalizationProgress <= 0 { return .buildingProfile }
        return .earlyEstimate
    }

    /// Pace of aging over the recorded trend window.
    /// < 1.0 = aging slower than calendar time, > 1.0 = aging faster.
    private(set) var paceOfAging: Double = 1.0

    /// False until enough real recorded days exist to quote a pace at all.
    /// Pace is a slope, and a slope off two weeks of integer ages is noise.
    private(set) var hasPaceEstimate: Bool = false

    /// Per-metric breakdown of contributing ages
    private(set) var componentAges: [VitalityComponent] = []

    /// Whether enough data exists to compute vitality age
    private(set) var isReady: Bool = false

    /// Vitality age history for charting, oldest first. Unrounded, so the line
    /// moves with the person instead of stepping a whole year at a time.
    private(set) var history: [(date: Date, age: Double)] = []

    // MARK: - Weights

    /// Metric contribution weights. sum to 1.0
    private static let weights: [(metric: VitalityMetricKey, weight: Double)] = [
        (.vo2Max, 0.25),
        (.restingHeartRate, 0.15),
        (.hrv, 0.20),
        (.sleepEfficiency, 0.08),
        (.deepSleepPercent, 0.07),
        (.walkingSpeed, 0.10),
        (.steps, 0.05),
        (.exerciseMinutes, 0.05),
        (.bodyComposition, 0.05)
    ]

    private enum VitalityMetricKey: String {
        case vo2Max, restingHeartRate, hrv
        case sleepEfficiency, deepSleepPercent
        case walkingSpeed, steps, exerciseMinutes
        case bodyComposition
    }

    // MARK: - Minimum Data Requirement

    /// Full personalization target for vitality age confidence.
    static let minimumDaysRequired = 30

    /// Days held at chronological age before allowing vitality divergence.
    private static let zeroDeltaDaysBeforeRamp = 7

    // MARK: - Trend Window

    /// How far back the vitality age trend looks for recorded days.
    static let trendWindowDays = 90

    /// Fewest recorded days before the trend chart is worth drawing.
    static let minimumTrendDays = 7

    /// Fewest recorded days before a pace of aging is quoted. A slope fitted to
    /// two weeks of whole-year ages is dominated by rounding, not by biology.
    static let minimumPaceDays = 30

    /// Smoothing applied before the pace slope is fitted. Vitality age is a
    /// whole number, so day-to-day it steps by 1 year; without smoothing that
    /// step alone reads as a pace of several years per year.
    private static let paceSmoothingWindowDays = 7

    /// Outlier guard on the reported pace, not an expected operating range.
    private static let paceLowerBound: Double = 0.5
    private static let paceUpperBound: Double = 2.0

    private static let secondsPerYear: Double = 365.25 * 24 * 60 * 60

    /// Days of data available at last compute. 0 means no data yet.
    private(set) var availableDays: Int = 0

    /// Whether vitality age is fully personalized for presentation.
    var isFullyMature: Bool { personalizationProgress >= 1 }

    // MARK: - Snapshot Persistence

    // Hot-path caches: avoid per-call allocations for the
    // snapshot save/restore round trip and any calendar component reads below.
    private static let jsonEncoder: JSONEncoder = JSONEncoder()
    private static let jsonDecoder: JSONDecoder = JSONDecoder()

    /// UserDefaults key for the last successfully computed vitality snapshot.
    /// Restored in `init()` so the first render after launch shows the most
    /// recent known values instead of zeros while async refresh is in flight.
    /// Bumped to v2 to discard any v1 snapshots that may have stored degraded
    /// (no-data) zeros from earlier builds.
    private static let snapshotKey = "VitalityScorer.snapshot.v2"

    private struct Snapshot: Codable {
        var vitalityAge: Int
        var chronologicalAge: Int
        var personalizationProgress: Double
        var availableDays: Int
    }

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
            let snap = try? Self.jsonDecoder.decode(Snapshot.self, from: data)
        else { return }
        vitalityAge = snap.vitalityAge
        chronologicalAge = snap.chronologicalAge
        computedBiologicalAge = snap.vitalityAge
        personalizationProgress = snap.personalizationProgress
        availableDays = snap.availableDays
        isReady = true
    }

    private func saveSnapshot() {
        // Guard against persisting degraded values. Without a real
        // chronological age and a non-zero vitality age, restoring this
        // snapshot would just paint zeros on the next launch.
        guard chronologicalAge > 0, vitalityAge > 0 else { return }
        let snap = Snapshot(
            vitalityAge: vitalityAge,
            chronologicalAge: chronologicalAge,
            personalizationProgress: personalizationProgress,
            availableDays: availableDays
        )
        if let data = try? Self.jsonEncoder.encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    // MARK: - Compute

    /// Compute vitality age from health metric time series.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store (used for historical trend computation).
    ///   - chronologicalAge: The user's actual age in years.
    ///   - timeSeries: Fresh in-memory time series from HealthKitManager.
    func compute(from store: HealthDataStore, chronologicalAge: Int, timeSeries: [HealthMetric: MetricTimeSeries]? = nil) {
        self.chronologicalAge = chronologicalAge
        // Defensive: if the caller passed an empty in-memory dictionary
        // (HealthKit fetch silently dropped keys, or the dashboard called
        // compute before sync populated anything), fall back to the persisted
        // store. Otherwise availableDays ends up 0 even when years of watch
        // data exist on disk.
        let allSeries: [HealthMetric: MetricTimeSeries]
        if let timeSeries, !timeSeries.isEmpty {
            allSeries = timeSeries
        } else {
            allSeries = MainActor.assumeIsolated { store.loadAllTimeSeries() }
        }

        availableDays = usableDaysForPersonalization(from: allSeries)
        personalizationProgress = personalizationProgress(for: availableDays)
        computedBiologicalAge = chronologicalAge
        // Always mark as ready. the orb is always shown.
        // With no data, vitality age defaults to chronological age.

        var components: [VitalityComponent] = []
        var weightedAgeSum: Double = 0
        var totalWeight: Double = 0

        // --- VO2 Max ---
        if let series = allSeries[.vo2Max],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 30) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.vo2Max, higherIsBetter: true)
            let w = Self.weightFor(.vo2Max)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.vo2Max)
            components.append(VitalityComponent(
                metric: "VO2 Max", metricAge: norm.age,
                currentValue: avg, unit: "mL/kg/min",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .vo2Max
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- Resting Heart Rate ---
        if let series = allSeries[.restingHeartRate],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 14) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.restingHeartRate, higherIsBetter: false)
            let w = Self.weightFor(.restingHeartRate)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.restingHeartRate)
            components.append(VitalityComponent(
                metric: "Resting HR", metricAge: norm.age,
                currentValue: avg, unit: "bpm",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .restingHeartRate
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- HRV ---
        if let series = allSeries[.heartRateVariability],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 14) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.hrv, higherIsBetter: true)
            let w = Self.weightFor(.hrv)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.hrv)
            components.append(VitalityComponent(
                metric: "HRV", metricAge: norm.age,
                currentValue: avg, unit: "ms",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .heartRateVariability
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- Sleep Efficiency (computed from duration and awake time) ---
        if let sleepSeries = allSeries[.sleepDuration],
           !sleepSeries.isStale(thresholdDays: 2),
           let awakeSeries = allSeries[.sleepAwake] {
            let recentSleep = sleepSeries.samples(lastDays: 14)
            let recentAwake = awakeSeries.samples(lastDays: 14)
            if recentSleep.count >= 7 && recentAwake.count >= 7 {
                let avgSleep = recentSleep.mean(of: \.value)
                let avgAwake = recentAwake.mean(of: \.value)
                let totalInBed = avgSleep + avgAwake
                if totalInBed > 0 {
                    let efficiency = (avgSleep / totalInBed) * 100.0
                    let norm = VitalityNorms.metricAge(value: efficiency, table: VitalityNorms.sleepEfficiency, higherIsBetter: true)
                    let w = Self.weightFor(.sleepEfficiency)
                    let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.sleepEfficiency)
                    components.append(VitalityComponent(
                        metric: "Sleep Efficiency", metricAge: norm.age,
                        currentValue: efficiency, unit: "%",
                        populationMedian: median,
                        isBeyondYoungestReference: norm.isBeyondYoungestReference,
                        healthMetric: .sleepDuration
                    ))
                    weightedAgeSum += Double(norm.age) * w
                    totalWeight += w
                }
            }
        }

        // --- Deep Sleep % ---
        if let deepSeries = allSeries[.sleepDeep],
           !deepSeries.isStale(thresholdDays: 2),
           let sleepSeries = allSeries[.sleepDuration] {
            let recentDeep = deepSeries.samples(lastDays: 14)
            let recentSleep = sleepSeries.samples(lastDays: 14)
            if recentDeep.count >= 7 && recentSleep.count >= 7 {
                let avgDeep = recentDeep.mean(of: \.value)
                let avgTotal = recentSleep.mean(of: \.value)
                if avgTotal > 0 {
                    let deepPct = (avgDeep / avgTotal) * 100.0
                    let norm = VitalityNorms.metricAge(value: deepPct, table: VitalityNorms.deepSleepPercent, higherIsBetter: true)
                    let w = Self.weightFor(.deepSleepPercent)
                    let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.deepSleepPercent)
                    components.append(VitalityComponent(
                        metric: "Deep Sleep", metricAge: norm.age,
                        currentValue: deepPct, unit: "%",
                        populationMedian: median,
                        isBeyondYoungestReference: norm.isBeyondYoungestReference,
                        healthMetric: .sleepDeep
                    ))
                    weightedAgeSum += Double(norm.age) * w
                    totalWeight += w
                }
            }
        }

        // --- Walking Speed ---
        if let series = allSeries[.walkingSpeed],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 30) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.walkingSpeed, higherIsBetter: true)
            let w = Self.weightFor(.walkingSpeed)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.walkingSpeed)
            components.append(VitalityComponent(
                metric: "Walking Speed", metricAge: norm.age,
                currentValue: avg, unit: "km/h",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .walkingSpeed
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- Steps ---
        if let series = allSeries[.steps],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 14) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.steps, higherIsBetter: true)
            let w = Self.weightFor(.steps)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.steps)
            components.append(VitalityComponent(
                metric: "Daily Steps", metricAge: norm.age,
                currentValue: avg, unit: "steps",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .steps
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- Exercise Minutes ---
        if let series = allSeries[.exerciseMinutes],
           !series.isStale(thresholdDays: 2),
           let avg = recentAverage(series, days: 14) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.exerciseMinutes, higherIsBetter: true)
            let w = Self.weightFor(.exerciseMinutes)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.exerciseMinutes)
            components.append(VitalityComponent(
                metric: "Exercise", metricAge: norm.age,
                currentValue: avg, unit: "min/day",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .exerciseMinutes
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        }

        // --- Body Composition (BMI or Body Fat %) ---
        if let bfSeries = allSeries[.bodyFatPercentage],
           !bfSeries.isStale(thresholdDays: 30), // Body comp doesn't change fast
           let avg = recentAverage(bfSeries, days: 30) {
            let norm = VitalityNorms.metricAge(value: avg, table: VitalityNorms.bodyFatPercent, higherIsBetter: false)
            let w = Self.weightFor(.bodyComposition)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.bodyFatPercent)
            components.append(VitalityComponent(
                metric: "Body Fat", metricAge: norm.age,
                currentValue: avg, unit: "%",
                populationMedian: median,
                isBeyondYoungestReference: norm.isBeyondYoungestReference,
                healthMetric: .bodyFatPercentage
            ))
            weightedAgeSum += Double(norm.age) * w
            totalWeight += w
        } else if let bmiSeries = allSeries[.bmi],
                  !bmiSeries.isStale(thresholdDays: 30),
                  let avg = recentAverage(bmiSeries, days: 30) {
            // Fall back to BMI if no body fat data
            // Map BMI deviation from optimal to an age offset
            let deviation = abs(avg - VitalityNorms.bmiOptimal)
            // Each point away from 22.5 adds ~1.5 years
            let ageOffset = deviation * 1.5
            let bmiAge = max(18, min(95, Int(Double(chronologicalAge) + ageOffset)))
            let w = Self.weightFor(.bodyComposition)
            components.append(VitalityComponent(
                metric: "BMI", metricAge: bmiAge,
                currentValue: avg, unit: "",
                populationMedian: VitalityNorms.bmiOptimal,
                // BMI age comes from distance to the optimal point, not a norm
                // table, so there is no youngest reference row to clamp at.
                isBeyondYoungestReference: false,
                healthMetric: .bmi
            ))
            weightedAgeSum += Double(bmiAge) * w
            totalWeight += w
        }

        // If fewer than 2 metrics available, default to chronological age.
        // Do NOT save a snapshot here — this is a degraded compute path with
        // no real personalization. Saving would overwrite the last known good
        // snapshot with a placeholder, so first-render after launch would
        // show chronological age (or 0) instead of the real vitality age.
        if components.count < 2 || totalWeight <= 0 {
            computedBiologicalAge = chronologicalAge
            vitalityAge = chronologicalAge
            personalizationProgress = 0
            componentAges = components.sorted { $0.metricAge > $1.metricAge }
            isReady = true
            history = []
            paceOfAging = 1.0
            hasPaceEstimate = false
            return
        }

        // Normalize weights if not all metrics are available
        let computedAge = max(18, min(95, weightedAgeSum / totalWeight))
        computedBiologicalAge = Int(computedAge.rounded())
        preciseVitalityAge = blendedBiologicalAge(
            chronologicalAge: chronologicalAge,
            computedBiologicalAge: computedAge,
            progress: personalizationProgress
        )
        vitalityAge = Int(preciseVitalityAge.rounded())
        componentAges = components.sorted { $0.metricAge > $1.metricAge }
        isReady = true

        // Compute historical trend and pace of aging
        computeHistory(from: store)
        computePaceOfAging()
        saveSnapshot()
    }

    // MARK: - Top Improvement Opportunities

    /// The 2-3 metrics with the oldest metric ages (biggest drag on vitality age)
    var topImprovementOpportunities: [VitalityComponent] {
        let sorted = componentAges.sorted { $0.metricAge > $1.metricAge }
        return Array(sorted.prefix(3).filter { $0.delta(chronologicalAge: chronologicalAge) > 0 })
    }

    // MARK: - Pace Label

    /// Human-readable pace of aging label
    var paceLabel: String {
        guard hasPaceEstimate else { return Copy.Vitality.paceBuilding }
        if paceOfAging < 0.85 { return Copy.Vitality.paceImproving }
        if paceOfAging <= 1.15 { return Copy.Vitality.paceStable }
        return Copy.Vitality.paceDeclining
    }

    /// Calendar days the recorded history actually spans, for honest chart
    /// titles. A two week old install must not be labelled a 90 day trend.
    var historySpanDays: Int {
        guard let first = history.first?.date, let last = history.last?.date else { return 0 }
        return max(1, (Date.cal.dateComponents([.day], from: first, to: last).day ?? 0) + 1)
    }

    // MARK: - Private Helpers

    /// Metrics used in vitality age computation and their minimum sample count
    /// before we consider their day count usable for personalization ramping.
    /// Thresholds are 1 because the data pipeline stores daily aggregates —
    /// each StoredDailySample already represents a full day of data.
    private static let usableDataSampleThresholds: [HealthMetric: Int] = [
        .vo2Max: 1,
        .restingHeartRate: 1,
        .heartRateVariability: 1,
        .sleepDuration: 1,
        .sleepAwake: 1,
        .sleepDeep: 1,
        .walkingSpeed: 1,
        .steps: 1,
        .exerciseMinutes: 1,
        .bodyFatPercentage: 1,
        .bmi: 1
    ]

    /// Best-effort "usable days of health data" for vitality personalization.
    /// Uses existing per-metric `daysOfData` and only counts metrics with enough samples.
    private func usableDaysForPersonalization(from allSeries: [HealthMetric: MetricTimeSeries]) -> Int {
        var maxUsableDays = 0
        for (metric, minSamples) in Self.usableDataSampleThresholds {
            guard let series = allSeries[metric], series.totalDataPoints >= minSamples else { continue }
            maxUsableDays = max(maxUsableDays, series.daysOfData)
        }
        // Defensive: if none of the curated metrics matched (e.g. user has
        // bodyFat/exerciseMinutes missing but plenty of HR/sleep history),
        // widen the lens to ANY metric with samples so we don't lock the UI
        // into "Building your profile" for users who clearly have history.
        if maxUsableDays == 0 {
            for (_, series) in allSeries where series.totalDataPoints > 0 {
                maxUsableDays = max(maxUsableDays, series.daysOfData)
            }
        }
        return maxUsableDays
    }

    /// Personalization stays at 0 for the first 7 usable days,
    /// then ramps linearly to 1.0 by day 30.
    private func personalizationProgress(for usableDays: Int) -> Double {
        if usableDays <= Self.zeroDeltaDaysBeforeRamp { return 0 }
        if usableDays >= Self.minimumDaysRequired { return 1 }

        let rampDays = Self.minimumDaysRequired - Self.zeroDeltaDaysBeforeRamp
        let progressedDays = usableDays - Self.zeroDeltaDaysBeforeRamp
        return max(0, min(1, Double(progressedDays) / Double(rampDays)))
    }

    /// Blend from chronological age to computed biological age based on personalization progress.
    /// Kept unrounded. Rounding here is what made pace of aging unmeasurable:
    /// over a quarter, real drift is a fraction of a year, and a whole number
    /// cannot hold a fraction, so the trend could only ever sit flat or jump.
    private func blendedBiologicalAge(
        chronologicalAge: Int,
        computedBiologicalAge: Double,
        progress: Double
    ) -> Double {
        let rawDelta = computedBiologicalAge - Double(chronologicalAge)
        let blended = Double(chronologicalAge) + (rawDelta * max(0, min(1, progress)))
        return max(18, min(95, blended))
    }

    /// Get the average value from the most recent N days, requiring at least 3 data points
    private func recentAverage(_ series: MetricTimeSeries, days: Int) -> Double? {
        let recent = series.samples(lastDays: days)
        guard recent.count >= 3 else { return nil }
        return recent.mean(of: \.value)
    }

    /// Look up the weight for a metric key
    private static func weightFor(_ key: VitalityMetricKey) -> Double {
        weights.first { $0.metric == key }?.weight ?? 0
    }

    // MARK: - Onboarding estimate (store-free)

    /// A single real metric in the onboarding estimate.
    struct OnboardingMetric: Identifiable {
        let id = UUID()
        let name: String
        let valueLabel: String
        /// 0 = worse than peers, 1 = better. Drives the marker position.
        let goodness: Double
        /// Years this metric adds (+) or removes (-) vs the user's real age.
        let delta: Int
    }

    /// Deltas inside this band read as "same as your age": ±1 year is within
    /// the estimate's noise floor, so only ±2+ is claimed as younger/older.
    static let onboardingHeadlineDeltaBandYears = 2

    /// Store-free Vitality Age estimate for the onboarding reveal, where only
    /// scalar averages exist (resting HR, HRV). Reuses the same population norms
    /// and weights as the full engine, renormalised over the metrics provided.
    /// Returns the chronological age and no metrics when nothing is available.
    static func onboardingEstimate(
        chronologicalAge: Int,
        restingHR: Double?,
        hrvMs: Double?,
        steps: Double?,
        vo2Max: Double?,
        exerciseMinutes: Double?,
        walkingSpeedKmh: Double?
    ) -> (vitalityAge: Int, metrics: [OnboardingMetric]) {
        var weightedSum = 0.0
        var totalWeight = 0.0
        var out: [OnboardingMetric] = []

        func add(_ value: Double?, name: String, label: (Double) -> String,
                 table: [(age: Int, value: Double)], higherIsBetter: Bool,
                 key: VitalityMetricKey, goodness: (Double) -> Double) {
            guard let v = value, v > 0 else { return }
            let norm = VitalityNorms.metricAge(value: v, table: table, higherIsBetter: higherIsBetter)
            let w = weightFor(key)
            weightedSum += Double(norm.age) * w
            totalWeight += w
            out.append(OnboardingMetric(name: name, valueLabel: label(v),
                                        goodness: min(1, max(0, goodness(v))),
                                        delta: norm.age - chronologicalAge))
        }

        add(restingHR, name: "RESTING HR", label: { "\(Int($0.rounded())) bpm" },
            table: VitalityNorms.restingHeartRate, higherIsBetter: false,
            key: .restingHeartRate, goodness: { (100 - $0) / 60 })
        add(hrvMs, name: "HRV", label: { "\(Int($0.rounded())) ms" },
            table: VitalityNorms.hrv, higherIsBetter: true,
            key: .hrv, goodness: { ($0 - 10) / 90 })
        add(steps, name: "STEPS", label: { "\(Int($0.rounded())) steps" },
            table: VitalityNorms.steps, higherIsBetter: true,
            key: .steps, goodness: { $0 / 12000 })
        add(vo2Max, name: "VO2 MAX", label: { "\(Int($0.rounded())) mL" },
            table: VitalityNorms.vo2Max, higherIsBetter: true,
            key: .vo2Max, goodness: { ($0 - 20) / 40 })
        add(exerciseMinutes, name: "EXERCISE", label: { "\(Int($0.rounded())) min" },
            table: VitalityNorms.exerciseMinutes, higherIsBetter: true,
            key: .exerciseMinutes, goodness: { $0 / 45 })
        add(walkingSpeedKmh, name: "WALK SPEED", label: { String(format: "%.1f km/h", $0) },
            table: VitalityNorms.walkingSpeed, higherIsBetter: true,
            key: .walkingSpeed, goodness: { ($0 - 3) / 3 })

        guard totalWeight > 0 else { return (chronologicalAge, []) }
        return (Int((weightedSum / totalWeight).rounded()), out)
    }

    /// Interpolate the population median for a given age from a reference table
    private func interpolateMedian(age: Int, table: [(age: Int, value: Double)]) -> Double {
        guard table.count >= 2, let firstEntry = table.first, let lastEntry = table.last else { return 0 }

        if age <= firstEntry.age { return firstEntry.value }
        if age >= lastEntry.age { return lastEntry.value }

        for i in 0..<(table.count - 1) {
            if age >= table[i].age && age <= table[i + 1].age {
                let fraction = Double(age - table[i].age) / Double(table[i + 1].age - table[i].age)
                return table[i].value + fraction * (table[i + 1].value - table[i].value)
            }
        }

        return table[table.count / 2].value
    }

    /// Record today's vitality age, then read back the days actually recorded.
    ///
    /// This used to reshape the overall health score curve into a fake age curve
    /// anchored on today. That had two failures the chart made visible: it was
    /// the score, not vitality age, and because it re-anchored on every compute
    /// the past redrew itself whenever today moved. Only real recorded days now.
    private func computeHistory(from store: HealthDataStore) {
        MainActor.assumeIsolated {
            store.saveVitalityAge(preciseVitalityAge)
            let recorded = store.loadVitalityAgeHistory(days: Self.trendWindowDays)
            history = recorded.count >= Self.minimumTrendDays ? recorded : []
        }
    }

    /// Pace of aging: how many years of vitality age accrue per calendar year.
    /// 1.0 tracks the calendar, below 1.0 is aging slower, above is faster.
    ///
    /// Chronological age is a constant across this window, so the slope of
    /// vitality age is the slope of the gap between them, which is why the
    /// fitted slope is offset by 1.
    private func computePaceOfAging() {
        if let pace = Self.pace(from: history) {
            paceOfAging = pace
            hasPaceEstimate = true
        } else {
            paceOfAging = 1.0
            hasPaceEstimate = false
        }
    }

    /// Returns nil when the history is too short to fit a slope worth showing.
    static func pace(from history: [(date: Date, age: Double)]) -> Double? {
        guard history.count >= minimumPaceDays else { return nil }

        let smoothed = history.map(\.age).movingAverage(window: paceSmoothingWindowDays)
        // `movingAverage` labels each window by its last day, so the dates that
        // line up with it are the trailing ones.
        let dates = history.map(\.date).suffix(smoothed.count)
        guard smoothed.count >= 2, let firstDate = dates.first else { return nil }

        let elapsedYears = dates.map { $0.timeIntervalSince(firstDate) / secondsPerYear }
        let (slope, _) = [Double].linearRegression(x: elapsedYears, y: smoothed)
        guard slope.isFinite else { return nil }

        return max(paceLowerBound, min(paceUpperBound, slope + 1.0))
    }
}
