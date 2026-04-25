import Foundation
import Observation

// MARK: - Age-Adjusted Population Norms

/// Reference tables mapping metric values to the age at which that value
/// would be median. Sourced from ACSM, AHA, and WHO population studies.
/// Each table maps age -> expected median value for that age group.
private enum VitalityNorms {

    /// VO2 Max norms (mL/kg/min) by age. combined sex average.
    /// Sources: ACSM Guidelines for Exercise Testing (11th ed.)
    static let vo2Max: [(age: Int, value: Double)] = [
        (20, 46), (25, 45), (30, 43), (35, 41), (40, 39),
        (45, 37), (50, 35), (55, 33), (60, 31), (65, 29),
        (70, 27), (75, 25), (80, 23)
    ]

    /// Resting heart rate norms (bpm) by age. lower is better.
    /// Sources: AHA, Framingham Heart Study population data.
    static let restingHeartRate: [(age: Int, value: Double)] = [
        (20, 63), (25, 64), (30, 65), (35, 66), (40, 67),
        (45, 68), (50, 69), (55, 70), (60, 71), (65, 72),
        (70, 73), (75, 74), (80, 76)
    ]

    /// HRV (SDNN, ms) by age. higher is better.
    /// Sources: Nunan et al. 2010, Meta-analysis of HRV norms.
    static let hrv: [(age: Int, value: Double)] = [
        (20, 62), (25, 58), (30, 54), (35, 50), (40, 46),
        (45, 42), (50, 38), (55, 34), (60, 30), (65, 27),
        (70, 24), (75, 22), (80, 20)
    ]

    /// Sleep efficiency (%) by age. % of time in bed asleep.
    /// Sources: Ohayon et al. 2004, meta-analysis of sleep parameters.
    static let sleepEfficiency: [(age: Int, value: Double)] = [
        (20, 92), (25, 91), (30, 90), (35, 89), (40, 88),
        (45, 87), (50, 86), (55, 85), (60, 83), (65, 81),
        (70, 79), (75, 77), (80, 75)
    ]

    /// Deep sleep % of total by age.
    /// Sources: AASM staging data, Redline et al.
    static let deepSleepPercent: [(age: Int, value: Double)] = [
        (20, 22), (25, 20), (30, 18), (35, 17), (40, 16),
        (45, 15), (50, 14), (55, 13), (60, 12), (65, 11),
        (70, 10), (75, 9), (80, 8)
    ]

    /// Walking speed (km/h) by age.
    /// Sources: Bohannon & Andrews 2011, normative walking speed data.
    static let walkingSpeed: [(age: Int, value: Double)] = [
        (20, 5.4), (25, 5.3), (30, 5.2), (35, 5.1), (40, 5.0),
        (45, 4.9), (50, 4.8), (55, 4.7), (60, 4.5), (65, 4.3),
        (70, 4.1), (75, 3.9), (80, 3.6)
    ]

    /// Steps per day norms by age.
    /// Sources: Tudor-Locke et al. 2011, NHANES normative data.
    static let steps: [(age: Int, value: Double)] = [
        (20, 10000), (25, 9800), (30, 9500), (35, 9000), (40, 8500),
        (45, 8000), (50, 7500), (55, 7000), (60, 6500), (65, 6000),
        (70, 5500), (75, 5000), (80, 4500)
    ]

    /// Exercise minutes per day norms by age.
    /// Sources: WHO Physical Activity Guidelines population data.
    static let exerciseMinutes: [(age: Int, value: Double)] = [
        (20, 45), (25, 42), (30, 40), (35, 38), (40, 35),
        (45, 33), (50, 30), (55, 28), (60, 25), (65, 22),
        (70, 20), (75, 18), (80, 15)
    ]

    /// BMI norms by age. U-shaped relationship; 22-25 is optimal.
    /// For BMI we measure distance from optimal (22.5), so lower delta = younger.
    static let bmiOptimal: Double = 22.5

