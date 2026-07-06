import Foundation
import UserNotifications

/// Journey 5: denied-branch re-permission.
///
/// A user who reached onboarding with no health data (the journal-first branch)
/// can still log morning check-ins. After three check-ins this fires ONE push
/// that restates the user's OWN logged words from the stored prediction phrase,
/// e.g. "You logged waking up tired 3 mornings, want to see if your sleep data
/// explains it?". It never invents a hypothesis. A one-shot flag stops repeats.
enum RepermissionScheduler {

    /// Minimum logged check-ins before the re-permission nudge is allowed to
    /// fire. Three is enough for the user to feel their own pattern before we
    /// offer to explain it with health data.
    private static let requiredCheckIns = 3

    /// Fire the nudge if the user has logged enough check-ins and we have their
    /// own words to quote. No-op when already fired, under the check-in bar, or
    /// missing a stored prediction phrase. Safe to call on every refresh.
    static func checkAndFire() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppKeys.Prediction.repermissionFired) else { return }

        let count = MorningCheckInManager.loadHistory().count
        guard count >= requiredCheckIns else { return }

        // The push must quote the user's own words; without a stored phrase there
        // is nothing honest to say, so stay silent rather than invent one.
        guard let prediction = OnboardingPredictionStore.loadPrediction(),
              !prediction.userPhrase.isEmpty else { return }

        // Await the real authorization state instead of trusting the launch-time
        // cache (cold at first render), and burn the one-shot flag only after
        // the schedule actually passed every gate — a suppressed attempt stays
        // retryable on the next refresh. Runs on the main actor so the flag
        // check-and-set cannot interleave with the other main-actor schedulers.
        Task { @MainActor in
            guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }
            let scheduled = NotificationManager.shared.scheduleNotification(
                title: Copy.Notifications.repermissionTitle(count: count),
                body: Copy.Notifications.repermissionBody(phrase: prediction.userPhrase, count: count),
                identifier: AppConstants.NotificationID.repermission,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            if scheduled {
                defaults.set(true, forKey: AppKeys.Prediction.repermissionFired)
            }
        }
    }

    /// Cancel the re-permission push.
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: AppConstants.NotificationID.repermission)
    }
}
