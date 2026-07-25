import Foundation

/// Single source of truth for all secrets, service identifiers, and sensitive configuration.
/// Keep actual secret values out of source control. use environment variables or .xcconfig files
/// for production secrets. This file centralizes the references so they're easy to find and rotate.
enum AppSecrets {

    // MARK: - Bundle & App Identifiers

    enum App {
        static let bundleID = "com.lasohealth.fit"
        static let appStoreID = "6762501313"
    }

    // MARK: - CloudKit

    enum CloudKit {
        static let recordType = "HealthBackup"
        static let recordID = "HealthBackup-v1"
    }

    // MARK: - Keychain

    enum Keychain {
        static let encryptionKeyAccount = "com.lasohealth.encryption.key"
        static let syncKeyAccount = "com.lasohealth.encryption.synckey"
    }

    // MARK: - StoreKit Product IDs

    enum StoreKit {
        static let yearlyProductID = "com.lasohealth.yearly"
        static let monthlyProductID = "com.lasohealth.monthly"
    }

    // MARK: - Firestore Collections

    enum Firestore {
        static let feedbackCollection = "feedback"
    }

    // MARK: - Legal URLs

    enum URLs {
        static let termsOfUse = "https://lasohealth.fit/terms"
        static let privacyPolicy = "https://lasohealth.fit/privacy"
        static let manageSubscriptions = "https://apps.apple.com/account/subscriptions"

        /// Direct App Store review write link. Empty string if App Store ID is not set yet.
        static var appStoreReview: String {
            guard !App.appStoreID.isEmpty else { return "" }
            return "itms-apps://itunes.apple.com/app/id\(App.appStoreID)?action=write-review"
        }
    }

    // MARK: - PostHog

    enum PostHog {
        static let apiKey = ""
        static let host = "https://eu.i.posthog.com"
    }

    // MARK: - Amplitude

    enum Amplitude {
        static let apiKey = ""
        /// Data residency, "EU" or "US". Must match the Amplitude project's region.
        static let region = "US"
    }
}
