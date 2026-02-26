import Foundation
import FirebaseAnalytics

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
}

/// Types of tappable blocks/cards in the app.
enum BlockType: String {
    // Home
    case recoveryCard = "recovery_card"
    case sleepCard = "sleep_card"
    case smartAction = "smart_action"
    case actionCard = "action_card"
    case headlineInsight = "headline_insight"
    case seeAllInsights = "see_all_insights"
    case seeAllNeedsAttention = "see_all_needs_attention"
    case seeAllCorrelations = "see_all_correlations"
    case weeklyReviewCard = "weekly_review_card"
    case settingsGear = "settings_gear"
    case emptyStateManageDevices = "empty_state_manage_devices"
    case emptyStateRefresh = "empty_state_refresh"
    case errorRetry = "error_retry"

    // Live
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

    // Explore
    case categoryRow = "category_row"
    case healthScoreHero = "health_score_hero"
    case focusBanner = "focus_banner"

    // Category Detail
    case metricRow = "metric_row"
    case insightCard = "insight_card"
    case patternCard = "pattern_card"

    // Correlations
    case correlationCard = "correlation_card"

    // Risk
    case focusArea = "focus_area"
    case focusAreaCard = "focus_area_card"
    case riskFactor = "risk_factor"

    // Devices
    case manageDevices = "manage_devices"
    case deviceRow = "device_row"
    case unconnectedDeviceRow = "unconnected_device_row"
    case appStoreLink = "app_store_link"

    // Settings
    case exportReport = "export_report"
    case settingsDoneButton = "settings_done_button"
    case metricAlertsPicker = "metric_alerts_picker"

    // Filters
    case trendFilter = "trend_filter"
    case periodSelector = "period_selector"

    // Section Impressions (Home)
    case todaysBriefingSection = "todays_briefing_section"
    case needsAttentionSection = "needs_attention_section"
    case correlationsSection = "correlations_section"
    case correlationCardImpression = "correlation_card_impression"
    case weeklyReviewSection = "weekly_review_section"
    case staleRecoveryCard = "stale_recovery_card"
    case connectHealthSection = "connect_health_section"
    case coachGreeting = "coach_greeting"
    case lastUpdatedFooter = "last_updated_footer"
    case periodSummarySection = "period_summary_section"

    // Section Impressions (MetricDetail)
    case metricDetailHeader = "metric_detail_header"
    case chartSection = "chart_section"
    case contextualSummary = "contextual_summary"
    case scoreBreakdownSection = "score_breakdown_section"
    case insightsSection = "insights_section"
    case actionBannerCard = "action_banner_card"

    // Section Impressions (Risk)
    case riskGaugeSection = "risk_gauge_section"
    case focusAreasSection = "focus_areas_section"
    case contributingFactorsSection = "contributing_factors_section"
    case disclaimerSection = "disclaimer_section"

    // Section Impressions (Live)
    case staleVitalsPrompt = "stale_vitals_prompt"
    case quickStatsRow = "quick_stats_row"
    case bloodPressureTempRow = "blood_pressure_temp_row"
    case liveHeaderSection = "live_header_section"
    case heartRateMiniChart = "heart_rate_mini_chart"
    case vitalSignsRow = "vital_signs_row"

    // Section Impressions (Explore)
    case categoryList = "category_list"
    case weakestCategoryBanner = "weakest_category_banner"

    // Section Impressions (Category Detail)
    case categoryScoreRing = "category_score_ring"
    case categoryTrendSummary = "category_trend_summary"
    case categoryInsightsSection = "category_insights_section"
    case categoryMetricList = "category_metric_list"

    // Section Impressions (Weekly Review)
    case weeklyScoreSection = "weekly_score_section"
    case weeklyWinsSection = "weekly_wins_section"
    case weeklyWatchOutSection = "weekly_watch_out_section"

    // Section Impressions (Insights Detail)
    case insightsFilterChips = "insights_filter_chips"
    case actionableInsightCard = "actionable_insight_card"

    // Section Impressions (Correlations View)
    case correlationsFilterChips = "correlations_filter_chips"
    case correlationDetailCard = "correlation_detail_card"

