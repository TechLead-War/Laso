import Foundation

/// Research: Apple Heart & Movement Study (2026) + multiple population studies.
/// Finding: VO2max is one of the strongest indicators of long-term fitness and
/// overall wellness. Each 1 MET increase is associated with meaningful improvements.
/// Age/sex percentile tables now available from large populations.
///
/// Implementation: Maps user's VO2max to population percentile by age bracket,
/// computes a Cardiorespiratory Age, and tracks VO2max trajectory over months.
struct CardioRespiratoryAgeAnalyzer {

    // MARK: - VO2max Percentile Tables (from Apple Heart & Movement Study 2026)
    // Approximated from published averages + population distributions.
    // Format: (percentile, VO2max) for combined sex.

    private struct AgeBracket {
        let ageRange: String
        let p10: Double // Poor
        let p25: Double // Below average
        let p50: Double // Average
        let p75: Double // Good
        let p90: Double // Excellent
        let p95: Double // Superior
    }

    /// Percentile brackets by age (mL/kg/min), combined sex averages
    private static let brackets: [AgeBracket] = [
        AgeBracket(ageRange: "18-29", p10: 28, p25: 32, p50: 35, p75: 40, p90: 45, p95: 50),
        AgeBracket(ageRange: "30-39", p10: 26, p25: 30, p50: 33, p75: 37, p90: 42, p95: 47),
        AgeBracket(ageRange: "40-49", p10: 24, p25: 28, p50: 31, p75: 35, p90: 39, p95: 44),
        AgeBracket(ageRange: "50-59", p10: 22, p25: 26, p50: 29, p75: 33, p90: 37, p95: 41),
        AgeBracket(ageRange: "60-69", p10: 20, p25: 24, p50: 27, p75: 30, p90: 34, p95: 38),
        AgeBracket(ageRange: "70-79", p10: 18, p25: 22, p50: 25, p75: 28, p90: 31, p95: 35),
        AgeBracket(ageRange: "80+", p10: 16, p25: 20, p50: 24, p75: 27, p90: 30, p95: 33),
    ]

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let vo2Series = context.timeSeries[.vo2Max] else { return [] }

        let recent = vo2Series.samples(lastDays: 90)
        guard recent.count >= 3 else { return [] }

        let currentVO2 = Array(recent.suffix(5)).map(\.value).mean

        // Find which age bracket this VO2max is "average" for
        let fitnessAge = findFitnessAge(vo2max: currentVO2)

        // Compute percentile (approximate. we don't know user's exact age)
        // Use middle bracket as reference and find where they fall
        let refBracket = brackets[2] // 40-49 as middle reference
        let percentile = computePercentile(vo2max: currentVO2, bracket: refBracket)

        // Compute trajectory
        let allSamples = vo2Series.samples(lastDays: 365)
        var trajectory: TrendDirection = .stable
        var changeOverPeriod: Double = 0
        var monthsTracked = 0

        if allSamples.count >= 5 {
            let sorted = allSamples.sorted { $0.date < $1.date }
            let firstValues = Array(sorted.prefix(max(3, sorted.count / 4))).map(\.value).mean
            let lastValues = Array(sorted.suffix(max(3, sorted.count / 4))).map(\.value).mean
            changeOverPeriod = lastValues - firstValues

            let daysSpanned: Int
            if let firstDate = sorted.first?.date, let lastDate = sorted.last?.date {
                daysSpanned = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
            } else {
                daysSpanned = 0
            }
            monthsTracked = max(1, daysSpanned / 30)

            trajectory = changeOverPeriod > 0.5 ? .improving
                : changeOverPeriod < -0.5 ? .declining : .stable
        }

        // Insight 1: VO2max fitness age equivalent
        insights.append(InsightFactory.observation(
            metric: .vo2Max,
            title: "Cardio Fitness Age: ~\(String(format: "%.0f", fitnessAge))",
            summary: "Your VO2max of \(String(format: "%.1f", currentVO2)) mL/kg/min is average for someone around age \(String(format: "%.0f", fitnessAge)). VO2max is one of the most important indicators of long-term fitness and overall wellness.",
            recommendation: "At \(String(format: "%.1f", currentVO2)) mL/kg/min, your cardiorespiratory fitness places you approximately at the \(String(format: "%.0f", percentile))th percentile for a middle-aged adult. Each 1 MET (~3.5 mL/kg/min) improvement is associated with meaningful health benefits.",
            severity: .info,
            trend: trajectory,
            currentValue: currentVO2,
            baselineValue: refBracket.p50,
            deviationPercent: ((currentVO2 - refBracket.p50) / max(refBracket.p50, 1)) * 100,
            category: .clinicalTrajectory,
            relatedMetrics: [.vo2Max, .exerciseMinutes, .heartRateRecovery, .restingHeartRate],
            context: InsightContext(
                confidenceLevel: min(Double(recent.count) / 10.0, 1.0),
                dataPointCount: recent.count
            )
        ))

