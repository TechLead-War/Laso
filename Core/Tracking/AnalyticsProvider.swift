import Foundation
#if os(iOS)
import UIKit
#endif

/// Provider-agnostic analytics seam. Every analytics call in the app routes
/// through `AnalyticsBackend.provider`, so the backend can be swapped without
/// touching any call site. Amplitude is the active provider; `PostHogManager`
/// stays in the codebase and is re-plugged by changing the one line in
/// `AnalyticsBackend`.
/// Sendable: `AnalyticsBackend.provider` is one process-wide instance called
/// from every thread in the app, so any conforming backend must be safe to
/// touch concurrently.
protocol AnalyticsProvider: AnyObject, Sendable {
    func configure()
    func installCrashHandlers()
    func flush()
    func reset()
    func capture(event: String, properties: [String: Any]?)
    func screen(_ screenName: String, properties: [String: Any]?)
    func identify(userId: String, properties: [String: Any]?)
    func setUserProperty(name: String, value: String)
    func setUserProperties(_ properties: [String: Any])
    func captureError(_ error: Error, context: String, metadata: [String: Any])
    func captureError(_ message: String, context: String, metadata: [String: Any])
}

// Swift protocols cannot declare default argument values. These two-argument
// forms are the only no-metadata call shapes used across the app (every other
// call passes the full signature), so only they are provided here.
extension AnalyticsProvider {
    func captureError(_ error: Error, context: String) {
        captureError(error, context: context, metadata: [:])
    }
    func captureError(_ message: String, context: String) {
        captureError(message, context: context, metadata: [:])
    }
}

/// The single active analytics backend. Swap this one line to
/// `PostHogManager.shared` to re-plug PostHog without changing any call site.
enum AnalyticsBackend {
    static let provider: AnalyticsProvider = AmplitudeProvider.shared
}

/// Build-environment values attached to every event as process-lifetime
/// super-properties. Centralized here so both providers share one definition.
enum AnalyticsEnvironment {

    /// True when this binary was compiled with the DEBUG configuration.
    static let isDebugBuild: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// "debug", "testflight", or "release" — lets prod dashboards filter out
    /// internal builds.
    static let appEnvironment: String = {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "release"
        #endif
    }()

    /// Super-properties that ride on every event (build, OS, locale, timezone)
    /// so dashboards can segment without per-event enrichment.
    static func staticSuperProperties() -> [String: Any] {
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "unknown"
        let buildNumber = (info["CFBundleVersion"] as? String) ?? "unknown"

        var props: [String: Any] = [
            "app_environment": appEnvironment,
            "is_debug": isDebugBuild ? 1 : 0,
            "app_version": appVersion,
            "app_build": buildNumber,
            "locale_language": Locale.current.language.languageCode?.identifier ?? "unknown",
            "locale_country": Locale.current.region?.identifier ?? "unknown",
            "timezone_id": TimeZone.current.identifier
        ]
        #if os(iOS)
        props["ios_version"] = UIDevice.current.systemVersion
        #endif
        return props
    }
}
