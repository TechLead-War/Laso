import Foundation

/// Tracks key health metrics over time and highlights meaningful changes.
/// References AHA/ACC (blood pressure), ADA (glucose), and standard ranges (respiratory rate).
struct ClinicalIntelligence {

    // MARK: - Clinical Stages

    enum BPStage: String, Comparable {
        case normal = "Normal"
        case elevated = "Elevated"
        case hypertensionS1 = "Above Range"
        case hypertensionS2 = "High"
        case crisis = "Very High"

        static func < (lhs: BPStage, rhs: BPStage) -> Bool {
            lhs.order < rhs.order
        }

        var order: Int {
            switch self {
            case .normal: return 0
            case .elevated: return 1
            case .hypertensionS1: return 2
            case .hypertensionS2: return 3
            case .crisis: return 4
            }
        }
    }

    enum GlucoseStage: String, Comparable {
        case normal = "Normal"
        case prediabetic = "Above Range"
        case diabetic = "High"

        static func < (lhs: GlucoseStage, rhs: GlucoseStage) -> Bool {
            lhs.order < rhs.order
        }

        var order: Int {
            switch self {
            case .normal: return 0
            case .prediabetic: return 1
            case .diabetic: return 2
            }
        }
    }

    enum RespiratoryStage: String {
        case bradypnea = "Below Range"
        case normal = "Normal"
        case tachypnea = "Above Range"
        case severe = "Well Above Range"
    }

    // MARK: - Classification thresholds (AHA/ACC 2017, ADA, standard ranges)

    /// Systolic mmHg above which BP is classified as hypertensive crisis.
    private static let bpCrisisSystolic: Double = 180
    /// Diastolic mmHg above which BP is classified as hypertensive crisis.
    private static let bpCrisisDiastolic: Double = 120
    /// Systolic mmHg at/above which BP enters Stage 2 hypertension.
    private static let bpStage2Systolic: Double = 140
    /// Diastolic mmHg at/above which BP enters Stage 2 hypertension.
    private static let bpStage2Diastolic: Double = 90
    /// Systolic mmHg at/above which BP enters Stage 1 hypertension.
    private static let bpStage1Systolic: Double = 130
    /// Diastolic mmHg at/above which BP enters Stage 1 hypertension.
    private static let bpStage1Diastolic: Double = 80
    /// Systolic mmHg at/above which BP is "elevated" (when diastolic is still normal).
    private static let bpElevatedSystolic: Double = 120

    /// Fasting glucose mg/dL at/above which the value is in the diabetic range (ADA).
    private static let glucoseDiabetic: Double = 126
    /// Fasting glucose mg/dL at/above which the value is in the prediabetic range (ADA).
    private static let glucosePrediabetic: Double = 100

    /// Respiratory rate (breaths/min) above which is severe tachypnea.
    private static let respiratoryRateSevere: Double = 25
    /// Respiratory rate (breaths/min) above which is tachypnea.
    private static let respiratoryRateTachypnea: Double = 20
    /// Respiratory rate (breaths/min) below which is bradypnea.
    private static let respiratoryRateBradypnea: Double = 12

    // MARK: - Classification (AHA/ACC 2017)

    /// Classify blood pressure stage from systolic and diastolic readings
    static func classifyBP(systolic: Double, diastolic: Double) -> BPStage {
        if systolic > bpCrisisSystolic || diastolic > bpCrisisDiastolic { return .crisis }
        if systolic >= bpStage2Systolic || diastolic >= bpStage2Diastolic { return .hypertensionS2 }
        if systolic >= bpStage1Systolic || diastolic >= bpStage1Diastolic { return .hypertensionS1 }
        if systolic >= bpElevatedSystolic && diastolic < bpStage1Diastolic { return .elevated }
        return .normal
    }

    /// Classify fasting glucose stage (ADA)
    static func classifyGlucose(_ value: Double) -> GlucoseStage {
        if value >= glucoseDiabetic { return .diabetic }
        if value >= glucosePrediabetic { return .prediabetic }
        return .normal
    }

    /// Classify respiratory rate
    static func classifyRespiratoryRate(_ value: Double) -> RespiratoryStage {
        if value > respiratoryRateSevere { return .severe }
        if value > respiratoryRateTachypnea { return .tachypnea }
        if value < respiratoryRateBradypnea { return .bradypnea }
        return .normal
    }

    // MARK: - Clinical Thresholds

    /// Next threshold values for trajectory projection
    private static let systolicThresholds: [(threshold: Double, label: String)] = [
        (120, "Elevated"), (130, "Above Range"), (140, "High"), (180, "Very High")
    ]

