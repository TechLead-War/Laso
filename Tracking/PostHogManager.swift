import Foundation
import PostHog

/// Central PostHog wrapper — sole analytics backend.
/// All events, user properties, screen views, and error tracking flow through here.
final class PostHogManager {

    static let shared = PostHogManager()

    private var isConfigured = false

    private init() {}

    // MARK: - Configuration

    /// Call once at app launch (inside AppDelegate).
    func configure() {
        guard !UITestMode.isEnabled else { return }
        guard !isConfigured else { return }

        let config = PostHogConfig(apiKey: PHConfig.apiKey, host: PHConfig.host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false // We track screens manually via AppAnalytics
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    // MARK: - Events

    /// Capture a named event with optional properties.
    func capture(event: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        #if DEBUG
        print("[PostHog] \(event)", properties?.keys.sorted().joined(separator: ", ") ?? "")
        #endif
        PostHogSDK.shared.capture(event, properties: properties)
    }

    // MARK: - Screen Views

    /// Record a screen view event with the PostHog `$screen` semantic.
    func screen(_ screenName: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.screen(screenName, properties: properties)
    }

    // MARK: - User Identity

    /// Identify a user with an ID and optional properties.
    func identify(userId: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    /// Set a single person property.
    func setUserProperty(name: String, value: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("$set", properties: nil, userProperties: [name: value])
    }

    /// Set multiple person properties at once.
    func setUserProperties(_ properties: [String: Any]) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("$set", properties: nil, userProperties: properties)
    }

    // MARK: - Error Tracking

    /// Capture a non-fatal error as a PostHog event for monitoring.
    func captureError(_ error: Error, context: String, metadata: [String: Any] = [:]) {
        guard isConfigured else { return }
        var props: [String: Any] = [
            "error_message": error.localizedDescription,
            "error_context": context,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ]
        for (k, v) in metadata { props[k] = v }
        PostHogSDK.shared.capture("app_error_recorded", properties: props)
    }

    /// Capture a string-described error (no Error object) as a PostHog event.
    func captureError(_ message: String, context: String, metadata: [String: Any] = [:]) {
        guard isConfigured else { return }
        var props: [String: Any] = [
            "error_message": message,
            "error_context": context
        ]
        for (k, v) in metadata { props[k] = v }
        #if DEBUG
        print("[PostHog] app_error_recorded: \(context) — \(message)")
        #endif
        PostHogSDK.shared.capture("app_error_recorded", properties: props)
    }

    // MARK: - Flush

    /// Force-flush the event queue (e.g. before app termination).
    func flush() {
        guard isConfigured else { return }
        PostHogSDK.shared.flush()
    }
}

// MARK: - PostHog Configuration

private enum PHConfig {
    static let apiKey = "phc_bBp1OaF9TabDqJ9iA9uxbObl8YAIIIYn049Tt8AS7km"
    static let host = "https://eu.i.posthog.com"
}
