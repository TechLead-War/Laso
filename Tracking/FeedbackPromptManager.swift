import Foundation

/// Manages the "ask for feedback after 5 days" logic.
/// Uses UserDefaults only — no backend needed for scheduling.
final class FeedbackPromptManager {
    static let shared = FeedbackPromptManager()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let installDate = "laso.install_date"
        static let lastPromptDate = "laso.feedback.last_prompt_date"
        static let feedbackSubmitted = "laso.feedback.submitted"
        static let promptCooldownDays = "laso.feedback.cooldown_days"
    }

    /// Default: re-ask every 30 days after the first prompt (if user skipped).
    private let cooldownDays: Int = 30

    /// Minimum days after install before showing the first prompt.
    private let daysBeforeFirstPrompt: Int = 5

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

        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0

        // Too early
        if daysSinceInstall < daysBeforeFirstPrompt {
            return false
        }

        // Check cooldown from last prompt
        if let lastPrompt = defaults.object(forKey: Key.lastPromptDate) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date()).day ?? 0
            if daysSinceLastPrompt < cooldownDays {
                return false
            }
        }

        return true
    }

    /// Mark that we showed the prompt (to enforce cooldown).
    func markPromptShown() {
        defaults.set(Date(), forKey: Key.lastPromptDate)

        // Fire analytics event
        let daysSinceInstall: Int = {
            guard let installDate = defaults.object(forKey: Key.installDate) as? Date else { return 0 }
            return Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        }()
        AppAnalytics.shared.trackFeedbackPromptShown(daysSinceInstall: daysSinceInstall)
    }

    /// Mark that user submitted feedback (for analytics).
    func markFeedbackSubmitted() {
        defaults.set(true, forKey: Key.feedbackSubmitted)
    }

    /// Days since install (for metadata).
    var daysSinceInstall: Int {
        guard let installDate = defaults.object(forKey: Key.installDate) as? Date else { return 0 }
        return Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }
}
