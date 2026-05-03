import Foundation

/// Finding: Wearable-derived HRV detects systemic inflammation via vagal withdrawal.
/// Sustained drop in overnight HRV RMSSD for 3-5 consecutive nights precedes
/// inflammatory events (IBD flares, RA flares, infections).
/// Low HRV = high CRP surrogate.
///
/// Also: Wrist temperature + HRV compound signal for infection early warning.
///
/// Implementation: Tracks rolling 5-day HRV slope. When HRV drops >1 SD below
/// baseline for 3+ consecutive nights without exercise load increase, surfaces
/// inflammation risk signal. Compounds with wrist temperature elevation.
struct InflammationRiskAnalyzer {

    // MARK: - Constants

    private static let minDaysRequired = 30 // Need baseline history
    private static let consecutiveDropThreshold = 3 // Nights of declining HRV
    private static let temperatureElevationThreshold = 0.3 // °C above baseline

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let hrvSeries = context.timeSeries[.heartRateVariability],
              let hrvBaseline = context.baselines[.heartRateVariability] else { return [] }

        let samples = hrvSeries.samples(lastDays: 60)
        guard samples.count >= minDaysRequired else { return [] }

        // Sort chronologically and get last 14 days
        let sorted = samples.sorted { $0.date < $1.date }
        let recent14 = Array(sorted.suffix(14))
        guard recent14.count >= 7 else { return [] }

        // Compute rolling 5-day HRV averages
        let recentValues = recent14.map(\.value)
        var rollingAverages: [Double] = []
        for i in 4..<recentValues.count {
            let window = Array(recentValues[(i-4)...i])
            rollingAverages.append(window.mean)
        }

        guard rollingAverages.count >= 3 else { return [] }

        // Detect consecutive decline
        var consecutiveDeclines = 0
        for i in 1..<rollingAverages.count {
            if rollingAverages[i] < rollingAverages[i-1] {
                consecutiveDeclines += 1
            } else {
                consecutiveDeclines = 0
            }
        }

        // Current HRV relative to baseline
        let currentHRV = Array(recentValues.suffix(5)).mean
        let hrvDeviation = (currentHRV - hrvBaseline.mean) / max(hrvBaseline.standardDeviation, 1)
        let hrvDropPercent = ((hrvBaseline.mean - currentHRV) / max(hrvBaseline.mean, 1)) * 100

        // Check if exercise load increased (which explains HRV drop)
        let exerciseLoadIncreased = isExerciseLoadElevated(context: context)

        // Check wrist temperature for compound signal
        let temperatureElevated = isTemperatureElevated(context: context)

        // Compound inflammation signal: HRV down + temperature up
        let isCompoundSignal = hrvDeviation < -1.0 && temperatureElevated && !exerciseLoadIncreased

