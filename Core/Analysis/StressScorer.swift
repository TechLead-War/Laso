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
        case .low: return AppColour.scoreOptimal
        case .mild: return AppColour.scoreGood
        case .moderate: return AppColour.scoreFair
        case .high: return AppColour.scorePoor
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

    /// Upper-exclusive score bound for the `low` stress level (0-100 scale).
    static let mildLowerBound: Double = 25
    /// Upper-exclusive score bound for the `mild` stress level (0-100 scale).
    static let moderateLowerBound: Double = 50
    /// Upper-exclusive score bound for the `moderate` stress level; at/above is `high`.
    static let highLowerBound: Double = 75

    init(score: Double) {
        switch score {
        case ..<StressLevel.mildLowerBound: self = .low
        case StressLevel.mildLowerBound..<StressLevel.moderateLowerBound: self = .mild
        case StressLevel.moderateLowerBound..<StressLevel.highLowerBound: self = .moderate
        default: self = .high
        }
    }
}

// MARK: - Stress Scale

/// The stress score range and how it is drawn. Kept next to the scorer so a
/// chart or gauge can never draw against a range the scorer does not produce.
enum StressScale {
    /// Scores run 0 (calm) to 100 (high stress), matching readiness, sleep, vitality
    /// and brain health. Stress was previously 0 to 3, where real readings clustered
    /// under 1.0 and the top of the range was unreachable, so the gauge looked broken
    /// and the top band never fired.
    static let maxScore: Double = 100

    /// Smallest fill drawn for a score above zero. Day to day scores sit far
    /// below the ceiling, so without a floor a real low reading draws as a
    /// hairline and the chart reads as empty or broken.
    static let minVisibleFraction: Double = 0.12

    /// True 0 to 1 position of a score in the range, for the gauge needle.
    static func position(for score: Double) -> Double {
        min(max(score / maxScore, 0), 1.0)
    }

    /// Bar fill for a score, floored so any score above zero stays visible.
    static func barFill(for score: Double) -> Double {
        guard score > 0 else { return 0 }
        return max(position(for: score), minVisibleFraction)
    }
}

// MARK: - Stress Score

struct StressScore {
    /// Continuous stress score from 0 (no stress) to 100 (high stress)
    let score: Double
    /// Categorical stress level derived from the score
    let level: StressLevel
    /// Percentage below personal HRV baseline (0.0 = at baseline, 1.0 = 100% below)
    let hrvDeviation: Double
    /// Percentage above personal resting HR baseline (0.0 = at baseline, 1.0 = 100% above)
    let hrElevation: Double
}

// MARK: - Stress Scorer

