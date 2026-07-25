import Foundation
import UserNotifications

/// Schedules morning daily summary notifications with rich health data
struct DailySummaryScheduler {
    private static let identifier = AppConstants.NotificationID.dailySummary
    private static let eveningIdentifier = AppConstants.NotificationID.eveningSummary

    /// Schedule rich daily summary with dynamic, varied copy and wake-time-aware scheduling.
    /// Fires every day the toggle is on: the earlier adaptive gate (only fire on
    /// a big delta/anomaly/streak/extreme score) silently produced ZERO summaries
    /// for metric-stable users, because housekeeping re-runs cancelled the pending
    /// repeat before the next morning.
    static func schedule(
        score: Int,
        anomalyCount: Int,
        topInsights: [Insight],
        preferences: NotificationPreferences,
        topAnomaly: (metricName: String, changePercent: Double)? = nil,
        scoreChangeFromYesterday: Int? = nil,
        streakDays: Int = 0,
        improvingDays: Int = 0
    ) {
        guard preferences.dailySummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        // Dynamic title. leads with the most interesting psychological hook
        let title = Copy.Notifications.dynamicDailySummaryTitle(
            score: score,
            scoreDelta: scoreChangeFromYesterday,
            streakDays: streakDays,
            topAnomalyMetric: topAnomaly?.metricName,
            topAnomalyPercent: topAnomaly?.changePercent,
            improvingDays: improvingDays
        )

        // Read which hook category was chosen (set inside dynamicDailySummaryTitle)
        let hookCategory = UserDefaults.standard.string(
            forKey: AppKeys.Notifications.lastDailyHookCategory
        )

        // Dynamic body. adds context without repeating the title
        let topAction: String? = topInsights.first.map { firstSentence($0.recommendation) }
        let dayOfWeek = Date.cal.component(.weekday, from: Date())

        let body = Copy.Notifications.dynamicDailySummaryBody(
            score: score,
            topInsightAction: topAction,
            streakDays: streakDays,
            anomalyCount: anomalyCount,
            topAnomalyMetric: topAnomaly?.metricName,
            dayOfWeek: dayOfWeek
        )

        // Detected wake-up time, already clamped to a sane morning band.
        let wakeTime = WakeUpTimeDetector.persistedWakeTime
        var dateComponents = DateComponents()
        dateComponents.hour = wakeTime.hour
        dateComponents.minute = wakeTime.minute
        dateComponents.calendar = Date.cal

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
            subtitle: Copy.Notifications.summaryScoreSubtitle(score: score, delta: scoreChangeFromYesterday),
            body: body,
            identifier: identifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay,
            hookCategory: hookCategory
        )
    }

    static func scheduleEvening(
        score: Int,
        strainLevel: String,
        preferences: NotificationPreferences
    ) {
        guard preferences.eveningSummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: eveningIdentifier)
            return
        }

        let title = Copy.Notifications.eveningSummaryTitle(strainLevel: strainLevel)
        let body = Copy.Notifications.eveningSummaryBody(strainLevel: strainLevel, score: score)

        var dateComponents = preferences.eveningSummaryTime
        dateComponents.calendar = Date.cal

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
            subtitle: Copy.Notifications.summaryScoreSubtitle(score: score, delta: nil),
            body: body,
            identifier: eveningIdentifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay
        )
    }

    private static func firstSentence(_ text: String) -> String {
        if let dotIndex = text.firstIndex(of: ".") {
            return String(text[text.startIndex...dotIndex])
        }
        return text
    }
}