    // Section Impressions (Settings)
    case settingsConnectedDevices = "settings_connected_devices"
    case settingsDailySummary = "settings_daily_summary"
    case settingsWeeklySummary = "settings_weekly_summary"
    case settingsHeartRateAlerts = "settings_heart_rate_alerts"
    case settingsAppleWatch = "settings_apple_watch"
    case settingsAlerts = "settings_alerts"
    case settingsMetricAlerts = "settings_metric_alerts"
    case settingsDataExport = "settings_data_export"
    case settingsAppearance = "settings_appearance"
    case settingsOnDeviceData = "settings_on_device_data"
    case settingsAbout = "settings_about"

    // Chart Interactions
    case chartTouch = "chart_touch"
    case chartDrag = "chart_drag"

    // Data Sync
    case dataSyncEvent = "data_sync_event"

    // Feedback
    case feedbackCategory = "feedback_category"
    case feedbackSubmit = "feedback_submit"
    case feedbackSkip = "feedback_skip"
    case feedbackDoneAfterSubmit = "feedback_done_after_submit"

    // Onboarding
    case onboardingConnectHealth = "onboarding_connect_health"
    case onboardingContinueAnyway = "onboarding_continue_anyway"
    case onboardingFocusChip = "onboarding_focus_chip"
    case onboardingGetStarted = "onboarding_get_started"
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference
// ──────────────────────────────────────────────────────────────────────────────
//
//  Event                     Key Params                              Answers
//  ─────────────────────────────────────────────────────────────────────────────
//  session_start             session_id, hour_of_day,                DAU, sessions,
//                            day_of_week, streak_days                 time-of-use
//  session_end               session_id, duration_sec,               session depth,
//                            screens_visited, max_depth               session duration
//  streak_updated            streak_days, is_longest                 continuous streak
//  tab_switched              tab, from_tab                           tab-wise usage
//  screen_viewed             screen, tab, depth, (+ context)         feature usage,
//                                                                    frequency, retention
//  screen_exited             screen, tab, duration_sec               duration per section
//  block_tapped              block_title, block_type,                clicked titles,
//                            screen, tab                              engagement
//  nav_transition            from_screen, to_screen                  behavioral transitions
//  feature_used              feature, duration_sec                    meaningful engagement
//  feature_stuck             feature, short_sessions_15m             struggle points
//  pull_to_refresh           screen                                  refresh frequency
//  time_range_changed        screen, context, from_days, to_days     time range preference
//  filter_changed            screen, filter_type, from, to           filter usage patterns
//  setting_changed           setting_name, new_value                 settings engagement
//  theme_changed             from_theme, to_theme                    appearance preference
//  streaming_started         -                                       live usage start
//  streaming_stopped         duration_sec                            live session length
//  live_first_data_received  -                                       connectivity success
//  heart_rate_zone_changed   from_zone, to_zone, bpm                 HR zone transitions
//  empty_state_shown         screen, state_type                      data gaps / UX issues
//  share_sheet_presented     content_type                            export engagement
//  card_impressed            card_type, screen                       card visibility
//  feedback_prompt_shown     days_since_install                      prompt timing
//  feedback_submitted        category, text_length                   user feedback
//
// ──────────────────────────────────────────────────────────────────────────────

/// Central analytics facade. Uses Firebase Analytics when available, otherwise logs to console.
final class AppAnalytics {
    static let shared = AppAnalytics()

    private let queue = DispatchQueue(label: "com.healthpulse.analytics")
    private let session = SessionTracker.shared

    private var openTimestamps: [AppFeature: Date] = [:]
    private var shortSessionTimestamps: [AppFeature: [Date]] = [:]
    private var streamingStartDate: Date?

    private init() {}

