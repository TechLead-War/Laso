import Foundation
import UserNotifications

/// Schedules evening recap notifications summarizing the day's strain and activity
struct EveningSummaryScheduler {
    private static let identifier = AppConstants.NotificationID.eveningSummary

    /// Schedule evening recap with strain level and health score.
    static func schedule(
        score: Int,
        strainLevel: String,
        preferences: NotificationPreferences
    ) {
        guard preferences.eveningSummaryEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
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
            identifier: identifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay
        )
    }

    /// Cancel the evening summary
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: identifier)
    }
}
