import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Persists user feedback locally and to Firestore. Used by FeedbackSheet.
/// Sendable: holds no stored state. `defaults` is computed rather than stored
/// because `UserDefaults` is thread-safe but not Sendable-audited by Apple, and
/// storing an instance would block the conformance for no gain.
final class FeedbackPromptManager: Sendable {
    static let shared = FeedbackPromptManager()

    private var defaults: UserDefaults { .standard }

    private enum Key {
        static let installDate = AppKeys.Lifecycle.installDate
    }

    private init() {}

    // MARK: - Public

    /// Days since install (for metadata).
    var daysSinceInstall: Int {
        guard let installDate = defaults.object(forKey: Key.installDate) as? Date else { return 0 }
        return Date.cal.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }

    /// Save feedback locally and send to Firestore.
    /// `contactEmail` is optional and only populated for categories like bug reports or support
    /// requests where the user may want a reply.
    func submitFeedback(
        category: String,
        text: String,
        contactEmail: String? = nil,
        completion: @escaping () -> Void
    ) {
        var allFeedback = defaults.stringArray(forKey: AppKeys.Feedback.entries) ?? []
        let entry = "[\(category)] \(text). \(Date().formatted(.dateTime.month().day().year()))"
        allFeedback.append(entry)
        defaults.set(allFeedback, forKey: AppKeys.Feedback.entries)

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        var feedbackData: [String: Any] = [
            "category": category,
            "text": text,
            "timestamp": Date().timeIntervalSince1970,
            "days_since_install": daysSinceInstall,
            "app_version": appVersion,
            "build_number": buildNumber,
            "ios_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "locale": Locale.current.identifier,
            "bundle_id": Bundle.main.bundleIdentifier ?? AppSecrets.App.bundleID
        ]

        if let email = contactEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            feedbackData["contact_email"] = email
        }

#if canImport(FirebaseFirestore)
        Firestore.firestore().collection(AppSecrets.Firestore.feedbackCollection).addDocument(data: feedbackData) { _ in
            completion()
        }
#else
        completion()
#endif
    }
}
