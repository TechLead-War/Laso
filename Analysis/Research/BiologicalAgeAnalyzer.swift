import Foundation

/// Research: npj Digital Medicine (2024). CosinorAge
/// Finding: Biological age estimated purely from wearable accelerometry data
/// correlates r=0.87-0.89 with blood-based biological age clocks.
/// Uses cosinor analysis of rest-activity rhythms (amplitude, acrophase).
///
/// Also: Apple Heart & Movement Study (2026). VO2max age percentiles.
/// VO2max is stronger than smoking/diabetes/hypertension for mortality prediction.
///
/// Implementation: Computes a composite Biological Age from activity rhythm
/// amplitude, VO2max percentile, RHR trajectory, and mobility metrics.
struct BiologicalAgeAnalyzer {

    // MARK: - VO2max Age/Sex Norms (from Apple Heart & Movement Study 2026)
    // Each tuple: (ageBracketMidpoint, maleAvg, femaleAvg)

    private static let vo2maxNorms: [(age: Double, male: Double, female: Double)] = [
        (19, 39.7, 31.1),
        (25, 38.5, 30.5),
        (35, 36.0, 28.8),
        (45, 34.0, 27.0),
        (55, 31.5, 25.5),
        (65, 29.0, 24.0),
        (75, 27.0, 23.0),
        (85, 25.9, 22.2),
    ]

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        // Collect available components
        var ageEstimates: [(component: String, estimatedAge: Double, weight: Double)] = []

        // 1. VO2max-based fitness age (strongest single predictor)
        if let vo2Insight = computeVO2maxAge(context: context) {
            ageEstimates.append(vo2Insight)
        }

        // 2. RHR-based cardiovascular age
        if let rhrInsight = computeRHRAge(context: context) {
            ageEstimates.append(rhrInsight)
        }

        // 3. Activity rhythm amplitude (CosinorAge proxy)
        if let rhythmInsight = computeActivityRhythmAge(context: context) {
            ageEstimates.append(rhythmInsight)
        }

        // 4. Mobility-based functional age
        if let mobilityInsight = computeMobilityAge(context: context) {
            ageEstimates.append(mobilityInsight)
        }

        // 5. HRV-based autonomic age
        if let hrvInsight = computeHRVAge(context: context) {
            ageEstimates.append(hrvInsight)
        }

        guard ageEstimates.count >= 2 else { return [] }

        // Weighted average biological age
        let totalWeight = ageEstimates.map(\.weight).reduce(0, +)
        let weightedAge = ageEstimates.map { $0.estimatedAge * $0.weight }.reduce(0, +) / max(totalWeight, 1)

        // We don't know the user's chronological age directly, but we can express
        // the result as a relative fitness equivalent and compare components.
        let componentBreakdown = ageEstimates
            .sorted { $0.estimatedAge < $1.estimatedAge }
            .map { "\($0.component): ~\(String(format: "%.0f", $0.estimatedAge)) yrs" }
            .joined(separator: ", ")

        let youngestComponent = ageEstimates.min(by: { $0.estimatedAge < $1.estimatedAge })!
        let oldestComponent = ageEstimates.max(by: { $0.estimatedAge < $1.estimatedAge })!
        let ageSpread = oldestComponent.estimatedAge - youngestComponent.estimatedAge

        // Primary insight: Biological age estimate
        insights.append(InsightFactory.observation(
            metric: .vo2Max,
            title: "Biological Age Estimate: ~\(String(format: "%.0f", weightedAge))",
            summary: "Based on \(ageEstimates.count) physiological markers, your body functions like someone around \(String(format: "%.0f", weightedAge)) years old. Strongest area: \(youngestComponent.component). Area with most room: \(oldestComponent.component).",
            recommendation: "Breakdown. \(componentBreakdown). Each component is mapped to population norms from large-scale studies. VO2max alone (your strongest mortality predictor) suggests a fitness age equivalent.",
            currentValue: weightedAge,
            baselineValue: weightedAge,
            deviationPercent: 0,
            category: .clinicalTrajectory,
            relatedMetrics: [.vo2Max, .restingHeartRate, .heartRateVariability, .walkingSpeed],
            context: InsightContext(
                confidenceLevel: min(Double(ageEstimates.count) / 5.0, 1.0),
                dataPointCount: ageEstimates.count
            )
        ))

