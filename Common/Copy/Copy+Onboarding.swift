import Foundation

extension Copy {
    enum Onboarding {

        // MARK: - Snapshot Cards

        static var restingHRLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_resting_hr_label", default: "Resting HR") }
        static var last7NightsLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_last7_nights_label", default: "Last 7 nights") }
        static var noNightsRecorded: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_no_nights_recorded", default: "No nights recorded yet") }
        static var hrvWeeklyAverage: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_hrv_weekly_average", default: "HRV · weekly average") }
        static var notEnoughHRVSamples: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_not_enough_hrv_samples", default: "Not enough HRV samples across the week") }

        // MARK: - Pulse (Screen 1)

        static var pulseHeadline: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_pulse_headline", default: "See what your body has been telling you.") }
        static var pulseBegin: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_pulse_begin", default: "Begin") }

        // MARK: - About You (Screen 2)

        static var aboutTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_title", default: "Start with you") }
        static var aboutSubtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_subtitle", default: "Heart, sleep, and recovery change at every life stage. Yours are yours alone.") }
        static var aboutAgeLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_age_label", default: "Age") }
        static var aboutAgePlaceholder: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_age_placeholder", default: "e.g. 28") }
        static var aboutGenderPrompt: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_gender_prompt", default: "Select gender") }
        static var aboutAgeError: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_age_error", default: "Enter a valid age between 13 and 120.") }
        static var aboutGenderError: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_gender_error", default: "Select a gender to continue.") }
        static var aboutContinue: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_about_continue", default: "Continue") }

        // MARK: - Connect Apple Health (Screen 3)

        static var connectTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_title", default: "Your numbers, made simple.") }
        static var connectSubtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_subtitle", default: "Laso turns your Apple Health history into the story of your body.") }
        static var connectPrivacyNote: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_privacy_note", default: "Stays on your iPhone.") }
        static var connectAllow: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_allow", default: "Connect Apple Health") }
        static var connectUnavailable: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_unavailable", default: "Apple Health is not available on this device.") }
        static var connectContinueAnyway: String { RemoteConfigManager.shared.copyString("copy_onboarding_onboarding_connect_continue_anyway", default: "Continue without Apple Health") }

        static func personalizedConnectNote(age: Int?) -> String? {
            guard let age else { return nil }
            switch age {
            case ..<25:
                return "Starting early means a lifetime of knowing what is normal for your body."
            case 25..<35:
                return "At your age, heart and recovery patterns say a lot about how you are doing."
            case 35..<45:
                return "At your age, watching heart health and recovery really pays off."
            case 45..<55:
                return "At your age, tracking heart, sleep, and mobility shows you important changes."
            default:
                return "Your data will be compared to what is typical for your age."
            }
        }

        // MARK: - Priority (Screen 4)

        static var priorityTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_priority_title", default: "What should Laso look at first?") }
        static var prioritySubtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_priority_subtitle", default: "Your pick shapes the insights you see.") }
        static var priorityContinue: String { RemoteConfigManager.shared.copyString("copy_onboarding_priority_continue", default: "Continue") }

        static func priorityCardSubtitle(for focus: HealthFocus) -> String {
            switch focus {
            case .sleep:       return RemoteConfigManager.shared.copyString("copy_onboarding_priority_card_subtitle_sleep", default: "Overnight recovery and patterns")
            case .fitness:     return RemoteConfigManager.shared.copyString("copy_onboarding_priority_card_subtitle_fitness", default: "Movement, workouts, and effort")
            case .heartHealth: return RemoteConfigManager.shared.copyString("copy_onboarding_priority_card_subtitle_heart_health", default: "Resting rate, HRV, cardio fitness")
            case .weightBody:  return RemoteConfigManager.shared.copyString("copy_onboarding_priority_card_subtitle_weight_body", default: "Trends in body shape and vitals")
            case .recovery:    return RemoteConfigManager.shared.copyString("copy_onboarding_priority_card_subtitle_recovery", default: "How ready your body is each day")
            }
        }

        // MARK: - Mirror Moment (Screen 5)

