import Foundation
import PostHog

/// Central PostHog wrapper. sole analytics backend.
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
        config.enableSwizzling = false
        #if os(iOS) || targetEnvironment(macCatalyst)
        config.captureElementInteractions = false
        #endif
        #if os(iOS)
        config.sessionReplay = false
        if #available(iOS 15.0, *) {
            config.surveys = false
        }
        #endif
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
        print("[PostHog] app_error_recorded: \(context). \(message)")
        #endif
        PostHogSDK.shared.capture("app_error_recorded", properties: props)
    }

    // MARK: - Flush

    /// Force-flush the event queue (e.g. before app termination).
    func flush() {
        guard isConfigured else { return }
        PostHogSDK.shared.flush()
    }

    // MARK: - Crash Handling

    /// Install handlers for uncaught exceptions and signals.
    /// Captures a `app_crash` event with stack trace and flushes before death.
    /// Call once at launch, after `configure()`.
    func installCrashHandlers() {
        guard isConfigured else { return }

        // 1. Uncaught NSException handler (Obj-C exceptions, Swift fatalError reaching Obj-C boundary)
        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.prefix(15).joined(separator: "\n")
            PostHogSDK.shared.capture("app_crash", properties: [
                "crash_type": "uncaught_exception",
                "exception_name": exception.name.rawValue,
                "exception_reason": exception.reason ?? "unknown",
                "stack_trace": String(stackTrace.prefix(2000))
            ])
            PostHogSDK.shared.flush()
        }

        // 2. POSIX signal handlers for Swift runtime crashes (EXC_BAD_ACCESS, SIGABRT, etc.)
        let crashSignals: [Int32] = [SIGABRT, SIGBUS, SIGSEGV, SIGFPE, SIGILL, SIGTRAP]
        for sig in crashSignals {
            signal(sig) { signalNumber in
                let signalName: String
                switch signalNumber {
                case SIGABRT: signalName = "SIGABRT"
                case SIGBUS:  signalName = "SIGBUS"
                case SIGSEGV: signalName = "SIGSEGV"
                case SIGFPE:  signalName = "SIGFPE"
                case SIGILL:  signalName = "SIGILL"
                case SIGTRAP: signalName = "SIGTRAP"
                default:      signalName = "SIGNAL_\(signalNumber)"
                }
                PostHogSDK.shared.capture("app_crash", properties: [
                    "crash_type": "signal",
                    "signal_name": signalName,
                    "signal_number": signalNumber
                ])
                PostHogSDK.shared.flush()
                // Re-raise so the default handler produces the crash report
                signal(signalNumber, SIG_DFL)
                raise(signalNumber)
            }
        }
    }
}

// MARK: - PostHog Configuration

private enum PHConfig {
    static let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String, !key.isEmpty else {
            return AppSecrets.PostHog.apiKey
        }
        return key
    }()
    static let host: String = {
        guard let host = Bundle.main.infoDictionary?["POSTHOG_HOST"] as? String, !host.isEmpty else {
            return AppSecrets.PostHog.host
        }
        return host
    }()
}
