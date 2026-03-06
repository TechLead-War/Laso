import UIKit
import UserNotifications
import FirebaseCore
import FirebaseCrashlytics
import PostHog

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !UITestMode.isEnabled {
            // Configure Firebase (Analytics + Firestore + Remote Config)
            FirebaseApp.configure()

            // Configure Crashlytics
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            setupCrashMetadata()

            // Fetch Remote Config (non-blocking — uses cached/default values until fetch completes)
            Task {
                await RemoteConfigManager.shared.fetchAndActivate()
            }

            // Configure PostHog Analytics
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

    // MARK: - Crashlytics Metadata

    private func setupCrashMetadata() {
        let crashlytics = Crashlytics.crashlytics()

        // App version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            crashlytics.setCustomValue(version, forKey: "app_version")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            crashlytics.setCustomValue(build, forKey: "build_number")
        }

        // Subscription status
        crashlytics.setCustomValue(FeatureGate.currentTier, forKey: "subscription_tier")
    }
}
