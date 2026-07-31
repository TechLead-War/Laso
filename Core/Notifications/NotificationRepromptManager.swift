import Foundation
import UserNotifications

/// Tracks notification permission denial and determines when to show
/// an in-app re-prompt asking the user to enable notifications in Settings.
///
/// - First denial: records the date
/// - After 7 days: `shouldShowReprompt` returns true (once per 30 days)
/// - The re-prompt is an in-app banner, not the system dialog (iOS blocks re-asking)
enum NotificationRepromptManager {

    // Immutable reference, and UserDefaults serialises its own reads and writes.
    // The denial keys are only ever read-modify-written from the foreground
    // check, so no cross-thread ordering is at stake either.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    /// Call on every foreground return to record denial if needed.
    /// Returns `true` if the re-prompt banner should be shown.
    static func checkAndRecordDenial() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            recordDenialIfNeeded()
            return shouldShowReprompt()
        case .authorized, .provisional, .ephemeral:
            // Permission restored. clear denial tracking
            clearDenialRecord()
            return false
        case .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Internal

    private static func recordDenialIfNeeded() {
        let existing = defaults.double(forKey: AppKeys.Notifications.permissionDeniedDate)
        if existing == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: AppKeys.Notifications.permissionDeniedDate)
            // Tracked inside the once-only branch: the caller runs on every
            // foreground return, so tracking beside it emitted one event per
            // app open forever and denials could not be counted.
            Task { @MainActor in
                AppAnalytics.shared.trackBlockTap(title: "Notification Permission Denied", type: .dataSyncEvent, screen: .home, metadata: ["source": "notification_reprompt", "event": "permission_denied"])
            }
        }
    }

    private static func clearDenialRecord() {
        defaults.removeObject(forKey: AppKeys.Notifications.permissionDeniedDate)
        defaults.removeObject(forKey: AppKeys.Notifications.repromptLastShownDate)
    }

    private static func shouldShowReprompt() -> Bool {
        let deniedTimestamp = defaults.double(forKey: AppKeys.Notifications.permissionDeniedDate)
        guard deniedTimestamp > 0 else { return false }

        let now = Date().timeIntervalSince1970
        let daysSinceDenial = (now - deniedTimestamp) / 86400

        // Wait at least 7 days after denial
        guard daysSinceDenial >= 7 else { return false }

        // Don't show more than once per 30 days
        let lastShown = defaults.double(forKey: AppKeys.Notifications.repromptLastShownDate)
        if lastShown > 0 {
            let daysSinceLastShown = (now - lastShown) / 86400
            guard daysSinceLastShown >= 30 else { return false }
        }

        return true
    }

    /// Call when the re-prompt banner is displayed to the user.
    /// The impression event belongs to the banner view, which fires it on
    /// appear; emitting it here as well double-counted every impression.
    static func recordRepromptShown() {
        defaults.set(Date().timeIntervalSince1970, forKey: AppKeys.Notifications.repromptLastShownDate)
    }
}
