import Foundation
#if os(iOS)
import UIKit
#endif
import AmplitudeSwift

/// Amplitude implementation of `AnalyticsProvider`. Mirrors `PostHogManager`'s
/// shape so the two are interchangeable behind `AnalyticsBackend.provider`.
final class AmplitudeProvider: AnalyticsProvider {

    static let shared = AmplitudeProvider()

    /// nil until `configure()` runs; every method no-ops until then, matching
    /// PostHogManager's `isConfigured` guard.
    private var amplitude: Amplitude?

    private init() {}

    // MARK: - Configuration

    func configure() {
        guard !UITestMode.isEnabled else { return }
        guard amplitude == nil else { return }

        let amp = Amplitude(configuration: Configuration(
            apiKey: AmpConfig.apiKey,
            logLevel: AnalyticsEnvironment.isDebugBuild ? .debug : .warn,
            serverZone: AmpConfig.serverZone,
            // No SDK autocapture: the taxonomy fires its own events (session_started /
            // session_ended / first_open). Leaving .sessions/.appLifecycles on would emit
            // duplicate SDK "session_start"/"session_end"/"[Amplitude] Application Opened"
            // events that are not in the taxonomy.
            autocapture: []
        ))
        // Register process-lifetime super-properties before the first event so
        // they ride on every event, including autocaptured session/lifecycle
        // and crash events.
        amp.add(plugin: SuperPropertiesPlugin(superProps: AnalyticsEnvironment.staticSuperProperties()))
        amplitude = amp

        errorWindowLock.lock()
        let pending = preConfigureErrors
        preConfigureErrors = []
        errorWindowLock.unlock()
        for buffered in pending {
            trackErrorGated(context: buffered.context, props: buffered.props)
        }

        #if DEBUG
        if AmpConfig.apiKey.isEmpty {
            print("[Amplitude] WARNING: AMPLITUDE_API_KEY is empty — no events will reach Amplitude. Set it in Secrets.xcconfig.")
        }
        #endif
    }

    // MARK: - Events

    func capture(event: String, properties: [String: Any]?) {
        guard let amplitude else { return }
        #if DEBUG
        print("[Amplitude] \(event)", properties?.keys.sorted().joined(separator: ", ") ?? "")
        #endif
        amplitude.track(eventType: event, eventProperties: properties)
    }

    // MARK: - Screen Views

    /// Amplitude has no `$screen` semantic, so a manual screen view is sent as a
    /// named `screen` event carrying the screen name.
    func screen(_ screenName: String, properties: [String: Any]?) {
        // No-op: screen views are not a taxonomy event. The current screen rides as the
        // `screen` global property on every event instead, so no separate "screen" event.
    }

    // MARK: - User Identity

    func identify(userId: String, properties: [String: Any]?) {
        guard let amplitude else { return }
        amplitude.setUserId(userId: userId)
        if let properties { applyUserProperties(properties, on: amplitude) }
    }

    func setUserProperty(name: String, value: String) {
        guard let amplitude else { return }
        let identify = Identify()
        identify.set(property: name, value: value)
        amplitude.identify(identify: identify)
    }

    func setUserProperties(_ properties: [String: Any]) {
        guard let amplitude else { return }
        applyUserProperties(properties, on: amplitude)
    }

    private func applyUserProperties(_ properties: [String: Any], on amplitude: Amplitude) {
        let identify = Identify()
        for (key, value) in properties {
            identify.set(property: key, value: value)
        }
        amplitude.identify(identify: identify)
    }

    // MARK: - Error Tracking

    /// captureError has ~50 call sites and no upstream throttle, so one failing
    /// subsystem can burst dozens of identical events in a second (observed: a
    /// locked-device HealthKit sync emitting ~60 per background wake). Cap each
    /// error_context per hour and emit a single marker event when the cap trips
    /// so suppression stays visible in Amplitude instead of failing silently.
    private static let errorEventsPerContextPerHour = 5
    private var errorWindows: [String: (start: Date, count: Int)] = [:]
    private let errorWindowLock = NSLock()

    /// Errors captured before configure() runs (e.g. EncryptedStore purging
    /// orphaned blobs during AppContainer init) would otherwise be silently
    /// dropped by the nil-amplitude guard. Buffer a few and flush on configure.
    private var preConfigureErrors: [(context: String, props: [String: Any])] = []
    private static let preConfigureErrorCap = 10

    func captureError(_ error: Error, context: String, metadata: [String: Any]) {
        var props: [String: Any] = [
            "error_message": error.localizedDescription,
            "error_context": context,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code
        ]
        for (k, v) in metadata { props[k] = v }
        trackErrorGated(context: context, props: props)
    }

    func captureError(_ message: String, context: String, metadata: [String: Any]) {
        var props: [String: Any] = [
            "error_message": message,
            "error_context": context
        ]
        for (k, v) in metadata { props[k] = v }
        #if DEBUG
        print("[Amplitude] app_error_recorded: \(context). \(message)")
        #endif
        trackErrorGated(context: context, props: props)
    }

