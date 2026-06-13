import Foundation
import UserNotifications

/// Journey 1: three reminders fired if the user drops out mid-onboarding.
///
/// Armed only once the user has granted notification permission (the cliffhanger
/// PN ask, or the onboarding-completion ask). Each reminder is a fixed offset
/// from arm time. All three are cancelled the moment onboarding completes, so a
/// user who finishes never receives an abandonment nudge.
///
/// Routed through `NotificationManager.scheduleNotification` so they inherit the
/// authorization gate, frequency cap, fatigue suppression, and quiet-hours
/// guard. Spaced > 1 day apart (2h / 24h / 72h) so the cap never collapses two
/// of them onto the same day.
enum OnboardingAbandonmentScheduler {

    /// Schedule the three abandonment reminders. Each reminder has a distinct
    /// identifier and a time-interval trigger measured from now.
    static func schedule() {
        let manager = NotificationManager.shared

        manager.scheduleNotification(
            title: Copy.Notifications.abandonment2hTitle,
            body: Copy.Notifications.abandonment2hBody,
            identifier: AppConstants.NotificationID.abandonment2h,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: AppConstants.Timing.abandonment2h, repeats: false)
        )
        manager.scheduleNotification(
            title: Copy.Notifications.abandonment24hTitle,
            body: Copy.Notifications.abandonment24hBody,
            identifier: AppConstants.NotificationID.abandonment24h,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: AppConstants.Timing.abandonment24h, repeats: false)
        )
        manager.scheduleNotification(
            title: Copy.Notifications.abandonment72hTitle,
            body: Copy.Notifications.abandonment72hBody,
            identifier: AppConstants.NotificationID.abandonment72h,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: AppConstants.Timing.abandonment72h, repeats: false)
        )
    }

    /// Cancel all three reminders. Called when onboarding completes so a user
    /// who finished never sees an abandonment nudge.
    static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: AppConstants.NotificationID.abandonmentAll)
    }
}
