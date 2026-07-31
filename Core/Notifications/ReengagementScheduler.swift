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
    /// The two gates below run before the manager's own copies for a reason:
    /// the authorization call refreshes the manager's cached flag, which on a
    /// fresh install still says "not granted", and the kill-switch branch also
    /// has to retire a request queued before the switch flipped — it would
    /// otherwise still fire up to three days later.
    static func reschedule() {
        Task {
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
        // Cancel existing. we always push the timer forward. Through the manager
        // so the old request's cap slot is refunded before the new one reserves.
        NotificationManager.shared.cancelNotification(identifier: identifier)

        // Build content using the richest snapshot we have, in priority order:
        // 1) HRV + trend + score (data-grounded loss frame, Headspace ML pattern)
        // 2) Last recovery score only (score-only loss frame)
        // 3) Generic "insights ready" copy (cold-start fallback)
        let title: String
        let body: String

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
            title = Copy.Notifications.healthSnapshot
            body = Copy.Notifications.lapsedLossFrameBody(
                score: lastScore,
                hrvMs: lastHRV,
                trend: trend,
                daysInactive: daysInactive
            )
        } else if lastScore > 0 {
            title = Copy.Notifications.healthSnapshot
            body = Copy.Notifications.lapsedScoreOnlyBody(
                score: lastScore,
                daysInactive: daysInactive
            )
        } else {
            title = Copy.Notifications.insightsReady
            body = Copy.Notifications.insightsReadyBody
        }

        // Scheduled through the central manager, not `center.add`: the direct
        // enqueue skipped the frequency cap, fatigue suppression and same-day
        // priority, so this push could land on a day already at its cap and
        // never consumed a slot, letting a later alert overflow the day too.
        // Quiet hours, the deferral event and the scheduled/failed events all
        // come from the manager now.
        // Last-open + 72h lands at the same clock time the user last opened the
        // app, which can be the middle of the night; the manager's quiet-hours
        // deferral moves it to the window's end.
        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, delaySeconds), repeats: false)
        )
    }

    /// Cancel the re-engagement notification (e.g. if user disables notifications).
    static func cancel() {
        NotificationManager.shared.cancelNotification(identifier: identifier)
    }
}