        // Insight 2: VO2max trajectory
        if monthsTracked >= 3 && allSamples.count >= 5 {
            if trajectory == .improving && changeOverPeriod >= 1.0 {
                insights.append(InsightFactory.observation(
                    metric: .vo2Max,
                    title: "VO2max Improving: +\(String(format: "%.1f", changeOverPeriod)) Over \(monthsTracked) Months",
                    summary: "Your cardiorespiratory fitness has improved by \(String(format: "%.1f", changeOverPeriod)) mL/kg/min over \(monthsTracked) months. This is a meaningful fitness gain based on population wellness studies.",
                    recommendation: "A \(String(format: "%.1f", changeOverPeriod)) mL/kg/min VO2max improvement represents real progress. This shifts your fitness age younger and is associated with better long-term wellness outcomes.",
                    currentValue: currentVO2,
                    baselineValue: currentVO2 - changeOverPeriod,
                    deviationPercent: (changeOverPeriod / max(currentVO2 - changeOverPeriod, 1)) * 100,
                    category: .clinicalTrajectory,
                    relatedMetrics: [.vo2Max, .exerciseMinutes, .activeCalories]
                ))
            } else if trajectory == .declining && changeOverPeriod <= -1.0 {
                insights.append(InsightFactory.make(
                    metric: .vo2Max,
                    title: "VO2max Declining: \(String(format: "%.1f", changeOverPeriod)) Over \(monthsTracked) Months",
                    summary: "Your cardiorespiratory fitness has dropped by \(String(format: "%.1f", abs(changeOverPeriod))) mL/kg/min over \(monthsTracked) months. Since VO2max is a key fitness indicator, this trend is worth reversing.",
                    recommendation: "A \(String(format: "%.1f", abs(changeOverPeriod))) mL/kg/min decline shifts your fitness age older. The decline rate of \(String(format: "%.1f", abs(changeOverPeriod / Double(monthsTracked)))) mL/kg/min per month is faster than typical aging (~1 to 2 mL/kg/min per decade). Increasing aerobic exercise frequency or intensity can help reverse this.",
                    severity: abs(changeOverPeriod) >= 2.0 ? .warning : .info,
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

        // Insight 3: Very low VO2max warning
        if currentVO2 < 20 {
            insights.append(InsightFactory.medicalAdvice(
                metric: .vo2Max,
                title: "VO2max Below Typical Threshold",
                summary: "Your VO2max of \(String(format: "%.1f", currentVO2)) mL/kg/min is below 20. a threshold associated with reduced fitness capacity across all age groups.",
                recommendation: "A VO2max below 20 mL/kg/min places you in the lowest fitness category regardless of age. Population studies consistently show this threshold as an important point for overall wellness. Even modest improvements from this baseline can make a meaningful difference.",
                trend: trajectory,
                currentValue: currentVO2,
                baselineValue: 20,
                deviationPercent: ((currentVO2 - 20) / 20) * 100,
                relatedMetrics: [.vo2Max, .exerciseMinutes, .restingHeartRate]
            ))
        }

        return insights
    }

    // MARK: - Helpers

    /// Find the age at which this VO2max is the 50th percentile
    private static func findFitnessAge(vo2max: Double) -> Double {
        let ageMidpoints: [Double] = [24, 35, 45, 55, 65, 75, 85]

        for i in 0..<brackets.count {
            if vo2max >= brackets[i].p50 {
                if i == 0 {
                    // Better than youngest bracket's average
                    let excess = (vo2max - brackets[0].p50) / max(brackets[0].p50 - (brackets.count > 1 ? brackets[1].p50 : brackets[0].p50 - 5), 1)
                    return max(15, ageMidpoints[0] - excess * 10)
                }
                // Interpolate between this bracket and the one before
                let prevP50 = brackets[i-1].p50
                let currP50 = brackets[i].p50
                let fraction = (prevP50 - vo2max) / max(prevP50 - currP50, 0.1)
                return ageMidpoints[i-1] + fraction * (ageMidpoints[i] - ageMidpoints[i-1])
            }
        }

        // Below the lowest bracket
        return min(90, (ageMidpoints.last ?? 85) + 5)
    }

    /// Approximate percentile within a bracket
    private static func computePercentile(vo2max: Double, bracket: AgeBracket) -> Double {
        let thresholds: [(percentile: Double, value: Double)] = [
            (5, bracket.p10 - 3),
            (10, bracket.p10),
            (25, bracket.p25),
            (50, bracket.p50),
            (75, bracket.p75),
            (90, bracket.p90),
            (95, bracket.p95),
        ]

        guard let firstThreshold = thresholds.first, let lastThreshold = thresholds.last else { return 50 }
        if vo2max <= firstThreshold.value { return 5 }
        if vo2max >= lastThreshold.value { return 97 }

        for i in 0..<(thresholds.count - 1) {
            if vo2max >= thresholds[i].value && vo2max < thresholds[i+1].value {
                let fraction = (vo2max - thresholds[i].value) / max(thresholds[i+1].value - thresholds[i].value, 0.1)
                return thresholds[i].percentile + fraction * (thresholds[i+1].percentile - thresholds[i].percentile)
            }
        }

        return 50
    }
}

// MARK: - InsightAnalyzer Conformance

extension CardioRespiratoryAgeAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "cardioRespiratoryAge" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }
}
