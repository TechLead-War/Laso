import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

/// Owns the FCM registration lifecycle and the `device_tokens` Firestore upsert.
///
/// Swizzling stays ENABLED (no `FirebaseAppDelegateProxyEnabled=NO`), so the
/// Firebase proxy auto-maps the APNS token into Messaging. This manager only:
/// sets the `MessagingDelegate`, asks iOS to register for remote notifications
/// after the user grants authorization, and persists each new registration
/// token so the backend can target a device by token.
final class PushNotificationManager: NSObject, MessagingDelegate {
    static let shared = PushNotificationManager()

    /// Firestore collection holding one document per FCM registration token.
    /// Defined locally because `AppSecrets.Firestore` is outside this domain's
    /// owned files; mirrors the existing `feedbackCollection` naming pattern.
    private static let deviceTokensCollection = "device_tokens"

    private override init() {}

    /// Bind the Messaging delegate. Call once after `FirebaseApp.configure()`.
    func configure() {
        Messaging.messaging().delegate = self
    }

    /// Ask iOS to register for remote notifications so APNS issues a device
    /// token. Safe to call repeatedly; the OS no-ops when already registered.
    /// Gated on notification authorization so we never prompt here.
    func registerForRemoteNotifications() {
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Re-persist the current token on launch so `lastSeenAt`/`appVersion`/
    /// `locale`/`timezone` stay fresh for active devices even when the token
    /// itself has not rotated (Messaging only fires the delegate on change).
    func refreshOnLaunch() {
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                AnalyticsBackend.provider.captureError(error, context: "fcm_token_refresh")
                return
            }
            guard let token else { return }
            self?.writeToken(token)
        }
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        writeToken(fcmToken)
    }

    // MARK: - Firestore upsert

    private func writeToken(_ token: String) {
        // Anonymous auth gives every install a stable uid (AppLaunchCoordinator).
        // Without it the device_tokens rule (request.auth != null) rejects the write.
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            AnalyticsBackend.provider.captureError("missing_uid", context: "fcm_token_write")
            return
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        Task {
            // `provisional` records whether the user is on a quiet provisional
            // grant vs a full opt-in, so the backend can throttle delivery
            // accordingly. Read it live rather than guessing.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isProvisional = settings.authorizationStatus == .provisional

            let data: [String: Any] = [
                "token": token,
                "uid": uid,
                "platform": "ios",
                "appVersion": appVersion,
                "locale": Locale.current.identifier,
                "timezone": TimeZone.current.identifier,
                "provisional": isProvisional,
                "lastSeenAt": FieldValue.serverTimestamp()
            ]

            do {
                try await Firestore.firestore()
                    .collection(Self.deviceTokensCollection)
                    .document(token)
                    .setData(data, merge: true)
            } catch {
                AnalyticsBackend.provider.captureError(error, context: "fcm_token_write")
            }
        }
    }
}
