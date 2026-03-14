import Foundation
import UserNotifications

/// Schedules morning daily summary notifications with rich health data
struct DailySummaryScheduler {
    private static let identifier = AppConstants.NotificationID.dailySummary

    /// Schedule rich daily summary with score, anomalies, top insights, category breakdown,
    /// specific anomaly callout, yesterday score delta, and streak.
    static func schedule(
        score: Int,
        anomalyCount: Int,
        topInsights: [Insight],
        categoryBreakdown: String,
        preferences: NotificationPreferences,
        topAnomaly: (metricName: String, changePercent: Double)? = nil,
        scoreChangeFromYesterday: Int? = nil,
        streakDays: Int = 0
    ) {
        guard preferences.dailySummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        let grade = gradeFor(score: score)

        // Title includes yesterday delta arrow when available
        var titleSuffix = ""
        if let delta = scoreChangeFromYesterday {
            let arrow = delta > 0 ? "\u{2191}" : "\u{2193}"  // ↑ or ↓
            titleSuffix = " \(arrow)\(abs(delta))"
        }
        let title = Copy.Notifications.dailySummaryTitle(score: score, grade: grade, suffix: titleSuffix)

        var bodyParts: [String] = []

        // Specific anomaly callout
        if let anomaly = topAnomaly {
            let direction = anomaly.changePercent > 0 ? "up" : "down"
            bodyParts.append(Copy.Notifications.anomalyCallout(metric: anomaly.metricName, direction: direction, percent: String(format: "%.0f", abs(anomaly.changePercent))))
        } else if anomalyCount > 0 {
            bodyParts.append(Copy.Notifications.metricsNeedAttention(anomalyCount))
        } else {
            bodyParts.append(Copy.Notifications.allMetricsHealthy)
        }

        // Top insight action
        if let top = topInsights.first {
            let shortRec = firstSentence(top.recommendation)
            bodyParts.append(Copy.Notifications.actionPrefix(shortRec))
        }

        // Streak mention
        if streakDays > 1 {
            bodyParts.append(Copy.Notifications.streakDays(streakDays))
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
