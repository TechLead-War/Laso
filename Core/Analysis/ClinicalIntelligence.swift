import Foundation

/// Tracks key health metrics over time and highlights meaningful changes.
/// Blood pressure, glucose and breathing rate are reported as a trend against
/// the user's own baseline, never as a clinical stage.
struct ClinicalIntelligence {

    // MARK: - Analysis thresholds

    /// Minimum sample count required before a clinical insight is generated.
    private static let minSamplesForInsight: Int = 14
    /// Most recent readings fed into the trend regression. Caps samples, not days.
    private static let regressionSampleCap: Int = 90
    /// Systolic mmHg/month rise above which a BP insight is surfaced.
    private static let bpUpwardSlopeThreshold: Double = 0.5
    /// Systolic mmHg/month rise above which the BP insight is escalated to warning.
    private static let bpWarningSlopeThreshold: Double = 2.0
    /// Pulse pressure (systolic - diastolic) mmHg above which it is flagged as elevated.
    private static let elevatedPulsePressureThreshold: Double = 60
    /// Minimum sample count for the pulse-pressure cross-check on each BP series.
    private static let minSamplesForPulsePressure: Int = 30
    /// Glucose mg/dL/month rise above which a glucose insight is surfaced.
    private static let glucoseUpwardSlopeThreshold: Double = 0.3
    /// Glucose mg/dL/month rise above which the glucose insight is escalated to warning.
    private static let glucoseWarningSlopeThreshold: Double = 1.5
    /// Most recent breathing-rate readings averaged for the baseline comparison. Caps samples, not days.
    private static let respiratorySampleCap: Int = 30
    /// Percent departure from the user's usual breathing rate worth surfacing.
    private static let respiratoryDeviationThreshold: Double = 10
    /// Percent departure from the user's usual breathing rate that escalates to warning.
    private static let respiratoryWarningDeviationThreshold: Double = 20
    /// Days per month used to convert per-day slopes to per-month slopes.
    private static let daysPerMonth: Double = 30
    /// Seconds in one day used to convert TimeInterval into day-based regression x-values.
    private static let secondsPerDay: Double = 86_400

    // MARK: - Insight Generation

