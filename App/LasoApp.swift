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
    private var shouldShowPaywall: Bool {
        guard appStateStore.onboardingCompleted else { return false }
        return subscriptionManager.shouldEnforcePaywall && !FeatureGate.hasFullAccess
    }

    /// Runs one-time initial calibration (historical sync + baseline analysis) during onboarding.
    /// Returns an error message when calibration fails; nil indicates success.
    @MainActor
    private func performInitialCalibration() async -> String? {
        let calibrator = container.makeDashboardViewModel()
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

    /// Integrity check failure reason, if any. Set once at launch.
    private let integrityFailure: String?

    init() {
        UITestMode.configureDefaults()
        isUITestMode = UITestMode.isEnabled
        _container = State(wrappedValue: AppContainer())
        _showSplash = State(initialValue: !isUITestMode)
        integrityFailure = AppIntegrityGuard.performChecks()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // -1. Integrity failure. blocks everything on compromised devices
                if let failure = integrityFailure {
                    CompromisedEnvironmentView(reason: failure)
                }
                // 0. Force update or maintenance. blocks everything (skip in UI test mode)
                else if !isUITestMode && remoteConfig.requiresForceUpdate {
                    ForceUpdateView()
                } else if !isUITestMode && remoteConfig.killSwitchEnabled {
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
                        OnboardingView(
                            healthKitManager: container.healthKitManager,
                            appStateStore: appStateStore,
                            runCalibration: performInitialCalibration
                        ) {
                            appStateStore.markOnboardingCompleted()
                        }
                    }
                    // 2. Paywall (trial expired + not subscribed)
                    .fullScreenCover(isPresented: Binding(
                        get: { shouldShowPaywall },
                        set: { _ in }  // Cannot dismiss. must subscribe
                    )) {
                        PaywallView(subscriptionManager: subscriptionManager)
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
                await container.startupCoordinator.runInitialSetup(
                    healthDataStore: container.healthDataStore,
                    healthKitManager: container.healthKitManager
                )

                // Dismiss splash once background init is done
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }

            }
            .preferredColorScheme(isUITestMode ? UITestMode.preferredColorScheme : .dark)
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
