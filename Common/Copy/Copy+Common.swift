import Foundation

extension Copy {
    enum Common {

        // MARK: - Shared UI Tokens

        static var notEnoughData: String { RemoteConfigManager.shared.copyString("copy_common_common_not_enough_data", default: "Not enough data yet") }
        static var avg: String { RemoteConfigManager.shared.copyString("copy_common_common_avg", default: "Avg") }
        static var thisWeek: String { RemoteConfigManager.shared.copyString("copy_common_common_this_week", default: "This Week") }
        static var lastWeek: String { RemoteConfigManager.shared.copyString("copy_common_common_last_week", default: "Last Week") }
        static var improved: String { RemoteConfigManager.shared.copyString("copy_common_common_improved", default: "Improved") }
        static var increased: String { RemoteConfigManager.shared.copyString("copy_common_common_increased", default: "Increased") }

        // MARK: - Trend Cards

        enum Trend {
            static var sectionTitle: String { RemoteConfigManager.shared.copyString("copy_common_trend_section_title", default: "Trends") }
            static var inUsualRange: String { RemoteConfigManager.shared.copyString("copy_common_trend_in_usual_range", default: "In your usual range") }
            static var aboveUsual: String { RemoteConfigManager.shared.copyString("copy_common_trend_above_usual", default: "Above your usual") }
            static var belowUsual: String { RemoteConfigManager.shared.copyString("copy_common_trend_below_usual", default: "Below your usual") }
            static var buildingUsualRange: String { RemoteConfigManager.shared.copyString("copy_common_trend_building_usual_range", default: "Learning your usual range") }

            static func accessibilityValue(value: String, status: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_common_trend_a11y_value", default: "%@, %@"), value, status)
            }
        }

        // MARK: - Metric Verdict

        enum Verdict {
            static var belowNormal: String { RemoteConfigManager.shared.copyString("copy_common_verdict_below_normal", default: "Below normal") }
            static var normal: String { RemoteConfigManager.shared.copyString("copy_common_verdict_normal", default: "Normal range") }
            static var aboveNormal: String { RemoteConfigManager.shared.copyString("copy_common_verdict_above_normal", default: "Above normal") }

            static func yourUsualRange(_ low: String, _ high: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_common_verdict_your_usual_range", default: "Your usual range %@ to %@"), low, high)
            }

            static func typicalRange(_ low: String, _ high: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_common_verdict_typical_range", default: "Typical range %@ to %@"), low, high)
            }
        }

        // MARK: - Shared Accessibility Labels

        static var sendingFeedback: String { RemoteConfigManager.shared.copyString("copy_common_common_sending_feedback", default: "Sending feedback") }
        static var quickQuestion: String { RemoteConfigManager.shared.copyString("copy_common_common_quick_question", default: "Quick question") }
        static var shareHealthCard: String { RemoteConfigManager.shared.copyString("copy_common_common_share_health_card", default: "Share health card") }

        // MARK: - Lifted view literals
        static var healthScore: String { RemoteConfigManager.shared.copyString("copy_common_health_score", default: "Health Score") }
        static var lastNightSSleep: String { RemoteConfigManager.shared.copyString("copy_common_last_night_s_sleep", default: "Last Night's Sleep") }
        static var readiness: String { RemoteConfigManager.shared.copyString("copy_common_readiness", default: "Readiness") }
        static var recoveryStatus: String { RemoteConfigManager.shared.copyString("copy_common_recovery_status", default: "Recovery Status") }
        static var waterLogged: String { RemoteConfigManager.shared.copyString("copy_common_water_logged", default: "Water Logged") }
        static var savedToAppleHealth: String { RemoteConfigManager.shared.copyString("copy_common_saved_to_apple_health", default: "Saved to Apple Health") }
        static var savedToAppleHealth2: String { RemoteConfigManager.shared.copyString("copy_common_saved_to_apple_health2", default: "Saved to Apple Health") }
        static var riskDataUnavailableTitle: String { RemoteConfigManager.shared.copyString("copy_common_risk_data_unavailable_title", default: "Risk data unavailable") }
        static var thisHealthRiskAssessmentIsNo: String { RemoteConfigManager.shared.copyString("copy_common_this_health_risk_assessment_is_no", default: "This health risk assessment is no longer available. Pull to refresh your data.") }
        static var buildingYourSleepProfile: String { RemoteConfigManager.shared.copyString("copy_common_building_your_sleep_profile", default: "Building your sleep profile") }
        static var weNeedAFewNightsOf: String { RemoteConfigManager.shared.copyString("copy_common_we_need_a_few_nights_of", default: "We need a few nights of overnight sleep data from your Apple Watch to learn your normal range. Wear your watch to bed and your sleep coach will appear here.") }
        static var whileYouWait: String { RemoteConfigManager.shared.copyString("copy_common_while_you_wait", default: "While you wait") }
        static var updateYourPaymentMethodToKeep: String { RemoteConfigManager.shared.copyString("copy_common_update_your_payment_method_to_keep", default: "Update your payment method to keep your subscription active.") }
        static var underMaintenance: String { RemoteConfigManager.shared.copyString("copy_common_under_maintenance", default: "Under Maintenance") }
        static var x: String { RemoteConfigManager.shared.copyString("copy_common_x", default: "·") }
        static var laso: String { RemoteConfigManager.shared.copyString("copy_common_laso", default: "Laso") }
        static var trackYourHealthWithLaso: String { RemoteConfigManager.shared.copyString("copy_common_track_your_health_with_laso", default: "Track your health with Laso") }

