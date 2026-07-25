import Foundation

/// Finding: Heart rate recovery (HRR) after exercise is one of the strongest
/// autonomic health markers. Abnormal recovery (<12 bpm drop in 1 min)
/// predicts mortality. HRR improves dose-response with 6+ months of exercise.
///
/// Implementation: Tracks HRR longitudinally, benchmarks against clinical
/// thresholds, shows improvement trajectory over months.
struct HRRFitnessAnalyzer {

    // MARK: - Clinical Thresholds (from literature)

    /// Abnormal HRR: <12 bpm drop in 1 minute (NEJM standard)
    private static let abnormalThreshold: Double = 12

    /// Good HRR: 20-30 bpm drop
    private static let goodThreshold: Double = 20

    /// Excellent HRR: >30 bpm drop
    private static let excellentThreshold: Double = 30

    private static let minSamplesRequired = 5

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let hrrSeries = context.timeSeries[.heartRateRecovery] else { return [] }

        let allSamples = hrrSeries.samples(lastDays: 365)
        guard allSamples.count >= minSamplesRequired,
              let lastAll = allSamples.last else { return [] }

        let recent = hrrSeries.samples(lastDays: 30)
        let currentHRR = recent.isEmpty ? lastAll.value : recent.map(\.value).mean

        // Compute trajectory over available data
        let sorted = allSamples.sorted { $0.date < $1.date }

        var trajectory: TrendDirection = .stable
        var totalChange: Double = 0

        if sorted.count >= 10 {
            let firstQuarter = Array(sorted.prefix(sorted.count / 4)).map(\.value).mean
            let lastQuarter = sorted.tailMean(sorted.count / 4)
            totalChange = lastQuarter - firstQuarter
            trajectory = totalChange > 2 ? .improving : totalChange < -2 ? .declining : .stable
        }

        let daysSpanned: Int
        if let firstDate = sorted.first?.date, let lastDate = sorted.last?.date {
            daysSpanned = Date.cal.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0
        } else {
            daysSpanned = 0
        }
        let monthsSpanned = max(1, daysSpanned / 30)

        // Insight 1: Current HRR assessment
        if currentHRR < abnormalThreshold {
            let currentText = String(format: "%.0f", currentHRR)
            insights.append(InsightFactory.make(
                metric: .heartRateRecovery,
                title: Copy.Analysis.Research.HRRFitness.belowClinicalTitle,
                summary: Copy.Analysis.Research.HRRFitness.belowClinicalSummary(currentHRR: currentText, threshold: Int(abnormalThreshold)),
                recommendation: Copy.Analysis.Research.HRRFitness.belowClinicalRecommendation(threshold: Int(abnormalThreshold), currentHRR: currentText, sampleCount: recent.count > 0 ? recent.count : allSamples.count),
                severity: .warning,
                trend: trajectory,
                baselineValue: abnormalThreshold,
                deviationPercent: ((currentHRR - abnormalThreshold) / abnormalThreshold) * 100,
                category: .clinicalTrajectory,
                directive: .increaseActivity,
                context: InsightContext(
                    slope: sorted.count >= 10 ? totalChange / Double(monthsSpanned) : nil,
                    confidenceLevel: min(Double(allSamples.count) / 20.0, 1.0),
                    dataPointCount: allSamples.count
                )
            ))
        } else if currentHRR >= excellentThreshold {
            let currentText = String(format: "%.0f", currentHRR)
            insights.append(InsightFactory.observation(
                metric: .heartRateRecovery,
                title: Copy.Analysis.Research.HRRFitness.excellentTitle,
                summary: Copy.Analysis.Research.HRRFitness.excellentSummary(currentHRR: currentText, goodThreshold: Int(goodThreshold)),
                recommendation: Copy.Analysis.Research.HRRFitness.excellentRecommendation(currentHRR: currentText),
                baselineValue: excellentThreshold,
                deviationPercent: ((currentHRR - excellentThreshold) / excellentThreshold) * 100,
                category: .recovery,
            ))
        }

        // Insight 2: HRR trajectory over months
        if daysSpanned >= 90 && sorted.count >= 10 {
            if trajectory == .improving && totalChange >= 3 {
                let changeText = String(format: "%.0f", abs(totalChange))
                insights.append(InsightFactory.observation(
                    metric: .heartRateRecovery,
                    title: Copy.Analysis.Research.HRRFitness.improvingTitle(months: monthsSpanned),
                    summary: Copy.Analysis.Research.HRRFitness.improvingSummary(change: changeText, months: monthsSpanned),
                    recommendation: Copy.Analysis.Research.HRRFitness.improvingRecommendation(change: changeText, months: monthsSpanned),
                    baselineValue: currentHRR - totalChange,
                    deviationPercent: (totalChange / max(currentHRR - totalChange, 1)) * 100,
                    category: .recovery,
                    context: InsightContext(
                        slope: totalChange / Double(monthsSpanned),
                        dataPointCount: sorted.count
                    )
                ))
            } else if trajectory == .declining && totalChange <= -3 {
                let changeText = String(format: "%.0f", abs(totalChange))
                let startText = String(format: "%.0f", currentHRR - totalChange)
                let currentText = String(format: "%.0f", currentHRR)
                insights.append(InsightFactory.make(
                    metric: .heartRateRecovery,
                    title: Copy.Analysis.Research.HRRFitness.decliningTitle,
                    summary: Copy.Analysis.Research.HRRFitness.decliningSummary(change: changeText, months: monthsSpanned),
                    recommendation: Copy.Analysis.Research.HRRFitness.decliningRecommendation(start: startText, current: currentText, months: monthsSpanned),
                    severity: currentHRR < abnormalThreshold ? .warning : .info,
                    trend: .declining,
                    baselineValue: currentHRR - totalChange,
                    deviationPercent: (totalChange / max(currentHRR - totalChange, 1)) * 100,
                    category: .clinicalTrajectory,
                    directive: .increaseActivity,
                ))
            }
        }

        return insights
    }
}

// MARK: - InsightAnalyzer Conformance

extension HRRFitnessAnalyzer: InsightAnalyzer {}
