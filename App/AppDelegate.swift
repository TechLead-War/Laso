import UIKit
import UserNotifications
import FacebookCore
import AppTrackingTransparency

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

        // Re-arm the Watch heart-rate observer here as well as in the SwiftUI
        // startup path: a scene-less background relaunch (BGTask, HealthKit
        // background delivery) never runs the WindowGroup .task, so without
        // this the observer stays dead — the pending "not worn" alarm then
        // fires falsely and battery alerts stop. startMonitoring falls back to
        // its own HKHealthStore until the startup coordinator injects the
        // shared one, and re-running it is idempotent (stops the old query).
        Task { @MainActor in
            WatchMonitor.shared.startMonitoring()
        }

        return true
    }

    // MARK: - Remote notification registration

    // No `didRegisterForRemoteNotificationsWithDeviceToken` forwarder: the
    // Firebase swizzling proxy (left enabled) maps the APNS token into Messaging.

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AnalyticsBackend.provider.captureError(error, context: "apns_registration")
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

    // MARK: - App Tracking Transparency

    /// Ask for tracking permission once the app is active (the prompt is
    /// suppressed if requested before the window is key), then mirror the
    /// choice into the Facebook SDK so Meta only uses the ad identifier for
    /// attribution when the user actually allowed it. Required for Meta
    /// subscription-conversion ad optimization on iOS 14.5+.
    func applicationDidBecomeActive(_ application: UIApplication) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            Settings.shared.isAdvertiserTrackingEnabled =
                ATTrackingManager.trackingAuthorizationStatus == .authorized
            return
        }
        ATTrackingManager.requestTrackingAuthorization { status in
            Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
        }
    }

    // MARK: - Lifecycle (analytics flush)

    func applicationDidEnterBackground(_ application: UIApplication) {
        AnalyticsBackend.provider.flush()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AnalyticsBackend.provider.flush()
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
