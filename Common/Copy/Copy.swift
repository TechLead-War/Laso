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

    static var medicalDisclaimer: String { RemoteConfigManager.shared.copyString("copy_copy_medical_disclaimer", default: "Laso is not a medical device. It shares health information, not medical advice. Always talk to a qualified professional before making health decisions.") }

    // MARK: - Medical Disclaimer Screen

    enum Disclaimer {
        static var title: String { RemoteConfigManager.shared.copyString("copy_copy_disclaimer_title", default: "Important Health Information") }
        static var body: String { RemoteConfigManager.shared.copyString("copy_copy_disclaimer_body", default: "Laso is not a medical device. It shares health information, not medical advice. Always talk to a qualified professional before making health decisions.") }
        static var secondaryBody: String { RemoteConfigManager.shared.copyString("copy_copy_disclaimer_secondary_body", default: "The scores, patterns, and insights here are based on your Apple Health data and are for your information only. They are not a replacement for professional health guidance.") }
        static var acknowledge: String { RemoteConfigManager.shared.copyString("copy_copy_disclaimer_acknowledge", default: "I Understand") }
    }

    // MARK: - Common Buttons

    enum Buttons {
        static var done: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_done", default: "Done") }
        static var cancel: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_cancel", default: "Cancel") }
        static var continueButton: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_continue_button", default: "Continue") }
        static var skipForNow: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_skip_for_now", default: "Skip for now") }
        static var close: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_close", default: "Close") }
        static var retry: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_retry", default: "Retry") }
        static var subscribe: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_subscribe", default: "Subscribe") }
        static var restorePurchases: String { RemoteConfigManager.shared.copyString("copy_copy_buttons_restore_purchases", default: "Restore Purchases") }
    }

    // MARK: - Common Labels

    enum Labels {
        static var pro: String { RemoteConfigManager.shared.copyString("copy_copy_labels_pro", default: "PRO") }
        static var version: String { RemoteConfigManager.shared.copyString("copy_copy_labels_version", default: "Version") }
        static var appName: String { RemoteConfigManager.shared.copyString("copy_copy_labels_app_name", default: "Laso") }
    }

    // MARK: - Privacy

    enum Privacy {
        static var privacyPolicy: String { RemoteConfigManager.shared.copyString("copy_copy_privacy_privacy_policy", default: "Privacy Policy") }
        static var termsOfUse: String { RemoteConfigManager.shared.copyString("copy_copy_privacy_terms_of_use", default: "Terms of Use") }
    }
}
