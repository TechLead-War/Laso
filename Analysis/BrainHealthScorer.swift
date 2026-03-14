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
        case .sharp: return "Sharp"
        case .focused: return "Focused"
        case .baseline: return "Baseline"
        case .foggy: return "Foggy"
        }
    }

    var color: Color {
        switch self {
        case .sharp: return .green
        case .focused: return .blue
        case .baseline: return .gray
        case .foggy: return .orange
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

    init(score: Int) {
        switch score {
        case 80...100: self = .sharp
        case 65..<80: self = .focused
        case 45..<65: self = .baseline
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
    private static let historyWindowDays = 14

    // Subscore weights (must sum to 1.0)
    private static let cognitiveReadinessWeight = 0.30
    private static let memoryRecoveryWeight = 0.25
    private static let stressCognitionWeight = 0.20
    private static let neurovascularWeight = 0.15
    private static let circadianWeight = 0.10

    // MARK: - Outputs

    /// The most recently computed brain health score, or nil if insufficient data
    private(set) var currentScore: BrainHealthScore?

    /// Whether the scorer has enough data to produce a meaningful result (7+ days of HRV)
    private(set) var isReady: Bool = false

    /// Daily brain health scores for the last 14 days
    private(set) var weeklyHistory: [(date: Date, score: Int)] = []

    /// Average brain health score over the last 7 days, or nil if insufficient history
    var weeklyAverage: Int? {
        let last7 = weeklyHistory.suffix(7)
        guard last7.count >= 3 else { return nil }
        let sum = last7.map(\.score).reduce(0, +)
        return sum / last7.count
    }

    /// Trend direction of brain health over the recent history
    var brainHealthTrend: String {
        guard weeklyHistory.count >= 7 else { return "stable" }

        let count = weeklyHistory.count
        let halfPoint = count / 2
        let firstHalf = weeklyHistory.prefix(halfPoint)
        let secondHalf = weeklyHistory.suffix(halfPoint)

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return "stable" }

        let firstAvg = Double(firstHalf.map(\.score).reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.map(\.score).reduce(0, +)) / Double(secondHalf.count)

        let delta = secondAvg - firstAvg
        if delta > 5.0 { return "improving" }
        if delta < -5.0 { return "declining" }
        return "stable"
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
            cognitiveReadiness: cognitiveReadiness,
            memoryRecovery: memoryRecovery,
            stressCognitionLoad: stressCognitionLoad,
            neurovascularFitness: neurovascularFitness,
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

        currentScore = BrainHealthScore(
            score: finalScore,
            state: state,
            cognitiveReadiness: cognitiveReadiness,
            memoryRecovery: memoryRecovery,
            stressCognitionLoad: stressCognitionLoad,
            neurovascularFitness: neurovascularFitness,
            circadianAlignment: circadianAlignment,
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

        // HRV z-score (40% of sub)
        let hrvZ = zScore(current: currentHRV, baseline: hrvBaseline)
        let hrvNorm = normalizeZScore(hrvZ)
        weightedSum += hrvNorm * 0.40
        totalWeight += 0.40

        // Deep sleep z-score (30% of sub)
        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepZ = zScore(current: deep, baseline: deepBase)
            weightedSum += normalizeZScore(deepZ) * 0.30
            totalWeight += 0.30
        }

        // REM sleep z-score (20% of sub)
        if let rem = currentREM, let remBase = remBaseline {
            let remZ = zScore(current: rem, baseline: remBase)
            weightedSum += normalizeZScore(remZ) * 0.20
            totalWeight += 0.20
        }

        // Sleep duration z-score (10% of sub)
        if let dur = currentDuration, let durBase = durationBaseline {
            let durZ = zScore(current: dur, baseline: durBase)
            weightedSum += normalizeZScore(durZ) * 0.10
            totalWeight += 0.10
        }

        // Re-normalize if some components are missing
        guard totalWeight > 0 else { return 50.0 }
        return weightedSum / totalWeight * 100.0
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
            weightedSum += normalizeZScore(remZ) * 0.50
            totalWeight += 0.50
        }

        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepZ = zScore(current: deep, baseline: deepBase)
            weightedSum += normalizeZScore(deepZ) * 0.50
            totalWeight += 0.50
        }

        guard totalWeight > 0 else { return 50.0 }
        return weightedSum / totalWeight * 100.0
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
            // Scale: 0% drop = 0 impact, 30%+ drop = 100 impact
            stressImpact += min(100, hrvDrop / 0.30 * 100.0)
            components += 1
        }

        // RHR above baseline = higher stress impact
        if let rhr = currentRHR, let rhrBase = rhrBaseline, rhrBase.mean > 0 {
            let rhrRise = max(0, (rhr - rhrBase.mean) / rhrBase.mean)
            // Scale: 0% rise = 0 impact, 15%+ rise = 100 impact
            stressImpact += min(100, rhrRise / 0.15 * 100.0)
            components += 1
        }

        guard components > 0 else { return 50.0 }
        let avgStress = stressImpact / Double(components)
        return max(0, min(100, 100 - avgStress))
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
            // General population scale: 20 = poor, 35 = fair, 45 = good, 55+ = excellent
            let vo2Score = min(100, max(0, (recentVO2 - 20.0) / 35.0 * 100.0))
            weightedSum += vo2Score * 0.50
            totalWeight += 0.50
        }

        // Resting HR component — lower is generally better, declining trend is good
        if let rhr = rhrSeries {
            let recentSamples = rhr.samples(lastDays: 7)
            let olderSamples = rhr.samples(lastDays: 14)
            if recentSamples.count >= 3, olderSamples.count >= 5 {
                let recentMean = recentSamples.mean(of: \.value)
                let olderMean = olderSamples.mean(of: \.value)
                // Lower RHR = better; score based on absolute level
                // 50 bpm = excellent (100), 70 bpm = average (50), 90+ bpm = poor (0)
                let levelScore = min(100, max(0, (90.0 - recentMean) / 40.0 * 100.0))
                // Trending down adds a small bonus
                let trendBonus = olderMean > recentMean ? 5.0 : 0.0
                weightedSum += min(100, levelScore + trendBonus) * 0.30
                totalWeight += 0.30
            }
        }

        // Steps/activity consistency
        if let steps = stepsSeries {
            let recentSteps = steps.samples(lastDays: 7)
            if recentSteps.count >= 3 {
                let avgSteps = recentSteps.mean(of: \.value)
                // 4000 = low (30), 8000 = moderate (60), 12000+ = high (100)
                let stepsScore = min(100, max(0, avgSteps / 12000.0 * 100.0))
                weightedSum += stepsScore * 0.20
                totalWeight += 0.20
            }
        }

        guard totalWeight > 0 else { return 50.0 }
        return weightedSum / totalWeight
    }

    /// Circadian Alignment: sleep duration variability over last 7 days
    private func computeCircadianAlignment(durationSeries: MetricTimeSeries?) -> Double {
        guard let dur = durationSeries else { return 50.0 }

        let recentSamples = dur.samples(lastDays: 7)
        guard recentSamples.count >= 3 else { return 50.0 }

        let values = recentSamples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return 50.0 }

        // Compute standard deviation of sleep duration
        var sumOfSquares = 0.0
        for value in values {
            let delta = value - mean
            sumOfSquares += delta * delta
        }
        let sd = (sumOfSquares / Double(values.count)).squareRoot()

        // Coefficient of variation: lower = more consistent = better alignment
        let cv = sd / mean
        // CV of 0 = perfect (100), CV of 0.3+ = poor (0)
        let score = min(100, max(0, (1.0 - cv / 0.30) * 100.0))
        return score
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

    /// Get the most recent daily average value from a time series (last 2 days)
    private func mostRecentDailyValue(_ series: MetricTimeSeries) -> Double? {
        let recent = series.samples(lastDays: 2)
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
            // No variability — return direction based on difference from mean
            if current > baseline.mean { return 1.0 }
            if current < baseline.mean { return -1.0 }
            return 0.0
        }
        return (current - baseline.mean) / baseline.sd
    }

    /// Normalize a z-score to 0-1 range: z of -2 → 0, z of +2 → 1
    private func normalizeZScore(_ z: Double) -> Double {
        min(max((z + 2.0) / 4.0, 0), 1)
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
        var confidence = 0.40

        // Each additional signal adds confidence
        if hasDeep { confidence += 0.15 }
        if hasREM { confidence += 0.15 }
        if hasRHR { confidence += 0.10 }
        if hasVO2 { confidence += 0.05 }
        if hasDuration { confidence += 0.05 }

        // Baseline stability bonus (up to 0.10)
        if hrvBaseline.mean > 0 {
            let cv = hrvBaseline.sd / hrvBaseline.mean
            let stabilityBonus = max(0, min(0.10, 0.10 * (1.0 - (cv - 0.1) / 0.3)))
            confidence += stabilityBonus
        }

        return min(1.0, confidence)
    }

    // MARK: - Top Factors

    private func buildTopFactors(
        cognitiveReadiness: Double,
        memoryRecovery: Double,
        stressCognitionLoad: Double,
        neurovascularFitness: Double,
        circadianAlignment: Double,
        currentHRV: Double, hrvBaseline: (mean: Double, sd: Double),
        currentREM: Double?, remBaseline: (mean: Double, sd: Double)?,
        currentDeep: Double?, deepBaseline: (mean: Double, sd: Double)?,
        currentRHR: Double?, rhrBaseline: (mean: Double, sd: Double)?
    ) -> [(label: String, impact: String, isPositive: Bool)] {
        var factors: [(label: String, impact: String, isPositive: Bool, magnitude: Double)] = []

        // HRV factor
        let hrvPct = (currentHRV - hrvBaseline.mean) / max(hrvBaseline.mean, 1) * 100
        if abs(hrvPct) > 5 {
            let isPositive = hrvPct > 0
            let direction = isPositive ? "above" : "below"
            factors.append((
                label: "HRV",
                impact: "\(Int(abs(hrvPct)))% \(direction) baseline",
                isPositive: isPositive,
                magnitude: abs(hrvPct)
            ))
        }

        // REM factor
        if let rem = currentREM, let remBase = remBaseline {
            let remPct = (rem - remBase.mean) / max(remBase.mean, 1) * 100
            if abs(remPct) > 5 {
                let isPositive = remPct > 0
                let direction = isPositive ? "above" : "below"
                factors.append((
                    label: "REM Sleep",
                    impact: "\(direction) baseline",
                    isPositive: isPositive,
                    magnitude: abs(remPct)
                ))
            }
        }

        // Deep sleep factor
        if let deep = currentDeep, let deepBase = deepBaseline {
            let deepPct = (deep - deepBase.mean) / max(deepBase.mean, 1) * 100
            if abs(deepPct) > 5 {
                let isPositive = deepPct > 0
                let direction = isPositive ? "above" : "below"
                factors.append((
                    label: "Deep Sleep",
                    impact: "\(direction) baseline",
                    isPositive: isPositive,
                    magnitude: abs(deepPct)
                ))
            }
        }

        // Resting HR factor
        if let rhr = currentRHR, let rhrBase = rhrBaseline {
            let rhrPct = (rhr - rhrBase.mean) / max(rhrBase.mean, 1) * 100
            if abs(rhrPct) > 3 {
                // For RHR, lower is better (inverted)
                let isPositive = rhrPct < 0
                let direction = rhrPct < 0 ? "below" : "above"
                factors.append((
                    label: "Resting HR",
                    impact: "\(direction) baseline",
                    isPositive: isPositive,
                    magnitude: abs(rhrPct)
                ))
            }
        }

        // Circadian alignment factor
        if circadianAlignment > 80 {
            factors.append((
                label: "Sleep Schedule",
                impact: "consistent timing",
                isPositive: true,
                magnitude: circadianAlignment - 50
            ))
        } else if circadianAlignment < 40 {
            factors.append((
                label: "Sleep Schedule",
                impact: "irregular timing",
                isPositive: false,
                magnitude: 50 - circadianAlignment
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
        let hrvAbove = currentHRV > hrvBaseline.mean * 1.05
        let remAbove: Bool = {
            guard let rem = currentREM, let base = remBaseline else { return false }
            return rem > base.mean * 1.05
        }()
        let deepAbove: Bool = {
            guard let deep = currentDeep, let base = deepBaseline else { return false }
            return deep > base.mean * 1.05
        }()

        switch state {
        case .sharp:
            if hrvAbove && remAbove {
                return "Strong REM + high HRV this morning"
            } else if hrvAbove {
                return "High HRV signals sharp cognitive readiness"
            } else if remAbove && deepAbove {
                return "Excellent sleep recovery driving peak sharpness"
            } else {
                return "All brain health signals trending above baseline"
            }

        case .focused:
            if hrvAbove {
                return "Good HRV supporting focused state today"
            } else if remAbove || deepAbove {
                return "Solid sleep recovery supporting focus"
            } else {
                return "Brain health signals in a good range overall"
            }

        case .baseline:
            if !hrvAbove && !remAbove {
                return "Signals near your personal baseline today"
            } else {
                return "Mixed signals — some metrics above, some below baseline"
            }

        case .foggy:
            let hrvBelow = currentHRV < hrvBaseline.mean * 0.90
            let remBelow: Bool = {
                guard let rem = currentREM, let base = remBaseline else { return false }
                return rem < base.mean * 0.85
            }()
            if hrvBelow && remBelow {
                return "Low HRV + reduced REM — expect brain fog today"
            } else if hrvBelow {
                return "HRV well below baseline — cognitive load may feel heavier"
            } else {
                return "Sleep quality below baseline — recovery is lagging"
            }
        }
    }

    // MARK: - Daily History

    /// Build the last 14 days of daily brain health scores
    private func buildWeeklyHistory(
        allSeries: [HealthMetric: MetricTimeSeries],
        hrvSeries: MetricTimeSeries
    ) {
        let calendar = Calendar.current
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
