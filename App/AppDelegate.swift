import UIKit
import HealthKit
import UserNotifications
import FirebaseCore

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase (Analytics + Firestore + Remote Config)
        FirebaseApp.configure()

        // Fetch Remote Config (non-blocking — uses cached/default values until fetch completes)
        Task {
            await RemoteConfigManager.shared.fetchAndActivate()
        }

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Enable background delivery for HealthKit
        if HKHealthStore.isHealthDataAvailable() {
            let manager = HealthKitManager()
            manager.enableBackgroundDelivery()
        }

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
        completionHandler()
    }
}
