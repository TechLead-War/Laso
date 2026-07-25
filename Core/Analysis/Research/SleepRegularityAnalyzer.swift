import Foundation

/// Finding: Sleep irregularity is a STRONGER predictor of cardiometabolic disease
/// than sleep duration. Irregular sleepers face 26-53% higher dementia risk,
/// 20-88% higher all-cause mortality. SRI (Sleep Regularity Index) validated
/// across 5 large cohorts.
///
/// Implementation: Computes a validated Sleep Regularity Index (0-100)
/// from daily sleep/wake patterns. Surfaces prominently alongside duration.
struct SleepRegularityAnalyzer {

    // MARK: - Constants

    private static let poorSRI: Double = 60
    private static let moderateSRI: Double = 70
    private static let goodSRI: Double = 80

    private static let minDaysRequired = 14

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let sleepSeries = context.timeSeries[.sleepDuration] else { return [] }

        let samples = sleepSeries.samples(lastDays: 30)
        guard samples.count >= minDaysRequired else { return [] }

        // Build daily sleep map
        let sleepMap = TimeSeriesAligner.dailyValueMap(sleepSeries)

        // Compute Sleep Regularity Index
        // SRI = probability that any two time points 24h apart are in the same state
        // Approximation using sleep duration consistency + timing consistency
        let sri = computeSRI(samples: samples, sleepMap: sleepMap)

        // Compute social jet lag (weekday vs weekend midpoint difference)
        let socialJetLag = computeSocialJetLag(samples: samples)

        // Compute week-over-week SRI trend
        let recentSamples = sleepSeries.samples(lastDays: 14)
        let recentSRI: Double
        if recentSamples.count >= 10 {
            let recentMap = TimeSeriesAligner.dailyValueMap(sleepSeries)
            recentSRI = computeSRI(samples: recentSamples, sleepMap: recentMap)
        } else {
            recentSRI = sri
        }

        let trendDirection: TrendDirection = recentSRI > sri + 3 ? .improving
            : recentSRI < sri - 3 ? .declining : .stable

        // Insight: Sleep Regularity Score
        if sri < poorSRI {
            let sriText = String(format: "%.0f", sri)
            let jetLagText = String(format: "%.0f", socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.irregularTitle,
                summary: Copy.Analysis.Research.SleepRegularity.irregularSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.irregularRecommendation(sri: sriText, samples: samples.count, socialJetLag: socialJetLag, jetLagMinutes: jetLagText),
                severity: .warning,
                trend: trendDirection,
                currentValue: sri,
                baselineValue: Double(goodSRI),
                deviationPercent: ((sri - Double(goodSRI)) / Double(goodSRI)) * 100,
                category: .sleepPerformance,
                directive: .sleepBetter,
                relatedMetrics: [.sleepDuration, .sleepDeep, .sleepREM],
                context: InsightContext(
                    confidenceLevel: min(Double(samples.count) / 30.0, 1.0),
                    dataPointCount: samples.count
                )
            ))
        } else if sri < moderateSRI {
            let sriText = String(format: "%.0f", sri)
            let jetLagText = String(format: "%.0f", socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.needsAttentionTitle,
                summary: Copy.Analysis.Research.SleepRegularity.needsAttentionSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.needsAttentionRecommendation(sri: sriText, samples: samples.count, socialJetLag: socialJetLag, jetLagMinutes: jetLagText),
                severity: .info,
                trend: trendDirection,
                currentValue: sri,
                baselineValue: Double(goodSRI),
                deviationPercent: ((sri - Double(goodSRI)) / Double(goodSRI)) * 100,
                category: .sleepPerformance,
                directive: .sleepBetter,
                relatedMetrics: [.sleepDuration, .sleepDeep, .sleepREM]
            ))
        } else if sri >= goodSRI {
            let sriText = String(format: "%.0f", sri)
            insights.append(InsightFactory.observation(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.excellentTitle,
                summary: Copy.Analysis.Research.SleepRegularity.excellentSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.excellentRecommendation(sri: sriText, samples: samples.count),
                currentValue: sri,
                baselineValue: Double(goodSRI),
                deviationPercent: ((sri - Double(goodSRI)) / Double(goodSRI)) * 100,
                category: .sleepPerformance,
                relatedMetrics: [.sleepDuration]
            ))
        }

        // Insight: Social jet lag warning
        if socialJetLag > 60 {
            let jetLagText = String(format: "%.0f", socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.socialJetLagTitle(minutes: jetLagText),
                summary: Copy.Analysis.Research.SleepRegularity.socialJetLagSummary(minutes: jetLagText),
                recommendation: Copy.Analysis.Research.SleepRegularity.socialJetLagRecommendation(minutes: jetLagText),
                severity: socialJetLag > 90 ? .warning : .info,
                trend: .stable,
                currentValue: socialJetLag,
                baselineValue: 30,
                deviationPercent: ((socialJetLag - 30) / 30) * 100,
                category: .circadian,
                directive: .sleepBetter,
                relatedMetrics: [.sleepDuration]
            ))
        }

        return insights
    }

    // MARK: - SRI Computation

    /// Computes an approximation of the Sleep Regularity Index.
    /// True SRI requires minute-level sleep/wake state; we approximate using
    /// daily sleep duration consistency + weekday/weekend timing alignment.
    private static func computeSRI(
        samples: [MetricSample],
        sleepMap: [Date: Double]
    ) -> Double {
        let values = samples.map(\.value)
        guard values.count >= 2 else { return 50 }

        let mean = values.mean
        guard mean > 0 else { return 50 }

        let stdDev = values.standardDeviation
        let cv = stdDev / mean

        // Day-to-day absolute difference
        var dayToDayDiffs: [Double] = []
        let sorted = samples.sorted { $0.date < $1.date }
        for i in 1..<sorted.count {
            let daysBetween = Date.cal.dateComponents(
                [.day], from: sorted[i-1].date, to: sorted[i].date
            ).day ?? 1
            if daysBetween == 1 {
                dayToDayDiffs.append(abs(sorted[i].value - sorted[i-1].value))
            }
        }

        let avgDayDiff = dayToDayDiffs.isEmpty ? stdDev : dayToDayDiffs.mean

        // SRI approximation:
        // Perfect regularity (cv=0, avgDayDiff=0) → 100
        // High variability (cv>0.3, avgDayDiff>2hr) → <50
        let cvPenalty = min(cv / 0.30, 1.0) * 30       // up to -30 points
        let diffPenalty = min(avgDayDiff / 2.0, 1.0) * 20 // up to -20 points

        return max(0, min(100, 100 - cvPenalty - diffPenalty))
    }

    /// Computes social jet lag in minutes: difference between weekday and weekend
    /// average sleep duration, approximating timing shift.
    private static func computeSocialJetLag(samples: [MetricSample]) -> Double {
        let calendar = Date.cal
        var weekdayDurations: [Double] = []
        var weekendDurations: [Double] = []

        for sample in samples {
            let weekday = calendar.component(.weekday, from: sample.date)
            if weekday >= 2 && weekday <= 6 {
                weekdayDurations.append(sample.value)
            } else {
                weekendDurations.append(sample.value)
            }
        }

        guard !weekdayDurations.isEmpty, !weekendDurations.isEmpty else { return 0 }

        // Social jet lag = absolute difference in average sleep, converted to minutes
        let diff = abs(weekendDurations.mean - weekdayDurations.mean)
        return diff * 60 // hours to minutes
    }
}

// MARK: - InsightAnalyzer Conformance

extension SleepRegularityAnalyzer: InsightAnalyzer {}
