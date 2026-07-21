import Foundation
import UserNotifications

/// Schedules the one-off reminder a user sets from the Next Up action card
/// ("Remind 9:30"). Fires once tonight at the chosen clock time with the
/// action text, then does not repeat. Mirrors WindDownScheduler's one-shot
/// calendar trigger.
enum ActionReminderScheduler {

    /// Default reminder time: 9:30 PM tonight.
    static let defaultHour = 21
    static let defaultMinute = 30

    /// The reminder clock time formatted for the button label (e.g. "9:30 PM").
    static func timeLabel(hour: Int = defaultHour, minute: Int = defaultMinute) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Date.cal.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        f.calendar = Date.cal
        return f.string(from: date)
    }

    /// Schedule (or replace) the reminder for `action` at the given time today.
    /// Returns false if the notification could not be scheduled.
    @discardableResult
    @MainActor
    static func schedule(action: String,
                         hour: Int = defaultHour,
                         minute: Int = defaultMinute) -> Bool {
        cancel()

        var components = Date.cal.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.calendar = Date.cal
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // User-initiated, so bypass the daily cap; opt out of quiet hours since
        // an evening reminder time can fall inside the DND window by design.
        return NotificationManager.shared.scheduleNotification(
            title: Copy.Notifications.actionReminderTitle,
            body: Copy.Notifications.actionReminderBody(action),
            identifier: AppConstants.NotificationID.actionReminder,
            trigger: trigger,
            severity: .info,
            bypassCap: true,
            respectsQuietHours: false
        )
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [AppConstants.NotificationID.actionReminder])
    }
}
