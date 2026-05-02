import FirebaseCore
import FirebaseAuth
import Foundation

/// Extracts launch-time third-party setup from AppDelegate.
final class AppLaunchCoordinator {
    private let remoteConfigManager: RemoteConfigManager
    private let analyticsManager: PostHogManager

    /// Retained so we can deregister on teardown (currently lifetime = app lifetime).
    private var authStateHandle: AuthStateDidChangeListenerHandle?

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

        // PostHog identity. Without `identify`, every session is anonymous and
        // retention/LTV cohorts cannot be built. We bind PostHog's distinct_id
        // to the Firebase UID so the same user is tracked across sessions and
        // across the anonymous → Apple Sign-In transition.
        if let uid = Auth.auth().currentUser?.uid {
            analyticsManager.identify(userId: uid, properties: [
                "auth_provider": Auth.auth().currentUser?.isAnonymous == true ? "anonymous" : "apple"
            ])
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self, let user else { return }
            self.analyticsManager.identify(userId: user.uid, properties: [
                "auth_provider": user.isAnonymous ? "anonymous" : "apple"
            ])
        }

        Task { @MainActor in
            AppAnalytics.shared.startScreenshotTracking()
        }
    }
}
