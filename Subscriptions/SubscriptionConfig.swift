import Foundation

/// Subscription product IDs and regional pricing configuration.
/// Actual prices are set in App Store Connect. this serves as the source of truth
/// for what tiers to configure per storefront and for analytics tagging.
struct SubscriptionConfig {

    // MARK: - Fallback Product IDs (used when Remote Config hasn't loaded yet)

    static let fallbackYearlyProductID  = AppSecrets.StoreKit.yearlyProductID
    static let fallbackMonthlyProductID = AppSecrets.StoreKit.monthlyProductID
    static let fallbackTrialDays = 7

    // MARK: - Live Product IDs (from Remote Config, falls back to hardcoded)

    static var yearlyProductID: String {
        RemoteConfigManager.shared.proYearlyProductID
    }

    static var monthlyProductID: String {
        RemoteConfigManager.shared.proMonthlyProductID
    }

    static var allProductIDs: Set<String> {
        [yearlyProductID, monthlyProductID]
    }

    // MARK: - Trial

    static var trialDays: Int {
        RemoteConfigManager.shared.proTrialDays
    }

    // MARK: - Regional Pricing Tiers
    //
    // Configure these in App Store Connect under "Pricing and Availability."
    // Each tier maps to an App Store Connect price point per storefront.
    //
    // Tier       | Yearly (USD equiv) | Monthly (USD equiv) | Storefronts
    // ─────────────────────────────────────────────────────────────────────
    // standard   | $29.99         | $5.99       | US, CA, GB, EU, AU, JP, KR
    // reduced    | $14.99         | $2.99       | IN, BR, MX, TR, ID, PH, TH, VN, PK, NG, EG, ZA, AR, CL, CO
    // premium    | $34.99         | $6.99       | CH, NO, DK, SE, SG

    enum PriceTier: String, Codable {
        case standard
        case reduced
        case premium
    }

    /// Country code → pricing tier mapping.
    /// Add or move countries here, then mirror changes in App Store Connect.
    static let regionPricing: [String: PriceTier] = [
        // Standard. mature markets
        "US": .standard, "CA": .standard, "GB": .standard,
        "DE": .standard, "FR": .standard, "AU": .standard,
        "JP": .standard, "KR": .standard, "IT": .standard,
        "ES": .standard, "NL": .standard, "AT": .standard,
        "BE": .standard, "FI": .standard, "IE": .standard,
        "PT": .standard, "NZ": .standard, "TW": .standard,
        "HK": .standard, "IL": .standard, "AE": .standard,
        "SA": .standard, "QA": .standard, "KW": .standard,

        // Reduced. developing markets (lower purchasing power)
        "IN": .reduced, "BR": .reduced, "MX": .reduced,
        "TR": .reduced, "ID": .reduced, "PH": .reduced,
        "TH": .reduced, "VN": .reduced, "PK": .reduced,
        "NG": .reduced, "EG": .reduced, "ZA": .reduced,
        "AR": .reduced, "CL": .reduced, "CO": .reduced,
        "PE": .reduced, "BD": .reduced, "LK": .reduced,
        "KE": .reduced, "GH": .reduced, "UA": .reduced,
        "RO": .reduced, "BG": .reduced, "MY": .reduced,

        // Premium. high cost-of-living markets
        "CH": .premium, "NO": .premium, "DK": .premium,
        "SE": .premium, "SG": .premium, "LU": .premium,
    ]

    /// Returns the pricing tier for a given ISO 3166-1 alpha-2 country code.
    /// Defaults to `.standard` for unlisted countries.
    static func priceTier(for regionCode: String) -> PriceTier {
        regionPricing[regionCode.uppercased()] ?? .standard
    }

    /// The current device's region pricing tier.
    static var currentTier: PriceTier {
        let region = Locale.current.region?.identifier ?? "US"
        return priceTier(for: region)
    }
}
