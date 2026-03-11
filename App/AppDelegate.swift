import UIKit
import UserNotifications
import FirebaseCore
import PostHog

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !UITestMode.isEnabled {
            // Configure Firebase (Firestore + Remote Config only — analytics via PostHog)
            FirebaseApp.configure()

            // Fetch Remote Config (non-blocking — uses cached/default values until fetch completes)
            Task {
                await RemoteConfigManager.shared.fetchAndActivate()
            }

            // Configure PostHog — sole analytics backend
            PostHogManager.shared.configure()
        }

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        NotificationManager.shared.store?.recordNotificationOpened(id: identifier)
        SessionTracker.shared.pendingSessionSource = .notification
        AppAnalytics.shared.trackNotificationOpened(identifier: identifier)
        completionHandler()
    }

}
