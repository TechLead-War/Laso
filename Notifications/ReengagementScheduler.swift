import Foundation
import UserNotifications

/// Schedules a local notification that fires after 3 days of inactivity.
/// On every app session, the pending notification is cancelled and rescheduled
/// 3 days into the future — so it only delivers if the user stops opening the app.
enum ReengagementScheduler {

    private static let identifier = "healthpulse.reengagement.3day"

    /// Interval before the re-engagement notification fires (3 days).
    private static let delaySeconds: TimeInterval = 3 * 24 * 60 * 60

    /// Cancel any pending re-engagement notification and schedule a new one
    /// 3 days from now. Call this on every session start.
    static func reschedule() {
        let center = UNUserNotificationCenter.current()

        // Cancel existing — we always push the timer forward
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Build content using last known score if available
        let content = UNMutableNotificationContent()
        content.sound = .default

        let lastScore = UserDefaults.standard.integer(forKey: AppKeys.Data.currentScore)
        if lastScore > 0 {
            content.title = "Your Health Snapshot"
            content.body = "Your last health score was \(lastScore)/100. Check in to see what's changed."
        } else {
            content.title = "Your Health Insights Are Ready"
            content.body = "It's been a few days — open Laso to see your latest health trends."
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delaySeconds,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[ReengagementScheduler] Failed to schedule: \(error.localizedDescription)")
            }
        }
    }

    /// Cancel the re-engagement notification (e.g. if user disables notifications).
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
