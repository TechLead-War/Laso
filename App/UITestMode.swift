import UIKit
import SwiftUI

enum UITestMode {
    private static let launchFlag = "--ui-test-mode"
    private static let resetDefaultsFlag = "--ui-test-reset-defaults"
    private static let showOnboardingFlag = "--ui-test-show-onboarding"
    private static let lightAppearanceFlag = "--ui-test-appearance-light"

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

    static func configureDefaults() {
        guard isEnabled else { return }

        // Disable all animations for deterministic screenshot captures
        UIView.setAnimationsEnabled(false)

        // Set appearance override via UIWindow appearance proxy — applies to all future windows
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
        defaults.set(true, forKey: AppKeys.App.hasSeenScoreGuide)
        defaults.set(true, forKey: AppKeys.Dismissals.siriTip)
    }
}
