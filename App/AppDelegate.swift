import UIKit
import UserNotifications
import FacebookCore

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let launchCoordinator = AppLaunchCoordinator()
    private let backgroundRefreshCoordinator = BackgroundRefreshCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        launchCoordinator.configureOnLaunch()

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register background readiness refresh (30-minute cadence)
        backgroundRefreshCoordinator.register()
        backgroundRefreshCoordinator.schedule()

        return true
    }

<<<<<<< Updated upstream
    // MARK: - Lifecycle (analytics flush)

    /// Flush PostHog queue when the app is backgrounded. Without this,
    /// session_end and any tail events can be lost if the OS reaps the
    /// process before the SDK's auto-flush timer fires.
    func applicationDidEnterBackground(_ application: UIApplication) {
        PostHogManager.shared.flush()
    }

    /// Last-chance flush. iOS sometimes calls willTerminate before reaping
    /// (e.g. user kills app from app switcher when not suspended).
    func applicationWillTerminate(_ application: UIApplication) {
        PostHogManager.shared.flush()
=======
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[.sourceApplication] as? String,
            annotation: options[.annotation]
        )
>>>>>>> Stashed changes
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
        NotificationManager.shared.recordAppOpen()
        SessionTracker.shared.pendingSessionSource = .notification
        AppAnalytics.shared.trackNotificationOpened(identifier: identifier)
        completionHandler()
    }

}
