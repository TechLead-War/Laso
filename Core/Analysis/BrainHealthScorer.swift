import Foundation
import SwiftUI

// MARK: - Brain Health State

enum BrainHealthState: String, CaseIterable, Codable {
    case sharp
    case focused
    case baseline
    case foggy

    var displayName: String {
        switch self {
        case .sharp: return Copy.BrainHealth.stateSharp
        case .focused: return Copy.BrainHealth.stateFocused
        case .baseline: return Copy.BrainHealth.stateBaseline
        case .foggy: return Copy.BrainHealth.stateLowEnergy
        }
    }

    var color: Color {
        switch self {
        case .sharp: return AppColour.success
        case .focused: return AppColour.info
        case .baseline: return AppColour.stateDefault
        case .foggy: return AppColour.warning
        }
    }

    var icon: String {
        switch self {
        case .sharp: return "brain.head.profile.fill"
        case .focused: return "brain.fill"
        case .baseline: return "brain"
        case .foggy: return "cloud.fog.fill"
        }
    }

    /// Lower-bound score (inclusive) for the `sharp` state.
    static let sharpLowerBound: Int = 80
    /// Lower-bound score (inclusive) for the `focused` state (also upper-exclusive bound for `sharp`).
    static let focusedLowerBound: Int = 65
    /// Lower-bound score (inclusive) for the `baseline` state (also upper-exclusive bound for `focused`).
    static let baselineLowerBound: Int = 45

    init(score: Int) {
        switch score {
        case BrainHealthState.sharpLowerBound...100: self = .sharp
        case BrainHealthState.focusedLowerBound..<BrainHealthState.sharpLowerBound: self = .focused
        case BrainHealthState.baselineLowerBound..<BrainHealthState.focusedLowerBound: self = .baseline
        default: self = .foggy
        }
    }
}

// MARK: - Brain Health Score

struct BrainHealthScore {
    /// Overall brain health score from 0 (poor) to 100 (excellent)
    let score: Int
    /// Categorical brain health state derived from the score
    let state: BrainHealthState
    /// Cognitive readiness subscale (0-100) from HRV, deep sleep, REM, duration
    let cognitiveReadiness: Double
    /// Memory recovery subscale (0-100) based on REM + deep sleep quality
    let memoryRecovery: Double
    /// Inverse stress impact on cognition (0-100); higher = less stress = better
    let stressCognitionLoad: Double
    /// Neurovascular fitness subscale (0-100) from VO2max + cardio fitness
    let neurovascularFitness: Double
    /// Circadian alignment subscale (0-100) from sleep timing regularity
    let circadianAlignment: Double
    /// Deep sleep component score (0-100), normalized against personal baseline. Nil when no deep sleep data available.
    let deepSleepScore: Double?
    /// REM sleep component score (0-100), normalized against personal baseline. Nil when no REM data available.
    let remSleepScore: Double?
    /// Sleep duration component score (0-100), normalized against personal baseline. Nil when no duration data available.
    /// Top contributing factors with their direction and sentiment
    let topFactors: [(label: String, impact: String, isPositive: Bool)]
    /// Concise, data-backed headline summarizing the score
    let headline: String
    /// Confidence in the score based on data availability (0.0-1.0)
    let confidence: Double
}

// MARK: - Brain Health Scorer

/// Computes a brain health score (0-100) from physiological proxy signals,
/// combining cognitive readiness, memory recovery, stress-cognition load,
/// neurovascular fitness, and circadian alignment.
///
/// Requires at least 7 days of HRV data to establish a reliable personal baseline.
@Observable
final class BrainHealthScorer {

    // MARK: - Configuration

    private static let minimumDaysRequired = 7
    private static let baselineWindowDays = 14
    private static let recentWindowDays = 3
    /// Long enough to feed the trend card. Everything reading a shorter span
    /// takes its own suffix, so widening this does not move those numbers.
    private static let historyWindowDays = 90
    /// Days the improving/declining verdict compares across.
    private static let trendWindowDays = 14

    // Subscore weights (must sum to 1.0). Exposed (non-private) so the
    // Improve-Your-Score section can read them without duplicating magic numbers.
    static let cognitiveReadinessWeight = 0.30
    static let memoryRecoveryWeight = 0.25
    static let stressCognitionWeight = 0.20
    static let neurovascularWeight = 0.15
    static let circadianWeight = 0.10

    // MARK: - Score classification thresholds

    /// Score delta (points) above which `brainHealthTrend` reports "improving".
    private static let trendImprovingDelta = 5.0
    /// Score delta (points) below which `brainHealthTrend` reports "declining".
    private static let trendDecliningDelta = -5.0

    // MARK: - Stress-cognition scaling

    /// HRV drop fraction at which stress impact saturates (30% drop = max stress impact).
    private static let hrvDropMaxImpact: Double = 0.30
    /// RHR rise fraction at which stress impact saturates (15% rise = max stress impact).
    private static let rhrRiseMaxImpact: Double = 0.15