    /// Body fat % norms by age. combined sex average.
    /// Sources: Jackson & Pollock, ACE body fat norms.
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
    /// - Returns: Interpolated metric age (clamped to 18...95).
    static func metricAge(
        value: Double,
        table: [(age: Int, value: Double)],
        higherIsBetter: Bool
    ) -> Int {
        guard table.count >= 2 else { return 50 }

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

        // If value is below the minimum or above the maximum, clamp
        if value <= sortedTable.first!.value {
            return higherIsBetter ? sortedTable.first!.age : sortedTable.first!.age
        }
        if value >= sortedTable.last!.value {
            return higherIsBetter ? sortedTable.last!.age : sortedTable.last!.age
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
                return max(18, min(95, Int(interpolatedAge.rounded())))
            }
        }

        return 50 // Fallback
    }
}

// MARK: - Vitality Component

/// A single metric's contribution to the vitality age
struct VitalityComponent: Identifiable {
    let id = UUID()
    let metric: String
    let metricAge: Int
    let weight: Double
    let currentValue: Double
    let unit: String
    let populationMedian: Double
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

    /// 90-day pace of aging trend.
    /// < 1.0 = aging slower than calendar time, > 1.0 = aging faster.
    private(set) var paceOfAging: Double = 1.0

    /// Per-metric breakdown of contributing ages
    private(set) var componentAges: [VitalityComponent] = []

    /// Whether enough data exists to compute vitality age
    private(set) var isReady: Bool = false

    /// Vitality age history for charting (date, age)
    private(set) var history: [(date: Date, age: Int)] = []

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

    /// Days of data available at last compute. 0 means no data yet.
    private(set) var availableDays: Int = 0

    /// Whether vitality age is fully personalized for presentation.
    var isFullyMature: Bool { personalizationProgress >= 1 }

    // MARK: - Snapshot Persistence

