import Foundation

extension Copy {
    enum Paywall {

        // MARK: - Header

        static let unlockTitle = "Unlock Laso"
        static let unlockSubtitle = "Your personal health guide,\npowered by Apple Health and your wearable."

        // MARK: - Features

        static var featureLiveVitals: String { "Live vitals & \(HealthMetric.allCases.count)+ health metrics" }
        static let featureInsights = "Personal insights that explain why things change"
        static let featureTrends = "Trends, connections, and weekly reports"
        static let featureAlerts = "Smart alerts you can customize"
        static let featurePrivacy = "Your health data stays on your phone"

        // MARK: - Pricing

        static let yearly = "Yearly"
        static let monthly = "Monthly"
        static let startFreeTrial = "Start Free Trial"
        static let subscribeNow = "Subscribe Now"
        static func perMonth(_ price: String) -> String { "\(price)/month" }
        static func perYear(_ price: String) -> String { "\(price)/year" }
        static func savePercent(_ pct: Int) -> String { "Save \(pct)%" }

        // MARK: - Trial Disclosure

        static func trialDuration(_ days: Int) -> String { "\(days)-day free trial" }
        static func afterTrial(_ price: String) -> String { "After your free trial, you will be charged \(price) automatically" }
    }
}
