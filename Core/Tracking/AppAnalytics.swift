import Foundation
import UIKit
import CryptoKit

/// All trackable screens in the app.
enum AppFeature: String, Hashable {
    case home
    case live
    case explore
    case categoryDetail = "category_detail"
    case metricDetail = "metric_detail"
    case riskDetail = "risk_detail"
    case settings
    case connectedDevices = "connected_devices"
    case deviceDetail = "device_detail"
    case insightsDetail = "insights_detail"
    case correlations
    case feedback
    case onboarding
    case weeklyReview = "weekly_review"
    case metricAlertPicker = "metric_alert_picker"
    case paywall
    case discovery
    case scoreGuide = "score_guide"
    case recoveryInfo = "recovery_info"
    case simulation
    case healthStateTimeline = "health_state_timeline"
    case metricLog = "metric_log"
    case proOverlay = "pro_overlay"
    case achievements
    case inviteFriends = "invite_friends"
    case performanceProfile = "performance_profile"
    case journalEntry = "journal_entry"
    case expandedJournal = "expanded_journal"
    case journalInsights = "journal_insights"
    case annualReport = "annual_report"
    case monthlyReview = "monthly_review"
    case sleepCoach = "sleep_coach"
    case breathwork
    case stressMonitor = "stress_monitor"
    case strainDetail = "strain_detail"
    case vitalityDetail = "vitality_detail"
    case brainHealth = "brain_health"
    case cycleDetail = "cycle_detail"
    case deviceSetupGuide = "device_setup_guide"
    case todaysActionDetail = "todays_action_detail"
    case askYourData = "ask_your_data"
    case notificationsSettings = "notifications_settings"
    case exploreDaySheet = "explore_day_sheet"
    case mirrorCapture = "mirror_capture"
}

/// Actionable block/card types. only user-initiated taps and meaningful interactions.
enum BlockType: String {
    // Home. user taps
    case sleepCard = "sleep_card"
    case smartAction = "smart_action"
    case headlineInsight = "headline_insight"
    case seeAllInsights = "see_all_insights"
    case seeAllNeedsAttention = "see_all_needs_attention"
    case seeAllCorrelations = "see_all_correlations"
    case weeklyReviewCard = "weekly_review_card"
    case emptyStateManageDevices = "empty_state_manage_devices"
    case emptyStateRefresh = "empty_state_refresh"
    case errorRetry = "error_retry"

    // Live. user taps
    case heartRateHeroCard = "heart_rate_hero_card"
    case vitalCardSpo2 = "vital_card_spo2"
    case vitalCardRespRate = "vital_card_resp_rate"
    case activityRingsSection = "activity_rings_section"
    case quickStatSteps = "quick_stat_steps"
    case quickStatDistance = "quick_stat_distance"
    case quickStatFlights = "quick_stat_flights"
    case bloodPressureCard = "blood_pressure_card"
    case temperatureCard = "temperature_card"
    case lastWorkoutCard = "last_workout_card"

    // Explore. user taps
    case categoryRow = "category_row"
    case healthScoreHero = "health_score_hero"
    case focusBanner = "focus_banner"

    // Category Detail. user taps
    case metricRow = "metric_row"

    // Devices. user taps
    case manageDevices = "manage_devices"
    case deviceRow = "device_row"
    case unconnectedDeviceRow = "unconnected_device_row"
    case appStoreLink = "app_store_link"

    // Settings. user taps
    case exportReport = "export_report"
    case settingsDoneButton = "settings_done_button"
    case metricAlertsPicker = "metric_alerts_picker"

    // Filters. user taps
    case trendFilter = "trend_filter"
    case periodSelector = "period_selector"
    case correlationFilterChip = "correlation_filter_chip"
    case correlationsExpandAll = "correlations_expand_all"

    // Chart. user taps
    case chartTouch = "chart_touch"
    case chartDrag = "chart_drag"

    // Data Sync
    case dataSyncEvent = "data_sync_event"

    // Feedback. user taps
    case feedbackCategory = "feedback_category"
    case feedbackSubmit = "feedback_submit"
    case feedbackSkip = "feedback_skip"
    case feedbackDoneAfterSubmit = "feedback_done_after_submit"

    // Help & Support. user taps from Settings
    case rateAppStore = "rate_app_store"
    case reportBug = "report_bug"
    case contactSupport = "contact_support"
    case updateApp = "update_app"

    // Onboarding. user taps
    case onboardingConnectHealth = "onboarding_connect_health"
    case onboardingContinueAnyway = "onboarding_continue_anyway"
    case onboardingFocusChip = "onboarding_focus_chip"
    case onboardingGetStarted = "onboarding_get_started"
    case onboardingCultureContinue = "onboarding_culture_continue"
    case onboardingCalibrationRetry = "onboarding_calibration_retry"
    case onboardingCalibrationSkip = "onboarding_calibration_skip"
    case onboardingProfileContinue = "onboarding_profile_continue"
    case onboardingProfileSkip = "onboarding_profile_skip"
    case onboardingNotifications = "onboarding_notifications"
    case scoreGuideGotIt = "score_guide_got_it"

    // Daily Mirror. user taps
    case mirrorCaptureStarted = "mirror_capture_started"
    case mirrorPhotoSaved = "mirror_photo_saved"
    case mirrorPhotoOpened = "mirror_photo_opened"
    case mirrorArchiveDeleted = "mirror_archive_deleted"

    // Navigation
    case tabHome = "tab_home"
    case tabLive = "tab_live"
    case tabExplore = "tab_explore"
    case tabSettings = "tab_settings"

    // Discovery
    case discoveryContinue = "discovery_continue"

    // Score/Recovery sheets
    case scoreGuideClose = "score_guide_close"
    case recoveryInfoDone = "recovery_info_done"

    // Explore extras
    case exploreScoreInfo = "explore_score_info"
    case exploreSimulationTeaser = "explore_simulation_teaser"
    case exploreHealthStateTeaser = "explore_health_state_teaser"
    case exploreNeedsAttentionMetric = "explore_needs_attention_metric"
    case exploreWeakCategory = "explore_weak_category"
    case exploreDecliningMetric = "explore_declining_metric"
    case exploreSeeAllCorrelations = "explore_see_all_correlations"
    case exploreCorrelationPreview = "explore_correlation_preview"
    case exploreTrendMetric = "explore_trend_metric"
    case exploreCalendarDay = "explore_calendar_day"
    case exploreCalendarMonthStep = "explore_calendar_month_step"
    case exploreCalendarToday = "explore_calendar_today"

    // Home extras
    case homeRiskRow = "home_risk_row"
    case homeRecoveryInfoButton = "home_recovery_info_button"
    case homeDailyAction = "home_daily_action"
    case homeBrainHealthCard = "home_brain_health_card"
    case shareCard = "share_card"

    // Live
    case staleWatchPrompt = "stale_watch_prompt"

    // Simulation
    case simulationDone = "simulation_done"
    case simulationReset = "simulation_reset"
    case simulationRecommendation = "simulation_recommendation"

    // Health State
    case healthStatePrevMonth = "health_state_prev_month"
    case healthStateNextMonth = "health_state_next_month"

    // Metric Log
    case metricLogCancel = "metric_log_cancel"
    case metricLogSave = "metric_log_save"
    case metricLogQuickAmount = "metric_log_quick_amount"
    case metricLogOpen = "metric_log_open"

    // Paywall
    case paywallPlanYearly = "paywall_plan_yearly"
    case paywallPlanMonthly = "paywall_plan_monthly"
    case paywallSubscribe = "paywall_subscribe"
    case paywallRestore = "paywall_restore"
    case paywallRetryPlans = "paywall_retry_plans"
    case paywallTermsLink = "paywall_terms_link"
    case paywallPrivacyLink = "paywall_privacy_link"
    case proUpgradeButton = "pro_upgrade_button"

    // Explore sections
    case exploreCategoryRow = "explore_category_row"
    case exploreHealthStateLink = "explore_health_state_link"
    case exploreTrendTimeframeChanged = "explore_trend_timeframe_changed"

    // Journal
    case journalCategorySelected = "journal_category_selected"
    case journalEntrySaved = "journal_entry_saved"
    case journalEntryCancelled = "journal_entry_cancelled"

    // Achievements
    case achievementCategoryFilter = "achievement_category_filter"

    // Siri Shortcuts
    case siriShortcutPerformed = "siri_shortcut_performed"
    case siriShortcutsLink = "siri_shortcuts_link"
    case siriTip = "siri_tip"

    // Settings rows that leave the screen. Each was previously untracked, so a
    // push into Notifications, Acknowledgements or Siri was invisible and the
    // destination screens had no denominator.
    case settingsNotifications = "settings_notifications"
    case settingsTermsLink = "settings_terms_link"
    case settingsAcknowledgements = "settings_acknowledgements"
    case settingsSiri = "settings_siri"
    case settingsDeleteData = "settings_delete_data"
    case acknowledgementSourceLink = "acknowledgement_source_link"

    // Sheet dismissals and value entry
    case briefingDetailDone = "briefing_detail_done"
    case valueInputAdjusted = "value_input_adjusted"
    case workoutPlanDone = "workout_plan_done"
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference. 5 Product Questions
// ──────────────────────────────────────────────────────────────────────────────
//
// NORTH-STAR METRICS:
//   1. Activation rate           → onboarding_completed → activation_completed
//   2. Time to first value       → time_to_first_value / first_score_generated
//   3. D1 / D7 / D30 retention  → retention_milestone
//   4. Trial-to-paid conversion  → subscription_renewed (trial_converted=yes)
//   5. Churn                     → subscription_cancelled / inactive_period_detected
//
// ─── Q1: WHO GETS VALUE? ────────────────────────────────────────────────────
//  onboarding_completed          focuses, focus_count, duration_sec  Setup completion
//  onboarding_step_completed     step_key, step_index, step_count, duration_sec, action  Drop-off funnel
//  onboarding_drop_off           last_step, step_index, step_count, duration_sec  Where they quit
//  activation_milestone          milestone, time_since_install       Which features click
//  activation_completed          milestones_completed, days_to_activate  Aha moment reached
//  time_to_first_value           seconds                             Speed to value (once per install)
//  first_score_generated         score, time_since_install_sec       First real output
//  health_permission_requested   metrics_requested                   Permission funnel start
//  health_permission_result      granted (0/1), granted_count, denied, grant_rate  Permission success
//  source_connected              source_type, metrics_available      Wearable onboarded
//  data_pipeline_quality         coverage, enough_for_score          Data readiness
//  empty_state_shown             screen, reason                      Blocked from value
//  day1_data_richness_segment    segment                             Day-1 data branch (rich/sparse/denied)
//  verdict_delivered             zone, magnitude_band, nights_remaining  Instant verdict payoff
//  promise_shown                 branch, nights_remaining            Sparse/denied promise screen
//  repermission_conversion       (none)                              Health access after re-permission push
//  first_checkin_done            (none)                              Denied-branch first value moment
//
// ─── Q2: WHO COMES BACK? ────────────────────────────────────────────────────
//  session_started               day_of_week (rest ride as globals)  When & how they open
//  session_ended                 duration_sec, active_sec, screens_viewed, max_depth, session_source  Session quality
//  return_session                session_number, days_since_last     Return cadence
//  daily_active                  session_source, weekly_active_days  DAU/WAU/MAU
//  retention_milestone           day (1,2,3,7,14,30) — only on the actual day  Retention curve
//  streak_milestone              days (7,14,30,60,100)               Habit formation
//  streak_broken                 previous_streak                     Habit loss
//  inactive_period_detected      days_inactive                       Churn signal
//  notification_opened           notification_id, notification_type, time_to_open_min  Re-engagement
//  recommendation_completed      recommendation_type, metric         Action loop
//
// ─── Q3: WHAT CREATES TRUST? ────────────────────────────────────────────────
//  explanation_viewed            explanation_type, screen            Do they check methodology?
//  privacy_page_viewed           source                              Privacy concern
//  recommendation_viewed         recommendation_type, metric, difficulty  Shown vs acted on
//  recommendation_skipped        recommendation_type, metric, reason Why they ignore advice
//  feedback_submitted            category, text_length, sentiment    What they want
//
// ─── Q4: WHAT CONVERTS TO PAID? ─────────────────────────────────────────────
//  paywall_viewed                source                              When they see paywall
//  paywall_dismissed             time_on_paywall, source, reason     Why they don't convert
//  paywall_cta_tapped            product_id, price, source           Purchase intent
//  paywall_plan_selected         product_id, period (yearly|monthly), price  Plan preference
//  paywall_error                 error_type (controlled), source     Paywall breakage
//  purchase_failed               product_id, failure_reason          Post-CTA friction
//  trial_started                 days_remaining                      Trial began
//  trial_day_check               days_remaining, milestones          Trial engagement
//  trial_expired                 milestones_completed                Why no conversion
//  subscription_expired          (same params as trial_expired)      Transitional dual-emit; remove after dashboards migrate
//  purchase_completed            product_id, is_free_trial           Who pays (gross_revenue=0 at $0 trial start)
//  pro_feature_funnel            feature, step                       Which feature converts
//  premium_feature_attempted     feature, screen                     Free user desire
//  pro_feature_upgrade_tapped    feature_name                        Upgrade intent (dupes pro_feature_funnel)
//
// ─── Q5: WHAT PREDICTS CHURN? ───────────────────────────────────────────────
//  subscription_cancelled        months_subscribed, cancellation_reason  Who churns
//  subscription_renewed          months_subscribed, trial_converted  Who stays (client-detected at status refresh)
//  inactive_period_detected      days_inactive, was_activated        Churn signal
//  stale_data_detected           stale_since_hours, metric           Data pipeline death
//  sync_failed                   reason, retry_count                 Broken pipeline
//  score_generation_failed       reason                              No value delivered
//  error_occurred                error_type, screen                  Product broken
//
// ─── ENGAGEMENT (supporting all 5 questions) ────────────────────────────────
//  screen_viewed                 screen, tab, depth                  What they use
//  screen_exited                 screen, duration_sec                Time per feature
//  block_tapped                  block_type, screen                  UI interaction
//  ask_query_submitted           query_text, query_length, screen    Exact Ask questions (full text)
//  share_photo_added             source, is_change, screen           Share card personalization
//  daily_result_shown            direction, score_delta              Loop-closer proof shown
//  core_action_completed         action, screen                      Retention predictor
//  insight_tapped                insight_category, severity, metric  Insight engagement (single event for every surface)
//  correlation_tapped            metric_a, metric_b, strength        Discovery
//  risk_tapped                   risk_type, grade, metric, source    Risk awareness
//  analysis_completed            score, insights_count               Engine output
//  weekly_score_change           score_delta, direction, score_bracket  Outcome improvement
//  account_data_deleted          stored_samples                      Hard churn (emitted before the wipe)
//
// ─── USER PROPERTIES (cohort segmentation) ──────────────────────────────────
//
//  DEMOGRAPHICS:                                  PIPELINE:
//  age                 27 | 34 | ...               data_sufficiency     sufficient | insufficient
//  gender              male | female | other       health_source_count  0, 1, 2, ...
//  country             US | GB | IN | ...          has_apple_watch      yes | no
//  language            en | es | de | ...          primary_health_source apple_watch | ...
//  timezone            America/New_York | ...      days_since_first_sync 0, 1, 2, ...
//  device_model        iPhone16,1 | ...            data_richness        low | medium | high
//  os_version          18.3 | ...                  notifications_enabled yes | no
//  app_version         1.71 | ...
//
//  LIFECYCLE:                                     MONETIZATION:
//  days_since_install  0, 1, 2, ...               subscription_status  trial | pro | expired
//  onboarding_completed yes | no                  months_subscribed    0, 1, 2, ...
//  activation_status   not_activated | activated   trial_converted      yes | no | pending
//  activation_milestones 0-10                     price_tier           standard | reduced
//  retention_day       0, 1, 3, 7, 14, 30        user_tier            free | pro
//  total_sessions      1, 2, 3, ...               renewal_count        0, 1, 2, ...
//  weekly_active_days  1-7
//  longest_streak      0, 1, 2, ...               ENGAGEMENT:
//  lifetime_core_actions 0, 1, 2, ...             health_score_bracket low | medium | high
//  organic_session_pct 0-100                      health_focus         sleep,fitness,...
//  pmf_response        very_disappointed | somewhat | not
//
// ─── PMF-SPECIFIC EVENTS (direct measurement) ──────────────────────────
//  satisfaction_survey_answered  sean_ellis_choice                   Sean Ellis canonical Q (step 1)
//  pmf_survey_step               step, text_length                   Steps 2-4 reach + answer length (never the text)
//  pmf_survey_completed          steps_answered                      Survey completion rate
//  share_completed               content_type, activity_type, completed  Viral loop closure
//  app_store_review_prompted     trigger                             Review velocity
//  deep_link_opened              url, source (widget|live_activity)  Attribution
//  notification_permission_requested  source                         Permission funnel start
//  notification_permission_result     granted, source                Permission conversion
//  push_route_unresolved         route                               Remote push landed on an unmapped route
//  query_feedback                helpful, confidence, query_length   LLM quality signal
//
// ─── BEHAVIORAL INTELLIGENCE (auto-computed, non-obvious) ───────────────────
//  ghost_session                 duration_sec, screens_viewed       Opened but did nothing
//  session_quality               quality (deep/engaged/shallow/bounce) Session classification
//  score_viewed                  score, delta, direction            When score is seen
//  score_reaction                reaction_type, next_action         What they do after seeing score
//  screenshot_taken              screen, tab                        Trust/share signal
//  habit_ritual_formed           ritual_strength_ratio, peak_hour_local  Morning ritual detection
//  feature_discovered            feature, discovery_pct             Feature adoption map
//  rage_tap                      element, screen, tap_count         Frustration detection
//  pre_churn_signal              avg_engagement_score, trend        1-2 week churn warning
//  value_delivered               has_new_value, new_insights        Did this session matter?
//  background_refresh_result     success, reason, samples_loaded    Data freshness pipeline
//
//  USER PROPERTIES (behavioral):
//  engagement_level              power_user | casual | at_risk | disengaging
//  usage_pattern                 strong | forming | irregular       Ritual consistency
//  has_morning_ritual            yes | no                           Habit formation
//  feature_discovery_pct         0-100                              Feature adoption
//
// ──────────────────────────────────────────────────────────────────────────────

/// Central analytics facade. PostHog backend (sole analytics platform).
/// Focused on PMF metrics: activation, retention, monetization, and value delivery.
@MainActor
final class AppAnalytics {
    static let shared = AppAnalytics()

