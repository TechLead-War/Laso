import Foundation
import SwiftUI

// MARK: - Stress Level

enum StressLevel: String, CaseIterable, Codable {
    case low
    case mild
    case moderate
    case high

    var displayName: String {
        switch self {
        case .low: return Copy.StressMonitor.stressLevelLow
        case .mild: return Copy.StressMonitor.stressLevelMild
        case .moderate: return Copy.StressMonitor.stressLevelModerate
        case .high: return Copy.StressMonitor.stressLevelHigh
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .high: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "leaf.fill"
        case .mild: return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .high: return "bolt.heart.fill"
        }
    }

    /// Upper-exclusive score bound for the `low` stress level (0-3 scale).
    static let mildLowerBound: Double = 0.75
    /// Upper-exclusive score bound for the `mild` stress level (0-3 scale).
    static let moderateLowerBound: Double = 1.5
    /// Upper-exclusive score bound for the `moderate` stress level; at/above is `high`.
    static let highLowerBound: Double = 2.25

    init(score: Double) {
        switch score {
        case ..<StressLevel.mildLowerBound: self = .low
        case StressLevel.mildLowerBound..<StressLevel.moderateLowerBound: self = .mild
        case StressLevel.moderateLowerBound..<StressLevel.highLowerBound: self = .moderate
        default: self = .high
        }
    }
}

// MARK: - Stress Score

struct StressScore {
    /// Continuous stress score from 0.0 (no stress) to 3.0 (high stress)
    let score: Double
    /// Categorical stress level derived from the score
    let level: StressLevel
    /// Percentage below personal HRV baseline (0.0 = at baseline, 1.0 = 100% below)
    let hrvDeviation: Double
    /// Percentage above personal resting HR baseline (0.0 = at baseline, 1.0 = 100% above)
    let hrElevation: Double
}

// MARK: - Stress Scorer

/// Computes a continuous stress score (0-3) from HRV and heart rate data,
/// modeled after WHOOP's strain/recovery scale.
///
/// The score combines two physiological signals:
/// - HRV deviation below personal baseline (60% weight). lower HRV indicates higher sympathetic activation
/// - Heart rate elevation above personal resting HR (40% weight). elevated HR indicates stress response
///
/// Requires at least 14 days of HRV data to establish a reliable personal baseline.
@Observable
final class StressScorer {

    // MARK: - Configuration

    private static let minimumDaysRequired = 3
    private static let baselineWindowDays = 14
    private static let historyWindowDays = 30
    private static let hrvWeight = 0.6
    private static let hrWeight = 0.4

    /// Number of days included in the weekly-average rolling window.
    private static let weeklyAverageWindowDays = 7
    /// Minimum samples required before `weeklyAverage` is reported.
    private static let weeklyAverageMinSamples = 3
    /// Stress-score scaling factor that maps a 0-100% deviation onto the 0-3 stress scale.
    private static let stressScoreScale: Double = 3.0
    /// Maximum value the final stress score is clamped to.
    private static let stressScoreCeiling: Double = 3.0
    /// Minimum samples required to compute a per-window baseline (mean, sd).
    private static let minSamplesForBaseline = 5
    /// Look-back window (days) used when picking the most recent daily mean.
    private static let mostRecentLookbackDays = 2

    // MARK: - Outputs

    /// The most recently computed stress score, or nil if insufficient data
    private(set) var currentStress: StressScore?

    /// Whether the scorer has enough data to produce a meaningful result (14+ days of HRV)
    private(set) var isReady: Bool = false

    /// Daily stress scores for the last 30 days
    private(set) var dailyStressHistory: [(date: Date, score: Double)] = []

    /// Average stress score over the last 7 days, or nil if insufficient history
    var weeklyAverage: Double? {
        let last7 = dailyStressHistory.suffix(Self.weeklyAverageWindowDays)
        guard last7.count >= Self.weeklyAverageMinSamples else { return nil }
        return last7.map(\.score).reduce(0, +) / Double(last7.count)
    }

    // MARK: - Compute

