import UIKit

enum UITestMode {
    private static let launchFlag = "--ui-test-mode"
    private static let resetDefaultsFlag = "--ui-test-reset-defaults"
    private static let showOnboardingFlag = "--ui-test-show-onboarding"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchFlag)
    }

    static var shouldShowOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains(showOnboardingFlag)
    }

    static func configureDefaults() {
        guard isEnabled else { return }

        // Disable all animations for deterministic screenshot captures
        UIView.setAnimationsEnabled(false)

        let defaults = UserDefaults.standard

        if ProcessInfo.processInfo.arguments.contains(resetDefaultsFlag) {
            let keysToReset = [
                AppKeys.App.onboardingCompleted,
                AppKeys.App.appTheme,
                AppKeys.App.hasSeenDiscovery,
                AppKeys.App.hasSeenScoreGuide,
                AppKeys.App.hasSeenRecoveryInfo,
                AppKeys.App.pendingCalibrationHydration,
                AppKeys.Dismissals.siriTip
            ]
            for key in keysToReset {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(!shouldShowOnboarding, forKey: AppKeys.App.onboardingCompleted)
        defaults.set(true, forKey: AppKeys.App.hasSeenDiscovery)
        defaults.set(true, forKey: AppKeys.App.hasSeenScoreGuide)
        defaults.set(false, forKey: AppKeys.App.pendingCalibrationHydration)
        defaults.set(true, forKey: AppKeys.Dismissals.siriTip)

        if let theme = ProcessInfo.processInfo.environment["HP_UI_THEME"],
           ["light", "dark", "system"].contains(theme) {
            defaults.set(theme, forKey: AppKeys.App.appTheme)
        }
    }
}
