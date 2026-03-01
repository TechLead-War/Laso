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

        if let container = Self.createModelContainer() {
            _healthDataStore = State(wrappedValue: HealthDataStore(modelContainer: container))
        } else {
            print("[HealthPulse] Running without SwiftData — all persistence disabled")
            _healthDataStore = State(wrappedValue: HealthDataStore())
        }
    }

    /// Creates a ModelContainer with progressive fallback — uses Schema-based API and logs every failure.
    private static func createModelContainer() -> ModelContainer? {
        let storeDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HealthData", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try? (storeDir as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
        let dbURL = storeDir.appendingPathComponent("health.store")

        let allModels: [any PersistentModel.Type] = [
            StoredDailySample.self, StoredSyncMetadata.self,
            StoredAnalysisSnapshot.self, StoredMLModelState.self
        ]

        // 1. Disk-based with all models (happy path)
        do {
            let config = ModelConfiguration(url: dbURL)
            return try ModelContainer(for: Schema(allModels), configurations: [config])
        } catch {
            print("[HealthPulse] Step 1 (disk, all models) failed: \(error)")
        }

        // 2. Delete corrupt database, retry disk
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: dbURL.path + suffix)
        }
        do {
            let config = ModelConfiguration(url: dbURL)
            return try ModelContainer(for: Schema(allModels), configurations: [config])
        } catch {
            print("[HealthPulse] Step 2 (clean disk, all models) failed: \(error)")
        }

        // 3–6. Progressive in-memory fallbacks with fewer models
        let fallbackSets: [[any PersistentModel.Type]] = [
            allModels,
            [StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self],
            [StoredDailySample.self, StoredSyncMetadata.self],
            [StoredDailySample.self]
        ]

        for (i, models) in fallbackSets.enumerated() {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: Schema(models), configurations: [config])
            } catch {
                print("[HealthPulse] Step \(i + 3) (in-memory, \(models.count) model\(models.count == 1 ? "" : "s")) failed: \(error)")
            }
        }

        // All Schema-based attempts failed — try the simplest possible call as last resort
        do {
            return try ModelContainer(for: StoredDailySample.self)
        } catch {
            print("[HealthPulse] All ModelContainer attempts failed: \(error)")
            return nil
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
                WatchMonitor.shared.configure(healthStore: healthKitManager.healthStore)
                WatchMonitor.shared.startMonitoring()
            }
        }
    }
}