    /// Compute the stress score from the health data store.
    ///
    /// Builds a 14-day personal baseline for HRV and resting heart rate,
    /// then scores the most recent values against those baselines.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store containing metric time series.
    ///   - timeSeries: Optional in-memory time series to avoid redundant full-store reads.
    func compute(from store: HealthDataStore, timeSeries: [HealthMetric: MetricTimeSeries]? = nil) {
        let allSeries: [HealthMetric: MetricTimeSeries]
        if let timeSeries {
            allSeries = timeSeries
        } else {
            allSeries = MainActor.assumeIsolated { store.loadAllTimeSeries() }
        }

        guard let hrvSeries = allSeries[.heartRateVariability],
              hrvSeries.daysOfData >= Self.minimumDaysRequired else {
            isReady = false
            currentStress = nil
            dailyStressHistory = []
            return
        }

        isReady = true

        // Build baselines from the 14-day window
        let hrvBaseline = computeBaseline(hrvSeries, days: Self.baselineWindowDays)
        let rhrBaseline: (mean: Double, sd: Double)?
        if let rhrSeries = allSeries[.restingHeartRate] {
            rhrBaseline = computeBaseline(rhrSeries, days: Self.baselineWindowDays)
        } else {
            rhrBaseline = nil
        }

        // Compute current stress from most recent values
        let currentHRV = mostRecentDailyValue(hrvSeries)
        let currentHR = currentHeartRateValue(allSeries)

        if let hrvBase = hrvBaseline, let hrv = currentHRV {
            let stressScore = computeStressScore(
                currentHRV: hrv,
                hrvBaseline: hrvBase,
                currentHR: currentHR,
                rhrBaseline: rhrBaseline
            )
            currentStress = stressScore
        } else {
            currentStress = nil
        }

        // Build daily history
        buildDailyHistory(
            hrvSeries: hrvSeries,
            rhrSeries: allSeries[.restingHeartRate],
            hrSeries: allSeries[.heartRate]
        )
    }

    // MARK: - Private Helpers

    /// Compute mean and standard deviation for a baseline window
    private func computeBaseline(_ series: MetricTimeSeries, days: Int) -> (mean: Double, sd: Double)? {
        let samples = series.samples(lastDays: days)
        guard samples.count >= Self.minSamplesForBaseline else { return nil }

        let mean = samples.mean(of: \.value)
        guard mean > 0 else { return nil }

        var sumOfSquares = 0.0
        for sample in samples {
            let delta = sample.value - mean
            sumOfSquares += delta * delta
        }
        let sd = (sumOfSquares / Double(samples.count)).squareRoot()

        return (mean: mean, sd: sd)
    }

    /// Get the most recent daily average value from a time series
    private func mostRecentDailyValue(_ series: MetricTimeSeries) -> Double? {
        mostRecentDailyMean(series.samples(lastDays: Self.mostRecentLookbackDays))
    }

    /// Get the current heart rate, preferring resting HR, falling back to general HR
    private func currentHeartRateValue(_ allSeries: [HealthMetric: MetricTimeSeries]) -> Double? {
        // Prefer resting heart rate as it is less noisy
        if let rhrSeries = allSeries[.restingHeartRate],
           let mean = mostRecentDailyMean(rhrSeries.samples(lastDays: Self.mostRecentLookbackDays)) {
            return mean
        }
        // Fall back to general heart rate
        if let hrSeries = allSeries[.heartRate],
           let mean = mostRecentDailyMean(hrSeries.samples(lastDays: Self.mostRecentLookbackDays)) {
            return mean
        }
        return nil
    }

    /// Aggregate samples by calendar day and return the most recent day's mean.
    /// Avoids the single-sample noise that caused the score to clip to 0 when one
    /// raw reading happened to land at or above the 14-day baseline mean.
    private func mostRecentDailyMean(_ samples: [MetricSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let calendar = Date.cal
        var byDay: [Date: (sum: Double, count: Int)] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            if var existing = byDay[day] {
                existing.sum += sample.value
                existing.count += 1
                byDay[day] = existing
            } else {
                byDay[day] = (sum: sample.value, count: 1)
            }
        }
        guard let latestDay = byDay.keys.max(),
              let agg = byDay[latestDay], agg.count > 0 else { return nil }
        return agg.sum / Double(agg.count)
    }