    // MARK: - Neurovascular score reference points

    /// VO2max value treated as the floor (poor) of the neurovascular subscore.
    private static let vo2MaxFloor: Double = 20
    /// Span (excellent − poor) of the VO2max scoring range.
    private static let vo2MaxRange: Double = 35
    /// Resting HR (bpm) treated as the ceiling (poor) of the RHR subscore.
    private static let rhrCeilingBpm: Double = 90
    /// Span (poor − excellent) of the RHR scoring range.
    private static let rhrRangeBpm: Double = 40
    /// Bonus added to the RHR score when the recent average is trending below the older average.
    private static let rhrTrendBonus: Double = 5
    /// Daily step count at/above which the steps subscore saturates.
    private static let stepsSaturation: Double = 12000

    // MARK: - Coefficient-of-variation thresholds

    /// Coefficient of variation at which circadian alignment is considered "poor" (score 0).
    private static let circadianCVPoor: Double = 0.30

    // MARK: - Top-factor thresholds

    /// Percent deviation from baseline above which HRV / sleep stages count as a top factor.
    private static let factorPercentThreshold: Double = 5
    /// Percent deviation from baseline above which RHR counts as a top factor (RHR is more sensitive).
    private static let rhrFactorPercentThreshold: Double = 3
    /// Circadian alignment score above which "consistent timing" is celebrated as a positive factor.
    private static let circadianStrongScore: Double = 80
    /// Circadian alignment score below which "irregular timing" is flagged as a negative factor.
    private static let circadianWeakScore: Double = 40

    // MARK: - Headline thresholds

    /// HRV multiplier above baseline that qualifies as "above baseline" for headlines.
    private static let headlineHRVAboveMultiplier: Double = 1.05
    /// REM/Deep multiplier above baseline that qualifies as "above baseline" for headlines.
    private static let headlineSleepAboveMultiplier: Double = 1.05
    /// HRV multiplier below baseline that qualifies as "below baseline" for foggy headlines.
    private static let headlineHRVBelowMultiplier: Double = 0.90
    /// REM multiplier below baseline that qualifies as "below baseline" for foggy headlines.
    private static let headlineREMBelowMultiplier: Double = 0.85

    // MARK: - Sample-size minimums

    /// Minimum samples required before a baseline (mean, sd) is computed.
    private static let minSamplesForBaseline = 5
    /// Minimum samples required for a recent-window summary statistic.
    private static let minSamplesForRecent = 3

    /// Number of trailing days included in the rolling weekly-average score.
    private static let weeklyAverageWindowDays = 7
    /// Minimum samples required before `weeklyAverage` is reported.
    private static let weeklyAverageMinSamples = 3
    /// HRV component weight inside the cognitive-readiness subscore.
    private static let cogReadinessHRVWeight: Double = 0.40
    /// Deep-sleep component weight inside the cognitive-readiness subscore.
    private static let cogReadinessDeepWeight: Double = 0.30
    /// REM-sleep component weight inside the cognitive-readiness subscore.
    private static let cogReadinessREMWeight: Double = 0.20
    /// Sleep-duration component weight inside the cognitive-readiness subscore.
    private static let cogReadinessDurationWeight: Double = 0.10
    /// REM weight inside the memory-recovery subscore.
    private static let memoryRecoveryREMWeight: Double = 0.50
    /// Deep-sleep weight inside the memory-recovery subscore.
    private static let memoryRecoveryDeepWeight: Double = 0.50
    /// VO2max weight inside the neurovascular-fitness subscore.
    private static let neuroVO2Weight: Double = 0.50
    /// Resting-HR weight inside the neurovascular-fitness subscore.
    private static let neuroRHRWeight: Double = 0.30
    /// Steps weight inside the neurovascular-fitness subscore.
    private static let neuroStepsWeight: Double = 0.20
    /// Trailing window (days) used for the resting-HR recent average.
    private static let neuroRHRRecentDays = 7
    /// Trailing window (days) used for the resting-HR older comparison average.
    private static let neuroRHROlderDays = 14
    /// Trailing window (days) used for the steps recent average.
    private static let neuroStepsRecentDays = 7
    /// Trailing window (days) used for circadian alignment variability calculation.
    private static let circadianWindowDays = 7
    /// Trailing window (days) used when fetching the most-recent daily VO2 value.
    private static let mostRecentVO2LookbackDays = 2
    /// Z-score lower bound (z = -2 maps to 0) used by `normalizeZScore`.
    private static let zScoreNormLower: Double = -2.0
    /// Span of the z-score window normalized by `normalizeZScore` (z range [-2, +2] = 4).
    private static let zScoreNormSpan: Double = 4.0
    /// 0-100 score scale used to convert a normalized z-score into a subscore.
    private static let subscoreScale: Double = 100.0
    /// Default subscore returned when a component cannot be computed (mid-scale).
    private static let subscoreDefault: Double = 50.0
    /// Confidence baseline contribution from having HRV data.
    private static let confidenceHRVBase: Double = 0.40
    /// Confidence contribution from each of deep, REM, RHR signals.
    private static let confidenceDeepBonus: Double = 0.15
    private static let confidenceREMBonus: Double = 0.15
    private static let confidenceRHRBonus: Double = 0.10
    private static let confidenceVO2Bonus: Double = 0.05
    private static let confidenceDurationBonus: Double = 0.05
    /// Maximum HRV-stability confidence bonus.
    private static let confidenceStabilityBonusCap: Double = 0.10
    /// Coefficient of variation at which the HRV-stability bonus reaches its cap.
    private static let stabilityFullStrengthCV: Double = 0.1
    /// Coefficient of variation span over which the HRV-stability bonus decays to zero.
    private static let stabilityCVRange: Double = 0.3
    /// Reference midpoint subtracted from circadian alignment when computing factor magnitudes.
    private static let circadianFactorMidpoint: Double = 50