    private func trackErrorGated(context: String, props: [String: Any]) {
        guard let amplitude else {
            errorWindowLock.lock()
            if preConfigureErrors.count < Self.preConfigureErrorCap {
                preConfigureErrors.append((context: context, props: props))
            }
            errorWindowLock.unlock()
            return
        }

        errorWindowLock.lock()
        let now = Date()
        var window = errorWindows[context] ?? (start: now, count: 0)
        if now.timeIntervalSince(window.start) > 3600 {
            window = (start: now, count: 0)
        }
        window.count += 1
        errorWindows[context] = window
        errorWindowLock.unlock()

        guard window.count <= Self.errorEventsPerContextPerHour else {
            if window.count == Self.errorEventsPerContextPerHour + 1 {
                amplitude.track(eventType: "app_error_recorded", eventProperties: sanitizeErrorProps([
                    "error_context": context,
                    "error_message": "Rate limit reached, suppressing further errors for this context this hour",
                    "rate_limited": true
                ]))
            }
            return
        }
        amplitude.track(eventType: "app_error_recorded", eventProperties: sanitizeErrorProps(props))
    }

    /// The error/crash channel posts straight to the SDK and so would otherwise
    /// bypass AppAnalytics.sanitizeParameters. Apply the same two protections here:
    /// collapse any health-metric raw value to its parent category (so a raw
    /// clinical condition like "bloodPressureSystolic" never ships) and bound
    /// free-text/error strings so untruncated error/exception text cannot leak. The
    /// bound here is 200 chars (vs 100 for normal events) since longer error and
    /// exception reasons aid crash triage while still being capped.
    private func sanitizeErrorProps(_ props: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in props {
            if Self.metricKeys.contains(key), let raw = value as? String {
                out[key] = HealthMetric(rawValue: raw)?.category.rawValue ?? "other"
            } else if let string = value as? String {
                out[key] = String(string.prefix(200))
            } else {
                out[key] = value
            }
        }
        return out
    }

    private static let metricKeys: Set<String> = ["metric", "alert_metric", "metrics"]

    // MARK: - Flush / Reset

    func flush() {
        amplitude?.flush()
    }

    /// Clear analytics identity on logout / account deletion: nulls userId and
    /// rotates deviceId so a fresh anonymous identity starts.
    func reset() {
        amplitude?.reset()
    }

    // MARK: - Crash Handling

    /// Install handlers for uncaught exceptions and fatal signals. Captures an
    /// `app_crash` event and flushes before the process dies. The signal
    /// handlers must be capture-free C function pointers, so they reach the SDK
    /// through the `AmplitudeProvider.shared` singleton rather than `self`.
    func installCrashHandlers() {
        guard amplitude != nil else { return }

        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.prefix(15).joined(separator: "\n")
            AmplitudeProvider.shared.amplitude?.track(eventType: "app_crash", eventProperties: [
                "crash_type": "uncaught_exception",
                "exception_name": exception.name.rawValue,
                "exception_reason": String((exception.reason ?? "unknown").prefix(200)),
                "stack_trace": String(stackTrace.prefix(2000))
            ])
            AmplitudeProvider.shared.amplitude?.flush()
        }

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
                AmplitudeProvider.shared.amplitude?.track(eventType: "app_crash", eventProperties: [
                    "crash_type": "signal",
                    "signal_name": signalName,
                    "signal_number": signalNumber
                ])
                AmplitudeProvider.shared.amplitude?.flush()
                // Re-raise so the default handler still produces the crash report.
                signal(signalNumber, SIG_DFL)
                raise(signalNumber)
            }
        }
    }
}

// MARK: - Super-properties Plugin

/// Attaches process-lifetime super-properties to every event — the Amplitude
/// equivalent of PostHog's `register(props)`. Runs for all events, including
/// autocaptured session/lifecycle and crash events.
final class SuperPropertiesPlugin: EnrichmentPlugin {
    private let superProps: [String: Any]

    init(superProps: [String: Any]) {
        self.superProps = superProps
        super.init()
    }

    override func execute(event: BaseEvent) -> BaseEvent? {
        var props = event.eventProperties ?? [:]
        // Never clobber an event's own property with a super-property.
        for (key, value) in superProps where props[key] == nil {
            props[key] = value
        }
        event.eventProperties = props
        return event
    }
}

// MARK: - Amplitude Configuration

private enum AmpConfig {
    static let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["AMPLITUDE_API_KEY"] as? String, !key.isEmpty else {
            return AppSecrets.Amplitude.apiKey
        }
        return key
    }()

    /// Data residency. Must match the Amplitude project's region or events are
    /// silently dropped. Read from AMPLITUDE_REGION ("EU"/"US"); defaults to US.
    static let serverZone: ServerZone = {
        let raw = (Bundle.main.infoDictionary?["AMPLITUDE_REGION"] as? String) ?? AppSecrets.Amplitude.region
        return raw.uppercased() == "EU" ? .EU : .US
    }()
}