        // Photo share card
        static var shareCardFooter: String { RemoteConfigManager.shared.copyString("copy_common_share_card_footer", default: "laso.fit") }
        static var shareAddPhoto: String { RemoteConfigManager.shared.copyString("copy_common_share_add_photo", default: "Add your photo") }
        static var shareTakePhoto: String { RemoteConfigManager.shared.copyString("copy_common_share_take_photo", default: "Take a photo") }
        static var shareChangePhoto: String { RemoteConfigManager.shared.copyString("copy_common_share_change_photo", default: "Change photo") }
        static var shareCTA: String { RemoteConfigManager.shared.copyString("copy_common_share_cta", default: "Share") }
        static var shareSheetTitle: String { RemoteConfigManager.shared.copyString("copy_common_share_sheet_title", default: "Share a win") }
        static var shareTrayHint: String { RemoteConfigManager.shared.copyString("copy_common_share_tray_hint", default: "Pick a win, then add your photo.") }

        // Shown when no template qualifies. The tray is deliberately empty
        // rather than filled with a number the user would not want to post.
        static var shareEmptyTitle: String { RemoteConfigManager.shared.copyString("copy_common_share_empty_title", default: "Nothing to share yet") }
        static var shareEmptyBody: String { RemoteConfigManager.shared.copyString("copy_common_share_empty_body", default: "Laso only makes a card when you have a real win. Keep going and one will turn up here.") }

        // Share templates. Each one is only built when its number reads as a win.
        static var shareChipYounger: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_younger", default: "Younger") }
        static var shareChipStreak: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_streak", default: "Streak") }
        static var shareChipProof: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_proof", default: "Proof") }
        static var shareChipBestSleep: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_best_sleep", default: "Best sleep") }
        static var shareChipToday: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_today", default: "Today") }

        // Rings template labels
        static var shareRingVitalityAge: String { RemoteConfigManager.shared.copyString("copy_common_share_ring_vitality_age", default: "VITALITY AGE") }
        static var shareRingRecovery: String { RemoteConfigManager.shared.copyString("copy_common_share_ring_recovery", default: "RECOVERY") }
        static var shareRingSleep: String { RemoteConfigManager.shared.copyString("copy_common_share_ring_sleep", default: "HOURS OF SLEEP") }

        static func shareYoungerAccent(years: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_younger_accent", default: "%d years"), years)
        }
        static var shareYoungerPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_younger_plain", default: "younger") }
        static func shareYoungerSub(realAge: Int, vitalityAge: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_younger_sub", default: "%1$d on paper. %2$d in the body."), realAge, vitalityAge)
        }

        static func shareStreakAccent(days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_streak_accent", default: "%d days"), days)
        }
        static var shareStreakPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_streak_plain", default: "in a row") }
        static var shareStreakSub: String { RemoteConfigManager.shared.copyString("copy_common_share_streak_sub", default: "Sleep, movement and recovery. Every one.") }

        static func shareProofAccent(delta: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_proof_accent", default: "+%d"), delta)
        }
        static var shareProofPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_proof_plain", default: "recovery") }
        static func shareProofSub(action: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_proof_sub", default: "Yesterday: %@. That is what it did."), action)
        }

        static var shareBestSleepPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_best_sleep_plain", default: "best sleep yet") }
        static var shareBestSleepSub: String { RemoteConfigManager.shared.copyString("copy_common_share_best_sleep_sub", default: "My longest night since I started tracking.") }

