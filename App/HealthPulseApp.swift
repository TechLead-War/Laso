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

    /// Show paywall only when onboarding is done and subscription is definitively expired.
    private var shouldShowPaywall: Bool {
        onboardingCompleted && subscriptionManager.shouldEnforcePaywall
    }

    init() {
        let hkManager = HealthKitManager()
        _healthKitManager = State(wrappedValue: hkManager)
        _deviceSourceManager = State(wrappedValue: DeviceSourceManager(healthStore: hkManager.healthStore))

        let container: ModelContainer
        do {
            let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("HealthData", isDirectory: true)
            try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
            try? (storeURL as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
            let config = ModelConfiguration(url: storeURL.appendingPathComponent("health.store"))
            container = try ModelContainer(
                for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredMLModelState.self,
                configurations: config
            )
        } catch {
            // Fallback to in-memory store if disk-based container fails (corrupted DB, etc.)
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(
                    for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredMLModelState.self,
                    configurations: fallback
                )
            } catch {
                // Last resort: empty container with default configuration
                container = try! ModelContainer(
                    for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredMLModelState.self
                )
            }
        }
        _healthDataStore = State(wrappedValue: HealthDataStore(modelContainer: container))
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
                set: { if !$0 {
                    onboardingCompleted = true
                    NSUbiquitousKeyValueStore.default.set(true, forKey: AppKeys.App.onboardingCompleted)
                }}
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
                // Restore from CloudKit on fresh install (before HealthKit sync)
                if healthDataStore.totalStoredSamples == 0 {
                    let persistence = PersistenceManager()
                    let restored = await CloudBackupManager.shared.restore(
                        store: healthDataStore, persistence: persistence
                    )
                    if restored {
                        // Data restored — HealthKit sync will be incremental (not full re-fetch)
                    }
                }
                await subscriptionManager.configure()
                WatchMonitor.shared.startMonitoring()
            }
        }
    }
}
