import Foundation

struct ReadinessScorer {
    struct BaselineStats: Equatable {
        let mean: Double
        let median: Double
        let standardDeviation: Double
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
        /// How far the model pulled the raw signal reading toward the centre
        /// because it did not have every signal, in score points.
        ///
        /// This is not a new estimate: the centre-pull below already decides how
        /// much of the raw reading we are willing to claim, and this is simply
        /// that same distance made visible. It lets the card show a range on a
        /// thin day instead of one confident looking number, without inventing a
        /// spread from nowhere.
        let uncertainty: Int
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
        // Hotfix kill switch — flip ON in Firebase Remote Config when readiness
        // ML output is bad in production. Callers fall back to the daily score.
        guard !RemoteConfigManager.shared.killReadinessScorer else { return nil }

        var signals: [Signal] = []

        if let hrv = input.hrv {
            let baseline = input.hrvBaseline
            let score = hrvScore(current: hrv, baseline: baseline)
            let age = input.hrvTimestamp.map { input.now.timeIntervalSince($0) } ?? ReadinessScorerConfig.missingCardiacAgeSeconds
            let freshness = freshnessConfidence(age: age, maxAge: ReadinessScorerConfig.cardiacFreshnessHorizonSeconds)
            let baselineConfidence = baseline.map { min(1.0, Double($0.sampleCount) / ReadinessScorerConfig.baselineConfidenceSampleCap) } ?? ReadinessScorerConfig.defaultBaselineConfidence
            signals.append(Signal(score: score, weight: ReadinessScorerConfig.hrvSignalWeight, confidence: freshness * baselineConfidence))
        }

        if let restingHeartRate = input.restingHeartRate {
            let baseline = input.restingHeartRateBaseline
            let score = rhrScore(current: restingHeartRate, baseline: baseline)
            let age = input.restingHeartRateTimestamp.map { input.now.timeIntervalSince($0) } ?? ReadinessScorerConfig.missingCardiacAgeSeconds
            let freshness = freshnessConfidence(age: age, maxAge: ReadinessScorerConfig.cardiacFreshnessHorizonSeconds)
            let baselineConfidence = baseline.map { min(1.0, Double($0.sampleCount) / ReadinessScorerConfig.baselineConfidenceSampleCap) } ?? ReadinessScorerConfig.defaultBaselineConfidence
            signals.append(Signal(score: score, weight: ReadinessScorerConfig.rhrSignalWeight, confidence: freshness * baselineConfidence))
        }

        let sleepHours = input.sleepDuration / 3600.0
        if sleepHours > 0 {
            let score = sleepDurationScore(hours: sleepHours)
            let confidence = min(1.0, max(ReadinessScorerConfig.sleepDurationConfidenceFloor, sleepHours / ReadinessScorerConfig.sleepDurationConfidenceTargetHours))
            signals.append(Signal(score: score, weight: ReadinessScorerConfig.sleepDurationSignalWeight, confidence: confidence))
        }

        if input.hasSleepStageBreakdown, input.sleepDuration > 0 {
            let score = sleepStageScore(
                deep: input.deepSleep,
                rem: input.remSleep,
                total: input.sleepDuration
            )
            signals.append(Signal(score: score, weight: ReadinessScorerConfig.sleepStageSignalWeight, confidence: ReadinessScorerConfig.sleepStageConfidence))
        }

        if let workoutDate = input.workoutTimestamp,
           let workoutDuration = input.workoutDurationMinutes {
            let hoursSinceWorkout = input.now.timeIntervalSince(workoutDate) / 3600.0
            let score = workoutRecoveryScore(
                hoursSinceWorkout: hoursSinceWorkout,
                durationMinutes: workoutDuration,
                calories: input.workoutCalories
            )
            let staleHours = max(0.0, hoursSinceWorkout - ReadinessScorerConfig.workoutRecoveryConfidenceOnsetHours)
            let confidence = min(1.0, max(ReadinessScorerConfig.workoutRecoveryConfidenceFloor, 1.0 - (staleHours / ReadinessScorerConfig.workoutRecoveryConfidenceDecayHours)))
            signals.append(Signal(score: score, weight: ReadinessScorerConfig.workoutSignalWeight, confidence: confidence))
        }

