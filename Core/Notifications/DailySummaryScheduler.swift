import Foundation
import UserNotifications

/// Schedules morning daily summary notifications with rich health data
struct DailySummaryScheduler {
    private static let identifier = AppConstants.NotificationID.dailySummary
    private static let eveningIdentifier = AppConstants.NotificationID.eveningSummary

    private static let scoreDeltaThreshold: Int = 3
    private static let anomalyPercentThreshold: Double = 10
    private static let streakMilestoneInterval: Int = 7
    private static let extremeHighScore: Int = 90
    private static let extremeLowScore: Int = 65

    // Bell et al. 2023 (PMC10337295) micro-randomized trial found fixed daily
    // notifications produce zero retention benefit (p=0.42) and recommended
    // adaptive triggering — only fire when there is a real signal worth surfacing.
    static func shouldFire(
        score: Int,
        scoreDelta: Int?,
        topAnomalyPercent: Double?,
        streakDays: Int,
        improvingDays: Int
    ) -> Bool {
        if let d = scoreDelta, abs(d) >= scoreDeltaThreshold { return true }
        if let p = topAnomalyPercent, abs(p) >= anomalyPercentThreshold { return true }
        if streakDays > 0, streakDays.isMultiple(of: streakMilestoneInterval) { return true }
        if score >= extremeHighScore || score < extremeLowScore { return true }
        return false
    }

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

        guard shouldFire(
            score: score,
            scoreDelta: scoreChangeFromYesterday,
            topAnomalyPercent: topAnomaly?.changePercent,
            streakDays: streakDays,
            improvingDays: improvingDays
        ) else {
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
        dateComponents.calendar = Date.cal

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
        dateComponents.calendar = Date.cal

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

    private static func firstSentence(_ text: String) -> String {
        if let dotIndex = text.firstIndex(of: ".") {
            return String(text[text.startIndex...dotIndex])
        }
        return text
    }
}
