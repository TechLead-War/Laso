import Foundation

extension Copy {
    enum Paywall {

        // MARK: - Header

        static var unlockTitle: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_unlock_title", default: "Unlock Laso") }
        static var unlockSubtitle: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_unlock_subtitle", default: "Your personal health guide,\npowered by Apple Health and your wearable.") }

        // MARK: - Features

        static var featureLiveVitals: String { "Live vitals & \(HealthMetric.allCases.count)+ health metrics" }
        static var featureInsights: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_feature_insights", default: "Personal insights that explain why things change") }
        static var featureTrends: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_feature_trends", default: "Trends, connections, and weekly reports") }
        static var featureAlerts: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_feature_alerts", default: "Smart alerts you can customize") }
        static var featurePrivacy: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_feature_privacy", default: "Your health data stays on your phone") }

        // MARK: - Pricing

        static var yearly: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_yearly", default: "Yearly") }
        static var monthly: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_monthly", default: "Monthly") }
        static var startFreeTrial: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_start_free_trial", default: "Start Free Trial") }
        static var subscribeNow: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_subscribe_now", default: "Subscribe Now") }
        static func perMonth(_ price: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_per_month", default: "%@/month"), price) }
        static func perYear(_ price: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_per_year", default: "%@/year"), price) }
        static func savePercent(_ pct: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_save_percent", default: "Save %d%%"), pct) }

        // MARK: - Trial Disclosure

        static func trialDuration(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_trial_duration", default: "%d-day free trial"), days) }
        static func afterTrial(_ price: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_after_trial", default: "After your free trial, you will be charged %@ automatically"), price) }

        // MARK: - Legal Disclosure

        static var appleAutoRenewDisclosure: String { RemoteConfigManager.shared.copyString("copy_paywall_paywall_apple_auto_renew_disclosure", default: "Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.") }

        // MARK: - Accessibility

        static func unlockMoreInsights(hiddenCount: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_paywall_paywall_unlock_more_insights", default: "Unlock %d more insights with Pro"), hiddenCount)
        }

        static var upgradeToPro: String { RemoteConfigManager.shared.copyString("copy_paywall_upgrade_to_pro", default: "Upgrade to Pro") }

        // MARK: - Lifted view literals
        static var restoresAnyPriorSubscriptionTiedToHint: String { RemoteConfigManager.shared.copyString("copy_paywall_restores_any_prior_subscription_tied_to_hint", default: "Restores any prior subscription tied to your Apple ID") }

        // MARK: - Lifted interpolated view literals
        static func planLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_plan_label", default: "%@ plan, %@"), p0, p1) }
        static func selectsTheSubscriptionPlanHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_paywall_selects_the_subscription_plan_hint", default: "Selects the %@ subscription plan"), p0) }
    }
}
