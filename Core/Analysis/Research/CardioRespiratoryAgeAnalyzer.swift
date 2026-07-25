import Foundation

/// Finding: VO2max is one of the strongest indicators of long-term fitness and
/// overall wellness. Each 1 MET increase is associated with meaningful improvements.
///
/// Implementation: Maps user's VO2max to a population percentile by age bracket,
/// computes a Cardiorespiratory Age, and tracks VO2max trajectory over months.
/// All bracket cutoffs and percentile points live in `CardioRespiratoryAgeConfig`.
struct CardioRespiratoryAgeAnalyzer {

    private typealias Cfg = CardioRespiratoryAgeConfig
    private typealias AgeBracket = CardioRespiratoryAgeConfig.AgeBracket

    private static let brackets = Cfg.brackets

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let vo2Series = context.timeSeries[.vo2Max] else { return [] }

        let recent = vo2Series.samples(lastDays: Cfg.recentVO2WindowDays)
        guard recent.count >= Cfg.minSamplesForAnalysis else { return [] }

        let currentVO2 = recent.tailMean(Cfg.recentVO2MeanWindow)

        let fitnessAge = findFitnessAge(vo2max: currentVO2)

        let refBracket = brackets[Cfg.referenceBracketIndex]
        let percentile = computePercentile(vo2max: currentVO2, bracket: refBracket)

        let allSamples = vo2Series.samples(lastDays: Cfg.trajectoryWindowDays)
        var trajectory: TrendDirection = .stable
        var changeOverPeriod: Double = 0
        var monthsTracked = 0

        if allSamples.count >= Cfg.trajectoryMinSamples {
            let sorted = allSamples.sorted { $0.date < $1.date }
            let segmentSize = max(Cfg.trajectorySegmentMinSize, sorted.count / Cfg.trajectorySegmentDivisor)
            let firstValues = Array(sorted.prefix(segmentSize)).map(\.value).mean
            let lastValues = sorted.tailMean(segmentSize)
            changeOverPeriod = lastValues - firstValues

            let daysSpanned: Int
            if let firstDate = sorted.first?.date, let lastDate = sorted.last?.date {
                daysSpanned = Date.cal.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            } else {
                daysSpanned = 0
            }
            monthsTracked = max(1, daysSpanned / 30)

            trajectory = changeOverPeriod > Cfg.trajectoryStableBand ? .improving
                : changeOverPeriod < -Cfg.trajectoryStableBand ? .declining : .stable
        }

        let ageText = String(format: "%.0f", fitnessAge)
        let vo2Text = String(format: "%.1f", currentVO2)
        let percentileText = String(format: "%.0f", percentile)
        insights.append(InsightFactory.observation(
            metric: .vo2Max,
            title: Copy.Analysis.Research.CardioRespiratoryAge.cardioFitnessAgeTitle(age: ageText),
            summary: Copy.Analysis.Research.CardioRespiratoryAge.cardioFitnessAgeSummary(vo2: vo2Text, age: ageText),
            recommendation: Copy.Analysis.Research.CardioRespiratoryAge.cardioFitnessAgeRecommendation(vo2: vo2Text, percentile: percentileText),
            severity: .info,
            trend: trajectory,
            currentValue: currentVO2,
            baselineValue: refBracket.p50,
            deviationPercent: ((currentVO2 - refBracket.p50) / max(refBracket.p50, 1)) * 100,
            category: .clinicalTrajectory,
            relatedMetrics: [.vo2Max, .exerciseMinutes, .heartRateRecovery, .restingHeartRate],
            context: InsightContext(
                confidenceLevel: min(Double(recent.count) / Cfg.confidenceFullSampleCount, 1.0),
                dataPointCount: recent.count
            )
        ))

        if monthsTracked >= Cfg.minMonthsTrackedForInsight && allSamples.count >= Cfg.trajectoryMinSamples {
            if trajectory == .improving && changeOverPeriod >= Cfg.trajectoryReportableChange {
                let changeText = String(format: "%.1f", changeOverPeriod)
                insights.append(InsightFactory.observation(
                    metric: .vo2Max,
                    title: Copy.Analysis.Research.CardioRespiratoryAge.vo2ImprovingTitle(change: changeText, months: monthsTracked),
                    summary: Copy.Analysis.Research.CardioRespiratoryAge.vo2ImprovingSummary(change: changeText, months: monthsTracked),
                    recommendation: Copy.Analysis.Research.CardioRespiratoryAge.vo2ImprovingRecommendation(change: changeText, months: monthsTracked),
                    currentValue: currentVO2,
                    baselineValue: currentVO2 - changeOverPeriod,
                    deviationPercent: (changeOverPeriod / max(currentVO2 - changeOverPeriod, 1)) * 100,
                    category: .clinicalTrajectory,
                    relatedMetrics: [.vo2Max, .exerciseMinutes, .activeCalories]
                ))
            } else if trajectory == .declining && changeOverPeriod <= -Cfg.trajectoryReportableChange {
                let changeText = String(format: "%.1f", changeOverPeriod)
                let absChangeText = String(format: "%.1f", abs(changeOverPeriod))
                let perMonthText = String(format: "%.1f", abs(changeOverPeriod / Double(monthsTracked)))
                insights.append(InsightFactory.make(
                    metric: .vo2Max,
                    title: Copy.Analysis.Research.CardioRespiratoryAge.vo2DecliningTitle(change: changeText, months: monthsTracked),
                    summary: Copy.Analysis.Research.CardioRespiratoryAge.vo2DecliningSummary(absChange: absChangeText, months: monthsTracked),
                    recommendation: Copy.Analysis.Research.CardioRespiratoryAge.vo2DecliningRecommendation(absChange: absChangeText, perMonth: perMonthText, months: monthsTracked),
                    severity: abs(changeOverPeriod) >= Cfg.warningDeclineMagnitude ? .warning : .info,
                    trend: .declining,
                    currentValue: currentVO2,
                    baselineValue: currentVO2 - changeOverPeriod,
                    deviationPercent: (changeOverPeriod / max(currentVO2 - changeOverPeriod, 1)) * 100,
                    category: .clinicalTrajectory,
                    directive: .increaseActivity,
                    relatedMetrics: [.vo2Max, .exerciseMinutes, .activeCalories]
                ))
            }
        }

