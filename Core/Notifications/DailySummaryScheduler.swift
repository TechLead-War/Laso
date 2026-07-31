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
        guard let trigger = nextOccurrenceTrigger(hour: wakeTime.hour, minute: wakeTime.minute) else { return }

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

        guard let trigger = nextOccurrenceTrigger(
            hour: preferences.eveningSummaryTime.hour ?? 20,
            minute: preferences.eveningSummaryTime.minute ?? 0
        ) else { return }

        NotificationManager.shared.scheduleNotification(
            title: title,
            subtitle: Copy.Notifications.summaryScoreSubtitle(score: score, delta: nil),
            body: body,
            identifier: eveningIdentifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay
        )
    }

    /// A one-shot trigger for the next time the clock hits `hour:minute`.
    ///
    /// Deliberately not `repeats: true`: both summaries bake the day's score,
    /// delta, streak and strain into the content at schedule time, and iOS
    /// replays a repeating request without the app running, so a user who
    /// stopped opening the app was told the same frozen numbers every morning
    /// forever. Each foreground refresh re-arms the next one with fresh data.
    private static func nextOccurrenceTrigger(hour: Int, minute: Int) -> UNCalendarNotificationTrigger? {
        var match = DateComponents()
        match.hour = hour
        match.minute = minute
        guard let next = Date.cal.nextDate(after: Date(), matching: match, matchingPolicy: .nextTime) else {
            return nil
        }
        var fire = Date.cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        fire.calendar = Date.cal
        return UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)
    }

    private static func firstSentence(_ text: String) -> String {
        if let dotIndex = text.firstIndex(of: ".") {
            return String(text[text.startIndex...dotIndex])
        }
        return text
    }
}