    private let session = SessionTracker.shared
    private let defaults = UserDefaults.standard

    /// Cached app version string. `Bundle.main.infoDictionary`
    /// was being read on every analytics event. The marketing version is fixed
    /// for the lifetime of the running process, so cache it once at startup.
    private static let cachedAppVersion: String = {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String) ?? "unknown"
    }()

    /// Fixed UTC formatter so every event carries one comparable, human-readable
    /// timestamp regardless of device timezone. Cached to avoid per-event
    /// allocation in the hot `logEvent` path.
    private static let eventTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private var openTimestamps: [AppFeature: Date] = [:]
    private var backgroundedAt: Date?
    private var streamingStartDate: Date?
    private enum Key {
        static let subscriptionStartDate = "laso.analytics.subscription_start_date"
        static let renewalCount = "laso.analytics.renewal_count"
        static let trialConverted = "laso.analytics.trial_converted"
        static let lastKnownStatus = "laso.analytics.last_known_status"
        static let lastRenewalExpirationDate = "laso.analytics.last_renewal_expiration_date"
        static let firstScoreGeneratedTracked = "laso.analytics.first_score_generated_tracked"
        static let trialStartedTracked = "laso.analytics.trial_started_tracked"
        static let dailyActiveLastDate = "laso.analytics.daily_active_last_date"
    }

    private init() {}

    /// Events that must fire at most once per app run. The onboarding router
    /// renders `content.id(screen)`, so every back navigation destroys and
    /// rebuilds the screen and resets its view-local @State guard — the payoff
    /// reveals re-fired on every back tap. A process-scoped claim dedupes the
    /// whole flow run while still allowing a genuinely restarted onboarding (new
    /// launch) to report its reveals.
    private var oneShotEmitted: Set<String> = []

