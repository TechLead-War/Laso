import UIKit
import UserNotifications

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let launchCoordinator = AppLaunchCoordinator()
    private let backgroundRefreshCoordinator = BackgroundRefreshCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        launchCoordinator.configureOnLaunch()

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register background readiness refresh (30-minute cadence)
        backgroundRefreshCoordinator.register()
        backgroundRefreshCoordinator.schedule()

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
