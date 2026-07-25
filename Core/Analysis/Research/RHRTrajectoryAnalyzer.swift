import Foundation

/// Heuristic — unvalidated. A rising resting heart rate over time is a
/// commonly cited long-term fitness signal; this analyzer surfaces those
/// trends so the user can spot changes early.
///
/// Implementation: Computes multi-month RHR trajectory slope.
/// Flags rising RHR when activity level hasn't declined.
struct RHRTrajectoryAnalyzer {

    // MARK: - Constants

    /// Rising RHR threshold: >1 bpm increase per 6 months while activity is stable
    private static let risingSlopeThreshold = 1.0 / 180.0 // bpm per day

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
            guard samples.count >= max(window.days / 5, 30),
                  let firstSample = samples.first else { continue }

            // Linear regression on RHR over time
            let startDate = firstSample.date.timeIntervalSince1970
            let xs = samples.map { $0.date.timeIntervalSince1970 - startDate }
            let ys = samples.map(\.value)
            let (slope, _) = linearRegression(x: xs, y: ys)

            // Convert slope to bpm per day
            let slopePerDay = slope * 86400 // seconds → days

            // Check if activity declined (which would explain rising RHR)
            let activityDeclined = isActivityDeclining(context: context, days: window.days)

            let totalChange = slopePerDay * Double(window.days)
            let currentRHR = samples.tailMean(7)
            let startRHR = Array(samples.prefix(7)).map(\.value).mean

            // Insight: Rising RHR without activity decline
            if slopePerDay > risingSlopeThreshold && !activityDeclined {
                let severity: Severity = totalChange >= 3 ? .warning : .info
                let changeText = String(format: "%.1f", abs(totalChange))
                let startText = String(format: "%.0f", startRHR)
                let currentText = String(format: "%.0f", currentRHR)

                insights.append(InsightFactory.make(
                    metric: .restingHeartRate,
                    title: Copy.Analysis.Research.RHRTrajectory.risingTitle,
                    summary: Copy.Analysis.Research.RHRTrajectory.risingSummary(change: changeText, windowLabel: window.label, startRHR: startText, currentRHR: currentText),
                    recommendation: Copy.Analysis.Research.RHRTrajectory.risingRecommendation(change: changeText, windowLabel: window.label, includeMedicalNote: totalChange >= 3),
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
                let changeText = String(format: "%.1f", abs(totalChange))
                let startText = String(format: "%.0f", startRHR)
                let currentText = String(format: "%.0f", currentRHR)
                insights.append(InsightFactory.observation(
                    metric: .restingHeartRate,
                    title: Copy.Analysis.Research.RHRTrajectory.improvingTitle,
                    summary: Copy.Analysis.Research.RHRTrajectory.improvingSummary(change: changeText, windowLabel: window.label, startRHR: startText, currentRHR: currentText),
                    recommendation: Copy.Analysis.Research.RHRTrajectory.improvingRecommendation,
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
            let secondHalf = samples.tailMean(samples.count / 2)
            guard firstHalf > 0 else { continue }

            let change = (secondHalf - firstHalf) / firstHalf
            if change < -0.15 { return true } // Activity declined >15%
        }
        return false
    }

    private static func linearRegression(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
        Array<Double>.linearRegression(x: x, y: y)
    }
}

// MARK: - InsightAnalyzer Conformance

extension RHRTrajectoryAnalyzer: InsightAnalyzer {}
