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
    case insightsDetail = "insights_detail"
    case correlations
    case feedback
    case onboarding
    case weeklyReview = "weekly_review"
}

/// Types of tappable blocks/cards in the app.
enum BlockType: String {
    case recoveryCard = "recovery_card"
    case sleepCard = "sleep_card"
    case smartAction = "smart_action"
    case actionCard = "action_card"
    case focusArea = "focus_area"
    case categoryRow = "category_row"
    case metricRow = "metric_row"
    case insightCard = "insight_card"
    case patternCard = "pattern_card"
    case seeAllInsights = "see_all_insights"
    case trendFilter = "trend_filter"
    case periodSelector = "period_selector"
    case settingsGear = "settings_gear"
    case manageDevices = "manage_devices"
    case exportReport = "export_report"
    case riskFactor = "risk_factor"
    case focusAreaCard = "focus_area_card"
    case deviceRow = "device_row"
    case correlationCard = "correlation_card"
    case feedbackCategory = "feedback_category"
    case feedbackSubmit = "feedback_submit"
    case feedbackSkip = "feedback_skip"
    case weeklyReviewCard = "weekly_review_card"
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Event Reference
// ──────────────────────────────────────────────────────────────────────────────
//
//  Event                 Key Params                           Answers
//  ─────────────────────────────────────────────────────────────────────────────
//  session_start         session_id, hour_of_day,             DAU, sessions,
//                        day_of_week, streak_days              time-of-use
//  session_end           session_id, duration_sec,            session depth,
//                        screens_visited, max_depth            session duration
//  streak_updated        streak_days, is_longest              continuous streak
//  tab_switched          tab, from_tab                        tab-wise usage
//  screen_viewed         screen, tab, depth, (+ context)      feature usage,
//                                                             frequency, retention
//  screen_exited         screen, tab, duration_sec            duration per section
//  block_tapped          block_title, block_type,             clicked titles,
//                        screen, tab                           engagement
//  nav_transition        from_screen, to_screen               behavioral transitions
//  feature_used          feature, duration_sec                 meaningful engagement
//  feature_stuck         feature, short_sessions_15m          struggle points
//  feedback_prompt_shown days_since_install                   prompt timing
//  feedback_submitted    category, text_length                user feedback
//
// ──────────────────────────────────────────────────────────────────────────────

/// Central analytics facade. Uses Firebase Analytics when available, otherwise logs to console.
final class AppAnalytics {
    static let shared = AppAnalytics()

    private let queue = DispatchQueue(label: "com.healthpulse.analytics")
    private let session = SessionTracker.shared

    private var openTimestamps: [AppFeature: Date] = [:]
    private var shortSessionTimestamps: [AppFeature: [Date]] = [:]

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
