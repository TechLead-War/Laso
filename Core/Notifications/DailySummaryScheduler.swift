import Foundation
import UserNotifications

/// Schedules morning daily summary notifications with rich health data
struct DailySummaryScheduler {
    private static let identifier = AppConstants.NotificationID.dailySummary
    private static let eveningIdentifier = AppConstants.NotificationID.eveningSummary

    /// Schedule rich daily summary with dynamic, varied copy and wake-time-aware scheduling.
    static func schedule(
        score: Int,
        anomalyCount: Int,
        topInsights: [Insight],
        categoryBreakdown: String,
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
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        let body = Copy.Notifications.dynamicDailySummaryBody(
            score: score,
            categoryBreakdown: categoryBreakdown,
            topInsightAction: topAction,
            streakDays: streakDays,
            anomalyCount: anomalyCount,
            topAnomalyMetric: topAnomaly?.metricName,
            dayOfWeek: dayOfWeek
        )

        // Use detected wake-up time, fall back to user preference
        let wakeTime = WakeUpTimeDetector.persistedWakeTime
        var dateComponents = DateComponents()
        dateComponents.hour = wakeTime.hour
        dateComponents.minute = wakeTime.minute
        dateComponents.calendar = Calendar.current

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
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
        dateComponents.calendar = Calendar.current

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: eveningIdentifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay
        )
    }

    /// Legacy entry point for backward compatibility
    static func schedule(
        score: Int,
        topInsight: String,
        preferences: NotificationPreferences
    ) {
        let insight = Insight(
            metric: .steps,
            title: "",
            summary: "",
            recommendation: topInsight,
            severity: .info,
            trend: .stable,
            currentValue: 0,
            baselineValue: 0,
            deviationPercent: 0
        )
        schedule(
            score: score,
            anomalyCount: 0,
            topInsights: [insight],
            categoryBreakdown: "",
            preferences: preferences
        )
    }

    /// Cancel the daily summary
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: identifier)
    }

    static func cancelEvening() {
        NotificationManager.shared.cancelNotification(identifier: eveningIdentifier)
    }

    private static func gradeFor(score: Int) -> String {
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private static func firstSentence(_ text: String) -> String {
        if let dotIndex = text.firstIndex(of: ".") {
            return String(text[text.startIndex...dotIndex])
        }
        return text
    }
}
