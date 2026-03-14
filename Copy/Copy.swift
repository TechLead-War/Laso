import Foundation

/// Single source of truth for all user-facing copy in the app.
/// Every user-visible string MUST live here. Organized by domain via extensions.
enum Copy {

    // MARK: - Medical Disclaimer

    static let medicalDisclaimer = "Laso provides health insights for wellness and informational purposes only. It is not a medical device and does not provide medical diagnosis or treatment. Always consult a qualified healthcare provider before making health-related decisions."

    // MARK: - Common Buttons

    enum Buttons {
        static let done = "Done"
        static let cancel = "Cancel"
        static let continueButton = "Continue"
        static let getStarted = "Get Started"
        static let skipForNow = "Skip for now"
        static let notNow = "Not now"
        static let close = "Close"
        static let retry = "Retry"
        static let subscribe = "Subscribe"
        static let restorePurchases = "Restore Purchases"
        static let enable = "Enable"
    }

    // MARK: - Common Labels

    enum Labels {
        static let pro = "PRO"
        static let version = "Version"
        static let appName = "Laso"
    }

    // MARK: - Privacy

    enum Privacy {
        static let healthDataOnDevice = "Health Data On-Device"
        static let privacyPolicy = "Privacy Policy"
        static let termsOfUse = "Terms of Use"
    }
}
