import Foundation
import UserNotifications

/// Schedules morning daily summary notifications with rich health data
struct DailySummaryScheduler {
    private static let identifier = "healthpulse.dailySummary"

    /// Schedule rich daily summary with score, anomalies, top insights, and category breakdown
    static func schedule(
        score: Int,
        anomalyCount: Int,
        topInsights: [Insight],
        categoryBreakdown: String,
        preferences: NotificationPreferences
    ) {
        guard preferences.dailySummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        let grade = gradeFor(score: score)
        let title = "Health Score: \(score)/100 (\(grade))"

        var bodyParts: [String] = []

        // Anomaly summary
        if anomalyCount > 0 {
            bodyParts.append("\(anomalyCount) metric\(anomalyCount == 1 ? "" : "s") need\(anomalyCount == 1 ? "s" : "") attention.")
        } else {
            bodyParts.append("All metrics looking healthy!")
        }

        // Top insight action
        if let top = topInsights.first {
            let shortRec = firstSentence(top.recommendation)
            bodyParts.append("Action: \(shortRec)")
        }

        // Category breakdown (compact)
        if !categoryBreakdown.isEmpty {
            bodyParts.append(categoryBreakdown)
        }

        let body = bodyParts.joined(separator: " ")

        var dateComponents = preferences.dailySummaryTime
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
