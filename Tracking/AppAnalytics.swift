import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

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
}

/// Actionable block/card types — only user-initiated taps and meaningful interactions.
enum BlockType: String {
    // Home — user taps
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

    // Live — user taps
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

    // Explore — user taps
    case categoryRow = "category_row"
    case healthScoreHero = "health_score_hero"
    case focusBanner = "focus_banner"

    // Category Detail — user taps
    case metricRow = "metric_row"

    // Devices — user taps
    case manageDevices = "manage_devices"
    case deviceRow = "device_row"
    case unconnectedDeviceRow = "unconnected_device_row"
    case appStoreLink = "app_store_link"

    // Settings — user taps
    case exportReport = "export_report"
    case settingsDoneButton = "settings_done_button"
    case metricAlertsPicker = "metric_alerts_picker"

    // Filters — user taps
    case trendFilter = "trend_filter"
    case periodSelector = "period_selector"
    case correlationFilterChip = "correlation_filter_chip"

    // Chart — user taps
    case chartTouch = "chart_touch"
    case chartDrag = "chart_drag"

    // Data Sync
    case dataSyncEvent = "data_sync_event"

    // Feedback — user taps
    case feedbackCategory = "feedback_category"
    case feedbackSubmit = "feedback_submit"
    case feedbackSkip = "feedback_skip"
    case feedbackDoneAfterSubmit = "feedback_done_after_submit"

    // Onboarding — user taps
    case onboardingConnectHealth = "onboarding_connect_health"
    case onboardingContinueAnyway = "onboarding_continue_anyway"
    case onboardingFocusChip = "onboarding_focus_chip"
    case onboardingGetStarted = "onboarding_get_started"
    case onboardingCultureContinue = "onboarding_culture_continue"
    case onboardingCalibrationRetry = "onboarding_calibration_retry"
    case onboardingCalibrationSkip = "onboarding_calibration_skip"
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

