import Foundation
import UserNotifications

/// Schedules the one-off reminder a user sets from the Next Up action card
/// ("Remind 9:30"). Fires once at the next occurrence of the chosen clock time
/// with the action text, then does not repeat. Mirrors WindDownScheduler's
/// one-shot calendar trigger.
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

    /// The next moment the reminder clock time comes around. `nextDate(after:)`
    /// never looks backwards, so a time that has already gone by today rolls to
    /// tomorrow. A fully dated calendar trigger in the past never fires at all,
    /// so this is what keeps a late tap from setting a reminder that goes off.
    static func nextFireDate(hour: Int = defaultHour,
                             minute: Int = defaultMinute,
                             from now: Date = Date()) -> Date? {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Date.cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime)
    }

    /// True when today's reminder time has passed, so the button can say the
    /// reminder lands tomorrow instead of naming a time that is already gone.
    static func firesTomorrow(hour: Int = defaultHour,
                              minute: Int = defaultMinute,
                              from now: Date = Date()) -> Bool {
        guard let fire = nextFireDate(hour: hour, minute: minute, from: now) else { return false }
        return !Date.cal.isDate(fire, inSameDayAs: now)
    }

    /// Schedule (or replace) the reminder for `action` at the next occurrence of
    /// the given time. Ensures notification permission first (refreshes the auth
    /// cache, and asks once if the user has never been prompted) so a tap does
    /// not silently fail. Returns false if permission is denied or scheduling fails.
    @discardableResult
    @MainActor
    static func schedule(action: String,
                         hour: Int = defaultHour,
                         minute: Int = defaultMinute) async -> Bool {
        var authorized = await NotificationManager.shared.isCurrentlyAuthorized()
        if !authorized {
            authorized = await NotificationManager.shared.requestAuthorization(source: "action_reminder")
        }
        guard authorized else { return false }

        guard let fireDate = nextFireDate(hour: hour, minute: minute) else { return false }

        cancel()

        var components = Date.cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
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
