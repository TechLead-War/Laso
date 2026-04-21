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

    // MARK: - Classification (AHA/ACC 2017)

    /// Classify blood pressure stage from systolic and diastolic readings
    static func classifyBP(systolic: Double, diastolic: Double) -> BPStage {
        if systolic > 180 || diastolic > 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90 { return .hypertensionS2 }
        if systolic >= 130 || diastolic >= 80 { return .hypertensionS1 }
        if systolic >= 120 && diastolic < 80 { return .elevated }
        return .normal
    }

    /// Classify fasting glucose stage (ADA)
    static func classifyGlucose(_ value: Double) -> GlucoseStage {
        if value >= 126 { return .diabetic }
        if value >= 100 { return .prediabetic }
        return .normal
    }

    /// Classify respiratory rate
    static func classifyRespiratoryRate(_ value: Double) -> RespiratoryStage {
        if value > 25 { return .severe }
        if value > 20 { return .tachypnea }
        if value < 12 { return .bradypnea }
        return .normal
    }

    // MARK: - Clinical Thresholds

    /// Next threshold values for trajectory projection
    private static let systolicThresholds: [(threshold: Double, label: String)] = [
        (120, "Elevated"), (130, "Above Range"), (140, "High"), (180, "Very High")
    ]

    private static let diastolicThresholds: [(threshold: Double, label: String)] = [
        (80, "Above Range"), (90, "High"), (120, "Very High")
    ]

    private static let glucoseThresholds: [(threshold: Double, label: String)] = [
        (100, "Above Range"), (126, "High")
    ]

    // MARK: - Insight Generation

    /// Generate clinical insights from time series data.
    static func generateInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> [Insight] {
        var insights: [Insight] = []

        // Blood pressure compound analysis
        insights.append(contentsOf: analyzeBP(timeSeries: timeSeries, baselines: baselines, trends: trends))

        // Glucose trajectory
        if let glucoseInsight = analyzeGlucose(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(glucoseInsight)
        }

        // Respiratory rate
        if let rrInsight = analyzeRespiratoryRate(timeSeries: timeSeries, baselines: baselines, trends: trends) {
            insights.append(rrInsight)
        }

        return insights
    }

    // MARK: - Blood Pressure Analysis

    private static func analyzeBP(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> [Insight] {
        var insights: [Insight] = []

        guard let sysSeries = timeSeries[.bloodPressureSystolic],
              sysSeries.values.count >= 14 else { return [] }

        let sysValues = sysSeries.sortedSamples
        let diaSeries = timeSeries[.bloodPressureDiastolic]
        let diaValues = diaSeries?.sortedSamples ?? []

        // Current stage
        guard let latestSys = sysValues.last?.value else { return [] }
        let latestDia = diaValues.last?.value ?? 80
        let currentStage = classifyBP(systolic: latestSys, diastolic: latestDia)

        // 90-day linear regression for systolic
        let recent90 = Array(sysValues.suffix(90))
        guard recent90.count >= 14 else { return [] }

        let sysSlope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = sysSlope * 30

        // Project days to next stage
        let daysToNextStage = projectDaysToNextThreshold(
            currentValue: latestSys,
            slopePerDay: sysSlope,
            thresholds: systolicThresholds
        )

        // Generate insight if trending upward significantly
        if slopePerMonth > 0.5 {
            let severity: Severity = slopePerMonth > 2.0 ? .warning : .info
            let nextStageInfo = daysToNextStage.map { Copy.Analysis.Clinical.projectedToReach(label: $0.label, days: $0.days) } ?? ""

            insights.append(Insight(
                metric: .bloodPressureSystolic,
                title: Copy.Analysis.Clinical.bloodPressureTrendingUp,
                summary: "Your systolic trend shows a rise of \(String(format: "%.1f", slopePerMonth)) mmHg/month over the past \(recent90.count) days. Currently in the \(currentStage.rawValue) range. This is still modifiable with lifestyle changes. \(nextStageInfo)",
                recommendation: "\(Copy.Analysis.Clinical.bpRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                severity: severity,
                trend: .declining,
                currentValue: latestSys,
                baselineValue: baselines[.bloodPressureSystolic]?.mean ?? latestSys,
                deviationPercent: slopePerMonth,
                category: .clinicalTrajectory,
                relatedMetrics: [.bloodPressureDiastolic],
                context: InsightContext(
                    slope: slopePerMonth,
                    projectedDaysToThreshold: daysToNextStage?.days,
                    confidenceLevel: min(1.0, Double(recent90.count) / 90.0)
                )
            ))
        }

        // Pulse pressure trend (systolic - diastolic)
        if sysValues.count >= 30 && diaValues.count >= 30 {
            let pulsePressure = latestSys - latestDia
            if pulsePressure > 60 {
                insights.append(Insight(
                    metric: .bloodPressureSystolic,
                    title: Copy.Analysis.Clinical.elevatedPulsePressure,
                    summary: Copy.Analysis.Clinical.pulsePressureSummary(pulsePressure: Int(pulsePressure)),
                    recommendation: "\(Copy.Analysis.Clinical.pulsePressureRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
                    severity: .warning,
                    trend: .declining,
                    currentValue: pulsePressure,
                    baselineValue: 40,
                    deviationPercent: ((pulsePressure - 40) / 40) * 100,
                    category: .clinicalTrajectory,
                    relatedMetrics: [.bloodPressureSystolic, .bloodPressureDiastolic]
                ))
            }
        }

        return insights
    }

    // MARK: - Glucose Analysis

    private static func analyzeGlucose(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        guard let glucoseSeries = timeSeries[.bloodGlucose],
              glucoseSeries.values.count >= 14 else { return nil }

        let samples = glucoseSeries.sortedSamples
        guard let latest = samples.last?.value else { return nil }

        let currentStage = classifyGlucose(latest)
        let recent90 = Array(samples.suffix(90))
        guard recent90.count >= 14 else { return nil }

        let slope = linearRegressionSlope(samples: recent90)
        let slopePerMonth = slope * 30

        guard slopePerMonth > 0.3 else { return nil }

        let daysToNext = projectDaysToNextThreshold(
            currentValue: latest,
            slopePerDay: slope,
            thresholds: glucoseThresholds
        )

        let severity: Severity = currentStage >= .prediabetic || slopePerMonth > 1.5 ? .warning : .info
        let nextInfo = daysToNext.map { Copy.Analysis.Clinical.projectedToReachRange(label: $0.label, days: $0.days) } ?? ""

        return Insight(
            metric: .bloodGlucose,
            title: Copy.Analysis.Clinical.bloodGlucoseTrendingUp,
            summary: "Your fasting glucose has been rising \(String(format: "%.1f", slopePerMonth)) mg/dL per month. Current: \(String(format: "%.0f", latest)) mg/dL (\(currentStage.rawValue)). \(nextInfo)",
            recommendation: "\(Copy.Analysis.Clinical.glucoseRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: severity,
            trend: .declining,
            currentValue: latest,
            baselineValue: baselines[.bloodGlucose]?.mean ?? latest,
            deviationPercent: slopePerMonth,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                projectedDaysToThreshold: daysToNext?.days,
                confidenceLevel: min(1.0, Double(recent90.count) / 90.0)
            )
        )
    }

    // MARK: - Respiratory Rate Analysis

    private static func analyzeRespiratoryRate(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> Insight? {
        guard let rrSeries = timeSeries[.respiratoryRate],
              rrSeries.values.count >= 14 else { return nil }

        let samples = rrSeries.sortedSamples
        guard let latest = samples.last?.value else { return nil }
        let stage = classifyRespiratoryRate(latest)

        guard stage != .normal else { return nil }

        let recent = Array(samples.suffix(30))
        let slope = recent.count >= 7 ? linearRegressionSlope(samples: recent) : 0
        let slopePerMonth = slope * 30

        return Insight(
            metric: .respiratoryRate,
            title: Copy.Analysis.Clinical.abnormalRespiratoryRate,
            summary: Copy.Analysis.Clinical.respiratorySummary(rate: String(format: "%.1f", latest), stage: stage.rawValue),
            recommendation: "\(Copy.Analysis.Clinical.respiratoryRecommendation) \(Copy.Analysis.Clinical.medicalDisclaimer)",
            severity: stage == .severe ? .critical : .warning,
            trend: slopePerMonth > 0 ? .declining : .stable,
            currentValue: latest,
            baselineValue: baselines[.respiratoryRate]?.mean ?? 16,
            deviationPercent: ((latest - 16) / 16) * 100,
            category: .clinicalTrajectory,
            context: InsightContext(
                slope: slopePerMonth,
                confidenceLevel: min(1.0, Double(recent.count) / 30.0)
            )
        )
    }

    // MARK: - Helpers

    /// Simple linear regression slope (value per day)
    private static func linearRegressionSlope(samples: [MetricSample]) -> Double {
        guard samples.count >= 2 else { return 0 }

        let n = Double(samples.count)
        let firstDate = samples.first!.date
        let xs = samples.map { $0.date.timeIntervalSince(firstDate) / 86400.0 }
        let ys = samples.map(\.value)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
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
                if daysToThreshold > 0 && daysToThreshold < 365 {
                    return (days: daysToThreshold, label: threshold.label)
                }
            }
        }
        return nil
    }

    private static let medicalDisclaimer = Copy.Analysis.Clinical.medicalDisclaimer
}

// MARK: - InsightAnalyzer Conformance

extension ClinicalIntelligence: InsightAnalyzer {
    static var analyzerID: String { "clinicalIntelligence" }
    static var insightCategory: InsightCategory { .clinicalTrajectory }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(
            timeSeries: context.timeSeries,
            baselines: context.baselines,
            trends: context.trends
        )
    }
}