    /// Compute the stress score from current values and baselines
    private func computeStressScore(
        currentHRV: Double,
        hrvBaseline: (mean: Double, sd: Double),
        currentHR: Double?,
        rhrBaseline: (mean: Double, sd: Double)?
    ) -> StressScore {
        // HRV component: how far below baseline (lower HRV = higher stress)
        let hrvDeviation: Double
        if hrvBaseline.mean > 0 {
            hrvDeviation = max(0, (hrvBaseline.mean - currentHRV) / hrvBaseline.mean)
        } else {
            hrvDeviation = 0
        }
        let hrvComponent = hrvDeviation * Self.stressScoreScale

        // HR component: how far above resting baseline (higher HR = higher stress)
        let hrElevation: Double
        let hrComponent: Double
        if let hr = currentHR, let rhr = rhrBaseline, rhr.mean > 0 {
            hrElevation = max(0, (hr - rhr.mean) / rhr.mean)
            hrComponent = hrElevation * Self.stressScoreScale
        } else {
            hrElevation = 0
            hrComponent = 0
        }

        // Weighted combination
        let hasHR = currentHR != nil && rhrBaseline != nil
        let rawScore: Double
        if hasHR {
            rawScore = hrvComponent * Self.hrvWeight + hrComponent * Self.hrWeight
        } else {
            // HRV only. use full weight
            rawScore = hrvComponent
        }

        let clampedScore = min(Self.stressScoreCeiling, max(0.0, rawScore))

        return StressScore(
            score: clampedScore,
            level: StressLevel(score: clampedScore),
            hrvDeviation: hrvDeviation,
            hrElevation: hrElevation
        )
    }

    /// Build the last 30 days of daily stress history
    private func buildDailyHistory(
        hrvSeries: MetricTimeSeries,
        rhrSeries: MetricTimeSeries?,
        hrSeries: MetricTimeSeries?
    ) {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let historyDays = Self.historyWindowDays

        // Build per-day lookup for HRV
        let hrvByDay = buildDailyLookup(hrvSeries.samples(lastDays: historyDays + Self.baselineWindowDays))

        // Build per-day lookup for resting HR
        let rhrByDay: [Date: Double]
        if let rhr = rhrSeries {
            rhrByDay = buildDailyLookup(rhr.samples(lastDays: historyDays + Self.baselineWindowDays))
        } else {
            rhrByDay = [:]
        }

        var history: [(date: Date, score: Double)] = []

        for dayOffset in (0..<historyDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            guard let currentHRV = hrvByDay[dayStart] else { continue }

            // Build a trailing baseline for this day (14 days ending the day before)
            let baselineHRV = trailingBaseline(from: hrvByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
            guard let hrvBase = baselineHRV, hrvBase.mean > 0 else { continue }

            let hrvDeviation = max(0, (hrvBase.mean - currentHRV) / hrvBase.mean)
            var score = hrvDeviation * Self.stressScoreScale

            // Add HR component if available
            if let currentRHR = rhrByDay[dayStart] {
                let rhrBase = trailingBaseline(from: rhrByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
                if let rBase = rhrBase, rBase.mean > 0 {
                    let hrElevation = max(0, (currentRHR - rBase.mean) / rBase.mean)
                    score = score * Self.hrvWeight + (hrElevation * Self.stressScoreScale) * Self.hrWeight
                }
            }

            history.append((date: dayStart, score: min(Self.stressScoreCeiling, max(0.0, score))))
        }

        dailyStressHistory = history
    }

    /// Build a lookup of date -> average value for a set of samples
    private func buildDailyLookup(_ samples: [MetricSample]) -> [Date: Double] {
        let calendar = Date.cal
        var grouped: [Date: (sum: Double, count: Int)] = [:]

        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            if var existing = grouped[day] {
                existing.sum += sample.value
                existing.count += 1
                grouped[day] = existing
            } else {
                grouped[day] = (sum: sample.value, count: 1)
            }
        }

        var result: [Date: Double] = [:]
        for (day, agg) in grouped {
            result[day] = agg.sum / Double(agg.count)
        }
        return result
    }

    /// Compute a trailing baseline (mean, sd) from a daily lookup, for the N days before a given date
    private func trailingBaseline(
        from lookup: [Date: Double],
        before date: Date,
        days: Int,
        calendar: Calendar
    ) -> (mean: Double, sd: Double)? {
        var values: [Double] = []
        values.reserveCapacity(days)

        for offset in 1...days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            if let value = lookup[dayStart] {
                values.append(value)
            }
        }

        guard values.count >= Self.minSamplesForBaseline else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return nil }

        var sumOfSquares = 0.0
        for value in values {
            let delta = value - mean
            sumOfSquares += delta * delta
        }
        let sd = (sumOfSquares / Double(values.count)).squareRoot()

        return (mean: mean, sd: sd)
    }
}
