import Foundation

extension Copy {
    enum WakeAnchor {

        // MARK: - Section

        static var setAction: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_set_action", default: "Set") }

        // MARK: - Onboarding ask

        static var onboardingEyebrow: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_eyebrow", default: "ONE THING TO KEEP") }

        /// "You usually wake around 7:00 AM."
        static func onboardingUsually(_ time: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_usually", default: "You usually wake around %@."), time)
        }

        static var onboardingBody: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_body", default: "Keep this as your wake time and we move your bedtime instead. Steady mornings do more for sleep than any single early night.") }

        static var onboardingConfirm: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_confirm", default: "Keep this wake time") }
        static var onboardingKept: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_kept", default: "Wake time set. You can change it any time in Sleep Coach.") }
    }
}
