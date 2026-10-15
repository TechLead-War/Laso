import Foundation

/// Heuristic, unvalidated. Surfaces circadian disruption signals derived
/// from wearable activity/sleep data; treat outputs as informational, not
/// clinical, measurements.
///
/// Three components, each 0 to 100:
/// - Rest-activity amplitude from the averaged 24-hour step profile (M10/L5
///   relative amplitude, Van Someren et al. 1999). This replaced a day-to-day
///   coefficient of variation of daily totals, which rewarded erratic days
///   while the regularity component punished them, so nobody could score well.
/// - Regularity: how similar consecutive days' step totals are.
/// - Sleep timing: how steady the nightly sleep midpoint is.
struct CircadianDisruptionAnalyzer {

    // MARK: - Constants

    private static let minDaysRequired = 21
    /// Days the hourly step profile spans; missing hours are zero steps, so the
    /// per-hour mean divides by the window, not by the hours that had samples.
    private static let hourlyProfileDays = 30
    /// Relative amplitude (M10 - L5) / (M10 + L5) of healthy consolidated
    /// rhythms sits near 0.9 or above; below about 0.6 the rhythm is flat or
    /// inverted (Van Someren et al. 1999; Gonçalves et al. 2014).
    private static let relativeAmplitudeFloor = 0.6
    private static let relativeAmplitudeCeiling = 0.95
    /// Sleep-midpoint spread that reads as fully irregular timing. Regular
    /// sleepers hold the midpoint within roughly 30 to 45 minutes night to night.
    private static let midpointSDAtZeroScore = 120.0 // minutes

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let stepsSeries = context.timeSeries[.steps] else { return [] }
        let samples = stepsSeries.samples(lastDays: 30)
        guard samples.count >= minDaysRequired else { return [] }

        // Composite circadian health score (0-100)
        var components: [(score: Double, weight: Double, label: String)] = []
        if let amplitude = relativeAmplitudeScore(hourlyStepBins: context.hourlyStepBins) {
            components.append((amplitude, 0.35, Copy.Analysis.Research.CircadianDisruption.restActivityComponent))
        }
        components.append((regularityScore(samples: samples), 0.30, Copy.Analysis.Research.CircadianDisruption.regularityComponent))
        if let sleepScore = sleepTimingConsistency(context: context) {
            components.append((sleepScore, 0.35, Copy.Analysis.Research.CircadianDisruption.sleepTimingComponent))
        }

        // Divide by the weight actually present, not by 1: amplitude and sleep
        // timing are optional, so a user missing one carries part of the model
        // and clamping the divisor to 1 would report their score low.
        let totalWeight = components.map(\.weight).reduce(0, +)
        guard totalWeight > 0 else { return [] }
        let circadianScore = components.map { $0.score * $0.weight }.reduce(0, +) / totalWeight

        let weakestComponent = components.min(by: { $0.score < $1.score })!
        let strongestComponent = components.max(by: { $0.score < $1.score })!

        // Insight 1: Circadian health assessment
        if circadianScore < 40 {
            let scoreText = String(format: "%.0f", circadianScore)
            let weakestScoreText = String(format: "%.0f", weakestComponent.score)
            insights.append(InsightFactory.make(
                metric: .steps,
                title: Copy.Analysis.Research.CircadianDisruption.disruptedTitle,
                summary: Copy.Analysis.Research.CircadianDisruption.disruptedSummary(score: scoreText, weakest: weakestComponent.label, weakestScore: weakestScoreText),
                recommendation: Copy.Analysis.Research.CircadianDisruption.disruptedRecommendation,
                severity: .warning,
                trend: .declining,
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
                directive: .sleepBetter,
                context: InsightContext(
                    confidenceLevel: min(Double(samples.count) / 30.0, 1.0),
                    dataPointCount: samples.count
                )
            ))
        } else if circadianScore < 60 {
            let scoreText = String(format: "%.0f", circadianScore)
            let weakestScoreText = String(format: "%.0f", weakestComponent.score)
            insights.append(InsightFactory.make(
                metric: .steps,
                title: Copy.Analysis.Research.CircadianDisruption.needsImprovementTitle,
                summary: Copy.Analysis.Research.CircadianDisruption.needsImprovementSummary(score: scoreText, weakest: weakestComponent.label),
                recommendation: Copy.Analysis.Research.CircadianDisruption.needsImprovementRecommendation(score: scoreText, weakest: weakestComponent.label, weakestScore: weakestScoreText),
                severity: .info,
                trend: .stable,
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
                directive: .informational,
            ))
        } else if circadianScore >= 80 {
            let scoreText = String(format: "%.0f", circadianScore)
            insights.append(InsightFactory.observation(
                metric: .steps,
                title: Copy.Analysis.Research.CircadianDisruption.strongRhythmTitle,
                summary: Copy.Analysis.Research.CircadianDisruption.strongRhythmSummary(score: scoreText, strongest: strongestComponent.label),
                recommendation: Copy.Analysis.Research.CircadianDisruption.strongRhythmRecommendation(score: scoreText),
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
            ))
        }