        // Insight: Large spread between components → imbalance
        if ageSpread > 15 {
            insights.append(InsightFactory.make(
                metric: .vo2Max,
                title: "Age Component Imbalance",
                summary: "There's a \(String(format: "%.0f", ageSpread))-year gap between your youngest system (\(youngestComponent.component): ~\(String(format: "%.0f", youngestComponent.estimatedAge))) and oldest (\(oldestComponent.component): ~\(String(format: "%.0f", oldestComponent.estimatedAge))). This imbalance is worth addressing.",
                recommendation: "A large spread between biological age components suggests one system is aging faster than others. Focusing on your \(oldestComponent.component) could bring your overall biological age down significantly.",
                severity: .info,
                trend: .stable,
                currentValue: ageSpread,
                baselineValue: 10,
                deviationPercent: ((ageSpread - 10) / 10) * 100,
                category: .clinicalTrajectory,
                directive: .informational,
                relatedMetrics: [.vo2Max, .restingHeartRate, .walkingSpeed]
            ))
        }

        return insights
    }

    // MARK: - Component Age Estimators

    private static func computeVO2maxAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let vo2Series = context.timeSeries[.vo2Max] else { return nil }
        let recent = vo2Series.samples(lastDays: 90)
        guard recent.count >= 3 else { return nil }

        let currentVO2 = Array(recent.suffix(5)).map(\.value).mean
        guard currentVO2 > 10 else { return nil }

        // Find the age where this VO2max is average (interpolate between norms)
        // Use male norms as default; we don't have sex info in context
        // The resulting age is approximate either way
        let norms = vo2maxNorms.map { ($0.age, ($0.male + $0.female) / 2.0) }

        var estimatedAge = norms.last!.0

        for i in 0..<(norms.count - 1) {
            let (age1, vo2_1) = norms[i]
            let (age2, vo2_2) = norms[i + 1]

            if currentVO2 >= vo2_2 && currentVO2 <= vo2_1 {
                // Interpolate
                let fraction = (vo2_1 - currentVO2) / max(vo2_1 - vo2_2, 0.1)
                estimatedAge = age1 + fraction * (age2 - age1)
                break
            } else if currentVO2 > vo2_1 && i == 0 {
                // Better than youngest bracket
                let excess = (currentVO2 - vo2_1) / max(vo2_1 - vo2_2, 0.1)
                estimatedAge = max(15, age1 - excess * (age2 - age1))
                break
            }
        }

        return ("Cardio Fitness", estimatedAge, 0.35) // Highest weight. strongest mortality predictor
    }

    private static func computeRHRAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let rhrSeries = context.timeSeries[.restingHeartRate] else { return nil }
        let recent = rhrSeries.samples(lastDays: 30)
        guard recent.count >= 10 else { return nil }

        let currentRHR = Array(recent.suffix(7)).map(\.value).mean

        // Population norms: RHR increases with poor cardiovascular health
        // Young fit adult: ~55-65 bpm, average: ~65-75, older/unfit: 75-85+
        // Map RHR to approximate functional age
        let rhrAge: Double
        if currentRHR <= 55 {
            rhrAge = 20
        } else if currentRHR <= 65 {
            rhrAge = 20 + (currentRHR - 55) * 2.0 // 20-40
        } else if currentRHR <= 75 {
            rhrAge = 40 + (currentRHR - 65) * 2.0 // 40-60
        } else {
            rhrAge = 60 + (currentRHR - 75) * 1.5 // 60+
        }

        return ("Resting Heart Rate", min(rhrAge, 90), 0.20)
    }

    private static func computeActivityRhythmAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let stepsSeries = context.timeSeries[.steps] else { return nil }
        let samples = stepsSeries.samples(lastDays: 60)
        guard samples.count >= 30 else { return nil }

        // CosinorAge proxy: activity rhythm amplitude
        // High amplitude (large difference between active and rest periods) = younger
        // Low amplitude (flat activity pattern) = older biological age
        let values = samples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return nil }

        let stdDev = values.standardDeviation
        let relativeAmplitude = stdDev / mean // Coefficient of variation as amplitude proxy

        // Also compute day-to-day regularity (lower is better)
        var dayDiffs: [Double] = []
        let sorted = samples.sorted { $0.date < $1.date }
        for i in 1..<sorted.count {
            dayDiffs.append(abs(sorted[i].value - sorted[i-1].value))
        }
        let avgDayDiff = dayDiffs.isEmpty ? stdDev : dayDiffs.mean
        let regularity = 1.0 - min(avgDayDiff / max(mean, 1), 1.0)

        // Combine: high amplitude + high regularity = younger
        let rhythmScore = (relativeAmplitude * 0.5 + regularity * 0.5)

        // Map to age: score 0.6+ → ~25, score 0.3 → ~50, score 0.15 → ~70
        let rhythmAge: Double
        if rhythmScore >= 0.55 {
            rhythmAge = 25
        } else if rhythmScore >= 0.35 {
            rhythmAge = 25 + (0.55 - rhythmScore) / 0.20 * 25
        } else {
            rhythmAge = 50 + (0.35 - rhythmScore) / 0.20 * 25
        }

        return ("Activity Rhythm", min(max(rhythmAge, 18), 90), 0.20)
    }

    private static func computeMobilityAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        var mobilityScores: [Double] = []

        // Walking speed: 1.4 m/s = young, 1.0 = middle-age, <0.8 = elderly
        if let speedSeries = context.timeSeries[.walkingSpeed] {
            let recent = speedSeries.samples(lastDays: 30)
            if recent.count >= 5 {
                let speed = Array(recent.suffix(10)).map(\.value).mean
                let speedAge: Double
                if speed >= 1.4 { speedAge = 25 }
                else if speed >= 1.2 { speedAge = 25 + (1.4 - speed) / 0.2 * 15 }
                else if speed >= 1.0 { speedAge = 40 + (1.2 - speed) / 0.2 * 15 }
                else { speedAge = 55 + (1.0 - speed) / 0.2 * 20 }
                mobilityScores.append(min(speedAge, 85))
            }
        }

        // Double support percentage: lower = younger (15-20% young, 25-30% elderly)
        if let dspSeries = context.timeSeries[.walkingDoubleSupportPercentage] {
            let recent = dspSeries.samples(lastDays: 30)
            if recent.count >= 5 {
                let dsp = Array(recent.suffix(10)).map(\.value).mean
                let dspAge = max(18, min(85, 20 + (dsp - 20) * 3))
                mobilityScores.append(dspAge)
            }
        }

        guard !mobilityScores.isEmpty else { return nil }
        return ("Mobility", mobilityScores.mean, 0.15)
    }

    private static func computeHRVAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let hrvSeries = context.timeSeries[.heartRateVariability] else { return nil }
        let recent = hrvSeries.samples(lastDays: 30)
        guard recent.count >= 10 else { return nil }

        let currentHRV = Array(recent.suffix(7)).map(\.value).mean

        // HRV population norms (SDNN): 20s: ~60-80ms, 40s: ~40-60ms, 60s: ~25-40ms
        let hrvAge: Double
        if currentHRV >= 70 { hrvAge = 22 }
        else if currentHRV >= 50 { hrvAge = 22 + (70 - currentHRV) / 20 * 18 }
        else if currentHRV >= 35 { hrvAge = 40 + (50 - currentHRV) / 15 * 15 }
        else if currentHRV >= 20 { hrvAge = 55 + (35 - currentHRV) / 15 * 20 }
        else { hrvAge = 75 + (20 - currentHRV) / 10 * 10 }

        return ("Autonomic Nervous System", min(hrvAge, 90), 0.10)
    }
}

// MARK: - InsightAnalyzer Conformance

extension BiologicalAgeAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "biologicalAge" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }
}
