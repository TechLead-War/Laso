import UIKit
import SwiftUI

enum UITestMode {
    private static let launchFlag = "--ui-test-mode"
    private static let resetDefaultsFlag = "--ui-test-reset-defaults"
    private static let showOnboardingFlag = "--ui-test-show-onboarding"
    private static let lightAppearanceFlag = "--ui-test-appearance-light"
    private static let noWatchFlag = "--ui-test-no-watch"
    private static let femaleProfileFlag = "--ui-test-female-profile"
    private static let showDisclaimerFlag = "--ui-test-show-disclaimer"
    private static let showPaywallFlag = "--ui-test-show-paywall"
    private static let forceProLockFlag = "--ui-test-force-pro-lock"
    private static let forceMorningCheckInFlag = "--ui-test-force-morning-checkin"
    private static let premiumShowcaseFlag = "--ui-test-premium-showcase"
    private static let subscribedFlag = "--ui-test-subscribed"
    private static let initialTabPrefix = "--ui-test-initial-tab="
    private static let initialRoutePrefix = "--ui-test-initial-route="
    private static let overrideNamePrefix = "--ui-test-override-name="
    private static let overrideOverallScorePrefix = "--ui-test-override-overall-score="
    private static let overrideSleepScorePrefix = "--ui-test-override-sleep-score="
    private static let overrideActivityScorePrefix = "--ui-test-override-activity-score="

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchFlag)
    }

    static var shouldShowOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains(showOnboardingFlag)
    }

    static var requestedAppearance: UIUserInterfaceStyle {
        ProcessInfo.processInfo.arguments.contains(lightAppearanceFlag) ? .light : .dark
    }

    static var preferredColorScheme: ColorScheme {
        ProcessInfo.processInfo.arguments.contains(lightAppearanceFlag) ? .light : .dark
    }

    /// When true the injected mock data omits the Apple Watch device entry so
    /// the UI renders its "iPhone only" paths (Live tab waiting state, missing
    /// watch-only metrics, etc).
    static var simulateNoWatch: Bool {
        ProcessInfo.processInfo.arguments.contains(noWatchFlag)
    }

    /// When true the injected profile is configured as female so female-only
    /// flows (cycle opt-in, cycle detail) become reachable in the test run.
    static var simulateFemaleProfile: Bool {
        ProcessInfo.processInfo.arguments.contains(femaleProfileFlag)
    }

    /// When true, configureDefaults leaves the medical disclaimer un-acknowledged
    /// so MedicalDisclaimerView renders its full-screen cover at launch.
    static var showDisclaimer: Bool {
        ProcessInfo.processInfo.arguments.contains(showDisclaimerFlag)
    }

    /// When true, LasoApp forces the paywall full-screen cover regardless of
    /// subscription status so PaywallView can be captured in tests.
    static var forceShowPaywall: Bool {
        ProcessInfo.processInfo.arguments.contains(showPaywallFlag)
    }

    /// When true, ContentView renders ProFeatureOverlay on the Live tab
    /// regardless of actual subscription tier so the overlay can be captured.
    static var forceProLock: Bool {
        ProcessInfo.processInfo.arguments.contains(forceProLockFlag)
    }

    /// When true, HomeView shows the morning check-in card regardless of the
    /// 5 AM to 11 AM time window so the card can be captured in any test run.
    static var forceMorningCheckIn: Bool {
        ProcessInfo.processInfo.arguments.contains(forceMorningCheckInFlag)
    }

    /// When true, AppContainer seeds PremiumShowcaseDataProvider (thriving values)
    /// instead of SampleDataProvider so App Store screenshots reflect the
    /// post-purchase experience.
    static var premiumShowcase: Bool {
        ProcessInfo.processInfo.arguments.contains(premiumShowcaseFlag)
    }

    /// When true, SubscriptionManager.status is forced to `.subscribed` so
    /// paywalls and feature gates reflect a paid user during screenshot capture.
    static var forceSubscribed: Bool {
        ProcessInfo.processInfo.arguments.contains(subscribedFlag)
    }

    /// Optional initial tab. When set, ContentView selects this tab on first
    /// appear so a single launch can land directly on Home, Live, Explore, or
    /// Settings without tap navigation.
    /// Format: `--ui-test-initial-tab=home|live|explore|settings`
    static var initialTab: String? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(initialTabPrefix) }) else {
            return nil
        }
        return String(arg.dropFirst(initialTabPrefix.count)).lowercased()
    }

    /// Optional initial deep-link route appended to the home navigation stack on
    /// first appear so a single launch can land directly on a detail screen.
    /// Format: `--ui-test-initial-route=sleepCoach|vitalityDetail|strainDetail|...`
    static var initialRoute: String? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(initialRoutePrefix) }) else {
            return nil
        }
        return String(arg.dropFirst(initialRoutePrefix.count))
    }

    // MARK: - Showcase value overrides

    /// Profile display name override. Visible anywhere the app personalises copy.
    static var overrideName: String? { stringValue(for: overrideNamePrefix) }
    /// Overall daily score override (0-100). Renders as the big hero number on Home.
    static var overrideOverallScore: Int? { intValue(for: overrideOverallScorePrefix) }
    /// Sleep category score override (0-100).
    static var overrideSleepScore: Int? { intValue(for: overrideSleepScorePrefix) }
    /// Activity category score override (0-100).
    static var overrideActivityScore: Int? { intValue(for: overrideActivityScorePrefix) }

    private static func stringValue(for prefix: String) -> String? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        let v = String(arg.dropFirst(prefix.count))
        return v.isEmpty ? nil : v
    }

    private static func intValue(for prefix: String) -> Int? {
        stringValue(for: prefix).flatMap(Int.init)
    }

    static func configureDefaults() {
        guard isEnabled else { return }

        // Disable all animations for deterministic screenshot captures
        UIView.setAnimationsEnabled(false)

        // Set appearance override via UIWindow appearance proxy. applies to all future windows
        UIWindow.appearance().overrideUserInterfaceStyle = requestedAppearance

        let defaults = UserDefaults.standard
        let appStateStore = AppStateStore(userDefaults: defaults, cloudStore: nil)

        if ProcessInfo.processInfo.arguments.contains(resetDefaultsFlag) {
            let keysToReset = [
                AppKeys.App.hasSeenScoreGuide,
                AppKeys.App.hasSeenRecoveryInfo,
                AppKeys.Dismissals.siriTip
            ]
            for key in keysToReset {
                defaults.removeObject(forKey: key)
            }

            appStateStore.setOnboardingCompleted(false)
            appStateStore.setHasSeenDiscovery(false)
            appStateStore.setPendingCalibrationHydration(false)
        }

        appStateStore.setOnboardingCompleted(!shouldShowOnboarding)
        appStateStore.markDiscoverySeen()
        appStateStore.setPendingCalibrationHydration(false)
        // Pre-ack the medical disclaimer so it does not interpose a full-screen
        // sheet between the app and the test harness once onboarding is done.
        // Skip the pre-ack when the test explicitly wants to capture the sheet.
        if !showDisclaimer {
            appStateStore.markDisclaimerAcknowledged()
        }
        defaults.set(true, forKey: AppKeys.App.hasSeenScoreGuide)
        defaults.set(true, forKey: AppKeys.Dismissals.siriTip)
    }
}
