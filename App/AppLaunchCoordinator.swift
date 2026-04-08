import FirebaseCore
import FirebaseAuth
import Foundation

/// Extracts launch-time third-party setup from AppDelegate.
final class AppLaunchCoordinator {
    private let remoteConfigManager: RemoteConfigManager
    private let analyticsManager: PostHogManager

    init(
        remoteConfigManager: RemoteConfigManager = .shared,
        analyticsManager: PostHogManager = .shared
    ) {
        self.remoteConfigManager = remoteConfigManager
        self.analyticsManager = analyticsManager
    }

    func configureOnLaunch(isUITestMode: Bool = UITestMode.isEnabled) {
        guard !isUITestMode else { return }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Anonymous auth. gives Firestore writes an auth context without requiring user credentials.
        // Firestore rules check request.auth != null to prevent unauthenticated writes.
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, error in
                if let error {
                    PostHogManager.shared.captureError(error, context: "anonymous_auth")
                }
            }
        }

        Task {
            await remoteConfigManager.fetchAndActivate()
        }

        analyticsManager.configure()
        analyticsManager.installCrashHandlers()
        Task { @MainActor in
            AppAnalytics.shared.startScreenshotTracking()
        }
    }
}