        static var mirrorCalibratingTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_calibrating_title", default: "Reading your signal") }
        static var mirrorCalibratingMessage: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_calibrating_message", default: "Laso is building your personal baseline from Apple Health. This only happens once.") }
        static var mirrorCompleteTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_complete_title", default: "Here is what I found") }
        static func mirrorCompleteSubtitle(_ span: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_onboarding_mirror_complete_subtitle", default: "%@ of your health, understood."), span)
        }
        static var mirrorNoDataMessage: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_no_data_message", default: "No data yet. Laso will build your baseline as data comes in.") }
        static var mirrorContinue: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_continue", default: "Show me more") }
        static var mirrorRetry: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_retry", default: "Try again") }
        static var mirrorSkip: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_skip", default: "Skip for now") }
        static var mirrorIncomplete: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_incomplete", default: "Still syncing") }

        /// Priority aware, soft pattern observation. Never predicts outcomes.
        static func mirrorObservation(for focuses: Set<HealthFocus>, metricsWithData: Int) -> String? {
            guard metricsWithData > 0 else { return nil }
            if focuses.contains(.heartHealth) || focuses.contains(.recovery) {
                return RemoteConfigManager.shared.copyString("copy_onboarding_mirror_observation_heart", default: "Heart and recovery signals are in. Laso can start finding your rhythms.")
            }
            if focuses.contains(.sleep) {
                return RemoteConfigManager.shared.copyString("copy_onboarding_mirror_observation_sleep", default: "Your sleep history gives Laso a strong signal to work with.")
            }
            if focuses.contains(.fitness) {
                return RemoteConfigManager.shared.copyString("copy_onboarding_mirror_observation_fitness", default: "Activity patterns are in. Laso can see how your body handles effort.")
            }
            if focuses.contains(.weightBody) {
                return RemoteConfigManager.shared.copyString("copy_onboarding_mirror_observation_body", default: "Body measurements will anchor the trends you see over time.")
            }
            return RemoteConfigManager.shared.copyString("copy_onboarding_mirror_observation_default", default: "Your baseline is in. Laso can start finding patterns.")
        }

        static var calibrationReassurance: [String] { RemoteConfigManager.shared.copyArray("copy_onboarding_calibration_reassurance", default: ["Reading your Apple Watch history", "Finding patterns in your heart rate", "Looking at sleep cycles", "Building your personal baseline", "Large histories take a moment", "Almost there"]) }

        // MARK: - Promise (Screen 6)

        static var promiseTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_promise_title", default: "Your first 7 days") }
        static func promiseBody(patternCount: Int, span: String?) -> String {
            let unit = patternCount == 1
                ? RemoteConfigManager.shared.copyString("copy_onboarding_promise_pattern_singular", default: "pattern")
                : RemoteConfigManager.shared.copyString("copy_onboarding_promise_pattern_plural", default: "patterns")
            if let span {
                return String(format: RemoteConfigManager.shared.copyString("copy_onboarding_promise_body_with_span", default: "Laso will surface %d %@ from your %@ of history."), patternCount, unit, span)
            }
            return String(format: RemoteConfigManager.shared.copyString("copy_onboarding_promise_body_no_span", default: "Laso will surface %d %@ from your health data."), patternCount, unit)
        }
        static var promiseFallback: String { RemoteConfigManager.shared.copyString("copy_onboarding_promise_fallback", default: "Laso will start building your baseline as data comes in.") }
        static var promiseSignInHelper: String { RemoteConfigManager.shared.copyString("copy_onboarding_promise_sign_in_helper", default: "We use Apple Sign In so your subscription stays with you across devices.") }
        static var promiseDisclaimerFooter: String { RemoteConfigManager.shared.copyString("copy_onboarding_promise_disclaimer_footer", default: "Not a medical device. Laso is for information, not diagnosis.") }
        static var promiseDisclaimerLearnMore: String { RemoteConfigManager.shared.copyString("copy_onboarding_promise_disclaimer_learn_more", default: "Full disclaimer") }

        // MARK: - Trial (Screen 7)

        static var trialTitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_trial_title", default: "Start your 7-day free trial") }
        static var trialSubtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_trial_subtitle", default: "Full access to insights, alerts, and trends. Cancel any time in Settings before day 7.") }
        static var trialCTA: String { RemoteConfigManager.shared.copyString("copy_onboarding_trial_cta", default: "Start 7-day Free Trial") }
        static var trialFooterNote: String { RemoteConfigManager.shared.copyString("copy_onboarding_trial_footer_note", default: "No charge today. Apple will remind you before your trial ends.") }

        // MARK: - Siri tip