        if currentVO2 < Cfg.veryLowVO2Threshold {
            let vo2BelowText = String(format: "%.1f", currentVO2)
            insights.append(InsightFactory.medicalAdvice(
                metric: .vo2Max,
                title: Copy.Analysis.Research.CardioRespiratoryAge.belowThresholdTitle,
                summary: Copy.Analysis.Research.CardioRespiratoryAge.belowThresholdSummary(vo2: vo2BelowText, threshold: Int(Cfg.veryLowVO2Threshold)),
                recommendation: Copy.Analysis.Research.CardioRespiratoryAge.belowThresholdRecommendation(threshold: Int(Cfg.veryLowVO2Threshold)),
                trend: trajectory,
                currentValue: currentVO2,
                baselineValue: Cfg.veryLowVO2Threshold,
                deviationPercent: ((currentVO2 - Cfg.veryLowVO2Threshold) / Cfg.veryLowVO2Threshold) * 100,
                relatedMetrics: [.vo2Max, .exerciseMinutes, .restingHeartRate]
            ))
        }

        return insights
    }

    // MARK: - Helpers

    /// Find the age at which this VO2max is the 50th percentile.
    private static func findFitnessAge(vo2max: Double) -> Double {
        let ageMidpoints = Cfg.bracketAgeMidpoints

        for i in 0..<brackets.count {
            if vo2max >= brackets[i].p50 {
                if i == 0 {
                    let neighborDelta = brackets.count > 1
                        ? brackets[0].p50 - brackets[1].p50
                        : Cfg.singleBracketFallbackDelta
                    let excess = (vo2max - brackets[0].p50) / max(neighborDelta, 1)
                    return max(Cfg.minExtrapolatedAge, ageMidpoints[0] - excess * Cfg.extrapolatedYearsPerExcessUnit)
                }
                let prevP50 = brackets[i-1].p50
                let currP50 = brackets[i].p50
                let fraction = (prevP50 - vo2max) / max(prevP50 - currP50, Cfg.percentileInterpolationEpsilon)
                return ageMidpoints[i-1] + fraction * (ageMidpoints[i] - ageMidpoints[i-1])
            }
        }

        return min(Cfg.maxExtrapolatedAge, (ageMidpoints.last ?? 85) + Cfg.belowAllBracketsAgeOffset)
    }

    /// Approximate percentile within a bracket using piecewise interpolation.
    private static func computePercentile(vo2max: Double, bracket: AgeBracket) -> Double {
        let thresholds: [(percentile: Double, value: Double)] = [
            (Cfg.percentileFloor, bracket.p10 - Cfg.lowestPercentileOffset),
            (10, bracket.p10),
            (25, bracket.p25),
            (50, bracket.p50),
            (75, bracket.p75),
            (90, bracket.p90),
            (95, bracket.p95)
        ]

        guard let firstThreshold = thresholds.first, let lastThreshold = thresholds.last else {
            return Cfg.percentileMidpointFallback
        }
        if vo2max <= firstThreshold.value { return Cfg.percentileFloor }
        if vo2max >= lastThreshold.value { return Cfg.percentileCeiling }

        for i in 0..<(thresholds.count - 1) {
            if vo2max >= thresholds[i].value && vo2max < thresholds[i+1].value {
                let fraction = (vo2max - thresholds[i].value) / max(thresholds[i+1].value - thresholds[i].value, Cfg.percentileInterpolationEpsilon)
                return thresholds[i].percentile + fraction * (thresholds[i+1].percentile - thresholds[i].percentile)
            }
        }

        return Cfg.percentileMidpointFallback
    }
}

// MARK: - InsightAnalyzer Conformance

extension CardioRespiratoryAgeAnalyzer: InsightAnalyzer {}