    // MARK: - Outputs

    /// The most recently computed brain health score, or nil if insufficient data
    private(set) var currentScore: BrainHealthScore?

    /// Whether the scorer has enough data to produce a meaningful result (7+ days of HRV)
    private(set) var isReady: Bool = false

    /// Daily brain health scores, oldest first, over `historyWindowDays`.
    private(set) var weeklyHistory: [(date: Date, score: Int)] = []

    /// Average brain health score over the last 7 days, or nil if insufficient history
    var weeklyAverage: Int? {
        let last7 = weeklyHistory.suffix(Self.weeklyAverageWindowDays)
        guard last7.count >= Self.weeklyAverageMinSamples else { return nil }
        let sum = last7.map(\.score).reduce(0, +)
        return sum / last7.count
    }

    /// Trend direction of brain health over the recent history
    var brainHealthTrend: String {
        guard weeklyHistory.count >= Self.weeklyAverageWindowDays else { return Copy.BrainHealth.trendStable }

        // Pinned to the recent window. Halving the whole history would quietly
        // turn this into a 45 day comparison now that history runs to 90 days.
        let recent = weeklyHistory.suffix(Self.trendWindowDays)
        let halfPoint = recent.count / 2
        let firstHalf = recent.prefix(halfPoint)
        let secondHalf = recent.suffix(halfPoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return Copy.BrainHealth.trendStable }

        let firstAvg = Double(firstHalf.map(\.score).reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.map(\.score).reduce(0, +)) / Double(secondHalf.count)

        let delta = secondAvg - firstAvg
        if delta > Self.trendImprovingDelta { return Copy.BrainHealth.trendImproving }
        if delta < Self.trendDecliningDelta { return Copy.BrainHealth.trendDeclining }
        return Copy.BrainHealth.trendStable
    }

    // MARK: - Compute

