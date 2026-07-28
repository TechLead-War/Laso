import SwiftUI
import AppIntents

/// Main entry point for the Laso app
@main
struct LasoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var container: AppContainer

    /// Controls optional branded splash overlay.
    @State private var showSplash = true
    private let isUITestMode: Bool

    private var appStateStore: AppStateStore { container.appStateStore }
    private var subscriptionManager: SubscriptionManager { container.subscriptionManager }
    private var remoteConfig: RemoteConfigManager { container.remoteConfigManager }

    /// Show paywall only when onboarding is done and subscription is definitively expired.
    /// Respects FeatureGate.freeYearActive. when active, paywall is disabled.
    /// UI test override: `--ui-test-show-paywall` forces it on for screenshot capture.
    private var shouldShowPaywall: Bool {
        if isUITestMode && UITestMode.forceShowPaywall {
            return appStateStore.onboardingCompleted && appStateStore.disclaimerAcknowledged
        }
        guard appStateStore.onboardingCompleted else { return false }
        return subscriptionManager.shouldEnforcePaywall && !FeatureGate.hasFullAccess
    }

    /// Detects TestFlight or App Store Review sandbox environment.
    /// Apple's review process uses a sandbox receipt, so remote config blockers
    /// (kill switch, force update) are bypassed to prevent App Store rejection.
    private var isTestFlightOrAppReview: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// Runs one-time initial calibration (historical sync + baseline analysis) during onboarding.
    /// Returns an error message when calibration fails; nil indicates success.
    @MainActor
    private func performInitialCalibration() async -> String? {
        // The shared instance, not a throwaway: a second one repeats the whole
        // scorer prewarm and its SwiftData write for results nothing reads.
        let calibrator = container.dashboardViewModel
        await calibrator.load(
            skipDiscovery: true,
            awaitDeferredAnalysis: true,
            forceHeavyDeferred: true,
            runHousekeeping: false
        )

        if let error = calibrator.ui.errorMessage {
            return error
        }

        // Calibration has already done the first full analysis; avoid showing Day-0 discovery later.
        appStateStore.markDiscoverySeen()
        appStateStore.setPendingCalibrationHydration(true)
        return nil
    }

    init() {
        UITestMode.configureDefaults()
        isUITestMode = UITestMode.isEnabled
        let newContainer = AppContainer()
        if UITestMode.isEnabled {
            newContainer.injectUITestMockData()
        }
        _container = State(wrappedValue: newContainer)
        _showSplash = State(initialValue: !isUITestMode)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 0. Force update or maintenance. blocks everything
                // Skip in UI test mode and during App Store review / TestFlight
                if !isUITestMode && !isTestFlightOrAppReview && remoteConfig.requiresForceUpdate {
                    ForceUpdateView()
                } else if !isUITestMode && !isTestFlightOrAppReview && remoteConfig.killSwitchEnabled {
                    MaintenanceView(message: remoteConfig.killSwitchMessage)
                } else {
                    ContentView(container: container)
                    // 1. Onboarding (first launch)
                    .fullScreenCover(isPresented: Binding(
                        get: { !appStateStore.onboardingCompleted },
                        set: { if !$0 {
                            appStateStore.markOnboardingCompleted()
                        }}
                    )) {
                        OnboardingV2View(
                            healthKitManager: container.healthKitManager,
                            appStateStore: appStateStore,
                            subscriptionManager: subscriptionManager,
                            runCalibration: performInitialCalibration
                        ) {
                            appStateStore.markOnboardingCompleted()
                        }
                    }
                    // 2. Medical disclaimer catch-up. New users acknowledge it on the
                    // onboarding done screen; this cover only reaches users who
                    // finished onboarding before that screen existed.
                    .fullScreenCover(isPresented: Binding(
                        get: { appStateStore.onboardingCompleted && !appStateStore.disclaimerAcknowledged },
                        set: { if !$0 { appStateStore.markDisclaimerAcknowledged() } }
                    )) {
                        MedicalDisclaimerView {
                            appStateStore.markDisclaimerAcknowledged()
                        }
                    }
                    // 3. Paywall (trial expired + not subscribed)
                    .fullScreenCover(isPresented: Binding(
                        get: { shouldShowPaywall },
                        set: { _ in }  // Cannot dismiss. must subscribe
                    )) {
                        PaywallView(subscriptionManager: subscriptionManager, source: "trial_expired")
                            .interactiveDismissDisabled()
                    }
                }

                // Branded splash. matches system launch screen for seamless transition.
                // Covers the gap between Firebase init and first meaningful render.
                if showSplash {
                    splashView
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                guard !isUITestMode else { return }
                // Reporting only, and it walks every loaded dyld image, so it runs
                // off the launch path instead of inside `init` ahead of first frame.
                Task.detached(priority: .utility) { AppIntegrityGuard.performChecks() }
                await container.startupCoordinator.runInitialSetup(
                    healthDataStore: container.healthDataStore,
                    healthKitManager: container.healthKitManager
                )

                // Dismiss splash once background init is done
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }

            }
            // After "Delete All My Data" wipes local state + signs out, the
            // SettingsView posts LasoDidWipeAccount. Reset onboardingCompleted
            // so the user lands back on onboarding instead of an empty dashboard.
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LasoDidWipeAccount"))) { _ in
                appStateStore.setOnboardingCompleted(false)
                // Stop HealthKit observers + background delivery so the app is not
                // woken after the user deletes their data.
                container.healthKitManager.stopDashboardObservers()
                WatchMonitor.shared.stopMonitoring()
                PhoneWatchSession.shared.clearForAccountWipe()
            }
            // Appearance is applied to the window by ThemeManager, not with
            // .preferredColorScheme — see ThemeManager for why "System" cannot
            // be built on the SwiftUI modifier. UI tests still pin a style so
            // snapshots stay deterministic.
            .task {
                ThemeManager.shared.apply(
                    override: isUITestMode ? UITestMode.requestedAppearance : nil
                )
            }
        }
    }

    // MARK: - Splash View

    private var splashView: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                ProgressView()
                    .tint(.secondary)
            }
        }
    }
}
