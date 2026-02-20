import Foundation

/// Every trackable event in the app.
/// Used by AnalyticsManager for local storage and future backend sync.
enum AnalyticsEvent: Codable {
    // MARK: - Session
    case sessionStarted
    case sessionEnded(durationSeconds: Int)

    // MARK: - Screen Views
    case screenView(screen: String)

    // MARK: - Feature Usage
    case featureUsed(feature: String)
    case featureGated(feature: String) // User hit a paywall

    // MARK: - Metric Engagement
    case metricViewed(metric: String, category: String)
    case categoryViewed(category: String)
    case riskViewed(riskType: String)

    // MARK: - Subscription
    case paywallViewed(trigger: String)
    case subscriptionStarted(tier: String, plan: String, price: String)
    case subscriptionCancelled(tier: String)
    case subscriptionRestored(tier: String)

    // MARK: - Engagement
    case pullToRefresh
    case periodChanged(period: String)
    case insightTapped(metric: String, severity: String)
    case focusAreaTapped(riskType: String, focusTitle: String)

    // MARK: - Feedback
    case feedbackPromptShown
    case feedbackSubmitted(category: String, hasText: Bool)
    case feedbackDismissed

    // MARK: - A/B Test
    case abTestAssigned(experiment: String, bucket: String)
    case trialStarted(daysTotal: Int)
    case trialExpired(bucket: String)
    case trialDayPassed(daysRemaining: Int)

    /// Event name for grouping/querying
    var name: String {
        switch self {
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"
        case .screenView: return "screen_view"
        case .featureUsed: return "feature_used"
        case .featureGated: return "feature_gated"
        case .metricViewed: return "metric_viewed"
        case .categoryViewed: return "category_viewed"
        case .riskViewed: return "risk_viewed"
        case .paywallViewed: return "paywall_viewed"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionCancelled: return "subscription_cancelled"
        case .subscriptionRestored: return "subscription_restored"
        case .pullToRefresh: return "pull_to_refresh"
        case .periodChanged: return "period_changed"
        case .insightTapped: return "insight_tapped"
        case .focusAreaTapped: return "focus_area_tapped"
        case .feedbackPromptShown: return "feedback_prompt_shown"
        case .feedbackSubmitted: return "feedback_submitted"
        case .feedbackDismissed: return "feedback_dismissed"
        case .abTestAssigned: return "ab_test_assigned"
        case .trialStarted: return "trial_started"
        case .trialExpired: return "trial_expired"
        case .trialDayPassed: return "trial_day_passed"
        }
    }

    /// Event properties as a dictionary for remote analytics (Firebase)
    var properties: [String: Any] {
        switch self {
        case .sessionStarted, .pullToRefresh, .feedbackPromptShown, .feedbackDismissed:
            return [:]
        case .sessionEnded(let duration):
            return ["duration_seconds": duration]
        case .screenView(let screen):
            return ["screen": screen]
        case .featureUsed(let feature):
            return ["feature": feature]
        case .featureGated(let feature):
            return ["feature": feature]
        case .metricViewed(let metric, let category):
            return ["metric": metric, "category": category]
        case .categoryViewed(let category):
            return ["category": category]
        case .riskViewed(let riskType):
            return ["risk_type": riskType]
        case .paywallViewed(let trigger):
            return ["trigger": trigger]
        case .subscriptionStarted(let tier, let plan, let price):
            return ["tier": tier, "plan": plan, "price": price]
        case .subscriptionCancelled(let tier):
            return ["tier": tier]
        case .subscriptionRestored(let tier):
            return ["tier": tier]
        case .periodChanged(let period):
            return ["period": period]
        case .insightTapped(let metric, let severity):
            return ["metric": metric, "severity": severity]
        case .focusAreaTapped(let riskType, let focusTitle):
            return ["risk_type": riskType, "focus_title": focusTitle]
        case .feedbackSubmitted(let category, let hasText):
            return ["category": category, "has_text": hasText]
        case .abTestAssigned(let experiment, let bucket):
            return ["experiment": experiment, "bucket": bucket]
        case .trialStarted(let daysTotal):
            return ["days_total": daysTotal]
        case .trialExpired(let bucket):
            return ["bucket": bucket]
        case .trialDayPassed(let daysRemaining):
            return ["days_remaining": daysRemaining]
        }
    }
}

/// A stored analytics event with timestamp
struct StoredEvent: Codable, Identifiable {
    let id: UUID
    let event: AnalyticsEvent
    let timestamp: Date
    let sessionId: String

    init(event: AnalyticsEvent, sessionId: String) {
        self.id = UUID()
        self.event = event
        self.timestamp = Date()
        self.sessionId = sessionId
    }
}
