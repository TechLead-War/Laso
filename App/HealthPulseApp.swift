import SwiftUI
import SwiftData

/// Main entry point for the Laso app
@main
struct HealthPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage(AppKeys.App.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(AppKeys.App.appTheme) private var appTheme: String = "system"
    @AppStorage(AppKeys.App.pendingCalibrationHydration) private var pendingCalibrationHydration = false

    @State private var healthKitManager: HealthKitManager
    @State private var analysisEngine = AnalysisEngine()
    @State private var deviceSourceManager: DeviceSourceManager
    @State private var healthDataStore: HealthDataStore

    /// Controls optional branded splash overlay.
    @State private var showSplash = true

    private let subscriptionManager = SubscriptionManager.shared

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Show paywall only when onboarding is done and subscription is definitively expired.
    /// Free year: paywall disabled for PMF signal.
    private var shouldShowPaywall: Bool {
        false
    }

    /// Runs one-time initial calibration (historical sync + baseline analysis) during onboarding.
    /// Returns an error message when calibration fails; nil indicates success.
    @MainActor
    private func performInitialCalibration() async -> String? {
        let calibrator = DashboardViewModel(
            healthKitManager: healthKitManager,
            analysisEngine: analysisEngine,
            store: healthDataStore
        )
        await calibrator.load(
            skipDiscovery: true,
            awaitDeferredAnalysis: true,
            forceHeavyDeferred: true,
            runHousekeeping: false
        )

        if let error = calibrator.errorMessage {
            return error
        }

        // Calibration has already done the first full analysis; avoid showing Day-0 discovery later.
        UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenDiscovery)
        pendingCalibrationHydration = true
        return nil
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
        // Use completeUntilFirstUserAuthentication so App Intents (Siri) can access
        // the store when the device is locked (after first unlock).
        try? (storeDir as NSURL).setResourceValue(URLFileProtection.completeUntilFirstUserAuthentication, forKey: .fileProtectionKey)
        let dbURL = storeDir.appendingPathComponent("health.store")

        let allModels: [any PersistentModel.Type] = [
            StoredDailySample.self, StoredSyncMetadata.self,
            StoredAnalysisSnapshot.self, StoredMLModelState.self,
            StoredRecommendation.self, StoredNotificationEvent.self,
            StoredAdherenceRecord.self, StoredECGFeatures.self
        ]

        // Schema version tracking — delete DB when model set changes to avoid hangs
        let schemaVersionKey = "healthdata.schema.version"
        let currentSchemaVersion = allModels.count
        let storedSchemaVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        if storedSchemaVersion != 0 && storedSchemaVersion != currentSchemaVersion {
            print("[HealthPulse] Schema changed (\(storedSchemaVersion) → \(currentSchemaVersion)), deleting DB")
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: dbURL.path + suffix)
            }
        }

        // 1. Disk-based with all models (happy path)
        do {
            let config = ModelConfiguration(url: dbURL)
            let container = try ModelContainer(for: Schema(allModels), configurations: [config])
            UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            return container
        } catch {
            print("[HealthPulse] Step 1 (disk, all models) failed: \(error)")
        }

        // 2. Delete corrupt database, retry disk
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: dbURL.path + suffix)
        }
        do {
            let config = ModelConfiguration(url: dbURL)
            let container = try ModelContainer(for: Schema(allModels), configurations: [config])
            UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            return container
        } catch {
            print("[HealthPulse] Step 2 (clean disk, all models) failed: \(error)")
        }

        // 3–6. Progressive in-memory fallbacks with fewer models
        let fallbackSets: [[any PersistentModel.Type]] = [
            allModels,
            [StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredRecommendation.self, StoredNotificationEvent.self],
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
            ZStack {
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
                    OnboardingView(
                        healthKitManager: healthKitManager,
                        runCalibration: performInitialCalibration
                    ) {
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
                    // Run CloudKit restore and subscription configure in parallel
                    async let subscriptionTask: Void = subscriptionManager.configure()

                    if healthDataStore.totalStoredSamples == 0 {
                        let persistence = PersistenceManager()
                        _ = await CloudBackupManager.shared.restore(
                            store: healthDataStore, persistence: persistence
                        )
                    }

                    // Wait for both to complete concurrently
                    _ = await subscriptionTask

                    NotificationManager.shared.store = healthDataStore

                    WatchMonitor.shared.configure(healthStore: healthKitManager.healthStore)
                    WatchMonitor.shared.startMonitoring()

                    // Cancel stale weekly summary notifications that may have been
                    // registered with older, more aggressive defaults.
                    WeeklySummaryScheduler.cancel()

                    // Dismiss splash once background init is done
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }

                // Branded splash — matches system launch screen for seamless transition.
                // Covers the gap between Firebase init and first meaningful render.
                if showSplash {
                    splashView
                        .transition(.opacity)
                        .zIndex(1)
                }
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
