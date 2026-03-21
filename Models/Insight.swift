import Foundation
import SwiftUI

// MARK: - Insight Category

/// Categories for grouping and filtering insights
enum InsightCategory: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    case anomaly
    case trend
    case correlation
    case recovery
    case workoutEffectiveness
    case sleepPerformance
    case weeklyPattern
    case personalRecord
    case scoreTrajectory
    case baselineDrift
    case multiMetricCluster
    case illnessWarning      // "Early Warning"
    case causalChain         // "Cause & Effect"
    case crossMetricAnomaly  // "Cross-Metric"
    case cognitiveEnergy     // "Cognitive & Energy"
    case brainHealth         // "Brain Health"
    case cyclePhase          // "Cycle Phase"
    case mlPattern           // "ML Pattern"
    case mlState             // "ML State"
    case mlPrediction        // "ML Prediction"
    case simulation          // "What-If"
    case adherenceFeedback   // "Advice Feedback"
    case circadian           // "Circadian"
    case clinicalTrajectory  // "Clinical Trajectory"
    case ecgIntelligence     // "ECG"
    case nutritionCorrelation // "Nutrition"

    var displayName: String {
        switch self {
        case .anomaly: return "Anomaly"
        case .trend: return "Trend"
        case .correlation: return "Correlation"
        case .recovery: return "Recovery"
        case .workoutEffectiveness: return "Workout"
        case .sleepPerformance: return "Sleep"
        case .weeklyPattern: return "Weekly"
        case .personalRecord: return "Record"
        case .scoreTrajectory: return "Trajectory"
        case .baselineDrift: return "Drift"
        case .multiMetricCluster: return "Cluster"
        case .illnessWarning: return "Early Warning"
        case .causalChain: return "Cause & Effect"
        case .crossMetricAnomaly: return "Cross-Metric"
        case .cognitiveEnergy: return "Cognitive & Energy"
        case .brainHealth: return "Brain Health"
        case .cyclePhase: return "Cycle Phase"
        case .mlPattern: return "ML Pattern"
        case .mlState: return "ML State"
        case .mlPrediction: return "ML Prediction"
        case .simulation: return "What-If"
        case .adherenceFeedback: return "Advice Feedback"
        case .circadian: return "Circadian"
        case .clinicalTrajectory: return "Clinical Trajectory"
        case .ecgIntelligence: return "ECG"
        case .nutritionCorrelation: return "Nutrition"
        }
    }

    var systemImageName: String {
        switch self {
        case .anomaly: return "exclamationmark.triangle.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .correlation: return "arrow.triangle.branch"
        case .recovery: return "heart.text.square.fill"
        case .workoutEffectiveness: return "figure.run.circle.fill"
        case .sleepPerformance: return "bed.double.circle.fill"
        case .weeklyPattern: return "calendar.circle.fill"
        case .personalRecord: return "trophy.fill"
        case .scoreTrajectory: return "chart.line.uptrend.xyaxis.circle.fill"
        case .baselineDrift: return "arrow.up.and.down.circle.fill"
        case .multiMetricCluster: return "exclamationmark.3"
        case .illnessWarning: return "shield.lefthalf.filled.badge.checkmark"
        case .causalChain: return "arrow.triangle.turn.up.right.diamond.fill"
        case .crossMetricAnomaly: return "circle.grid.cross.fill"
        case .cognitiveEnergy: return "brain.head.profile"
        case .brainHealth: return "brain"
        case .cyclePhase: return "calendar.badge.clock"
        case .mlPattern: return "waveform.path.ecg.rectangle"
        case .mlState: return "gauge.with.dots.needle.67percent"
        case .mlPrediction: return "sparkles"
        case .simulation: return "wand.and.stars"
        case .adherenceFeedback: return "checkmark.seal.fill"
        case .circadian: return "clock.arrow.2.circlepath"
        case .clinicalTrajectory: return "stethoscope.circle.fill"
        case .ecgIntelligence: return "waveform.path.ecg"
        case .nutritionCorrelation: return "fork.knife.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .anomaly: return .red
        case .trend: return .blue
        case .correlation: return .purple
        case .recovery: return .green
        case .workoutEffectiveness: return .orange
        case .sleepPerformance: return .indigo
        case .weeklyPattern: return .teal
        case .personalRecord: return .yellow
        case .scoreTrajectory: return .mint
        case .baselineDrift: return .cyan
        case .multiMetricCluster: return Color.red.opacity(0.8)
        case .illnessWarning: return .red
        case .causalChain: return .indigo
        case .crossMetricAnomaly: return .purple
        case .cognitiveEnergy: return .orange
        case .brainHealth: return .purple
        case .cyclePhase: return .pink
        case .mlPattern: return .teal
        case .mlState: return .mint
        case .mlPrediction: return .indigo
        case .simulation: return .cyan
        case .adherenceFeedback: return .green
        case .circadian: return .orange
        case .clinicalTrajectory: return .red
        case .ecgIntelligence: return .red
        case .nutritionCorrelation: return .green
        }
    }
}

