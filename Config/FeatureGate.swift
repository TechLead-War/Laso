import Foundation

/// Single source of truth for feature access decisions.
/// Combines subscription tier with Remote Config feature flags.
struct FeatureGate {

    private static var config: RemoteConfigManager { .shared }
    private static var subscription: SubscriptionManager { .shared }

    /// The current user's tier string for feature flag lookup.
    static var currentTier: String {
        switch subscription.status {
        case .trial, .subscribed, .billingGrace: return "pro"
        case .unknown, .expired: return "free"
        }
    }

    /// Whether the user can access a specific feature.
    static func canAccess(_ feature: RemoteConfigManager.FeatureKey) -> Bool {
        config.isFeatureEnabled(feature, for: currentTier)
    }

    /// Whether the user is on the free tier (for showing upgrade prompts).
    static var isFreeTier: Bool {
        currentTier == "free"
    }

    /// Whether the user has full app access (trial or subscribed).
    static var hasFullAccess: Bool {
        subscription.hasAccess
    }

    /// The number of metric detail views allowed for free users.
    static var metricDetailLimit: Int {
        isFreeTier ? config.freeMetricDetailLimit : .max
    }

    /// The number of insights shown to free users.
    static var insightLimit: Int {
        isFreeTier ? config.freeInsightLimit : .max
    }

    /// Allowed time range periods for the current tier.
    static var allowedPeriods: [String] {
        isFreeTier ? config.freePeriods : ["7d", "30d", "3m", "6m", "1y"]
    }

    /// Metrics available to the current tier.
    static var allowedFreeMetrics: [String] {
        config.freeMetrics
    }
}