    /// Compute the brain health score from the health data store.
    ///
    /// Builds personal baselines for HRV, sleep stages, heart rate, VO2max, and activity,
    /// then scores the most recent values against those baselines across five subscales.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store containing metric time series.
    ///   - timeSeries: Optional in-memory time series for guaranteed freshness (falls back to store).
    @MainActor
    func compute(from store: HealthDataStore, timeSeries: [HealthMetric: MetricTimeSeries]? = nil) {
        let allSeries = timeSeries ?? store.loadAllTimeSeries()

        guard let hrvSeries = allSeries[.heartRateVariability],
              hrvSeries.daysOfData >= Self.minimumDaysRequired else {
            isReady = false
            currentScore = nil
            weeklyHistory = []
            return
        }

        isReady = true

        // Gather all available series
        let deepSeries = allSeries[.sleepDeep]
        let remSeries = allSeries[.sleepREM]
        let durationSeries = allSeries[.sleepDuration]
        let rhrSeries = allSeries[.restingHeartRate]
        let vo2Series = allSeries[.vo2Max]
        let stepsSeries = allSeries[.steps]

        // Build baselines
        let hrvBaseline = computeBaseline(hrvSeries, days: Self.baselineWindowDays)
        let deepBaseline = deepSeries.flatMap { computeBaseline($0, days: Self.baselineWindowDays) }
        let remBaseline = remSeries.flatMap { computeBaseline($0, days: Self.baselineWindowDays) }
        let durationBaseline = durationSeries.flatMap { computeBaseline($0, days: Self.baselineWindowDays) }
        let rhrBaseline = rhrSeries.flatMap { computeBaseline($0, days: Self.baselineWindowDays) }

        // Recent averages (3-day)
        let recentHRV = recentAverage(hrvSeries, days: Self.recentWindowDays)
        let recentDeep = deepSeries.flatMap { recentAverage($0, days: Self.recentWindowDays) }
        let recentREM = remSeries.flatMap { recentAverage($0, days: Self.recentWindowDays) }
        let recentDuration = durationSeries.flatMap { recentAverage($0, days: Self.recentWindowDays) }
        let recentRHR = rhrSeries.flatMap { recentAverage($0, days: Self.recentWindowDays) }

        guard let hrvBase = hrvBaseline, let currentHRV = recentHRV else {
            currentScore = nil
            weeklyHistory = []
            return
        }

        // --- Subscale 1: Cognitive Readiness (30%) ---
        let cognitiveReadiness = computeCognitiveReadiness(
            currentHRV: currentHRV, hrvBaseline: hrvBase,
            currentDeep: recentDeep, deepBaseline: deepBaseline,
            currentREM: recentREM, remBaseline: remBaseline,
            currentDuration: recentDuration, durationBaseline: durationBaseline
        )

        // --- Subscale 2: Memory & Recovery (25%) ---
        let memoryRecovery = computeMemoryRecovery(
            currentREM: recentREM, remBaseline: remBaseline,
            currentDeep: recentDeep, deepBaseline: deepBaseline
        )

        // --- Subscale 3: Stress-Cognition Load (20%) ---
        let stressCognitionLoad = computeStressCognitionLoad(
            currentHRV: currentHRV, hrvBaseline: hrvBase,
            currentRHR: recentRHR, rhrBaseline: rhrBaseline
        )

        // --- Subscale 4: Neurovascular Fitness (15%) ---
        let neurovascularFitness = computeNeurovascularFitness(
            vo2Series: vo2Series,
            rhrSeries: rhrSeries,
            stepsSeries: stepsSeries
        )

        // --- Subscale 5: Circadian Alignment (10%) ---
        let circadianAlignment = computeCircadianAlignment(durationSeries: durationSeries)

        // Weighted composite
        let rawScore = cognitiveReadiness * Self.cognitiveReadinessWeight
            + memoryRecovery * Self.memoryRecoveryWeight
            + stressCognitionLoad * Self.stressCognitionWeight
            + neurovascularFitness * Self.neurovascularWeight
            + circadianAlignment * Self.circadianWeight

        let finalScore = Int(min(100, max(0, rawScore)).rounded())
        let state = BrainHealthState(score: finalScore)

        // Build top factors
        let topFactors = buildTopFactors(
            circadianAlignment: circadianAlignment,
            currentHRV: currentHRV, hrvBaseline: hrvBase,
            currentREM: recentREM, remBaseline: remBaseline,
            currentDeep: recentDeep, deepBaseline: deepBaseline,
            currentRHR: recentRHR, rhrBaseline: rhrBaseline
        )

        // Build headline
        let headline = buildHeadline(
            state: state,
            currentHRV: currentHRV, hrvBaseline: hrvBase,
            currentREM: recentREM, remBaseline: remBaseline,
            currentDeep: recentDeep, deepBaseline: deepBaseline
        )

        // Confidence
        let confidence = computeConfidence(
            hasDeep: deepSeries != nil,
            hasREM: remSeries != nil,
            hasRHR: rhrSeries != nil,
            hasVO2: vo2Series != nil,
            hasDuration: durationSeries != nil,
            hrvBaseline: hrvBase
        )

        // Individual sleep stage component scores (0-100) for direct display
        let deepSleepScore: Double? = {
            guard let deep = recentDeep, let deepBase = deepBaseline else { return nil }
            let z = zScore(current: deep, baseline: deepBase)
            return normalizeZScore(z) * 100.0
        }()

        let remSleepScore: Double? = {
            guard let rem = recentREM, let remBase = remBaseline else { return nil }
            let z = zScore(current: rem, baseline: remBase)
            return normalizeZScore(z) * 100.0
        }()

        currentScore = BrainHealthScore(
            score: finalScore,
            state: state,
            cognitiveReadiness: cognitiveReadiness,
            memoryRecovery: memoryRecovery,
            stressCognitionLoad: stressCognitionLoad,
            neurovascularFitness: neurovascularFitness,
            circadianAlignment: circadianAlignment,
            deepSleepScore: deepSleepScore,
            remSleepScore: remSleepScore,
            topFactors: topFactors,
            headline: headline,
            confidence: confidence
        )

        // Build daily history for the last 14 days
        buildWeeklyHistory(
            allSeries: allSeries,
            hrvSeries: hrvSeries
        )
    }

    // MARK: - Subscale Computations

