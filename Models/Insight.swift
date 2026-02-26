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
        }
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
    let relatedMetrics: [HealthMetric]

    /// First sentence of the recommendation — used as a concise action summary
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
        relatedMetrics: [HealthMetric] = []
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
        self.relatedMetrics = relatedMetrics
    }
}
