import Foundation

/// Centralized factory for constructing `Insight` instances.
///
/// Provides consistent construction with automatic directive tagging,
/// replacing scattered `Insight(...)` initializer calls across 20+ analyzer files.
/// Analyzers should prefer factory methods over direct `Insight.init` for new code.
struct InsightFactory {

    // MARK: - Primary Factory Method

    /// Create an insight with an explicit directive.
    static func make(
        metric: HealthMetric,
        title: String,
        summary: String,
        recommendation: String,
        severity: Severity,
        trend: TrendDirection,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        category: InsightCategory,
        directive: InsightDirective,
        relatedMetrics: [HealthMetric] = [],
        context: InsightContext? = nil
    ) -> Insight {
        Insight(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            category: category,
            directive: directive,
            relatedMetrics: relatedMetrics,
            context: context
        )
    }

    // MARK: - Convenience: Observation (no action)

    /// Create an informational insight. observation only, no behavioral direction.
    static func observation(
        metric: HealthMetric,
        title: String,
        summary: String,
        recommendation: String,
        severity: Severity = .info,
        trend: TrendDirection = .stable,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        category: InsightCategory,
        relatedMetrics: [HealthMetric] = [],
        context: InsightContext? = nil
    ) -> Insight {
        make(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            category: category,
            directive: .informational,
            relatedMetrics: relatedMetrics,
            context: context
        )
    }

    // MARK: - Convenience: Medical

    /// Create a seek-medical directive insight.
    static func medicalAdvice(
        metric: HealthMetric,
        title: String,
        summary: String,
        recommendation: String,
        severity: Severity = .warning,
        trend: TrendDirection,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        category: InsightCategory = .clinicalTrajectory,
        relatedMetrics: [HealthMetric] = [],
        context: InsightContext? = nil
    ) -> Insight {
        make(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            category: category,
            directive: .seekMedical,
            relatedMetrics: relatedMetrics,
            context: context
        )
    }
}