    /// Cognitive Readiness: HRV (40%), Deep sleep (30%), REM (20%), Duration (10%)
    private func computeCognitiveReadiness(
        currentHRV: Double, hrvBaseline: (mean: Double, sd: Double),
        currentDeep: Double?, deepBaseline: (mean: Double, sd: Double)?,
        currentREM: Double?, remBaseline: (mean: Double, sd: Double)?,
        currentDuration: Double?, durationBaseline: (mean: Double, sd: Double)?
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0

        // HRV z-score
        let hrvZ = zScore(current: currentHRV, baseline: hrvBaseline)
        let hrvNorm = normalizeZScore(hrvZ)
        weightedSum += hrvNorm * Self.cogReadinessHRVWeight
        totalWeight += Self.cogReadinessHRVWeight

        // Deep sleep z-score
        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepZ = zScore(current: deep, baseline: deepBase)
            weightedSum += normalizeZScore(deepZ) * Self.cogReadinessDeepWeight
            totalWeight += Self.cogReadinessDeepWeight
        }

        // REM sleep z-score
        if let rem = currentREM, let remBase = remBaseline {
            let remZ = zScore(current: rem, baseline: remBase)
            weightedSum += normalizeZScore(remZ) * Self.cogReadinessREMWeight
            totalWeight += Self.cogReadinessREMWeight
        }

        // Sleep duration z-score
        if let dur = currentDuration, let durBase = durationBaseline {
            let durZ = zScore(current: dur, baseline: durBase)
            weightedSum += normalizeZScore(durZ) * Self.cogReadinessDurationWeight
            totalWeight += Self.cogReadinessDurationWeight
        }

