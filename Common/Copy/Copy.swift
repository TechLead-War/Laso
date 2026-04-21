import Foundation

/// Single source of truth for all user-facing copy in the app.
/// Every user-visible string MUST live here. Organized by domain via extensions.
enum Copy {

    // MARK: - Medical Disclaimer

    static let medicalDisclaimer = "Laso is not a medical device. It gives you health information, not medical advice. Always consult a qualified professional before making health decisions."

    // MARK: - Medical Disclaimer Screen

    enum Disclaimer {
        static let title = "Important Health Information"
        static let body = "Laso is not a medical device. It gives you health information, not medical advice. Always consult a qualified professional before making health decisions."
        static let secondaryBody = "The scores, patterns, and insights in this app are based on your Apple Health data and are for informational purposes only. They should not be used as a substitute for professional health guidance."
        static let acknowledge = "I Understand"
    }

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
