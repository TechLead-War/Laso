import Foundation
import SwiftUI

/// Severity level for health insights and anomalies
enum Severity: String, Codable, Comparable {
    case info
    case warning
    case critical

    var displayName: String {
        switch self {
        case .info: return "Tip"
        case .warning: return "Check this"
        case .critical: return "Needs attention"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var systemImageName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Clinical triage level for user-facing safety guidance.
enum SafetyTriageLevel: String, Codable, Comparable {
    case normal
    case monitor
    case seekCare

    /// User-facing level label. Resolved through one Copy key per level so the
    /// wording (and any future localization) lives in Copy, not three literals.
    var displayName: String {
        switch self {
        case .normal: return Copy.Notifications.triageLevelNormal
        case .monitor: return Copy.Notifications.triageLevelMonitor
        case .seekCare: return Copy.Notifications.triageLevelSeekCare
        }
    }

    var minimumSeverity: Severity {
        switch self {
        case .normal: return .info
        case .monitor: return .warning
        case .seekCare: return .critical
        }
    }

    /// Same wording as `displayName`; the alert-title prefix shares the level
    /// label, so it resolves through the same single Copy key per level.
    var notificationPrefix: String { displayName }

    private var sortOrder: Int {
        switch self {
        case .normal: return 0
        case .monitor: return 1
        case .seekCare: return 2
        }
    }

    static func < (lhs: SafetyTriageLevel, rhs: SafetyTriageLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Result of triaging a single metric reading into a care action level.
struct SafetyTriageAssessment {
    let metric: HealthMetric
    let level: SafetyTriageLevel
    let reason: String
    let action: String
    let currentValue: Double
    let baselineValue: Double?

    var summaryNote: String? {
        guard level != .normal else { return nil }
        return Copy.Notifications.triageSummaryNote(level: level.displayName, action: action)
    }

    var alertTitle: String {
        Copy.Notifications.triageAlertTitle(prefix: level.notificationPrefix, metric: metric.displayName)
    }

    var alertBody: String {
        Copy.Notifications.triageAlertBody(reason: reason, action: action)
    }

    func decorateRecommendation(_ recommendation: String) -> String {
        guard level != .normal else { return recommendation }
        return Copy.Notifications.triageRecommendationDecorated(level: level.displayName, action: action, recommendation: recommendation)
    }
}

/// Clinical-style triage rules for safety-critical situations.
/// This complements anomaly scoring by adding clear care actions.
struct SafetyTriageEngine {

    /// Highest-signal metrics where abrupt changes can require urgent care.
    static let safetyCriticalMetrics: Set<HealthMetric> = [
        .restingHeartRate,
        .heartRate,
        .bloodOxygen,
        .respiratoryRate,
        .bloodPressureSystolic,
        .bloodPressureDiastolic,
        .bodyTemperature,
        .atrialFibrillationBurden
    ]

    static func assess(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double? = nil,
        trend _: TrendDirection? = nil
    ) -> SafetyTriageAssessment {
        let baseline = normalizedBaseline(baselineValue)

        switch metric {
        case .restingHeartRate:
            if currentValue >= 120 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Resting heart rate is \(formattedValue(currentValue, metric: metric)), which is severely elevated.",
                    action: "Consider contacting a healthcare provider. If you experience chest pain, shortness of breath, or faintness, please get checked promptly."
                )
            }
            if let baseline {
                let rise = percentChange(from: baseline, to: currentValue)
                if rise >= 50, currentValue >= 110 {
                    return make(
                        metric: metric,
                        level: .seekCare,
                        currentValue: currentValue,
                        baselineValue: baseline,
                        reason: "Resting heart rate jumped \(String(format: "%.0f", rise))% above your usual baseline.",
                        action: "Repeat the reading at rest. If it stays elevated, consider speaking with a healthcare provider."
                    )
                }
                if rise >= 30, currentValue >= 95 {
                    return make(
                        metric: metric,
                        level: .monitor,
                        currentValue: currentValue,
                        baselineValue: baseline,
                        reason: "Resting heart rate is \(String(format: "%.0f", rise))% above your baseline.",
                        action: "Recheck after 10-15 minutes of rest. If it persists, you may want to speak with a healthcare provider."
                    )
                }
            }
            if currentValue >= 100 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Resting heart rate is \(formattedValue(currentValue, metric: metric)), above the typical resting range.",
                    action: "Repeat the reading while fully at rest. If it stays elevated, consider speaking with a healthcare provider."
                )
            }

        case .heartRate:
            if currentValue >= 140 || currentValue <= 40 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Heart rate is \(formattedValue(currentValue, metric: metric)), a high-risk value when not exercising.",
                    action: "Consider contacting a healthcare provider. If you have symptoms, please get checked promptly."
                )
            }
            if currentValue >= 120 || currentValue <= 45 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Heart rate is \(formattedValue(currentValue, metric: metric)), outside your usual safe zone.",
                    action: "Recheck after resting. If this persists or you develop symptoms, consider speaking with a healthcare provider."
                )
            }

        case .bloodOxygen:
            if currentValue < 90 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Blood oxygen is \(formattedValue(currentValue, metric: metric)), below the 90% critical threshold.",
                    action: "Consider contacting a healthcare provider. If you experience shortness of breath, confusion, or chest pain, please get checked promptly."
                )
            }
            if currentValue < 93 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Blood oxygen is \(formattedValue(currentValue, metric: metric)), below normal range.",
                    action: "Repeat the reading and monitor closely. If readings stay low, consider speaking with a healthcare provider."
                )
            }

        case .respiratoryRate:
            if currentValue >= 30 || currentValue <= 8 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Respiratory rate is \(formattedValue(currentValue, metric: metric)), which can indicate acute distress.",
                    action: "If breathing feels difficult, consider contacting a healthcare provider promptly."
                )
            }
            if currentValue >= 22 || currentValue <= 10 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Respiratory rate is \(formattedValue(currentValue, metric: metric)), outside normal resting range.",
                    action: "Recheck in 15 minutes while resting. If this persists, consider speaking with a healthcare provider."
                )
            }

        case .bloodPressureSystolic:
            if currentValue >= 180 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Systolic blood pressure is \(formattedValue(currentValue, metric: metric)), in crisis range.",
                    action: "If you have symptoms, consider contacting a healthcare provider promptly."
                )
            }
            if currentValue >= 140 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Systolic blood pressure is \(formattedValue(currentValue, metric: metric)), above normal.",
                    action: "Recheck after resting for 5 minutes. If repeated values stay high, consider speaking with a healthcare provider."
                )
            }

        case .bloodPressureDiastolic:
            if currentValue >= 120 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Diastolic blood pressure is \(formattedValue(currentValue, metric: metric)), in crisis range.",
                    action: "If you have symptoms, consider contacting a healthcare provider promptly."
                )
            }
            if currentValue >= 90 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Diastolic blood pressure is \(formattedValue(currentValue, metric: metric)), above normal.",
                    action: "Recheck after resting for 5 minutes. If repeated values stay high, consider speaking with a healthcare provider."
                )
            }

        case .bodyTemperature:
            if currentValue >= 39.0 || currentValue <= 35.0 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Body temperature is \(formattedValue(currentValue, metric: metric)), a high-risk reading.",
                    action: "Consider contacting a healthcare provider. If you have severe symptoms, please get checked promptly."
                )
            }
            if currentValue >= 37.8 || currentValue <= 35.5 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "Body temperature is \(formattedValue(currentValue, metric: metric)), outside your expected range.",
                    action: "Hydrate, rest, and recheck in 1-2 hours. If this persists, consider speaking with a healthcare provider."
                )
            }

        case .atrialFibrillationBurden:
            if currentValue >= 5 {
                return make(
                    metric: metric,
                    level: .seekCare,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "AFib burden is \(formattedValue(currentValue, metric: metric)), a high-risk level.",
                    action: "Consider contacting your cardiologist to discuss these readings."
                )
            }
            if currentValue >= 1 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "AFib burden is \(formattedValue(currentValue, metric: metric)), above normal target.",
                    action: "Track repeat readings. If this continues, consider sharing the data with your cardiologist."
                )
            }

        default:
            break
        }

        if safetyCriticalMetrics.contains(metric), let baseline {
            let deviation = abs(percentChange(from: baseline, to: currentValue))
            if deviation >= 55 {
                return make(
                    metric: metric,
                    level: .monitor,
                    currentValue: currentValue,
                    baselineValue: baseline,
                    reason: "\(metric.displayName) moved \(String(format: "%.0f", deviation))% away from your baseline.",
                    action: "Recheck this metric soon. If values remain far from baseline or you feel unwell, consider speaking with a healthcare provider."
                )
            }
        }

        return make(
            metric: metric,
            level: .normal,
            currentValue: currentValue,
            baselineValue: baseline,
            reason: "\(metric.displayName) is within expected range.",
            action: "Continue regular tracking."
        )
    }

    private static func make(
        metric: HealthMetric,
        level: SafetyTriageLevel,
        currentValue: Double,
        baselineValue: Double?,
        reason: String,
        action: String
    ) -> SafetyTriageAssessment {
        SafetyTriageAssessment(
            metric: metric,
            level: level,
            reason: reason,
            action: action,
            currentValue: currentValue,
            baselineValue: baselineValue
        )
    }

    private static func normalizedBaseline(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private static func percentChange(from baseline: Double, to current: Double) -> Double {
        guard baseline != 0 else { return 0 }
        return ((current - baseline) / baseline) * 100.0
    }

    private static func formattedValue(_ value: Double, metric: HealthMetric) -> String {
        let unit = metric.unit.isEmpty ? "" : " \(metric.unit)"
        return "\(metric.formatValue(value))\(unit)"
    }
}