        // Re-normalize if some components are missing
        guard totalWeight > 0 else { return Self.subscoreDefault }
        return weightedSum / totalWeight * Self.subscoreScale
    }

    /// Memory & Recovery: REM (50%), Deep sleep (50%)
    private func computeMemoryRecovery(
        currentREM: Double?, remBaseline: (mean: Double, sd: Double)?,
        currentDeep: Double?, deepBaseline: (mean: Double, sd: Double)?
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0

        if let rem = currentREM, let remBase = remBaseline {
            let remZ = zScore(current: rem, baseline: remBase)
            weightedSum += normalizeZScore(remZ) * Self.memoryRecoveryREMWeight
            totalWeight += Self.memoryRecoveryREMWeight
        }

        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepZ = zScore(current: deep, baseline: deepBase)
            weightedSum += normalizeZScore(deepZ) * Self.memoryRecoveryDeepWeight
            totalWeight += Self.memoryRecoveryDeepWeight
        }

        guard totalWeight > 0 else { return Self.subscoreDefault }
        return weightedSum / totalWeight * Self.subscoreScale
    }

    /// Stress-Cognition Load: inverse of stress impact (higher = less stress = better for brain)
    private func computeStressCognitionLoad(
        currentHRV: Double, hrvBaseline: (mean: Double, sd: Double),
        currentRHR: Double?, rhrBaseline: (mean: Double, sd: Double)?
    ) -> Double {
        var stressImpact = 0.0
        var components = 0

        // HRV below baseline = higher stress impact
        if hrvBaseline.mean > 0 {
            let hrvDrop = max(0, (hrvBaseline.mean - currentHRV) / hrvBaseline.mean)
            // Scale: 0% drop = 0 impact, hrvDropMaxImpact (e.g. 30%) drop = 100 impact
            stressImpact += min(Self.subscoreScale, hrvDrop / Self.hrvDropMaxImpact * Self.subscoreScale)
            components += 1
        }

        // RHR above baseline = higher stress impact
        if let rhr = currentRHR, let rhrBase = rhrBaseline, rhrBase.mean > 0 {
            let rhrRise = max(0, (rhr - rhrBase.mean) / rhrBase.mean)
            // Scale: 0% rise = 0 impact, rhrRiseMaxImpact (e.g. 15%) rise = 100 impact
            stressImpact += min(Self.subscoreScale, rhrRise / Self.rhrRiseMaxImpact * Self.subscoreScale)
            components += 1
        }

        guard components > 0 else { return Self.subscoreDefault }
        let avgStress = stressImpact / Double(components)
        return max(0, min(Self.subscoreScale, Self.subscoreScale - avgStress))
    }

    /// Neurovascular Fitness: VO2max level, resting HR trend, activity consistency
    private func computeNeurovascularFitness(
        vo2Series: MetricTimeSeries?,
        rhrSeries: MetricTimeSeries?,
        stepsSeries: MetricTimeSeries?
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0

        // VO2max component (simple population-norm scale)
        if let vo2 = vo2Series, let recentVO2 = mostRecentDailyValue(vo2) {
            // General population scale: vo2MaxFloor = poor, fair, good, excellent at floor + range
            let vo2Score = min(Self.subscoreScale, max(0, (recentVO2 - Self.vo2MaxFloor) / Self.vo2MaxRange * Self.subscoreScale))
            weightedSum += vo2Score * Self.neuroVO2Weight
            totalWeight += Self.neuroVO2Weight
        }

        // Resting HR component. lower is generally better, declining trend is good
        if let rhr = rhrSeries {
            let recentSamples = rhr.samples(lastDays: Self.neuroRHRRecentDays)
            let olderSamples = rhr.samples(lastDays: Self.neuroRHROlderDays)
            if recentSamples.count >= Self.minSamplesForRecent, olderSamples.count >= Self.minSamplesForBaseline {
                let recentMean = recentSamples.mean(of: \.value)
                let olderMean = olderSamples.mean(of: \.value)
                // Lower RHR = better; score based on absolute level
                let levelScore = min(Self.subscoreScale, max(0, (Self.rhrCeilingBpm - recentMean) / Self.rhrRangeBpm * Self.subscoreScale))
                // Trending down adds a small bonus
                let trendBonus = olderMean > recentMean ? Self.rhrTrendBonus : 0.0
                weightedSum += min(Self.subscoreScale, levelScore + trendBonus) * Self.neuroRHRWeight
                totalWeight += Self.neuroRHRWeight
            }
        }

        // Steps/activity consistency
        if let steps = stepsSeries {
            let recentSteps = steps.samples(lastDays: Self.neuroStepsRecentDays)
            if recentSteps.count >= Self.minSamplesForRecent {
                let avgSteps = recentSteps.mean(of: \.value)
                // Saturates at stepsSaturation (e.g. 12k = high)
                let stepsScore = min(Self.subscoreScale, max(0, avgSteps / Self.stepsSaturation * Self.subscoreScale))
                weightedSum += stepsScore * Self.neuroStepsWeight
                totalWeight += Self.neuroStepsWeight
            }
        }

        guard totalWeight > 0 else { return Self.subscoreDefault }
        return weightedSum / totalWeight
    }

    /// Circadian Alignment: sleep duration variability over last 7 days
    private func computeCircadianAlignment(durationSeries: MetricTimeSeries?) -> Double {
        guard let dur = durationSeries else { return Self.subscoreDefault }

        let recentSamples = dur.samples(lastDays: Self.circadianWindowDays)
        guard recentSamples.count >= Self.minSamplesForRecent else { return Self.subscoreDefault }

        let values = recentSamples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return Self.subscoreDefault }

        // Compute standard deviation of sleep duration
        var sumOfSquares = 0.0
        for value in values {
            let delta = value - mean
            sumOfSquares += delta * delta
        }
        let sd = (sumOfSquares / Double(values.count)).squareRoot()

        // Coefficient of variation: lower = more consistent = better alignment
        let cv = sd / mean
        // CV of 0 = perfect (100), CV of circadianCVPoor+ = poor (0)
        let score = min(Self.subscoreScale, max(0, (1.0 - cv / Self.circadianCVPoor) * Self.subscoreScale))
        return score
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

    /// Get the most recent daily average value from a time series (last 2 days)
    private func mostRecentDailyValue(_ series: MetricTimeSeries) -> Double? {
        let recent = series.samples(lastDays: Self.mostRecentVO2LookbackDays)
        guard !recent.isEmpty else { return nil }
        return recent.last?.value
    }

    /// Get the average value over the last N days
    private func recentAverage(_ series: MetricTimeSeries, days: Int) -> Double? {
        let samples = series.samples(lastDays: days)
        guard !samples.isEmpty else { return nil }
        return samples.mean(of: \.value)
    }

    /// Z-score of a current value relative to a baseline
    private func zScore(current: Double, baseline: (mean: Double, sd: Double)) -> Double {
        guard baseline.sd > 0 else {
            // No variability. return direction based on difference from mean
            if current > baseline.mean { return 1.0 }
            if current < baseline.mean { return -1.0 }
            return 0.0
        }
        return (current - baseline.mean) / baseline.sd
    }

    /// Normalize a z-score to 0-1 range: z of -2 → 0, z of +2 → 1
    private func normalizeZScore(_ z: Double) -> Double {
        min(max((z - Self.zScoreNormLower) / Self.zScoreNormSpan, 0), 1)
    }

    /// Compute confidence based on data availability
    private func computeConfidence(
        hasDeep: Bool,
        hasREM: Bool,
        hasRHR: Bool,
        hasVO2: Bool,
        hasDuration: Bool,
        hrvBaseline: (mean: Double, sd: Double)
    ) -> Double {
        // HRV is mandatory and provides base confidence
        var confidence = Self.confidenceHRVBase

        // Each additional signal adds confidence
        if hasDeep { confidence += Self.confidenceDeepBonus }
        if hasREM { confidence += Self.confidenceREMBonus }
        if hasRHR { confidence += Self.confidenceRHRBonus }
        if hasVO2 { confidence += Self.confidenceVO2Bonus }
        if hasDuration { confidence += Self.confidenceDurationBonus }

        // Baseline stability bonus
        if hrvBaseline.mean > 0 {
            let cv = hrvBaseline.sd / hrvBaseline.mean
            let stabilityBonus = max(0, min(
                Self.confidenceStabilityBonusCap,
                Self.confidenceStabilityBonusCap * (1.0 - (cv - Self.stabilityFullStrengthCV) / Self.stabilityCVRange)
            ))
            confidence += stabilityBonus
        }

        return min(1.0, confidence)
    }

    // MARK: - Top Factors

    private func buildTopFactors(
        circadianAlignment: Double,
        currentHRV: Double, hrvBaseline: (mean: Double, sd: Double),
        currentREM: Double?, remBaseline: (mean: Double, sd: Double)?,
        currentDeep: Double?, deepBaseline: (mean: Double, sd: Double)?,
        currentRHR: Double?, rhrBaseline: (mean: Double, sd: Double)?
    ) -> [(label: String, impact: String, isPositive: Bool)] {
        var factors: [(label: String, impact: String, isPositive: Bool, magnitude: Double)] = []

        // HRV factor
        let hrvPct = (currentHRV - hrvBaseline.mean) / max(hrvBaseline.mean, 1) * 100
        if abs(hrvPct) > Self.factorPercentThreshold {
            let isPositive = hrvPct > 0
            let direction = isPositive ? Copy.BrainHealth.directionAbove : Copy.BrainHealth.directionBelow
            factors.append((
                label: Copy.BrainHealth.factorHRV,
                impact: Copy.BrainHealth.percentAboveBelowBaseline(Int(abs(hrvPct)), direction: direction),
                isPositive: isPositive,
                magnitude: abs(hrvPct)
            ))
        }

        // REM factor
        if let rem = currentREM, let remBase = remBaseline {
            let remPct = (rem - remBase.mean) / max(remBase.mean, 1) * 100
            if abs(remPct) > Self.factorPercentThreshold {
                let isPositive = remPct > 0
                let direction = isPositive ? Copy.BrainHealth.directionAbove : Copy.BrainHealth.directionBelow
                factors.append((
                    label: Copy.BrainHealth.factorREM,
                    impact: Copy.BrainHealth.directionBaseline(direction),
                    isPositive: isPositive,
                    magnitude: abs(remPct)
                ))
            }
        }

        // Deep sleep factor
        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepPct = (deep - deepBase.mean) / max(deepBase.mean, 1) * 100
            if abs(deepPct) > Self.factorPercentThreshold {
                let isPositive = deepPct > 0
                let direction = isPositive ? Copy.BrainHealth.directionAbove : Copy.BrainHealth.directionBelow
                factors.append((
                    label: Copy.BrainHealth.factorDeepSleep,
                    impact: Copy.BrainHealth.directionBaseline(direction),
                    isPositive: isPositive,
                    magnitude: abs(deepPct)
                ))
            }
        }

        // Resting HR factor
        if let rhr = currentRHR, let rhrBase = rhrBaseline {
            let rhrPct = (rhr - rhrBase.mean) / max(rhrBase.mean, 1) * 100
            if abs(rhrPct) > Self.rhrFactorPercentThreshold {
                // Lower is better for RHR — flip the polarity.
                let isPositive = rhrPct < 0
                let direction = rhrPct < 0 ? Copy.BrainHealth.directionBelow : Copy.BrainHealth.directionAbove
                factors.append((
                    label: Copy.BrainHealth.factorRestingHR,
                    impact: Copy.BrainHealth.directionBaseline(direction),
                    isPositive: isPositive,
                    magnitude: abs(rhrPct)
                ))
            }
        }

        // Circadian alignment factor
        if circadianAlignment > Self.circadianStrongScore {
            factors.append((
                label: Copy.BrainHealth.factorSleepSchedule,
                impact: Copy.BrainHealth.timingConsistent,
                isPositive: true,
                magnitude: circadianAlignment - Self.circadianFactorMidpoint
            ))
        } else if circadianAlignment < Self.circadianWeakScore {
            factors.append((
                label: Copy.BrainHealth.factorSleepSchedule,
                impact: Copy.BrainHealth.timingIrregular,
                isPositive: false,
                magnitude: Self.circadianFactorMidpoint - circadianAlignment
            ))
        }

        // Sort by magnitude descending, take top 3
        factors.sort { $0.magnitude > $1.magnitude }
        return factors.prefix(3).map { (label: $0.label, impact: $0.impact, isPositive: $0.isPositive) }
    }

    // MARK: - Headline

    private func buildHeadline(
        state: BrainHealthState,
        currentHRV: Double, hrvBaseline: (mean: Double, sd: Double),
        currentREM: Double?, remBaseline: (mean: Double, sd: Double)?,
        currentDeep: Double?, deepBaseline: (mean: Double, sd: Double)?
    ) -> String {
        let hrvAbove = currentHRV > hrvBaseline.mean * Self.headlineHRVAboveMultiplier
        let remAbove: Bool = {
            guard let rem = currentREM, let base = remBaseline else { return false }
            return rem > base.mean * Self.headlineSleepAboveMultiplier
        }()
        let deepAbove: Bool = {
            guard let deep = currentDeep, let base = deepBaseline else { return false }
            return deep > base.mean * Self.headlineSleepAboveMultiplier
        }()

        switch state {
        case .sharp:
            if hrvAbove && remAbove {
                return Copy.BrainHealth.headlineSharpStrong
            } else if hrvAbove {
                return Copy.BrainHealth.headlineSharpHRV
            } else if remAbove && deepAbove {
                return Copy.BrainHealth.headlineSharpSleep
            } else {
                return Copy.BrainHealth.headlineSharpDefault
            }

        case .focused:
            if hrvAbove {
                return Copy.BrainHealth.headlineFocusedHRV
            } else if remAbove || deepAbove {
                return Copy.BrainHealth.headlineFocusedSleep
            } else {
                return Copy.BrainHealth.headlineFocusedDefault
            }

        case .baseline:
            if !hrvAbove && !remAbove {
                return Copy.BrainHealth.headlineBaselineSteady
            } else {
                return Copy.BrainHealth.headlineBaselineMixed
            }

        case .foggy:
            let hrvBelow = currentHRV < hrvBaseline.mean * Self.headlineHRVBelowMultiplier
            let remBelow: Bool = {
                guard let rem = currentREM, let base = remBaseline else { return false }
                return rem < base.mean * Self.headlineREMBelowMultiplier
            }()
            if hrvBelow && remBelow {
                return Copy.BrainHealth.headlineFoggyBoth
            } else if hrvBelow {
                return Copy.BrainHealth.headlineFoggyHRV
            } else {
                return Copy.BrainHealth.headlineFoggySleep
            }
        }
    }

    // MARK: - Daily History

    /// Build the last 14 days of daily brain health scores
    private func buildWeeklyHistory(
        allSeries: [HealthMetric: MetricTimeSeries],
        hrvSeries: MetricTimeSeries
    ) {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let historyDays = Self.historyWindowDays
        let lookbackDays = historyDays + Self.baselineWindowDays

        // Build per-day lookups
        let hrvByDay = buildDailyLookup(hrvSeries.samples(lastDays: lookbackDays))
        let deepByDay = allSeries[.sleepDeep].map { buildDailyLookup($0.samples(lastDays: lookbackDays)) } ?? [:]
        let remByDay = allSeries[.sleepREM].map { buildDailyLookup($0.samples(lastDays: lookbackDays)) } ?? [:]
        let durationByDay = allSeries[.sleepDuration].map { buildDailyLookup($0.samples(lastDays: lookbackDays)) } ?? [:]
        let rhrByDay = allSeries[.restingHeartRate].map { buildDailyLookup($0.samples(lastDays: lookbackDays)) } ?? [:]

        var history: [(date: Date, score: Int)] = []

        for dayOffset in (0..<historyDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            // Need at least HRV for this day
            guard let dayHRV = hrvByDay[dayStart] else { continue }

            // Trailing baselines
            let hrvBase = trailingBaseline(from: hrvByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
            guard let hrvB = hrvBase, hrvB.mean > 0 else { continue }

            let deepBase = trailingBaseline(from: deepByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
            let remBase = trailingBaseline(from: remByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
            let durBase = trailingBaseline(from: durationByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)
            let rhrBase = trailingBaseline(from: rhrByDay, before: dayStart, days: Self.baselineWindowDays, calendar: calendar)

            // Compute subscores for this day
            let cogReady = computeCognitiveReadiness(
                currentHRV: dayHRV, hrvBaseline: hrvB,
                currentDeep: deepByDay[dayStart], deepBaseline: deepBase,
                currentREM: remByDay[dayStart], remBaseline: remBase,
                currentDuration: durationByDay[dayStart], durationBaseline: durBase
            )

            let memRec = computeMemoryRecovery(
                currentREM: remByDay[dayStart], remBaseline: remBase,
                currentDeep: deepByDay[dayStart], deepBaseline: deepBase
            )

            let stressLoad = computeStressCognitionLoad(
                currentHRV: dayHRV, hrvBaseline: hrvB,
                currentRHR: rhrByDay[dayStart], rhrBaseline: rhrBase
            )

            // Simplified neurovascular and circadian for daily history (use defaults)
            let neuro = 50.0
            let circadian = 50.0

            let rawScore = cogReady * Self.cognitiveReadinessWeight
                + memRec * Self.memoryRecoveryWeight
                + stressLoad * Self.stressCognitionWeight
                + neuro * Self.neurovascularWeight
                + circadian * Self.circadianWeight

            let dayScore = Int(min(100, max(0, rawScore)).rounded())
            history.append((date: dayStart, score: dayScore))
        }

        weeklyHistory = history
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