/// Computes a continuous stress score (0-100) from HRV and heart rate data,
/// modeled after WHOOP's strain/recovery scale. `score(...)` is the one stress
/// formula in the app: `ReadinessScorer.stressLevel` calls it too, so Siri and
/// the morning lock can never disagree with the Stress Monitor about a morning.
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
    /// Long enough to feed the trend card. Everything reading a shorter span
    /// takes its own suffix, so widening this does not move those numbers.
    private static let historyWindowDays = 90
    private static let hrvWeight = 0.6
    private static let hrWeight = 0.4

    /// Number of days included in the weekly-average rolling window.
    private static let weeklyAverageWindowDays = 7
    /// Minimum samples required before `weeklyAverage` is reported.
    private static let weeklyAverageMinSamples = 3
    /// Deviation below personal baseline that reads as the top of the scale.
    ///
    /// HRV rarely falls more than about a third below a person's own baseline, so
    /// mapping a full 100% deviation onto the scale left most of it unused and made
    /// the top band unreachable. Anchoring the ceiling at half is a display choice
    /// about resolution, not a clinical threshold: it puts everyday readings across
    /// the usable range while still leaving headroom above a severe day.
    private static let deviationAtMaxScore: Double = 0.5

    /// Converts a fraction below baseline into a point on the 0 to 100 scale.
    private static let stressScoreScale: Double = StressScale.maxScore / deviationAtMaxScore
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

        // Build daily history and update currentStress deterministically
        buildDailyHistory(
            hrvSeries: hrvSeries,
            rhrSeries: allSeries[.restingHeartRate]
        )
    }

    // MARK: - Private Helpers

    /// The stress score for one reading against personal baseline means.
    static func score(
        currentHRV: Double,
        hrvBaselineMean: Double,
        currentHR: Double?,
        rhrBaselineMean: Double?
    ) -> StressScore {
        // HRV component: how far below baseline (lower HRV = higher stress)
        let hrvDeviation: Double
        if hrvBaselineMean > 0 {
            hrvDeviation = max(0, (hrvBaselineMean - currentHRV) / hrvBaselineMean)
        } else {
            hrvDeviation = 0
        }
        let hrvComponent = hrvDeviation * Self.stressScoreScale

        // HR component: how far above resting baseline (higher HR = higher stress)
        let hrElevation: Double
        let hrComponent: Double
        if let hr = currentHR, let rhrMean = rhrBaselineMean, rhrMean > 0 {
            hrElevation = max(0, (hr - rhrMean) / rhrMean)
            hrComponent = hrElevation * Self.stressScoreScale
        } else {
            hrElevation = 0
            hrComponent = 0
        }

        // Weighted combination
        let hasHR = currentHR != nil && rhrBaselineMean != nil
        let rawScore: Double
        if hasHR {
            rawScore = hrvComponent * Self.hrvWeight + hrComponent * Self.hrWeight
        } else {
            // HRV only. use full weight
            rawScore = hrvComponent
        }

        let clampedScore = min(StressScale.maxScore, max(0.0, rawScore))

        return StressScore(
            score: clampedScore,
            level: StressLevel(score: clampedScore),
            hrvDeviation: hrvDeviation,
            hrElevation: hrElevation
        )
    }

    /// Build daily stress history and update currentStress deterministically
    private func buildDailyHistory(
        hrvSeries: MetricTimeSeries,
        rhrSeries: MetricTimeSeries?
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
        var latestComputedStress: (date: Date, stress: StressScore)?

        for dayOffset in (0..<historyDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            guard let currentHRV = hrvByDay[dayStart] else { continue }

            // Build a trailing baseline for this day (14 days ending the day before)
            guard let hrvBaseMean = trailingBaselineMean(from: hrvByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar) else { continue }

            let currentRHR = rhrByDay[dayStart]
            let rhrBaseMean = currentRHR == nil
                ? nil
                : trailingBaselineMean(from: rhrByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)

            let dayStress = Self.score(
                currentHRV: currentHRV,
                hrvBaselineMean: hrvBaseMean,
                currentHR: currentRHR,
                rhrBaselineMean: rhrBaseMean
            )

            history.append((date: dayStart, score: dayStress.score))
            latestComputedStress = (date: dayStart, stress: dayStress)
        }

        dailyStressHistory = history

        // Current stress corresponds to the latest available day within the lookback window.
        // Because each day uses an immutable trailing baseline strictly preceding it,
        // historical scores are deterministic and will not mutate overnight.
        if let latest = latestComputedStress {
            let daysDifference = calendar.dateComponents([.day], from: latest.date, to: today).day ?? 0
            if daysDifference < Self.mostRecentLookbackDays {
                currentStress = latest.stress
            } else {
                currentStress = nil
            }
        } else {
            currentStress = nil
        }
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

    /// Mean of the N daily values strictly before `date`. Excluding the day
    /// itself is what keeps a past day's score fixed once it is scored.
    private func trailingBaselineMean(
        from lookup: [Date: Double],
        before date: Date,
        days: Int,
        calendar: Calendar
    ) -> Double? {
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

        let mean = values.mean
        return mean > 0 ? mean : nil
    }
}