        // Everyday cards. These need no win, only the reading to exist, so the
        // tray is never down to a single option on an ordinary day.
        static var shareChipRecovery: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_recovery", default: "Recovery") }
        static var shareChipSleep: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_sleep", default: "Sleep") }
        static var shareChipAge: String { RemoteConfigManager.shared.copyString("copy_common_share_chip_age", default: "Body age") }

        static func shareRecoveryAccent(score: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_recovery_accent", default: "%d"), score)
        }
        static var shareRecoveryPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_recovery_plain", default: "recovery today") }
        static var shareRecoverySubPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_recovery_sub_plain", default: "Read against my own baseline, not an average.") }

        static var shareSleepPlain: String { RemoteConfigManager.shared.copyString("copy_common_share_sleep_plain", default: "asleep last night") }
        static var shareSleepSub: String { RemoteConfigManager.shared.copyString("copy_common_share_sleep_sub", default: "Tracked start to finish, not guessed.") }

        static func shareAgeAccent(age: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_age_accent", default: "%d"), age)
        }
        static var shareAgePlain: String { RemoteConfigManager.shared.copyString("copy_common_share_age_plain", default: "is my body age") }
        static func shareAgeSub(realAge: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_common_share_age_sub", default: "%d on paper."), realAge)
        }
        static var laso2: String { RemoteConfigManager.shared.copyString("copy_common_laso2", default: "Laso") }
        static var discoverYourHealthPatternsWithLaso: String { RemoteConfigManager.shared.copyString("copy_common_discover_your_health_patterns_with_laso", default: "Discover your health patterns with Laso") }
        static var hidesThisBannerWithoutChangingNotificationHint: String { RemoteConfigManager.shared.copyString("copy_common_hides_this_banner_without_changing_notification_hint", default: "Hides this banner without changing notification settings") }
        static var opensTheSystemSettingsAppToHint: String { RemoteConfigManager.shared.copyString("copy_common_opens_the_system_settings_app_to_hint", default: "Opens the system Settings app to enable notifications") }
        static var updateRequired: String { RemoteConfigManager.shared.copyString("copy_common_update_required", default: "Update Required") }
        static var aNewVersionOfLasoIs: String { RemoteConfigManager.shared.copyString("copy_common_a_new_version_of_laso_is", default: "A new version of Laso is available with important fixes. Please update to continue.") }
        static var updateNow: String { RemoteConfigManager.shared.copyString("copy_common_update_now", default: "Update Now") }
        static var skipButton: String { RemoteConfigManager.shared.copyString("copy_common_skip_button", default: "Skip") }
        static var howWouldYouFeelIfYou: String { RemoteConfigManager.shared.copyString("copy_common_how_would_you_feel_if_you", default: "How would you feel if you could no longer use Laso?") }
        static var whatTypeOfPersonDoYou: String { RemoteConfigManager.shared.copyString("copy_common_what_type_of_person_do_you", default: "What made you want to use Laso?") }
        static var continueLabel: String { RemoteConfigManager.shared.copyString("copy_common_continue", default: "Continue") }
        static var whatIsTheMainBenefitYou: String { RemoteConfigManager.shared.copyString("copy_common_what_is_the_main_benefit_you", default: "What is the main benefit you get from Laso?") }
        static var continueLabel2: String { RemoteConfigManager.shared.copyString("copy_common_continue2", default: "Continue") }
        static var howCanWeImproveLasoFor: String { RemoteConfigManager.shared.copyString("copy_common_how_can_we_improve_laso_for", default: "How can we improve Laso for you?") }
        static var pmfSegmentPlaceholder: String { RemoteConfigManager.shared.copyString("copy_common_pmf_segment_placeholder", default: "e.g., fitness enthusiast, someone with a chronic condition...") }
        static var pmfBenefitPlaceholder: String { RemoteConfigManager.shared.copyString("copy_common_pmf_benefit_placeholder", default: "e.g., understanding my recovery, sleep insights...") }
        static var pmfImprovementPlaceholder: String { RemoteConfigManager.shared.copyString("copy_common_pmf_improvement_placeholder", default: "Optional — anything you'd change or add") }
        static var submitButton: String { RemoteConfigManager.shared.copyString("copy_common_submit_button", default: "Submit") }
        static var thankYou: String { RemoteConfigManager.shared.copyString("copy_common_thank_you", default: "Thank you") }
        static var yourFeedbackShapesWhatWeBuild: String { RemoteConfigManager.shared.copyString("copy_common_your_feedback_shapes_what_we_build", default: "Your feedback shapes what we build next.") }
        static var doneButton: String { RemoteConfigManager.shared.copyString("copy_common_done_button", default: "Done") }
        static var atLeast2DataPointsNeeded: String { RemoteConfigManager.shared.copyString("copy_common_at_least2_data_points_needed", default: "At least 2 data points needed") }
        static var baseline: String { RemoteConfigManager.shared.copyString("copy_common_baseline", default: "Baseline") }
        static var hidesThisBannerWithoutChangingHealthHint: String { RemoteConfigManager.shared.copyString("copy_common_hides_this_banner_without_changing_health_hint", default: "Hides this banner without changing Health app settings") }
        static var whatIsThisAbout: String { RemoteConfigManager.shared.copyString("copy_common_what_is_this_about", default: "What is this about?") }
        static var yourEmail: String { RemoteConfigManager.shared.copyString("copy_common_your_email", default: "Your email") }
        static var rendersThisCardAndOpensTheHint: String { RemoteConfigManager.shared.copyString("copy_common_renders_this_card_and_opens_the_hint", default: "Renders this card and opens the share sheet") }
        static var securityCheckFailed: String { RemoteConfigManager.shared.copyString("copy_common_security_check_failed", default: "Security Check Failed") }
        static var thisAppCannotRunOnA: String { RemoteConfigManager.shared.copyString("copy_common_this_app_cannot_run_on_a", default: "This app cannot run on a modified device. Your health data security cannot be guaranteed in this environment.") }
        static var ifYouBelieveThisIsAn: String { RemoteConfigManager.shared.copyString("copy_common_if_you_believe_this_is_an", default: "If you believe this is an error, please reinstall the app from the App Store.") }
        static var acknowledgesTheMedicalDisclaimerAndContinuesHint: String { RemoteConfigManager.shared.copyString("copy_common_acknowledges_the_medical_disclaimer_and_continues_hint", default: "Acknowledges the medical disclaimer and continues into the app") }
        static var pro: String { RemoteConfigManager.shared.copyString("copy_common_pro", default: "PRO") }
        static var unlockTheFullSetWithA: String { RemoteConfigManager.shared.copyString("copy_common_unlock_the_full_set_with_a", default: "Unlock the full set with a Pro subscription.") }
        static var pmfVeryDisappointed: String { RemoteConfigManager.shared.copyString("copy_common_pmf_very_disappointed", default: "Very disappointed") }
        static var pmfSomewhatDisappointed: String { RemoteConfigManager.shared.copyString("copy_common_pmf_somewhat_disappointed", default: "Somewhat disappointed") }
        static var pmfNotDisappointed: String { RemoteConfigManager.shared.copyString("copy_common_pmf_not_disappointed", default: "Not disappointed") }

