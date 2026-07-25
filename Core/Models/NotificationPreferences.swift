import Foundation

/// User preferences for notifications
struct NotificationPreferences: Codable, Equatable {
    // Summaries (daily, evening, weekly) are on by default; one-off alert
    // types stay opt-in. Note: flipping a default here only affects users
    // with no stored preferences — existing users keep their saved values.

    var dailySummaryEnabled: Bool = true
    var dailySummaryTime: DateComponents = {
        var c = DateComponents()
        c.hour = 8
        c.minute = 0
        return c
    }()

    var eveningSummaryEnabled: Bool = true
    var eveningSummaryTime: DateComponents = {
        var c = DateComponents()
        c.hour = 20
        c.minute = 0
        return c
    }()

    /// Evening wind-down push (~60 min before predicted bedtime). Default on because
    /// it only fires when we have enough sleep data to compute a real bedtime target.
    var windDownEnabled: Bool = true

    var weeklySummaryEnabled: Bool = true
    var weeklySummaryDay: Int = 2 // Monday = 2

    var criticalAlertsEnabled: Bool = true
    var warningAlertsEnabled: Bool = false

    /// Heart rate spike/drop real-time alerts
    var heartRateSpikeAlertsEnabled: Bool = true
    var heartRateSpikeThreshold: Double = 120 // bpm. alert if above
    var heartRateDropThreshold: Double = 45   // bpm. alert if below

    /// Trend reversal alerts (metric was declining, now improving. or vice versa)
    var trendReversalAlertsEnabled: Bool = false

    /// Improvement celebration alerts
    var improvementAlertsEnabled: Bool = false

    /// Apple Watch not-worn reminder
    var watchNotWornReminderEnabled: Bool = true

    var maxNotificationsPerDay: Int = 2

    /// Metrics for which warning alerts are enabled. only the most safety-critical metrics by default
    var warningAlertMetrics: Set<HealthMetric> = [
        .restingHeartRate, .heartRate, .heartRateVariability,
        .bloodOxygen,
        .bloodPressureSystolic, .bloodPressureDiastolic,
        .sleepDuration
    ]

    static let `default` = NotificationPreferences()
}

extension NotificationPreferences {
    /// Coding keys must handle the Set<HealthMetric> properly
    enum CodingKeys: String, CodingKey {
        case dailySummaryEnabled, dailySummaryTime, eveningSummaryEnabled, eveningSummaryTime
        case windDownEnabled
        case weeklySummaryEnabled, weeklySummaryDay
        case criticalAlertsEnabled, warningAlertsEnabled, maxNotificationsPerDay
        case warningAlertMetrics
        case heartRateSpikeAlertsEnabled, heartRateSpikeThreshold, heartRateDropThreshold
        case trendReversalAlertsEnabled, improvementAlertsEnabled
        case watchNotWornReminderEnabled
    }
}