        return insights
    }

    // MARK: - Rhythm Metrics

    /// Relative amplitude of the averaged 24-hour step profile: the mean of the
    /// most active 10 consecutive hours (M10) against the least active 5 (L5).
    /// Nil without an hourly profile.
    static func relativeAmplitudeScore(hourlyStepBins: [[Double]]?) -> Double? {
        guard let bins = hourlyStepBins, bins.count == 24 else { return nil }
        let hourlyMean = bins.map { $0.reduce(0, +) / Double(hourlyProfileDays) }

        func windowMean(length: Int, pick: (Double, Double) -> Bool) -> Double {
            var best: Double? = nil
            for start in 0..<24 {
                var sum = 0.0
                for offset in 0..<length { sum += hourlyMean[(start + offset) % 24] }
                let mean = sum / Double(length)
                if let current = best, !pick(mean, current) { continue }
                best = mean
            }
            return best ?? 0
        }
        let m10 = windowMean(length: 10, pick: >)
        let l5 = windowMean(length: 5, pick: <)
        guard m10 + l5 > 0 else { return nil }

        let relativeAmplitude = (m10 - l5) / (m10 + l5)
        let span = relativeAmplitudeCeiling - relativeAmplitudeFloor
        return min(max((relativeAmplitude - relativeAmplitudeFloor) / span, 0), 1) * 100
    }

    /// 0 to 100 from how similar consecutive days' step totals are.
    private static func regularityScore(samples: [MetricSample]) -> Double {
        let sorted = samples.sorted { $0.date < $1.date }
        var dayDiffs: [Double] = []
        for i in 1..<sorted.count {
            let daysBetween = Date.cal.dateComponents(
                [.day], from: sorted[i-1].date, to: sorted[i].date
            ).day ?? 1
            if daysBetween == 1 && sorted[i-1].value > 0 {
                let relDiff = abs(sorted[i].value - sorted[i-1].value) / max(sorted[i-1].value, 1)
                dayDiffs.append(relDiff)
            }
        }
        let avgRelDiff = dayDiffs.isEmpty ? 0.5 : dayDiffs.mean
        return max(0, (1.0 - avgRelDiff) * 100)
    }

    /// 0 to 100 from how steady the nightly sleep midpoint is: the spread of
    /// the midpoint clock time, so a fixed 7 h sleeper who drifts from 10 pm to
    /// 2 am scores low even though every night is the same length.
    private static func sleepTimingConsistency(context: AnalysisContext) -> Double? {
        guard let sleepSeries = context.timeSeries[.sleepDuration] else { return nil }
        let samples = sleepSeries.samples(lastDays: 21)
        guard samples.count >= 14 else { return nil }

        let midpointSD = samples.map(SleepRegularityAnalyzer.sleepMidpointMinutesFromNoon).standardDeviation
        return max(0, 100 - min(midpointSD / midpointSDAtZeroScore, 1.0) * 100)
    }
}

// MARK: - InsightAnalyzer Conformance

extension CircadianDisruptionAnalyzer: InsightAnalyzer {}
