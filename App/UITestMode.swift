import UIKit
import SwiftUI

#if DEBUG
enum UITestMode {
    private static let launchFlag = "--ui-test-mode"
    private static let resetDefaultsFlag = "--ui-test-reset-defaults"
    private static let seedMirrorFlag = "--ui-test-seed-mirror"
    private static let showOnboardingFlag = "--ui-test-show-onboarding"
    private static let lightAppearanceFlag = "--ui-test-appearance-light"
    private static let noWatchFlag = "--ui-test-no-watch"
    private static let femaleProfileFlag = "--ui-test-female-profile"
    private static let showDisclaimerFlag = "--ui-test-show-disclaimer"
    private static let showPaywallFlag = "--ui-test-show-paywall"
    private static let forceProLockFlag = "--ui-test-force-pro-lock"
    private static let forceMorningCheckInFlag = "--ui-test-force-morning-checkin"
    private static let forceMirrorMomentFlag = "--ui-test-force-mirror-moment"
    private static let forceShareTrayFlag = "--ui-test-force-share-tray"
    private static let mirrorConfirmPrefix = "--ui-test-mirror-confirm="
    private static let premiumShowcaseFlag = "--ui-test-premium-showcase"
    private static let subscribedFlag = "--ui-test-subscribed"
    private static let initialTabPrefix = "--ui-test-initial-tab="
    private static let initialRoutePrefix = "--ui-test-initial-route="
    private static let onboardingV2ScreenPrefix = "--ui-test-onboarding-v2-screen="
    private static let onboardingGoalPrefix = "--ui-test-onboarding-goal="
    private static let settingsRoutePrefix = "--ui-test-settings-route="
    private static let overrideNamePrefix = "--ui-test-override-name="
    private static let overrideOverallScorePrefix = "--ui-test-override-overall-score="
    private static let seedDailyResultPrefix = "--ui-test-seed-daily-result="
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

    /// When true, HomeView presents the Mirror Moment sheet regardless of the
    /// once-a-day and camera-availability rules, so the flow can be exercised
    /// on the simulator (which has no camera).
    static var forceMirrorMoment: Bool {
        ProcessInfo.processInfo.arguments.contains(forceMirrorMomentFlag)
    }

    /// When true, ContentView presents the share tray on launch.
    ///
    /// The tray is otherwise only reachable by tapping, and the share cards are
    /// the one part of the app whose output leaves it as an image, so this is
    /// the only way to see the rendered artwork on a simulator.
    static var forceShareTray: Bool {
        ProcessInfo.processInfo.arguments.contains(forceShareTrayFlag)
    }

    /// Opens MirrorCaptureSheet directly on the confirm step with the named
    /// template preselected, using today's archived photo as the capture. The
    /// simulator has no camera, so this is the only way to see the template
    /// picker there. Format: `--ui-test-mirror-confirm=<MirrorTemplate rawValue>`
    static var mirrorConfirmFilter: String? { stringValue(for: mirrorConfirmPrefix) }

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

    /// Onboarding screen the test harness wants to land on directly so each
    /// screen can be captured from a single launch. Raw value must match an
    /// `OnboardingV2View.Screen` case (welcome|about|goal|symptoms|bridge|scan|
    /// verdict|cliffhanger|journalFirst|heart|sleep|hrv|preview|signIn|referral|
    /// paywall|done). Format: `--ui-test-onboarding-v2-screen=heart`
    static var onboardingV2StartScreen: String? { stringValue(for: onboardingV2ScreenPrefix) }

    /// Forces the onboarding primary goal for screenshot capture so goal-adaptive
    /// screens (e.g. the Screen 14 social proof line) render per goal from a single
    /// launch. Format: `--ui-test-onboarding-goal=sleep|energy|training|stress|longevity|weight`
    static var onboardingGoal: String? { stringValue(for: onboardingGoalPrefix) }

    /// Settings sub-page the test harness wants pushed onto the Settings tab on
    /// first appear so a single launch can capture e.g. NotificationsSettingsView.
    /// Format: `--ui-test-settings-route=notifications|devices|siri`
    static var settingsInitialRoute: String? { stringValue(for: settingsRoutePrefix) }

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

