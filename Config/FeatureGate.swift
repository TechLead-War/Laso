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
    /// Free year: all features unlocked for PMF signal.
    static func canAccess(_ feature: RemoteConfigManager.FeatureKey) -> Bool {
        true
    }

    /// Whether the user is on the free tier (for showing upgrade prompts).
    /// Free year: always treated as pro.
    static var isFreeTier: Bool {
        false
    }

    /// Whether the user has full app access (trial or subscribed).
    /// Free year: always true.
    static var hasFullAccess: Bool {
        true
    }

    /// The number of metric detail views allowed for free users.
    static var metricDetailLimit: Int {
        .max
    }

    /// The number of insights shown to free users.
    static var insightLimit: Int {
        .max
    }

    /// Allowed time range periods for the current tier.
    static var allowedPeriods: [String] {
        ["7d", "30d", "3m", "6m", "1y"]
    }

    /// Metrics available to the current tier.
    static var allowedFreeMetrics: [String] {
        config.freeMetrics
    }
}
