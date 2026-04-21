import StoreKit
import Foundation
import UIKit

/// Manages App Store review prompt timing.
/// Prompts after a positive moment (score improvement, streak milestone)
/// only when the user is activated, has 7+ sessions, and hasn't been asked recently.
@MainActor
final class AppStoreReviewManager {
    static let shared = AppStoreReviewManager()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let lastPromptDate = "laso.review.last_prompt_date"
        static let promptCount = "laso.review.prompt_count"
    }

    /// Minimum days between review prompts (Apple limits to 3/year anyway)
    private let cooldownDays = 120

    /// Minimum sessions before first prompt
    private let minSessions = 7

    private init() {}

    /// Call after a positive moment (score improved, streak milestone, insight marked helpful).
    /// The method will check eligibility and only prompt if appropriate.
    func requestReviewIfEligible(trigger: String) {
        guard SessionTracker.shared.isActivated else { return }
        guard SessionTracker.shared.totalSessions >= minSessions else { return }

        if let lastDate = defaults.object(forKey: Key.lastPromptDate) as? Date {
            let daysSinceLast = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSinceLast >= cooldownDays else { return }
        }

        // Eligible — prompt
        defaults.set(Date(), forKey: Key.lastPromptDate)
        let count = defaults.integer(forKey: Key.promptCount) + 1
        defaults.set(count, forKey: Key.promptCount)

        AppAnalytics.shared.trackAppStoreReviewPrompted(trigger: trigger)

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// User explicitly tapped "Rate on App Store" in Settings. Bypasses activation, session, and
    /// cooldown gates. Prefers the deterministic App Store review URL when the App Store ID is
    /// configured, otherwise falls back to the in-app `SKStoreReviewController` prompt.
    func requestReviewFromUser(trigger: String) {
        defaults.set(Date(), forKey: Key.lastPromptDate)
        let count = defaults.integer(forKey: Key.promptCount) + 1
        defaults.set(count, forKey: Key.promptCount)

        AppAnalytics.shared.trackAppStoreReviewPrompted(trigger: trigger)

        let reviewString = AppSecrets.URLs.appStoreReview
        if !reviewString.isEmpty, let url = URL(string: reviewString) {
            UIApplication.shared.open(url)
            return
        }

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