    // MARK: - Session Events

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
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])

        logEvent("streak_updated", parameters: [
            "streak_days": session.streakDays,
            "is_longest": session.isLongestStreak ? 1 : 0
        ])

        setUserProperty("streak_days", value: "\(session.streakDays)")
        setUserProperty("price_tier", value: SubscriptionConfig.currentTier.rawValue)
    }

    /// Update subscription-related user properties. Call after subscription status changes.
    func updateSubscriptionProperties(status: SubscriptionManager.Status) {
        let statusLabel: String
        let userTier: String
        switch status {
        case .trial:
            statusLabel = "trial"
            userTier = "free"
        case .subscribed:
            statusLabel = "pro"
            userTier = "pro"
        case .expired:
            statusLabel = "expired"
            userTier = "free"
        case .unknown:
            statusLabel = "unknown"
            userTier = "free"
        }
        setUserProperty("subscription_status", value: statusLabel)
        setUserProperty("user_tier", value: userTier)
    }

    /// Call when app enters background.
    func trackSessionEnd() {
        let stats = session.endSession()

        logEvent("session_end", parameters: [
            "session_id": session.sessionId,
            "duration_sec": stats.durationSec,
            "screens_visited": stats.screensVisited,
            "max_depth": stats.maxDepth
        ])
    }

    // MARK: - Tab Events

    func trackTabSwitch(to tab: String, from fromTab: String) {
        session.currentTab = tab

        logEvent("tab_switched", parameters: [
            "tab": tab,
            "from_tab": fromTab
        ])
    }

    // MARK: - Screen Events

    func trackFeatureOpen(_ feature: AppFeature, metadata: [String: Any] = [:]) {
        let now = Date()

        queue.sync {
            self.openTimestamps[feature] = now
        }

        // Record transition
        let fromScreen = session.recordScreenView(feature.rawValue)

        var params: [String: Any] = [
            "screen": feature.rawValue,
            "tab": session.currentTab,
            "depth": session.currentDepth
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_viewed", parameters: params)

        // Log nav_transition if coming from another screen
        if let from = fromScreen, from != feature.rawValue {
            logEvent("nav_transition", parameters: [
                "from_screen": from,
                "to_screen": feature.rawValue
            ])
        }

        // Legacy event
        var legacyParams = metadata
        legacyParams["feature"] = feature.rawValue
        logEvent("feature_open", parameters: legacyParams)
    }

    func trackFeatureClose(_ feature: AppFeature, metadata: [String: Any] = [:]) {
        let now = Date()
        var durationSeconds = 0.0

        queue.sync {
            if let start = openTimestamps[feature] {
                durationSeconds = now.timeIntervalSince(start)
            }
            openTimestamps[feature] = nil

            // "Stuck" heuristic: repeated short sessions (<=20s) within 15 minutes
            if durationSeconds <= 20 {
                var shortSessions = shortSessionTimestamps[feature] ?? []
                shortSessions.append(now)
                let cutoff = now.addingTimeInterval(-15 * 60)
                shortSessions = shortSessions.filter { $0 >= cutoff }
                shortSessionTimestamps[feature] = shortSessions

                if shortSessions.count >= 3 {
                    logEvent("feature_stuck", parameters: [
                        "feature": feature.rawValue,
                        "short_sessions_15m": shortSessions.count
                    ])
                    shortSessionTimestamps[feature] = [now]
                }
            }
        }

        let duration = Int(durationSeconds.rounded())

        logEvent("screen_exited", parameters: [
            "screen": feature.rawValue,
            "tab": session.currentTab,
            "duration_sec": duration
        ])

        // Legacy events
        var legacyParams = metadata
        legacyParams["feature"] = feature.rawValue
        legacyParams["duration_sec"] = duration
        logEvent("feature_close", parameters: legacyParams)

        if durationSeconds >= 30 {
            logEvent("feature_used", parameters: [
                "feature": feature.rawValue,
                "duration_sec": duration
            ])
        }
    }

    // MARK: - Block Tap Events

    func trackBlockTap(title: String, type: BlockType, screen: AppFeature) {
        logEvent("block_tapped", parameters: [
            "block_title": title,
            "block_type": type.rawValue,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ])
    }

    // MARK: - Pull to Refresh

    func trackPullToRefresh(screen: AppFeature) {
        logEvent("pull_to_refresh", parameters: [
            "screen": screen.rawValue,
            "tab": session.currentTab
        ])
    }

    // MARK: - Time Range Changed

    /// Tracks when user changes the time range picker (7D, 30D, 3M, 6M).
    func trackTimeRangeChanged(screen: AppFeature, context: String, fromDays: Int, toDays: Int) {
        logEvent("time_range_changed", parameters: [
            "screen": screen.rawValue,
            "context": context,
            "from_days": fromDays,
            "to_days": toDays
        ])
    }

    // MARK: - Filter Changed

    /// Tracks when user selects a different filter chip (Insights, Correlations).
    func trackFilterChanged(screen: AppFeature, filterType: String, from: String, to: String) {
        logEvent("filter_changed", parameters: [
            "screen": screen.rawValue,
            "filter_type": filterType,
            "from_filter": from,
            "to_filter": to
        ])
    }

    // MARK: - Settings Changed

    /// Tracks individual setting toggle/slider/stepper changes.
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

    /// Tracks theme change separately for deeper analysis.
    func trackThemeChanged(from fromTheme: String, to toTheme: String) {
        logEvent("theme_changed", parameters: [
            "from_theme": fromTheme,
            "to_theme": toTheme
        ])
    }

    // MARK: - Live Streaming Events

    /// Tracks when live data streaming begins.
    func trackStreamingStarted() {
        streamingStartDate = Date()
        logEvent("streaming_started", parameters: [
            "screen": AppFeature.live.rawValue
        ])
    }

    /// Tracks when live data streaming ends with duration.
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

    /// Tracks the first time live data arrives in a session.
    func trackLiveFirstDataReceived() {
        logEvent("live_first_data_received", parameters: [
            "screen": AppFeature.live.rawValue
        ])
    }

    /// Tracks heart rate zone transitions.
    func trackHeartRateZoneChanged(fromZone: String, toZone: String, bpm: Int) {
        logEvent("heart_rate_zone_changed", parameters: [
            "from_zone": fromZone,
            "to_zone": toZone,
            "bpm": bpm
        ])
    }

    // MARK: - Empty State Events

    /// Tracks when an empty/waiting state is displayed to the user.
    func trackEmptyStateShown(screen: AppFeature, stateType: String) {
        logEvent("empty_state_shown", parameters: [
            "screen": screen.rawValue,
            "state_type": stateType,
            "tab": session.currentTab
        ])
    }

    // MARK: - Card Impressions

    /// Tracks when a card/section becomes visible to the user.
    func trackCardImpression(cardType: BlockType, screen: AppFeature) {
        logEvent("card_impressed", parameters: [
            "card_type": cardType.rawValue,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ])
    }

    // MARK: - Share Sheet

    /// Tracks when a share sheet is presented.
    func trackShareSheetPresented(contentType: String) {
        logEvent("share_sheet_presented", parameters: [
            "content_type": contentType,
            "screen": AppFeature.settings.rawValue
        ])
    }

    // MARK: - Navigation Depth

    func updateNavigationDepth(_ depth: Int) {
        session.updateDepth(depth)
    }

    // MARK: - Feedback Events

    func trackFeedbackPromptShown(daysSinceInstall: Int) {
        logEvent("feedback_prompt_shown", parameters: [
            "days_since_install": daysSinceInstall
        ])
    }

    func trackFeedbackSubmitted(category: String, textLength: Int) {
        logEvent("feedback_submitted", parameters: [
            "category": category,
            "text_length": textLength
        ])
    }

    // MARK: - Section Impression with Context

    /// Tracks when a section/block becomes visible with optional metadata.
    func trackSectionImpression(section: BlockType, screen: AppFeature, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "section": section.rawValue,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("section_impressed", parameters: params)
    }

    // MARK: - Chart Interaction Events

    /// Tracks when user touches/selects a point on a chart.
    func trackChartInteraction(metric: String, interactionType: String, screen: AppFeature, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "metric": metric,
            "interaction_type": interactionType,
            "screen": screen.rawValue,
            "tab": session.currentTab
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("chart_interaction", parameters: params)
    }

    // MARK: - Data Sync Events

    /// Tracks a HealthKit data sync completion.
    func trackDataSync(metricsCount: Int, newSamplesCount: Int, durationSec: Int, isFirstSync: Bool) {
        logEvent("data_sync_completed", parameters: [
            "metrics_count": metricsCount,
            "new_samples_count": newSamplesCount,
            "duration_sec": durationSec,
            "is_first_sync": isFirstSync ? 1 : 0
        ])
    }

    // MARK: - Scroll Depth

    /// Tracks how far down the user scrolled on a screen (0.0 to 1.0).
    func trackScrollDepth(screen: AppFeature, maxDepthPercent: Int) {
        logEvent("scroll_depth", parameters: [
            "screen": screen.rawValue,
            "max_depth_percent": maxDepthPercent,
            "tab": session.currentTab
        ])
    }

    // MARK: - Subscription Events

    /// Tracks when user views the subscription/paywall screen.
    func trackPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source,
            "tab": session.currentTab
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 1. Activation Discovery
    // ══════════════════════════════════════════════════════════════════════

    /// Standard activation milestones. Track each the FIRST time it happens.
    enum ActivationMilestone: String {
        case firstDataLoad = "first_data_load"              // HealthKit data loaded
        case firstScoreSeen = "first_score_seen"            // Saw health score
        case firstInsightViewed = "first_insight_viewed"    // Opened an insight
        case firstMetricDetail = "first_metric_detail"      // Drilled into a metric
        case firstChartInteraction = "first_chart_interaction" // Touched a chart
        case firstWeeklyReview = "first_weekly_review"      // Opened weekly review
        case firstCorrelation = "first_correlation"         // Viewed a correlation
        case firstLiveSession = "first_live_session"        // Used Live tab 30s+
        case firstSettingsVisit = "first_settings_visit"    // Opened settings
        case firstPullToRefresh = "first_pull_to_refresh"   // Pulled to refresh
    }

    /// Fire once per milestone. Tracks activation funnel + time-to-milestone.
    func trackActivationMilestone(_ milestone: ActivationMilestone) {
        let isNew = session.recordMilestone(milestone.rawValue)
        guard isNew else { return }

        let timeSinceInstall = Int(Date().timeIntervalSince(session.installDate))
        let sessionNumber = session.totalSessions

        logEvent("activation_milestone", parameters: [
            "milestone": milestone.rawValue,
            "session_number": sessionNumber,
            "time_since_install_sec": timeSinceInstall,
            "session_elapsed_sec": session.sessionElapsedSeconds,
            "milestones_completed": session.completedMilestones.count,
            "is_first_session": session.isFirstSession ? 1 : 0
        ])

        // Update user property with milestone count
        setUserProperty("activation_milestones", value: "\(session.completedMilestones.count)")

        // If user hit 3+ milestones → activated
        if session.completedMilestones.count >= 3 {
            setUserProperty("activation_status", value: "activated")
        }
    }

    /// Fires at end of first session with a profile of what the user did.
    func trackFirstSessionProfile() {
        guard session.isFirstSession else { return }

        logEvent("first_session_profile", parameters: [
            "screens_visited": session.screensVisited.count,
            "max_depth": session.maxDepth,
            "milestones_completed": session.completedMilestones.count,
            "core_actions": session.coreActionsThisSession.joined(separator: ","),
            "duration_sec": session.sessionElapsedSeconds
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 2. Behavior → Retention Causality
    // ══════════════════════════════════════════════════════════════════════

    /// Core actions that predict retention. Call each time one is performed.
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

    /// Track a core action completion for retention analysis.
    func trackCoreAction(_ action: CoreAction, screen: AppFeature) {
        session.recordCoreAction(action.rawValue)

        logEvent("core_action_completed", parameters: [
            "action": action.rawValue,
            "screen": screen.rawValue,
            "session_number": session.totalSessions,
            "session_elapsed_sec": session.sessionElapsedSeconds,
            "core_actions_this_session": session.coreActionsThisSession.count,
            "days_since_install": session.daysSinceInstall
        ])

        // Update user property with total core actions this session
        setUserProperty("session_core_actions", value: "\(session.coreActionsThisSession.count)")
    }

    /// Record time-to-first-value: how long until user first saw their health score.
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

    /// Fires on 2nd+ session to track return behavior.
    func trackReturnSession() {
        guard session.totalSessions > 1 else { return }

        logEvent("return_session", parameters: [
            "session_number": session.totalSessions,
            "days_since_last_session": session.daysSinceLastSession ?? -1,
            "days_since_install": session.daysSinceInstall,
            "streak_days": session.streakDays
        ])

        setUserProperty("total_sessions", value: "\(session.totalSessions)")
        setUserProperty("days_since_install", value: "\(session.daysSinceInstall)")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 3. Behavior → Monetization Signal
    // ══════════════════════════════════════════════════════════════════════

    /// Track when a free user attempts a premium feature (hits paywall).
    func trackPremiumFeatureAttempted(feature: String, screen: AppFeature) {
        logEvent("premium_feature_attempted", parameters: [
            "feature": feature,
            "screen": screen.rawValue,
            "session_number": session.totalSessions,
            "days_since_install": session.daysSinceInstall,
            "core_actions_this_session": session.coreActionsThisSession.count
        ])
    }

    /// Track high-engagement signal — user crossed an engagement threshold.
    func trackHighEngagementSignal(signal: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "signal": signal,
            "session_number": session.totalSessions,
            "days_since_install": session.daysSinceInstall
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("high_engagement_signal", parameters: params)
    }

    /// Track pre-purchase behavior (browsed paywall, compared plans, etc.)
    func trackPrePurchaseBehavior(action: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "action": action,
            "session_number": session.totalSessions,
            "days_since_install": session.daysSinceInstall
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("pre_purchase_behavior", parameters: params)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - 4. Churn Forensics
    // ══════════════════════════════════════════════════════════════════════

    /// Fires at end of EVERY session with quality metrics for churn analysis.
    func trackSessionQuality() {
        let stats = session.endSession()

        let engagementScore = min(100, (stats.screensVisited * 10) + (stats.maxDepth * 15) + min(stats.durationSec / 6, 50))

        logEvent("session_quality", parameters: [
            "session_number": session.totalSessions,
            "duration_sec": stats.durationSec,
            "screens_visited": stats.screensVisited,
            "max_depth": stats.maxDepth,
            "core_actions_count": session.coreActionsThisSession.count,
            "core_actions": session.coreActionsThisSession.prefix(10).joined(separator: ","),
            "engagement_score": engagementScore,
            "days_since_install": session.daysSinceInstall,
            "streak_days": session.streakDays,
            "is_first_session": session.isFirstSession ? 1 : 0
        ])

        // Update user properties for cohort analysis
        setUserProperty("last_engagement_score", value: "\(engagementScore)")
        setUserProperty("last_session_depth", value: "\(stats.maxDepth)")
        setUserProperty("last_core_action", value: session.coreActionsThisSession.last ?? "none")

        // Monetization signal: high-engagement sessions predict payment
        if engagementScore >= 70 {
            trackHighEngagementSignal(signal: "high_session_quality", metadata: [
                "engagement_score": engagementScore,
                "core_actions_count": session.coreActionsThisSession.count
            ])
        }
        if session.coreActionsThisSession.count >= 5 {
            trackHighEngagementSignal(signal: "power_session", metadata: [
                "core_actions_count": session.coreActionsThisSession.count,
                "screens_visited": stats.screensVisited
            ])
        }
    }

    /// Track the last meaningful action before session ends (for churn forensics).
    func trackLastMeaningfulAction(action: String, screen: AppFeature) {
        setUserProperty("last_meaningful_action", value: action)
        setUserProperty("last_active_screen", value: screen.rawValue)
    }

    // MARK: - Generic Action

    func trackAction(_ action: String, metadata: [String: Any] = [:]) {
        let sanitized = sanitizeEventName(action)
        logEvent(sanitized, parameters: metadata)
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

    fileprivate func logEvent(_ name: String, parameters: [String: Any]) {
        let eventName = sanitizeEventName(name)
        let params = sanitizeParameters(parameters)
        Analytics.logEvent(eventName, parameters: params)
    }

    private func setUserProperty(_ name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}