        // A simulator has no camera, so the Daily Mirror capture flow can only
        // be driven end to end if the archive already holds something. Writing
        // synthetic days here is the only way a UI test reaches the confirm
        // screen and the template picker at all.
        if ProcessInfo.processInfo.arguments.contains(seedMirrorFlag) {
            // configureDefaults runs on the main thread during app init, and
            // MirrorPhotoStore.Meta inherits the store's main actor isolation.
            MainActor.assumeIsolated { seedMirrorArchive() }
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

        // Seed a prior-day marked-done action so the loop-closer card can be
        // driven deterministically. Value = the morning lock recorded on the done
        // day; today's override-overall-score minus this is the shown delta.
        if let seededScore = intValue(for: seedDailyResultPrefix),
           let dayAgo = Calendar.current.date(byAdding: .hour, value: -26, to: Date()),
           let data = try? JSONEncoder().encode(
               DailyActionResultStore.Record(doneDate: dayAgo,
                                             actionTitle: "10-minute brisk walk",
                                             actionIcon: "figure.walk",
                                             morningLockOnDoneDay: seededScore)) {
            defaults.set(data, forKey: AppKeys.Data.dailyActionResult)
            // The card compares morning locks on both ends, so today needs a real
            // lock as well or it stays hidden.
            if let todayScore = overrideOverallScore {
                ReadinessStore().saveMorningLock(todayScore, for: Date())
            }
        }
    }

    /// Writes eight synthetic Daily Mirror days ending today, so the capture
    /// confirm screen, the template picker, the gallery and the archive
    /// templates all have something real to draw on a device with no camera.
    ///
    /// Written straight to disk rather than through the store: this runs before
    /// the first main actor hop, and the store reads its index once at init.
    @MainActor
    private static func seedMirrorArchive() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("DailyMirror", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"

        var index: [String: MirrorPhotoStore.Meta] = [:]
        for offset in 0..<8 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let key = formatter.string(from: Calendar.current.startOfDay(for: day))
            let score = 58 + (offset * 9) % 34
            let photo = syntheticPortrait(warm: offset % 2 == 0)
            try? photo.jpegData(compressionQuality: 0.7)?
                .write(to: directory.appendingPathComponent("\(key).jpg"))

            // The oldest two are left without a template on purpose: they stand
            // in for photos captured before the overlay moved out of the pixels,
            // which is the migration path most likely to break unnoticed.
            if offset >= 6 {
                index[key] = MirrorPhotoStore.Meta(score: score, streak: 8 - offset)
            } else {
                var payload = MirrorPayload.empty
                payload.date = day
                payload.streak = 8 - offset
                payload.captureCount = 8
                payload.daysSinceFirst = 212
                payload.score = score
                payload.sleepHours = 7.4
                payload.deepMinutes = 63
                payload.vitalityAge = 31
                payload.chronologicalAge = 34
                payload.scoreHistory = (0..<20).map { 58 + ($0 * 7) % 32 }
                index[key] = MirrorPhotoStore.Meta(
                    score: score, streak: 8 - offset,
                    template: MirrorTemplate.fieldNotes.rawValue, payload: payload
                )
            }
        }
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: directory.appendingPathComponent("index.json"))
        }
    }

    private static func syntheticPortrait(warm: Bool) -> UIImage {
        let size = CGSize(width: 780, height: 1040)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let top: [CGFloat] = warm ? [0.79, 0.72, 0.62, 1] : [0.42, 0.49, 0.56, 1]
            let bottom: [CGFloat] = warm ? [0.20, 0.17, 0.14, 1] : [0.09, 0.11, 0.13, 1]
            if let gradient = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                         colorComponents: top + bottom,
                                         locations: [0, 1], count: 2) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: 0, y: size.height), options: [])
            }
            cg.setFillColor(red: 0.16, green: 0.12, blue: 0.09, alpha: 0.85)
            cg.fillEllipse(in: CGRect(x: size.width * 0.30, y: size.height * 0.20,
                                      width: size.width * 0.40, height: size.height * 0.30))
        }
    }
}
#else
/// Release-safe stub. All values are static-false / nil so feature gates compile
/// at every call site but no test-only behaviour can ever activate in App Store
/// builds. The launch-flag strings and configuration logic are stripped from
/// the Release binary entirely.
enum UITestMode {
    static var isEnabled: Bool { false }
    static var shouldShowOnboarding: Bool { false }
    static var requestedAppearance: UIUserInterfaceStyle { .dark }
    static var preferredColorScheme: ColorScheme { .dark }
    static var simulateNoWatch: Bool { false }
    static var simulateFemaleProfile: Bool { false }
    static var showDisclaimer: Bool { false }
    static var forceShowPaywall: Bool { false }
    static var forceProLock: Bool { false }
    static var forceMorningCheckIn: Bool { false }
    static var forceMirrorMoment: Bool { false }
    static var forceShareTray: Bool { false }
    static var mirrorConfirmFilter: String? { nil }
    static var premiumShowcase: Bool { false }
    static var forceSubscribed: Bool { false }
    static var initialTab: String? { nil }
    static var initialRoute: String? { nil }
    static var onboardingV2StartScreen: String? { nil }
    static var onboardingGoal: String? { nil }
    static var settingsInitialRoute: String? { nil }
    static var overrideName: String? { nil }
    static var overrideOverallScore: Int? { nil }
    static var overrideSleepScore: Int? { nil }
    static var overrideActivityScore: Int? { nil }

    static func configureDefaults() { /* no-op in Release */ }
}
#endif
