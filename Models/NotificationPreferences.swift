import Foundation

/// User preferences for notifications
struct NotificationPreferences: Codable {
    var dailySummaryEnabled: Bool = true
    var dailySummaryTime: DateComponents = {
        var c = DateComponents()
        c.hour = 8
        c.minute = 0
        return c
    }()

    var weeklySummaryEnabled: Bool = true
    var weeklySummaryDay: Int = 2 // Monday = 2

    var criticalAlertsEnabled: Bool = true
    var warningAlertsEnabled: Bool = true

    /// Heart rate spike/drop real-time alerts
    var heartRateSpikeAlertsEnabled: Bool = true
    var heartRateSpikeThreshold: Double = 120 // bpm — alert if above
    var heartRateDropThreshold: Double = 45   // bpm — alert if below

    /// Trend reversal alerts (metric was declining, now improving — or vice versa)
    var trendReversalAlertsEnabled: Bool = true

    /// Improvement celebration alerts
    var improvementAlertsEnabled: Bool = true

    var maxNotificationsPerDay: Int = 8

    /// Metrics for which warning alerts are enabled — all health-critical metrics by default
    var warningAlertMetrics: Set<HealthMetric> = [
        .restingHeartRate, .heartRate, .heartRateVariability, .heartRateRecovery,
        .bloodOxygen, .bloodPressureSystolic, .bloodPressureDiastolic,
        .respiratoryRate, .vo2Max,
        .bodyTemperature, .appleSleepingWristTemperature,
        .sleepDuration,
        .walkingAsymmetry,
        .atrialFibrillationBurden, .peripheralPerfusionIndex
    ]

    static let `default` = NotificationPreferences()

    /// All metrics that can be toggled for warning alerts, grouped by category
    static var alertableMetrics: [HealthCategory: [HealthMetric]] {
        var grouped: [HealthCategory: [HealthMetric]] = [:]
        for category in HealthCategory.allCases {
            grouped[category] = category.metrics
        }
        return grouped
    }
}

extension NotificationPreferences {
    /// Coding keys must handle the Set<HealthMetric> properly
    enum CodingKeys: String, CodingKey {
        case dailySummaryEnabled, dailySummaryTime, weeklySummaryEnabled, weeklySummaryDay
        case criticalAlertsEnabled, warningAlertsEnabled, maxNotificationsPerDay
        case warningAlertMetrics
        case heartRateSpikeAlertsEnabled, heartRateSpikeThreshold, heartRateDropThreshold
        case trendReversalAlertsEnabled, improvementAlertsEnabled
    }
}
