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
    ///
    /// Builds the request through `center.add()` directly (it needs the richest
    /// snapshot copy, which `NotificationManager.scheduleNotification` cannot
    /// build), so it does not inherit the manager's authorization gate. Without
    /// the check below a fresh install — where the permission prompt has not run
    /// yet — would schedule into the void: iOS silently drops the request until
    /// permission is granted, which never happens for this id. Gate here so the
    /// notification is only enqueued once the user has actually granted.
    static func reschedule() {
        Task {
            // This builder bypasses NotificationManager.scheduleNotification, so
            // the remote kill switch must be re-checked here. Re-engagement is
            // never critical, so kill_notifications always blocks it. A request
            // queued before the switch flipped would still fire up to 3 days
            // later, so cancel it before skipping.
            let notifType = NotificationManager.notificationType(identifier)
            guard !RemoteConfigManager.shared.killNotifications else {
                cancel()
                await MainActor.run {
                    AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "kill_switch")
                }
                return
            }
            guard await NotificationManager.shared.isCurrentlyAuthorized() else {
                await MainActor.run {
                    AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "not_authorized")
                }
                return
            }
            performReschedule()
        }
    }

    private static func performReschedule() {
        let center = UNUserNotificationCenter.current()

        // Cancel existing. we always push the timer forward
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Build content using the richest snapshot we have, in priority order:
        // 1) HRV + trend + score (data-grounded loss frame, Headspace ML pattern)
        // 2) Last recovery score only (score-only loss frame)
        // 3) Generic "insights ready" copy (cold-start fallback)
        let content = UNMutableNotificationContent()
        content.sound = .default
        // Standard category so a swipe-dismiss fires didReceive (tracked as a
        // dismissal). This builder bypasses NotificationManager's central one,
        // so the category is set here directly.
        content.categoryIdentifier = AppConstants.NotificationCategory.standard

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

        // Last-open + 72h lands at the same clock time the user last opened
        // the app, which can be the middle of the night. Push a quiet-hours
        // fire time forward to the window's end (e.g. 02:00 -> 07:00) using
        // the same rule the central manager applies.
        let target = NotificationManager.shared.quietHoursAdjusted(Date().addingTimeInterval(delaySeconds))
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, target.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Mirror the central manager's success/error tracking: scheduled also
        // stamps the sent timestamp so a later presented/opened has a known
        // latency.
        let notifType = NotificationManager.notificationType(identifier)
        center.add(request) { error in
            Task { @MainActor in
                if let error {
                    AppAnalytics.shared.trackNotificationFailed(type: notifType, identifier: identifier, error: error.localizedDescription)
                } else {
                    AppAnalytics.shared.trackNotificationScheduled(type: notifType, identifier: identifier)
                }
            }
        }
    }

    /// Cancel the re-engagement notification (e.g. if user disables notifications).
    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
