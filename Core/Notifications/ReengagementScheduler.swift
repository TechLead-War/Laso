import Foundation
import UserNotifications

/// Schedules a local notification that fires after 3 days of inactivity.
/// On every app session, the pending notification is cancelled and rescheduled
/// 3 days into the future. so it only delivers if the user stops opening the app.
enum ReengagementScheduler {

    private static let identifier = AppConstants.NotificationID.reengagement

    /// Interval before the re-engagement notification fires (3 days).
    private static let delaySeconds: TimeInterval = AppConstants.Timing.reengagementDelay

    /// Cancel any pending re-engagement notification and schedule a new one
    /// 3 days from now. Call this on every session start.
    static func reschedule() {
        let center = UNUserNotificationCenter.current()

        // Cancel existing. we always push the timer forward
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Build content using the richest snapshot we have, in priority order:
        // 1) HRV + trend + score (data-grounded loss frame, Headspace ML pattern)
        // 2) Last recovery score only (score-only loss frame)
        // 3) Generic "insights ready" copy (cold-start fallback)
        let content = UNMutableNotificationContent()
        content.sound = .default

        let defaults = UserDefaults.standard
        let lastScore = defaults.integer(forKey: AppKeys.Notifications.lastRecoveryScore)
        let lastHRV = defaults.integer(forKey: AppKeys.Notifications.lastHRVValue)
        let trendRaw = defaults.string(forKey: AppKeys.Notifications.lastHRVTrend) ?? ""
        let lastTrend = TrendDirection(rawValue: trendRaw)

        // Days-inactive is used to rotate copy so repeat-lapsers see fresh framing.
        // We approximate it as the fixed 3-day delay; later we can use the
        // lastAppOpenedAt timestamp if we want finer granularity.
        let daysInactive = Int(delaySeconds / (24 * 60 * 60))

        if lastScore > 0, lastHRV > 0, let trend = lastTrend {
            content.title = Copy.Notifications.healthSnapshot
            content.body = Copy.Notifications.lapsedLossFrameBody(
                score: lastScore,
                hrvMs: lastHRV,
                trend: trend,
                daysInactive: daysInactive
            )
        } else if lastScore > 0 {
            content.title = Copy.Notifications.healthSnapshot
            content.body = Copy.Notifications.lapsedScoreOnlyBody(
                score: lastScore,
                daysInactive: daysInactive
            )
        } else {
            content.title = Copy.Notifications.insightsReady
            content.body = Copy.Notifications.insightsReadyBody
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