        guard !signals.isEmpty else { return nil }

        let effectiveWeightTotal = signals.reduce(0.0) { $0 + ($1.weight * $1.confidence) }
        guard effectiveWeightTotal > 0 else { return nil }

        let weightedScore = signals.reduce(0.0) { partial, signal in
            partial + (signal.score * signal.weight * signal.confidence)
        } / effectiveWeightTotal

        // Against every signal the score can use, not just the ones that turned
        // up: a missing signal has to cost confidence, otherwise a lone HRV
        // reading reports as certain as a full day.
        let totalConfiguredWeight = ReadinessScorerConfig.allSignalWeightTotal
        let confidence = min(1.0, effectiveWeightTotal / max(totalConfiguredWeight, 0.0001))
        var score = ReadinessScorerConfig.scoreCenter + (weightedScore - ReadinessScorerConfig.scoreCenter) * (ReadinessScorerConfig.scoreConfidenceFloor + ReadinessScorerConfig.scoreConfidenceSlope * confidence)

        // Read the centre-pull here, before the staleness penalty and the EMA.
        // Measuring it against the final shown score instead folds in
        // yesterday's number: at full confidence the EMA alone leaves a 9 point
        // gap after a 30 point day-over-day swing, and the card would print a
        // range on a day where nothing was missing.
        let centrePull = abs(weightedScore - score)

        if let bestAge = freshestCardiacAgeHours(
            hrvTimestamp: input.hrvTimestamp,
            rhrTimestamp: input.restingHeartRateTimestamp,
            now: input.now
        ), bestAge > ReadinessScorerConfig.cardiacStalenessOnsetHours {
            score -= min(ReadinessScorerConfig.cardiacStalenessMaxPenalty, (bestAge - ReadinessScorerConfig.cardiacStalenessOnsetHours) * ReadinessScorerConfig.cardiacStalenessPenaltyPerHour)
        }

        let clampedScore = clamp(score, min: 0, max: 100)
        let smoothedScore: Double
        if let previous = input.previousSmoothedScore {
            smoothedScore = previous + smoothingAlpha * (clampedScore - previous)
        } else {
            smoothedScore = clampedScore
        }

        let shown = clamp(smoothedScore, min: 0, max: 100)
        return Assessment(
            score: Int(shown.rounded()),
            confidence: Int((confidence * 100).rounded()),
            smoothedScore: smoothedScore,
            // How far the centre-pull moved the raw reading. Full confidence
            // collapses it to 0.
            uncertainty: Int(centrePull.rounded())
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
            sampleCount: usable.count
        )
    }

