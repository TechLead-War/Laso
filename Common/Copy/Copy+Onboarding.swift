import Foundation

extension Copy {
    enum Onboarding {

        // MARK: - Snapshot Cards

        static var restingHRLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_resting_hr_label", default: "Resting HR") }
        static var last7NightsLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_last7_nights_label", default: "Last 7 nights") }
        static var noNightsRecorded: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_no_nights_recorded", default: "No nights recorded yet") }
        static var hrvWeeklyAverage: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_hrv_weekly_average", default: "HRV · weekly average") }
        static var notEnoughHRVSamples: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_not_enough_hrv_samples", default: "Not enough HRV samples across the week") }

        // MARK: - About You (Screen 2)

        // MARK: - Mirror Moment (Screen 5)

        // MARK: - Referral Code Step

        enum ReferralCode {
            static var brand: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_brand", default: "Laso") }
            static var title: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_title", default: "Have a Referral Code?") }
            static var subtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_subtitle", default: "If a friend shared their code with you, enter it below. You both get 1 free month of Pro when Laso goes paid.") }
            static var fieldLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_field_label", default: "Referral Code") }
            static var fieldPlaceholder: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_field_placeholder", default: "e.g. LASO-A7X3K2") }
            static var verifying: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_verifying", default: "Verifying code\u{2026}") }
            static var apply: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_apply", default: "Apply Code") }
            static var skip: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_skip", default: "Skip") }
            static var codeApplied: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_code_applied", default: "Code applied! You both get a free month of Pro.") }
            static var emptyCodeError: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_empty_code_error", default: "Please enter a referral code.") }
            static var invalidCodeFallback: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_invalid_code_fallback", default: "Invalid code.") }
        }

        // MARK: - Lifted view literals
        static var x: String { RemoteConfigManager.shared.copyString("copy_onboarding_x", default: "—") }
        static var noDataYet: String { RemoteConfigManager.shared.copyString("copy_onboarding_no_data_yet", default: "no data yet") }
        static var h: String { RemoteConfigManager.shared.copyString("copy_onboarding_h", default: "h") }
        static var m: String { RemoteConfigManager.shared.copyString("copy_onboarding_m", default: "m") }
        static var ms: String { RemoteConfigManager.shared.copyString("copy_onboarding_ms", default: "ms") }
        static var x2: String { RemoteConfigManager.shared.copyString("copy_onboarding_x2", default: "—") }
        static var target7h: String { RemoteConfigManager.shared.copyString("copy_onboarding_target7h", default: "target 7h") }
        static var noDataYet2: String { RemoteConfigManager.shared.copyString("copy_onboarding_no_data_yet2", default: "no data yet") }
        static var years: String { RemoteConfigManager.shared.copyString("copy_onboarding_years", default: "years") }

        // MARK: - Lifted interpolated view literals
        static func hMText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_h_m_text", default: "%dh %dm"), p0, p1) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_x_text", default: "%d"), p0) }
        static func progressStepText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_progress_step_text", default: "%d / %d"), p0, p1) }
    }
}