    // Home extras
    case homeCoachGoal = "home_coach_goal"
    case homeRiskRow = "home_risk_row"
    case homeRecoveryInfoButton = "home_recovery_info_button"

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
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference (PMF-Focused, Decision-Making Events Only)
// ──────────────────────────────────────────────────────────────────────────────
//
// PMF CORE METRICS (4 numbers that matter):
//   1. Activation %    → onboarding_completed → activation_completed funnel
//   2. Day 7 retention → retention_milestone day=7
//   3. % disappointed  → nps_submitted score < 7
//   4. % paying        → subscription_purchased conversion
//
// BUSINESS EVENTS:
//
//  Event                         Key Params                          Question Answered
//  ─────────────────────────────────────────────────────────────────────────────────────
//  SESSION & RETENTION:
//  session_start                 session_id, hour, weekday, streak,  When do users open?
//                                session_source, weekly_active_days  + How? (organic/notif)
//  session_end                   duration_sec, screens, depth        How deep are sessions?
//  return_session                session_number, days_since_last     Are users coming back?
//  daily_active                  session_source, weekly_active_days  DAU/WAU/MAU counting
//  retention_milestone           day (1,2,3,7,14,30)                 When do we lose users?
//  inactive_period_detected      days_inactive (3, 7)                Who is churning?
//  streak_broken                 previous_streak, longest_streak     When do habits break?
//  streak_milestone              days (7, 14, 30, 60, 100)           Who forms habits?
//
//  ACTIVATION:
//  onboarding_completed          focuses, duration_sec, step         Did they finish setup?
//  onboarding_step_completed     step, step_name, duration_sec       Where do they drop?
//  activation_completed          milestones_count, days_to_activate  Did they find value?
//  time_to_first_value           seconds                             How fast is aha moment?
//  activation_milestone          milestone, time_since_install       What features click?
//
//  FEATURE ENGAGEMENT:
//  screen_viewed                 screen, tab, depth, content         What do users see?
//  screen_exited                 screen, duration_sec                How long per feature?
//  feature_abandoned             screen, duration_sec                What confuses users?
//  block_tapped                  block_type, screen                  What UI gets tapped?
//  core_action_completed         action, screen                      What predicts retention?
//  chart_interaction             metric, type, period                Which charts explored?
//  time_range_changed            from_days, to_days                  What periods matter?
//
//  CONTENT VALUE:
//  insight_tapped                category, severity, metric          Which insights resonate?
//  correlation_tapped            metric_a, metric_b, strength        Which correlations?
//  risk_tapped                   risk_type, grade                    Do risks drive action?
//  analysis_completed            insights/anomalies counts           Is engine useful?
//  weekly_score_change           delta, direction, new_score         Is user improving?
//
//  MONETIZATION:
//  paywall_viewed                source, days_since_install          When do they see paywall?
//  paywall_dismissed             time_on_paywall, source             Why don't they convert?
//  paywall_cta_tapped            product_id, price                   What triggers purchase?
//  subscription_purchased        product_id, trial_converted         Who pays?
//  subscription_renewed          months_subscribed                   Who stays?
//  subscription_cancelled        months_subscribed                   Who churns?
//  trial_started                 days_remaining                      Trial began
//  trial_day_check               days_remaining, milestones          Engagement during trial
//  trial_expired                 milestones_completed                Why didn't they convert?
//  restore_attempted             success                             Are they confused?
//  purchase_failed               error_type                          What blocks payment?
//
//  EMOTIONAL / NPS:
//  nps_submitted                 score, category                     Would they recommend?
//  feedback_submitted            category, text_length, sentiment    What do they want?
//
//  FRICTION:
//  error_occurred                error_type, screen                  What breaks?
//  onboarding_drop_off           last_step, duration_sec             Where do they give up?
//
//  DEVICE & DATA:
//  device_detected               device_type, is_active              What devices do they own?
//  data_sync_completed           metrics, new_samples                Is sync healthy?
//  sync_performance              duration_ms, metrics, samples       How fast is sync?
//
//  DASHBOARD METRICS:
//  daily_active                  source, weekly_active_days          DAU/WAU/MAU
//  notification_scheduled        type, notification_id               Notif delivery tracking
//  ml_analysis_performance       duration_ms, components, data_pts   ML speed
//  pro_feature_funnel            feature, step                       Pro conversion by feature
//  insight_engagement            category, metric, action            Insight usefulness
//
// USER PROPERTIES (for cohort analysis):
//
//  Property                  Values                           Use
//  ─────────────────────────────────────────────────────────────────────────────
//  subscription_status       trial | pro | billing_grace |    Segment by tier
//                            expired | unknown
//  months_subscribed         0, 1, 2, ...                     LTV / churn month
//  trial_converted           yes | no | pending               Conversion rate
//  price_tier                standard | reduced | premium      Pricing analysis
//  days_since_install        0, 1, 2, ...                     Retention cohorts
//  activation_status         not_activated | activated         Did they find value?
//  activation_milestones     0-10                              Activation depth
//  total_sessions            1, 2, 3, ...                      Usage frequency
//  data_richness             low | medium | high               Data completeness
//  connected_device_count    0, 1, 2, ...                      Device ecosystem
//  primary_device            apple_watch | garmin | ...        Primary data source
//  health_focus              sleep,fitness,heartHealth,...      User goals
//  longest_streak            0, 1, 2, ...                      Habit strength
//  lifetime_core_actions     0, 1, 2, ...                      Value extracted
//  health_score_bracket      low | medium | high               Outcome segment
//  retention_day             0, 1, 2, 3, 7, 14, 30            Furthest milestone
//  onboarding_completed      yes | no                          Setup completion
//  weekly_active_days        1-7                                Stickiness (days/week)
//  organic_session_pct       0-100                              % organic (vs notif)
//
// ──────────────────────────────────────────────────────────────────────────────

/// Central analytics facade. Firebase Analytics backend.
/// Focused on PMF metrics: activation, retention, monetization, and value delivery.
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
    }

    private init() {}

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Crashlytics
    // ══════════════════════════════════════════════════════════════════════

    /// Record a non-fatal error to Crashlytics for monitoring without crashing.
    func recordNonFatal(_ error: Error, context: String, metadata: [String: Any] = [:]) {
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log("\(context): \(error.localizedDescription)")
        for (key, value) in metadata {
            crashlytics.setCustomValue("\(value)", forKey: key)
        }
        crashlytics.record(error: error)
    }

    /// Log a breadcrumb message to Crashlytics (visible in crash reports).
    func logBreadcrumb(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Set the Crashlytics user identifier for crash attribution.
    func setCrashlyticsUser(_ userId: String) {
        Crashlytics.crashlytics().setUserID(userId)
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
    }

    /// Call when app enters background.
    func trackSessionEnd() {
        let stats = session.endSession()

        logEvent("session_end", parameters: [
            "session_id": session.sessionId,
            "duration_sec": stats.durationSec,
            "screens_visited": stats.screensVisited,
            "max_depth": stats.maxDepth,
            "core_actions_count": session.coreActionsThisSession.count
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
        let now = Date()

        queue.sync {
            self.openTimestamps[feature] = now
        }

        let previousScreen = session.recordScreenView(feature.rawValue)

        var params: [String: Any] = [
            "screen": feature.rawValue,
            "screen_id": feature.rawValue,
            "tab": session.currentTab,
            "depth": session.currentDepth
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_viewed", parameters: params)

        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: feature.rawValue,
            AnalyticsParameterScreenClass: screenClassName(for: feature)
        ])

        if let previousScreen, previousScreen != feature.rawValue {
            logEvent("nav_transition", parameters: [
                "from_screen": previousScreen,
                "to_screen": feature.rawValue,
                "to_screen_id": feature.rawValue,
                "tab": session.currentTab,
                "depth": session.currentDepth
            ])
        }
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

        // Feature abandoned = opened but closed in < 3 seconds
        if duration < 3 && duration > 0 {
            logEvent("feature_abandoned", parameters: [
                "screen": feature.rawValue,
                "duration_sec": duration,
                "tab": session.currentTab
            ])
        }

        logEvent("screen_exited", parameters: [
            "screen": feature.rawValue,
            "screen_id": feature.rawValue,
            "tab": session.currentTab,
            "duration_sec": duration
        ])
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
    }

    func trackCoreAction(_ action: CoreAction, screen: AppFeature) {
        session.recordCoreAction(action.rawValue)

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
        logEvent("tap_\(type.rawValue)", parameters: params)
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
        logEvent("analysis_completed", parameters: [
            "insights_count": insightsCount,
            "anomalies_count": anomaliesCount,
            "risks_count": risksCount,
            "correlations_count": correlationsCount,
            "illness_warnings_count": illnessWarningsCount,
            "metrics_analyzed": metricsAnalyzed,
            "score": score
        ])

        setUserProperty("data_richness", value: metricsAnalyzed < 10 ? "low" : metricsAnalyzed < 30 ? "medium" : "high")

        let bracket: String
        if score >= 75 { bracket = "high" }
        else if score >= 50 { bracket = "medium" }
        else { bracket = "low" }
        setUserProperty("health_score_bracket", value: bracket)
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

    /// Call when we detect a renewal.
    func trackSubscriptionRenewed() {
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
            userTier = "free"
            trackTrialDayCheck(daysRemaining: daysRemaining)
            if previousStatus == "unknown" {
                trackTrialStarted(daysRemaining: daysRemaining)
            }
        case .subscribed:
            statusLabel = "pro"
            userTier = "pro"
            updateMonthsSubscribed()
            if previousStatus == "pro" {
                trackSubscriptionRenewed()
            }
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

    func trackThemeChanged(from fromTheme: String, to toTheme: String) {
        logEvent("theme_changed", parameters: [
            "from_theme": fromTheme,
            "to_theme": toTheme
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

    func trackFeedbackThankYouShown(category: String) {
        logEvent("feedback_thank_you_shown", parameters: [
            "category": category,
            "screen": AppFeature.feedback.rawValue
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

    func trackSectionStuck(section: AppSection, tab: AppFeature, durationMs: Int) {
        logEvent("section_stuck", parameters: [
            "section_id": section.rawValue,
            "tab": tab.rawValue,
            "screen": tab.rawValue,
            "duration_ms": durationMs,
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

    func trackConnectivityStateChanged(isOnline: Bool, isExpensive: Bool, isConstrained: Bool) {
        logEvent("connectivity_state_changed", parameters: [
            "is_online": isOnline ? 1 : 0,
            "is_expensive": isExpensive ? 1 : 0,
            "is_constrained": isConstrained ? 1 : 0
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
        logEvent("notification_opened", parameters: [
            "notification_id": identifier,
            "type": NotificationManager.notificationType(identifier)
        ])
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

    /// Fires once per calendar day to power DAU/WAU/MAU in Firebase.
    /// Call from session start — deduplicated by Firebase's unique user counting.
    func trackDailyActiveUser() {
        logEvent("daily_active", parameters: [
            "session_source": session.currentSessionSource.rawValue,
            "weekly_active_days": session.weeklyActiveDays,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])
    }

    /// Track notification delivery (when we schedule a local notification).
    func trackNotificationScheduled(type: String, identifier: String) {
        logEvent("notification_scheduled", parameters: [
            "type": type,
            "notification_id": identifier
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

    // MARK: - Private Helpers

    private func sanitizeEventName(_ name: String) -> String {
        let allowed = name.lowercased().map { char -> Character in
            if char.isLetter || char.isNumber || char == "_" {
                return char
            }
            return "_"
        }
        let normalized = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if normalized.isEmpty { return "custom_event" }
        if normalized.count > 40 { return String(normalized.prefix(40)) }
        return normalized
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

        let eventName = sanitizeEventName(name)
        let params = sanitizeParameters(enriched)
        Analytics.logEvent(eventName, parameters: params)
    }

    private func setUserProperty(_ name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    private func screenClassName(for feature: AppFeature) -> String {
        switch feature {
        case .home: return "HomeView"
        case .live: return "LiveView"
        case .explore: return "ExploreView"
        case .categoryDetail: return "CategoryDetailView"
        case .metricDetail: return "MetricDetailView"
        case .riskDetail: return "HealthRiskDetailView"
        case .settings: return "SettingsView"
        case .connectedDevices: return "ConnectedDevicesView"
        case .deviceDetail: return "DeviceDetailView"
        case .insightsDetail: return "InsightsDetailView"
        case .correlations: return "CorrelationsView"
        case .feedback: return "FeedbackSheet"
        case .onboarding: return "OnboardingView"
        case .weeklyReview: return "WeeklyReviewView"
        case .metricAlertPicker: return "MetricAlertPickerView"
        case .paywall: return "PaywallView"
        case .discovery: return "DiscoveryView"
        case .scoreGuide: return "ScoreGuideSheet"
        case .recoveryInfo: return "RecoveryInfoSheet"
        case .simulation: return "SimulationView"
        case .healthStateTimeline: return "HealthStateTimelineView"
        case .metricLog: return "MetricLogSheet"
        case .proOverlay: return "ProFeatureOverlay"
        }
    }
}