        static var worksWithSiri: String { RemoteConfigManager.shared.copyString("copy_onboarding_works_with_siri", default: "Works with Siri") }
        static var siriTip: String { RemoteConfigManager.shared.copyString("copy_onboarding_siri_tip", default: "Try saying \"Hey Siri, what's my health score in Laso\"") }

        // MARK: - Mirror Moment Calibration

        static var mirrorStartingCalibration: String { RemoteConfigManager.shared.copyString("copy_onboarding_mirror_starting_calibration", default: "Starting calibration\u{2026}") }

        // MARK: - Referral Code Step

        enum ReferralCode {
            static var brand: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_brand", default: "Laso") }
            static var title: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_title", default: "Have a Referral Code?") }
            static var subtitle: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_subtitle", default: "If a friend shared their code with you, enter it below. You\u{2019}ll both get 1 free month of Pro when you subscribe.") }
            static var fieldLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_field_label", default: "Referral Code") }
            static var fieldPlaceholder: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_field_placeholder", default: "e.g. HEALTH-A7X3K2") }
            static var verifying: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_verifying", default: "Verifying code\u{2026}") }
            static var apply: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_apply", default: "Apply Code") }
            static var skip: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_skip", default: "Skip") }
            static var codeApplied: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_code_applied", default: "Code applied! Subscribe to unlock your free month.") }
            static var emptyCodeError: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_empty_code_error", default: "Please enter a referral code.") }
            static var invalidCodeFallback: String { RemoteConfigManager.shared.copyString("copy_onboarding_referral_code_invalid_code_fallback", default: "Invalid code.") }
        }

        // MARK: - Lifted view literals
        static var savesYourSelectedFocusAreasAndHint: String { RemoteConfigManager.shared.copyString("copy_onboarding_saves_your_selected_focus_areas_and_hint", default: "Saves your selected focus areas and continues onboarding") }
        static var x: String { RemoteConfigManager.shared.copyString("copy_onboarding_x", default: "—") }
        static var noDataYet: String { RemoteConfigManager.shared.copyString("copy_onboarding_no_data_yet", default: "no data yet") }
        static var h: String { RemoteConfigManager.shared.copyString("copy_onboarding_h", default: "h") }
        static var m: String { RemoteConfigManager.shared.copyString("copy_onboarding_m", default: "m") }
        static var ms: String { RemoteConfigManager.shared.copyString("copy_onboarding_ms", default: "ms") }
        static var pct: String { RemoteConfigManager.shared.copyString("copy_onboarding_pct", default: "%") }
        static var x2: String { RemoteConfigManager.shared.copyString("copy_onboarding_x2", default: "—") }
        static var target7h: String { RemoteConfigManager.shared.copyString("copy_onboarding_target7h", default: "target 7h") }
        static var noDataYet2: String { RemoteConfigManager.shared.copyString("copy_onboarding_no_data_yet2", default: "no data yet") }
        static var genderLabel: String { RemoteConfigManager.shared.copyString("copy_onboarding_gender_label", default: "Gender") }
        static var chooseYourGenderForPersonalizedAnalysisHint: String { RemoteConfigManager.shared.copyString("copy_onboarding_choose_your_gender_for_personalized_analysis_hint", default: "Choose your gender for personalized analysis") }
        static var savesYourAgeAndGenderAndHint: String { RemoteConfigManager.shared.copyString("copy_onboarding_saves_your_age_and_gender_and_hint", default: "Saves your age and gender and continues onboarding") }
        static var years: String { RemoteConfigManager.shared.copyString("copy_onboarding_years", default: "years") }
        static var startsTheOnboardingFlowHint: String { RemoteConfigManager.shared.copyString("copy_onboarding_starts_the_onboarding_flow_hint", default: "Starts the onboarding flow") }

        // MARK: - Lifted interpolated view literals
        static func togglesAsAFocusAreaHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_toggles_as_a_focus_area_hint", default: "Toggles %@ as a focus area"), p0) }
        static func hMText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_h_m_text", default: "%dh %dm"), p0, p1) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_x_text", default: "%d"), p0) }
        static func progressStepText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_progress_step_text", default: "%d / %d"), p0, p1) }
        static func ofMetricsSyncedText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_of_metrics_synced_text", default: "%d of %d metrics synced"), p0, p1) }
        static func dataPointsFoundText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_data_points_found_text", default: "%@ data points found"), p0) }
        static func xText2(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_onboarding_x_text2", default: "%@: **%@**"), p0, p1) }
    }
}
