import Foundation
import HealthKit
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
    case paywall
}

/// Actionable block/card types — only user-initiated taps and meaningful interactions.
/// Section impressions removed (they were noise, not actionable).
enum BlockType: String {
    // Home — user taps
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
    case insightCard = "insight_card"
    case patternCard = "pattern_card"

    // Correlations — user taps
    case correlationCard = "correlation_card"

    // Risk — user taps
    case focusArea = "focus_area"
    case focusAreaCard = "focus_area_card"
    case riskFactor = "risk_factor"

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

    // Legacy section impression types — kept for compile compatibility, no longer logged.
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
    case metricDetailHeader = "metric_detail_header"
    case chartSection = "chart_section"
    case contextualSummary = "contextual_summary"
    case scoreBreakdownSection = "score_breakdown_section"
    case insightsSection = "insights_section"
    case actionBannerCard = "action_banner_card"
    case riskGaugeSection = "risk_gauge_section"
    case focusAreasSection = "focus_areas_section"
    case contributingFactorsSection = "contributing_factors_section"
    case disclaimerSection = "disclaimer_section"
    case staleVitalsPrompt = "stale_vitals_prompt"
    case quickStatsRow = "quick_stats_row"
    case bloodPressureTempRow = "blood_pressure_temp_row"
    case liveHeaderSection = "live_header_section"
    case heartRateMiniChart = "heart_rate_mini_chart"
    case vitalSignsRow = "vital_signs_row"
    case categoryList = "category_list"
    case weakestCategoryBanner = "weakest_category_banner"
    case categoryScoreRing = "category_score_ring"
    case categoryTrendSummary = "category_trend_summary"
    case categoryInsightsSection = "category_insights_section"
    case categoryMetricList = "category_metric_list"
    case weeklyScoreSection = "weekly_score_section"
    case weeklyWinsSection = "weekly_wins_section"
    case weeklyWatchOutSection = "weekly_watch_out_section"
    case insightsFilterChips = "insights_filter_chips"
    case actionableInsightCard = "actionable_insight_card"
    case correlationsFilterChips = "correlations_filter_chips"
    case correlationDetailCard = "correlation_detail_card"
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
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference (Decision-Making Events Only)
// ──────────────────────────────────────────────────────────────────────────────
//
// BUSINESS EVENTS (these answer real questions):
//
//  Event                         Key Params                          Question Answered
//  ─────────────────────────────────────────────────────────────────────────────────────
//  session_start                 session_id, hour, weekday, streak   DAU, time-of-use
//  session_end                   duration_sec, screens, max_depth    session depth
//  screen_viewed                 screen, tab, depth                  feature usage
//  screen_exited                 screen, duration_sec                time per feature
//  block_tapped                  block_type, screen                  what users tap
//  trial_started                 days_remaining                      install→trial funnel
//  trial_day_check               days_remaining, engagement_score    trial health
//  trial_expired                 converted, milestones_completed     why users don't pay
//  paywall_viewed                source, trial_days_remaining        paywall reach rate
//  paywall_dismissed             time_on_paywall_sec                 paywall friction
//  subscription_purchased        product_id, price, region, trial_converted   revenue
//  subscription_renewed          months_subscribed, renewal_count    retention/LTV
//  subscription_cancelled        months_subscribed, last_action      churn reason
//  feedback_submitted            category, text_length               what users want
//  activation_milestone          milestone, time_since_install_sec   aha moments
//  core_action_completed         action, days_since_install          retention signals
//
// USER PROPERTIES (for cohort analysis in Firebase/GA4):
//
//  Property                  Values                           Use
//  ─────────────────────────────────────────────────────────────────────────────
//  subscription_status       trial | pro | billing_grace |    Segment everything by tier
//                            expired | unknown
//  months_subscribed         0, 1, 2, ...                     LTV / churn month
//  trial_converted           yes | no | pending               Conversion rate
//  biological_sex            male | female | other | unknown   Demographic segmentation
//  age_bracket               18-24 | 25-34 | 35-44 | ...      Age-based behavior
//  region                    US | IN | DE | ...                Geo segmentation
//  price_tier                standard | reduced | premium      Pricing analysis
//  days_since_install        0, 1, 2, ...                     Retention cohorts
//  activation_milestones     0-10                              Activation depth
//  total_sessions            1, 2, 3, ...                      Usage frequency
//
// REMOVED (noise, not actionable):
//  - card_impressed / section_impressed (55 call sites, zero decisions made from them)
//  - feature_open / feature_close (duplicated screen_viewed / screen_exited)
//  - streak_updated (already a user property)
//  - high_engagement_signal / power_session (computed, not raw signals)
//
// ──────────────────────────────────────────────────────────────────────────────

/// Central analytics facade. Firebase Analytics backend.
/// Focused on business-critical events: funnel, retention, demographics, monetization.
final class AppAnalytics {
    static let shared = AppAnalytics()

