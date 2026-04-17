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
            PostHogManager.shared.captureError("Running without SwiftData — all persistence disabled", context: "app_container_init")
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

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            healthKitManager: healthKitManager,
            analysisEngine: analysisEngine,
            store: healthDataStore,
            persistence: persistenceManager,
            appStateStore: appStateStore,
            intentCacheStore: intentCacheStore,
            smartActionAdvisor: dashboardSmartActionAdvisor,
            housekeepingService: dashboardHousekeepingService
        )
    }

    func makeLiveViewModel() -> LiveViewModel {
        LiveViewModel(
            healthKitManager: healthKitManager,
            readinessStore: readinessStore
        )
    }

    func makeWebExportViewModel() -> WebExportViewModel {
        WebExportViewModel(
            healthKitManager: healthKitManager,
            analysisEngine: analysisEngine
        )
    }

    /// Seeds the in-memory stores with SampleDataProvider output so screenshot
    /// tests can exercise every data-dependent screen. Only runs when
    /// `UITestMode.isEnabled` so the production path is untouched.
    func injectUITestMockData() {
        guard UITestMode.isEnabled else { return }

        // Seed a completed user profile (female if requested so cycle flows appear)
        let gender: Gender = UITestMode.simulateFemaleProfile ? .female : .male
        let dob = Calendar.current.date(byAdding: .year, value: -32, to: Date()) ?? Date()
        let profile = UserProfileStore.shared.makeProfile(
            name: "Alex Taylor",
            email: "alex@example.com",
            gender: gender,
            dateOfBirth: dob,
            healthFocuses: ["Sleep", "Stress", "Activity"]
        )
        UserProfileStore.shared.saveLocal(profile)

        // Time series + baselines drive every metric/detail view
        healthKitManager.timeSeries = SampleDataProvider.generateAllTimeSeries(days: 90)
        healthKitManager.isAuthorized = true
        healthKitManager.lastRefresh = Date()

        analysisEngine.baselines = SampleDataProvider.generateBaselines()
        let (overall, categories) = SampleDataProvider.generateSampleScores()
        analysisEngine.overallScore = overall
        analysisEngine.categoryScores = categories
        analysisEngine.insights = SampleDataProvider.generateSampleInsights()
        analysisEngine.healthRisks = SampleDataProvider.generateSampleRisks()
        analysisEngine.lastAnalysis = Date()

        // Persist samples + snapshots so detail views that read SwiftData render
        for (metric, series) in healthKitManager.timeSeries {
            healthDataStore.saveSamples(series.samples, for: metric)
        }
        for dayOffset in 0..<7 {
            let strain = 8.0 + Double(dayOffset) * 0.9
            let level = StrainLevel(strain: strain).rawValue
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            healthDataStore.saveDailyStrain(
                date: date,
                strain: strain,
                level: level,
                hrZoneMinutes: [45, 90, 60, 20, 5]
            )
        }
        healthDataStore.saveAnalysisSnapshot(
            overallScore: overall.score,
            categoryScores: categories,
            baselines: analysisEngine.baselines
        )

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
    }
}