        // MARK: - Lifted interpolated view literals
        static func activeText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_active_text", default: "%d active"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x_text", default: "%d"), p0) }
        static func metricsLabel(_ p0: Int, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_metrics_label", default: "%d metrics %@"), p0, p1) }
        static func xText2(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x_text2", default: "%@ %@"), p0, p1) }
        static func intentReadinessScoreText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_intent_readiness_score_text", default: "%d"), p0) }
        static func xLabel(_ p0: String, _ p1: String, _ p2: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x_label", default: "%@, %@ %@"), p0, p1, p2) }
        static func riskTypeAndGradeLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_risk_type_and_grade_label", default: "%@, %@"), p0, p1) }
        static func viewDetailsHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_view_details_hint", default: "View %@ details"), p0) }
        static func xLabel2(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x_label2", default: "%@, %@"), p0, p1) }
        static func xLabel3(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x_label3", default: "%@: %@"), p0, p1) }
        static func loggedText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_logged_text", default: "%@ Logged"), p0) }
        static func switchToTabHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_switch_to_tab_hint", default: "Switch to %@ tab"), p0) }
        static func dayStreakText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_day_streak_text", default: "%d-day streak"), p0) }
        static func x10100Text(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_x10100_text", default: "%d%%"), p0) }
        static func percentValue(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_percent_value", default: "%d percent"), p0) }
        static func errorText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_error_text", default: "Error: %@"), p0) }
        static func viaText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_via_text", default: "via %@"), p0) }
        static func opensTheSubscriptionPaywallToHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_common_opens_the_subscription_paywall_to_hint", default: "Opens the subscription paywall to unlock %@"), p0) }
    }
}
