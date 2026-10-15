import Foundation

/// Heuristic, unvalidated. Scores how steady sleep duration is night to night
/// and how far the sleep midpoint shifts between weekdays and weekends.
///
/// This is NOT the Phillips et al. Sleep Regularity Index: that needs
/// minute-level sleep/wake state, which the daily series here does not carry,
/// so no cohort outcome from the SRI literature may be quoted against this
/// number. Social jet lag follows Roenneberg et al. (2006): the clock
/// difference between weekend and weekday sleep midpoints, not a difference
/// in hours slept.
struct SleepRegularityAnalyzer {

    // MARK: - Constants

    private static let poorSteadiness: Double = 60
    private static let moderateSteadiness: Double = 70
    private static let goodSteadiness: Double = 80

    private static let minDaysRequired = 14

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let sleepSeries = context.timeSeries[.sleepDuration] else { return [] }

        let samples = sleepSeries.samples(lastDays: 30)
        guard samples.count >= minDaysRequired else { return [] }

        let sri = computeSteadiness(samples: samples)

        let socialJetLag = computeSocialJetLag(samples: samples)

        // Week-over-week steadiness trend
        let recentSamples = sleepSeries.samples(lastDays: 14)
        let recentSRI: Double
        if recentSamples.count >= 10 {
            recentSRI = computeSteadiness(samples: recentSamples)
        } else {
            recentSRI = sri
        }

        let trendDirection: TrendDirection = recentSRI > sri + 3 ? .improving
            : recentSRI < sri - 3 ? .declining : .stable

        // Insight: sleep steadiness score
        if sri < poorSteadiness {
            let sriText = String(format: "%.0f", sri)
            let jetLagText = String(format: "%.0f", socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.irregularTitle,
                summary: Copy.Analysis.Research.SleepRegularity.irregularSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.irregularRecommendation(sri: sriText, samples: samples.count, socialJetLag: socialJetLag, jetLagMinutes: jetLagText),
                severity: .warning,
                trend: trendDirection,
                baselineValue: Double(goodSteadiness),
                deviationPercent: ((sri - Double(goodSteadiness)) / Double(goodSteadiness)) * 100,
                category: .sleepPerformance,
                directive: .sleepBetter,
                context: InsightContext(
                    confidenceLevel: min(Double(samples.count) / 30.0, 1.0),
                    dataPointCount: samples.count
                )
            ))
        } else if sri < moderateSteadiness {
            let sriText = String(format: "%.0f", sri)
            let jetLagText = String(format: "%.0f", socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.needsAttentionTitle,
                summary: Copy.Analysis.Research.SleepRegularity.needsAttentionSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.needsAttentionRecommendation(sri: sriText, samples: samples.count, socialJetLag: socialJetLag, jetLagMinutes: jetLagText),
                severity: .info,
                trend: trendDirection,
                baselineValue: Double(goodSteadiness),
                deviationPercent: ((sri - Double(goodSteadiness)) / Double(goodSteadiness)) * 100,
                category: .sleepPerformance,
                directive: .sleepBetter,
            ))
        } else if sri >= goodSteadiness {
            let sriText = String(format: "%.0f", sri)
            insights.append(InsightFactory.observation(
                metric: .sleepDuration,
                title: Copy.Analysis.Research.SleepRegularity.excellentTitle,
                summary: Copy.Analysis.Research.SleepRegularity.excellentSummary(sri: sriText),
                recommendation: Copy.Analysis.Research.SleepRegularity.excellentRecommendation(sri: sriText, samples: samples.count),
                baselineValue: Double(goodSteadiness),
                deviationPercent: ((sri - Double(goodSteadiness)) / Double(goodSteadiness)) * 100,
                category: .sleepPerformance,
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
                baselineValue: 30,
                deviationPercent: ((socialJetLag - 30) / 30) * 100,
                category: .circadian,
                directive: .sleepBetter,
            ))
        }

        return insights
    }

    // MARK: - Steadiness

    /// 0 to 100 from how much nightly duration varies (coefficient of variation)
    /// and how much it jumps between consecutive nights. Duration only; timing
    /// is read separately through the midpoint helpers below.
    private static func computeSteadiness(samples: [MetricSample]) -> Double {
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

        // Perfect steadiness (cv=0, avgDayDiff=0) → 100
        // High variability (cv>0.3, avgDayDiff>2hr) → <50
        let cvPenalty = min(cv / 0.30, 1.0) * 30       // up to -30 points
        let diffPenalty = min(avgDayDiff / 2.0, 1.0) * 20 // up to -20 points

        return max(0, min(100, 100 - cvPenalty - diffPenalty))
    }

    // MARK: - Sleep Timing

    /// Clock time of the middle of a night's sleep, in minutes from noon
    /// (3 am reads 900, 11 pm reads 660). Noon-based so a midpoint either side of
    /// midnight averages correctly; the seam sits at noon, where no overnight
    /// midpoint falls. A `sleepDuration` sample is stamped at wake time and
    /// holds hours slept, so the midpoint is wake minus half the duration.
    static func sleepMidpointMinutesFromNoon(_ sample: MetricSample) -> Double {
        let midpoint = sample.date.addingTimeInterval(-sample.value * 1800)
        let parts = Date.cal.dateComponents([.hour, .minute], from: midpoint)
        let sinceMidnight = Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0)
        return (sinceMidnight + 720).truncatingRemainder(dividingBy: 1440)
    }

    /// Social jet lag in minutes: how far the weekend sleep midpoint sits from
    /// the weekday one (Roenneberg et al. 2006, Chronobiol Int). A night counts
    /// as weekend when it ends on Saturday or Sunday.
    private static func computeSocialJetLag(samples: [MetricSample]) -> Double {
        let calendar = Date.cal
        var weekdayMidpoints: [Double] = []
        var weekendMidpoints: [Double] = []

        for sample in samples {
            let weekday = calendar.component(.weekday, from: sample.date)
            if weekday >= 2 && weekday <= 6 {
                weekdayMidpoints.append(sleepMidpointMinutesFromNoon(sample))
            } else {
                weekendMidpoints.append(sleepMidpointMinutesFromNoon(sample))
            }
        }

        guard !weekdayMidpoints.isEmpty, !weekendMidpoints.isEmpty else { return 0 }
        return abs(weekendMidpoints.mean - weekdayMidpoints.mean)
    }
}

// MARK: - InsightAnalyzer Conformance

extension SleepRegularityAnalyzer: InsightAnalyzer {}
