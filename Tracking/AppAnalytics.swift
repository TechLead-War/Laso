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
        setUserProperty("country", value: Locale.current.region?.identifier ?? "unknown")
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

        queue.async {
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
