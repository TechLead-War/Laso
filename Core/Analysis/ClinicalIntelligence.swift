import Foundation

/// Tracks key health metrics over time and highlights meaningful changes.
/// Blood pressure and glucose are reported as a trend against the user's own baseline, not a clinical stage.
struct ClinicalIntelligence {

    // MARK: - Clinical Stages

    enum RespiratoryStage: String {
        case bradypnea = "Below Range"
        case normal = "Normal"
        case tachypnea = "Above Range"
        case severe = "Well Above Range"
    }

    // MARK: - Classification thresholds (standard ranges)

    /// Respiratory rate (breaths/min) above which is severe tachypnea.
    private static let respiratoryRateSevere: Double = 25
    /// Respiratory rate (breaths/min) above which is tachypnea.
    private static let respiratoryRateTachypnea: Double = 20
    /// Respiratory rate (breaths/min) below which is bradypnea.
    private static let respiratoryRateBradypnea: Double = 12

    // MARK: - Classification

    /// Classify respiratory rate
    static func classifyRespiratoryRate(_ value: Double) -> RespiratoryStage {
        if value > respiratoryRateSevere { return .severe }
        if value > respiratoryRateTachypnea { return .tachypnea }
        if value < respiratoryRateBradypnea { return .bradypnea }
        return .normal
    }

    // MARK: - Analysis thresholds

    /// Minimum sample count required before a clinical insight is generated.
    private static let minSamplesForInsight: Int = 14
    /// Maximum recent days included in the trend regression window.
    private static let regressionWindowDays: Int = 90
    /// Systolic mmHg/month rise above which a BP insight is surfaced.
    private static let bpUpwardSlopeThreshold: Double = 0.5
    /// Systolic mmHg/month rise above which the BP insight is escalated to warning.
    private static let bpWarningSlopeThreshold: Double = 2.0
    /// Pulse pressure (systolic - diastolic) mmHg above which it is flagged as elevated.
    private static let elevatedPulsePressureThreshold: Double = 60
    /// Reference healthy pulse pressure used as the baseline in the deviation calculation.
    private static let pulsePressureBaseline: Double = 40
    /// Minimum sample count for the pulse-pressure cross-check on each BP series.
    private static let minSamplesForPulsePressure: Int = 30
    /// Glucose mg/dL/month rise above which a glucose insight is surfaced.
    private static let glucoseUpwardSlopeThreshold: Double = 0.3
    /// Glucose mg/dL/month rise above which the glucose insight is escalated to warning.
    private static let glucoseWarningSlopeThreshold: Double = 1.5
    /// Respiratory rate analysis trailing window in days.
    private static let respiratoryWindowDays: Int = 30
    /// Reference healthy respiratory rate (breaths/min) used as the baseline in deviation calculations.
    private static let respiratoryRateBaseline: Double = 16
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

        // 90-day linear regression for systolic
        let recent90 = Array(sysValues.suffix(regressionWindowDays))
        guard recent90.count >= minSamplesForInsight else { return [] }

        let sysSlope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = sysSlope * daysPerMonth

        // Generate insight if trending upward significantly
        if slopePerMonth > bpUpwardSlopeThreshold {
            let severity: Severity = slopePerMonth > bpWarningSlopeThreshold ? .warning : .info
            let baselineMean = baselines[.bloodPressureSystolic]?.mean
            let baselineComparison = baselineMean.map {
                Copy.Analysis.Clinical.systolicVsBaseline(baseline: String(format: "%.0f", $0))
            } ?? ""

            insights.append(Insight(
                metric: .bloodPressureSystolic,
                title: Copy.Analysis.Clinical.bloodPressureTrendingUp,
                summary: Copy.Analysis.ClinicalSentences.systolicTrendSummary(
                    slopePerMonth: String(format: "%.1f", slopePerMonth),
                    recentDays: recent90.count,
                    latest: String(format: "%.0f", latestSys),
                    baselineComparison: baselineComparison),
                recommendation: "\(Copy.Analysis.Clinical.bpRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                severity: severity,
                trend: .declining,
                baselineValue: baselineMean ?? latestSys,
                deviationPercent: slopePerMonth,
                category: .clinicalTrajectory,
                context: InsightContext(
                    slope: slopePerMonth,
                    confidenceLevel: min(1.0, Double(recent90.count) / Double(regressionWindowDays))
                )
            ))
        }

        // Pulse pressure trend (systolic - diastolic)
        if sysValues.count >= minSamplesForPulsePressure,
           diaValues.count >= minSamplesForPulsePressure,
           let latestDia = diaValues.last?.value {
            let pulsePressure = latestSys - latestDia
            if pulsePressure > elevatedPulsePressureThreshold {
                insights.append(Insight(
                    metric: .bloodPressureSystolic,
                    title: Copy.Analysis.Clinical.elevatedPulsePressure,
                    summary: Copy.Analysis.Clinical.pulsePressureSummary(pulsePressure: Int(pulsePressure)),
                    recommendation: "\(Copy.Analysis.Clinical.pulsePressureRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                    severity: .warning,
                    trend: .declining,
                    baselineValue: pulsePressureBaseline,
                    deviationPercent: ((pulsePressure - pulsePressureBaseline) / pulsePressureBaseline) * 100,
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

        let recent90 = Array(samples.suffix(regressionWindowDays))
        guard recent90.count >= minSamplesForInsight else { return nil }

        let slope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = slope * daysPerMonth

        guard slopePerMonth > glucoseUpwardSlopeThreshold else { return nil }

        let severity: Severity = slopePerMonth > glucoseWarningSlopeThreshold ? .warning : .info
        let baselineMean = baselines[.bloodGlucose]?.mean
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
            baselineValue: baselineMean ?? latest,
            deviationPercent: slopePerMonth,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                confidenceLevel: min(1.0, Double(recent90.count) / Double(regressionWindowDays))
            )
        )
    }

    // MARK: - Respiratory Rate Analysis

    /// Minimum sample count for the respiratory regression trend.
    private static let minSamplesForRespiratoryTrend: Int = 7

    private static func analyzeRespiratoryRate(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> Insight? {
        guard let rrSeries = timeSeries[.respiratoryRate],
              rrSeries.samples.count >= minSamplesForInsight else { return nil }

        let samples = rrSeries.sortedSamples
        guard let latest = samples.last?.value else { return nil }
        let stage = classifyRespiratoryRate(latest)

        guard stage != .normal else { return nil }

        let recent = Array(samples.suffix(respiratoryWindowDays))
        let slope = recent.count >= minSamplesForRespiratoryTrend ? linearRegressionSlope(samples: recent) : 0
        let slopePerMonth = slope * daysPerMonth

        return Insight(
            metric: .respiratoryRate,
            title: Copy.Analysis.Clinical.abnormalRespiratoryRate,
            summary: Copy.Analysis.Clinical.respiratorySummary(rate: String(format: "%.1f", latest), stage: stage.rawValue),
            recommendation: "\(Copy.Analysis.Clinical.respiratoryRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: stage == .severe ? .critical : .warning,
            trend: slopePerMonth > 0 ? .declining : .stable,
            baselineValue: baselines[.respiratoryRate]?.mean ?? respiratoryRateBaseline,
            deviationPercent: ((latest - respiratoryRateBaseline) / respiratoryRateBaseline) * 100,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                confidenceLevel: min(1.0, Double(recent.count) / Double(respiratoryWindowDays))
            )
        )
    }

    // MARK: - Helpers

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