// MARK: - Insight Context

/// Rich data carrier from analyzers to text generation. enables specific, data-backed recommendations
struct InsightContext {
    var slope: Double?
    var projectedDaysToThreshold: Int?
    var allTimePercentile: Double?
    var seasonalDeviation: Double?
    var yearOverYearChange: Double?
    var correlatedFactors: [CorrelatedFactor]
    var rootCauseMetric: HealthMetric?
    var rootCauseDeviation: Double?
    var comparisonToLastWeek: Double?
    var recentValues: [(date: Date, value: Double)]?
    var confidenceLevel: Double?
    var dataPointCount: Int?
    var categoryDrivers: [(category: HealthCategory, change: Double)]?

    init(
        slope: Double? = nil,
        projectedDaysToThreshold: Int? = nil,
        allTimePercentile: Double? = nil,
        seasonalDeviation: Double? = nil,
        yearOverYearChange: Double? = nil,
        correlatedFactors: [CorrelatedFactor] = [],
        rootCauseMetric: HealthMetric? = nil,
        rootCauseDeviation: Double? = nil,
        comparisonToLastWeek: Double? = nil,
        recentValues: [(date: Date, value: Double)]? = nil,
        confidenceLevel: Double? = nil,
        dataPointCount: Int? = nil,
        categoryDrivers: [(category: HealthCategory, change: Double)]? = nil
    ) {
        self.slope = slope
        self.projectedDaysToThreshold = projectedDaysToThreshold
        self.allTimePercentile = allTimePercentile
        self.seasonalDeviation = seasonalDeviation
        self.yearOverYearChange = yearOverYearChange
        self.correlatedFactors = correlatedFactors
        self.rootCauseMetric = rootCauseMetric
        self.rootCauseDeviation = rootCauseDeviation
        self.comparisonToLastWeek = comparisonToLastWeek
        self.recentValues = recentValues
        self.confidenceLevel = confidenceLevel
        self.dataPointCount = dataPointCount
        self.categoryDrivers = categoryDrivers
    }
}

/// A correlated factor linking a metric to an effect size
struct CorrelatedFactor {
    let metric: HealthMetric
    let correlation: Double
    let effectPercent: Double
    let dayOffset: Int
    let sampleCount: Int

    init(
        metric: HealthMetric,
        correlation: Double,
        effectPercent: Double,
        dayOffset: Int = 0,
        sampleCount: Int = 0
    ) {
        self.metric = metric
        self.correlation = correlation
        self.effectPercent = effectPercent
        self.dayOffset = dayOffset
        self.sampleCount = sampleCount
    }
}

// MARK: - Insight

/// An actionable health insight with supporting evidence
struct Insight: Identifiable {
    let id: UUID
    let metric: HealthMetric
    let title: String
    let summary: String
    let recommendation: String
    let severity: Severity
    let trend: TrendDirection
    let currentValue: Double
    let baselineValue: Double
    let deviationPercent: Double
    let generatedAt: Date
    let category: InsightCategory
    /// Behavioral direction this insight pushes the user toward.
    /// Used by `InsightCoordinator` to detect and resolve conflicting advice.
    var directive: InsightDirective
    let relatedMetrics: [HealthMetric]
    var context: InsightContext?

    /// First sentence of the recommendation. used as a concise action summary
    var actionSummary: String {
        let rec = recommendation
        if let dotIndex = rec.firstIndex(of: ".") {
            return String(rec[rec.startIndex...dotIndex])
        }
        return rec
    }

    /// Priority score for sorting (higher = more important)
    var priorityScore: Double {
        let severityWeight: Double = switch severity {
        case .critical: 3.0
        case .warning: 2.0
        case .info: 1.0
        }
        let trendWeight: Double = switch trend {
        case .declining: 2.0
        case .stable: 1.0
        case .improving: 0.5
        }
        return severityWeight * trendWeight * max(abs(deviationPercent), 1.0)
    }

    init(
        id: UUID = UUID(),
        metric: HealthMetric,
        title: String,
        summary: String,
        recommendation: String,
        severity: Severity,
        trend: TrendDirection,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        generatedAt: Date = Date(),
        category: InsightCategory = .anomaly,
        directive: InsightDirective = .informational,
        relatedMetrics: [HealthMetric] = [],
        context: InsightContext? = nil
    ) {
        self.id = id
        self.metric = metric
        self.title = title
        self.summary = summary
        self.recommendation = recommendation
        self.severity = severity
        self.trend = trend
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.deviationPercent = deviationPercent
        self.generatedAt = generatedAt
        self.category = category
        self.directive = directive
        self.relatedMetrics = relatedMetrics
        self.context = context
    }
}
