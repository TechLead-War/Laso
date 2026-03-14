import UIKit
import UserNotifications
import BackgroundTasks
import FirebaseCore
import PostHog

/// AppDelegate for background delivery registration and notification setup
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private static let bgRefreshTaskID = "com.lasohealth.com.background-refresh"

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

        // Register background readiness refresh (30-minute cadence)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgRefreshTaskID,
            using: nil
        ) { task in
            Self.handleBackgroundRefresh(task as! BGAppRefreshTask)
        }
        Self.scheduleBackgroundRefresh()

        return true
    }

    // MARK: - Background Readiness Refresh

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleBackgroundRefresh()

        let hkManager = HealthKitManager()
        let liveVM = LiveViewModel(healthKitManager: hkManager)

        task.expirationHandler = {
            // Lightweight task — nothing to cancel
        }

        // Fetch latest daily values (RHR, HRV) + sleep, then readiness auto-computes
        liveVM.fetchHomeData()

        // Give HealthKit queries time to complete, then mark done
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            task.setTaskCompleted(success: liveVM.recovery.readinessScore != nil)
        }
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
