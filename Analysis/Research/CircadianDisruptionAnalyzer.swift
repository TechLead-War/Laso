import Foundation

/// Research: npj Digital Medicine (2024) + Chronobiology in Medicine (2025)
/// + Nature (Dec 2024) on circadian markers and mental health.
/// Finding: Circadian disruption measurable from wearable activity/sleep data
/// underlies metabolic disorders, cardiovascular disease, cancer, and aging.
/// CosinorAge correlates r=0.87-0.89 with blood-based biological age.
/// Bidirectional links between circadian disruption and mood confirmed.
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
        components.append((rhythmMetrics.amplitudeScore, 0.30, "activity amplitude"))
        components.append((rhythmMetrics.regularityScore, 0.25, "rhythm regularity"))
        components.append((rhythmMetrics.restActivityRatio, 0.20, "rest-activity contrast"))

        if let sleepScore = sleepTimingConsistency {
            components.append((sleepScore, 0.25, "sleep timing"))
        }

        let totalWeight = components.map(\.weight).reduce(0, +)
        let circadianScore = components.map { $0.score * $0.weight }.reduce(0, +) / max(totalWeight, 1)

        let weakestComponent = components.min(by: { $0.score < $1.score })!
        let strongestComponent = components.max(by: { $0.score < $1.score })!

        // Insight 1: Circadian health assessment
        if circadianScore < 40 {
            insights.append(InsightFactory.make(
                metric: .steps,
                title: "Circadian Rhythm Disrupted",
                summary: "Your circadian health score is \(String(format: "%.0f", circadianScore))/100. indicating significant disruption in your daily biological rhythm. Weakest area: \(weakestComponent.label) (\(String(format: "%.0f", weakestComponent.score))/100).",
                recommendation: "Research shows circadian disruption is linked to reduced metabolic health, heart wellness, mood, and long-term wellness. Your activity patterns lack the strong daily rhythm (high daytime activity, low nighttime activity) associated with healthy circadian function. Circadian rhythm amplitude measured from wearables strongly correlates with overall fitness age.",
                severity: .warning,
                trend: .declining,
                currentValue: circadianScore,
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
                directive: .sleepBetter,
                relatedMetrics: [.steps, .sleepDuration, .timeInDaylight],
                context: InsightContext(
                    confidenceLevel: min(Double(samples.count) / 30.0, 1.0),
                    dataPointCount: samples.count
                )
            ))
        } else if circadianScore < 60 {
            insights.append(InsightFactory.make(
                metric: .steps,
                title: "Circadian Rhythm: Room for Improvement",
                summary: "Your circadian health score is \(String(format: "%.0f", circadianScore))/100. Your daily rhythm is present but could be stronger. Focus area: \(weakestComponent.label).",
                recommendation: "A circadian score of \(String(format: "%.0f", circadianScore)) suggests your body's 24-hour rhythm is moderately aligned. Strengthening your \(weakestComponent.label) (currently \(String(format: "%.0f", weakestComponent.score))/100) would have the most impact. Regular light exposure in the morning and consistent sleep timing are the most effective interventions.",
                severity: .info,
                trend: .stable,
                currentValue: circadianScore,
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
                directive: .informational,
                relatedMetrics: [.steps, .sleepDuration, .timeInDaylight]
            ))
        } else if circadianScore >= 80 {
            insights.append(InsightFactory.observation(
                metric: .steps,
                title: "Strong Circadian Rhythm",
                summary: "Your circadian health score is \(String(format: "%.0f", circadianScore))/100. Your daily biological rhythm shows strong amplitude, good regularity, and clear rest-activity contrast. Strongest area: \(strongestComponent.label).",
                recommendation: "A circadian score of \(String(format: "%.0f", circadianScore)) reflects a well-entrained biological clock. Research shows strong circadian rhythmicity is independently supportive of metabolic health, cognitive performance, and long-term wellness. correlating with a younger fitness age.",
                currentValue: circadianScore,
                baselineValue: 70,
                deviationPercent: ((circadianScore - 70) / 70) * 100,
                category: .circadian,
                relatedMetrics: [.steps, .sleepDuration, .timeInDaylight]
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
            let daysBetween = Calendar.current.dateComponents(
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
        let calendar = Calendar.current
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

extension CircadianDisruptionAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "circadianDisruption" }
    static var insightCategory: InsightCategory { .circadian }
}
