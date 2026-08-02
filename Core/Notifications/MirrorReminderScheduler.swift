import Foundation
import UserNotifications

/// The opt-in Daily Mirror reminder: one notification per day for the next
/// seven days, each at a different random time inside the user's chosen
/// window. Random-within-window is the habituation countermeasure the daily
/// selfie apps (Everyday, Selfie A Day) converged on. Off by default; the
/// in-app Mirror Moment is the primary cue and needs no notification.
enum MirrorReminderScheduler {

    /// Default window: 8:00 to 11:00 in the morning.
    static let defaultStartMinutes = 8 * 60
    static let defaultEndMinutes = 11 * 60
    /// A window narrower than this collapses random timing into a fixed time.
    static let minimumWindowMinutes = 15
    private static let daysAhead = 7
    private static let lastMinuteOfDay = 24 * 60 - 1

    private static var identifiers: [String] {
        (0..<daysAhead).map { AppConstants.NotificationID.mirrorReminderPrefix + String($0) }
    }

    private static var todayIdentifier: String {
        AppConstants.NotificationID.mirrorReminderPrefix + "0"
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppKeys.Mirror.reminderEnabled)
    }

    /// Minutes from midnight. Presence-checked, not value-checked: 0 is a
    /// legitimate stored value (a midnight boundary), so only a missing key
    /// falls back to the default.
    static var windowStartMinutes: Int {
        UserDefaults.standard.object(forKey: AppKeys.Mirror.reminderWindowStartMins) as? Int ?? defaultStartMinutes
    }

    static var windowEndMinutes: Int {
        UserDefaults.standard.object(forKey: AppKeys.Mirror.reminderWindowEndMins) as? Int ?? defaultEndMinutes
    }

    /// Turn the reminder on. Returns false when notification permission is
    /// denied, so the settings toggle can revert instead of lying.
    @MainActor
    static func enable(startMinutes: Int, endMinutes: Int) async -> Bool {
        var authorized = await NotificationManager.shared.isCurrentlyAuthorized()
        if !authorized {
            authorized = await NotificationManager.shared.requestAuthorization(source: "mirror_reminder")
        }
        guard authorized else { return false }

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: AppKeys.Mirror.reminderEnabled)
        defaults.set(startMinutes, forKey: AppKeys.Mirror.reminderWindowStartMins)
        defaults.set(endMinutes, forKey: AppKeys.Mirror.reminderWindowEndMins)
        await scheduleWeek(rerollToday: true)
        return true
    }

    @MainActor
    static func updateWindow(startMinutes: Int, endMinutes: Int) {
        let defaults = UserDefaults.standard
        defaults.set(startMinutes, forKey: AppKeys.Mirror.reminderWindowStartMins)
        defaults.set(endMinutes, forKey: AppKeys.Mirror.reminderWindowEndMins)
        guard isEnabled else { return }
        // The window changed, so today's pending time may now sit outside it.
        Task { await scheduleWeek(rerollToday: true) }
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: AppKeys.Mirror.reminderEnabled)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Called on every home open (and after a capture): tops the seven day
    /// runway back up, drops today's reminder once today is captured, and
    /// never disturbs a still-upcoming today slot.
    @MainActor
    static func refreshIfEnabled() {
        guard isEnabled else { return }
        Task { await scheduleWeek() }
    }

    /// Today's slot needs care the other six days do not:
    /// - A still-pending future reminder must survive a refresh untouched; a
    ///   blind reroll can land in the past and silently drop it.
    /// - A reminder that already fired today must never be rescheduled, or
    ///   the same day gets a second notification. `reminderLastRolledDay`
    ///   plus "no longer pending" is how a fired reminder is recognized.
    @MainActor
    private static func scheduleWeek(rerollToday: Bool = false, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let defaults = UserDefaults.standard

        let start = windowStartMinutes
        let end = min(max(windowEndMinutes, start + minimumWindowMinutes), lastMinuteOfDay)

        let pendingIDs = Set(await center.pendingNotificationRequests().map(\.identifier))
        let todayWasPending = pendingIDs.contains(todayIdentifier)
        let capturedToday = MirrorPhotoStore.shared.hasPhoto(on: now)
        let todayKey = MirrorPhotoStore.dayKey(for: now)

        let keepToday = !rerollToday && todayWasPending && !capturedToday
        var removeIDs = identifiers
        if keepToday { removeIDs.removeAll { $0 == todayIdentifier } }
        center.removePendingNotificationRequests(withIdentifiers: removeIDs)

        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        for offset in 0..<daysAhead {
            if offset == 0 {
                if keepToday || capturedToday { continue }
                // Rolled earlier today and no longer pending means it fired.
                if !todayWasPending,
                   defaults.string(forKey: AppKeys.Mirror.reminderLastRolledDay) == todayKey { continue }
            }

            let lower = offset == 0 ? max(start, nowMinutes + 1) : start
            guard lower <= end,
                  let dayStart = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fireDate = calendar.date(byAdding: .minute, value: Int.random(in: lower...end), to: dayStart),
                  fireDate > now else { continue }

            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            components.calendar = calendar
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            // User opted in and chose the window, so the daily cap and quiet
            // hours both yield to that explicit choice.
            let scheduled = NotificationManager.shared.scheduleNotification(
                title: Copy.Notifications.mirrorReminderTitle,
                body: Copy.Notifications.mirrorReminderBody,
                identifier: AppConstants.NotificationID.mirrorReminderPrefix + String(offset),
                trigger: trigger,
                severity: .info,
                bypassCap: true,
                respectsQuietHours: false
            )
            if offset == 0 && scheduled {
                defaults.set(todayKey, forKey: AppKeys.Mirror.reminderLastRolledDay)
            }
        }
    }
}
