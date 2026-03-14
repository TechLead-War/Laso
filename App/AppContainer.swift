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
            print("[Laso] Running without SwiftData — all persistence disabled")
            healthDataStore = HealthDataStore()
        }
        dashboardSmartActionAdvisor = DashboardSmartActionAdvisor()
        dashboardHousekeepingService = DashboardHousekeepingService(
            persistenceManager: persistenceManager
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
}