    private let queue = DispatchQueue(label: "com.healthpulse.analytics")
    private let session = SessionTracker.shared
    private let defaults = UserDefaults.standard

    private var openTimestamps: [AppFeature: Date] = [:]
    private var streamingStartDate: Date?
    private var demographicsSet = false

    private enum Key {
        static let demographicsSet = "laso.analytics.demographics_set"
        static let subscriptionStartDate = "laso.analytics.subscription_start_date"
        static let renewalCount = "laso.analytics.renewal_count"
        static let trialConverted = "laso.analytics.trial_converted"
        static let lastKnownStatus = "laso.analytics.last_known_status"
    }

    private init() {
        demographicsSet = defaults.bool(forKey: Key.demographicsSet)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Demographics (from HealthKit)
    // ══════════════════════════════════════════════════════════════════════

    /// Call once after HealthKit authorization. Sets biological_sex, age_bracket, region.
    func setDemographics(from healthStore: HKHealthStore) {
        guard !demographicsSet else { return }

        // Biological sex
        let sexLabel: String
        if let sex = try? healthStore.biologicalSex().biologicalSex {
            switch sex {
            case .male: sexLabel = "male"
            case .female: sexLabel = "female"
            case .other: sexLabel = "other"
            case .notSet: sexLabel = "unknown"
            @unknown default: sexLabel = "unknown"
            }
        } else {
            sexLabel = "unknown"
        }
        setUserProperty("biological_sex", value: sexLabel)

        // Age bracket from date of birth
        if let dob = try? healthStore.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: dob) {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
            let bracket: String
            switch age {
            case ..<18: bracket = "under_18"
            case 18..<25: bracket = "18-24"
            case 25..<35: bracket = "25-34"
            case 35..<45: bracket = "35-44"
            case 45..<55: bracket = "45-54"
            case 55..<65: bracket = "55-64"
            default: bracket = "65+"
            }
            setUserProperty("age_bracket", value: bracket)
        } else {
            setUserProperty("age_bracket", value: "unknown")
        }

        // Region
        let region = Locale.current.region?.identifier ?? "unknown"
        setUserProperty("region", value: region)
        setUserProperty("price_tier", value: SubscriptionConfig.currentTier.rawValue)

        defaults.set(true, forKey: Key.demographicsSet)
        demographicsSet = true
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Subscription Funnel
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
            "days_since_install": session.daysSinceInstall
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
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("trial_converted", value: "no")
        defaults.set("no", forKey: Key.trialConverted)
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

    /// Call after a successful purchase. Tracks conversion and sets subscription properties.
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
            "milestones_completed": session.completedMilestones.count
        ])

        // Mark trial as converted
        if isTrialConversion {
            setUserProperty("trial_converted", value: "yes")
            defaults.set("yes", forKey: Key.trialConverted)
        }

        // Set subscription start date if first time
        if defaults.object(forKey: Key.subscriptionStartDate) == nil {
            defaults.set(Date(), forKey: Key.subscriptionStartDate)
        }