    private func claimOneShot(_ key: String) -> Bool {
        guard !oneShotEmitted.contains(key) else { return false }
        oneShotEmitted.insert(key)
        return true
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Demographics & Device Properties
    // ══════════════════════════════════════════════════════════════════════

    /// Set standard demographic and device user properties.
    /// Call on session start and after onboarding completes.
    func setDemographicProperties() {
        let defaults = UserDefaults.standard
        var props: [String: Any] = [:]

        // Exact age, derived from encrypted date of birth
        if let dob = UserProfileStore.shared.storedDateOfBirth() {
            let age = Date.cal.dateComponents([.year], from: dob, to: Date()).year ?? 0
            if age > 0 {
                props["age"] = age
            }
        }

        // Gender
        if let genderRaw = defaults.string(forKey: AppKeys.Profile.gender) {
            props["gender"] = genderRaw
        }

        // Country (ISO 3166-1 alpha-2)
        if let region = Locale.current.region?.identifier {
            props["country"] = region
        }

        // Language (e.g. "en", "es", "de")
        if let lang = Locale.current.language.languageCode?.identifier {
            props["language"] = lang
        }

        // Timezone (e.g. "America/New_York")
        props["timezone"] = TimeZone.current.identifier

        // Device model (raw hw.machine + marketing name)
        let rawModel = deviceMachineIdentifier()
        props["device_model"] = rawModel
        props["phone_model"] = Self.iPhoneMarketingName(for: rawModel)

        // OS version
        props["os_version"] = UIDevice.current.systemVersion

        // App version
        props["app_version"] = Self.cachedAppVersion

        // Accessibility settings
        props["uses_voiceover"] = UIAccessibility.isVoiceOverRunning ? "yes" : "no"
        props["uses_reduce_motion"] = UIAccessibility.isReduceMotionEnabled ? "yes" : "no"
        let contentSize = UIApplication.shared.preferredContentSizeCategory.rawValue
        props["uses_dynamic_type"] = contentSize != "UICTContentSizeCategoryLarge" ? contentSize : "default"

        if !props.isEmpty {
            AnalyticsBackend.provider.setUserProperties(props)
        }
    }

    /// Returns the raw hw.machine identifier (e.g. "iPhone16,1").
    private func deviceMachineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    /// Maps hw.machine identifiers to marketing names.
    private static func iPhoneMarketingName(for identifier: String) -> String {
        let map: [String: String] = [
            // iPhone 12
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            // iPhone 13
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            // iPhone SE 3rd gen
            "iPhone14,6": "iPhone SE (3rd gen)",
            // iPhone 14
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone 15
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            // iPhone 16
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,5": "iPhone 16e",
            // iPhone 17
            "iPhone18,1": "iPhone 17 Pro",
            "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,3": "iPhone 17",
            "iPhone18,4": "iPhone 17 Plus",
            "iPhone18,5": "iPhone 17 Air",
        ]
        return map[identifier] ?? identifier
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Error Tracking
    // ══════════════════════════════════════════════════════════════════════

    /// Record a non-fatal error for monitoring.
    func recordNonFatal(_ error: Error, context: String, metadata: [String: Any] = [:]) {
        AnalyticsBackend.provider.captureError(error, context: context, metadata: metadata)
    }

    /// Record a string-described error (no Error object) for monitoring.
    func recordNonFatal(_ message: String, context: String, metadata: [String: Any] = [:]) {
        AnalyticsBackend.provider.captureError(message, context: context, metadata: metadata)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 1. Activation Events
    // ══════════════════════════════════════════════════════════════════════

    /// How the user left an onboarding step: forward completion, a skip, or back.
    enum OnboardingStepAction: String {
        case completed
        case skipped
        case back
    }

    /// Call when the user completes, skips, or backs out of an onboarding step.
    /// `stepKey` is the stable step id (e.g. welcome, profile, connect_health);
    /// `stepCount` is the total steps in the CURRENT flow version (not a constant)
    /// so per-step drop-off is comparable across onboarding versions.
    func trackOnboardingStepCompleted(
        stepKey: String,
        stepIndex: Int,
        stepCount: Int,
        durationSec: Int,
        action: OnboardingStepAction
    ) {
        logEvent("onboarding_step_completed", parameters: [
            "step_key": stepKey,
            "step_index": stepIndex,
            "step_count": stepCount,
            "duration_sec": durationSec,
            "action": action.rawValue
        ])
    }

    /// Fired when the app is backgrounded mid-onboarding (the user quit before
    /// finishing). `onboarding_step_completed` only logs screens the user
    /// navigates away from, so without this the exact screen someone abandons on
    /// is invisible. Fired on every background, not once, so the LAST drop_off
    /// with no later `onboarding_completed` is the true abandonment point.
    func trackOnboardingDropOff(lastStep: String, stepIndex: Int, stepCount: Int, durationSec: Int) {
        logEvent("onboarding_drop_off", parameters: [
            "last_step": lastStep,
            "step_index": stepIndex,
            "step_count": stepCount,
            "duration_sec": durationSec
        ])
    }

    /// Fired when the onboarding Vitality Age reveal (screen 12) settles on its
    /// result, so the computed outcome — not just the screen transition — is in
    /// Amplitude (how many users land younger vs older, and how often we had no
    /// health data to compute from). The vitality age and the exact year gap are
    /// computed health results, so only the coarse band and the verdict are
    /// sent; the numbers stay on the phone.
    func trackOnboardingVitalityRevealed(vitalityAge: Int, realAge: Int, metricCount: Int, hasHealthData: Bool) {
        guard claimOneShot("onboarding_vitality_revealed") else { return }
        let diff = realAge - vitalityAge   // + younger, - older
        let band: String
        // `even` is its own band: folding a zero gap into "younger" contradicted
        // the verdict on the same event and swept the whole no-data cohort
        // (vitality age == chronological age) into the younger bucket.
        if diff > 0 { band = "younger" }
        else if diff == 0 { band = "even" }
        else if diff >= -3 { band = "slightly_older" }
        else { band = "much_older" }
        logEvent("onboarding_vitality_revealed", parameters: [
            "real_age": realAge,
            "verdict": diff > 0 ? "younger" : (diff < 0 ? "older" : "even"),
            "band": band,
            "metric_count": metricCount,
            "has_health_data": hasHealthData
        ])
    }

    /// First touch of the onboarding funnel, so abandonment on the very first
    /// screen (before any step is completed) is visible.
    func trackOnboardingStarted() {
        logEvent("onboarding_started", parameters: [:])
    }

    /// Profile screen: the age + sex the user entered (screen 3). Sent on the
    /// screen so mid-funnel drop-offs are cohortable, not only at completion.
    func trackOnboardingProfileSet(age: Int, sex: String) {
        logEvent("onboarding_profile_set", parameters: ["age": age, "sex": sex])
    }

    /// Goal screen (4): which goals the user picked and how many. Order-preserved.
    func trackOnboardingGoalSelected(goals: [String], count: Int) {
        logEvent("onboarding_goal_selected", parameters: ["goals": goals, "count": count])
    }

    /// Symptom screen (5): which symptoms the user picked and how many.
    func trackOnboardingSymptomsSelected(symptoms: [String], count: Int) {
        logEvent("onboarding_symptoms_selected", parameters: ["symptoms": symptoms, "count": count])
    }

    /// How the sign-in step ended. `skipped` exists because "Skip for now" creates
    /// no account at all — reporting it as success=true made the account-creation
    /// conversion rate read as ~100%.
    enum SignInOutcome: String {
        case completed
        case skipped
        case failed
    }

    /// Sign-in outcome on the onboarding sign-in screen (13). `success` stays on
    /// the event for existing charts but is now derived: only `completed` is the
    /// account-creation conversion.
    func trackSignInCompleted(method: String, outcome: SignInOutcome) {
        logEvent("sign_in_completed", parameters: [
            "method": method,
            "outcome": outcome.rawValue,
            "success": outcome == .completed
        ])
    }

    /// Heart screen (11): the resting-HR reveal outcome, so empty-state vs
    /// has-data drop-off is measurable like the vitality reveal.
    /// The resting heart rate itself is never sent. `has_data` is the whole
    /// funnel question, and events are joined to a signed-in user id, so a raw
    /// vital here would be identified health data leaving the phone.
    func trackOnboardingHeartRevealed(hasData: Bool, monthsCovered: Int?) {
        guard claimOneShot("onboarding_heart_revealed") else { return }
        var params: [String: Any] = ["has_data": hasData]
        if let monthsCovered { params["months_covered"] = monthsCovered }
        logEvent("onboarding_heart_revealed", parameters: params)
    }

    /// Cliffhanger screen: user skipped the notification opt-in (distinct from
    /// the generic step event, which can't tell skip from opt-in).
    func trackOnboardingNotificationSkipped(source: String) {
        logEvent("onboarding_notification_skipped", parameters: ["source": source])
    }

    /// Call when onboarding is fully completed. The two Identify calls run BEFORE
    /// logEvent: Amplitude applies identifies in arrival order, so setting them
    /// afterwards stamped this very event with the session-start value
    /// onboarding_completed="no". `focuses` ships on the event as well as on the
    /// user property so activation can be cut by goal at the completion moment.
    func trackOnboardingCompleted(focuses: [String], durationSec: Int) {
        setUserProperty("onboarding_completed", value: "yes")
        setUserProperty("health_focus", value: focuses.joined(separator: ","))

        logEvent("onboarding_completed", parameters: [
            "duration_sec": durationSec,
            "focuses": focuses,
            "focus_count": focuses.count
        ])

        // Set demographics now that profile is captured
        setDemographicProperties()
    }

    enum ActivationMilestone: String {
        case firstDataLoad = "first_data_load"
        case firstScoreSeen = "first_score_seen"
        case firstInsightViewed = "first_insight_viewed"
        case firstMetricDetail = "first_metric_detail"
        case firstChartInteraction = "first_chart_interaction"
        case firstWeeklyReview = "first_weekly_review"
        case firstCorrelation = "first_correlation"
        case firstLiveSession = "first_live_session"
        case firstSettingsVisit = "first_settings_visit"
        case firstPullToRefresh = "first_pull_to_refresh"
        case firstPrediction = "first_prediction"
        case fullCalibration = "full_calibration"
    }

    func trackActivationMilestone(_ milestone: ActivationMilestone) {
        let isNew = session.recordMilestone(milestone.rawValue)
        guard isNew else { return }

        let timeSinceInstall = Int(Date().timeIntervalSince(session.installDate))

        logEvent("activation_milestone", parameters: [
            "milestone": milestone.rawValue,
            "session_number": session.totalSessions,
            "time_since_install_sec": timeSinceInstall,
            "milestones_completed": session.completedMilestones.count,
            "is_first_session": session.isFirstSession ? 1 : 0
        ])

        setUserProperty("activation_milestones", value: "\(session.completedMilestones.count)")

        // Aha moment (canonical North Star single-action event). Laso's chosen
        // aha is "user viewed their first personalised daily insight" because
        // it's the first moment the app has delivered tailored value. Emitting
        // a dedicated event makes activation dashboards 1-click in PostHog
        // rather than requiring a filter on the activation_milestone stream.
        if milestone == .firstInsightViewed {
            logEvent("aha_moment_reached", parameters: [
                "milestone": milestone.rawValue,
                "session_number": session.totalSessions,
                "time_since_install_sec": timeSinceInstall,
                "days_since_install": session.daysSinceInstall
            ])
            setUserProperty("aha_reached", value: "yes")
            setUserProperty("aha_time_since_install_sec", value: "\(timeSinceInstall)")
        }

        // Check if user just became activated (3+ milestones)
        if session.completedMilestones.count == 3 {
            logEvent("activation_completed", parameters: [
                "milestones_completed": session.completedMilestones.count,
                "days_to_activate": session.daysSinceInstall,
                "sessions_to_activate": session.totalSessions,
                "time_since_install_sec": timeSinceInstall
            ])
            setUserProperty("activation_status", value: "activated")
        }
    }

    /// North-star metric #2. The caller runs inside every sync, so the one-shot
    /// lives in `recordFirstValueTime()`: gating on `ttfv > 0` re-emitted the
    /// session-1 seconds value on every later sync under the CURRENT session
    /// number, and never emitted at all when the first value landed in the same
    /// second as session start.
    func trackTimeToFirstValue() {
        guard session.recordFirstValueTime() else { return }
        let ttfv = session.firstValueTimeSec
        logEvent("time_to_first_value", parameters: [
            "seconds": ttfv,
            "session_number": session.totalSessions
        ])
        setUserProperty("first_value_time_sec", value: "\(ttfv)")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 2. Habit Formation (Retention & Streaks)
    // ══════════════════════════════════════════════════════════════════════

    /// Call on each session start. Checks and fires retention milestones.
    func trackRetentionMilestones() {
        // Retention day milestones
        if let day = session.checkRetentionMilestone() {
            logEvent("retention_milestone", parameters: [
                "day": day,
                "total_sessions": session.totalSessions,
                "activation_milestones": session.completedMilestones.count,
                "streak_days": session.streakDays
            ])
            setUserProperty("retention_day", value: "\(day)")
        }

        // Streak milestones
        if let streakDays = session.checkStreakMilestone() {
            logEvent("streak_milestone", parameters: [
                "days": streakDays,
                "total_sessions": session.totalSessions,
                "days_since_install": session.daysSinceInstall
            ])
            setUserProperty("longest_streak", value: "\(session.longestStreak)")
        }

        // Streak broken detection
        if let previousStreak = session.previousStreakBeforeBreak, previousStreak > 1 {
            logEvent("streak_broken", parameters: [
                "previous_streak": previousStreak,
                "longest_streak": session.longestStreak,
                "days_since_install": session.daysSinceInstall
            ])
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 3. Churn Signals
    // ══════════════════════════════════════════════════════════════════════

    /// Call on session start. Detects and logs inactivity periods.
    func trackInactivityIfNeeded() {
        if let inactiveDays = session.checkInactivityPeriod() {
            logEvent("inactive_period_detected", parameters: [
                "days_inactive": inactiveDays,
                "total_sessions": session.totalSessions,
                "days_since_install": session.daysSinceInstall,
                "was_activated": session.isActivated ? 1 : 0,
                "lifetime_core_actions": session.lifetimeCoreActions
            ])
        }

        // Clear inactivity state since user is now active
        session.clearInactivityState()
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 4. Session Events
    // ══════════════════════════════════════════════════════════════════════

    /// Call when app enters foreground. Returns true when a NEW session was
    /// minted (so the caller runs the rest of the session-start analytics), false
    /// when the previous session resumed within the 30-minute idle window — this
    /// is the DAU-inflation guard the taxonomy requires.
    @discardableResult
    func trackSessionStart() -> Bool {
        // Screens stay open across a background gap (no onDisappear fired), so
        // shift their open stamps forward by the gap: screen_exited duration_sec
        // must measure foreground dwell only, mirroring the score-reaction re-arm
        // in trackAppBackgrounded.
        if let backgroundStart = backgroundedAt {
            let now = Date()
            // Clamps: a wall-clock rollback during background makes the gap
            // negative (would inflate durations), and a notification-tap deep
            // link can stamp a screen open after foregrounding but before this
            // runs — shifting that fresh stamp by the full gap would push it
            // past `now` and produce negative duration_sec.
            let gap = max(0, now.timeIntervalSince(backgroundStart))
            for (feature, opened) in openTimestamps {
                openTimestamps[feature] = min(opened.addingTimeInterval(gap), now)
            }
            backgroundedAt = nil
        }

        // A session left open by a prior app run (killed or backgrounded past the
        // idle window) ends here, on the next foreground — emit its deferred
        // session_ended before anything new starts.
        if let priorEnd = session.reconcilePersistedSession() {
            emitSessionEnded(priorEnd)
        }

        let outcome = session.startSession()

        // Minting this session idle-timed-out a still-open prior session in the same
        // process: emit its session_ended first so started/ended stay paired.
        if let priorEnd = outcome.priorEnd {
            emitSessionEnded(priorEnd)
        }

        // A quick app-switch resumes the open session: do not re-emit
        // session_started or any per-session work.
        guard outcome.isNew else { return false }

        // first_open: the user's very first app open, emitted exactly once.
        // Gated on totalSessions == 1 (set inside startSession). is_reinstall is
        // backed by a Keychain install token so a reinstall is not counted as a
        // fresh install.
        if session.totalSessions == 1 {
            emitFirstOpenIfNeeded()
        }

        // Rest-day credit telemetry (Gentler Streak / Duolingo pattern). Emits
        // once per session when SessionTracker has flipped the flag during
        // this startSession call.
        if session.didGrantCreditThisSession {
            logEvent("streak_rest_credit_granted", parameters: [
                "credits_remaining": session.restCreditsRemaining,
                "streak_days": session.streakDays
            ])
        }
        if session.didSpendCreditThisSession {
            logEvent("streak_rest_credit_spent", parameters: [
                "credits_remaining": session.restCreditsRemaining,
                "streak_days_saved": session.streakDays
            ])
        }
        setUserProperty("rest_credits_remaining", value: "\(session.restCreditsRemaining)")

        let calendar = Date.cal
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let dayNames = ["", "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

        // session_started carries only day_of_week; every other dimension rides
        // as a global (session_id, hour_of_day, app_version, opened_from) or as a
        // user property (set below), so it is never duplicated on the event.
        logEvent("session_started", parameters: [
            "day_of_week": dayNames[weekday]
        ])

        // User-level dimensions removed from per-event injection now live here as
        // user properties so cohort dashboards keep working without bloating
        // every event with them.
        let engagement = computeEngagementLevel()
        let networkType: String = ConnectivityMonitor.shared.isOnline
            ? (ConnectivityMonitor.shared.isExpensive ? "cellular" : "wifi")
            : "offline"
        // One batched Identify instead of one per property. Each setUserProperty
        // is a separate $identify event that Amplitude enqueues, writes to its
        // on-disk event file and uploads, so this was 13 payloads per session
        // carrying the same information as one.
        AnalyticsBackend.provider.setUserProperties([
            "streak_days": "\(session.streakDays)",
            "price_tier": SubscriptionConfig.currentTier.rawValue,
            "days_since_install": "\(session.daysSinceInstall)",
            "total_sessions": "\(session.totalSessions)",
            "lifetime_core_actions": "\(session.lifetimeCoreActions)",
            "weekly_active_days": "\(session.weeklyActiveDays)",
            "organic_session_pct": "\(session.organicSessionPercent)",
            "session_source": session.currentSessionSource.rawValue,
            "network_type": networkType,
            "activation_status": session.isActivated ? "activated" : "not_activated",
            "engagement_level": engagement.rawValue,
            "subscription_age_days": "\(subscriptionAgeDays)"
            // nav_depth is deliberately absent: startSession() resets currentDepth
            // to 0 a few lines above, so it could only ever be "0". Session depth
            // now ships as max_depth on session_ended.
        ])

        // Refresh demographic & device properties every session
        setDemographicProperties()
        updateJourneyProperties()

        // Behavioral intelligence: detect habit patterns
        detectHabitPattern()
        return true
    }

    /// Call when the app enters the background. Closes the active foreground span
    /// and snapshots the session to disk, but does NOT emit `session_ended`: under
    /// the resume model a brief background is still the same session (it ends on the
    /// idle timeout or next launch). Re-arms score_viewed / score_reaction so
    /// reaction_time_sec never spans the backgrounded gap.
    func trackAppBackgrounded() {
        // Anything still buffered would be lost if the app is killed while
        // backgrounded, so drain it before the process can go away.
        SectionViewBuffer.flushNow()
        session.closeActiveSpanForBackground()
        scoreSeenDate = nil
        scoreViewedThisSession = false
        // onDisappear never fires on backgrounding, so open-screen stamps survive
        // the gap; remember when it started so the next foreground can exclude
        // the backgrounded time from screen_exited duration_sec.
        backgroundedAt = Date()
    }

    /// Emits `session_ended` for a session that has truly ended, tagged with its own
    /// session_id so the deferred/idle ends pair with the correct session_started
    /// (the global session_id by now points at the live session, not this one).
    private func emitSessionEnded(_ stats: SessionTracker.EndedStats) {
        // session_number is passed explicitly: by the time the idle-timeout end is
        // emitted, the live session.totalSessions has already incremented for the new
        // session, so logEvent's global injection would otherwise be off by one.
        // session_source and opened_from are passed explicitly for the same reason
        // session_number is: by the time this fires, the LIVE session's source is
        // either the new session's (idle-timeout end) or the fresh process default
        // (reconciled end), so logEvent's injection would describe the wrong
        // session. A stored source that no longer maps onto the enum ships as
        // "unknown" rather than being silently rewritten to app_icon.
        let endedSource = SessionTracker.SessionSource(rawValue: stats.sessionSource)
        logEvent("session_ended", parameters: [
            "session_id": stats.sessionId,
            "session_number": stats.sessionNumber,
            "session_source": stats.sessionSource,
            "opened_from": endedSource.map(Self.openedFrom(for:)) ?? "unknown",
            "duration_sec": stats.durationSec,
            "active_sec": stats.activeSec,
            "screens_viewed": stats.screensVisited,
            "max_depth": stats.maxDepth,
            "core_actions_count": stats.coreActionsCount,
            "ended_reason": stats.reason
        ])

        // Behavioral intelligence: ghost sessions, churn risk, session quality. These
        // emit their own events, which must carry the ENDED session's id/number/source
        // (not the live session's), so the full stats are threaded through.
        evaluateSessionQuality(stats)
        evaluateChurnRisk(stats)
    }

    // MARK: - first_open

    private enum FirstOpenKey {
        /// Keychain-backed marker that survives app deletion. Its presence on a
        /// fresh install means this is a REINSTALL, not a first-ever install.
        static let installToken = "laso.analytics.install_token"
    }

    /// Emits `first_open` exactly once for the user's first-ever app open.
    /// `is_reinstall` is true when a Keychain install token already exists (the
    /// token survives app deletion via the Keychain), false on a genuine first
    /// install. The token is written after reading so the next reinstall is
    /// detected.
    private func emitFirstOpenIfNeeded() {
        guard !defaults.bool(forKey: "laso.analytics.first_open_tracked") else { return }
        defaults.set(true, forKey: "laso.analytics.first_open_tracked")

        let hadToken = EncryptedStore.shared.load(forKey: FirstOpenKey.installToken) != nil
        if !hadToken {
            EncryptedStore.shared.save(Data(UUID().uuidString.utf8), forKey: FirstOpenKey.installToken)
        }

        logEvent("first_open", parameters: [
            "is_reinstall": hadToken ? 1 : 0
        ])
    }

    // MARK: - feature_used

    /// Controlled product-action type. One `feature_used` event with this enum
    /// replaces the fragmented per-feature event names.
    enum FeatureAction: String {
        case askedHealthQuery = "asked_health_query"
        case completedBreathwork = "completed_breathwork"
        case viewedInsight = "viewed_insight"
        case viewedScore = "viewed_score"
        case viewedMetricDetail = "viewed_metric_detail"
        case viewedCorrelation = "viewed_correlation"
        case viewedWeeklyReview = "viewed_weekly_review"
        case interactedWithChart = "interacted_with_chart"
        case usedLiveTab = "used_live_tab"
        case changedTimeRange = "changed_time_range"
        case pulledToRefresh = "pulled_to_refresh"
        case viewedRiskDetail = "viewed_risk_detail"
        case completedMorningCheckIn = "completed_morning_checkin"
        case viewedDailyAction = "viewed_daily_action"
        case completedDailyAction = "completed_daily_action"
        case loggedJournal = "logged_journal"
    }

    /// Emits the consolidated `feature_used` event. Called from `trackCoreAction`
    /// so any meaningful product action lands under one stable event name with a
    /// controlled `action_type`.
    func trackFeatureUsed(_ action: FeatureAction) {
        logEvent("feature_used", parameters: [
            "action_type": action.rawValue
        ])
    }

    func trackReturnSession() {
        guard session.totalSessions > 1 else { return }

        logEvent("return_session", parameters: [
            "session_number": session.totalSessions,
            "days_since_last_session": session.daysSinceLastSession ?? -1,
            "days_since_install": session.daysSinceInstall,
            "streak_days": session.streakDays,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 5. Screen Events
    // ══════════════════════════════════════════════════════════════════════

    func trackFeatureOpen(_ feature: AppFeature, metadata: [String: Any] = [:]) {
        // Buffered section_viewed events belong to the screen the user is
        // leaving, so drain them before recordScreenView moves the screen that
        // logEvent injects forward.
        SectionViewBuffer.flushNow()

        let now = Date()
        let previousScreen = session.recordScreenView(feature.rawValue)

        openTimestamps[feature] = now

        // Always send previous_screen and transition with explicit "first_screen"
        // placeholders on the first screen of a session so PostHog funnels can
        // group/filter without a missing-property branch.
        var params: [String: Any] = [
            "screen": feature.rawValue,
            "screen_id": feature.rawValue,
            "tab": session.currentTab,
            "depth": session.currentDepth,
            "previous_screen": previousScreen ?? "first_screen",
            "transition": previousScreen.map { "\($0)->\(feature.rawValue)" } ?? "first_screen->\(feature.rawValue)"
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_viewed", parameters: params)

        AnalyticsBackend.provider.screen(feature.rawValue, properties: [
            "tab": session.currentTab,
            "depth": session.currentDepth
        ])

        // Behavioral intelligence: track feature discovery
        updateFeatureDiscovery(screen: feature)
    }

    func trackFeatureClose(_ feature: AppFeature, metadata: [String: Any] = [:]) {
        let now = Date()
        var durationSeconds = 0.0

        if let start = openTimestamps[feature] {
            durationSeconds = now.timeIntervalSince(start)
        }
        openTimestamps[feature] = nil

        let duration = max(0, Int(durationSeconds.rounded()))

        var params: [String: Any] = [
            "screen": feature.rawValue,
            "screen_id": feature.rawValue,
            "tab": session.currentTab,
            "duration_sec": duration
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_exited", parameters: params)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Day-1 Prediction Funnel & Upgrade Intent
    // ══════════════════════════════════════════════════════════════════════

    /// Data-richness branch chosen after the onboarding scan. The call site
    /// holds the once-per-flow guard (the back-nav scan re-run would refire it).
    func trackDay1DataRichnessSegment(_ segment: String) {
        logEvent("day1_data_richness_segment", parameters: ["segment": segment])
    }

    /// Instant verdict payoff on the rich onboarding branch.
    func trackVerdictDelivered(zone: String, magnitudeBand: String, weekday: Int, nightsRemaining: Int, sideDiscoveryCount: Int) {
        guard claimOneShot("verdict_delivered") else { return }
        logEvent("verdict_delivered", parameters: [
            "zone": zone,
            "magnitude_band": magnitudeBand,
            "weekday": weekday,
            "nights_remaining": nightsRemaining,
            "side_discovery_count": sideDiscoveryCount
        ])
    }

    /// Sparse/denied-branch promise screen shown. `nightsRemaining` only
    /// exists on the cliffhanger (sparse) branch.
    func trackPromiseShown(branch: String, nightsRemaining: Int? = nil) {
        var params: [String: Any] = ["branch": branch]
        if let nightsRemaining { params["nights_remaining"] = nightsRemaining }
        logEvent("promise_shown", parameters: params)
    }

    /// Denied-branch payoff: Health access granted after the re-permission push.
    /// No properties: the event only exists on conversion, so a literal
    /// `granted: 1` added nothing and collided with the boolean `granted` on the
    /// notification-permission events.
    func trackRepermissionConversion() {
        logEvent("repermission_conversion", parameters: [:])
    }

    /// First-ever morning check-in, the denied branch's value moment.
    func trackFirstCheckInDone() {
        logEvent("first_checkin_done", parameters: [:])
    }

    /// Upgrade tap on the pro feature overlay. Duplicates
    /// pro_feature_funnel(step=upgrade_tapped); remove once dashboards keyed
    /// on this event migrate to pro_feature_funnel.
    func trackProFeatureUpgradeTapped(feature: String) {
        logEvent("pro_feature_upgrade_tapped", parameters: ["feature_name": feature])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 6. Core Actions & Block Taps
    // ══════════════════════════════════════════════════════════════════════

    enum CoreAction: String {
        case viewedScore = "viewed_score"
        case viewedInsight = "viewed_insight"
        case viewedMetricDetail = "viewed_metric_detail"
        case viewedCorrelation = "viewed_correlation"
        case viewedWeeklyReview = "viewed_weekly_review"
        case interactedWithChart = "interacted_with_chart"
        case usedLiveTab = "used_live_tab"
        case changedTimeRange = "changed_time_range"
        case pulledToRefresh = "pulled_to_refresh"
        case viewedRiskDetail = "viewed_risk_detail"
        case completedMorningCheckIn = "completed_morning_checkin"
        case viewedDailyAction = "viewed_daily_action"
        case completedDailyAction = "completed_daily_action"
        case askedHealthQuery = "asked_health_query"
    }

    /// `source` names the surface that actually produced the action when it is
    /// not the screen (e.g. the watch check-in records on the phone with no
    /// screen on display). Nil keeps the parameter out of the payload.
    func trackCoreAction(_ action: CoreAction, screen: AppFeature, source: String? = nil) {
        session.recordCoreAction(action.rawValue)

        // Consolidated taxonomy event: every meaningful product action also emits
        // one feature_used with a controlled action_type. CoreAction rawValues
        // align 1:1 with FeatureAction rawValues.
        if let featureAction = FeatureAction(rawValue: action.rawValue) {
            trackFeatureUsed(featureAction)
        }

        // Score reaction: capture what the user does after seeing their score
        trackScoreReaction(nextAction: action.rawValue, nextScreen: screen)

        var coreActionParameters: [String: Any] = [
            "action": action.rawValue,
            "screen": screen.rawValue,
            "session_number": session.totalSessions,
            "core_actions_this_session": session.coreActionsThisSession.count,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "days_since_install": session.daysSinceInstall
        ]
        if let source { coreActionParameters["source"] = source }
        logEvent("core_action_completed", parameters: coreActionParameters)

        setUserProperty("lifetime_core_actions", value: "\(session.lifetimeCoreActions)")

        // A core action is the goal a re-engagement notification aims for: if one
        // was opened inside the conversion window, credit it now.
        attributePendingNotificationConversion(goal: action.rawValue)
    }

    func trackBlockTap(title: String, type: BlockType, screen: AppFeature, metadata: [String: Any] = [:]) {
        let derivedTargetId = slugify(title)
        let actionId = "\(screen.rawValue)_\(type.rawValue)_\(derivedTargetId)"
        var params: [String: Any] = [
            // Canonical card identity for actionable analysis.
            "card_id": type.rawValue,
            "card_label": title,
            "interaction_id": actionId,
            "action_id": actionId,
            "element_id": "\(screen.rawValue)_\(type.rawValue)",
            "target_id": derivedTargetId,
            // Backward-compatible keys already used in dashboards.
            "block_title": title,
            "block_type": type.rawValue,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("block_tapped", parameters: params)

        // Behavioral intelligence: detect rage taps on any block
        detectRageTap(element: type.rawValue, screen: screen)
    }

    /// The exact question a user typed in Ask. `query_text` is a full-text field
    /// (kept whole, not clipped to 100 chars) so the real wording reaches
    /// Amplitude. These are health questions — treat the property as sensitive
    /// when configuring the destination.
    func trackAskQuerySubmitted(text: String, screen: AppFeature = .askYourData) {
        logEvent("ask_query_submitted", parameters: [
            "query_text": text,
            "query_length": text.count,
            "screen": screen.rawValue
        ])
    }

    /// User attached a personal photo to the share card. `source` is
    /// "library" or "camera"; `is_change` is true when a photo was already set
    /// and the user replaced it. Sits between the share-sheet open and
    /// share_completed so the personalization step of the share funnel is
    /// measurable.
    func trackSharePhotoAdded(source: String, isChange: Bool, screen: AppFeature = .home) {
        logEvent("share_photo_added", parameters: [
            "source": source,
            "is_change": isChange ? 1 : 0,
            "screen": screen.rawValue
        ])
    }

    /// The morning-after result of a marked-done action was shown (the loop
    /// closer). `direction` is up/steady/down and `delta` is the readiness-score
    /// change — the core retention proof that the app worked.
    func trackDailyResultShown(direction: String, delta: Int) {
        logEvent("daily_result_shown", parameters: [
            "direction": direction,
            "score_delta": delta
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 7. Content Engagement Events
    // ══════════════════════════════════════════════════════════════════════

    func trackInsightTapped(category: String, severity: String, metric: String, screen: AppFeature) {
        logEvent("insight_tapped", parameters: [
            "insight_category": category,
            "severity": severity,
            "metric": metric,
            "screen": screen.rawValue
        ])
    }

    /// `source` names which Correlations tier the tap came from. It is a separate
    /// property because `strength` is a single value space (Strong | Moderate |
    /// Mild | none) and folding the tier into it would make one property carry two
    /// unrelated vocabularies.
    func trackCorrelationTapped(metricA: String, metricB: String, strength: String, source: String, screen: AppFeature) {
        logEvent("correlation_tapped", parameters: [
            "metric_a": metricA,
            "metric_b": metricB,
            "strength": strength,
            "source": source,
            "screen": screen.rawValue
        ])
    }

    /// `metric` is the tapped row's metric and `source` names which row type it
    /// was ("focus_area" / "contributing_factor"). Without them the two call
    /// sites on Risk Detail produce byte-identical payloads that only restate the
    /// preceding screen_viewed.
    func trackRiskTapped(riskType: String, grade: String, metric: String, source: String, screen: AppFeature) {
        logEvent("risk_tapped", parameters: [
            "risk_type": riskType,
            "grade": grade,
            "metric": metric,
            "source": source,
            "screen": screen.rawValue
        ])
    }

    func trackChartInteraction(metric: String, interactionType: String, period: String, screen: AppFeature) {
        logEvent("chart_interaction", parameters: [
            "metric": metric,
            "interaction_type": interactionType,
            "period": period,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ])
    }

    func trackPullToRefresh(screen: AppFeature) {
        logEvent("pull_to_refresh", parameters: [
            "screen": screen.rawValue,
            "tab": session.currentTab
        ])
    }

    /// Wake anchor chosen. `hour_bucket` rather than the raw hour so the event
    /// does not carry a routine that pinpoints when someone is at home.
    func trackWakeAnchorSet(hour: Int, isFirstSet: Bool, source: String = "sleep_coach") {
        let bucket: String
        if hour < 6 { bucket = "early" } else if hour < 8 { bucket = "mid" } else { bucket = "late" }
        logEvent("wake_anchor_set", parameters: [
            "hour_bucket": bucket,
            "is_first_set": isFirstSet,
            "source": source
        ])
    }

    /// Fired once per Sleep Coach open so the drift distribution is visible
    /// without shipping per-night times. Success is this median falling
    /// within-user between week 1 and week 8.
    func trackWakeAnchorDriftSnapshot(medianDriftMinutes: Int, nightsInWindow: Int, nightsTracked: Int) {
        logEvent("wake_anchor_drift_snapshot", parameters: [
            "median_drift_minutes": medianDriftMinutes,
            "nights_in_window": nightsInWindow,
            "nights_tracked": nightsTracked
        ])
    }

    func trackTimeRangeChanged(screen: AppFeature, context: String, fromDays: Int, toDays: Int) {
        logEvent("time_range_changed", parameters: [
            "screen": screen.rawValue,
            "context": context,
            "from_days": fromDays,
            "to_days": toDays
        ])
    }

    func trackFilterChanged(screen: AppFeature, filterType: String, from: String, to: String) {
        logEvent("filter_changed", parameters: [
            "screen": screen.rawValue,
            "filter_type": filterType,
            "from_filter": from,
            "to_filter": to
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 8. Outcome Metrics
    // ══════════════════════════════════════════════════════════════════════

    /// Call after analysis refresh when we have a new score.
    func trackWeeklyScoreChange(newScore: Int, delta: Int) {
        let direction: String
        if delta > 2 { direction = "improving" }
        else if delta < -2 { direction = "declining" }
        else { direction = "stable" }

        logEvent("weekly_score_change", parameters: [
            "score_bracket": scoreBracket(newScore),
            // The magnitude, not just the bucket: a +3 and a +40 week were the
            // same row. score_delta is the key daily_result_shown and
            // score_reaction already use, and a delta is not an identifiable score.
            "score_delta": delta,
            "direction": direction,
            "days_since_install": session.daysSinceInstall
        ])

        let bracket: String
        if newScore >= 75 { bracket = "high" }
        else if newScore >= 50 { bracket = "medium" }
        else { bracket = "low" }
        setUserProperty("health_score_bracket", value: bracket)
    }

    func trackAnalysisCompleted(score: Int, insightsCount: Int, anomaliesCount: Int,
                                 risksCount: Int, correlationsCount: Int,
                                 illnessWarningsCount: Int, metricsAnalyzed: Int) {
        let insightsPerMetric = metricsAnalyzed > 0
            ? Double(insightsCount) / Double(metricsAnalyzed)
            : 0
        let analysisDepth: String
        switch metricsAnalyzed {
        case 0..<8:
            analysisDepth = "thin"
        case 8..<18:
            analysisDepth = "developing"
        case 18..<32:
            analysisDepth = "strong"
        default:
            analysisDepth = "dense"
        }
        let signalDensity = anomaliesCount + risksCount + correlationsCount + illnessWarningsCount

        logEvent("analysis_completed", parameters: [
            "insights_count": insightsCount,
            "anomalies_count": anomaliesCount,
            "risks_count": risksCount,
            "correlations_count": correlationsCount,
            "illness_warnings_count": illnessWarningsCount,
            "metrics_analyzed": metricsAnalyzed,
            "score_bracket": scoreBracket(score),
            "insights_per_metric": insightsPerMetric,
            "signal_density": signalDensity,
            "analysis_depth": analysisDepth
        ])

        setUserProperty("data_richness", value: metricsAnalyzed < 10 ? "low" : metricsAnalyzed < 30 ? "medium" : "high")
        setUserProperty("analysis_depth", value: analysisDepth)
        setUserProperty("last_score_bracket", value: scoreBracket(score))
        setUserProperty("insight_density", value: insightsPerMetric >= 0.75 ? "high" : insightsPerMetric >= 0.35 ? "medium" : "low")

        let bracket: String
        if score >= 75 { bracket = "high" }
        else if score >= 50 { bracket = "medium" }
        else { bracket = "low" }
        setUserProperty("health_score_bracket", value: bracket)

        if !defaults.bool(forKey: Key.firstScoreGeneratedTracked) {
            defaults.set(true, forKey: Key.firstScoreGeneratedTracked)
            trackFirstScoreGenerated(
                score: score,
                timeSinceInstallSec: Int(Date().timeIntervalSince(session.installDate)),
                metricsUsed: metricsAnalyzed
            )
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 9. Subscription Funnel
    // ══════════════════════════════════════════════════════════════════════

    /// Call when trial begins (first app launch after onboarding).
    /// Fires `trial_started` exactly once per install. The persisted
    /// `trialStartedTracked` flag is the single source of truth so the event
    /// neither double-fires (every `updateSubscriptionProperties` while the
    /// user is still in trial would otherwise re-emit) nor gets missed (the
    /// old `previousStatus == "unknown"` gate skipped it whenever the first
    /// observed status was anything other than "unknown").
    func trackTrialStarted(daysRemaining: Int) {
        // User-property maintenance always runs so a reinstall still rebuilds
        // subscription_status / trial_converted even after the one-shot event.
        setUserProperty("subscription_status", value: "trial")
        setUserProperty("trial_converted", value: "pending")
        defaults.set("pending", forKey: Key.trialConverted)

        guard !defaults.bool(forKey: Key.trialStartedTracked) else { return }
        defaults.set(true, forKey: Key.trialStartedTracked)

        logEvent("trial_started", parameters: [
            "days_remaining": daysRemaining
        ])
    }

    /// Call on each session during trial to track engagement vs trial days left.
    func trackTrialDayCheck(daysRemaining: Int) {
        logEvent("trial_day_check", parameters: [
            "days_remaining": daysRemaining,
            "milestones_completed": session.completedMilestones.count,
            "total_sessions": session.totalSessions,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
    }

    /// Call when trial expires without a purchase.
    func trackTrialExpired() {
        let converted = defaults.string(forKey: Key.trialConverted) ?? "no"
        guard converted != "yes" else { return }

        let params: [String: Any] = [
            "converted": 0,
            "milestones_completed": session.completedMilestones.count,
            "total_sessions": session.totalSessions,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "was_activated": session.isActivated ? 1 : 0
        ]
        logEvent("trial_expired", parameters: params)
        // Transitional dual-emit: this event shipped in production as
        // subscription_expired, and saved Amplitude charts still key on that
        // name. Remove once dashboards are migrated to trial_expired.
        logEvent("subscription_expired", parameters: params)
        setUserProperty("trial_converted", value: "no")
        defaults.set("no", forKey: Key.trialConverted)
    }

    /// Call when paywall is viewed. `source` is the placement that triggered the
    /// paywall (e.g. "onboarding", "aha_moment", "trial_expired"). Fire exactly
    /// once per presentation, from PaywallView.onAppear. tab, days_since_install,
    /// subscription, and activation state ship as auto-injected globals / user
    /// properties, so they are not duplicated on the event itself.
    func trackPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source
        ])
    }

    /// Call when paywall is dismissed without purchasing. `source` stays the
    /// placement so the viewed->dismissed funnel joins; `reason` carries how it
    /// was dismissed ("declined" explicit no-thanks, "back" back navigation,
    /// "closed" sheet close).
    func trackPaywallDismissed(timeOnPaywallSec: Int, source: String, reason: String = "closed") {
        logEvent("paywall_dismissed", parameters: [
            "time_on_paywall_sec": timeOnPaywallSec,
            "source": source,
            "reason": reason,
            "days_since_install": session.daysSinceInstall,
            "trial_converted": defaults.string(forKey: Key.trialConverted) ?? "pending"
        ])
    }

    /// Call when user taps subscribe/CTA button on paywall. `source` is the same
    /// placement string passed to `trackPaywallViewed` — without it the
    /// viewed→CTA→purchase conversion cannot be scored per placement, which is
    /// the only reason the source dimension exists.
    func trackPaywallCTATapped(productID: String, price: String, source: String) {
        logEvent("paywall_cta_tapped", parameters: [
            "product_id": productID,
            "price": price,
            "source": source,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
    }

    /// Billing period as a controlled value. Never derive this from display copy:
    /// the plan labels are Firebase Remote Config strings, so a copy experiment
    /// would silently retag every yearly selection as monthly.
    enum BillingPeriod: String {
        case yearly
        case monthly
    }

    /// Call when user toggles between yearly / monthly plans on the paywall
    /// (before the final CTA tap). Lets us see plan-selection bias separately
    /// from final purchase intent.
    func trackPaywallPlanSelected(productID: String, period: BillingPeriod, price: String) {
        logEvent("paywall_plan_selected", parameters: [
            "product_id": productID,
            "period": period.rawValue,
            "price": price,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Controlled paywall failure cause. Never a substring match on a
    /// user-facing message — those are Remote Config copy and every post-CTA
    /// failure fell through to `unknown`.
    enum PaywallErrorType: String {
        case productsUnavailable = "products_unavailable"
        case network
        case purchaseFailed = "purchase_failed"
        case purchasePending = "purchase_pending"
        case paymentDeclined = "payment_declined"
        case cancelled
        case notPermitted = "not_permitted"
        case restoreFailed = "restore_failed"
        case unknown
    }

    /// Call when paywall hits an error: products fail to load, restore fails,
    /// network times out, or payment is declined. Distinct from `purchase_failed`
    /// which is post-CTA only.
    func trackPaywallError(errorType: PaywallErrorType, source: String, timeOnPaywallSec: Int) {
        logEvent("paywall_error", parameters: [
            "error_type": errorType.rawValue,
            "source": source,
            "time_on_paywall_sec": timeOnPaywallSec,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call after a successful StoreKit purchase. Emits `purchase_completed`.
    /// `grossRevenue` is the gross DISPLAY price in major units (NOT Apple net
    /// proceeds); authoritative revenue moves server-side later.
    /// `isFreeTrialStart` marks a purchase that opened Apple's $0 introductory
    /// trial: nothing was charged, so gross_revenue ships as 0 and the paid-only
    /// user-property mutations are skipped — the paid activation is recorded at
    /// the trial→paid conversion via `subscription_renewed`.
    /// `transactionIDHash` is a one-way hash of the StoreKit transaction id for
    /// dedupe — never the raw id.
    func trackPurchaseCompleted(
        productID: String,
        billingPeriod: String,
        grossRevenue: Double,
        currency: String,
        isTrialConversion: Bool,
        isFreeTrialStart: Bool,
        transactionIDHash: String
    ) {
        logEvent("purchase_completed", parameters: [
            "product_id": productID,
            "billing_period": billingPeriod,
            "gross_revenue": isFreeTrialStart ? 0 : grossRevenue,
            "currency": currency,
            "trial_converted": isTrialConversion ? "yes" : "no",
            "is_free_trial": isFreeTrialStart ? "yes" : "no",
            "transaction_id_hash": transactionIDHash
        ])

        if isTrialConversion {
            setUserProperty("trial_converted", value: "yes")
            defaults.set("yes", forKey: Key.trialConverted)
        }

        // A $0 trial start is not a paid activation: subscription_status stays
        // "trial" (maintained by updateSubscriptionProperties), renewal_count
        // stays 0, and the subscription age anchors at the first PAID period.
        guard !isFreeTrialStart else { return }

        if defaults.object(forKey: Key.subscriptionStartDate) == nil {
            defaults.set(Date(), forKey: Key.subscriptionStartDate)
        }

        let renewals = defaults.integer(forKey: Key.renewalCount) + 1
        defaults.set(renewals, forKey: Key.renewalCount)

        setUserProperty("subscription_status", value: "pro")
        setUserProperty("renewal_count", value: "\(renewals)")
        updateMonthsSubscribed()
    }

    /// Call on every observation of an active entitlement (each status refresh).
    /// Real renewals — including the trial→paid conversion — land while the app
    /// is closed and their transactions are drained by
    /// processUnfinishedTransactions() before the Transaction.updates listener
    /// can observe them, so renewal detection lives here on the refresh path:
    /// the first observed expiration is stored as a baseline (that observation
    /// is the initial purchase/restore, covered by purchase_completed) and the
    /// event fires only when the user was entitled at the previous check AND the
    /// expiration moved later, i.e. Apple extended the period. When the previous
    /// status was trial, this renewal IS the trial→paid conversion
    /// (trial_converted=yes). Renewals missed between launches collapse into one
    /// event — the best client-side approximation without a server webhook.
    /// Moves the renewal baseline forward without emitting an event. Called by
    /// the purchase flow before refreshStatus so a plan-change charge is
    /// reported once (purchase_completed), not also as subscription_renewed.
    func advanceRenewalBaseline(to expiration: Date) {
        defaults.set(expiration, forKey: Key.lastRenewalExpirationDate)
    }

    func trackSubscriptionRenewed(newExpirationDate: Date) {
        let previousExpiration = defaults.object(forKey: Key.lastRenewalExpirationDate) as? Date
        let previousStatus = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"
        defaults.set(newExpirationDate, forKey: Key.lastRenewalExpirationDate)

        let wasEntitled = previousStatus == "trial" || previousStatus == "pro"
            || previousStatus == "billing_grace"
        // Late trial→paid conversion: the trial was observed expired before
        // Apple's charge posted (trial_converted persisted "no"), then the
        // entitlement reappeared with a later expiration — that charge IS the
        // conversion and must not be dropped by the wasEntitled guard.
        let isLateTrialConversion = previousStatus == "expired"
            && defaults.string(forKey: Key.trialConverted) == "no"
        // 60s tolerance absorbs StoreKit reporting the same period end with
        // sub-minute jitter across refreshes.
        guard let previousExpiration, wasEntitled || isLateTrialConversion,
              newExpirationDate.timeIntervalSince(previousExpiration) > 60 else { return }

        // First paid period for trial converts: anchor the subscription age
        // here since their purchase_completed (trial start) no longer anchors it.
        if defaults.object(forKey: Key.subscriptionStartDate) == nil {
            defaults.set(Date(), forKey: Key.subscriptionStartDate)
        }

        let renewals = defaults.integer(forKey: Key.renewalCount) + 1
        defaults.set(renewals, forKey: Key.renewalCount)

        updateMonthsSubscribed()

        logEvent("subscription_renewed", parameters: [
            "months_subscribed": monthsSubscribed,
            "renewal_count": renewals,
            "total_sessions": session.totalSessions,
            "trial_converted": (previousStatus == "trial" || isLateTrialConversion) ? "yes" : "no"
        ])

        // updateSubscriptionProperties only flips trial_converted on a
        // trial→subscribed flip, so the late-conversion path must flip it here
        // or the paying convert stays recorded as a lost trial forever.
        if isLateTrialConversion {
            setUserProperty("trial_converted", value: "yes")
            defaults.set("yes", forKey: Key.trialConverted)
        }

        setUserProperty("renewal_count", value: "\(renewals)")
    }

    /// Controlled voluntary-churn reason. `unknown` is used when the cancel is
    /// inferred from a client status flip rather than an explicit user choice.
    enum CancellationReason: String {
        case tooExpensive = "too_expensive"
        case notUsing = "not_using"
        case missingFeature = "missing_feature"
        case foundAlternative = "found_alternative"
        case technical
        case billing
        case unknown
    }

    /// Call when paid access is lost (voluntary churn). `cancellation_reason` is a
    /// controlled enum — never free text. Authoritative cancel truth needs a store
    /// webhook (server-side); until then this is client-inferred from a status flip
    /// and defaults the reason to `unknown`.
    func trackSubscriptionCancelled(reason: CancellationReason = .unknown) {
        // months_subscribed must be read BEFORE subscription_status flips to
        // expired: tenure-at-churn is the question this event exists for, and the
        // user property it would otherwise have to be joined against is
        // overwritten on the next line.
        logEvent("subscription_cancelled", parameters: [
            "cancellation_reason": reason.rawValue,
            "months_subscribed": monthsSubscribed,
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("subscription_status", value: "expired")
    }

    /// Call when a paid activation happens WITHOUT a free trial (a direct
    /// purchase, or a re-subscribe with no new trial). Marks the cohort so
    /// "non-trial activated" users are queryable, and records acquisition path.
    func trackNonTrialActivation(productID: String, billingPeriod: String) {
        logEvent("non_trial_activation", parameters: [
            "product_id": productID,
            "billing_period": billingPeriod,
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("acquired_via_trial", value: "no")
    }

    /// Call when a still-active subscription is found with auto-renew turned off
    /// (cancelled but not yet lapsed). Client-inferred from StoreKit renewal
    /// status on app open; authoritative cancel truth still needs a store webhook.
    func trackSubscriptionCancelDetected(daysUntilExpiry: Int) {
        logEvent("subscription_cancel_detected", parameters: [
            "days_until_expiry": daysUntilExpiry,
            "was_activated": session.isActivated ? 1 : 0,
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("auto_renew", value: "off")
    }

    /// Call when restore purchases is attempted.
    func trackRestoreAttempted(success: Bool) {
        logEvent("restore_attempted", parameters: [
            "success": success ? 1 : 0,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Controlled post-CTA purchase-failure reason. Never a raw error_domain/code.
    enum PurchaseFailureReason: String {
        case userCancelled = "user_cancelled"
        case paymentDeclined = "payment_declined"
        case networkError = "network_error"
        case verification
        /// Ask to Buy / SCA challenge / deferred approval. A normal family-account
        /// state, so these CTA taps must land somewhere instead of vanishing.
        case pending
        /// A StoreKit outcome this build does not know about.
        case unknown
    }

    /// Call when a post-CTA purchase attempt fails. `failure_reason` is a
    /// controlled enum so paywall friction can be cut by reason without leaking
    /// raw StoreKit error domains/codes.
    func trackPurchaseFailed(productID: String, reason: PurchaseFailureReason) {
        logEvent("purchase_failed", parameters: [
            "product_id": productID,
            "failure_reason": reason.rawValue
        ])
    }

    /// Update subscription-related user properties. Call after subscription status changes.
    func updateSubscriptionProperties(status: SubscriptionManager.Status) {
        let previousStatus = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"

        let statusLabel: String
        let userTier: String
        switch status {
        case .trial(let expiration):
            statusLabel = "trial"
            userTier = "trial"
            let daysRemaining = max(0, Date.cal.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
            trackTrialDayCheck(daysRemaining: daysRemaining)
            // trackTrialStarted self-dedupes via the persisted trialStartedTracked
            // flag, so call it on every trial observation. The old
            // previousStatus == "unknown" gate missed the event whenever the
            // first observed status was already non-"unknown".
            trackTrialStarted(daysRemaining: daysRemaining)
        case .subscribed:
            statusLabel = "pro"
            userTier = "pro"
            // .trial -> .subscribed is the trial->paid conversion: flip the
            // trial_converted user property from "pending" to "yes" so conversion
            // is queryable per user, not only inferable from the event stream.
            if previousStatus == "trial" {
                setUserProperty("trial_converted", value: "yes")
                defaults.set("yes", forKey: Key.trialConverted)
            }
            updateMonthsSubscribed()
        case .billingGrace:
            statusLabel = "billing_grace"
            userTier = "pro"
        case .expired:
            statusLabel = "expired"
            userTier = "free"
            if previousStatus == "pro" || previousStatus == "billing_grace" {
                trackSubscriptionCancelled()
            }
            if previousStatus == "trial" {
                trackTrialExpired()
            }
        case .unknown:
            statusLabel = "unknown"
            userTier = "free"
        }

        defaults.set(statusLabel, forKey: Key.lastKnownStatus)
        setUserProperty("subscription_status", value: statusLabel)
        setUserProperty("user_tier", value: userTier)
    }

    private var monthsSubscribed: Int {
        guard let startDate = defaults.object(forKey: Key.subscriptionStartDate) as? Date else { return 0 }
        return Date.cal.dateComponents([.month], from: startDate, to: Date()).month ?? 0
    }

    /// Days since the user first started a subscription (0 for non-subscribers).
    /// Emitted on every session_start so analysts can build month-2, month-3 paid
    /// retention cohorts directly in PostHog without post-hoc event joins.
    private var subscriptionAgeDays: Int {
        guard let startDate = defaults.object(forKey: Key.subscriptionStartDate) as? Date else { return 0 }
        return Date.cal.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }

    private func updateMonthsSubscribed() {
        setUserProperty("months_subscribed", value: "\(monthsSubscribed)")
    }

    // MARK: - Engagement Level (L28 / Power-User Curve)

    /// PostHog's recommended engagement buckets for consumer apps. Computed on every
    /// session_start so analysts can segment cohorts by power user vs disengaging
    /// without having to derive it from raw streak + lifetime action joins.
    private enum EngagementLevel: String {
        case powerUser = "power_user"
        case casual = "casual"
        case atRisk = "at_risk"
        case disengaging = "disengaging"
    }

    /// Deterministic bucketing. Ranked by most-concerning first so a recently-lapsed
    /// power user gets classified as `at_risk` / `disengaging`, not `power_user`.
    private func computeEngagementLevel() -> EngagementLevel {
        let daysSinceLast = session.daysSinceLastSession ?? 0
        if daysSinceLast >= 7 { return .disengaging }
        if daysSinceLast >= 4 { return .atRisk }
        let streak = session.streakDays
        let lifetime = session.lifetimeCoreActions
        if streak >= 14 && lifetime >= 50 { return .powerUser }
        return .casual
    }

    // MARK: - Churn Health Score (0-100)

    /// Composite churn-risk score. 100 = healthy, 0 = critical churn risk.
    /// Weighted per Supportbench / Cerebral Ops "customer health score" research:
    /// recency (35), streak break (20), weekly activity (25), notifications off (20).
    /// 4-dimension composites show ~34% better churn-prediction accuracy than single metrics.
    private func computeChurnHealthScore(pushAuthorized: Bool) -> Int {
        var score = 100

        // Recency — the biggest single predictor.
        let daysSinceLast = session.daysSinceLastSession ?? 0
        if daysSinceLast >= 7 { score -= 35 }
        else if daysSinceLast >= 4 { score -= 20 }
        else if daysSinceLast >= 2 { score -= 10 }

        // Recent streak break (recorded by SessionTracker when the streak resets).
        if let broken = session.previousStreakBeforeBreak, broken >= 3 {
            score -= 20
        }

        // Weekly frequency floor.
        if session.weeklyActiveDays <= 1 { score -= 25 }
        else if session.weeklyActiveDays <= 2 { score -= 10 }

        // Notifications off — user has cut the re-engagement channel.
        if !pushAuthorized { score -= 20 }

        return max(0, min(100, score))
    }

    private func churnBucket(_ score: Int) -> String {
        switch score {
        case 80...100: return "healthy"
        case 60...79:  return "watching"
        case 40...59:  return "at_risk"
        default:       return "critical"
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 10. Emotional / NPS
    // ══════════════════════════════════════════════════════════════════════

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 11. Friction Metrics
    // ══════════════════════════════════════════════════════════════════════

    /// Track any error that occurs in the app.
    func trackError(type: String, screen: AppFeature, message: String = "") {
        logEvent("error_occurred", parameters: [
            "error_type": type,
            "screen": screen.rawValue,
            "message": String(message.prefix(100))
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 12. Device & Data Events
    // ══════════════════════════════════════════════════════════════════════

    func trackDeviceDetected(deviceType: String, metricsCount: Int, isActive: Bool, modelName: String? = nil) {
        logEvent("device_detected", parameters: [
            "device_type": deviceType,
            "metrics_count": metricsCount,
            "is_active": isActive ? 1 : 0,
            "device_model_name": modelName ?? "unknown"
        ])
    }

    func updateDeviceProperties(activeCount: Int, primaryDevice: String) {
        setUserProperty("connected_device_count", value: "\(activeCount)")
        setUserProperty("primary_device", value: primaryDevice)
    }

    func trackDataSync(metricsCount: Int, newSamplesCount: Int, durationSec: Int, isFirstSync: Bool) {
        var params: [String: Any] = [
            "metrics_count": metricsCount,
            "new_samples_count": newSamplesCount,
            "duration_sec": durationSec,
            "is_first_sync": isFirstSync ? 1 : 0
        ]
        if isFirstSync {
            params["first_sync_duration_sec"] = durationSec
        }
        logEvent("data_sync_completed", parameters: params)
    }

    func trackReportExported(score: Int, metricsCount: Int, insightsCount: Int) {
        logEvent("report_exported", parameters: [
            "score_bracket": scoreBracket(score),
            "metrics_count": metricsCount,
            "insights_count": insightsCount
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 13. Settings & Misc
    // ══════════════════════════════════════════════════════════════════════

    func trackSettingChanged(name: String, value: Any) {
        var stringValue: String
        switch value {
        case let v as Bool: stringValue = v ? "on" : "off"
        case let v as Int: stringValue = "\(v)"
        case let v as Double: stringValue = String(format: "%.0f", v)
        case let v as String: stringValue = v
        default: stringValue = String(describing: value)
        }
        // No hardcoded `screen`: most call sites are on Notifications Settings,
        // a distinct AppFeature, and the literal overrode logEvent's injection so
        // every toggle looked like it happened on the Settings root.
        logEvent("setting_changed", parameters: [
            "setting_name": name,
            "new_value": stringValue
        ])
    }

    func trackShareSheetPresented(contentType: String) {
        logEvent("share_sheet_presented", parameters: [
            "content_type": contentType,
            "screen": AppFeature.settings.rawValue
        ])
    }

    func updateNavigationDepth(_ depth: Int) {
        session.updateDepth(depth)
    }

    // Live Streaming
    func trackStreamingStarted() {
        streamingStartDate = Date()
        logEvent("streaming_started", parameters: [
            "screen": AppFeature.live.rawValue
        ])
    }

    func trackStreamingStopped() {
        var duration = 0
        if let start = streamingStartDate {
            duration = Int(Date().timeIntervalSince(start))
        }
        streamingStartDate = nil
        logEvent("streaming_stopped", parameters: [
            "screen": AppFeature.live.rawValue,
            "duration_sec": duration
        ])
    }

    func trackLiveFirstDataReceived() {
        logEvent("live_first_data_received", parameters: [
            "screen": AppFeature.live.rawValue
        ])
    }

    // Feedback
    func trackFeedbackSubmitted(category: String, textLength: Int, sentiment: String = "neutral") {
        logEvent("feedback_submitted", parameters: [
            "category": category,
            "text_length": textLength,
            "sentiment": sentiment
        ])
    }

    // Scroll depth
    func trackScrollDepth(screen: AppFeature, maxDepthPercent: Int) {
        logEvent("scroll_depth", parameters: [
            "screen": screen.rawValue,
            "max_depth_percent": maxDepthPercent,
            "tab": session.currentTab
        ])
    }

    // Section analytics.
    // `tab` is NOT set here: SectionTracker's `tab` is really the hosting SCREEN
    // and views legitimately pass non-tab AppFeatures (.categoryDetail,
    // .correlations, .weeklyReview…). Writing those into `tab` overrode
    // logEvent's global and mixed a dozen screen names into a value space that is
    // otherwise only home | live | explore | settings.
    func trackSectionViewed(section: AppSection, tab: AppFeature, durationMs: Int) {
        logEvent("section_viewed", parameters: [
            "section_id": section.rawValue,
            "screen": tab.rawValue,
            "duration_ms": durationMs,
            "session_id": session.sessionId
        ])
    }

    func trackSectionTapped(section: AppSection, tab: AppFeature, target: String) {
        logEvent("section_tapped", parameters: [
            "section_id": section.rawValue,
            "screen": tab.rawValue,
            "target_id": slugify(target),
            "target": target,
            "session_id": session.sessionId
        ])
    }

    // Subscription billing grace
    func trackBillingGraceStarted(daysSinceInstall: Int) {
        logEvent("billing_grace_started", parameters: [
            "days_since_install": daysSinceInstall
        ])
    }

    func trackBillingGraceResolved(daysInGrace: Int) {
        logEvent("billing_grace_resolved", parameters: [
            "days_in_grace": daysInGrace,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // Connectivity recovery
    func trackConnectivityRecovered(offlineDurationSec: Int, syncTriggered: Bool, backupTriggered: Bool) {
        logEvent("connectivity_recovered", parameters: [
            "offline_duration_sec": offlineDurationSec,
            "sync_triggered": syncTriggered ? 1 : 0,
            "backup_triggered": backupTriggered ? 1 : 0
        ])
    }

    // Recommendation outcome
    func trackRecommendationOutcome(category: String, metric: String, severity: String, lift24h: Double?, lift7d: Double?, wasTapped: Bool, outcome: String) {
        // lift_24h / lift_7d are percent changes measured on the user's own
        // metric series, so the raw numbers are health data and are not sent.
        // `outcome` is the classified 7-day result and the `_known` flags keep
        // evaluation coverage measurable.
        logEvent("recommendation_outcome", parameters: [
            "category": category,
            "metric": metric,
            "severity": severity,
            "was_tapped": wasTapped,
            "outcome": outcome,
            "lift_24h_known": lift24h == nil ? 0 : 1,
            "lift_7d_known": lift7d == nil ? 0 : 1
        ])
    }

    // Notification opened
    func trackNotificationOpened(identifier: String) {
        let defaults = UserDefaults.standard

        // hook_category is only meaningful when it maps onto a real HookCategory
        // case. Anything else (no stored value, legacy "unknown") collapses to
        // "none" so the property is enum-clean for Amplitude breakdowns.
        let storedHook = defaults.string(forKey: "healthpulse.notif.hook.\(identifier)")
        let hookCategory = Copy.Notifications.HookCategory(rawValue: storedHook ?? "").map(\.rawValue) ?? "none"

        // Time from the notification's real FIRE time to the open. The stored
        // stamp is the trigger's fire date (written by trackNotificationScheduled),
        // so this is a response latency, not the enqueue lead time.
        let firedTimestamp = defaults.double(forKey: "healthpulse.notif.sent.\(identifier)")
        let timeToOpenKnown = firedTimestamp > 0
        let timeToOpenMin = timeToOpenKnown
            ? max(Int(Date().timeIntervalSince1970 - firedTimestamp) / 60, 0)
            : 0

        let params: [String: Any] = [
            // PII-safe id: any embedded HealthMetric raw value is collapsed to its
            // parent category, so "healthpulse.spike.bloodPressureSystolic.high"
            // ships as "healthpulse.spike.cardiovascular.high".
            "notification_id": sanitizedNotificationID(identifier),
            "notification_type": NotificationManager.notificationType(identifier),
            "hook_category": hookCategory,
            "alert_metric": alertMetricSegment(identifier),
            "time_to_open_min": timeToOpenMin,
            "time_to_open_known": timeToOpenKnown ? 1 : 0
        ]
        logEvent("notification_opened", parameters: params)

        // Stage this open for downstream goal attribution: the next core action
        // within notification_conversion_window_hours credits this notification as
        // a conversion. Fixed keys (not per-id) so the most recent open is the
        // active attribution. Raw id is stored so the converted event can derive
        // notification_type; it is sanitized before it ships.
        defaults.set(identifier, forKey: "healthpulse.notif.pendingConv.id")
        defaults.set(Date().timeIntervalSince1970, forKey: "healthpulse.notif.pendingConv.at")

        // Clean up stored context
        defaults.removeObject(forKey: "healthpulse.notif.hook.\(identifier)")
        defaults.removeObject(forKey: "healthpulse.notif.sent.\(identifier)")
    }

    /// Credit a prior notification open with a downstream goal completion when it
    /// lands inside the remote-config conversion window. Called from the canonical
    /// value action so a notification that brought the user back to actually *do*
    /// something is counted, not a mere app open. One credit per open: the pending
    /// marker is cleared whether or not it converts (so it never double-counts or
    /// leaks into a later organic action).
    private func attributePendingNotificationConversion(goal: String) {
        let openedAt = defaults.double(forKey: "healthpulse.notif.pendingConv.at")
        guard openedAt > 0,
              let rawID = defaults.string(forKey: "healthpulse.notif.pendingConv.id") else { return }

        defaults.removeObject(forKey: "healthpulse.notif.pendingConv.id")
        defaults.removeObject(forKey: "healthpulse.notif.pendingConv.at")

        let windowHours = Double(RemoteConfigManager.shared.notificationConversionWindowHours)
        let elapsedHours = (Date().timeIntervalSince1970 - openedAt) / 3600
        guard elapsedHours <= windowHours else { return }
        trackNotificationConverted(identifier: rawID, goal: goal)
    }

    /// Notification surfaced in foreground (willPresent). Mirrors trackNotificationOpened's
    /// latency + metric-split shape but does NOT clear the stored sent/hook keys, because a
    /// later open still needs them. Analytics-only; the store write lives in HealthDataStore.
    func trackNotificationPresented(identifier: String) {
        let defaults = UserDefaults.standard
        let type = NotificationManager.notificationType(identifier)

        // Measured from the trigger's FIRE date, not from enqueue time: a push
        // scheduled 72h ahead used to report latency_minutes ~4320, which is the
        // trigger lead time wearing a response-latency name. Clamped at 0 because
        // willPresent can run a hair before the stored fire date.
        let firedTimestamp = defaults.double(forKey: "healthpulse.notif.sent.\(identifier)")
        let now = Date()
        let latencyKnown = firedTimestamp > 0
        let latencyMinutes: Int = latencyKnown
            ? max(Int(now.timeIntervalSince1970 - firedTimestamp) / 60, 0)
            : 0

        let cal = Date.cal

        logEvent("notification_presented", parameters: [
            "notification_id": sanitizedNotificationID(identifier),
            "notification_type": type,
            "latency_minutes": latencyMinutes,
            "latency_known": latencyKnown ? 1 : 0,
            "hour_presented_local": cal.component(.hour, from: now),
            "day_of_week": cal.component(.weekday, from: now),
            "alert_metric": alertMetricSegment(identifier),
            "alert_subtype": alertSubtypeSegment(identifier)
        ])
    }

    /// User swipe-dismissed the notification (terminal funnel signal, no store write).
    /// Fired from didReceive when actionIdentifier == UNNotificationDismissActionIdentifier.
    func trackNotificationDismissed(identifier: String) {
        let type = NotificationManager.notificationType(identifier)

        logEvent("notification_dismissed", parameters: [
            "notification_id": sanitizedNotificationID(identifier),
            "notification_type": type,
            "alert_metric": alertMetricSegment(identifier),
            "alert_subtype": alertSubtypeSegment(identifier)
        ])
    }

    /// Notification families whose identifier carries a HealthMetric rawValue in
    /// its third dot segment. Matched through `NotificationManager.notificationType`
    /// so the prefix scheme keeps one source of truth.
    private static let alertMetricTypes: Set<String> = [
        "safety_triage", "spike", "trend_reversal", "celebration", "alert"
    ]

    /// `alert_metric` for a notification identifier, or "none" when the id is not
    /// an alert. A blind `parts[2]` slice shipped "day1", "2h", "gettingStarted"
    /// and "notWorn" as metric values, and because alert_metric is in
    /// `metricParameterKeys` that junk passed through untouched while real
    /// metrics were collapsed to a category — so the breakdown mixed the two.
    private func alertMetricSegment(_ identifier: String) -> String {
        guard Self.alertMetricTypes.contains(NotificationManager.notificationType(identifier)) else {
            return "none"
        }
        let parts = identifier.split(separator: ".")
        return parts.count >= 3 ? String(parts[2]) : "none"
    }

    /// `alert_subtype` (severity/direction) for a notification identifier, or
    /// "none" when the id is not an alert. Guarded like `alertMetricSegment`
    /// because a blind `parts[3]` slice gave unrelated families a subtype that
    /// shares no value space with a severity — the watch not-worn alarm shipped
    /// "scheduled" as its alert_subtype.
    private func alertSubtypeSegment(_ identifier: String) -> String {
        guard Self.alertMetricTypes.contains(NotificationManager.notificationType(identifier)) else {
            return "none"
        }
        let parts = identifier.split(separator: ".")
        return parts.count >= 4 ? String(parts[3]) : "none"
    }

    /// center.add() threw. Distinct from notification_suppressed (cap/filter). `error` is the
    /// NSError.localizedDescription, not user-facing. Fired from the schedule error branch.
    func trackNotificationFailed(type: String, identifier: String, error: String) {
        logEvent("notification_failed", parameters: [
            "notification_type": type,
            "notification_id": sanitizedNotificationID(identifier),
            "error": error
        ])
    }

    /// A notification drove a downstream goal completion. The conversion-window decision
    /// belongs to the caller (RemoteConfigManager.shared.notificationConversionWindowHours);
    /// this method only records the attributed event. Called from
    /// `attributePendingNotificationConversion`, which `trackCoreAction` fires on
    /// every completed core action.
    func trackNotificationConverted(identifier: String, goal: String) {
        logEvent("notification_converted", parameters: [
            "notification_id": sanitizedNotificationID(identifier),
            "notification_type": NotificationManager.notificationType(identifier),
            "goal": goal
        ])
    }

    // Monetization signals

    /// `screen` is where the user hit the wall. Pass nil from a reusable
    /// component that does not know its host (TimeRangeSelector, LockedInsightsCTA)
    /// so logEvent injects the real current screen — hardcoding .proOverlay there
    /// overrode the global and collapsed the dimension to one constant value.
    func trackPremiumFeatureAttempted(feature: String, screen: AppFeature? = nil) {
        var params: [String: Any] = [
            "feature": feature,
            "days_since_install": session.daysSinceInstall
        ]
        if let screen { params["screen"] = screen.rawValue }
        logEvent("premium_feature_attempted", parameters: params)
    }

    func trackLastMeaningfulAction(action: String, screen: AppFeature) {
        setUserProperty("last_meaningful_action", value: action)
        setUserProperty("last_active_screen", value: screen.rawValue)
    }

    // Discovery
    func trackDiscoveryShown(count: Int, types: [String]) {
        logEvent("discovery_shown", parameters: [
            "count": count,
            "types": types.joined(separator: ","),
            "days_since_install": session.daysSinceInstall
        ])
    }

    func trackDiscoveryPageViewed(type: String, index: Int) {
        logEvent("discovery_page_viewed", parameters: [
            "type": type,
            "page_index": index
        ])
    }

    /// No `pages_viewed`: Discovery is a non-dismissable full-screen cover whose
    /// only exit is the last page's Continue button, so the count was always equal
    /// to `total_pages`. Depth still ships on feature_close as max_page_viewed.
    func trackDiscoveryCompleted(totalPages: Int) {
        logEvent("discovery_completed", parameters: [
            "total_pages": totalPages,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 14. Intelligence Suite
    // ══════════════════════════════════════════════════════════════════════

    func trackHealthStateTimelineViewed(currentState: String, daysInState: Int, totalStates: Int) {
        logEvent("health_state_timeline_viewed", parameters: [
            "current_state": currentState,
            "days_in_state": daysInState,
            "total_states": totalStates,
            "screen": AppFeature.healthStateTimeline.rawValue
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 15. Dashboard Metrics (Retention/Stickiness/Engagement)
    // ══════════════════════════════════════════════════════════════════════

    /// Fires once per calendar day to power DAU/WAU/MAU in PostHog.
    /// Call from session start. Client-side dedupe by local calendar day so a
    /// second foreground on the same day does not re-emit daily_active.
    func trackDailyActiveUser() {
        let today = Date.cal.startOfDay(for: Date())
        if let lastDay = defaults.object(forKey: Key.dailyActiveLastDate) as? Date,
           Date.cal.isDate(lastDay, inSameDayAs: today) {
            return
        }
        defaults.set(today, forKey: Key.dailyActiveLastDate)

        logEvent("daily_active", parameters: [
            "session_source": session.currentSessionSource.rawValue,
            "weekly_active_days": session.weeklyActiveDays,
            "app_version": Self.cachedAppVersion
        ])
    }

    /// Call when the app is opened via a deep link (laso:// widget/Live Activity
    /// links). Attribution counterpart of the session_source tag set in
    /// ContentView.handleDeepLink.
    func trackDeepLinkOpened(url: String, source: String) {
        logEvent("deep_link_opened", parameters: [
            "url": url,
            "source": source
        ])
    }

    /// Enqueue/intent-to-send floor (when we schedule a local notification), not
    /// delivered reach. `fireDate` is the trigger's real fire time — it is what
    /// notification_presented / notification_opened measure their latency from,
    /// so an enqueue stamp there reported the trigger lead time instead.
    ///
    /// Deduped per identifier per fire day: schedulers replace an already-pending
    /// request idempotently (WatchMonitor re-runs on every heart-rate delivery,
    /// housekeeping re-enqueues the repeating summaries on every dashboard
    /// refresh), and counting each replacement as a fresh enqueue let
    /// watch_monitor swamp the event and broke every scheduled→presented rate.
    func trackNotificationScheduled(type: String, identifier: String, fireDate: Date, hookCategory: String? = nil) {
        let defaults = UserDefaults.standard

        if let hook = hookCategory {
            defaults.set(hook, forKey: "healthpulse.notif.hook.\(identifier)")
        }
        defaults.set(fireDate.timeIntervalSince1970, forKey: "healthpulse.notif.sent.\(identifier)")

        let dayKey = "healthpulse.notif.schedday.\(identifier)"
        let fireDay = Date.cal.startOfDay(for: fireDate)
        if let lastFireDay = defaults.object(forKey: dayKey) as? Date,
           Date.cal.isDate(lastFireDay, inSameDayAs: fireDay) {
            return
        }
        defaults.set(fireDay, forKey: dayKey)

        var params: [String: Any] = [
            "notification_type": type,
            // Same sanitized id as opened/presented/dismissed/suppressed, so the
            // scheduled->opened funnel joins on notification_id.
            "notification_id": sanitizedNotificationID(identifier),
            // Transitional dual-param: notification_id previously shipped as this
            // 16-hex hash, so charts keyed on the old id-space can bridge the
            // format flip. Remove once the pre-flip scheduled cohort has aged out
            // and dashboards read notification_id.
            "notification_id_legacy": Self.sha256Hash16(identifier),
            "alert_metric": alertMetricSegment(identifier),
            "lead_time_min": max(Int(fireDate.timeIntervalSinceNow) / 60, 0)
        ]
        if let hook = hookCategory {
            params["hook_category"] = hook
        }
        logEvent("notification_scheduled", parameters: params)
    }

    /// A remote push carried a route this build cannot map. Deliberately NOT a
    /// notification_suppressed: this runs from `didReceive`, i.e. the push was
    /// delivered AND opened, so filing it as a pre-delivery suppression polluted
    /// the suppression-reason breakdown the cap/filter gates own.
    func trackPushRouteUnresolved(route: String) {
        logEvent("push_route_unresolved", parameters: [
            "route": route
        ])
    }

    /// Stable, non-reversible SHA256 hash truncated to 16 hex chars. Used for
    /// dedupe/join keys (transaction ids, referral codes) without transmitting
    /// the raw value.
    static func sha256Hash16(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    /// Track when a notification is suppressed before delivery.
    /// Gives visibility into cap/filter behavior that would otherwise be invisible.
    func trackNotificationSuppressed(type: String, identifier: String, reason: String) {
        logEvent("notification_suppressed", parameters: [
            "notification_type": type,
            "notification_id": sanitizedNotificationID(identifier),
            "reason": reason
        ])
    }

    /// A non-critical one-shot's fire time fell inside quiet hours and was
    /// deferred to the window's end rather than dropped.
    func trackNotificationDeferredQuietHours(type: String, identifier: String) {
        logEvent("notification_deferred_quiet_hours", parameters: [
            "notification_type": type,
            // Transitional dual-param: the old inline capture sent this value as
            // "type" and saved breakdowns may still filter on it. Remove once
            // dashboards are migrated to notification_type.
            "type": type,
            "notification_id": sanitizedNotificationID(identifier)
        ])
    }

    /// The dynamic per-day notification budget could not be computed (no store
    /// or off the main thread), so the static per-call budget was used.
    func trackNotificationBudgetFallback(identifier: String, reason: String, staticBudget: Int) {
        logEvent("notification_budget_fallback", parameters: [
            "notification_id": sanitizedNotificationID(identifier),
            "reason": reason,
            "static_budget": staticBudget
        ])
    }

    /// Track HealthKit sync performance for the sync duration chart.
    func trackSyncPerformance(durationMs: Int, metricsCount: Int, samplesLoaded: Int, isIncremental: Bool) {
        logEvent("sync_performance", parameters: [
            "duration_ms": durationMs,
            "metrics_count": metricsCount,
            "samples_loaded": samplesLoaded,
            "is_incremental": isIncremental ? 1 : 0
        ])
    }

    /// Track ML analysis performance for the analysis duration chart.
    func trackMLAnalysisPerformance(durationMs: Int, componentsRun: Int, dataPointsUsed: Int) {
        logEvent("ml_analysis_performance", parameters: [
            "duration_ms": durationMs,
            "components_run": componentsRun,
            "data_points_used": dataPointsUsed
        ])
    }

    /// Track which pro features drive conversions.
    func trackProFeatureFunnel(feature: String, step: String) {
        logEvent("pro_feature_funnel", parameters: [
            "feature": feature,
            "step": step,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 16. Health Data Pipeline Quality
    // ══════════════════════════════════════════════════════════════════════

    /// Call when HealthKit authorization is requested.
    func trackHealthPermissionRequested(metrics: [String]) {
        logEvent("health_permission_requested", parameters: [
            "metrics_requested": metrics.count,
            "includes_cycle_data": metrics.contains("menstrual_flow") ? 1 : 0,
            "includes_ecg": metrics.contains("electrocardiogram") ? 1 : 0,
            "metric_preview": metrics.prefix(5).joined(separator: ","),
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call after HealthKit authorization response. The COUNT ships as
    /// `granted_count`: `granted` is a 0/1 boolean on every other permission
    /// event, and Amplitude treats one property name as one value space, so a
    /// count here made every "granted = 1" filter mean two different things.
    func trackHealthPermissionResult(granted: Int, denied: Int, total: Int) {
        logEvent("health_permission_result", parameters: [
            "granted": granted > 0,
            "granted_count": granted,
            "denied": denied,
            "total": total,
            "grant_rate": total > 0 ? Double(granted) / Double(total) : 0
        ])
    }

    /// Call when a health source (Apple Watch, Oura, etc.) is detected as connected.
    func trackSourceConnected(sourceType: String, metricsAvailable: Int) {
        logEvent("source_connected", parameters: [
            "source_type": sourceType,
            "metrics_available": metricsAvailable,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call after each sync to track data pipeline health.
    func trackDataPipelineQuality(
        metricsAvailable: Int,
        metricsMissing: Int,
        dataCoveragePercent: Int,
        lastSyncAgeSec: Int,
        hasEnoughForScore: Bool
    ) {
        let freshnessBucket: String
        switch lastSyncAgeSec {
        case ..<0:
            freshnessBucket = "unknown"
        case 0..<3_600:
            freshnessBucket = "fresh"
        case 3_600..<21_600:
            freshnessBucket = "warm"
        case 21_600..<86_400:
            freshnessBucket = "aging"
        default:
            freshnessBucket = "stale"
        }
        let coverageBucket: String
        switch dataCoveragePercent {
        case 85...100:
            coverageBucket = "excellent"
        case 65..<85:
            coverageBucket = "good"
        case 40..<65:
            coverageBucket = "partial"
        default:
            coverageBucket = "thin"
        }

        logEvent("data_pipeline_quality", parameters: [
            "metrics_available": metricsAvailable,
            "metrics_missing": metricsMissing,
            "data_coverage_pct": dataCoveragePercent,
            "last_sync_age_sec": lastSyncAgeSec,
            "enough_for_score": hasEnoughForScore ? 1 : 0,
            "coverage_bucket": coverageBucket,
            "freshness_bucket": freshnessBucket
        ])

        // Set user properties for cohort segmentation
        let sufficiency = hasEnoughForScore ? "sufficient" : "insufficient"
        setUserProperty("data_sufficiency", value: sufficiency)
        setUserProperty("data_coverage_bucket", value: coverageBucket)
        setUserProperty("data_freshness", value: freshnessBucket)
        setUserProperty("metrics_available_count", value: "\(metricsAvailable)")
    }

    /// Call when first score is generated. critical activation event.
    func trackFirstScoreGenerated(score: Int, timeSinceInstallSec: Int, metricsUsed: Int) {
        logEvent("first_score_generated", parameters: [
            "score_bracket": scoreBracket(score),
            "time_since_install_sec": timeSinceInstallSec,
            "metrics_used": metricsUsed
        ])
    }

    /// Call when stale data is detected (no new samples for >24h).
    func trackStaleDataDetected(staleSinceHours: Int, metric: String) {
        logEvent("stale_data_detected", parameters: [
            "stale_since_hours": staleSinceHours,
            "metric": metric
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 17. Trust Signals
    // ══════════════════════════════════════════════════════════════════════

    /// Call when user views a score explanation or methodology page.
    func trackExplanationViewed(type: String, screen: AppFeature) {
        logEvent("explanation_viewed", parameters: [
            "explanation_type": type,
            "screen": screen.rawValue,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call when user views the privacy/data policy page.
    func trackPrivacyPageViewed(source: String) {
        logEvent("privacy_page_viewed", parameters: [
            "source": source,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 18. Recommendation Lifecycle
    // ══════════════════════════════════════════════════════════════════════

    /// Call when a recommendation (Today's Action, insight action) is shown.
    func trackRecommendationViewed(type: String, metric: String, difficulty: String = "") {
        logEvent("recommendation_viewed", parameters: [
            "recommendation_type": type,
            "metric": metric,
            "difficulty": difficulty.isEmpty ? "unspecified" : difficulty
        ])
    }

    /// Call when user starts acting on a recommendation.
    func trackRecommendationStarted(type: String, metric: String) {
        logEvent("recommendation_started", parameters: [
            "recommendation_type": type,
            "metric": metric
        ])
    }

    /// Call when user completes a recommendation action.
    func trackRecommendationCompleted(type: String, metric: String, delaySec: Int = 0) {
        logEvent("recommendation_completed", parameters: [
            "recommendation_type": type,
            "metric": metric,
            "delay_sec": delaySec
        ])
    }

    /// Call when user skips/dismisses a recommendation.
    func trackRecommendationSkipped(type: String, metric: String, reason: String = "") {
        logEvent("recommendation_skipped", parameters: [
            "recommendation_type": type,
            "metric": metric,
            "reason": reason.isEmpty ? "unspecified" : reason
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 19. Feature Lifecycle Metrics
    // ══════════════════════════════════════════════════════════════════════

    func trackWorkoutPlanOpened(
        plan: WorkoutPlan,
        recoveryBand: WorkoutRecoveryBand,
        cyclePhase: CyclePhaseModifier?,
        screen: AppFeature
    ) {
        logEvent("workout_plan_opened", parameters: [
            "screen": screen.rawValue,
            "training_zone": plan.zone.rawValue,
            "recovery_band": recoveryBand.rawValue,
            "target_duration_min": plan.targetDuration,
            "estimated_calories": plan.estimatedCalories,
            "cycle_phase": cyclePhase?.displayName ?? "none"
        ])
    }

    func trackBreathworkProtocolSelected(_ breathingProtocol: BreathingProtocol) {
        logEvent("breathwork_protocol_selected", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "protocol_id": breathingProtocol.rawValue,
            "planned_duration_sec": Int(breathingProtocol.sessionDuration),
            "phase_count": breathingProtocol.phases.count
        ])
    }

    func trackBreathworkSessionStarted(_ breathingProtocol: BreathingProtocol, cycleCount: Int) {
        logEvent("breathwork_session_started", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "protocol_id": breathingProtocol.rawValue,
            "planned_duration_sec": Int(breathingProtocol.sessionDuration),
            "cycle_count": cycleCount
        ])
    }

    func trackBreathworkSessionPaused(
        _ breathingProtocol: BreathingProtocol,
        phase: BreathPhase,
        remainingSec: Int,
        pauseCount: Int
    ) {
        logEvent("breathwork_session_paused", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "phase": phase.rawValue,
            "remaining_sec": remainingSec,
            "pause_count": pauseCount
        ])
    }

    func trackBreathworkSessionResumed(
        _ breathingProtocol: BreathingProtocol,
        phase: BreathPhase,
        remainingSec: Int,
        pauseCount: Int
    ) {
        logEvent("breathwork_session_resumed", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "phase": phase.rawValue,
            "remaining_sec": remainingSec,
            "pause_count": pauseCount
        ])
    }

    func trackBreathworkSessionCompleted(
        _ breathingProtocol: BreathingProtocol,
        actualDurationSec: Int,
        pauseCount: Int,
        mood: PostSessionMood?
    ) {
        let plannedDurationSec = Int(breathingProtocol.sessionDuration)

        // No `completion_rate`: completeSession() only runs when the timer reaches
        // zero, so it was a constant 1.0 here. It is a real dimension only on
        // breathwork_session_abandoned.
        logEvent("breathwork_session_completed", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "protocol_id": breathingProtocol.rawValue,
            "planned_duration_sec": plannedDurationSec,
            "actual_duration_sec": actualDurationSec,
            "pause_count": pauseCount,
            "mood": mood?.rawValue.lowercased() ?? "unanswered"
        ])

        trackFeatureUsed(.completedBreathwork)
    }

    func trackBreathworkSessionAbandoned(
        _ breathingProtocol: BreathingProtocol,
        phase: BreathPhase,
        actualDurationSec: Int,
        pauseCount: Int
    ) {
        let plannedDurationSec = Int(breathingProtocol.sessionDuration)
        let completionRate = plannedDurationSec > 0
            ? min(max(Double(actualDurationSec) / Double(plannedDurationSec), 0), 1)
            : 0

        logEvent("breathwork_session_abandoned", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "protocol_id": breathingProtocol.rawValue,
            "phase": phase.rawValue,
            "planned_duration_sec": plannedDurationSec,
            "actual_duration_sec": actualDurationSec,
            "completion_rate": completionRate,
            "pause_count": pauseCount
        ])
    }

    /// Wellness-specific PMF snapshot. Emitted on every session_start with the signals
    /// research calls out as the biggest levers for health-app retention: Apple Watch
    /// pairing, daily-data completeness, permission state, and a composite churn score.
    /// Analysts can now cut every cohort by these dimensions without event joins.
    func trackUserHealthSnapshot(
        watchPaired: Bool,
        dailyCompleteness7d: Int, // 0...7 days covered
        pushAuthorized: Bool,
        notifCategoriesEnabled: Int,
        hkHeartHasData: Bool,
        hkSleepHasData: Bool,
        hkStepsHasData: Bool
    ) {
        let churnScore = computeChurnHealthScore(pushAuthorized: pushAuthorized)
        let bucket = churnBucket(churnScore)
        let completenessPct = Int((Double(dailyCompleteness7d) / 7.0 * 100).rounded())

        logEvent("user_health_snapshot", parameters: [
            "watch_paired": watchPaired ? 1 : 0,
            "daily_completeness_7d_days": dailyCompleteness7d,
            "daily_completeness_7d_pct": completenessPct,
            "push_authorized": pushAuthorized ? 1 : 0,
            "notif_categories_enabled": notifCategoriesEnabled,
            "hk_heart_has_data": hkHeartHasData ? 1 : 0,
            "hk_sleep_has_data": hkSleepHasData ? 1 : 0,
            "hk_steps_has_data": hkStepsHasData ? 1 : 0,
            "churn_health_score": churnScore,
            "churn_bucket": bucket,
            "days_since_install": session.daysSinceInstall,
            "streak_days": session.streakDays
        ])

        setUserProperty("watch_paired", value: watchPaired ? "yes" : "no")
        setUserProperty("daily_completeness_7d_pct", value: "\(completenessPct)")
        setUserProperty("push_authorized", value: pushAuthorized ? "yes" : "no")
        setUserProperty("notif_categories_enabled", value: "\(notifCategoriesEnabled)")
        setUserProperty("hk_heart_has_data", value: hkHeartHasData ? "yes" : "no")
        setUserProperty("hk_sleep_has_data", value: hkSleepHasData ? "yes" : "no")
        setUserProperty("hk_steps_has_data", value: hkStepsHasData ? "yes" : "no")
        setUserProperty("churn_health_score", value: "\(churnScore)")
        setUserProperty("churn_bucket", value: bucket)
    }

    func trackLiveActivityStateChanged(kind: String, state: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "activity_kind": kind,
            "activity_state": state
        ]
        for (key, value) in metadata {
            params[key] = value
        }
        logEvent("live_activity_state_changed", parameters: params)
    }

    /// Emitted when a user taps an App Intent button on a Live Activity (Dynamic Island
    /// or Lock Screen) and the app consumes the pending action on next activation.
    /// Drives the tap-through funnel for PMF.
    func trackLiveActivityAction(kind: String, actionKind: String) {
        logEvent("live_activity_action_performed", parameters: [
            "activity_kind": kind,
            "action_kind": actionKind
        ])
    }

    /// Emitted the morning after a Wind-Down Live Activity was shown, once HealthKit
    /// has recorded sleep onset. `deltaMinutes` is (sleep onset - target bedtime) in
    /// minutes; negative means the user fell asleep before the target.
    /// The onset timestamp and the exact minute gap both come from HealthKit sleep
    /// samples, so neither is sent. `onset_band` is the bucketed distance from the
    /// target bedtime, which is all the wind-down funnel needs.
    func trackLiveActivitySleepOutcome(
        kind: String,
        bedtimeEpoch: Int,
        sleepOnsetEpoch: Int?,
        deltaMinutes: Int?,
        sleepDetected: Bool
    ) {
        let onsetBand: String
        switch deltaMinutes {
        case .none:              onsetBand = "unknown"
        case .some(..<(-30)):    onsetBand = "early"
        case .some(-30..<15):    onsetBand = "on_time"
        case .some(15..<60):     onsetBand = "late"
        default:                 onsetBand = "very_late"
        }

        logEvent("live_activity_sleep_outcome", parameters: [
            "activity_kind": kind,
            "bedtime_epoch": bedtimeEpoch,
            "sleep_detected": sleepDetected ? 1 : 0,
            "sleep_onset_known": sleepOnsetEpoch == nil ? 0 : 1,
            "onset_band": onsetBand
        ])
    }

    func trackWidgetSnapshotUpdated(
        trigger: String,
        snapshotsWritten: Int,
        hasReadiness: Bool,
        hasSleep: Bool,
        hasAction: Bool,
        hasIntelligence: Bool,
        hasRecoveryDebt: Bool
    ) {
        let completeness = [hasReadiness, hasSleep, hasAction, hasIntelligence, hasRecoveryDebt]
            .filter { $0 }
            .count

        logEvent("widget_snapshot_updated", parameters: [
            "trigger": trigger,
            "snapshots_written": snapshotsWritten,
            "completeness_count": completeness,
            "has_readiness": hasReadiness ? 1 : 0,
            "has_sleep": hasSleep ? 1 : 0,
            "has_action": hasAction ? 1 : 0,
            "has_intelligence": hasIntelligence ? 1 : 0,
            "has_recovery_debt": hasRecoveryDebt ? 1 : 0
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 20. Wearable & Source Properties
    // ══════════════════════════════════════════════════════════════════════

    /// Update wearable/source user properties. Call after device detection.
    func updateHealthSourceProperties(
        hasAppleWatch: Bool,
        sourceCount: Int,
        primarySource: String,
        daysSinceFirstSync: Int,
        watchModel: String? = nil,
        wearableModel: String? = nil
    ) {
        var props: [String: Any] = [
            "has_apple_watch": hasAppleWatch ? "yes" : "no",
            "health_source_count": "\(sourceCount)",
            "primary_health_source": primarySource,
            "days_since_first_sync": "\(daysSinceFirstSync)"
        ]
        if let watchModel { props["watch_model"] = watchModel }
        if let wearableModel { props["wearable_model"] = wearableModel }
        AnalyticsBackend.provider.setUserProperties(props)
    }

    /// Update notification permission state as user property.
    func updateNotificationProperties(enabled: Bool) {
        setUserProperty("notifications_enabled", value: enabled ? "yes" : "no")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 20b. Referral Events
    // ══════════════════════════════════════════════════════════════════════

    func trackReferralCodeRedeemed(code: String, success: Bool, failureReason: String? = nil) {
        logEvent("referral_code_redeemed", parameters: [
            "code": AppAnalytics.sha256Hash16(code),
            "success": success ? 1 : 0,
            "failure_reason": failureReason ?? "none"
        ])
    }

    func trackReferralCompleted(role: String) {
        logEvent("referral_completed", parameters: [
            "role": role
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 20c. Achievement Events
    // ══════════════════════════════════════════════════════════════════════

    /// One event per achievement per install. GamificationEngine holds its
    /// unlocked set in memory only, so on the first compute() of every cold
    /// launch it classifies every already-unlocked achievement as new — a user
    /// with 8 unlocked emitted 8 events on every launch. The persisted claim
    /// below is the only place that survives the process.
    func trackAchievementUnlocked(id: String, title: String, category: String) {
        let key = "laso.analytics.achievements_emitted"
        var emitted = Set(defaults.stringArray(forKey: key) ?? [])
        guard !emitted.contains(id) else { return }
        emitted.insert(id)
        defaults.set(Array(emitted), forKey: key)

        logEvent("achievement_unlocked", parameters: [
            "achievement_id": id,
            "achievement_title": title,
            "achievement_category": category
        ])
    }

    func trackLevelUp(newLevel: String, totalDaysTracked: Int) {
        logEvent("level_up", parameters: [
            "new_level": newLevel,
            "total_days_tracked": totalDaysTracked
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 20d. Device Disconnect Events
    // ══════════════════════════════════════════════════════════════════════

    func trackDeviceDisconnected(deviceType: String, daysSinceLastData: Int, modelName: String? = nil) {
        logEvent("device_disconnected", parameters: [
            "device_type": deviceType,
            "days_since_last_data": daysSinceLastData,
            "device_model_name": modelName ?? "unknown"
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 20f. Journal Lifecycle Events
    // ══════════════════════════════════════════════════════════════════════

    /// The logged amount is the user's own health entry (drinks, stress level,
    /// mood), so it is not taken and not sent. Only the fact that a category was
    /// logged is sent, which is what the feature-usage funnel needs.
    func trackJournalEntryCreated(category: String, hasNotes: Bool) {
        logEvent("journal_entry_created", parameters: [
            "category": category,
            "has_notes": hasNotes ? 1 : 0
        ])

        trackFeatureUsed(.loggedJournal)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 21. Empty State & Friction Signals
    // ══════════════════════════════════════════════════════════════════════

    /// Call when an empty state is shown (no data, no insights, etc.).
    func trackEmptyStateShown(screen: AppFeature, reason: String) {
        logEvent("empty_state_shown", parameters: [
            "screen": screen.rawValue,
            "reason": reason,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// The user wiped their account from Settings. MUST be emitted as the FIRST
    /// statement of the deletion routine: the wipe calls
    /// `AnalyticsBackend.provider.reset()`, after which any event lands on a
    /// fresh anonymous id and the strongest churn signal in the product is lost.
    func trackAccountDataDeleted(storedSamples: Int) {
        logEvent("account_data_deleted", parameters: [
            "stored_samples": storedSamples,
            "days_since_install": session.daysSinceInstall,
            "total_sessions": session.totalSessions,
            "was_activated": session.isActivated ? 1 : 0
        ])
    }

    /// Call when score generation fails.
    func trackScoreGenerationFailed(reason: String) {
        logEvent("score_generation_failed", parameters: [
            "reason": reason,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Controlled sync-failure cause. Free text produced one distinct `reason`
    /// per device locale and per underlying error string, so the dimension could
    /// not be grouped. Put the localized description on `trackError` instead.
    enum SyncFailureReason: String {
        case healthkitAuthorization = "healthkit_authorization"
        case protectedDataUnavailable = "protected_data_unavailable"
        case noModelContext = "no_model_context"
        case timeout
        case unknown
    }

    /// Call when sync times out or fails. `retryCount` is the number of attempts
    /// already burned — the whole point of the property is answering "did retries
    /// help?", so pass the real count, never the default.
    func trackSyncFailed(reason: SyncFailureReason, retryCount: Int = 0) {
        logEvent("sync_failed", parameters: [
            "reason": reason.rawValue,
            "retry_count": retryCount
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 22. Behavioral Intelligence (Non-Obvious Signals)
    // ══════════════════════════════════════════════════════════════════════

    // --- A. Ghost Sessions ---
    // A session where the user opened the app but did nothing meaningful.
    // Strongest leading indicator of disengagement. they came, saw nothing worth doing, and left.

    /// Call from `emitSessionEnded`. Automatically detects ghost sessions.
    func evaluateSessionQuality(_ stats: SessionTracker.EndedStats) {
        let durationSec = stats.durationSec
        let screensVisited = stats.screensVisited
        let coreActionsCount = stats.coreActionsCount

        // Ghost: >5 sec but zero core actions and ≤1 screen
        let isGhost = durationSec >= 5 && coreActionsCount == 0 && screensVisited <= 1
        if isGhost {
            // screens_viewed / core_actions_count, matching session_ended: these
            // three events are built from the SAME EndedStats milliseconds apart,
            // and two key names for one value meant no single breakdown could
            // chart screens-per-session across the session funnel.
            logEvent("ghost_session", parameters: [
                "session_id": stats.sessionId,
                "session_number": stats.sessionNumber,
                "opened_from": SessionTracker.SessionSource(rawValue: stats.sessionSource).map(Self.openedFrom(for:)) ?? "unknown",
                "duration_sec": durationSec,
                "screens_viewed": screensVisited,
                "days_since_install": session.daysSinceInstall,
                "streak_days": session.streakDays,
                "session_source": stats.sessionSource
            ])
        }

        // Classify session quality for cohort analysis
        let quality: String
        if coreActionsCount >= 3 && screensVisited >= 3 { quality = "deep" }
        else if coreActionsCount >= 1 { quality = "engaged" }
        else if durationSec >= 5 { quality = "shallow" }
        else { quality = "bounce" }

        logEvent("session_quality", parameters: [
            "session_id": stats.sessionId,
            "session_number": stats.sessionNumber,
            "opened_from": SessionTracker.SessionSource(rawValue: stats.sessionSource).map(Self.openedFrom(for:)) ?? "unknown",
            "quality": quality,
            "duration_sec": durationSec,
            "screens_viewed": screensVisited,
            "core_actions_count": coreActionsCount,
            "session_source": stats.sessionSource
        ])
    }

    // --- B. Score Reaction ---
    // When score changes, what does the user do? Investigate = engaged. Close = disengaging.
    // This reveals whether the scoring system drives action or apathy.

    private var lastScoreDelta: Int = 0
    private var scoreSeenDate: Date?
    private var scoreViewedThisSession = false

    /// Call when the score is first shown to the user.
    func trackScoreViewed(score: Int, previousScore: Int?) {
        // Fire once per foreground session: re-entry of the score view (re-render,
        // tab switch back) must not re-emit score_viewed or re-arm the reaction
        // timer, which would otherwise span a backgrounded gap.
        guard !scoreViewedThisSession else { return }
        scoreViewedThisSession = true

        let delta = previousScore.map { score - $0 } ?? 0
        lastScoreDelta = delta
        scoreSeenDate = Date()

        let direction: String
        if delta > 5 { direction = "big_improvement" }
        else if delta > 0 { direction = "slight_improvement" }
        else if delta == 0 { direction = "unchanged" }
        else if delta > -5 { direction = "slight_decline" }
        else { direction = "big_decline" }

        logEvent("score_viewed", parameters: [
            "score_bracket": scoreBracket(score),
            "direction": direction,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call when the user takes ANY action after seeing the score.
    /// Fires only once per session to capture the immediate reaction.
    func trackScoreReaction(nextAction: String, nextScreen: AppFeature) {
        guard let seen = scoreSeenDate else { return }
        let reactionTimeSec = Int(Date().timeIntervalSince(seen))
        scoreSeenDate = nil // fire once per session

        // reaction_type is investigated/continued only: the sole caller passes
        // CoreAction rawValues, none of which signal disengagement.
        let reactionType: String
        if nextAction.contains("insight") || nextAction.contains("metric") || nextAction.contains("correlation") {
            reactionType = "investigated"
        } else {
            reactionType = "continued"
        }

        logEvent("score_reaction", parameters: [
            "reaction_type": reactionType,
            "next_action": nextAction,
            "next_screen": nextScreen.rawValue,
            "reaction_time_sec": reactionTimeSec,
            "score_delta": lastScoreDelta
        ])
    }

    // --- C. Screenshot Detection ---
    // Users screenshot things they trust and want to share.
    // Screenshot rate is a proxy for "would you show this to a friend?"

    private var screenshotObserver: NSObjectProtocol?

    /// Call once at app launch to start observing screenshots.
    /// Idempotent — safe to call multiple times; previous observer is removed first
    /// so we never accumulate duplicate observers (which would emit duplicate events).
    func startScreenshotTracking() {
        if let existing = screenshotObserver {
            NotificationCenter.default.removeObserver(existing)
            screenshotObserver = nil
        }
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.logEvent("screenshot_taken", parameters: [
                    "screen": self.session.currentScreen ?? "unknown",
                    "tab": self.session.currentTab,
                    "days_since_install": self.session.daysSinceInstall,
                    "subscription_status": UserDefaults.standard.string(forKey: "laso.analytics.last_known_status") ?? "unknown"
                ])
            }
        }
    }

    // --- D. Habit Pattern Detection ---
    // Detect if the user is forming a "morning ritual". checking the app at roughly the same
    // time on consecutive days. This is the #1 predictor of 6-month retention.

    private enum HabitKey {
        static let sessionHours = "laso.analytics.session_hours"
        static let ritualDetected = "laso.analytics.ritual_detected"
    }

    /// Call from session start. Builds up a pattern of open-times to detect ritual formation.
    func detectHabitPattern() {
        let hour = Date.cal.component(.hour, from: Date())

        // Store last 14 session hours
        var hours = defaults.array(forKey: HabitKey.sessionHours) as? [Int] ?? []
        hours.append(hour)
        if hours.count > 14 { hours = Array(hours.suffix(14)) }
        defaults.set(hours, forKey: HabitKey.sessionHours)

        guard hours.count >= 5 else { return }

        // Check if >60% of sessions are within a 2-hour window
        var bestCount = 0
        for testHour in 0..<24 {
            let count = hours.filter { abs($0 - testHour) <= 1 || abs($0 - testHour) >= 23 }.count
            bestCount = max(bestCount, count)
        }

        let ritualStrength = Double(bestCount) / Double(hours.count)
        let isRitual = ritualStrength >= 0.6 && hours.count >= 7

        if isRitual && !defaults.bool(forKey: HabitKey.ritualDetected) {
            defaults.set(true, forKey: HabitKey.ritualDetected)
            // `hours` is guaranteed non-empty by the count >= 5 guard above, so
            // max() cannot return nil — the old sibling `peak_hour_known` flag was
            // a constant 1 on every event.
            let computedPeakHour = hours.max(by: { a, b in hours.filter { $0 == a }.count < hours.filter { $0 == b }.count })
            logEvent("habit_ritual_formed", parameters: [
                "ritual_strength_ratio": ritualStrength,
                "peak_hour_local": computedPeakHour ?? 0,
                "days_since_install": session.daysSinceInstall,
                "streak_days": session.streakDays
            ])
            setUserProperty("has_morning_ritual", value: "yes")
        }

        // Always update ritual strength as user property for cohort segmentation
        if hours.count >= 7 {
            let bucket: String
            if ritualStrength >= 0.8 { bucket = "strong" }
            else if ritualStrength >= 0.5 { bucket = "forming" }
            else { bucket = "irregular" }
            setUserProperty("usage_pattern", value: bucket)
        }
    }

    // --- E. Feature Discovery Map ---
    // What % of features has this user seen? Correlate with retention.
    // Users who discover <30% of features churn. Users who discover >60% retain.

    private static let keyFeatures: Set<String> = [
        "home", "explore", "metric_detail", "insights_detail", "correlations",
        "score_guide", "simulation", "settings", "connected_devices",
        "sleep_coach", "stress_monitor", "performance_profile", "brain_health"
    ]

    /// Call from `trackFeatureOpen`. Automatically tracks discovery depth.
    func updateFeatureDiscovery(screen: AppFeature) {
        let key = "laso.analytics.discovered_features"
        var discovered = Set(defaults.stringArray(forKey: key) ?? [])
        let raw = screen.rawValue

        guard Self.keyFeatures.contains(raw), !discovered.contains(raw) else { return }

        discovered.insert(raw)
        defaults.set(Array(discovered), forKey: key)

        let discoveryPct = (discovered.count * 100) / Self.keyFeatures.count

        logEvent("feature_discovered", parameters: [
            "feature": raw,
            "total_discovered": discovered.count,
            "discovery_pct": discoveryPct,
            "days_since_install": session.daysSinceInstall,
            "session_number": session.totalSessions
        ])

        setUserProperty("feature_discovery_pct", value: "\(discoveryPct)")
    }

    // --- F. Rage Tap Detection ---
    // 3+ taps on the same element within 2 seconds = frustration.
    // This is the mobile equivalent of rage-clicking.

    private var lastTapElement: String = ""
    private var tapTimestamps: [Date] = []

    /// Call from any tap handler. Detects rapid repeated taps (frustration).
    func detectRageTap(element: String, screen: AppFeature) {
        let now = Date()
        if element == lastTapElement {
            tapTimestamps.append(now)
            // Keep only taps within last 2 seconds
            tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2.0 }
        } else {
            lastTapElement = element
            tapTimestamps = [now]
        }

        if tapTimestamps.count >= 3 {
            logEvent("rage_tap", parameters: [
                "element": element,
                "screen": screen.rawValue,
                "tap_count": tapTimestamps.count,
                "days_since_install": session.daysSinceInstall
            ])
            tapTimestamps = [] // reset after detection
        }
    }

    // --- G. Pre-Churn Behavioral Signature ---
    // Track a "health score" of the user's engagement. Declining engagement
    // over 3 sessions = pre-churn. This gives you 1-2 weeks warning before they leave.

    private enum ChurnKey {
        static let sessionScores = "laso.analytics.session_engagement_scores"
    }

    /// Call at session end. Computes an engagement score and detects decline patterns.
    func evaluateChurnRisk(_ stats: SessionTracker.EndedStats) {
        let durationSec = stats.durationSec
        let coreActionsCount = stats.coreActionsCount
        let screensVisited = stats.screensVisited

        // Simple engagement score: 0-100
        let durationScore = min(30, durationSec / 6)           // max 30 pts for 3 min
        let actionScore = min(40, coreActionsCount * 10)        // max 40 pts for 4 actions
        let depthScore = min(30, screensVisited * 6)            // max 30 pts for 5 screens
        let engagementScore = durationScore + actionScore + depthScore

        var scores = defaults.array(forKey: ChurnKey.sessionScores) as? [Int] ?? []
        scores.append(engagementScore)
        if scores.count > 5 { scores = Array(scores.suffix(5)) }
        defaults.set(scores, forKey: ChurnKey.sessionScores)

        guard scores.count >= 3 else { return }

        // Check for declining trend: each session worse than the previous
        let recentThree = Array(scores.suffix(3))
        let isDecline = recentThree[0] > recentThree[1] && recentThree[1] > recentThree[2]
        let avgScore = recentThree.reduce(0, +) / recentThree.count

        if isDecline && avgScore < 40 {
            logEvent("pre_churn_signal", parameters: [
                "session_id": stats.sessionId,
                "session_number": stats.sessionNumber,
                "opened_from": SessionTracker.SessionSource(rawValue: stats.sessionSource).map(Self.openedFrom(for:)) ?? "unknown",
                "avg_engagement_score": avgScore,
                "trend": "declining_3_sessions",
                "latest_score": engagementScore,
                "days_since_install": session.daysSinceInstall,
                "subscription_status": defaults.string(forKey: "laso.analytics.last_known_status") ?? "unknown"
            ])
        }
        // engagement_level (user property) has exactly one writer:
        // computeEngagementLevel at session start. The churn score here ships
        // only on pre_churn_signal, never as a competing property definition.
    }

    // --- H. Background Refresh Success ---
    // If background refresh fails, the app feels stale when opened. Users leave.

    /// Why a background pass ended the way it did. Without it a drop in
    /// background_refresh_result volume cannot be split between "BGTask never
    /// ran", "thermal throttle" and "no readiness produced".
    enum BackgroundRefreshReason: String {
        case ok
        case noReadiness = "no_readiness"
        case thermalThrottle = "thermal_throttle"
    }

    /// Call after background refresh completes, INCLUDING the early exits — a
    /// throttled device must show up as failures with a cause, not as silence.
    func trackBackgroundRefreshResult(success: Bool, reason: BackgroundRefreshReason, durationMs: Int, samplesLoaded: Int) {
        logEvent("background_refresh_result", parameters: [
            "success": success ? 1 : 0,
            "reason": reason.rawValue,
            "duration_ms": durationMs,
            "samples_loaded": samplesLoaded
        ])
    }

    // --- I. Value Delivery Rate ---
    // Track the ratio of sessions where the user received genuinely new information
    // vs sessions where everything was the same. If nothing changes, why come back?

    /// Call after analysis completes. Track whether this session delivered new value.
    func trackValueDelivered(newInsightsCount: Int, scoreChanged: Bool, newAnomalies: Int, newCorrelations: Int) {
        let hasNewValue = newInsightsCount > 0 || scoreChanged || newAnomalies > 0 || newCorrelations > 0

        logEvent("value_delivered", parameters: [
            "has_new_value": hasNewValue ? 1 : 0,
            "new_insights": newInsightsCount,
            "score_changed": scoreChanged ? 1 : 0,
            "new_anomalies": newAnomalies,
            "new_correlations": newCorrelations,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // MARK: - Private Helpers

    /// Returns a privacy-safe bracket string for a health score (0-100).
    /// Exact scores are considered identifiable health data and must never
    /// be sent to third-party analytics.
    private func scoreBracket(_ score: Int) -> String {
        switch score {
        case ..<20:  return "0-19"
        case 20..<40: return "20-39"
        case 40..<60: return "40-59"
        case 60..<80: return "60-79"
        default:      return "80-100"
        }
    }

    private func updateJourneyProperties() {
        let onboardingCompleted = defaults.bool(forKey: AppKeys.App.onboardingCompleted)
        let status = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"
        let journeyStage: String

        if !onboardingCompleted {
            journeyStage = "onboarding"
        } else if status == "trial" {
            journeyStage = "trial"
        } else if status == "pro" || status == "billing_grace" {
            journeyStage = "subscriber"
        } else if session.isActivated {
            journeyStage = "activated_free"
        } else {
            journeyStage = "exploring"
        }

        setUserProperty("journey_stage", value: journeyStage)
        setUserProperty("activation_status", value: session.isActivated ? "activated" : "not_activated")
        setUserProperty("onboarding_completed", value: onboardingCompleted ? "yes" : "no")
    }

    /// Memoized `sanitizeEventName` answers. Event names and parameter keys are
    /// string literals from a closed set, so the same few hundred inputs were
    /// being re-lowercased, re-mapped per character and re-trimmed on every
    /// event — roughly 20 keys per event, all identical work. Capped so a future
    /// caller passing a dynamic key cannot grow this without bound.
    private var sanitizedNameCache: [String: String] = [:]

    private func sanitizeEventName(_ name: String) -> String {
        if let cached = sanitizedNameCache[name] { return cached }

        let allowed = name.lowercased().map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" {
                return char
            }
            return "_"
        }
        let normalized = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let result: String
        if normalized.isEmpty {
            result = "custom_event"
        } else if normalized.count > 80 {
            result = String(normalized.prefix(80))
        } else {
            result = normalized
        }

        if sanitizedNameCache.count < 512 {
            sanitizedNameCache[name] = result
        }
        return result
    }


    /// Parameter keys whose string values may contain identifiable health metric names.
    /// These are replaced with the metric's generic HealthCategory before sending to PostHog
    /// so that specific conditions (e.g. "bloodPressure", "menstrualFlow") are never transmitted.
    private static let metricParameterKeys: Set<String> = [
        "metric", "metric_a", "metric_b", "metric_id", "alert_metric",
        "nutrition_metric", "outcome_metric", "metric_preview"
    ]

    /// Parameter keys carrying a raw 0-100 health score. These are bracketed in
    /// `sanitizeParameters` so an exact, identifiable score never reaches a third
    /// party (see `scoreBracket`). Deliberately excludes non-health numbers that
    /// merely contain "score" — `score_delta`, `score_tint`,
    /// `notification_min_priority_score`, `avg_engagement_score`, `latest_score`
    /// — which stay numeric (the engagement scores are 0-100 engagement signals,
    /// not clinical health scores).
    private static let healthScoreKeys: Set<String> = [
        "score", "category_score", "overall_score"
    ]

    /// Parameter keys whose value is deliberately kept as full free text rather
    /// than clipped to 100 chars — the exact words the user typed are the point
    /// (e.g. the Ask question). Still capped at Amplitude's 1024-char string
    /// limit so a pasted essay cannot blow up the payload.
    private static let fullTextParameterKeys: Set<String> = [
        "query_text"
    ]

    /// Spike notification ids (`healthpulse.spike.rhr.elevated`) carry a short
    /// abbreviation where every other alert family carries a HealthMetric
    /// rawValue. Without this table the same metric lands in two incomparable
    /// Amplitude buckets: the raw abbreviation from spikes, the anonymised
    /// category from everything else.
    private static let metricAbbreviations: [String: String] = [
        "rhr": HealthMetric.restingHeartRate.rawValue,
        "hr": HealthMetric.heartRate.rawValue,
        "hrv": HealthMetric.heartRateVariability.rawValue,
        "spo2": HealthMetric.bloodOxygen.rawValue,
        "rr": HealthMetric.respiratoryRate.rawValue
    ]

    /// Replaces a recognizable HealthMetric rawValue with its parent category name.
    /// Returns the original string unchanged when no matching metric is found.
    private func anonymizeMetricValue(_ value: String) -> String {
        // Handle comma-separated lists (used by metric_preview)
        if value.contains(",") {
            return value
                .split(separator: ",")
                .map { anonymizeMetricValue(String($0).trimmingCharacters(in: .whitespaces)) }
                .joined(separator: ",")
        }
        if let metric = HealthMetric(rawValue: Self.metricAbbreviations[value] ?? value) {
            return metric.category.rawValue
        }
        return value
    }

    /// PII-safe form of a notification identifier. Prefix-based alert ids embed a
    /// raw HealthMetric rawValue in their third segment
    /// (e.g. "healthpulse.spike.bloodPressureSystolic.high"); that segment is
    /// collapsed to its parent HealthCategory so a specific condition never ships
    /// inside notification_id. Static, non-metric ids (dailySummary, engagement)
    /// pass through unchanged. The metric segment is the only PII carrier, so all
    /// other segments are preserved to keep the id joinable in Amplitude.
    private func sanitizedNotificationID(_ identifier: String) -> String {
        var parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 3 else { return identifier }
        parts[2] = anonymizeMetricValue(parts[2])
        return parts.joined(separator: ".")
    }

    private func sanitizeParameters(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (rawKey, rawValue) in parameters {
            let key = sanitizeEventName(rawKey)
            if key.isEmpty { continue }

            switch rawValue {
            case let value as String:
                // Full-text fields keep the whole message (up to Amplitude's
                // 1024-char string limit); everything else clips to 100.
                let cap = Self.fullTextParameterKeys.contains(key) ? 1024 : 100
                let truncated = value.count > cap ? String(value.prefix(cap)) : value
                // Anonymize health metric names so specific conditions are not sent to PostHog
                if Self.metricParameterKeys.contains(key) {
                    sanitized[key] = anonymizeMetricValue(truncated)
                } else {
                    sanitized[key] = truncated
                }
            case let value as Int:
                // Raw 0-100 health scores must never reach a third party; bracket
                // them centrally so every event carrying one is privacy-safe. A
                // negative sentinel (e.g. category_score = -1 "no score") maps to
                // "none" rather than a misleading low bucket.
                if Self.healthScoreKeys.contains(key) {
                    sanitized[key] = value < 0 ? "none" : scoreBracket(value)
                } else {
                    sanitized[key] = value
                }
            case let value as Double:
                sanitized[key] = value
            case let value as Float:
                sanitized[key] = Double(value)
            case let value as Bool:
                sanitized[key] = value ? 1 : 0
            case let value as [String]:
                // Passed through as a native array-of-string property so Amplitude
                // can segment on individual elements (goals, symptoms); each
                // element gets the same truncation + metric anonymization as a
                // scalar string.
                sanitized[key] = value.map { element -> String in
                    let truncated = element.count > 100 ? String(element.prefix(100)) : element
                    return Self.metricParameterKeys.contains(key) ? anonymizeMetricValue(truncated) : truncated
                }
            default:
                sanitized[key] = String(describing: rawValue)
            }
        }

        return sanitized
    }

    private func slugify(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalized = trimmed.map { ch -> Character in
            if ch.isLetter || ch.isNumber {
                return ch
            }
            return "_"
        }
        let collapsed = String(normalized).replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        let cleaned = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return cleaned.isEmpty ? "unknown" : String(cleaned.prefix(64))
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 23. Sean Ellis PMF Survey
    // ══════════════════════════════════════════════════════════════════════

    /// Controlled Sean Ellis PMF answer. Free-text segment/benefit/improvement
    /// answers are deliberately NOT emitted — they leak PII and the taxonomy keeps
    /// only the enum choice.
    enum SeanEllisChoice: String {
        case veryDisappointed = "very_disappointed"
        case somewhatDisappointed = "somewhat_disappointed"
        case notDisappointed = "not_disappointed"
    }

    /// The single PMF survey event. Fires once when the user answers the canonical
    /// Sean Ellis question ("How would you feel if you could no longer use Laso?").
    /// >40% very_disappointed = PMF (Rahul Vohra / Superhuman benchmark). The four
    /// old PMF events are consolidated here; only the enum choice ships.
    func trackSatisfactionSurveyAnswered(_ choice: SeanEllisChoice) {
        logEvent("satisfaction_survey_answered", parameters: [
            "sean_ellis_choice": choice.rawValue
        ])
        setUserProperty("pmf_response", value: choice.rawValue)
    }

    /// Steps 2-4 of the survey (segment / benefit / improvement). Only the step id
    /// and how much the user wrote are sent — the free-text answers are health
    /// context and stay on the phone.
    func trackPMFSurveyStep(step: String, textLength: Int) {
        logEvent("pmf_survey_step", parameters: [
            "step": step,
            "text_length": textLength
        ])
    }

    /// The survey's terminal event. Without it, completion rate cannot be
    /// computed at all: only step 1 emitted anything.
    func trackPMFSurveyCompleted(stepsAnswered: Int) {
        logEvent("pmf_survey_completed", parameters: [
            "steps_answered": stepsAnswered
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 24. Share Completion
    // ══════════════════════════════════════════════════════════════════════

    /// Call from UIActivityViewController's completion handler.
    /// Tracks whether the user actually completed a share or cancelled it.
    func trackShareCompleted(contentType: String, activityType: String?, completed: Bool) {
        logEvent("share_completed", parameters: [
            "content_type": contentType,
            "activity_type": activityType ?? "unknown",
            "completed": completed ? 1 : 0
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 26. App Store Review Prompt
    // ══════════════════════════════════════════════════════════════════════

    /// Call when we present the App Store review prompt (SKStoreReviewController).
    func trackAppStoreReviewPrompted(trigger: String) {
        logEvent("app_store_review_prompted", parameters: [
            "trigger": trigger,
            "total_sessions": session.totalSessions,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "was_activated": session.isActivated ? 1 : 0
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 28. Notification Permission Funnel
    // ══════════════════════════════════════════════════════════════════════

    /// Call when the notification permission dialog is about to be shown.
    func trackNotificationPermissionRequested(source: String) {
        logEvent("notification_permission_requested", parameters: [
            "source": source
        ])
    }

    /// Call after the user responds to the notification permission dialog.
    func trackNotificationPermissionResult(granted: Bool, source: String) {
        logEvent("notification_permission_result", parameters: [
            "granted": granted ? 1 : 0,
            "source": source
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 29. LLM Query Satisfaction
    // ══════════════════════════════════════════════════════════════════════

    /// Call when the user provides feedback on an "Ask Your Data" result.
    func trackQueryFeedback(helpful: Bool, confidence: Int, queryLength: Int) {
        logEvent("query_feedback", parameters: [
            "helpful": helpful ? 1 : 0,
            "confidence": confidence,
            "query_length": queryLength
        ])
    }

    // MARK: - Analytics Backend (all events)

    /// Every event built by this facade is forwarded to Amplitude under its stable
    /// name. There is no client-side allowlist: a previous "finalised taxonomy" set
    /// silently dropped 117 of the 133 events here (activation, retention, the whole
    /// paywall funnel, screen/engagement/behavioral signals), so the dashboard saw
    /// only a fraction of the instrumented product. Each event still passes through
    /// `sanitizeParameters` (metric-name anonymization, string truncation, raw-score
    /// bracketing) before sending, so opening the stream does not leak identifiable
    /// health data.
    /// (marketing_spend_recorded is server-imported; refunded and payment_issue_*
    /// arrive from the App Store Server Notifications webhook. subscription_renewed
    /// is client-emitted from entitlement-extension detection — the webhook skips
    /// it to avoid double counting.)
    fileprivate func logEvent(_ name: String, parameters: [String: Any]) {
        var enriched = parameters

        // The 12 global properties from the analytics taxonomy, injected on every
        // event. User-level dimensions (subscription_status, streak_days,
        // engagement_level, etc.) are NOT injected here — they live as user
        // properties and are set via setUserProperty on session start, so they
        // are still joinable in Amplitude without bloating every event.

        // Build-time constants.
        enriched["schema_version"] = Self.schemaVersion
        enriched["environment"] = Self.environment
        enriched["platform"] = "ios"
        enriched["build_number"] = Self.cachedBuildNumber
        if enriched["app_version"] == nil {
            enriched["app_version"] = Self.cachedAppVersion
        }

        // Session identity.
        if enriched["session_id"] == nil {
            enriched["session_id"] = session.sessionId
        }
        if enriched["session_number"] == nil {
            enriched["session_number"] = session.totalSessions
        }

        // Current location in the app, when known.
        if enriched["tab"] == nil {
            enriched["tab"] = session.currentTab
        }
        if enriched["screen"] == nil, let currentScreen = session.currentScreen {
            enriched["screen"] = currentScreen
        }

        // Entry point for this session, mapped onto the taxonomy enum.
        if enriched["opened_from"] == nil {
            enriched["opened_from"] = Self.openedFrom(for: session.currentSessionSource)
        }

        // Local hour (0-23) for time-of-day analysis the UTC stamp cannot give.
        if enriched["hour_of_day"] == nil {
            enriched["hour_of_day"] = Date.cal.component(.hour, from: Date())
        }

        // Fixed-UTC ISO-8601 wall-clock stamp, comparable across timezones.
        if enriched["client_timestamp_utc"] == nil {
            enriched["client_timestamp_utc"] = Self.eventTimestampFormatter.string(from: Date())
        }

        // Events ship under their literal, sanitized stable name.
        let params = sanitizeParameters(enriched)
        AnalyticsBackend.provider.capture(event: sanitizeEventName(name), properties: params)
    }

    /// Analytics schema version. Bump when the event/property contract changes so
    /// dashboards can pin to a known taxonomy.
    private static let schemaVersion = "2026-05-31.1"

    /// `environment` global mapped onto the taxonomy enum (debug, testflight,
    /// production). AnalyticsEnvironment uses "release" for App Store builds;
    /// the taxonomy calls that "production".
    private static let environment: String = {
        switch AnalyticsEnvironment.appEnvironment {
        case "release": return "production"
        default:        return AnalyticsEnvironment.appEnvironment
        }
    }()

    /// Cached internal build number (CFBundleVersion). Fixed for the process.
    private static let cachedBuildNumber: String = {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleVersion"] as? String) ?? "unknown"
    }()

    /// Maps the session source onto the taxonomy `opened_from` enum
    /// (app_icon, notification, widget, deeplink, live_activity, shortcut, unknown).
    private static func openedFrom(for source: SessionTracker.SessionSource) -> String {
        switch source {
        case .organic:      return "app_icon"
        case .notification: return "notification"
        case .widget:       return "widget"
        case .liveActivity: return "live_activity"
        }
    }

    private func setUserProperty(_ name: String, value: String) {
        AnalyticsBackend.provider.setUserProperty(name: name, value: value)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 25. Widget & Watch Engagement
    // ══════════════════════════════════════════════════════════════════════
    // (Widget interaction + Apple Watch session tracking methods removed —
    // they had zero call sites because widget/watchOS instrumentation was
    // never wired. Re-add when those surfaces actually emit events.)
}
