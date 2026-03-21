import Foundation
import UIKit

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
}

/// Actionable block/card types. only user-initiated taps and meaningful interactions.
enum BlockType: String {
    // Home. user taps
    case recoveryCard = "recovery_card"
    case sleepCard = "sleep_card"
    case smartAction = "smart_action"
    case headlineInsight = "headline_insight"
    case seeAllInsights = "see_all_insights"
    case seeAllNeedsAttention = "see_all_needs_attention"
    case seeAllCorrelations = "see_all_correlations"
    case weeklyReviewCard = "weekly_review_card"
    case settingsGear = "settings_gear"
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
    case scoreGuideGotIt = "score_guide_got_it"

    // Navigation
    case tabHome = "tab_home"
    case tabLive = "tab_live"
    case tabExplore = "tab_explore"

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

    // Home extras
    case homeRiskRow = "home_risk_row"
    case homeRecoveryInfoButton = "home_recovery_info_button"
    case homeDailyAction = "home_daily_action"
    case homeBrainHealthCard = "home_brain_health_card"
    case dataConfidenceBadge = "data_confidence_badge"
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
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference. 5 Product Questions
// ──────────────────────────────────────────────────────────────────────────────
//
// NORTH-STAR METRICS:
//   1. Activation rate           → onboarding_completed → activation_completed
//   2. Time to first value       → time_to_first_value / first_score_generated
//   3. D1 / D7 / D30 retention  → retention_milestone
//   4. Trial-to-paid conversion  → subscription_purchased (trial_converted=1)
//   5. Churn                     → subscription_cancelled / inactive_period_detected
//
// ─── Q1: WHO GETS VALUE? ────────────────────────────────────────────────────
//  onboarding_completed          focuses, duration_sec               Setup completion
//  onboarding_step_completed     step, step_name, duration_sec       Drop-off funnel
//  onboarding_drop_off           last_step, duration_sec             Where they quit
//  activation_milestone          milestone, time_since_install       Which features click
//  activation_completed          milestones_count, days_to_activate  Aha moment reached
//  time_to_first_value           seconds                             Speed to value
//  first_score_generated         score, time_since_install_sec       First real output
//  health_permission_requested   metrics_requested                   Permission funnel start
//  health_permission_result      granted, denied, grant_rate         Permission success
//  source_connected              source_type, metrics_available      Wearable onboarded
//  data_pipeline_quality         coverage, enough_for_score          Data readiness
//  empty_state_shown             screen, reason                      Blocked from value
//
// ─── Q2: WHO COMES BACK? ────────────────────────────────────────────────────
//  session_start                 hour, weekday, streak, source       When & how they open
//  session_end                   duration_sec, screens, depth        Session quality
//  return_session                session_number, days_since_last     Return cadence
//  daily_active                  source, weekly_active_days          DAU/WAU/MAU
//  retention_milestone           day (1,2,3,7,14,30)                 Retention curve
//  streak_milestone              days (7,14,30,60,100)               Habit formation
//  streak_broken                 previous_streak                     Habit loss
//  inactive_period_detected      days_inactive                       Churn signal
//  notification_opened           notification_id, type               Re-engagement
//  recommendation_completed      type, metric                        Action loop
//
// ─── Q3: WHAT CREATES TRUST? ────────────────────────────────────────────────
//  explanation_viewed            type, screen                        Do they check methodology?
//  insight_marked_helpful        category, metric                    Insight quality signal
//  insight_marked_unhelpful      category, metric, reason            False positives
//  privacy_page_viewed           source                              Privacy concern
//  recommendation_viewed         type, metric, difficulty            Shown vs acted on
//  recommendation_skipped        type, metric, reason                Why they ignore advice
//  nps_submitted                 score, category                     Would they recommend?
//  feedback_submitted            category, text_length, sentiment    What they want
//
// ─── Q4: WHAT CONVERTS TO PAID? ─────────────────────────────────────────────
//  paywall_viewed                source, days_since_install          When they see paywall
//  paywall_dismissed             time_on_paywall, source             Why they don't convert
//  paywall_cta_tapped            product_id, price                   Purchase intent
//  trial_started                 days_remaining                      Trial began
//  trial_day_check               days_remaining, milestones          Trial engagement
//  trial_expired                 milestones_completed                Why no conversion
//  subscription_purchased        product_id, trial_converted         Who pays
//  pro_feature_funnel            feature, step                       Which feature converts
//  premium_feature_attempted     feature, screen                     Free user desire
//
// ─── Q5: WHAT PREDICTS CHURN? ───────────────────────────────────────────────
//  subscription_cancelled        months_subscribed                   Who churns
//  subscription_renewed          months_subscribed                   Who stays
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
//  core_action_completed         action, screen                      Retention predictor
//  insight_tapped                category, severity, metric          Insight engagement
//  correlation_tapped            metric_a, metric_b, strength        Discovery
//  risk_tapped                   risk_type, grade                    Risk awareness
//  analysis_completed            score, insights_count               Engine output
//  weekly_score_change           delta, direction, new_score         Outcome improvement
//
// ─── USER PROPERTIES (cohort segmentation) ──────────────────────────────────
//
//  DEMOGRAPHICS:                                  PIPELINE:
//  age_bracket         18-24 | 25-34 | ...        data_sufficiency     sufficient | insufficient
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
//  nps_category        promoter | passive | detractor
//
// ─── BEHAVIORAL INTELLIGENCE (auto-computed, non-obvious) ───────────────────
//  ghost_session                 duration_sec, screens_visited      Opened but did nothing
//  session_quality               quality (deep/engaged/shallow/bounce) Session classification
//  score_viewed                  score, delta, direction            When score is seen
//  score_reaction                reaction_type, next_action         What they do after seeing score
//  screenshot_taken              screen, tab                        Trust/share signal
//  habit_ritual_formed           ritual_strength, peak_hour         Morning ritual detection
//  feature_discovered            feature, discovery_pct             Feature adoption map
//  rage_tap                      element, screen, tap_count         Frustration detection
//  pre_churn_signal              avg_engagement_score, trend        1-2 week churn warning
//  value_delivered               has_new_value, new_insights        Did this session matter?
//  background_refresh_result     success, samples_loaded            Data freshness pipeline
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

