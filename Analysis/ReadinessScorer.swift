import Foundation

struct ReadinessScorer {
    struct BaselineStats: Equatable {
        let mean: Double
        let median: Double
        let standardDeviation: Double
        let iqr: Double
        let sampleCount: Int
    }

    struct Input {
        var now: Date = Date()
        var hrv: Double?
        var hrvTimestamp: Date?
        var hrvBaseline: BaselineStats?
        var restingHeartRate: Double?
        var restingHeartRateTimestamp: Date?
        var restingHeartRateBaseline: BaselineStats?
        var sleepDuration: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var hasSleepStageBreakdown = false
        var workoutTimestamp: Date?
        var workoutDurationMinutes: Double?
        var workoutCalories: Double?
        var previousSmoothedScore: Double?
    }

    struct Assessment: Equatable {
        let score: Int
        let confidence: Int
        let smoothedScore: Double
    }

    private struct Signal {
        let score: Double
        let weight: Double
        let confidence: Double
    }

    static let defaultSmoothingAlpha = 0.7
    static let defaultMinimumSampleCount = 10

    static func assess(
        _ input: Input,
        smoothingAlpha: Double = defaultSmoothingAlpha
    ) -> Assessment? {
        var signals: [Signal] = []

        if let hrv = input.hrv {
            let baseline = input.hrvBaseline
            let score = hrvScore(current: hrv, baseline: baseline)
            let age = input.hrvTimestamp.map { input.now.timeIntervalSince($0) } ?? (72 * 3600)
            let freshness = freshnessConfidence(age: age, maxAge: 48 * 3600)
            let baselineConfidence = baseline.map { min(1.0, Double($0.sampleCount) / 21.0) } ?? 0.55
            signals.append(Signal(score: score, weight: 0.40, confidence: freshness * baselineConfidence))
        }

        if let restingHeartRate = input.restingHeartRate {
            let baseline = input.restingHeartRateBaseline
            let score = rhrScore(current: restingHeartRate, baseline: baseline)
            let age = input.restingHeartRateTimestamp.map { input.now.timeIntervalSince($0) } ?? (72 * 3600)
            let freshness = freshnessConfidence(age: age, maxAge: 48 * 3600)
            let baselineConfidence = baseline.map { min(1.0, Double($0.sampleCount) / 21.0) } ?? 0.55
            signals.append(Signal(score: score, weight: 0.35, confidence: freshness * baselineConfidence))
        }

        let sleepHours = input.sleepDuration / 3600.0
        if sleepHours > 0 {
            let score = sleepDurationScore(hours: sleepHours)
            let confidence = min(1.0, max(0.5, sleepHours / 7.0))
            signals.append(Signal(score: score, weight: 0.15, confidence: confidence))
        }

        if input.hasSleepStageBreakdown, input.sleepDuration > 0 {
            let score = sleepStageScore(
                deep: input.deepSleep,
                rem: input.remSleep,
                total: input.sleepDuration
            )
            signals.append(Signal(score: score, weight: 0.06, confidence: 0.85))
        }

        if let workoutDate = input.workoutTimestamp,
           let workoutDuration = input.workoutDurationMinutes {
            let hoursSinceWorkout = input.now.timeIntervalSince(workoutDate) / 3600.0
            let score = workoutRecoveryScore(
                hoursSinceWorkout: hoursSinceWorkout,
                durationMinutes: workoutDuration,
                calories: input.workoutCalories
            )
            let confidence = min(1.0, max(0.4, 1.0 - (max(0.0, hoursSinceWorkout - 36.0) / 24.0)))
            signals.append(Signal(score: score, weight: 0.04, confidence: confidence))
        }

        guard !signals.isEmpty else { return nil }

        let effectiveWeightTotal = signals.reduce(0.0) { $0 + ($1.weight * $1.confidence) }
        guard effectiveWeightTotal > 0 else { return nil }

        let weightedScore = signals.reduce(0.0) { partial, signal in
            partial + (signal.score * signal.weight * signal.confidence)
        } / effectiveWeightTotal

        let totalConfiguredWeight = signals.reduce(0.0) { $0 + $1.weight }
        let confidence = min(1.0, effectiveWeightTotal / max(totalConfiguredWeight, 0.0001))
        var score = 50 + (weightedScore - 50) * (0.35 + 0.65 * confidence)

        if let bestAge = freshestCardiacAgeHours(
            hrvTimestamp: input.hrvTimestamp,
            rhrTimestamp: input.restingHeartRateTimestamp,
            now: input.now
        ), bestAge > 24 {
            score -= min(12.0, (bestAge - 24.0) * 0.5)
        }

        let clampedScore = clamp(score, min: 0, max: 100)
        let smoothedScore: Double
        if let previous = input.previousSmoothedScore {
            smoothedScore = previous + smoothingAlpha * (clampedScore - previous)
        } else {
            smoothedScore = clampedScore
        }

        return Assessment(
            score: Int(clamp(smoothedScore, min: 0, max: 100).rounded()),
            confidence: Int((confidence * 100).rounded()),
            smoothedScore: smoothedScore
        )
    }

