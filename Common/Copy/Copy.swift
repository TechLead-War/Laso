import Foundation

/// Single source of truth for all user-facing copy in the app.
/// Every user-visible string MUST live here. Organized by domain via extensions.
///
/// # Localization migration plan
///
/// The app currently ships English-only as raw `String` literals. The String
/// Catalog at `Common/Localizable.xcstrings` is the future home of every
/// translatable string. Fifteen seed entries already mirror the most common
/// surfaces (buttons, disclaimers, common labels, privacy links).
///
/// To migrate a string without changing visible text:
///
/// ```swift
/// // Before:
/// extension Copy {
///     enum Buttons { static let done = "Done" }
/// }
/// // After:
/// extension Copy {
///     enum Buttons { static let done: LocalizedStringKey = "common.button.done" }
/// }
/// ```
///
/// And add the matching key to `Common/Localizable.xcstrings` (state `translated`,
/// English `value` set to the original literal).
///
/// **Safety check before flipping a property to `LocalizedStringKey`:** every call
/// site must accept `LocalizedStringKey`. SwiftUI initializers like `Text(_:)`,
/// `Button(_:action:)`, `Link(_:destination:)`, and `.navigationTitle(_:)` accept
/// both. Sites that bind into a `String` (e.g. `let s: String = Copy.Buttons.done`),
/// interpolate (`"\(Copy.Buttons.done) — saved"`), or pass into APIs that demand a
/// `String` (analytics events, accessibility labels in some forms, `URL` query
/// params) will fail to compile and need an explicit `String(localized:)` lookup.
///
/// Until each call site has been audited, properties remain `String`. Do not
/// flip a property without first running:
///
/// ```
/// grep -rn "Copy\.Buttons\.done" --include="*.swift" .
/// ```
///
/// and confirming every site is `LocalizedStringKey`-tolerant.
enum Copy {

    // MARK: - Medical Disclaimer

    static let medicalDisclaimer = "Laso is not a medical device. It shares health information, not medical advice. Always talk to a qualified professional before making health decisions."

    // MARK: - Medical Disclaimer Screen

    enum Disclaimer {
        static let title = "Important Health Information"
        static let body = "Laso is not a medical device. It shares health information, not medical advice. Always talk to a qualified professional before making health decisions."
        static let secondaryBody = "The scores, patterns, and insights here are based on your Apple Health data and are for your information only. They are not a replacement for professional health guidance."
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
