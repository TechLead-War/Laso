import Foundation

/// Single source of truth for feature access decisions.
/// Combines subscription tier with Remote Config feature flags.
///
/// Observation note: although the accessors are static, every accessor reads
/// instance properties on `RemoteConfigManager.shared` (via `observeFetchUpdates`
/// touching `lastFetchTime`) and/or `SubscriptionManager.shared` (`status`).
/// SwiftUI's Observation framework tracks any tracked-property read inside the
/// active body-evaluation scope, so static intermediates do not break tracking.
/// Views consuming `FeatureGate.*` automatically re-render when fetches land or
/// subscription status changes.
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
    /// Controlled via Remote Config. flip from admin panel without an app update.
    static var freeYearActive: Bool { config.freeYearActive }

    /// End date of free-year mode (when configured in Remote Config). nil when unset.
    static var freeYearEndDate: Date? { config.freeYearEndDate }

    /// Expiry of the active paid entitlement, when the user has actually purchased.
    /// A free trial reports as `.trial` and charges at its end, so its expiration
    /// is the same "renews on" date; both return it. nil for free/expired users.
    static var subscriptionExpirationDate: Date? {
        switch subscription.status {
        case .subscribed(let expiration), .trial(let expiration): return expiration
        default: return nil
        }
    }

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
