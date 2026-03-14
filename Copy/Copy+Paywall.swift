import Foundation

extension Copy {
    enum Paywall {

        // MARK: - Header

        static let unlockTitle = "Unlock Laso"
        static let unlockSubtitle = "Your personal health intelligence,\npowered by Apple Health and wearable data."

        // MARK: - Features

        static let featureLiveVitals = "Live vitals & 58+ health metrics"
        static let featureInsights = "Personalized insights & root cause analysis"
        static let featureTrends = "Trends, correlations & weekly reports"
        static let featureAlerts = "Smart alerts with custom thresholds"
        static let featurePrivacy = "Health data stays on-device; anonymous usage analytics and optional feedback improve Laso"

        // MARK: - Pricing

        static let yearly = "Yearly"
        static let monthly = "Monthly"
        static let startFreeTrial = "Start Free Trial"
        static let subscribeNow = "Subscribe Now"
        static func perMonth(_ price: String) -> String { "\(price)/month" }
        static func perYear(_ price: String) -> String { "\(price)/year" }
        static func savePercent(_ pct: Int) -> String { "Save \(pct)%" }
    }
}