    private static let glucoseThresholds: [(threshold: Double, label: String)] = [
        (100, "Above Range"), (126, "High")
    ]

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
    /// Maximum forward projection in days when estimating time-to-threshold.
    private static let maxProjectionDays: Int = 365
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
        let diaSeries = timeSeries[.bloodPressureDiastolic]
        let diaValues = diaSeries?.sortedSamples ?? []

        // Current stage
        guard let latestSys = sysValues.last?.value else { return [] }
        let latestDia = diaValues.last?.value ?? bpStage1Diastolic
        let currentStage = classifyBP(systolic: latestSys, diastolic: latestDia)

        // 90-day linear regression for systolic
        let recent90 = Array(sysValues.suffix(regressionWindowDays))
        guard recent90.count >= minSamplesForInsight else { return [] }

        let sysSlope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = sysSlope * daysPerMonth

        // Project days to next stage
        let daysToNextStage = projectDaysToNextThreshold(
            currentValue: latestSys,
            slopePerDay: sysSlope,
            thresholds: systolicThresholds
        )

        // Generate insight if trending upward significantly
        if slopePerMonth > bpUpwardSlopeThreshold {
            let severity: Severity = slopePerMonth > bpWarningSlopeThreshold ? .warning : .info
            let nextStageInfo = daysToNextStage.map { Copy.Analysis.Clinical.projectedToReach(label: $0.label, days: $0.days) } ?? ""

            insights.append(Insight(
                metric: .bloodPressureSystolic,
                title: Copy.Analysis.Clinical.bloodPressureTrendingUp,
                summary: Copy.Analysis.ClinicalSentences.systolicTrendSummary(
                    slopePerMonth: String(format: "%.1f", slopePerMonth),
                    recentDays: recent90.count,
                    currentStage: currentStage.rawValue,
                    nextStageInfo: nextStageInfo),
                recommendation: "\(Copy.Analysis.Clinical.bpRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                severity: severity,
                trend: .declining,
                baselineValue: baselines[.bloodPressureSystolic]?.mean ?? latestSys,
                deviationPercent: slopePerMonth,
                category: .clinicalTrajectory,
                context: InsightContext(
                    slope: slopePerMonth,
                    projectedDaysToThreshold: daysToNextStage?.days,
                    confidenceLevel: min(1.0, Double(recent90.count) / Double(regressionWindowDays))
                )
            ))
        }

        // Pulse pressure trend (systolic - diastolic)
        if sysValues.count >= minSamplesForPulsePressure && diaValues.count >= minSamplesForPulsePressure {
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

        let currentStage = classifyGlucose(latest)
        let recent90 = Array(samples.suffix(regressionWindowDays))
        guard recent90.count >= minSamplesForInsight else { return nil }

        let slope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = slope * daysPerMonth

        guard slopePerMonth > glucoseUpwardSlopeThreshold else { return nil }

        let daysToNext = projectDaysToNextThreshold(
            currentValue: latest,
            slopePerDay: slope,
            thresholds: glucoseThresholds
        )

        let severity: Severity = currentStage >= .prediabetic || slopePerMonth > glucoseWarningSlopeThreshold ? .warning : .info
        let nextInfo = daysToNext.map { Copy.Analysis.Clinical.projectedToReachRange(label: $0.label, days: $0.days) } ?? ""

        return Insight(
            metric: .bloodGlucose,
            title: Copy.Analysis.Clinical.bloodGlucoseTrendingUp,
            summary: Copy.Analysis.ClinicalSentences.glucoseTrendSummary(
                slopePerMonth: String(format: "%.1f", slopePerMonth),
                latest: String(format: "%.0f", latest),
                currentStage: currentStage.rawValue,
                nextInfo: nextInfo),
            recommendation: "\(Copy.Analysis.Clinical.glucoseRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: severity,
            trend: .declining,
            baselineValue: baselines[.bloodGlucose]?.mean ?? latest,
            deviationPercent: slopePerMonth,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                projectedDaysToThreshold: daysToNext?.days,
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

    /// Project how many days until the next clinical threshold is reached
    private static func projectDaysToNextThreshold(
        currentValue: Double,
        slopePerDay: Double,
        thresholds: [(threshold: Double, label: String)]
    ) -> (days: Int, label: String)? {
        guard slopePerDay > 0 else { return nil }

        for threshold in thresholds {
            if currentValue < threshold.threshold {
                let daysToThreshold = Int((threshold.threshold - currentValue) / slopePerDay)
                if daysToThreshold > 0 && daysToThreshold < maxProjectionDays {
                    return (days: daysToThreshold, label: threshold.label)
                }
            }
        }
        return nil
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
