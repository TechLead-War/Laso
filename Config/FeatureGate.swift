import Foundation
import Observation

/// Central gate that checks whether the current user has access to a feature.
/// Currently all features are unlocked for all users.
@Observable
final class FeatureGate {
    var currentTier: SubscriptionTier = .free
    var freeMetricViewsUsed: Int = 0

    func isUnlocked(_ feature: Feature) -> Bool { true }

    var isAppLocked: Bool { false }

    func canAccessMetric(_ metric: HealthMetric) -> Bool { true }

    func canAccessPeriod(_ periodId: String) -> Bool { true }

    func canAccessInsight(at index: Int) -> Bool { true }

    func minimumTier(for feature: Feature) -> SubscriptionTier? { nil }

    func featuresGainedBy(upgradingTo tier: SubscriptionTier) -> [Feature] { [] }

    var proFeatures: [Feature] { [] }
}
