import Foundation

/// Single source of truth for feature access decisions.
/// Combines subscription tier with Remote Config feature flags.
@MainActor
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

    /// Whether free-year mode is active (all features unlocked for PMF signal).
    /// Set to `false` before going to a paid model.
    private static let freeYearActive = true

    /// Whether the user can access a specific feature.
    static func canAccess(_ feature: RemoteConfigManager.FeatureKey) -> Bool {
        if freeYearActive { return true }
        return config.isFeatureEnabled(feature, for: currentTier)
    }

    /// Whether the user is on the free tier (for showing upgrade prompts).
    static var isFreeTier: Bool {
        if freeYearActive { return false }
        return currentTier == "free"
    }

    /// Whether the user has full app access (trial or subscribed).
    static var hasFullAccess: Bool {
        if freeYearActive { return true }
        return subscription.hasAccess
    }

    /// The number of metric detail views allowed for free users.
    static var metricDetailLimit: Int {
        if freeYearActive { return .max }
        return isFreeTier ? config.freeMetricDetailLimit : .max
    }

    /// The number of insights shown to free users.
    static var insightLimit: Int {
        if freeYearActive { return .max }
        return isFreeTier ? config.freeInsightLimit : .max
    }

    /// Allowed time range periods for the current tier.
    static var allowedPeriods: [String] {
        if freeYearActive { return ["7d", "30d", "3m", "6m", "1y"] }
        return isFreeTier ? config.freePeriods : ["7d", "30d", "3m", "6m", "1y"]
    }

    /// Metrics available to the current tier.
    static var allowedFreeMetrics: [String] {
        config.freeMetrics
    }
}
