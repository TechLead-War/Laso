import Foundation

/// Research: Apple Heart & Movement Study (2026) + multiple validation studies.
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
        guard allSamples.count >= minSamplesRequired else { return [] }

        let recent = hrrSeries.samples(lastDays: 30)
        let currentHRR = recent.isEmpty ? allSamples.last!.value : recent.map(\.value).mean

        // Compute trajectory over available data
        let sorted = allSamples.sorted { $0.date < $1.date }

        var trajectory: TrendDirection = .stable
        var totalChange: Double = 0

        if sorted.count >= 10 {
            let firstQuarter = Array(sorted.prefix(sorted.count / 4)).map(\.value).mean
            let lastQuarter = Array(sorted.suffix(sorted.count / 4)).map(\.value).mean
            totalChange = lastQuarter - firstQuarter
            trajectory = totalChange > 2 ? .improving : totalChange < -2 ? .declining : .stable
        }

        let daysSpanned = Calendar.current.dateComponents(
            [.day], from: sorted.first!.date, to: sorted.last!.date
        ).day ?? 0
        let monthsSpanned = max(1, daysSpanned / 30)

        // Insight 1: Current HRR assessment
        if currentHRR < abnormalThreshold {
            insights.append(InsightFactory.make(
                metric: .heartRateRecovery,
                title: "Heart Rate Recovery Below Clinical Threshold",
                summary: "Your heart rate recovery is \(String(format: "%.0f", currentHRR)) bpm — below the clinical threshold of \(Int(abnormalThreshold)) bpm. This indicates reduced parasympathetic reactivation after exercise.",
                recommendation: "A heart rate recovery <\(Int(abnormalThreshold)) bpm at 1 minute post-exercise is independently associated with increased all-cause mortality in multiple large studies. Your average HRR of \(String(format: "%.0f", currentHRR)) bpm across \(recent.count > 0 ? recent.count : allSamples.count) measurements suggests blunted autonomic recovery.",
                severity: .warning,
                trend: trajectory,
                currentValue: currentHRR,
                baselineValue: abnormalThreshold,
                deviationPercent: ((currentHRR - abnormalThreshold) / abnormalThreshold) * 100,
                category: .clinicalTrajectory,
                directive: .increaseActivity,
                relatedMetrics: [.heartRateRecovery, .heartRateVariability, .vo2Max],
                context: InsightContext(
                    slope: sorted.count >= 10 ? totalChange / Double(monthsSpanned) : nil,
                    confidenceLevel: min(Double(allSamples.count) / 20.0, 1.0),
                    dataPointCount: allSamples.count
                )
            ))
        } else if currentHRR >= excellentThreshold {
            insights.append(InsightFactory.observation(
                metric: .heartRateRecovery,
                title: "Excellent Heart Rate Recovery",
                summary: "Your heart rate drops \(String(format: "%.0f", currentHRR)) bpm after exercise — well above the \(Int(goodThreshold)) bpm threshold for good autonomic function. This indicates strong parasympathetic tone.",
                recommendation: "An HRR of \(String(format: "%.0f", currentHRR)) bpm places you in the excellent range. Research shows this level of post-exercise recovery is associated with lower cardiovascular mortality risk and superior autonomic nervous system health.",
                currentValue: currentHRR,
                baselineValue: excellentThreshold,
                deviationPercent: ((currentHRR - excellentThreshold) / excellentThreshold) * 100,
                category: .recovery,
                relatedMetrics: [.heartRateRecovery, .heartRateVariability, .vo2Max]
            ))
        }

        // Insight 2: HRR trajectory over months
        if daysSpanned >= 90 && sorted.count >= 10 {
            if trajectory == .improving && totalChange >= 3 {
                insights.append(InsightFactory.observation(
                    metric: .heartRateRecovery,
                    title: "Heart Recovery Improving Over \(monthsSpanned) Months",
                    summary: "Your heart rate recovery has improved by \(String(format: "%.0f", abs(totalChange))) bpm over the past \(monthsSpanned) months. Research shows HRR improves dose-dependently with regular exercise training.",
                    recommendation: "A \(String(format: "%.0f", abs(totalChange))) bpm improvement in HRR over \(monthsSpanned) months reflects measurable gains in autonomic fitness. Studies show as few as 6 months of consistent exercise produces this kind of parasympathetic adaptation.",
                    currentValue: currentHRR,
                    baselineValue: currentHRR - totalChange,
                    deviationPercent: (totalChange / max(currentHRR - totalChange, 1)) * 100,
                    category: .recovery,
                    relatedMetrics: [.heartRateRecovery, .exerciseMinutes, .vo2Max],
                    context: InsightContext(
                        slope: totalChange / Double(monthsSpanned),
                        dataPointCount: sorted.count
                    )
                ))
            } else if trajectory == .declining && totalChange <= -3 {
                insights.append(InsightFactory.make(
                    metric: .heartRateRecovery,
                    title: "Heart Recovery Declining",
                    summary: "Your heart rate recovery has worsened by \(String(format: "%.0f", abs(totalChange))) bpm over \(monthsSpanned) months. A declining HRR trajectory suggests reduced autonomic fitness.",
                    recommendation: "HRR dropped from \(String(format: "%.0f", currentHRR - totalChange)) to \(String(format: "%.0f", currentHRR)) bpm over \(monthsSpanned) months. This may reflect detraining, increased stress, or an underlying condition. Regular aerobic exercise is the strongest intervention for improving HRR.",
                    severity: currentHRR < abnormalThreshold ? .warning : .info,
                    trend: .declining,
                    currentValue: currentHRR,
                    baselineValue: currentHRR - totalChange,
                    deviationPercent: (totalChange / max(currentHRR - totalChange, 1)) * 100,
                    category: .clinicalTrajectory,
                    directive: .increaseActivity,
                    relatedMetrics: [.heartRateRecovery, .exerciseMinutes, .vo2Max]
                ))
            }
        }

        return insights
    }
}

// MARK: - InsightAnalyzer Conformance

extension HRRFitnessAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "hrrFitness" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }
}