    /// Stress read against the person's own HRV and resting-HR baselines, the
    /// way every other channel in this scorer reads. Fixed population anchors
    /// (60 ms SDNN, 50 bpm) made "Relaxed" unreachable for normal older adults
    /// and disagreed with `StressScorer`, which is baseline-relative.
    ///
    /// Returns nil without both baselines: there is no honest population
    /// fallback here, so callers must show a no-data state instead.
    static func stressLevel(
        hrv: Double?,
        hrvBaseline: BaselineStats?,
        restingHeartRate: Double?,
        restingHeartRateBaseline: BaselineStats?
    ) -> Int? {
        guard let hrv, let restingHeartRate,
              let hrvBaseline, hrvBaseline.median > 0,
              let rhrBaseline = restingHeartRateBaseline, rhrBaseline.median > 0 else { return nil }

        let cap = ReadinessScorerConfig.stressChannelCap
        let deviationAtCap = max(ReadinessScorerConfig.stressDeviationAtCap, 0.0001)
        let hrvDrop = max(0, (hrvBaseline.median - hrv) / hrvBaseline.median)
        let rhrRise = max(0, (restingHeartRate - rhrBaseline.median) / rhrBaseline.median)
        let hrvStress = min(hrvDrop / deviationAtCap, 1.0) * cap
        let rhrStress = min(rhrRise / deviationAtCap, 1.0) * cap
        return Int((hrvStress + rhrStress).rounded())
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

    private static func hrvScore(current: Double, baseline: BaselineStats?) -> Double {
        if let baseline {
            let z = (current - baseline.median) / baseline.standardDeviation
            let normalized = tanh(z / ReadinessScorerConfig.hrvRhrTanhDivisor)
            return clamp(
                ReadinessScorerConfig.hrvRhrScoreCenter + normalized * ReadinessScorerConfig.hrvRhrScoreSpread,
                min: 0, max: 100
            )
        }

        return clamp(
            (current - ReadinessScorerConfig.hrvFallbackAnchor) / ReadinessScorerConfig.hrvFallbackRange * 100,
            min: 0, max: 100
        )
    }

    private static func rhrScore(current: Double, baseline: BaselineStats?) -> Double {
        if let baseline {
            let z = (baseline.median - current) / baseline.standardDeviation
            let normalized = tanh(z / ReadinessScorerConfig.hrvRhrTanhDivisor)
            return clamp(
                ReadinessScorerConfig.hrvRhrScoreCenter + normalized * ReadinessScorerConfig.hrvRhrScoreSpread,
                min: 0, max: 100
            )
        }

        return clamp(
            (ReadinessScorerConfig.rhrFallbackAnchor - current) / ReadinessScorerConfig.rhrFallbackRange * 100,
            min: 0, max: 100
        )
    }

    private static func sleepDurationScore(hours: Double) -> Double {
        let target = ReadinessScorerConfig.sleepTargetHours
        if hours < target {
            let deficit = target - hours
            let penalty = deficit * ReadinessScorerConfig.sleepDeficitLinearPenalty
                + deficit * deficit * ReadinessScorerConfig.sleepDeficitQuadraticPenalty
            return clamp(100 - penalty, min: ReadinessScorerConfig.sleepDurationDeficitFloor, max: 100)
        }

        let excess = hours - target
        let penalty = excess * ReadinessScorerConfig.sleepExcessLinearPenalty
            + excess * excess * ReadinessScorerConfig.sleepExcessQuadraticPenalty
        return clamp(100 - penalty, min: ReadinessScorerConfig.sleepDurationExcessFloor, max: 100)
    }

    private static func sleepStageScore(deep: TimeInterval, rem: TimeInterval, total: TimeInterval) -> Double {
        guard total > 0 else { return 50 }
        let restorativeRatio = (deep + rem) / total
        return clamp(
            (restorativeRatio - ReadinessScorerConfig.sleepRestorativeRatioFloor)
                / ReadinessScorerConfig.sleepRestorativeRatioRange * 100,
            min: 0, max: 100
        )
    }

    private static func workoutRecoveryScore(
        hoursSinceWorkout: Double,
        durationMinutes: Double,
        calories: Double?
    ) -> Double {
        let workoutLoad = min(
            1.0,
            max(
                durationMinutes / ReadinessScorerConfig.workoutLoadDurationCap,
                (calories ?? 0) / ReadinessScorerConfig.workoutLoadCalorieCap
            )
        )
        if hoursSinceWorkout < ReadinessScorerConfig.workoutRecoveryRecentBandHours {
            return ReadinessScorerConfig.workoutRecoveryRecentBase - workoutLoad * ReadinessScorerConfig.workoutRecoveryRecentLoadPenalty
        }
        if hoursSinceWorkout < ReadinessScorerConfig.workoutRecoveryMidBandHours {
            return ReadinessScorerConfig.workoutRecoveryMidBase - workoutLoad * ReadinessScorerConfig.workoutRecoveryMidLoadPenalty
        }
        return ReadinessScorerConfig.workoutRecoveryLateBase - workoutLoad * ReadinessScorerConfig.workoutRecoveryLateLoadPenalty
    }

    private static func freshnessConfidence(age: TimeInterval, maxAge: TimeInterval) -> Double {
        guard age.isFinite else { return ReadinessScorerConfig.freshnessFloor }
        let ratio = clamp(age / maxAge, min: 0, max: ReadinessScorerConfig.freshnessRatioClampMax)
        return clamp(
            1.0 - ratio * ReadinessScorerConfig.freshnessRatioWeight,
            min: ReadinessScorerConfig.freshnessFloor, max: 1.0
        )
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

}
