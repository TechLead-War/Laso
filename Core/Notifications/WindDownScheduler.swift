import Foundation
import UserNotifications

/// Schedules an evening wind-down push (~60 min before the user's predicted bedtime).
/// Follows the Oura pattern: concrete bedtime anchor, data-grounded, never faked.
///
/// If no target bedtime is available (SleepNeedCalculator not ready, insufficient data),
/// the scheduler cancels any pending wind-down and skips. We never invent a bedtime.
struct WindDownScheduler {
    private static let identifier = AppConstants.NotificationID.windDown

    /// How many minutes before the predicted bedtime we fire.
    private static let leadMinutes = 60

    /// Pass 12 BE perf: cached current calendar. `schedule(...)` runs on every
    /// HealthKit refresh and uses two `Calendar.current` calls per invocation.
    private static let cal: Calendar = Calendar.current

    /// Schedule the wind-down push.
    /// - Parameters:
    ///   - recommendedBedtime: A real target bedtime (from `SleepNeedCalculator.currentNeed?.recommendedBedtime`).
    ///     Pass `nil` if unavailable — the scheduler will cancel and skip.
    ///   - lastHRV: Optional last HRV value in ms (for a personalised hint when HRV is low).
    ///   - hrvIsLow: Whether the user's recent HRV is meaningfully below baseline.
    ///   - preferences: User notification preferences.
    static func schedule(
        recommendedBedtime: Date?,
        lastHRV: Int?,
        hrvIsLow: Bool,
        preferences: NotificationPreferences
    ) {
        guard preferences.windDownEnabled else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        // Hard requirement: never fake a bedtime. If we have no target, cancel and skip.
        guard let bedtime = recommendedBedtime else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        // Fire at bedtime - 60 min. If that timestamp has already passed for today,
        // skip silently so we don't queue a notification that fires immediately.
        guard let fireDate = Self.cal.date(byAdding: .minute, value: -leadMinutes, to: bedtime) else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }
        guard fireDate > Date() else {
            NotificationManager.shared.cancelNotification(identifier: identifier)
            return
        }

        let bedtimeDisplay = Self.formatBedtime(bedtime)
        let hrvHint: String? = {
            guard hrvIsLow, let lastHRV, lastHRV > 0 else { return nil }
            return "Your HRV (\(lastHRV) ms) suggests an early night."
        }()

        let title = Copy.Notifications.windDownTitle()
        let body = Copy.Notifications.windDownBody(bedtimeDisplay: bedtimeDisplay, hrvHint: hrvHint)

        // One-shot trigger for tonight. The housekeeping pipeline reschedules on each refresh,
        // so the next day's bedtime gets its own fresh firing.
        var components = Self.cal.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        components.calendar = Self.cal

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        // Non-critical, medium priority, counts toward the daily cap.
        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: trigger,
            maxPerDay: preferences.maxNotificationsPerDay,
            severity: .info,
            deviationPercent: 0,
            metricInFocus: false,
            bypassCap: false
        )
    }

    /// Cancel any pending wind-down notification.
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: identifier)
    }

    // Pass 8 Y: bedtime is shown inside a user-visible notification body, so
    // it must follow the user's clock preference (12h vs 24h, AM/PM symbols
    // localized). `.formatted(.dateTime.hour().minute())` resolves both from
    // `Locale.current`. The previous `en_US_POSIX` "h:mm a" formatter forced
    // "9:30 PM" on every locale (a French user expects "21:30"). Foundation
    // caches the underlying FormatStyle so the per-call cost is negligible.
    private static func formatBedtime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
