import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Feedback prompt cadence:
/// - First prompt: 5 days after install.
/// - If user skips: nag every 5 days until they submit.
/// - If user submits: wait 30 days, then ask again (recurring).
/// All intervals are tunable via Remote Config.
final class FeedbackPromptManager {
    static let shared = FeedbackPromptManager()

    private let defaults = UserDefaults.standard


    private enum Key {
        static let installDate        = AppKeys.Lifecycle.installDate
        static let lastPromptDate     = AppKeys.Feedback.lastPromptDate
        static let feedbackSubmitted  = AppKeys.Feedback.submitted
        static let lastSubmittedDate  = AppKeys.Feedback.lastSubmittedDate
    }

    /// Days after install before showing the very first prompt.
    private var daysBeforeFirstPrompt: Int { RemoteConfigManager.shared.feedbackDaysBeforeFirstPrompt }

    /// Cooldown after user submits feedback (default 30 days).
    private var postSubmitCooldownDays: Int { RemoteConfigManager.shared.feedbackCooldownDays }

    /// Nag interval when user keeps skipping (default 5 days).
    private var nagIntervalDays: Int { RemoteConfigManager.shared.feedbackDaysBeforeFirstPrompt }

    private init() {}

    // MARK: - Public

    /// Call on every app open. Records install date on first launch.
    func recordAppOpen() {
        if defaults.object(forKey: Key.installDate) == nil {
            defaults.set(Date(), forKey: Key.installDate)
        }
    }

    /// Whether the feedback sheet should be presented right now.
    func shouldShowFeedbackPrompt() -> Bool {
        guard let installDate = defaults.object(forKey: Key.installDate) as? Date else {
            return false
        }

        let daysSinceInstall = Date.cal.dateComponents([.day], from: installDate, to: Date()).day ?? 0

        // Too early. wait at least daysBeforeFirstPrompt
        if daysSinceInstall < daysBeforeFirstPrompt {
            return false
        }

        let hasSubmittedBefore = defaults.bool(forKey: Key.feedbackSubmitted)

        if hasSubmittedBefore {
            // User has submitted before → wait postSubmitCooldownDays (30) from last submission
            guard let lastSubmitted = defaults.object(forKey: Key.lastSubmittedDate) as? Date else {
                // Pre-versioning data: the submitted flag was set but no
                // date was persisted. Reset the flag and ask again.
                defaults.set(false, forKey: Key.feedbackSubmitted)
                return true
            }
            let daysSinceSubmission = Date.cal.dateComponents([.day], from: lastSubmitted, to: Date()).day ?? 0
            return daysSinceSubmission >= postSubmitCooldownDays
        } else {
            // User has never submitted → nag every nagIntervalDays (5) from last prompt shown
            guard let lastPrompt = defaults.object(forKey: Key.lastPromptDate) as? Date else {
                // Never shown before. show now
                return true
            }
            let daysSinceLastPrompt = Date.cal.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            return daysSinceLastPrompt >= nagIntervalDays
        }
    }

    /// Mark that we showed the prompt (to enforce cooldown).
    func markPromptShown() {
        defaults.set(Date(), forKey: Key.lastPromptDate)

        let daysSinceInstall: Int = {
            guard let installDate = defaults.object(forKey: Key.installDate) as? Date else { return 0 }
            return Date.cal.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        }()
        Task { @MainActor in
            AppAnalytics.shared.trackFeedbackPromptShown(daysSinceInstall: daysSinceInstall)
        }
    }

    /// Mark that user submitted feedback. Resets nag cycle, starts 30-day cooldown.
    func markFeedbackSubmitted() {
        defaults.set(true, forKey: Key.feedbackSubmitted)
        defaults.set(Date(), forKey: Key.lastSubmittedDate)
    }

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
