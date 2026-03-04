import Foundation

/// User preferences for notifications
struct NotificationPreferences: Codable, Equatable {
    // Only the daily summary is on by default — everything else is opt-in.
    // Users hate notification spam; one morning briefing is enough.

    var dailySummaryEnabled: Bool = true
    var dailySummaryTime: DateComponents = {
        var c = DateComponents()
        c.hour = 8
        c.minute = 0
        return c
    }()

    var weeklySummaryEnabled: Bool = false
    var weeklySummaryDay: Int = 2 // Monday = 2

    var criticalAlertsEnabled: Bool = true
    var warningAlertsEnabled: Bool = false

    /// Heart rate spike/drop real-time alerts
    var heartRateSpikeAlertsEnabled: Bool = true
    var heartRateSpikeThreshold: Double = 120 // bpm — alert if above
    var heartRateDropThreshold: Double = 45   // bpm — alert if below

    /// Trend reversal alerts (metric was declining, now improving — or vice versa)
    var trendReversalAlertsEnabled: Bool = false

    /// Improvement celebration alerts
    var improvementAlertsEnabled: Bool = false

    /// Apple Watch not-worn reminder
    var watchNotWornReminderEnabled: Bool = false

    /// Low battery reminder
    var lowBatteryReminderEnabled: Bool = false

    var maxNotificationsPerDay: Int = 2

    /// Metrics for which warning alerts are enabled — only the most safety-critical metrics by default
    var warningAlertMetrics: Set<HealthMetric> = [
        .restingHeartRate, .heartRate, .heartRateVariability,
        .bloodOxygen,
        .bloodPressureSystolic, .bloodPressureDiastolic,
        .sleepDuration
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
        case watchNotWornReminderEnabled, lowBatteryReminderEnabled
    }
}
