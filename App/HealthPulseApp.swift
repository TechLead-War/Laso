import SwiftUI

/// Main entry point for the Laso app
@main
struct HealthPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("healthpulse.onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("healthpulse.appTheme") private var appTheme: String = "system"

    @State private var healthKitManager: HealthKitManager
    @State private var analysisEngine = AnalysisEngine()
    @State private var deviceSourceManager: DeviceSourceManager

    private let subscriptionManager = SubscriptionManager.shared

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Show paywall when onboarding is done but user has no access (trial expired, not subscribed).
    private var shouldShowPaywall: Bool {
        onboardingCompleted && !subscriptionManager.hasAccess
    }

    init() {
        let hkManager = HealthKitManager()
        _healthKitManager = State(wrappedValue: hkManager)
        _deviceSourceManager = State(wrappedValue: DeviceSourceManager(healthStore: hkManager.healthStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                healthKitManager: healthKitManager,
                analysisEngine: analysisEngine,
                deviceSourceManager: deviceSourceManager
            )
            .preferredColorScheme(colorScheme)
            // 1. Onboarding (first launch)
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingCompleted },
                set: { if !$0 { onboardingCompleted = true } }
            )) {
                OnboardingView(healthKitManager: healthKitManager) {
                    onboardingCompleted = true
                    NSUbiquitousKeyValueStore.default.set(true, forKey: "healthpulse.onboardingCompleted")
                }
            }
            // 2. Paywall (trial expired + not subscribed)
            .fullScreenCover(isPresented: Binding(
                get: { shouldShowPaywall },
                set: { _ in }  // Cannot dismiss — must subscribe
            )) {
                PaywallView(subscriptionManager: subscriptionManager)
                    .interactiveDismissDisabled()
            }
            .task {
                await subscriptionManager.configure()
                WatchMonitor.shared.startMonitoring()
            }
        }
    }
}
