import Foundation
import UserNotifications

/// Schedules weekly trend report notifications with detailed analytics
struct WeeklySummaryScheduler {
    private static let identifier = AppConstants.NotificationID.weeklySummary

    /// Schedule rich weekly summary with score, improvements, declines, and top trends
    static func schedule(
        score: Int,
        scoreChange: Int,
        improvedCount: Int,
        declinedCount: Int,
        topTrends: [(metric: String, direction: String, change: Double)],
        preferences: NotificationPreferences
    ) {
        guard preferences.weeklySummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        let changeText = scoreChange >= 0 ? "+\(scoreChange)" : "\(scoreChange)"
        let title = Copy.Notifications.weeklyReportTitle(score: score, change: changeText)

        var bodyParts: [String] = []

        // Improved vs declined summary
        if improvedCount > 0 || declinedCount > 0 {
            var statusParts: [String] = []
            if improvedCount > 0 {
                statusParts.append(Copy.Notifications.improvedCount(improvedCount))
            }
            if declinedCount > 0 {
                statusParts.append(Copy.Notifications.declinedCount(declinedCount))
            }
            bodyParts.append(statusParts.joined(separator: ", ") + ".")
        }

        // Top movers with actual percentages
        let movers = topTrends.prefix(3).map { trend in
            let sign = trend.change >= 0 ? "+" : ""
            return "\(trend.metric) \(trend.direction)\(sign)\(String(format: "%.0f", trend.change))%"
        }
        if !movers.isEmpty {
            bodyParts.append(Copy.Notifications.topMovers + movers.joined(separator: ", "))
        }

        let body = bodyParts.joined(separator: " ")

        // RC-driven fire time (default 10:00) so the weekly summary does not
        // collide with the morning daily summary, which fires around the user's
        // wake time (~7-9 AM). Baked default holds when RC is offline.
        var dateComponents = DateComponents()
        dateComponents.weekday = preferences.weeklySummaryDay
        dateComponents.hour = RemoteConfigManager.shared.weeklySummaryFireHour
        dateComponents.minute = RemoteConfigManager.shared.weeklySummaryFireMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay
        )
    }
}
