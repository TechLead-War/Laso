import Foundation
import PostHog

/// Lightweight wrapper around the PostHog iOS SDK.
/// All events and user properties flow through here so PostHog
/// can be swapped or disabled without touching call-sites.
final class PostHogManager {

    static let shared = PostHogManager()

    private var isConfigured = false

    private init() {}

    // MARK: - Configuration

    /// Call once at app launch (after Firebase, inside AppDelegate).
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
        PostHogSDK.shared.capture(event, properties: properties)
    }

    // MARK: - User Identity

    /// Identify a user with an ID and optional properties.
    func identify(userId: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    /// Set a single user property (person property in PostHog).
    func setUserProperty(name: String, value: String) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture("$set", properties: nil, userProperties: [name: value])
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
