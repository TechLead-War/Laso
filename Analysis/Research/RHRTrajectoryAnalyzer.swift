import Foundation

/// Research: AHA (Nov 2024) + Nature (Sept 2024) + Lancet (Jan 2025)
/// Finding: Rising resting heart rate over years = 65% higher heart failure risk,
/// 69% higher all-cause mortality. RHR is "the forgotten risk factor" —
/// stronger predictor than hypertension in 692K adults.
///
/// Implementation: Computes multi-month RHR trajectory slope.
/// Flags rising RHR when activity level hasn't declined.
struct RHRTrajectoryAnalyzer {

    // MARK: - Constants

    /// Minimum days of data to compute meaningful trajectory
    private static let minDaysRequired = 90

    /// Rising RHR threshold: >1 bpm increase per 6 months while activity is stable
    private static let risingSlopeThreshold = 1.0 / 180.0 // bpm per day

    /// Population norms: RHR should gently decline with regular activity over years
    /// AHA data: normal aging = slight decrease in RHR
    private static let normalAgingSlope = -0.002 // ~-0.7 bpm/year decline is normal

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let rhrSeries = context.timeSeries[.restingHeartRate] else { return [] }

        // Compute trajectory across available windows: 90d, 180d, 365d
        let windows: [(days: Int, label: String)] = [
            (365, "12-month"),
            (180, "6-month"),
            (90, "3-month"),
        ]

        for window in windows {
            let samples = rhrSeries.samples(lastDays: window.days)
            guard samples.count >= max(window.days / 5, 30) else { continue }

            // Linear regression on RHR over time
            let startDate = samples.first!.date.timeIntervalSince1970
            let xs = samples.map { $0.date.timeIntervalSince1970 - startDate }
            let ys = samples.map(\.value)
            let (slope, _) = linearRegression(x: xs, y: ys)

            // Convert slope to bpm per day
            let slopePerDay = slope * 86400 // seconds → days

            // Check if activity declined (which would explain rising RHR)
            let activityDeclined = isActivityDeclining(context: context, days: window.days)

            let totalChange = slopePerDay * Double(window.days)
            let currentRHR = Array(samples.suffix(7)).map(\.value).mean
            let startRHR = Array(samples.prefix(7)).map(\.value).mean

            // Insight: Rising RHR without activity decline
            if slopePerDay > risingSlopeThreshold && !activityDeclined {
                let severity: Severity = totalChange >= 3 ? .warning : .info

                insights.append(InsightFactory.make(
                    metric: .restingHeartRate,
                    title: "Resting Heart Rate Rising",
                    summary: "Your resting heart rate has increased by \(String(format: "%.1f", abs(totalChange))) bpm over the past \(window.label) — from \(String(format: "%.0f", startRHR)) to \(String(format: "%.0f", currentRHR)) bpm — without a decline in your activity levels.",
                    recommendation: "Research on 692,000+ adults shows a rising resting heart rate is a stronger predictor of cardiovascular events than hypertension. A \(String(format: "%.1f", abs(totalChange))) bpm rise over \(window.label) while maintaining activity warrants attention.\(totalChange >= 3 ? " Consider discussing this trajectory with your doctor." : "")",
                    severity: severity,
                    trend: .declining,
                    currentValue: currentRHR,
                    baselineValue: startRHR,
                    deviationPercent: ((currentRHR - startRHR) / max(startRHR, 1)) * 100,
                    category: .clinicalTrajectory,
                    directive: totalChange >= 5 ? .seekMedical : .informational,
                    relatedMetrics: [.restingHeartRate, .heartRateVariability, .activeCalories],
                    context: InsightContext(
                        slope: slopePerDay,
                        confidenceLevel: min(Double(samples.count) / Double(window.days), 1.0),
                        dataPointCount: samples.count
                    )
                ))
                break // Report longest window that qualifies
            }

            // Insight: Improving RHR trajectory
            if slopePerDay < normalAgingSlope * 2 && totalChange <= -2 {
                insights.append(InsightFactory.observation(
                    metric: .restingHeartRate,
                    title: "Heart Rate Trajectory Improving",
                    summary: "Your resting heart rate has dropped \(String(format: "%.1f", abs(totalChange))) bpm over the past \(window.label) — from \(String(format: "%.0f", startRHR)) to \(String(format: "%.0f", currentRHR)) bpm. This trajectory is associated with reduced cardiovascular risk.",
                    recommendation: "A declining RHR trajectory reflects improved cardiovascular efficiency. Each 1 bpm decrease in long-term RHR is independently associated with reduced all-cause mortality risk across multiple cohort studies.",
                    currentValue: currentRHR,
                    baselineValue: startRHR,
                    deviationPercent: ((currentRHR - startRHR) / max(startRHR, 1)) * 100,
                    category: .clinicalTrajectory,
                    relatedMetrics: [.restingHeartRate, .vo2Max, .exerciseMinutes],
                    context: InsightContext(
                        slope: slopePerDay,
                        dataPointCount: samples.count
                    )
                ))
                break
            }
        }

        return insights
    }

    // MARK: - Helpers

    private static func isActivityDeclining(context: AnalysisContext, days: Int) -> Bool {
        let activityMetrics: [HealthMetric] = [.activeCalories, .steps, .exerciseMinutes]

        for metric in activityMetrics {
            guard let series = context.timeSeries[metric] else { continue }
            let samples = series.samples(lastDays: days)
            guard samples.count >= 20 else { continue }

            let firstHalf = Array(samples.prefix(samples.count / 2)).map(\.value).mean
            let secondHalf = Array(samples.suffix(samples.count / 2)).map(\.value).mean
            guard firstHalf > 0 else { continue }

            let change = (secondHalf - firstHalf) / firstHalf
            if change < -0.15 { return true } // Activity declined >15%
        }
        return false
    }

    private static func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
        let n = Double(x.count)
        guard n > 1 else { return (0, y.first ?? 0) }

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)

        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 1e-10 else { return (0, sumY / n) }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        return (slope, intercept)
    }
}

// MARK: - InsightAnalyzer Conformance

extension RHRTrajectoryAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "rhrTrajectory" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }
}
