import Foundation

/// Finding: Sleep irregularity + reduced activity + decreased daylight exposure
/// predicts depression/anxiety onset with clinical-grade accuracy.
/// No invasive phone tracking needed. HealthKit metrics suffice.
///
/// Implementation: Uses Sleep Regularity Index + steps trend + daylight exposure
/// + mindful minutes to detect patterns associated with mood deterioration.
/// Non-diagnostic. surfaces pattern observations only.
struct WellbeingTrendAnalyzer {

    // MARK: - Signal Weights

    private struct WellbeingSignal {
        let score: Double // -1 (concerning) to +1 (positive)
        let weight: Double
        let detail: String
    }

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []
        var signals: [WellbeingSignal] = []

        // 1. Sleep regularity signal
        if let sleepSignal = evaluateSleepRegularity(context: context) {
            signals.append(sleepSignal)
        }

        // 2. Activity level trend
        if let activitySignal = evaluateActivityTrend(context: context) {
            signals.append(activitySignal)
        }

        // 3. Daylight exposure
        if let daylightSignal = evaluateDaylightExposure(context: context) {
            signals.append(daylightSignal)
        }

        // 4. Mindfulness engagement
        if let mindfulSignal = evaluateMindfulness(context: context) {
            signals.append(mindfulSignal)
        }

        // 5. HRV trend (autonomic stress marker)
        if let hrvSignal = evaluateHRVTrend(context: context) {
            signals.append(hrvSignal)
        }

        guard signals.count >= 3 else { return [] }

        // Compute weighted wellbeing score
        let totalWeight = signals.map(\.weight).reduce(0, +)
        let weightedScore = signals.map { $0.score * $0.weight }.reduce(0, +) / max(totalWeight, 1)

        // Count concerning signals
        let concerningSignals = signals.filter { $0.score < -0.3 }
        let positiveSignals = signals.filter { $0.score > 0.3 }

