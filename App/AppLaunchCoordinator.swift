import FirebaseCore
import FirebaseAuth
import Foundation

/// Extracts launch-time third-party setup from AppDelegate.
final class AppLaunchCoordinator {
    private let remoteConfigManager: RemoteConfigManager
    private let analyticsManager: AnalyticsProvider

    /// Retained so we can deregister on teardown (currently lifetime = app lifetime).
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(
        remoteConfigManager: RemoteConfigManager = .shared,
        analyticsManager: AnalyticsProvider = AnalyticsBackend.provider
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
                    AnalyticsBackend.provider.captureError(error, context: "anonymous_auth")
                }
            }
        }

        // Bind the FCM delegate now that Firebase is configured. Swizzling stays
        // enabled, so the proxy maps the APNS token into Messaging automatically.
        PushNotificationManager.shared.configure()

        Task {
            await remoteConfigManager.fetchAndActivate()
        }

        // Prime the notification-authorization cache BEFORE any scheduler runs so
        // the first non-critical schedule at launch is not wrongly suppressed as
        // not_authorized (the cached flag defaults to false). Critical alerts are
        // never gated by this flag. When already authorized, register for remote
        // notifications and refresh the FCM token document.
        Task {
            let authorized = await NotificationManager.shared.isCurrentlyAuthorized()
            if authorized {
                PushNotificationManager.shared.registerForRemoteNotifications()
                PushNotificationManager.shared.refreshOnLaunch()
            }
        }

        // Start the Firestore listener that streams admin-edited Copy overrides
        // so live edits in the in-app dashboard propagate to every screen
        // without an app relaunch. Must run after FirebaseApp.configure().
        CopyOverridesStore.shared.start()

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
            // Referral state needs an auth context (Firestore rules + callable),
            // so refresh it here rather than at cold start. Fires once when the
            // anonymous session lands and again on the anon → Apple link.
            Task { @MainActor in
                await ReferralManager.shared.syncWithFirestore()
            }
        }

        Task { @MainActor in
            AppAnalytics.shared.startScreenshotTracking()
        }
    }
}
