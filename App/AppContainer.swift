import Foundation

/// Centralized dependency composition for the app's long-lived services.
@MainActor
final class AppContainer {
    let appStateStore: AppStateStore
    let intentCacheStore: IntentCacheStore
    let readinessStore: ReadinessStore
    let persistenceManager: PersistenceManager

    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let deviceSourceManager: DeviceSourceManager
    let healthDataStore: HealthDataStore
    let dashboardSmartActionAdvisor: DashboardSmartActionAdvisor
    let dashboardHousekeepingService: DashboardHousekeepingService

    let subscriptionManager: SubscriptionManager
    let remoteConfigManager: RemoteConfigManager
    let cloudBackupManager: CloudBackupManager
    let notificationManager: NotificationManager
    let watchMonitor: WatchMonitor

    let startupCoordinator: AppStartupCoordinator
    let backgroundRefreshCoordinator: BackgroundRefreshCoordinator

    init() {
        appStateStore = AppStateStore()
        intentCacheStore = IntentCacheStore()
        readinessStore = ReadinessStore()
        persistenceManager = PersistenceManager()

        let healthKitManager = HealthKitManager()
        self.healthKitManager = healthKitManager
        analysisEngine = AnalysisEngine()
        deviceSourceManager = DeviceSourceManager(healthStore: healthKitManager.healthStore)

        if let modelContainer = HealthDataContainerFactory.makeModelContainer() {
            healthDataStore = HealthDataStore(modelContainer: modelContainer)
        } else {
            AnalyticsBackend.provider.captureError("Running without SwiftData — all persistence disabled", context: "app_container_init")
            healthDataStore = HealthDataStore()
        }
        dashboardSmartActionAdvisor = DashboardSmartActionAdvisor()
        dashboardHousekeepingService = DashboardHousekeepingService(
            persistenceManager: persistenceManager,
            analytics: AppAnalytics.shared,
            sessionTracker: SessionTracker.shared
        )

        subscriptionManager = .shared
        remoteConfigManager = .shared
        cloudBackupManager = .shared
        notificationManager = .shared
        watchMonitor = .shared

        startupCoordinator = AppStartupCoordinator(
            subscriptionManager: subscriptionManager,
            cloudBackupManager: cloudBackupManager,
            notificationManager: notificationManager,
            watchMonitor: watchMonitor,
            persistenceManager: persistenceManager
        )
        // Activate the watch link as soon as the process is alive, not inside
        // post-launch setup: wrist writes queued while the app was closed are
        // delivered on activation, and every launch path must drain that queue.
        PhoneWatchSession.shared.activate(healthDataStore: healthDataStore)

        let sharedReadinessStore = readinessStore
        backgroundRefreshCoordinator = BackgroundRefreshCoordinator(
            liveViewModelFactory: {
                let healthKitManager = HealthKitManager()
                return LiveViewModel(
                    healthKitManager: healthKitManager,
                    readinessStore: sharedReadinessStore
                )
            }
        )
    }

    // Long-lived, exactly like every other service above. They are `lazy` rather
    // than built in `init` so nothing here runs before the container is ready.
    //
    // These used to be factory methods. `State(wrappedValue:)` takes a value, not
    // an autoclosure, so `ContentView.init` built all three on every construction
    // and SwiftUI discarded all but the first — and `ContentView` is reconstructed
    // whenever `LasoApp`'s body re-evaluates, which `showSplash` alone guarantees
    // at least once per launch. Each discarded `DashboardViewModel.init` still ran
    // its scorer prewarm and a synchronous SwiftData write.
    lazy var dashboardViewModel: DashboardViewModel = DashboardViewModel(
        healthKitManager: healthKitManager,
        analysisEngine: analysisEngine,
        store: healthDataStore,
        persistence: persistenceManager,
        appStateStore: appStateStore,
        intentCacheStore: intentCacheStore,
        smartActionAdvisor: dashboardSmartActionAdvisor,
        housekeepingService: dashboardHousekeepingService
    )

    lazy var liveViewModel: LiveViewModel = LiveViewModel(
        healthKitManager: healthKitManager,
        readinessStore: readinessStore
    )

    lazy var webExportViewModel: WebExportViewModel = WebExportViewModel(
        healthKitManager: healthKitManager,
        analysisEngine: analysisEngine
    )