    /// Generate clinical insights from time series data.
    static func generateInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Insight] {
        var insights: [Insight] = []

        // Blood pressure compound analysis
        insights.append(contentsOf: analyzeBP(timeSeries: timeSeries, baselines: baselines))

        // Glucose trajectory
        if let glucoseInsight = analyzeGlucose(timeSeries: timeSeries, baselines: baselines) {
            insights.append(glucoseInsight)
        }

        // Respiratory rate
        if let rrInsight = analyzeRespiratoryRate(timeSeries: timeSeries, baselines: baselines) {
            insights.append(rrInsight)
        }

        return insights
    }

    // MARK: - Blood Pressure Analysis

    private static func analyzeBP(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Insight] {
        var insights: [Insight] = []

        guard let sysSeries = timeSeries[.bloodPressureSystolic],
              sysSeries.samples.count >= minSamplesForInsight else { return [] }

        let sysValues = sysSeries.sortedSamples
        let diaValues = timeSeries[.bloodPressureDiastolic]?.sortedSamples ?? []

        guard let latestSys = sysValues.last?.value else { return [] }

        let recentSys = Array(sysValues.suffix(regressionSampleCap))
        guard recentSys.count >= minSamplesForInsight else { return [] }

        let sysSlope = linearRegressionSlope(samples: recentSys)
        let slopePerMonth = sysSlope * daysPerMonth

        // Generate insight if trending upward significantly
        if slopePerMonth > bpUpwardSlopeThreshold {
            let severity: Severity = slopePerMonth > bpWarningSlopeThreshold ? .warning : .info
            let baselineMean = usableBaseline(baselines[.bloodPressureSystolic])
            let baselineComparison = baselineMean.map {
                Copy.Analysis.Clinical.systolicVsBaseline(baseline: String(format: "%.0f", $0))
            } ?? ""

            insights.append(Insight(
                metric: .bloodPressureSystolic,
                title: Copy.Analysis.Clinical.bloodPressureTrendingUp,
                summary: Copy.Analysis.ClinicalSentences.systolicTrendSummary(
                    slopePerMonth: String(format: "%.1f", slopePerMonth),
                    recentDays: daySpan(of: recentSys),
                    latest: String(format: "%.0f", latestSys),
                    baselineComparison: baselineComparison),
                recommendation: "\(Copy.Analysis.Clinical.bpRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                severity: severity,
                trend: .declining,
                // Without a baseline there is no deviation to report, so both fields stay
                // empty rather than passing the slope off as a percentage off baseline.
                baselineValue: baselineMean ?? 0,
                deviationPercent: baselineMean.map { ((latestSys - $0) / $0) * 100 } ?? 0,
                category: .clinicalTrajectory,
                context: InsightContext(
                    slope: slopePerMonth,
                    confidenceLevel: min(1.0, Double(recentSys.count) / Double(regressionSampleCap))
                )
            ))
        }

        // Pulse pressure against this person's own usual gap
        if sysValues.count >= minSamplesForPulsePressure,
           diaValues.count >= minSamplesForPulsePressure,
           let latestDia = diaValues.last?.value,
           let sysBaseline = usableBaseline(baselines[.bloodPressureSystolic]),
           let diaBaseline = usableBaseline(baselines[.bloodPressureDiastolic]) {
            let usualGap = sysBaseline - diaBaseline
            let pulsePressure = latestSys - latestDia
            // Both bars have to clear: wide in absolute terms, and wider than this
            // person normally runs, so the "higher than usual" title stays true.
            if usualGap > 0, pulsePressure > max(usualGap, elevatedPulsePressureThreshold) {
                insights.append(Insight(
                    metric: .bloodPressureSystolic,
                    title: Copy.Analysis.Clinical.elevatedPulsePressure,
                    summary: Copy.Analysis.Clinical.pulsePressureSummary(
                        pulsePressure: Int(pulsePressure),
                        usualGap: Int(usualGap.rounded())),
                    recommendation: "\(Copy.Analysis.Clinical.pulsePressureRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                    severity: .warning,
                    trend: .declining,
                    baselineValue: usualGap,
                    deviationPercent: ((pulsePressure - usualGap) / usualGap) * 100,
                    category: .clinicalTrajectory,
                ))
            }
        }

        return insights
    }

    // MARK: - Glucose Analysis

    private static func analyzeGlucose(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Insight? {
        guard let glucoseSeries = timeSeries[.bloodGlucose],
              glucoseSeries.samples.count >= minSamplesForInsight else { return nil }

        let samples = glucoseSeries.sortedSamples
        guard let latest = samples.last?.value else { return nil }

        let recent = Array(samples.suffix(regressionSampleCap))
        guard recent.count >= minSamplesForInsight else { return nil }

        let slope = linearRegressionSlope(samples: recent)
        let slopePerMonth = slope * daysPerMonth

        guard slopePerMonth > glucoseUpwardSlopeThreshold else { return nil }

        let severity: Severity = slopePerMonth > glucoseWarningSlopeThreshold ? .warning : .info
        let baselineMean = usableBaseline(baselines[.bloodGlucose])
        let baselineComparison = baselineMean.map {
            Copy.Analysis.Clinical.glucoseVsBaseline(baseline: String(format: "%.0f", $0))
        } ?? ""

        return Insight(
            metric: .bloodGlucose,
            title: Copy.Analysis.Clinical.bloodGlucoseTrendingUp,
            summary: Copy.Analysis.ClinicalSentences.glucoseTrendSummary(
                slopePerMonth: String(format: "%.1f", slopePerMonth),
                latest: String(format: "%.0f", latest),
                baselineComparison: baselineComparison),
            recommendation: "\(Copy.Analysis.Clinical.glucoseRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: severity,
            trend: .declining,
            // Same rule as blood pressure: no baseline, no percentage.
            baselineValue: baselineMean ?? 0,
            deviationPercent: baselineMean.map { ((latest - $0) / $0) * 100 } ?? 0,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                confidenceLevel: min(1.0, Double(recent.count) / Double(regressionSampleCap))
            )
        )
    }

    // MARK: - Respiratory Rate Analysis

    /// Minimum sample count for the respiratory baseline comparison.
    private static let minSamplesForRespiratoryTrend: Int = 7

    private static func analyzeRespiratoryRate(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Insight? {
        guard let rrSeries = timeSeries[.respiratoryRate],
              rrSeries.samples.count >= minSamplesForInsight,
              let baselineMean = usableBaseline(baselines[.respiratoryRate]) else { return nil }

        let recent = Array(rrSeries.sortedSamples.suffix(respiratorySampleCap))
        guard recent.count >= minSamplesForRespiratoryTrend else { return nil }

        // One unusual night is noise, so the comparison uses the window mean.
        let recentMean = recent.map(\.value).reduce(0, +) / Double(recent.count)
        let deviationPercent = ((recentMean - baselineMean) / baselineMean) * 100
        guard abs(deviationPercent) >= respiratoryDeviationThreshold else { return nil }

        let rate = String(format: "%.1f", recentMean)
        let usual = String(format: "%.1f", baselineMean)
        let days = daySpan(of: recent)
        let summary = deviationPercent > 0
            ? Copy.Analysis.Clinical.respiratoryAboveUsualSummary(rate: rate, days: days, usual: usual)
            : Copy.Analysis.Clinical.respiratoryBelowUsualSummary(rate: rate, days: days, usual: usual)

        return Insight(
            metric: .respiratoryRate,
            title: Copy.Analysis.Clinical.abnormalRespiratoryRate,
            summary: summary,
            recommendation: "\(Copy.Analysis.Clinical.respiratoryRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: abs(deviationPercent) >= respiratoryWarningDeviationThreshold ? .warning : .info,
            // A drift either side of this person's usual is a move away from it, never an improvement.
            trend: .declining,
            baselineValue: baselineMean,
            deviationPercent: deviationPercent,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: linearRegressionSlope(samples: recent) * daysPerMonth,
                confidenceLevel: min(1.0, Double(recent.count) / Double(respiratorySampleCap))
            )
        )
    }

    // MARK: - Helpers

    /// A baseline mean of zero cannot anchor a percentage, so it counts as no baseline.
    private static func usableBaseline(_ baseline: UserBaseline?) -> Double? {
        baseline.flatMap { $0.mean > 0 ? $0.mean : nil }
    }

    /// Calendar days a sample window actually covers. The windows are capped by
    /// sample count, so the span has to come from the timestamps.
    private static func daySpan(of samples: [MetricSample]) -> Int {
        guard let first = samples.first?.date, let last = samples.last?.date else { return 0 }
        return max(1, (Date.cal.dateComponents([.day], from: first, to: last).day ?? 0) + 1)
    }

    /// Simple linear regression slope (value per day)
    private static func linearRegressionSlope(samples: [MetricSample]) -> Double {
        guard samples.count >= 2, let firstDate = samples.first?.date else { return 0 }
        let xs = samples.map { $0.date.timeIntervalSince(firstDate) / secondsPerDay }
        let ys = samples.map(\.value)
        return Array<Double>.linearRegression(x: xs, y: ys).slope
    }

}

// MARK: - InsightAnalyzer Conformance

extension ClinicalIntelligence: InsightAnalyzer {
    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(
            timeSeries: context.timeSeries,
            baselines: context.baselines
        )
    }
}
