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
