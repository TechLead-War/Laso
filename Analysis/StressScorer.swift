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
        case .low: return "Low Stress"
        case .mild: return "Mild Stress"
        case .moderate: return "Moderate Stress"
        case .high: return "High Stress"
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

    init(score: Double) {
        switch score {
        case ..<0.75: self = .low
        case 0.75..<1.5: self = .mild
        case 1.5..<2.25: self = .moderate
        default: self = .high
        }
    }
}

// MARK: - Stress Trend

enum StressTrend: String, CaseIterable {
    case decreasing
    case stable
    case increasing

    var displayName: String {
        switch self {
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        case .increasing: return "Increasing"
        }
    }

    var icon: String {
        switch self {
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .increasing: return "arrow.up.right"
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
    /// Confidence in the score based on data availability and freshness (0.0-1.0)
    let confidence: Double
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

    // MARK: - Outputs

    /// The most recently computed stress score, or nil if insufficient data
    private(set) var currentStress: StressScore?

    /// Whether the scorer has enough data to produce a meaningful result (14+ days of HRV)
    private(set) var isReady: Bool = false

    /// Daily stress scores for the last 30 days
    private(set) var dailyStressHistory: [(date: Date, score: Double)] = []

    /// Average stress score over the last 7 days, or nil if insufficient history
    var weeklyAverage: Double? {
        let last7 = dailyStressHistory.suffix(7)
        guard last7.count >= 3 else { return nil }
        return last7.map(\.score).reduce(0, +) / Double(last7.count)
    }

    /// Trend direction of stress over the recent history
    var stressTrend: StressTrend {
        guard dailyStressHistory.count >= 7 else { return .stable }

        let count = dailyStressHistory.count
        let halfPoint = count / 2
        let firstHalf = dailyStressHistory.prefix(halfPoint)
        let secondHalf = dailyStressHistory.suffix(halfPoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return .stable }

        let firstAvg = firstHalf.map(\.score).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.score).reduce(0, +) / Double(secondHalf.count)

        let delta = secondAvg - firstAvg
        if delta > 0.2 { return .increasing }
        if delta < -0.2 { return .decreasing }
        return .stable
    }

    /// Human-readable description of current stress state with actionable advice
    var stressDescription: String {
        guard let stress = currentStress else {
            return "Not enough data to assess stress yet. Keep heart rate and HRV data syncing to establish your personal baseline."
        }

        let scoreText = String(format: "%.1f", stress.score)

        switch stress.level {
        case .low:
            return "Your stress level is low (\(scoreText)/3.0). Your HRV and heart rate are within your normal range. Keep up your current routine. your body is recovering well."

        case .mild:
            return "Your stress level is mildly elevated (\(scoreText)/3.0). "
                + (stress.hrvDeviation > 0.1
                    ? "Your HRV is \(Int(stress.hrvDeviation * 100))% below your baseline. "
                    : "")
                + "Consider lighter exercise today and prioritize sleep tonight."

        case .moderate:
            return "Your stress level is moderate (\(scoreText)/3.0). "
                + (stress.hrvDeviation > 0.15
                    ? "Your HRV is \(Int(stress.hrvDeviation * 100))% below your baseline. "
                    : "")
                + (stress.hrElevation > 0.1
                    ? "Your heart rate is \(Int(stress.hrElevation * 100))% above your resting average. "
                    : "")
                + "Focus on recovery: deep breathing, gentle movement, and adequate hydration."

        case .high:
            return "Your stress level is high (\(scoreText)/3.0). "
                + "Your HRV is \(Int(stress.hrvDeviation * 100))% below baseline and heart rate is \(Int(stress.hrElevation * 100))% elevated. "
                + "Prioritize rest and recovery. Avoid intense exercise, reduce caffeine, and consider mindfulness or breathing exercises."
        }
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
        guard samples.count >= 5 else { return nil }

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
        let recent = series.samples(lastDays: 2)
        guard !recent.isEmpty else { return nil }
        return recent.last?.value
    }

    /// Get the current heart rate, preferring resting HR, falling back to general HR
    private func currentHeartRateValue(_ allSeries: [HealthMetric: MetricTimeSeries]) -> Double? {
        // Prefer resting heart rate as it is less noisy
        if let rhrSeries = allSeries[.restingHeartRate] {
            let recent = rhrSeries.samples(lastDays: 2)
            if let last = recent.last {
                return last.value
            }
        }
        // Fall back to general heart rate
        if let hrSeries = allSeries[.heartRate] {
            let recent = hrSeries.samples(lastDays: 2)
            if let last = recent.last {
                return last.value
            }
        }
        return nil
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
        let hrvComponent = hrvDeviation * 3.0

        // HR component: how far above resting baseline (higher HR = higher stress)
        let hrElevation: Double
        let hrComponent: Double
        if let hr = currentHR, let rhr = rhrBaseline, rhr.mean > 0 {
            hrElevation = max(0, (hr - rhr.mean) / rhr.mean)
            hrComponent = hrElevation * 3.0
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

        let clampedScore = min(3.0, max(0.0, rawScore))

        // Confidence based on data availability and freshness
        let confidence = computeConfidence(
            hasHRV: true,
            hasHR: hasHR,
            hrvBaseline: hrvBaseline
        )

        return StressScore(
            score: clampedScore,
            level: StressLevel(score: clampedScore),
            hrvDeviation: hrvDeviation,
            hrElevation: hrElevation,
            confidence: confidence
        )
    }

    /// Compute confidence based on data freshness and sample count
    private func computeConfidence(
        hasHRV: Bool,
        hasHR: Bool,
        hrvBaseline: (mean: Double, sd: Double)
    ) -> Double {
        var confidence = 0.0

        // HRV data presence is the foundation (up to 0.6)
        if hasHRV {
            confidence += 0.6
        }

        // HR data adds confidence (up to 0.25)
        if hasHR {
            confidence += 0.25
        }

        // Baseline stability: lower coefficient of variation = more stable baseline = higher confidence
        // (up to 0.15)
        if hrvBaseline.mean > 0 {
            let cv = hrvBaseline.sd / hrvBaseline.mean
            // CV < 0.1 = very stable (full bonus), CV > 0.4 = highly variable (no bonus)
            let stabilityBonus = max(0, min(0.15, 0.15 * (1.0 - (cv - 0.1) / 0.3)))
            confidence += stabilityBonus
        }

        return min(1.0, confidence)
    }

    /// Build the last 30 days of daily stress history
    private func buildDailyHistory(
        hrvSeries: MetricTimeSeries,
        rhrSeries: MetricTimeSeries?,
        hrSeries: MetricTimeSeries?
    ) {
        let calendar = Calendar.current
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
            var score = hrvDeviation * 3.0

            // Add HR component if available
            if let currentRHR = rhrByDay[dayStart] {
                let rhrBase = trailingBaseline(from: rhrByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
                if let rBase = rhrBase, rBase.mean > 0 {
                    let hrElevation = max(0, (currentRHR - rBase.mean) / rBase.mean)
                    score = score * Self.hrvWeight + (hrElevation * 3.0) * Self.hrWeight
                }
            }

            history.append((date: dayStart, score: min(3.0, max(0.0, score))))
        }

        dailyStressHistory = history
    }

    /// Build a lookup of date -> average value for a set of samples
    private func buildDailyLookup(_ samples: [MetricSample]) -> [Date: Double] {
        let calendar = Calendar.current
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

        guard values.count >= 5 else { return nil }

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
