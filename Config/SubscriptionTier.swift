import Foundation

/// All subscription tiers available in Laso.
/// Add new cases here as you introduce new plans.
enum SubscriptionTier: String, CaseIterable, Identifiable, Codable, Comparable {
    var id: String { rawValue }

    case free
    case pro
    // Future tiers: .team, .family, .enterprise

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Laso Pro"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Basic health tracking"
        case .pro: return "Full health intelligence"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .free: return 0
        case .pro: return 1
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// Pricing metadata for a tier (display only — real prices come from StoreKit)
struct TierPricing {
    let monthlyDisplayPrice: String
    let yearlyDisplayPrice: String
    let monthlyProductId: String
    let yearlyProductId: String
    let trialDays: Int
}
