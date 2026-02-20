import Foundation

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FEATURE CONFIGURATION — SINGLE SOURCE OF TRUTH                        ║
// ║                                                                        ║
// ║  Values are fetched from Firebase Remote Config at launch.             ║
// ║  If Remote Config is unavailable, hardcoded defaults are used.         ║
// ║  No app update needed to change feature access or limits.              ║
// ║                                                                        ║
// ║  To add a new tier (e.g., .team):                                      ║
// ║    1. Add case to SubscriptionTier enum                                ║
// ║    2. Update remote config keys to include the new tier                ║
// ║    3. Add pricing entry in `pricing` below                             ║
// ║    4. Done.                                                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝

struct FeatureConfig {

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  HARDCODED DEFAULTS                                                 │
    // │  Used when Remote Config is unavailable or returns no value         │
    // └──────────────────────────────────────────────────────────────────────┘

    private static let defaultAccess: [Feature: Set<SubscriptionTier>] = [
        .healthScore:       [.free, .pro],
        .categoryScores:    [.free, .pro],
        .basicMetrics:      [.free, .pro],
        .sevenDayTrends:    [.free, .pro],
        .basicInsights:     [.free, .pro],
        .liveTab:           [.free, .pro],
        .allMetrics:        [.pro],
        .extendedHistory:   [.pro],
        .riskPredictions:   [.pro],
        .focusAreas:        [.pro],
        .allInsights:       [.pro],
        .exportReport:      [.pro],
        .advancedAnalytics: [.pro],
        .correlationInsights:    [.pro],
        .recoveryInsights:       [.pro],
        .workoutEffectiveness:   [.pro],
        .sleepPerformanceLink:   [.pro],
        .weeklyPatterns:         [.free, .pro],
        .personalRecords:        [.free, .pro],
    ]

    private static let defaultFreeMetricDetailLimit = 3
    private static let defaultFreeMetrics: Set<HealthMetric> = [.steps, .sleepDuration, .restingHeartRate]
    private static let defaultFreeInsightLimit = 1
    private static let defaultFreePeriods: Set<String> = ["7D"]

    private static let defaultProMonthlyDisplayPrice = "\u{20B9}300"
    private static let defaultProYearlyDisplayPrice = "\u{20B9}1,200"
    private static let defaultProMonthlyProductId = "com.laso.pro.monthly"
    private static let defaultProYearlyProductId = "com.laso.pro.yearly"
    private static let defaultProTrialDays = 7

    private static let defaultFeedbackPromptAfterSessions = 5
    private static let defaultFeedbackCooldownDays = 5
    private static let defaultMaxLocalAnalyticsEvents = 5000
    private static let defaultSessionTimeoutSeconds: TimeInterval = 300

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  FEATURE → TIER MAPPING                                             │
    // │  Reads from Remote Config, falls back to hardcoded defaults         │
    // └──────────────────────────────────────────────────────────────────────┘

    static var access: [Feature: Set<SubscriptionTier>] {
        let rc = RemoteConfigManager.shared
        var result: [Feature: Set<SubscriptionTier>] = [:]
        for feature in Feature.allCases {
            let key = "feature_access_\(feature.rawValue)"
            if let csv = rc.string(forKey: key) {
                let tiers = parseTiers(from: csv)
                if !tiers.isEmpty {
                    result[feature] = tiers
                    continue
                }
            }
            // Fall back to hardcoded default
            result[feature] = defaultAccess[feature] ?? [.pro]
        }
        return result
    }

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  LIMITS                                                             │
    // │  Numeric caps for free tier                                         │
    // └──────────────────────────────────────────────────────────────────────┘

    /// How many metric detail views free users can open
    static var freeMetricDetailLimit: Int {
        RemoteConfigManager.shared.int(forKey: "free_metric_detail_limit")
            ?? defaultFreeMetricDetailLimit
    }

    /// Which specific metrics are available for free
    static var freeMetrics: Set<HealthMetric> {
        if let csv = RemoteConfigManager.shared.string(forKey: "free_metrics") {
            let parsed = parseHealthMetrics(from: csv)
            if !parsed.isEmpty { return parsed }
        }
        return defaultFreeMetrics
    }

    /// Maximum number of insights shown to free users
    static var freeInsightLimit: Int {
        RemoteConfigManager.shared.int(forKey: "free_insight_limit")
            ?? defaultFreeInsightLimit
    }

    /// Which time periods free users can select
    static var freePeriods: Set<String> {
        if let csv = RemoteConfigManager.shared.string(forKey: "free_periods") {
            let parsed = Set(csv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
            if !parsed.isEmpty { return parsed }
        }
        return defaultFreePeriods
    }

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  PRICING                                                            │
    // │  Display prices + StoreKit product IDs                              │
    // │  Actual prices are set in App Store Connect — these are fallbacks   │
    // └──────────────────────────────────────────────────────────────────────┘

    static var pricing: [SubscriptionTier: TierPricing] {
        let rc = RemoteConfigManager.shared
        return [
            .pro: TierPricing(
                monthlyDisplayPrice: rc.string(forKey: "pricing_pro_monthly_display_price")
                    ?? defaultProMonthlyDisplayPrice,
                yearlyDisplayPrice: rc.string(forKey: "pricing_pro_yearly_display_price")
                    ?? defaultProYearlyDisplayPrice,
                monthlyProductId: rc.string(forKey: "pricing_pro_monthly_product_id")
                    ?? defaultProMonthlyProductId,
                yearlyProductId: rc.string(forKey: "pricing_pro_yearly_product_id")
                    ?? defaultProYearlyProductId,
                trialDays: rc.int(forKey: "pricing_pro_trial_days")
                    ?? defaultProTrialDays
            ),
        ]
    }

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  FEEDBACK CONFIG                                                    │
    // └──────────────────────────────────────────────────────────────────────┘

    /// Show feedback prompt after this many app sessions
    static var feedbackPromptAfterSessions: Int {
        RemoteConfigManager.shared.int(forKey: "feedback_prompt_after_sessions")
            ?? defaultFeedbackPromptAfterSessions
    }

    /// Don't show feedback prompt again for this many days after dismissal
    static var feedbackCooldownDays: Int {
        RemoteConfigManager.shared.int(forKey: "feedback_cooldown_days")
            ?? defaultFeedbackCooldownDays
    }

    // ┌──────────────────────────────────────────────────────────────────────┐
    // │  ANALYTICS CONFIG                                                   │
    // └──────────────────────────────────────────────────────────────────────┘

    /// Max local events to store before oldest get trimmed
    static var maxLocalAnalyticsEvents: Int {
        RemoteConfigManager.shared.int(forKey: "max_local_analytics_events")
            ?? defaultMaxLocalAnalyticsEvents
    }

    /// Session timeout: if app is backgrounded longer than this, it's a new session
    static var sessionTimeoutSeconds: TimeInterval {
        if let value = RemoteConfigManager.shared.double(forKey: "session_timeout_seconds") {
            return value
        }
        return defaultSessionTimeoutSeconds
    }

    // MARK: - Parsing Helpers

    private static func parseTiers(from csv: String) -> Set<SubscriptionTier> {
        let raw = csv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        var tiers = Set<SubscriptionTier>()
        for name in raw {
            if let tier = SubscriptionTier(rawValue: name) {
                tiers.insert(tier)
            }
        }
        return tiers
    }

    private static func parseHealthMetrics(from csv: String) -> Set<HealthMetric> {
        let raw = csv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        var metrics = Set<HealthMetric>()
        for name in raw {
            if let metric = HealthMetric(rawValue: name) {
                metrics.insert(metric)
            }
        }
        return metrics
    }
}