        // Insight: Multiple concerning signals
        if concerningSignals.count >= 3 {
            let concernList = concerningSignals
                .sorted { $0.score < $1.score }
                .prefix(4)
                .map(\.detail)
                .joined(separator: ". ")
            let scoreText = String(format: "%.0f", (weightedScore + 1) * 50)

            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.WellbeingTrend.patternShiftTitle,
                summary: Copy.Analysis.Research.WellbeingTrend.patternShiftSummary(concerningCount: concerningSignals.count, total: signals.count, concerns: concernList),
                recommendation: Copy.Analysis.Research.WellbeingTrend.patternShiftRecommendation(score: scoreText),
                severity: concerningSignals.count >= 4 ? .warning : .info,
                trend: .declining,
                currentValue: (weightedScore + 1) * 50,
                baselineValue: 70,
                deviationPercent: ((weightedScore + 1) * 50 - 70) / 70 * 100,
                category: .cognitiveEnergy,
                directive: concerningSignals.count >= 4 ? .rest : .informational,
                relatedMetrics: [.sleepDuration, .steps, .timeInDaylight, .mindfulMinutes],
                context: InsightContext(
                    confidenceLevel: min(Double(signals.count) / 5.0, 1.0),
                    dataPointCount: signals.count
                )
            ))
        } else if concerningSignals.count == 2 {
            let concernList = concerningSignals.map(\.detail).joined(separator: " and ")

            insights.append(InsightFactory.observation(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.WellbeingTrend.mildPatternChangeTitle,
                summary: Copy.Analysis.Research.WellbeingTrend.mildSummary(concerns: concernList),
                recommendation: Copy.Analysis.Research.WellbeingTrend.mildRecommendation,
                currentValue: (weightedScore + 1) * 50,
                baselineValue: 70,
                deviationPercent: ((weightedScore + 1) * 50 - 70) / 70 * 100,
                category: .cognitiveEnergy,
                relatedMetrics: [.sleepDuration, .steps, .timeInDaylight]
            ))
        }

        // Positive: All signals look good
        if positiveSignals.count >= 3 && concerningSignals.isEmpty {
            insights.append(InsightFactory.observation(
                metric: .steps,
                title: Copy.Analysis.Research.WellbeingTrend.strongIndicatorsTitle,
                summary: Copy.Analysis.Research.WellbeingTrend.strongSummary(total: signals.count, includeMindfulness: signals.count >= 4),
                recommendation: Copy.Analysis.Research.WellbeingTrend.strongRecommendation,
                currentValue: (weightedScore + 1) * 50,
                baselineValue: 70,
                deviationPercent: ((weightedScore + 1) * 50 - 70) / 70 * 100,
                category: .cognitiveEnergy,
                relatedMetrics: [.sleepDuration, .steps, .timeInDaylight, .mindfulMinutes]
            ))
        }

        return insights
    }

    // MARK: - Signal Evaluators

    private static func evaluateSleepRegularity(context: AnalysisContext) -> WellbeingSignal? {
        guard let sleepSeries = context.timeSeries[.sleepDuration] else { return nil }
        let samples = sleepSeries.samples(lastDays: 14)
        guard samples.count >= 10 else { return nil }

        let values = samples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return nil }

        let cv = values.standardDeviation / mean

        let score: Double
        let detail: String
        if cv < 0.12 {
            score = 0.8
            detail = Copy.Analysis.Research.WellbeingTrend.sleepVeryRegular
        } else if cv < 0.20 {
            score = 0.2
            detail = Copy.Analysis.Research.WellbeingTrend.sleepModeratelyRegular
        } else if cv < 0.30 {
            score = -0.5
            detail = Copy.Analysis.Research.WellbeingTrend.sleepVariesSignificantly
        } else {
            score = -0.9
            detail = Copy.Analysis.Research.WellbeingTrend.sleepHighlyIrregular
        }

        return WellbeingSignal(score: score, weight: 0.30, detail: detail)
    }

    private static func evaluateActivityTrend(context: AnalysisContext) -> WellbeingSignal? {
        guard let stepsSeries = context.timeSeries[.steps] else { return nil }

        let recent7 = stepsSeries.samples(lastDays: 7)
        let prior7 = stepsSeries.samples(lastDays: 14).filter { sample in
            sample.date < Date.cal.date(byAdding: .day, value: -7, to: Date())!
        }

        guard recent7.count >= 4, prior7.count >= 4 else { return nil }

        let recentAvg = recent7.map(\.value).mean
        let priorAvg = prior7.map(\.value).mean
        guard priorAvg > 0 else { return nil }

        let change = (recentAvg - priorAvg) / priorAvg

        let score: Double
        let detail: String
        if change > 0.10 {
            score = 0.7
            detail = Copy.Analysis.Research.WellbeingTrend.activityIncreased
        } else if change > -0.10 {
            score = 0.3
            detail = Copy.Analysis.Research.WellbeingTrend.activityStable
        } else if change > -0.25 {
            score = -0.4
            detail = Copy.Analysis.Research.WellbeingTrend.activityDropped(percent: String(format: "%.0f", abs(change) * 100))
        } else {
            score = -0.8
            detail = Copy.Analysis.Research.WellbeingTrend.activityDropped(percent: String(format: "%.0f", abs(change) * 100))
        }

        return WellbeingSignal(score: score, weight: 0.25, detail: detail)
    }

    private static func evaluateDaylightExposure(context: AnalysisContext) -> WellbeingSignal? {
        guard let daylightSeries = context.timeSeries[.timeInDaylight] else { return nil }

        let recent7 = daylightSeries.samples(lastDays: 7)
        guard recent7.count >= 4 else { return nil }

        let avgMinutes = recent7.map(\.value).mean

        let score: Double
        let detail: String
        let minutesText = String(format: "%.0f", avgMinutes)
        if avgMinutes >= 30 {
            score = 0.8
            detail = Copy.Analysis.Research.WellbeingTrend.goodDaylight(minutes: minutesText)
        } else if avgMinutes >= 15 {
            score = 0.1
            detail = Copy.Analysis.Research.WellbeingTrend.moderateDaylight
        } else if avgMinutes >= 5 {
            score = -0.5
            detail = Copy.Analysis.Research.WellbeingTrend.lowDaylight(minutes: minutesText)
        } else {
            score = -0.9
            detail = Copy.Analysis.Research.WellbeingTrend.veryLowDaylight
        }

        return WellbeingSignal(score: score, weight: 0.20, detail: detail)
    }

    private static func evaluateMindfulness(context: AnalysisContext) -> WellbeingSignal? {
        guard let mindfulSeries = context.timeSeries[.mindfulMinutes] else { return nil }

        let recent7 = mindfulSeries.samples(lastDays: 7)
        guard recent7.count >= 3 else { return nil }

        let totalMinutes = recent7.map(\.value).reduce(0, +)
        let avgDaily = totalMinutes / 7.0

        let score: Double
        let detail: String
        if avgDaily >= 10 {
            score = 0.7
            detail = Copy.Analysis.Research.WellbeingTrend.mindfulnessConsistent
        } else if avgDaily >= 3 {
            score = 0.3
            detail = Copy.Analysis.Research.WellbeingTrend.mindfulnessSome
        } else {
            score = -0.2
            detail = Copy.Analysis.Research.WellbeingTrend.mindfulnessMinimal
        }

        return WellbeingSignal(score: score, weight: 0.10, detail: detail)
    }

    private static func evaluateHRVTrend(context: AnalysisContext) -> WellbeingSignal? {
        guard let hrvSeries = context.timeSeries[.heartRateVariability],
              let hrvBaseline = context.baselines[.heartRateVariability] else { return nil }

        let recent7 = hrvSeries.samples(lastDays: 7)
        guard recent7.count >= 4 else { return nil }

        let recentAvg = recent7.map(\.value).mean
        let deviation = (recentAvg - hrvBaseline.mean) / max(hrvBaseline.standardDeviation, 1)

        let score: Double
        let detail: String
        if deviation > 0.5 {
            score = 0.6
            detail = Copy.Analysis.Research.WellbeingTrend.autonomicStrong
        } else if deviation > -0.5 {
            score = 0.2
            detail = Copy.Analysis.Research.WellbeingTrend.autonomicNormal
        } else if deviation > -1.5 {
            score = -0.4
            detail = Copy.Analysis.Research.WellbeingTrend.autonomicBelowBaseline
        } else {
            score = -0.8
            detail = Copy.Analysis.Research.WellbeingTrend.autonomicSuppressed
        }

        return WellbeingSignal(score: score, weight: 0.15, detail: detail)
    }
}

// MARK: - InsightAnalyzer Conformance

extension WellbeingTrendAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "wellbeingTrend" }
    static var insightCategory: InsightCategory { .cognitiveEnergy }
}