    static func makeBaseline(
        values: [Double],
        minimumSampleCount: Int = defaultMinimumSampleCount,
        minimumSD: Double
    ) -> BaselineStats? {
        let clean = values.filter { $0.isFinite && $0 > 0 }
        guard clean.count >= minimumSampleCount else { return nil }

        let q1 = clean.percentile(25)
        let q3 = clean.percentile(75)
        let iqr = max(0.001, q3 - q1)
        let lower = q1 - 1.5 * iqr
        let upper = q3 + 1.5 * iqr
        let trimmed = clean.filter { $0 >= lower && $0 <= upper }
        let usable = trimmed.count >= minimumSampleCount ? trimmed : clean

        let mean = usable.mean
        let median = usable.median
        let adaptiveFloor = max(minimumSD, abs(mean) * 0.05, iqr * 0.3)
        let standardDeviation = max(usable.standardDeviation, adaptiveFloor)

        return BaselineStats(
            mean: mean,
            median: median,
            standardDeviation: standardDeviation,
            iqr: iqr,
            sampleCount: usable.count
        )
    }

    static func stressLevel(hrv: Double?, restingHeartRate: Double?) -> Int? {
        guard let hrv, let restingHeartRate else { return nil }
        let hrvStress = min(max((60 - hrv) / 40.0 * 50, 0), 50)
        let rhrStress = min(max((restingHeartRate - 50) / 30.0 * 50, 0), 50)
        return Int(hrvStress + rhrStress)
    }

    static func stressLabel(for level: Int?) -> String {
        guard let level else { return "No Data" }
        switch level {
        case 0..<20: return "Relaxed"
        case 20..<40: return "Low"
        case 40..<60: return "Moderate"
        case 60..<80: return "High"
        default: return "Very High"
        }
    }

    static func stressColorName(for level: Int?) -> String {
        guard let level else { return "gray" }
        switch level {
        case 0..<20: return "green"
        case 20..<40: return "green"
        case 40..<60: return "yellow"
        case 60..<80: return "orange"
        default: return "red"
        }
    }

    private static func hrvScore(current: Double, baseline: BaselineStats?) -> Double {
        if let baseline {
            let z = (current - baseline.median) / baseline.standardDeviation
            let normalized = tanh(z / 1.8)
            return clamp(55 + normalized * 35, min: 0, max: 100)
        }

        return clamp((current - 15) / 55 * 100, min: 0, max: 100)
    }

    private static func rhrScore(current: Double, baseline: BaselineStats?) -> Double {
        if let baseline {
            let z = (baseline.median - current) / baseline.standardDeviation
            let normalized = tanh(z / 1.8)
            return clamp(55 + normalized * 35, min: 0, max: 100)
        }

        return clamp((85 - current) / 40 * 100, min: 0, max: 100)
    }

    private static func sleepDurationScore(hours: Double) -> Double {
        if hours < 7.5 {
            let deficit = 7.5 - hours
            let penalty = deficit * 13 + deficit * deficit * 4
            return clamp(100 - penalty, min: 10, max: 100)
        }

        let excess = hours - 7.5
        let penalty = excess * 7 + excess * excess * 2
        return clamp(100 - penalty, min: 35, max: 100)
    }

    private static func sleepStageScore(deep: TimeInterval, rem: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 50 }
        let restorativeRatio = (deep + rem) / total
        return clamp((restorativeRatio - 0.16) / 0.24 * 100, min: 0, max: 100)
    }

    private static func workoutRecoveryScore(
        hoursSinceWorkout: Double,
        durationMinutes: Double,
        calories: Double?
    ) -> Double {
        let workoutLoad = min(1.0, max(durationMinutes / 75.0, (calories ?? 0) / 600.0))
        if hoursSinceWorkout < 6 {
            return 85 - workoutLoad * 35
        }
        if hoursSinceWorkout < 18 {
            return 92 - workoutLoad * 25
        }
        return 96 - workoutLoad * 12
    }

    private static func freshnessConfidence(age: TimeInterval, maxAge: TimeInterval) -> Double {
        guard age.isFinite else { return 0.35 }
        let ratio = clamp(age / maxAge, min: 0, max: 2)
        return clamp(1.0 - ratio * 0.65, min: 0.35, max: 1.0)
    }

    private static func freshestCardiacAgeHours(
        hrvTimestamp: Date?,
        rhrTimestamp: Date?,
        now: Date
    ) -> Double? {
        let ages = [hrvTimestamp, rhrTimestamp]
            .compactMap { $0 }
            .map { now.timeIntervalSince($0) / 3600.0 }
            .filter { $0.isFinite && $0 >= 0 }
        return ages.min()
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }
}
