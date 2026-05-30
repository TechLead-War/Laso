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

        // Register a category with `.customDismissAction` so a swipe-dismiss
        // fires `didReceive` (default categories swallow the dismiss). Outgoing
        // notifications set this as their categoryIdentifier.
        let standardCategory = UNNotificationCategory(
            identifier: AppConstants.NotificationCategory.standard,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([standardCategory])

        // Register background readiness refresh (30-minute cadence)
        backgroundRefreshCoordinator.register()
        backgroundRefreshCoordinator.schedule()

        return true
    }

    // MARK: - Remote notification registration

    // No `didRegisterForRemoteNotificationsWithDeviceToken` forwarder: the
    // Firebase swizzling proxy (left enabled) maps the APNS token into Messaging.

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PostHogManager.shared.captureError(error, context: "apns_registration")
    }

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
    }

    // MARK: - Lifecycle (analytics flush)

    func applicationDidEnterBackground(_ application: UIApplication) {
        PostHogManager.shared.flush()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PostHogManager.shared.flush()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        Task { @MainActor in
            AppAnalytics.shared.trackNotificationPresented(identifier: identifier)
            NotificationManager.shared.store?.recordNotificationPresented(id: identifier)
            // Show notification even when app is in foreground
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        let isDismiss = response.actionIdentifier == UNNotificationDismissActionIdentifier
        Task { @MainActor in
            if isDismiss {
                AppAnalytics.shared.trackNotificationDismissed(identifier: identifier)
            } else {
                NotificationManager.shared.store?.recordNotificationOpened(id: identifier)
                NotificationManager.shared.recordAppOpen()
                SessionTracker.shared.pendingSessionSource = .notification
                AppAnalytics.shared.trackNotificationOpened(identifier: identifier)
                // Stage any deep-link route carried in the remote-push payload so
                // the scene navigates to the right surface on activation.
                NotificationRouter.shared.handle(userInfo: userInfo)
            }
            completionHandler()
        }
    }

}
