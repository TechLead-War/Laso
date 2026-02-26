import SwiftUI
import SwiftData

/// Main entry point for the Laso app
@main
struct HealthPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage(AppKeys.App.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(AppKeys.App.appTheme) private var appTheme: String = "system"

    @State private var healthKitManager: HealthKitManager
    @State private var analysisEngine = AnalysisEngine()
    @State private var deviceSourceManager: DeviceSourceManager
    @State private var healthDataStore: HealthDataStore

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
        onboardingCompleted && !FeatureGate.hasFullAccess
    }

    init() {
        let hkManager = HealthKitManager()
        _healthKitManager = State(wrappedValue: hkManager)
        _deviceSourceManager = State(wrappedValue: DeviceSourceManager(healthStore: hkManager.healthStore))

        do {
            let container = try ModelContainer(
                for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self
            )
            _healthDataStore = State(wrappedValue: HealthDataStore(modelContainer: container))
        } catch {
            fatalError("Failed to create health data ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                healthKitManager: healthKitManager,
                analysisEngine: analysisEngine,
                deviceSourceManager: deviceSourceManager,
                healthDataStore: healthDataStore
            )
            .preferredColorScheme(colorScheme)
            // 1. Onboarding (first launch)
            .fullScreenCover(isPresented: Binding(
                get: { !onboardingCompleted },
                set: { if !$0 { onboardingCompleted = true } }
            )) {
                OnboardingView(healthKitManager: healthKitManager) {
                    onboardingCompleted = true
                    NSUbiquitousKeyValueStore.default.set(true, forKey: AppKeys.App.onboardingCompleted)
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
