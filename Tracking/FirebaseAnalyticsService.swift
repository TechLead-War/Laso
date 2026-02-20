import Foundation
import FirebaseAnalytics

/// Thin wrapper around Firebase Analytics for remote event tracking.
/// All events appear in your Firebase console at https://console.firebase.google.com
///
/// No configuration needed — uses the existing GoogleService-Info.plist.
/// User identity is handled automatically via Firebase's anonymous device ID.
final class FirebaseAnalyticsService {
    static let shared = FirebaseAnalyticsService()

    private init() {}

    // MARK: - Track Event

    /// Log an event to Firebase Analytics
    func track(name: String, properties: [String: Any]) {
        Analytics.logEvent(name, parameters: properties.compactMapValues { value in
            // Firebase only accepts String, Int, Double as parameter values
            if let str = value as? String { return str }
            if let num = value as? Int { return num }
            if let num = value as? Double { return num }
            if let bool = value as? Bool { return bool ? "true" : "false" }
            return String(describing: value)
        })
    }

    // MARK: - User Properties

    /// Set persistent user properties for segmentation in Firebase
    func setUserProperties() {
        let abTest = ABTestManager.shared
        Analytics.setUserProperty(abTest.bucket.rawValue, forName: "ab_bucket")
        Analytics.setUserProperty(
            abTest.installDate.formatted(.iso8601),
            forName: "install_date"
        )
        Analytics.setUserProperty(
            "\(ABTestManager.trialDurationDays)",
            forName: "trial_duration_days"
        )
    }

    /// Update the subscription tier (call when tier changes)
    func updateTier(_ tier: String) {
        Analytics.setUserProperty(tier, forName: "subscription_tier")
    }

    /// Update trial days remaining (call each session for trial users)
    func updateTrialDays(_ daysRemaining: Int) {
        Analytics.setUserProperty("\(daysRemaining)", forName: "trial_days_remaining")
    }
}