    // Performance Pass 2 hot-path caches: avoid per-call allocations for the
    // snapshot save/restore round trip and any calendar component reads below.
    private static let cal: Calendar = Calendar.current
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
        let allSeries: [HealthMetric: MetricTimeSeries]
        if let timeSeries {
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
           let avg = recentAverage(series, days: 30) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.vo2Max, higherIsBetter: true)
            let w = Self.weightFor(.vo2Max)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.vo2Max)
            components.append(VitalityComponent(
                metric: "VO2 Max", metricAge: age, weight: w,
                currentValue: avg, unit: "mL/kg/min",
                populationMedian: median, healthMetric: .vo2Max
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- Resting Heart Rate ---
        if let series = allSeries[.restingHeartRate],
           let avg = recentAverage(series, days: 14) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.restingHeartRate, higherIsBetter: false)
            let w = Self.weightFor(.restingHeartRate)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.restingHeartRate)
            components.append(VitalityComponent(
                metric: "Resting HR", metricAge: age, weight: w,
                currentValue: avg, unit: "bpm",
                populationMedian: median, healthMetric: .restingHeartRate
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- HRV ---
        if let series = allSeries[.heartRateVariability],
           let avg = recentAverage(series, days: 14) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.hrv, higherIsBetter: true)
            let w = Self.weightFor(.hrv)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.hrv)
            components.append(VitalityComponent(
                metric: "HRV", metricAge: age, weight: w,
                currentValue: avg, unit: "ms",
                populationMedian: median, healthMetric: .heartRateVariability
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- Sleep Efficiency (computed from duration and awake time) ---
        if let sleepSeries = allSeries[.sleepDuration],
           let awakeSeries = allSeries[.sleepAwake] {
            let recentSleep = sleepSeries.samples(lastDays: 14)
            let recentAwake = awakeSeries.samples(lastDays: 14)
            if recentSleep.count >= 7 && recentAwake.count >= 7 {
                let avgSleep = recentSleep.mean(of: \.value)
                let avgAwake = recentAwake.mean(of: \.value)
                let totalInBed = avgSleep + avgAwake
                if totalInBed > 0 {
                    let efficiency = (avgSleep / totalInBed) * 100.0
                    let age = VitalityNorms.metricAge(value: efficiency, table: VitalityNorms.sleepEfficiency, higherIsBetter: true)
                    let w = Self.weightFor(.sleepEfficiency)
                    let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.sleepEfficiency)
                    components.append(VitalityComponent(
                        metric: "Sleep Efficiency", metricAge: age, weight: w,
                        currentValue: efficiency, unit: "%",
                        populationMedian: median, healthMetric: .sleepDuration
                    ))
                    weightedAgeSum += Double(age) * w
                    totalWeight += w
                }
            }
        }

        // --- Deep Sleep % ---
        if let deepSeries = allSeries[.sleepDeep],
           let sleepSeries = allSeries[.sleepDuration] {
            let recentDeep = deepSeries.samples(lastDays: 14)
            let recentSleep = sleepSeries.samples(lastDays: 14)
            if recentDeep.count >= 7 && recentSleep.count >= 7 {
                let avgDeep = recentDeep.mean(of: \.value)
                let avgTotal = recentSleep.mean(of: \.value)
                if avgTotal > 0 {
                    let deepPct = (avgDeep / avgTotal) * 100.0
                    let age = VitalityNorms.metricAge(value: deepPct, table: VitalityNorms.deepSleepPercent, higherIsBetter: true)
                    let w = Self.weightFor(.deepSleepPercent)
                    let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.deepSleepPercent)
                    components.append(VitalityComponent(
                        metric: "Deep Sleep", metricAge: age, weight: w,
                        currentValue: deepPct, unit: "%",
                        populationMedian: median, healthMetric: .sleepDeep
                    ))
                    weightedAgeSum += Double(age) * w
                    totalWeight += w
                }
            }
        }

        // --- Walking Speed ---
        if let series = allSeries[.walkingSpeed],
           let avg = recentAverage(series, days: 30) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.walkingSpeed, higherIsBetter: true)
            let w = Self.weightFor(.walkingSpeed)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.walkingSpeed)
            components.append(VitalityComponent(
                metric: "Walking Speed", metricAge: age, weight: w,
                currentValue: avg, unit: "km/h",
                populationMedian: median, healthMetric: .walkingSpeed
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- Steps ---
        if let series = allSeries[.steps],
           let avg = recentAverage(series, days: 14) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.steps, higherIsBetter: true)
            let w = Self.weightFor(.steps)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.steps)
            components.append(VitalityComponent(
                metric: "Daily Steps", metricAge: age, weight: w,
                currentValue: avg, unit: "steps",
                populationMedian: median, healthMetric: .steps
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- Exercise Minutes ---
        if let series = allSeries[.exerciseMinutes],
           let avg = recentAverage(series, days: 14) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.exerciseMinutes, higherIsBetter: true)
            let w = Self.weightFor(.exerciseMinutes)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.exerciseMinutes)
            components.append(VitalityComponent(
                metric: "Exercise", metricAge: age, weight: w,
                currentValue: avg, unit: "min/day",
                populationMedian: median, healthMetric: .exerciseMinutes
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        }

        // --- Body Composition (BMI or Body Fat %) ---
        if let bfSeries = allSeries[.bodyFatPercentage],
           let avg = recentAverage(bfSeries, days: 30) {
            let age = VitalityNorms.metricAge(value: avg, table: VitalityNorms.bodyFatPercent, higherIsBetter: false)
            let w = Self.weightFor(.bodyComposition)
            let median = interpolateMedian(age: chronologicalAge, table: VitalityNorms.bodyFatPercent)
            components.append(VitalityComponent(
                metric: "Body Fat", metricAge: age, weight: w,
                currentValue: avg, unit: "%",
                populationMedian: median, healthMetric: .bodyFatPercentage
            ))
            weightedAgeSum += Double(age) * w
            totalWeight += w
        } else if let bmiSeries = allSeries[.bmi],
                  let avg = recentAverage(bmiSeries, days: 30) {
            // Fall back to BMI if no body fat data
            // Map BMI deviation from optimal to an age offset
            let deviation = abs(avg - VitalityNorms.bmiOptimal)
            // Each point away from 22.5 adds ~1.5 years
            let ageOffset = deviation * 1.5
            let bmiAge = max(18, min(95, Int(Double(chronologicalAge) + ageOffset)))
            let w = Self.weightFor(.bodyComposition)
            components.append(VitalityComponent(
                metric: "BMI", metricAge: bmiAge, weight: w,
                currentValue: avg, unit: "",
                populationMedian: VitalityNorms.bmiOptimal, healthMetric: .bmi
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
            return
        }

        // Normalize weights if not all metrics are available
        let computedAge = Int((weightedAgeSum / totalWeight).rounded())
        computedBiologicalAge = max(18, min(95, computedAge))
        vitalityAge = blendedBiologicalAge(
            chronologicalAge: chronologicalAge,
            computedBiologicalAge: computedBiologicalAge,
            progress: personalizationProgress
        )
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
        if paceOfAging < 0.85 { return "Improving" }
        if paceOfAging <= 1.15 { return "Stable" }
        return "Declining"
    }

    /// Whether the pace trend is positive (aging slower than calendar)
    var paceIsPositive: Bool { paceOfAging < 1.0 }

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
    private func blendedBiologicalAge(
        chronologicalAge: Int,
        computedBiologicalAge: Int,
        progress: Double
    ) -> Int {
        let rawDelta = Double(computedBiologicalAge - chronologicalAge)
        let blended = Double(chronologicalAge) + (rawDelta * max(0, min(1, progress)))
        return max(18, min(95, Int(blended.rounded())))
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

    /// Interpolate the population median for a given age from a reference table
    private func interpolateMedian(age: Int, table: [(age: Int, value: Double)]) -> Double {
        guard table.count >= 2 else { return 0 }

        if age <= table.first!.age { return table.first!.value }
        if age >= table.last!.age { return table.last!.value }

        for i in 0..<(table.count - 1) {
            if age >= table[i].age && age <= table[i + 1].age {
                let fraction = Double(age - table[i].age) / Double(table[i + 1].age - table[i].age)
                return table[i].value + fraction * (table[i + 1].value - table[i].value)
            }
        }

        return table[table.count / 2].value
    }

    /// Build vitality age history from stored analysis snapshots
    /// Uses a simplified re-computation approach: samples the overall score trend
    /// and maps it to a vitality age approximation over time.
    private func computeHistory(from store: HealthDataStore) {
        let scoreHistory = MainActor.assumeIsolated { store.loadScoreHistory(days: 90) }
        guard scoreHistory.count >= 7 else {
            history = []
            return
        }

        // Map health scores to approximate vitality ages.
        // A perfect score (100) maps to chronologicalAge - 10,
        // a poor score (40) maps to chronologicalAge + 15.
        // The current vitality age anchors the most recent point.
        let latestScore = scoreHistory.last?.score ?? 75
        let currentDelta = vitalityAge - chronologicalAge

        history = scoreHistory.map { entry in
            let scoreDiff = entry.score - latestScore
            // Each point of health score difference ~= 0.3 years of vitality age
            let ageOffset = currentDelta - Int(Double(scoreDiff) * 0.3)
            let historicalAge = max(18, min(95, chronologicalAge + ageOffset))
            return (date: entry.date, age: historicalAge)
        }
    }

    /// Compute pace of aging from the 90-day history.
    /// Pace = (change in vitality age) / (change in calendar time).
    /// < 1.0 means aging slower, > 1.0 means aging faster.
    private func computePaceOfAging() {
        guard history.count >= 14 else {
            paceOfAging = 1.0
            return
        }

        // Compare first third vs last third of history
        let thirdCount = history.count / 3
        let earlySlice = history.prefix(thirdCount)
        let lateSlice = history.suffix(thirdCount)

        guard !earlySlice.isEmpty, !lateSlice.isEmpty else {
            paceOfAging = 1.0
            return
        }

        let earlyAvgAge = Double(earlySlice.map(\.age).reduce(0, +)) / Double(earlySlice.count)
        let lateAvgAge = Double(lateSlice.map(\.age).reduce(0, +)) / Double(lateSlice.count)

        let earlyDate = earlySlice.first!.date
        let lateDate = lateSlice.last!.date
        let calendarDays = Self.cal.dateComponents([.day], from: earlyDate, to: lateDate).day ?? 1
        let calendarYears = Double(max(calendarDays, 1)) / 365.25

        if calendarYears > 0 {
            let vitalityAgeChange = lateAvgAge - earlyAvgAge
            let calendarAgeChange = calendarYears
            // Ratio: how many years of vitality age change per calendar year
            paceOfAging = max(0.5, min(2.0, (vitalityAgeChange / calendarAgeChange) + 1.0))
        } else {
            paceOfAging = 1.0
        }
    }
}
