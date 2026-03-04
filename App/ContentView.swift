import SwiftUI
import SwiftData
import Network
import Observation

/// Root view with custom three-tab navigation and NavigationStack
struct ContentView: View {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let deviceSourceManager: DeviceSourceManager
    let healthDataStore: HealthDataStore

    @AppStorage(AppKeys.App.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(AppKeys.App.pendingCalibrationHydration) private var pendingCalibrationHydration = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @State private var showFeedback = false
    @State private var navigationPath = NavigationPath()
    @State private var connectivityMonitor = ConnectivityMonitor.shared

    @State private var dashboardViewModel: DashboardViewModel
    @State private var liveViewModel: LiveViewModel
    @State private var webExportViewModel: WebExportViewModel

    init(
        healthKitManager: HealthKitManager,
        analysisEngine: AnalysisEngine,
        deviceSourceManager: DeviceSourceManager,
        healthDataStore: HealthDataStore
    ) {
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
        self.deviceSourceManager = deviceSourceManager
        self.healthDataStore = healthDataStore
        _dashboardViewModel = State(wrappedValue: DashboardViewModel(healthKitManager: healthKitManager, analysisEngine: analysisEngine, store: healthDataStore))
        _liveViewModel = State(wrappedValue: LiveViewModel(healthKitManager: healthKitManager))
        _webExportViewModel = State(wrappedValue: WebExportViewModel(healthKitManager: healthKitManager, analysisEngine: analysisEngine))
    }

    var body: some View {
        mainApp
    }

    private var subscriptionManager: SubscriptionManager { .shared }

    private var mainApp: some View {
        NavigationStack(path: $navigationPath) {
            tabContent
                .safeAreaInset(edge: .top, spacing: 0) {
                    billingGraceBanner
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .navigationDestination(for: HealthCategory.self) { category in
                    CategoryDetailView(
                        viewModel: CategoryDetailViewModel(
                            category: category,
                            healthKitManager: healthKitManager,
                            analysisEngine: analysisEngine
                        )
                    )
                }
                .navigationDestination(for: HealthMetric.self) { metric in
                    MetricDetailView(
                        viewModel: MetricDetailViewModel(
                            metric: metric,
                            healthKitManager: healthKitManager,
                            analysisEngine: analysisEngine
                        ),
                        deviceSourceManager: deviceSourceManager,
                        healthKitManager: healthKitManager,
                        healthDataStore: healthDataStore
                    )
                }
                .navigationDestination(for: HealthRiskType.self) { riskType in
                    if let risk = dashboardViewModel.healthRisks.first(where: { $0.riskType == riskType }) {
                        HealthRiskDetailView(risk: risk) { metric in
                            navigationPath.append(metric)
                        }
                    } else {
                        ContentUnavailableView(
                            "Risk Data Unavailable",
                            systemImage: "heart.text.clipboard",
                            description: Text("This health risk assessment is no longer available. Pull to refresh your data.")
                        )
                    }
                }
                .navigationDestination(for: String.self) { route in
                    if route == "insightsDetail" {
                        InsightsDetailView(
                            insightsByCategory: dashboardViewModel.actionableInsightsByCategory,
                            onTapMetric: { metric in
                                navigationPath.append(metric)
                            },
                            headlineSummary: dashboardViewModel.topCausalChain?.narrative ?? dashboardViewModel.headlineInsight?.recommendation,
                            store: healthDataStore
                        )
                    } else if route == "weeklyReview" {
                        WeeklyReviewView(
                            viewModel: WeeklyReviewViewModel(dashboardViewModel: dashboardViewModel)
                        )
                    } else if route == "correlationsDetail" {
                        CorrelationsView(
                            correlations: dashboardViewModel.correlations,
                            onTapMetric: { metric in
                                navigationPath.append(metric)
                            }
                        )
                    } else if route == "healthStateTimeline" {
                        HealthStateTimelineView(
                            viewModel: HealthStateTimelineViewModel(
                                mlOrchestrator: dashboardViewModel.analysisEngine.mlOrchestrator
                            )
                        )
                    }
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                webExportViewModel: webExportViewModel,
                deviceSourceManager: deviceSourceManager,
                healthKitManager: healthKitManager,
                healthDataStore: healthDataStore
            )
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet()
        }
        .task(id: onboardingCompleted) {
            guard onboardingCompleted else { return }

            if pendingCalibrationHydration && healthKitManager.lastRefresh != nil {
                dashboardViewModel.hydrateFromCalibration()
                pendingCalibrationHydration = false
            } else {
                await dashboardViewModel.load()
            }
            if selectedTab == .home {
                liveViewModel.fetchHomeData()
            }
        }
        .onAppear {
            FeedbackPromptManager.shared.recordAppOpen()
            startSessionAnalytics()
            if FeedbackPromptManager.shared.shouldShowFeedbackPrompt() {
                showFeedback = true
                FeedbackPromptManager.shared.markPromptShown()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                startSessionAnalytics()
                WatchMonitor.shared.evaluateWatchStatus()
                if selectedTab == .home {
                    // Refresh home data only when Home is visible.
                    liveViewModel.fetchHomeData()
                    // Retry sync only when Home is visible and potentially stuck.
                    Task { await dashboardViewModel.retrySyncIfNeeded() }
                }
            } else if newPhase == .background {
                AppAnalytics.shared.trackSessionEnd()
            }
        }
        .onChange(of: connectivityMonitor.isOnline) { wasOnline, isOnline in
            AppAnalytics.shared.trackConnectivityStateChanged(
                isOnline: isOnline,
                isExpensive: connectivityMonitor.isExpensive,
                isConstrained: connectivityMonitor.isConstrained
            )

            guard wasOnline == false, isOnline == true else { return }
            guard onboardingCompleted, scenePhase == .active else { return }

            Task {
                let shouldRunSync = selectedTab == .home && !ThermalManager.shared.shouldThrottle
                let shouldRunBackup = !ThermalManager.shared.shouldThrottle
                let didSync: Bool

                if shouldRunSync && shouldRunBackup {
                    async let syncTask: Bool = dashboardViewModel.refreshAfterConnectivityRestoreIfNeeded()
                    async let backupTask: Void = CloudBackupManager.shared.backupIfNeeded(
                        store: healthDataStore,
                        persistence: PersistenceManager()
                    )
                    didSync = await syncTask
                    _ = await backupTask
                } else if shouldRunSync {
                    didSync = await dashboardViewModel.refreshAfterConnectivityRestoreIfNeeded()
                } else {
                    didSync = false
                    if shouldRunBackup {
                        await CloudBackupManager.shared.backupIfNeeded(
                            store: healthDataStore,
                            persistence: PersistenceManager()
                        )
                    }
                }

                AppAnalytics.shared.trackConnectivityRecovered(
                    offlineDurationSec: connectivityMonitor.lastOfflineDurationSec,
                    syncTriggered: didSync,
                    backupTriggered: shouldRunBackup
                )
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            SessionTracker.shared.currentTab = newTab.rawValue
            guard scenePhase == .active else { return }
            if newTab == .home {
                liveViewModel.fetchHomeDataTiered()
            }
        }
        .onChange(of: navigationPath.count) { _, newCount in
            AppAnalytics.shared.updateNavigationDepth(newCount)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(
                viewModel: dashboardViewModel,
                liveViewModel: liveViewModel,
                deviceSourceManager: deviceSourceManager,
                navigationPath: $navigationPath,
                showSettings: $showSettings
            )
        case .live:
            if FeatureGate.canAccess(.liveTab) {
                LiveView(viewModel: liveViewModel)
            } else {
                ProFeatureOverlay(
                    feature: "Live Vitals",
                    icon: "waveform.path.ecg",
                    description: "Monitor your heart rate, SpO2, activity rings, and readiness in real time."
                )
            }
        case .explore:
            ExploreView(
                viewModel: dashboardViewModel,
                navigationPath: $navigationPath
            )
        }
    }

    // MARK: - Session Analytics

    private func startSessionAnalytics() {
        let analytics = AppAnalytics.shared
        analytics.trackSessionStart()
        analytics.trackReturnSession()
        analytics.trackRetentionMilestones()
        analytics.trackInactivityIfNeeded()
    }

    // MARK: - Billing Grace Banner (subtle, non-blocking, only after 16 days)

    @ViewBuilder
    private var billingGraceBanner: some View {
        if let days = subscriptionManager.billingGraceDays, days >= 16 {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("Update your payment method to keep your subscription active.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link("Update", destination: url)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.08))
        }
    }
}

#Preview {
    let hkManager = HealthKitManager()
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    ContentView(
        healthKitManager: hkManager,
        analysisEngine: AnalysisEngine(),
        deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
        healthDataStore: HealthDataStore(modelContainer: container)
    )
}

/// Tracks internet reachability and transition timing for online recovery workflows.
@MainActor
@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.healthpulse.connectivity.monitor", qos: .utility)

    private(set) var isOnline = true
    private(set) var isExpensive = false
    private(set) var isConstrained = false
    private(set) var lastBecameOfflineAt: Date?
    private(set) var lastRecoveredAt: Date?
    private(set) var lastOfflineDurationSec: Int = 0

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained

            Task { @MainActor in
                self.applyPathState(
                    isOnline: online,
                    isExpensive: expensive,
                    isConstrained: constrained
                )
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func applyPathState(isOnline: Bool, isExpensive: Bool, isConstrained: Bool) {
        let wasOnline = self.isOnline
        let now = Date()

        if wasOnline != isOnline {
            if isOnline {
                if let offlineSince = lastBecameOfflineAt {
                    lastOfflineDurationSec = max(0, Int(now.timeIntervalSince(offlineSince)))
                } else {
                    lastOfflineDurationSec = 0
                }
                lastRecoveredAt = now
                lastBecameOfflineAt = nil
            } else {
                lastBecameOfflineAt = now
            }
        }

        self.isOnline = isOnline
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}
