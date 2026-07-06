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
                trigger: morningTrigger(for: day1)
            )
        }

        // Day-3 insight nudge.
        if let day3 = Date.cal.date(byAdding: .day, value: 3, to: now), day3 > now {
            manager.scheduleNotification(
                title: Copy.Notifications.trialInsightNudgeTitle,
                body: Copy.Notifications.trialInsightNudgeBody,
                identifier: AppConstants.NotificationID.trialInsightNudge,
                trigger: morningTrigger(for: day3)
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
                trigger: morningTrigger(for: reminderDate)
            )
        }
    }

    /// Journey 3: a single win-back, fired soon after the trial expires. `focus`
    /// is the user's own tracked focus area (their prediction phrase or first
    /// health-focus label); when empty, the generic copy is used. Idempotent via
    /// the fixed identifier — re-arming replaces the pending request.
    /// Returns whether the schedule passed the gates so the caller's one-shot
    /// arm flag is only burned for a push that actually exists.
    @discardableResult
    static func scheduleWinback(focus: String?, delay: TimeInterval) -> Bool {
        let manager = NotificationManager.shared
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)

        if let focus, !focus.isEmpty {
            return manager.scheduleNotification(
                title: Copy.Notifications.trialWinbackTitle(focus: focus),
                body: Copy.Notifications.trialWinbackBody(focus: focus),
                identifier: AppConstants.NotificationID.trialWinback,
                trigger: trigger
            )
        } else {
            return manager.scheduleNotification(
                title: Copy.Notifications.trialWinbackGenericTitle,
                body: Copy.Notifications.trialWinbackGenericBody,
                identifier: AppConstants.NotificationID.trialWinback,
                trigger: trigger
            )
        }
    }

    /// One welcome push after a paid activation that did NOT go through a free
    /// trial. Fired a couple of hours after purchase so it reads as a
    /// confirmation, not an upsell. Idempotent via the fixed identifier.
    static func scheduleNonTrialWelcome() {
        NotificationManager.shared.scheduleNotification(
            title: Copy.Notifications.nonTrialWelcomeTitle,
            body: Copy.Notifications.nonTrialWelcomeBody,
            identifier: AppConstants.NotificationID.nonTrialWelcome,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: AppConstants.Timing.nonTrialWelcomeDelay, repeats: false)
        )
    }

    /// One save push for a subscriber who turned off auto-renew but still has
    /// access. Fired about a day before the period ends, or in an hour when
    /// under a day remains, so it lands while they can still keep the plan.
    /// `focus` names the user's own tracked focus; nil uses the generic copy.
    /// Returns whether the schedule passed the gates so the caller's one-shot
    /// arm flag is only burned for a push that actually exists.
    @discardableResult
    static func scheduleCancelledSave(focus: String?, expiration: Date) -> Bool {
        let manager = NotificationManager.shared
        let now = Date()
        let lead = Date.cal.date(byAdding: .second, value: -Int(AppConstants.Timing.cancelledSaveLeadTime), to: expiration) ?? now
        let trigger: UNNotificationTrigger
        if lead > now {
            trigger = morningTrigger(for: lead)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: AppConstants.Timing.cancelledSaveMinDelay, repeats: false)
        }
        if let focus, !focus.isEmpty {
            return manager.scheduleNotification(
                title: Copy.Notifications.cancelledSaveTitle(focus: focus),
                body: Copy.Notifications.cancelledSaveBody(focus: focus),
                identifier: AppConstants.NotificationID.cancelledSave,
                trigger: trigger
            )
        } else {
            return manager.scheduleNotification(
                title: Copy.Notifications.cancelledSaveGenericTitle,
                body: Copy.Notifications.cancelledSaveGenericBody,
                identifier: AppConstants.NotificationID.cancelledSave,
                trigger: trigger
            )
        }
    }

    /// Retire the pending save push, e.g. when the user turns auto-renew back on.
    static func cancelCancelledSave() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [AppConstants.NotificationID.cancelledSave])
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

    /// Trigger at `date`'s morning wake time — or, when that moment has already
    /// passed (a fully-dated calendar trigger in the past NEVER fires; iOS
    /// keeps it pending forever), an hour from now so the push still lands.
    private static func morningTrigger(for date: Date) -> UNNotificationTrigger {
        let comps = morningComponents(for: date)
        if let fireDate = Date.cal.date(from: comps), fireDate <= Date() {
            return UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        }
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
    }
}