    private let queue = DispatchQueue(label: "com.healthpulse.analytics")
    private let session = SessionTracker.shared
    private let defaults = UserDefaults.standard

    private var openTimestamps: [AppFeature: Date] = [:]
    private var streamingStartDate: Date?
    private enum Key {
        static let subscriptionStartDate = "laso.analytics.subscription_start_date"
        static let renewalCount = "laso.analytics.renewal_count"
        static let trialConverted = "laso.analytics.trial_converted"
        static let lastKnownStatus = "laso.analytics.last_known_status"
        static let lastRenewalExpirationDate = "laso.analytics.last_renewal_expiration_date"
        static let firstScoreGeneratedTracked = "laso.analytics.first_score_generated_tracked"
    }

    private init() {}

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Demographics & Device Properties
    // ══════════════════════════════════════════════════════════════════════

    /// Set standard demographic and device user properties.
    /// Call on session start and after onboarding completes.
    func setDemographicProperties() {
        let defaults = UserDefaults.standard
        var props: [String: Any] = [:]

        // Age bracket. derived from stored age
        if let storedAge = defaults.object(forKey: AppKeys.Profile.dateOfBirth) as? Int, storedAge > 0 {
            let bracket: String
            switch storedAge {
            case ..<18:   bracket = "under_18"
            case 18...24: bracket = "18-24"
            case 25...34: bracket = "25-34"
            case 35...44: bracket = "35-44"
            case 45...54: bracket = "45-54"
            case 55...64: bracket = "55-64"
            default:      bracket = "65+"
            }
            props["age_bracket"] = bracket
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

        // Device model (marketing name)
        props["device_model"] = deviceModelName()

        // OS version
        props["os_version"] = UIDevice.current.systemVersion

        // App version
        props["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        if !props.isEmpty {
            PostHogManager.shared.setUserProperties(props)
        }
    }

    /// Returns the marketing device name (e.g. "iPhone 15 Pro") from the hw.machine identifier.
    private func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        // Return the raw identifier. PostHog can map these, and it avoids maintaining a lookup table.
        return machine
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Error Tracking (PostHog)
    // ══════════════════════════════════════════════════════════════════════

    /// Record a non-fatal error to PostHog for monitoring.
    func recordNonFatal(_ error: Error, context: String, metadata: [String: Any] = [:]) {
        PostHogManager.shared.captureError(error, context: context, metadata: metadata)
    }

    /// Record a string-described error (no Error object) to PostHog.
    func recordNonFatal(_ message: String, context: String, metadata: [String: Any] = [:]) {
        PostHogManager.shared.captureError(message, context: context, metadata: metadata)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 1. Activation Events
    // ══════════════════════════════════════════════════════════════════════

    /// Call when user completes a specific onboarding step.
    func trackOnboardingStepCompleted(step: Int, stepName: String, durationSec: Int) {
        logEvent("onboarding_step_completed", parameters: [
            "step": step,
            "step_name": stepName,
            "duration_sec": durationSec
        ])
    }

    /// Call when onboarding is fully completed.
    func trackOnboardingCompleted(focuses: [String], durationSec: Int, stepsCompleted: Int) {
        logEvent("onboarding_completed", parameters: [
            "focuses": focuses.joined(separator: ","),
            "focuses_count": focuses.count,
            "duration_sec": durationSec,
            "steps_completed": stepsCompleted,
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("onboarding_completed", value: "yes")
        setUserProperty("health_focus", value: focuses.joined(separator: ","))

        // Set demographics now that profile is captured
        setDemographicProperties()
    }

    /// Call when user drops off onboarding without completing.
    func trackOnboardingDropOff(lastStep: Int, lastStepName: String, durationSec: Int) {
        logEvent("onboarding_drop_off", parameters: [
            "last_step": lastStep,
            "last_step_name": lastStepName,
            "duration_sec": durationSec
        ])
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

    func trackTimeToFirstValue() {
        session.recordFirstValueTime()
        let ttfv = session.firstValueTimeSec
        if ttfv > 0 {
            logEvent("time_to_first_value", parameters: [
                "seconds": ttfv,
                "session_number": session.totalSessions
            ])
            setUserProperty("first_value_time_sec", value: "\(ttfv)")
        }
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

    /// Call when app enters foreground.
    func trackSessionStart() {
        session.startSession()

        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let dayNames = ["", "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

        logEvent("session_start", parameters: [
            "session_id": session.sessionId,
            "hour_of_day": hour,
            "day_of_week": dayNames[weekday],
            "streak_days": session.streakDays,
            "session_source": session.currentSessionSource.rawValue,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "days_since_install": session.daysSinceInstall,
            "weekly_active_days": session.weeklyActiveDays
        ])

        setUserProperty("streak_days", value: "\(session.streakDays)")
        setUserProperty("price_tier", value: SubscriptionConfig.currentTier.rawValue)
        setUserProperty("days_since_install", value: "\(session.daysSinceInstall)")
        setUserProperty("total_sessions", value: "\(session.totalSessions)")
        setUserProperty("lifetime_core_actions", value: "\(session.lifetimeCoreActions)")
        setUserProperty("weekly_active_days", value: "\(session.weeklyActiveDays)")
        setUserProperty("organic_session_pct", value: "\(session.organicSessionPercent)")
        setUserProperty("activation_status", value: session.isActivated ? "activated" : "not_activated")

        // Refresh demographic & device properties every session
        setDemographicProperties()
        updateJourneyProperties()

        // Behavioral intelligence: detect habit patterns
        detectHabitPattern()
    }

    /// Call when app enters background.
    func trackSessionEnd() {
        let stats = session.endSession()
        let coreActionsCount = session.coreActionsThisSession.count

        logEvent("session_end", parameters: [
            "session_id": session.sessionId,
            "duration_sec": stats.durationSec,
            "screens_visited": stats.screensVisited,
            "max_depth": stats.maxDepth,
            "core_actions_count": coreActionsCount
        ])

        // Behavioral intelligence: ghost sessions, churn risk, session quality
        evaluateSessionQuality(durationSec: stats.durationSec, screensVisited: stats.screensVisited, coreActionsCount: coreActionsCount)
        evaluateChurnRisk(durationSec: stats.durationSec, coreActionsCount: coreActionsCount, screensVisited: stats.screensVisited)
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
        let now = Date()
        let previousScreen = session.recordScreenView(feature.rawValue)

        queue.sync {
            self.openTimestamps[feature] = now
        }

        var params: [String: Any] = [
            "screen": feature.rawValue,
            "screen_id": feature.rawValue,
            "tab": session.currentTab,
            "depth": session.currentDepth
        ]
        if let previousScreen {
            params["previous_screen"] = previousScreen
            params["transition"] = "\(previousScreen)->\(feature.rawValue)"
        }
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_viewed", parameters: params)

        PostHogManager.shared.screen(feature.rawValue, properties: [
            "tab": session.currentTab,
            "depth": session.currentDepth
        ])

        // Behavioral intelligence: track feature discovery
        updateFeatureDiscovery(screen: feature)
    }

    func trackFeatureClose(_ feature: AppFeature, metadata: [String: Any] = [:]) {
        let now = Date()
        var durationSeconds = 0.0

        queue.sync {
            if let start = openTimestamps[feature] {
                durationSeconds = now.timeIntervalSince(start)
            }
            openTimestamps[feature] = nil
        }

        let duration = Int(durationSeconds.rounded())

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
        case askedHealthQuery = "asked_health_query"
    }

    func trackCoreAction(_ action: CoreAction, screen: AppFeature) {
        session.recordCoreAction(action.rawValue)

        // Score reaction: capture what the user does after seeing their score
        trackScoreReaction(nextAction: action.rawValue, nextScreen: screen)

        logEvent("core_action_completed", parameters: [
            "action": action.rawValue,
            "screen": screen.rawValue,
            "session_number": session.totalSessions,
            "core_actions_this_session": session.coreActionsThisSession.count,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "days_since_install": session.daysSinceInstall
        ])

        setUserProperty("lifetime_core_actions", value: "\(session.lifetimeCoreActions)")
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

    func trackCorrelationTapped(metricA: String, metricB: String, strength: String, screen: AppFeature) {
        logEvent("correlation_tapped", parameters: [
            "metric_a": metricA,
            "metric_b": metricB,
            "strength": strength,
            "screen": screen.rawValue
        ])
    }

    func trackRiskTapped(riskType: String, grade: String, screen: AppFeature) {
        logEvent("risk_tapped", parameters: [
            "risk_type": riskType,
            "grade": grade,
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
    func trackWeeklyScoreChange(newScore: Int, previousScore: Int?, delta: Int) {
        let direction: String
        if delta > 2 { direction = "improving" }
        else if delta < -2 { direction = "declining" }
        else { direction = "stable" }

        logEvent("weekly_score_change", parameters: [
            "new_score": newScore,
            "previous_score": previousScore ?? -1,
            "delta": delta,
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
            "score": score,
            "insights_per_metric": insightsPerMetric,
            "signal_density": signalDensity,
            "analysis_depth": analysisDepth
        ])

        setUserProperty("data_richness", value: metricsAnalyzed < 10 ? "low" : metricsAnalyzed < 30 ? "medium" : "high")
        setUserProperty("analysis_depth", value: analysisDepth)
        setUserProperty("last_score", value: "\(score)")
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
    func trackTrialStarted(daysRemaining: Int) {
        logEvent("trial_started", parameters: [
            "days_remaining": daysRemaining
        ])
        setUserProperty("subscription_status", value: "trial")
        setUserProperty("trial_converted", value: "pending")
        defaults.set("pending", forKey: Key.trialConverted)
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

        logEvent("trial_expired", parameters: [
            "converted": 0,
            "milestones_completed": session.completedMilestones.count,
            "total_sessions": session.totalSessions,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "was_activated": session.isActivated ? 1 : 0
        ])
        setUserProperty("trial_converted", value: "no")
        defaults.set("no", forKey: Key.trialConverted)
    }

    /// Call when paywall is viewed.
    func trackPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source,
            "tab": session.currentTab,
            "days_since_install": session.daysSinceInstall,
            "trial_converted": defaults.string(forKey: Key.trialConverted) ?? "pending",
            "was_activated": session.isActivated ? 1 : 0,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
    }

    /// Call when paywall is dismissed without purchasing.
    func trackPaywallDismissed(timeOnPaywallSec: Int, source: String) {
        logEvent("paywall_dismissed", parameters: [
            "time_on_paywall_sec": timeOnPaywallSec,
            "source": source,
            "days_since_install": session.daysSinceInstall,
            "trial_converted": defaults.string(forKey: Key.trialConverted) ?? "pending"
        ])
    }

    /// Call when user taps subscribe/CTA button on paywall.
    func trackPaywallCTATapped(productID: String, price: String) {
        logEvent("paywall_cta_tapped", parameters: [
            "product_id": productID,
            "price": price,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
    }

    /// Call after a successful purchase.
    func trackSubscriptionPurchased(productID: String, price: String, isTrialConversion: Bool) {
        let region = Locale.current.region?.identifier ?? "unknown"

        logEvent("subscription_purchased", parameters: [
            "product_id": productID,
            "price": price,
            "region": region,
            "price_tier": SubscriptionConfig.currentTier.rawValue,
            "trial_converted": isTrialConversion ? 1 : 0,
            "days_since_install": session.daysSinceInstall,
            "total_sessions": session.totalSessions,
            "milestones_completed": session.completedMilestones.count,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])

        if isTrialConversion {
            setUserProperty("trial_converted", value: "yes")
            defaults.set("yes", forKey: Key.trialConverted)
        }

        if defaults.object(forKey: Key.subscriptionStartDate) == nil {
            defaults.set(Date(), forKey: Key.subscriptionStartDate)
        }

        let renewals = defaults.integer(forKey: Key.renewalCount) + 1
        defaults.set(renewals, forKey: Key.renewalCount)

        setUserProperty("subscription_status", value: "pro")
        setUserProperty("renewal_count", value: "\(renewals)")
        updateMonthsSubscribed()
    }

    /// Call when we detect a renewal. Pass the new expiration date to deduplicate —
    /// the counter only increments when the expiration date differs from the last recorded one.
    func trackSubscriptionRenewed(newExpirationDate: Date? = nil) {
        // Deduplicate: only count if the expiration date is genuinely new
        if let newDate = newExpirationDate,
           let lastDate = defaults.object(forKey: Key.lastRenewalExpirationDate) as? Date,
           abs(newDate.timeIntervalSince(lastDate)) < 60 {
            // Same renewal period. skip
            return
        }

        if let newDate = newExpirationDate {
            defaults.set(newDate, forKey: Key.lastRenewalExpirationDate)
        }

        let renewals = defaults.integer(forKey: Key.renewalCount) + 1
        defaults.set(renewals, forKey: Key.renewalCount)

        updateMonthsSubscribed()

        logEvent("subscription_renewed", parameters: [
            "months_subscribed": monthsSubscribed,
            "renewal_count": renewals,
            "total_sessions": session.totalSessions
        ])

        setUserProperty("renewal_count", value: "\(renewals)")
    }

    /// Call when subscription transitions to expired.
    func trackSubscriptionCancelled() {
        logEvent("subscription_cancelled", parameters: [
            "months_subscribed": monthsSubscribed,
            "renewal_count": defaults.integer(forKey: Key.renewalCount),
            "total_sessions": session.totalSessions,
            "days_since_install": session.daysSinceInstall,
            "lifetime_core_actions": session.lifetimeCoreActions
        ])
        setUserProperty("subscription_status", value: "expired")
    }

    /// Call when restore purchases is attempted.
    func trackRestoreAttempted(success: Bool) {
        logEvent("restore_attempted", parameters: [
            "success": success ? 1 : 0,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call when a purchase fails.
    func trackPurchaseFailed(productID: String, errorType: String) {
        logEvent("purchase_failed", parameters: [
            "product_id": productID,
            "error_type": errorType,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Update subscription-related user properties. Call after subscription status changes.
    func updateSubscriptionProperties(status: SubscriptionManager.Status) {
        let previousStatus = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"

        let statusLabel: String
        let userTier: String
        switch status {
        case .trial(let daysRemaining):
            statusLabel = "trial"
            userTier = "trial"
            trackTrialDayCheck(daysRemaining: daysRemaining)
            if previousStatus == "unknown" {
                trackTrialStarted(daysRemaining: daysRemaining)
            }
        case .subscribed:
            statusLabel = "pro"
            userTier = "pro"
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
        return Calendar.current.dateComponents([.month], from: startDate, to: Date()).month ?? 0
    }

    private func updateMonthsSubscribed() {
        setUserProperty("months_subscribed", value: "\(monthsSubscribed)")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 10. Emotional / NPS
    // ══════════════════════════════════════════════════════════════════════

    /// Call when user submits NPS score (0-10).
    func trackNPSSubmitted(score: Int, source: String) {
        logEvent("nps_submitted", parameters: [
            "score": score,
            "source": source,
            "days_since_install": session.daysSinceInstall,
            "total_sessions": session.totalSessions,
            "lifetime_core_actions": session.lifetimeCoreActions,
            "was_activated": session.isActivated ? 1 : 0
        ])

        defaults.set(Date(), forKey: AppKeys.Feedback.lastNPSDate)
        defaults.set(score, forKey: AppKeys.Feedback.lastNPSScore)

        let category: String
        if score >= 9 { category = "promoter" }
        else if score >= 7 { category = "passive" }
        else { category = "detractor" }
        setUserProperty("nps_category", value: category)
    }

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

    func trackDeviceDetected(deviceType: String, metricsCount: Int, isActive: Bool) {
        logEvent("device_detected", parameters: [
            "device_type": deviceType,
            "metrics_count": metricsCount,
            "is_active": isActive ? 1 : 0
        ])
    }

    func updateDeviceProperties(activeCount: Int, primaryDevice: String) {
        setUserProperty("connected_device_count", value: "\(activeCount)")
        setUserProperty("primary_device", value: primaryDevice)
    }

    func trackDataSync(metricsCount: Int, newSamplesCount: Int, durationSec: Int, isFirstSync: Bool) {
        logEvent("data_sync_completed", parameters: [
            "metrics_count": metricsCount,
            "new_samples_count": newSamplesCount,
            "duration_sec": durationSec,
            "is_first_sync": isFirstSync ? 1 : 0
        ])
    }

    func trackReportExported(score: Int, metricsCount: Int, insightsCount: Int) {
        logEvent("report_exported", parameters: [
            "score": score,
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
        logEvent("setting_changed", parameters: [
            "setting_name": name,
            "new_value": stringValue,
            "screen": AppFeature.settings.rawValue
        ])
    }

    func trackNotificationSent(type: String) {
        logEvent("notification_sent", parameters: [
            "type": type
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
    func trackFeedbackPromptShown(daysSinceInstall: Int) {
        logEvent("feedback_prompt_shown", parameters: [
            "days_since_install": daysSinceInstall
        ])
    }

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

    // Section analytics
    func trackSectionViewed(section: AppSection, tab: AppFeature, durationMs: Int) {
        logEvent("section_viewed", parameters: [
            "section_id": section.rawValue,
            "tab": tab.rawValue,
            "screen": tab.rawValue,
            "duration_ms": durationMs,
            "session_id": session.sessionId
        ])
    }

    func trackSectionTapped(section: AppSection, tab: AppFeature, target: String) {
        logEvent("section_tapped", parameters: [
            "section_id": section.rawValue,
            "tab": tab.rawValue,
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
        var params: [String: Any] = [
            "category": category,
            "metric": metric,
            "severity": severity,
            "was_tapped": wasTapped,
            "outcome": outcome
        ]
        if let lift24h { params["lift_24h"] = lift24h }
        if let lift7d { params["lift_7d"] = lift7d }
        logEvent("recommendation_outcome", parameters: params)
    }

    // Notification opened
    func trackNotificationOpened(identifier: String) {
        let defaults = UserDefaults.standard
        let type = NotificationManager.notificationType(identifier)

        // Retrieve stored context from when notification was scheduled
        let hookCategory = defaults.string(forKey: "healthpulse.notif.hook.\(identifier)") ?? "unknown"
        let sentTimestamp = defaults.double(forKey: "healthpulse.notif.sent.\(identifier)")

        // Compute time-to-open in minutes
        let now = Date()
        let latencyMinutes: Int
        if sentTimestamp > 0 {
            latencyMinutes = Int(now.timeIntervalSince1970 - sentTimestamp) / 60
        } else {
            latencyMinutes = -1 // unknown
        }

        let cal = Calendar.current
        logEvent("notification_opened", parameters: [
            "notification_id": identifier,
            "type": type,
            "hook_category": hookCategory,
            "latency_minutes": latencyMinutes,
            "hour_opened": cal.component(.hour, from: now),
            "day_of_week": cal.component(.weekday, from: now)
        ])

        // Clean up stored context
        defaults.removeObject(forKey: "healthpulse.notif.hook.\(identifier)")
        defaults.removeObject(forKey: "healthpulse.notif.sent.\(identifier)")
    }

    // Monetization signals
    func trackPremiumFeatureAttempted(feature: String, screen: AppFeature) {
        logEvent("premium_feature_attempted", parameters: [
            "feature": feature,
            "screen": screen.rawValue,
            "days_since_install": session.daysSinceInstall
        ])
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

    func trackDiscoveryCompleted(pagesViewed: Int, totalPages: Int) {
        logEvent("discovery_completed", parameters: [
            "pages_viewed": pagesViewed,
            "total_pages": totalPages,
            "days_since_install": session.daysSinceInstall
        ])
    }

    // Generic action is intentionally unavailable to prevent non-actionable analytics.
    @available(*, unavailable, message: "Use specific AppAnalytics tracking methods with explicit metadata.")
    func trackAction(_ action: String, metadata: [String: Any] = [:]) {
        let sanitized = sanitizeEventName(action)
        logEvent(sanitized, parameters: metadata)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 14. Intelligence Suite
    // ══════════════════════════════════════════════════════════════════════

    func trackSimulationRun(adjustedMetrics: Int, scoreDelta: Int, confidence: Double) {
        logEvent("simulation_run", parameters: [
            "adjusted_metrics": adjustedMetrics,
            "score_delta": scoreDelta,
            "confidence": String(format: "%.2f", confidence),
            "screen": AppFeature.simulation.rawValue
        ])
    }

    func trackROIRecommendationTapped(metric: String, predictedGain: Int, effortLevel: String) {
        logEvent("roi_recommendation_tapped", parameters: [
            "metric": metric,
            "predicted_gain": predictedGain,
            "effort_level": effortLevel,
            "screen": AppFeature.simulation.rawValue
        ])
    }

    func trackECGAnalysisCompleted(recordingsCount: Int, afibCount: Int, insightsGenerated: Int) {
        logEvent("ecg_analysis_completed", parameters: [
            "recordings_count": recordingsCount,
            "afib_count": afibCount,
            "insights_generated": insightsGenerated
        ])
    }

    func trackNutritionCorrelationDiscovered(nutritionMetric: String, outcomeMetric: String, correlation: Double) {
        logEvent("nutrition_correlation_discovered", parameters: [
            "nutrition_metric": nutritionMetric,
            "outcome_metric": outcomeMetric,
            "correlation": String(format: "%.2f", correlation)
        ])
    }

    func trackClinicalInsightGenerated(metric: String, stage: String, trajectory: String) {
        logEvent("clinical_insight_generated", parameters: [
            "metric": metric,
            "clinical_stage": stage,
            "trajectory": trajectory
        ])
    }

    func trackHealthStateTimelineViewed(currentState: String, daysInState: Int, totalStates: Int) {
        logEvent("health_state_timeline_viewed", parameters: [
            "current_state": currentState,
            "days_in_state": daysInState,
            "total_states": totalStates,
            "screen": AppFeature.healthStateTimeline.rawValue
        ])
    }

    func trackCircadianAnalysisCompleted(chronotype: String, metricsAnalyzed: Int, confidence: Double) {
        logEvent("circadian_analysis_completed", parameters: [
            "chronotype": chronotype,
            "metrics_analyzed": metricsAnalyzed,
            "confidence": String(format: "%.2f", confidence)
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 15. Dashboard Metrics (Retention/Stickiness/Engagement)
    // ══════════════════════════════════════════════════════════════════════

    /// Fires once per calendar day to power DAU/WAU/MAU in PostHog.
    /// Call from session start. deduplicated by PostHog's unique user counting.
    func trackDailyActiveUser() {
        logEvent("daily_active", parameters: [
            "session_source": session.currentSessionSource.rawValue,
            "weekly_active_days": session.weeklyActiveDays,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }

    /// Track notification delivery (when we schedule a local notification).
    func trackNotificationScheduled(type: String, identifier: String, hookCategory: String? = nil) {
        let now = Date()
        let cal = Calendar.current
        var params: [String: Any] = [
            "type": type,
            "notification_id": identifier,
            "hour_scheduled": cal.component(.hour, from: now),
            "day_of_week": cal.component(.weekday, from: now)
        ]
        if let hook = hookCategory {
            params["hook_category"] = hook
            UserDefaults.standard.set(hook, forKey: "healthpulse.notif.hook.\(identifier)")
        }
        // Store send timestamp for time-to-open calculation
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "healthpulse.notif.sent.\(identifier)")
        logEvent("notification_scheduled", parameters: params)
    }

    /// Track when a notification is suppressed before delivery.
    /// Gives visibility into cap/filter behavior that would otherwise be invisible.
    func trackNotificationSuppressed(type: String, identifier: String, reason: String) {
        logEvent("notification_suppressed", parameters: [
            "type": type,
            "notification_id": identifier,
            "reason": reason
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

    /// Track insight usefulness (did user act on it?).
    func trackInsightEngagement(category: String, metric: String, action: String) {
        logEvent("insight_engagement", parameters: [
            "insight_category": category,
            "metric": metric,
            "action": action
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

    /// Call after HealthKit authorization response.
    func trackHealthPermissionResult(granted: Int, denied: Int, total: Int) {
        logEvent("health_permission_result", parameters: [
            "granted": granted,
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
            "score": score,
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

    /// Call when user marks an insight as helpful.
    func trackInsightMarkedHelpful(category: String, metric: String) {
        logEvent("insight_marked_helpful", parameters: [
            "insight_category": category,
            "metric": metric
        ])
    }

    /// Call when user marks an insight as unhelpful / false positive.
    func trackInsightMarkedUnhelpful(category: String, metric: String, reason: String = "") {
        logEvent("insight_marked_unhelpful", parameters: [
            "insight_category": category,
            "metric": metric,
            "reason": reason
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
            "difficulty": difficulty
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
            "reason": reason
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 19. Feature Lifecycle Metrics
    // ══════════════════════════════════════════════════════════════════════

    func trackWorkoutPlanGenerated(
        plan: WorkoutPlan,
        recoveryBand: WorkoutRecoveryBand,
        cyclePhase: CyclePhaseModifier?,
        screen: AppFeature
    ) {
        logEvent("workout_plan_generated", parameters: [
            "screen": screen.rawValue,
            "training_zone": plan.zone.rawValue,
            "recovery_band": recoveryBand.rawValue,
            "target_duration_min": plan.targetDuration,
            "estimated_calories": plan.estimatedCalories,
            "main_block_count": plan.mainBlocks.count,
            "has_cycle_adjustment": cyclePhase == nil ? 0 : 1,
            "cycle_phase": cyclePhase?.displayName ?? "none"
        ])
    }

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
        let completionRate = plannedDurationSec > 0
            ? min(max(Double(actualDurationSec) / Double(plannedDurationSec), 0), 1)
            : 0

        logEvent("breathwork_session_completed", parameters: [
            "protocol_type": breathingProtocol.subtitle,
            "protocol_id": breathingProtocol.rawValue,
            "planned_duration_sec": plannedDurationSec,
            "actual_duration_sec": actualDurationSec,
            "completion_rate": completionRate,
            "pause_count": pauseCount,
            "mood": mood?.rawValue.lowercased() ?? "unanswered"
        ])
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
        daysSinceFirstSync: Int
    ) {
        PostHogManager.shared.setUserProperties([
            "has_apple_watch": hasAppleWatch ? "yes" : "no",
            "health_source_count": "\(sourceCount)",
            "primary_health_source": primarySource,
            "days_since_first_sync": "\(daysSinceFirstSync)"
        ])
    }

    /// Update notification permission state as user property.
    func updateNotificationProperties(enabled: Bool) {
        setUserProperty("notifications_enabled", value: enabled ? "yes" : "no")
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

    /// Call when score generation fails.
    func trackScoreGenerationFailed(reason: String) {
        logEvent("score_generation_failed", parameters: [
            "reason": reason,
            "days_since_install": session.daysSinceInstall
        ])
    }

    /// Call when sync times out or fails.
    func trackSyncFailed(reason: String, retryCount: Int = 0) {
        logEvent("sync_failed", parameters: [
            "reason": reason,
            "retry_count": retryCount
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 22. Behavioral Intelligence (Non-Obvious Signals)
    // ══════════════════════════════════════════════════════════════════════

    // --- A. Ghost Sessions ---
    // A session where the user opened the app but did nothing meaningful.
    // Strongest leading indicator of disengagement. they came, saw nothing worth doing, and left.

    /// Call from `trackSessionEnd`. Automatically detects ghost sessions.
    func evaluateSessionQuality(durationSec: Int, screensVisited: Int, coreActionsCount: Int) {
        // Ghost: >5 sec but zero core actions and ≤1 screen
        let isGhost = durationSec >= 5 && coreActionsCount == 0 && screensVisited <= 1
        if isGhost {
            logEvent("ghost_session", parameters: [
                "duration_sec": durationSec,
                "screens_visited": screensVisited,
                "days_since_install": session.daysSinceInstall,
                "streak_days": session.streakDays,
                "session_source": session.currentSessionSource.rawValue
            ])
        }

        // Classify session quality for cohort analysis
        let quality: String
        if coreActionsCount >= 3 && screensVisited >= 3 { quality = "deep" }
        else if coreActionsCount >= 1 { quality = "engaged" }
        else if durationSec >= 5 { quality = "shallow" }
        else { quality = "bounce" }

        logEvent("session_quality", parameters: [
            "quality": quality,
            "duration_sec": durationSec,
            "screens_visited": screensVisited,
            "core_actions": coreActionsCount,
            "session_source": session.currentSessionSource.rawValue
        ])
    }

    // --- B. Score Reaction ---
    // When score changes, what does the user do? Investigate = engaged. Close = disengaging.
    // This reveals whether the scoring system drives action or apathy.

    private var lastScoreDelta: Int = 0
    private var scoreSeenDate: Date?

    /// Call when the score is first shown to the user.
    func trackScoreViewed(score: Int, previousScore: Int?) {
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
            "score": score,
            "delta": delta,
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

        let reactionType: String
        if nextAction.contains("insight") || nextAction.contains("metric") || nextAction.contains("correlation") {
            reactionType = "investigated"
        } else if nextAction.contains("setting") || nextAction == "session_end" {
            reactionType = "disengaged"
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

    private var screenshotObserver: Any?

    /// Call once at app launch to start observing screenshots.
    func startScreenshotTracking() {
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
        let hour = Calendar.current.component(.hour, from: Date())

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
            logEvent("habit_ritual_formed", parameters: [
                "ritual_strength": String(format: "%.2f", ritualStrength),
                "peak_hour": hours.max(by: { a, b in hours.filter { $0 == a }.count < hours.filter { $0 == b }.count }) ?? -1,
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
    func evaluateChurnRisk(durationSec: Int, coreActionsCount: Int, screensVisited: Int) {
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
                "avg_engagement_score": avgScore,
                "trend": "declining_3_sessions",
                "latest_score": engagementScore,
                "days_since_install": session.daysSinceInstall,
                "subscription_status": defaults.string(forKey: "laso.analytics.last_known_status") ?? "unknown"
            ])
        }

        // User property: engagement bucket
        let bucket: String
        if avgScore >= 70 { bucket = "power_user" }
        else if avgScore >= 40 { bucket = "casual" }
        else if avgScore >= 15 { bucket = "at_risk" }
        else { bucket = "disengaging" }
        setUserProperty("engagement_level", value: bucket)
    }

    // --- H. Background Refresh Success ---
    // If background refresh fails, the app feels stale when opened. Users leave.

    /// Call after background refresh completes.
    func trackBackgroundRefreshResult(success: Bool, durationMs: Int, samplesLoaded: Int) {
        logEvent("background_refresh_result", parameters: [
            "success": success ? 1 : 0,
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

    private func sanitizeEventName(_ name: String) -> String {
        let allowed = name.lowercased().map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" {
                return char
            }
            return "_"
        }
        let normalized = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if normalized.isEmpty { return "custom_event" }
        if normalized.count > 80 { return String(normalized.prefix(80)) }
        return normalized
    }

    private func canonicalEventName(_ name: String, parameters: [String: Any]) -> String {
        let screen = scopedValue("screen", in: parameters)
        let action = scopedValue("action", in: parameters)
        let metric = scopedValue("metric", in: parameters)
        let filterType = scopedValue("filter_type", in: parameters)
        let context = scopedValue("context", in: parameters)
        let section = scopedValue("section_id", in: parameters)
        let setting = scopedValue("setting_name", in: parameters)
        let notificationType = scopedValue("type", in: parameters)
        let recommendationType = scopedValue("recommendation_type", in: parameters)
        let explanationType = scopedValue("explanation_type", in: parameters)
        let source = scopedValue("source", in: parameters)
        let errorType = scopedValue("error_type", in: parameters)
        let activityKind = scopedValue("activity_kind", in: parameters)
        let trigger = scopedValue("trigger", in: parameters)
        let contentType = scopedValue("content_type", in: parameters)
        let feedbackCategory = scopedValue("category", in: parameters)
        let sourceType = scopedValue("source_type", in: parameters)

        switch name {
        case "session_start":
            return "app_session_started"
        case "session_end":
            return "app_session_ended"
        case "return_session":
            return "app_return_session_recorded"
        case "daily_active":
            return "app_daily_active_recorded"
        case "screen_viewed":
            return composedEventName([screen, "screen", "viewed"], fallback: "app_screen_viewed")
        case "screen_exited":
            return composedEventName([screen, "screen", "exited"], fallback: "app_screen_exited")
        case "block_tapped":
            return composedEventName([screen, "block", "tapped"], fallback: "app_block_tapped")
        case "core_action_completed":
            return composedEventName([screen, action, "completed"], fallback: "app_core_action_completed")
        case "insight_tapped":
            return composedEventName([screen, "insight", "tapped"], fallback: "insight_tapped")
        case "correlation_tapped":
            return composedEventName([screen, "correlation", "tapped"], fallback: "correlation_tapped")
        case "risk_tapped":
            return composedEventName([screen, "risk", "tapped"], fallback: "risk_tapped")
        case "chart_interaction":
            return composedEventName([screen, metric, "chart", "interacted"], fallback: "chart_interaction")
        case "pull_to_refresh":
            return composedEventName([screen, "pull", "to", "refresh", "triggered"], fallback: "pull_to_refresh_triggered")
        case "time_range_changed":
            return composedEventName([screen, context, "time", "range", "changed"], fallback: "time_range_changed")
        case "filter_changed":
            return composedEventName([screen, filterType, "filter", "changed"], fallback: "filter_changed")
        case "weekly_score_change":
            return "health_score_weekly_changed"
        case "analysis_completed":
            return "health_analysis_completed"
        case "data_sync_completed":
            return "health_data_sync_completed"
        case "sync_performance":
            return "health_data_sync_performance_measured"
        case "setting_changed":
            return composedEventName(["settings", setting, "changed"], fallback: "settings_changed")
        case "notification_sent":
            return composedEventName([notificationType, "notification", "sent"], fallback: "notification_sent")
        case "notification_opened":
            return composedEventName([notificationType, "notification", "opened"], fallback: "notification_opened")
        case "notification_scheduled":
            return composedEventName([notificationType, "notification", "scheduled"], fallback: "notification_scheduled")
        case "share_sheet_presented":
            return composedEventName([contentType, "share", "sheet", "presented"], fallback: "share_sheet_presented")
        case "feedback_submitted":
            return composedEventName([feedbackCategory, "feedback", "submitted"], fallback: "feedback_submitted")
        case "scroll_depth":
            return composedEventName([screen, "scroll", "depth", "recorded"], fallback: "scroll_depth_recorded")
        case "section_viewed":
            return composedEventName([section, "section", "viewed"], fallback: "section_viewed")
        case "section_tapped":
            return composedEventName([section, "section", "tapped"], fallback: "section_tapped")
        case "error_occurred":
            return composedEventName([screen, errorType, "error", "occurred"], fallback: "app_error_occurred")
        case "health_permission_requested":
            return "healthkit_permission_requested"
        case "health_permission_result":
            return "healthkit_permission_result_recorded"
        case "source_connected":
            return composedEventName([sourceType, "source", "connected"], fallback: "source_connected")
        case "recommendation_viewed":
            return composedEventName([recommendationType, "recommendation", "viewed"], fallback: "recommendation_viewed")
        case "recommendation_started":
            return composedEventName([recommendationType, "recommendation", "started"], fallback: "recommendation_started")
        case "recommendation_completed":
            return composedEventName([recommendationType, "recommendation", "completed"], fallback: "recommendation_completed")
        case "recommendation_skipped":
            return composedEventName([recommendationType, "recommendation", "skipped"], fallback: "recommendation_skipped")
        case "workout_plan_generated":
            return composedEventName([screen, "workout", "plan", "generated"], fallback: "workout_plan_generated")
        case "workout_plan_opened":
            return composedEventName([screen, "workout", "plan", "opened"], fallback: "workout_plan_opened")
        case "live_activity_state_changed":
            return composedEventName([activityKind, "live", "activity", "state", "changed"], fallback: "live_activity_state_changed")
        case "widget_snapshot_updated":
            return composedEventName([trigger, "widget", "snapshot", "updated"], fallback: "widget_snapshot_updated")
        case "empty_state_shown":
            return composedEventName([screen, "empty", "state", "shown"], fallback: "empty_state_shown")
        case "score_generation_failed":
            return "health_score_generation_failed"
        case "sync_failed":
            return "health_data_sync_failed"
        case "streaming_started":
            return "live_vitals_streaming_started"
        case "streaming_stopped":
            return "live_vitals_streaming_stopped"
        case "live_first_data_received":
            return "live_vitals_first_data_received"
        case "explanation_viewed":
            return composedEventName([screen, explanationType, "explanation", "viewed"], fallback: "explanation_viewed")
        case "privacy_page_viewed":
            return composedEventName([source, "privacy", "page", "viewed"], fallback: "privacy_page_viewed")
        case "background_refresh_result":
            return "background_refresh_completed"
        case "value_delivered":
            return "analysis_value_delivered"
        default:
            return name
        }
    }

    private func scopedValue(_ key: String, in parameters: [String: Any]) -> String? {
        guard let rawValue = parameters[key] else { return nil }
        let value = String(describing: rawValue)
        let slug = slugify(value)
        return slug == "unknown" ? nil : slug
    }

    private func composedEventName(_ parts: [String?], fallback: String) -> String {
        let components = parts.compactMap { part -> String? in
            guard let part, !part.isEmpty else { return nil }
            return part
        }
        guard !components.isEmpty else { return fallback }
        return components.joined(separator: "_")
    }

    private func sanitizeParameters(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (rawKey, rawValue) in parameters {
            let key = sanitizeEventName(rawKey)
            if key.isEmpty { continue }

            switch rawValue {
            case let value as String:
                sanitized[key] = value.count > 100 ? String(value.prefix(100)) : value
            case let value as Int:
                sanitized[key] = value
            case let value as Double:
                sanitized[key] = value
            case let value as Float:
                sanitized[key] = Double(value)
            case let value as Bool:
                sanitized[key] = value ? 1 : 0
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

    // MARK: - PostHog Backend (all events)

    fileprivate func logEvent(_ name: String, parameters: [String: Any]) {
        var enriched = parameters
        if enriched["session_id"] == nil {
            enriched["session_id"] = session.sessionId
        }
        if enriched["tab"] == nil {
            enriched["tab"] = session.currentTab
        }
        if enriched["screen"] == nil, let currentScreen = session.currentScreen {
            enriched["screen"] = currentScreen
        }
        if enriched["session_source"] == nil {
            enriched["session_source"] = session.currentSessionSource.rawValue
        }
        if enriched["session_number"] == nil {
            enriched["session_number"] = session.totalSessions
        }
        if enriched["days_since_install"] == nil {
            enriched["days_since_install"] = session.daysSinceInstall
        }
        if enriched["streak_days"] == nil {
            enriched["streak_days"] = session.streakDays
        }
        if enriched["weekly_active_days"] == nil {
            enriched["weekly_active_days"] = session.weeklyActiveDays
        }
        if enriched["nav_depth"] == nil {
            enriched["nav_depth"] = session.currentDepth
        }
        if enriched["organic_session_pct"] == nil {
            enriched["organic_session_pct"] = session.organicSessionPercent
        }
        if enriched["app_version"] == nil {
            enriched["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        }
        if enriched["subscription_status"] == nil {
            enriched["subscription_status"] = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"
        }
        if enriched["user_tier"] == nil {
            let status = defaults.string(forKey: Key.lastKnownStatus) ?? "unknown"
            enriched["user_tier"] = (status == "pro" || status == "billing_grace") ? "pro" : (status == "trial" ? "trial" : "free")
        }
        if enriched["onboarding_completed"] == nil {
            enriched["onboarding_completed"] = defaults.bool(forKey: AppKeys.App.onboardingCompleted) ? 1 : 0
        }
        if enriched["activation_status"] == nil {
            enriched["activation_status"] = session.isActivated ? "activated" : "not_activated"
        }

        let eventName = sanitizeEventName(canonicalEventName(name, parameters: enriched))
        let params = sanitizeParameters(enriched)
        PostHogManager.shared.capture(event: eventName, properties: params)
    }

    private func setUserProperty(_ name: String, value: String) {
        PostHogManager.shared.setUserProperty(name: name, value: value)
    }
}