        // Increment renewal count
        let renewals = defaults.integer(forKey: Key.renewalCount) + 1
        defaults.set(renewals, forKey: Key.renewalCount)

        setUserProperty("subscription_status", value: "pro")
        setUserProperty("renewal_count", value: "\(renewals)")
        updateMonthsSubscribed()
    }

    /// Call when we detect a renewal (transaction listener fires for an existing subscriber).
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

    /// Call when subscription transitions to expired from a previously-subscribed state.
    func trackSubscriptionCancelled() {
        logEvent("subscription_cancelled", parameters: [
            "months_subscribed": monthsSubscribed,
            "renewal_count": defaults.integer(forKey: Key.renewalCount),
            "total_sessions": session.totalSessions,
            "days_since_install": session.daysSinceInstall
        ])
        setUserProperty("subscription_status", value: "expired")
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
            // Track trial day check each session
            trackTrialDayCheck(daysRemaining: daysRemaining)
            // Detect first trial start
            if previousStatus == "unknown" {
                trackTrialStarted(daysRemaining: daysRemaining)
            }
        case .subscribed:
            statusLabel = "pro"
            userTier = "pro"
            updateMonthsSubscribed()
            // Detect renewal: was already subscribed, got a new entitlement
            if previousStatus == "pro" {
                trackSubscriptionRenewed()
            }
        case .billingGrace:
            statusLabel = "billing_grace"
            userTier = "pro"
        case .expired:
            statusLabel = "expired"
            userTier = "free"
            // Detect churn: was subscribed, now expired
            if previousStatus == "pro" || previousStatus == "billing_grace" {
                trackSubscriptionCancelled()
            }
            // Detect trial expiry: was trial, now expired
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

    /// Months since first subscription purchase.
    private var monthsSubscribed: Int {
        guard let startDate = defaults.object(forKey: Key.subscriptionStartDate) as? Date else { return 0 }
        return Calendar.current.dateComponents([.month], from: startDate, to: Date()).month ?? 0
    }

    private func updateMonthsSubscribed() {
        setUserProperty("months_subscribed", value: "\(monthsSubscribed)")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Session Events
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
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ])

        setUserProperty("streak_days", value: "\(session.streakDays)")
        setUserProperty("price_tier", value: SubscriptionConfig.currentTier.rawValue)
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

        let fromScreen = session.recordScreenView(feature.rawValue)

        var params: [String: Any] = [
            "screen": feature.rawValue,
            "tab": session.currentTab,
            "depth": session.currentDepth
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("screen_viewed", parameters: params)

        if let from = fromScreen, from != feature.rawValue {
            logEvent("nav_transition", parameters: [
                "from_screen": from,
                "to_screen": feature.rawValue
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

        logEvent("screen_exited", parameters: [
            "screen": feature.rawValue,
            "tab": session.currentTab,
            "duration_sec": duration
        ])
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

    func trackTimeRangeChanged(screen: AppFeature, context: String, fromDays: Int, toDays: Int) {
        logEvent("time_range_changed", parameters: [
            "screen": screen.rawValue,
            "context": context,
            "from_days": fromDays,
            "to_days": toDays
        ])
    }

    // MARK: - Filter Changed

    func trackFilterChanged(screen: AppFeature, filterType: String, from: String, to: String) {
        logEvent("filter_changed", parameters: [
            "screen": screen.rawValue,
            "filter_type": filterType,
            "from_filter": from,
            "to_filter": to
        ])
    }

    // MARK: - Settings Changed

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

    // MARK: - Live Streaming Events

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

    func trackHeartRateZoneChanged(fromZone: String, toZone: String, bpm: Int) {
        logEvent("heart_rate_zone_changed", parameters: [
            "from_zone": fromZone,
            "to_zone": toZone,
            "bpm": bpm
        ])
    }

    // MARK: - Empty State Events

    func trackEmptyStateShown(screen: AppFeature, stateType: String) {
        logEvent("empty_state_shown", parameters: [
            "screen": screen.rawValue,
            "state_type": stateType,
            "tab": session.currentTab
        ])
    }

    // MARK: - Section/Card Impressions (NO-OP — removed noise)

    /// Kept for compile compatibility. No longer fires events.
    func trackCardImpression(cardType: BlockType, screen: AppFeature) {
        // Intentionally empty — impression events were noise, not actionable.
    }

    /// Kept for compile compatibility. No longer fires events.
    func trackSectionImpression(section: BlockType, screen: AppFeature, metadata: [String: Any] = [:]) {
        // Intentionally empty — impression events were noise, not actionable.
    }

    // MARK: - Share Sheet

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

    // MARK: - Chart Interaction Events

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

    func trackDataSync(metricsCount: Int, newSamplesCount: Int, durationSec: Int, isFirstSync: Bool) {
        logEvent("data_sync_completed", parameters: [
            "metrics_count": metricsCount,
            "new_samples_count": newSamplesCount,
            "duration_sec": durationSec,
            "is_first_sync": isFirstSync ? 1 : 0
        ])
    }

    // MARK: - Scroll Depth

    func trackScrollDepth(screen: AppFeature, maxDepthPercent: Int) {
        logEvent("scroll_depth", parameters: [
            "screen": screen.rawValue,
            "max_depth_percent": maxDepthPercent,
            "tab": session.currentTab
        ])
    }

    // MARK: - Subscription/Paywall Events

    func trackPaywallViewed(source: String) {
        logEvent("paywall_viewed", parameters: [
            "source": source,
            "tab": session.currentTab,
            "days_since_install": session.daysSinceInstall,
            "trial_converted": defaults.string(forKey: Key.trialConverted) ?? "pending"
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Activation Discovery
    // ══════════════════════════════════════════════════════════════════════

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

        if session.completedMilestones.count >= 3 {
            setUserProperty("activation_status", value: "activated")
        }
    }

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
    // MARK: - Core Action Tracking
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
            "days_since_install": session.daysSinceInstall
        ])

        setUserProperty("session_core_actions", value: "\(session.coreActionsThisSession.count)")
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
    // MARK: - Monetization Signals
    // ══════════════════════════════════════════════════════════════════════

    func trackPremiumFeatureAttempted(feature: String, screen: AppFeature) {
        logEvent("premium_feature_attempted", parameters: [
            "feature": feature,
            "screen": screen.rawValue,
            "days_since_install": session.daysSinceInstall
        ])
    }

    func trackHighEngagementSignal(signal: String, metadata: [String: Any] = [:]) {
        // Kept as user property update only, no longer a standalone event
        setUserProperty("last_engagement_signal", value: signal)
    }

    func trackPrePurchaseBehavior(action: String, metadata: [String: Any] = [:]) {
        var params: [String: Any] = [
            "action": action,
            "days_since_install": session.daysSinceInstall
        ]
        for (k, v) in metadata { params[k] = v }
        logEvent("pre_purchase_behavior", parameters: params)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Session Quality (Churn Analysis)
    // ══════════════════════════════════════════════════════════════════════

    func trackSessionQuality() {
        let stats = session.endSession()

        let engagementScore = min(100,
            (stats.screensVisited * 10) +
            (stats.maxDepth * 15) +
            min(stats.durationSec / 6, 50)
        )

        logEvent("session_quality", parameters: [
            "session_number": session.totalSessions,
            "duration_sec": stats.durationSec,
            "screens_visited": stats.screensVisited,
            "max_depth": stats.maxDepth,
            "core_actions_count": session.coreActionsThisSession.count,
            "engagement_score": engagementScore,
            "days_since_install": session.daysSinceInstall,
            "streak_days": session.streakDays,
            "is_first_session": session.isFirstSession ? 1 : 0
        ])

        setUserProperty("last_engagement_score", value: "\(engagementScore)")
    }

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
