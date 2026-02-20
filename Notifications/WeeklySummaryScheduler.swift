import Foundation
import UserNotifications

/// Schedules weekly trend report notifications with detailed analytics
struct WeeklySummaryScheduler {
    private static let identifier = "healthpulse.weeklySummary"

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
        let title = "Weekly Report: \(score)/100 (\(changeText))"

        var bodyParts: [String] = []

        // Improved vs declined summary
        if improvedCount > 0 || declinedCount > 0 {
            var statusParts: [String] = []
            if improvedCount > 0 {
                statusParts.append("\(improvedCount) improved")
            }
            if declinedCount > 0 {
                statusParts.append("\(declinedCount) declined")
            }
            bodyParts.append(statusParts.joined(separator: ", ") + ".")
        }

        // Top movers with actual percentages
        let movers = topTrends.prefix(3).map { trend in
            let sign = trend.change >= 0 ? "+" : ""
            return "\(trend.metric) \(trend.direction)\(sign)\(String(format: "%.0f", trend.change))%"
        }
        if !movers.isEmpty {
            bodyParts.append("Top movers: " + movers.joined(separator: ", "))
        }

        let body = bodyParts.joined(separator: " ")

        var dateComponents = DateComponents()
        dateComponents.weekday = preferences.weeklySummaryDay
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: trigger
        )
    }

    /// Legacy entry point
    static func schedule(
        score: Int,
        scoreChange: Int,
        topTrends: [(metric: String, direction: String)],
        preferences: NotificationPreferences
    ) {
        schedule(
            score: score,
            scoreChange: scoreChange,
            improvedCount: 0,
            declinedCount: 0,
            topTrends: topTrends.map { ($0.metric, $0.direction, 0.0) },
            preferences: preferences
        )
    }

    /// Cancel the weekly summary
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: identifier)
    }
}