    /// Seeds the in-memory stores with SampleDataProvider output so screenshot
    /// tests can exercise every data-dependent screen. Only runs when
    /// `UITestMode.isEnabled` so the production path is untouched.
    /// When `--ui-test-premium-showcase` is passed, swaps in
    /// `PremiumShowcaseDataProvider` so values reflect a thriving, post-purchase
    /// user (used to capture App Store screenshots).
    /// DEBUG-only body: in Release builds this is a no-op since the providers
    /// and UITestMode flags do not ship.
    func injectUITestMockData() {
        #if DEBUG
        guard UITestMode.isEnabled else { return }

        // Seed a completed user profile (female if requested so cycle flows appear)
        let gender: Gender = UITestMode.simulateFemaleProfile ? .female : .male
        let dob = Date.cal.date(byAdding: .year, value: -32, to: Date()) ?? Date()
        let profile = UserProfileStore.shared.makeProfile(
            name: UITestMode.overrideName ?? "Alex Taylor",
            email: "alex@example.com",
            gender: gender,
            dateOfBirth: dob,
            healthFocuses: ["Sleep", "Stress", "Activity"]
        )
        UserProfileStore.shared.saveLocal(profile)

        let useShowcase = UITestMode.premiumShowcase

        // Time series + baselines drive every metric/detail view
        healthKitManager.timeSeries = useShowcase
            ? PremiumShowcaseDataProvider.generateAllTimeSeries(days: 90)
            : SampleDataProvider.generateAllTimeSeries(days: 90)
        healthKitManager.isAuthorized = true
        healthKitManager.lastRefresh = Date()

        analysisEngine.baselines = useShowcase
            ? PremiumShowcaseDataProvider.generateBaselines()
            : SampleDataProvider.generateBaselines()
        var (overall, categories) = useShowcase
            ? PremiumShowcaseDataProvider.generateSampleScores()
            : SampleDataProvider.generateSampleScores()

        // Apply per-run value overrides from launch args. Lets the admin
        // dashboard customise the numbers visible on the home hero card and
        // category cards without rebuilding the app.
        if let v = UITestMode.overrideOverallScore {
            overall = HealthScore(score: max(0, min(100, v)))
        }
        if let v = UITestMode.overrideSleepScore,
           let i = categories.firstIndex(where: { $0.category == .sleep }) {
            categories[i] = HealthScore(category: .sleep, score: max(0, min(100, v)), breakdown: categories[i].breakdown)
        }
        if let v = UITestMode.overrideActivityScore,
           let i = categories.firstIndex(where: { $0.category == .activity }) {
            categories[i] = HealthScore(category: .activity, score: max(0, min(100, v)), breakdown: categories[i].breakdown)
        }

        analysisEngine.overallScore = overall
        analysisEngine.categoryScores = categories
        analysisEngine.insights = useShowcase
            ? PremiumShowcaseDataProvider.generateSampleInsights()
            : SampleDataProvider.generateSampleInsights()
        analysisEngine.healthRisks = useShowcase
            ? PremiumShowcaseDataProvider.generateSampleRisks()
            : SampleDataProvider.generateSampleRisks()
        analysisEngine.lastAnalysis = Date()

        // Persist samples + snapshots so detail views that read SwiftData render
        for (metric, series) in healthKitManager.timeSeries {
            healthDataStore.saveSamples(series.samples, for: metric)
        }
        // Premium showcase: high but balanced strain across the week (10-14 range,
        // peaking mid-week). Default mock: linear ramp 8 -> 13.4.
        for dayOffset in 0..<7 {
            let strain: Double = useShowcase
                ? [12.6, 13.4, 11.2, 14.1, 10.8, 13.0, 9.5][dayOffset]
                : 8.0 + Double(dayOffset) * 0.9
            let zoneMinutes: [Double] = useShowcase
                ? [30, 95, 75, 35, 10]
                : [45, 90, 60, 20, 5]
            let level = StrainLevel(strain: strain).rawValue
            let date = Date.cal.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            healthDataStore.saveDailyStrain(
                date: date,
                strain: strain,
                level: level,
                hrZoneMinutes: zoneMinutes
            )
        }
        healthDataStore.saveAnalysisSnapshot(
            overallScore: overall.score,
            categoryScores: categories,
            baselines: analysisEngine.baselines
        )

        // Force a paid subscription state so paywalls don't intercept and feature
        // gates render the post-purchase UI.
        if UITestMode.forceSubscribed {
            SubscriptionManager.shared.setStatusForUITestMode(
                .subscribed(expirationDate: .distantFuture)
            )
        }

        // Seed connected devices so Settings → Connected Devices renders and
        // watch-dependent paths (Live tab, stress, readiness) light up.
        let watchMetrics: Set<HealthMetric> = [
            .heartRate, .heartRateVariability, .restingHeartRate,
            .bloodOxygen, .sleepDuration, .activeCalories, .exerciseMinutes
        ]
        let phoneMetrics: Set<HealthMetric> = [
            .steps, .distanceWalkingRunning, .flightsClimbed, .walkingSpeed
        ]
        var devices: [ConnectedDeviceInfo] = [
            ConnectedDeviceInfo(
                device: .iPhone,
                sourceName: "Apple Health",
                sourceBundleId: "com.apple.health",
                metricsProvided: phoneMetrics,
                lastDataDate: Date(),
                deviceModelName: "iPhone 17 Pro"
            )
        ]
        if !UITestMode.simulateNoWatch {
            devices.insert(
                ConnectedDeviceInfo(
                    device: .appleWatch,
                    sourceName: "Apple Watch",
                    sourceBundleId: "com.apple.health.watch",
                    metricsProvided: watchMetrics,
                    lastDataDate: Date(),
                    deviceModelName: "Apple Watch Series 10"
                ),
                at: 0
            )
        }
        deviceSourceManager.connectedDevices = devices
        #endif
    }
}
