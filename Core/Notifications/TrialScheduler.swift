import Foundation
import UserNotifications

/// Journey 2 (trial) + Journey 3 (trial expired).
///
/// Journey 2 fires three nudges across the live trial: a day-1 getting-started
/// prompt, a day-3 insight nudge, and a reminder the day before renewal. Every
/// offset is derived from the live trial length, never a hardcoded 7 days — the
/// trial-day count resolves through `SubscriptionConfig.trialDays` (live Remote
/// Config with a fallback) and the renewal anchor is the real entitlement
/// expiration date StoreKit reports for the introductory period.
///
/// Journey 3 is a single win-back after the trial expires, referencing the
/// user's own tracked focus so the nudge is about their question.
///
/// All notifications route through `NotificationManager.scheduleNotification`
/// (auth gate + cap) and are cancelled the moment the user purchases.
enum TrialScheduler {

    /// Arm the three trial-lifecycle nudges. Call once when the trial begins
    /// (purchase success). `trialEnd` is the live entitlement expiration; when
    /// nil the renewal reminder is skipped rather than faked.
    static func scheduleTrialLifecycle(trialEnd: Date?) {
        let manager = NotificationManager.shared
        let now = Date()

        // Day-1 getting started: one day after the trial begins.
        if let day1 = Date.cal.date(byAdding: .day, value: 1, to: now), day1 > now {
            manager.scheduleNotification(
                title: Copy.Notifications.trialGettingStartedTitle,
                body: Copy.Notifications.trialGettingStartedBody,
                identifier: AppConstants.NotificationID.trialGettingStarted,
                trigger: UNCalendarNotificationTrigger(dateMatching: morningComponents(for: day1), repeats: false)
            )
        }

        // Day-3 insight nudge.
        if let day3 = Date.cal.date(byAdding: .day, value: 3, to: now), day3 > now {
            manager.scheduleNotification(
                title: Copy.Notifications.trialInsightNudgeTitle,
                body: Copy.Notifications.trialInsightNudgeBody,
                identifier: AppConstants.NotificationID.trialInsightNudge,
                trigger: UNCalendarNotificationTrigger(dateMatching: morningComponents(for: day3), repeats: false)
            )
        }

        // Renewal reminder: 24h before the real trial end. Skipped entirely when
        // StoreKit has not surfaced an expiration date.
        if let trialEnd,
           let reminderDate = Date.cal.date(byAdding: .hour, value: -24, to: trialEnd),
           reminderDate > now {
            let daysLeft = max(1, Date.cal.dateComponents([.day], from: now, to: trialEnd).day ?? 1)
            manager.scheduleNotification(
                title: Copy.Notifications.trialRenewalTitle(daysLeft: daysLeft),
                body: Copy.Notifications.trialRenewalBody,
                identifier: AppConstants.NotificationID.trialRenewalReminder,
                trigger: UNCalendarNotificationTrigger(dateMatching: morningComponents(for: reminderDate), repeats: false)
            )
        }
    }

    /// Journey 3: a single win-back, fired soon after the trial expires. `focus`
    /// is the user's own tracked focus area (their prediction phrase or first
    /// health-focus label); when empty, the generic copy is used. Idempotent via
    /// the fixed identifier — re-arming replaces the pending request.
    static func scheduleWinback(focus: String?, delay: TimeInterval) {
        let manager = NotificationManager.shared
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)

        if let focus, !focus.isEmpty {
            manager.scheduleNotification(
                title: Copy.Notifications.trialWinbackTitle(focus: focus),
                body: Copy.Notifications.trialWinbackBody(focus: focus),
                identifier: AppConstants.NotificationID.trialWinback,
                trigger: trigger
            )
        } else {
            manager.scheduleNotification(
                title: Copy.Notifications.trialWinbackGenericTitle,
                body: Copy.Notifications.trialWinbackGenericBody,
                identifier: AppConstants.NotificationID.trialWinback,
                trigger: trigger
            )
        }
    }

    /// Cancel every trial-lifecycle and win-back notification. Called on
    /// purchase so a paying user never sees a trial nudge.
    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: AppConstants.NotificationID.trialAll)
    }

    /// Fire trial nudges at the user's detected wake time so they land in the
    /// morning, not at a random hour. Falls back to 9 AM when no wake time is
    /// stored, matching the engagement drip default.
    private static func morningComponents(for date: Date) -> DateComponents {
        let defaults = UserDefaults.standard
        let hour = defaults.object(forKey: AppKeys.Engagement.detectedWakeHour) as? Int ?? 9
        let minute = defaults.object(forKey: AppKeys.Engagement.detectedWakeMinute) as? Int ?? 0
        var comps = Date.cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        comps.calendar = Date.cal
        return comps
    }
}