        if isCompoundSignal {
            let dropText = String(format: "%.0f", hrvDropPercent)
            let currentText = String(format: "%.0f", currentHRV)
            let baselineText = String(format: "%.0f", hrvBaseline.mean)
            insights.append(InsightFactory.make(
                metric: .heartRateVariability,
                title: Copy.Analysis.Research.InflammationRisk.bodyStressSignalTitle,
                summary: Copy.Analysis.Research.InflammationRisk.bodyStressSummary(dropPercent: dropText),
                recommendation: Copy.Analysis.Research.InflammationRisk.bodyStressRecommendation(currentHRV: currentText, baseline: baselineText),
                severity: .warning,
                trend: .declining,
                currentValue: currentHRV,
                baselineValue: hrvBaseline.mean,
                deviationPercent: -hrvDropPercent,
                category: .watchSignal,
                directive: .rest,
                relatedMetrics: [.heartRateVariability, .appleSleepingWristTemperature, .restingHeartRate],
                context: InsightContext(
                    slope: rollingAverages.count >= 2 ? (rollingAverages.last! - rollingAverages.first!) / Double(rollingAverages.count) : nil,
                    confidenceLevel: 0.85,
                    dataPointCount: recent14.count
                )
            ))
        } else if hrvDeviation < -1.0 && consecutiveDeclines >= consecutiveDropThreshold && !exerciseLoadIncreased {
            let dropText = String(format: "%.0f", hrvDropPercent)
            let currentText = String(format: "%.0f", currentHRV)
            let baselineText = String(format: "%.0f", hrvBaseline.mean)
            insights.append(InsightFactory.make(
                metric: .heartRateVariability,
                title: Copy.Analysis.Research.InflammationRisk.elevatedBodyStressTitle,
                summary: Copy.Analysis.Research.InflammationRisk.elevatedBodyStressSummary(consecutiveDeclines: consecutiveDeclines, dropPercent: dropText),
                recommendation: Copy.Analysis.Research.InflammationRisk.elevatedBodyStressRecommendation(currentHRV: currentText, baseline: baselineText, days: recent14.count),
                severity: hrvDeviation < -2.0 ? .warning : .info,
                trend: .declining,
                currentValue: currentHRV,
                baselineValue: hrvBaseline.mean,
                deviationPercent: -hrvDropPercent,
                category: .watchSignal,
                directive: hrvDeviation < -2.0 ? .rest : .informational,
                relatedMetrics: [.heartRateVariability, .restingHeartRate],
                context: InsightContext(
                    slope: rollingAverages.count >= 2 ? (rollingAverages.last! - rollingAverages.first!) / Double(rollingAverages.count) : nil,
                    confidenceLevel: min(0.6 + Double(consecutiveDeclines) * 0.1, 0.9),
                    dataPointCount: recent14.count
                )
            ))
        }

        // Positive insight: Strong vagal tone = low inflammation
        if hrvDeviation > 1.0 && currentHRV > hrvBaseline.mean * 1.1 {
            let aboveText = String(format: "%.0f", abs(hrvDropPercent))
            let currentText = String(format: "%.0f", currentHRV)
            let baselineText = String(format: "%.0f", hrvBaseline.mean)
            insights.append(InsightFactory.observation(
                metric: .heartRateVariability,
                title: Copy.Analysis.Research.InflammationRisk.strongRecoveryToneTitle,
                summary: Copy.Analysis.Research.InflammationRisk.strongRecoverySummary(abovePercent: aboveText),
                recommendation: Copy.Analysis.Research.InflammationRisk.strongRecoveryRecommendation(currentHRV: currentText, baseline: baselineText),
                currentValue: currentHRV,
                baselineValue: hrvBaseline.mean,
                deviationPercent: ((currentHRV - hrvBaseline.mean) / max(hrvBaseline.mean, 1)) * 100,
                category: .recovery,
                relatedMetrics: [.heartRateVariability, .restingHeartRate]
            ))
        }

        return insights
    }

    // MARK: - Helpers

    private static func isExerciseLoadElevated(context: AnalysisContext) -> Bool {
        guard let calSeries = context.timeSeries[.activeCalories] else { return false }
        let recent7 = calSeries.samples(lastDays: 7)
        let prior7 = calSeries.samples(lastDays: 14).filter { sample in
            sample.date < Date.cal.date(byAdding: .day, value: -7, to: Date())!
        }

        guard recent7.count >= 3, prior7.count >= 3 else { return false }

        let recentAvg = recent7.map(\.value).mean
        let priorAvg = prior7.map(\.value).mean
        guard priorAvg > 0 else { return false }

        return (recentAvg - priorAvg) / priorAvg > 0.25 // >25% increase
    }

    private static func isTemperatureElevated(context: AnalysisContext) -> Bool {
        guard let tempSeries = context.timeSeries[.appleSleepingWristTemperature],
              let tempBaseline = context.baselines[.appleSleepingWristTemperature] else { return false }

        let recent = tempSeries.samples(lastDays: 3)
        guard recent.count >= 2 else { return false }

        let recentAvg = recent.map(\.value).mean
        return recentAvg > tempBaseline.mean + temperatureElevationThreshold
    }
}

// MARK: - InsightAnalyzer Conformance

extension InflammationRiskAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "inflammationRisk" }
    static var insightCategory: InsightCategory { .watchSignal }
}
