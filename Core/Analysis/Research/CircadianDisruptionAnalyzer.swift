import Foundation

/// Heuristic — unvalidated. Surfaces circadian disruption signals derived
/// from wearable activity/sleep data; treat outputs as informational, not
/// clinical, measurements.
///
/// Implementation: Computes circadian rhythm metrics from daily activity patterns:
/// rest-activity amplitude, acrophase stability, and intradaily variability.
/// Surfaces circadian health as a distinct signal.
struct CircadianDisruptionAnalyzer {

    // MARK: - Constants

    private static let minDaysRequired = 21

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let stepsSeries = context.timeSeries[.steps] else { return [] }
        let samples = stepsSeries.samples(lastDays: 30)
        guard samples.count >= minDaysRequired else { return [] }

        // Compute circadian metrics
        let rhythmMetrics = computeRhythmMetrics(samples: samples)

        // Also check sleep timing consistency
        let sleepTimingConsistency = computeSleepTimingConsistency(context: context)

        // Composite circadian health score (0-100)
        var components: [(score: Double, weight: Double, label: String)] = []
        components.append((rhythmMetrics.amplitudeScore, 0.30, Copy.Analysis.Research.CircadianDisruption.amplitudeComponent))
        components.append((rhythmMetrics.regularityScore, 0.25, Copy.Analysis.Research.CircadianDisruption.regularityComponent))
        components.append((rhythmMetrics.restActivityRatio, 0.20, Copy.Analysis.Research.CircadianDisruption.restActivityComponent))

        if let sleepScore = sleepTimingConsistency {
            components.append((sleepScore, 0.25, Copy.Analysis.Research.CircadianDisruption.sleepTimingComponent))
        }

        let totalWeight = components.map(\.weight).reduce(0, +)
        let circadianScore = components.map { $0.score * $0.weight }.reduce(0, +) / max(totalWeight, 1)

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

    private struct RhythmResult {
        let amplitudeScore: Double    // 0-100: how different active vs rest periods are
        let regularityScore: Double   // 0-100: day-to-day consistency
        let restActivityRatio: Double // 0-100: contrast between rest and activity
    }

    private static func computeRhythmMetrics(samples: [MetricSample]) -> RhythmResult {
        let values = samples.map(\.value)
        let mean = values.mean
        let stdDev = values.standardDeviation

        // 1. Amplitude: relative amplitude of daily activity pattern
        // Higher CV = more distinct active/rest contrast = younger rhythm
        let cv = mean > 0 ? stdDev / mean : 0
        let amplitudeScore = min(cv / 0.5, 1.0) * 100

        // 2. Regularity: consistency of day-to-day patterns
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
        let regularityScore = max(0, (1.0 - avgRelDiff) * 100)

        // 3. Rest-activity ratio: do rest days look different from active days?
        let sortedValues = values.sorted()
        let lower25 = Array(sortedValues.prefix(max(1, sortedValues.count / 4)))
        let upper25 = Array(sortedValues.suffix(max(1, sortedValues.count / 4)))
        let restMean = lower25.mean
        let activeMean = upper25.mean
        let contrast = activeMean > 0 ? (activeMean - restMean) / activeMean : 0
        let ratioScore = min(contrast / 0.6, 1.0) * 100

        return RhythmResult(
            amplitudeScore: amplitudeScore,
            regularityScore: regularityScore,
            restActivityRatio: ratioScore
        )
    }

    /// Compute sleep timing consistency score from sleep data
    private static func computeSleepTimingConsistency(context: AnalysisContext) -> Double? {
        guard let sleepSeries = context.timeSeries[.sleepDuration] else { return nil }
        let samples = sleepSeries.samples(lastDays: 21)
        guard samples.count >= 14 else { return nil }

        let values = samples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return nil }

        let cv = values.standardDeviation / mean

        // Also check weekday vs weekend gap
        let calendar = Date.cal
        let weekday = samples.filter { calendar.component(.weekday, from: $0.date) >= 2 && calendar.component(.weekday, from: $0.date) <= 6 }.map(\.value)
        let weekend = samples.filter { calendar.component(.weekday, from: $0.date) == 1 || calendar.component(.weekday, from: $0.date) == 7 }.map(\.value)

        var gapPenalty = 0.0
        if !weekday.isEmpty && !weekend.isEmpty {
            let gap = abs(weekday.mean - weekend.mean)
            gapPenalty = min(gap / 2.0, 1.0) * 20
        }

        let cvPenalty = min(cv / 0.25, 1.0) * 30

        return max(0, 100 - cvPenalty - gapPenalty)
    }
}

// MARK: - InsightAnalyzer Conformance

extension CircadianDisruptionAnalyzer: InsightAnalyzer {}
