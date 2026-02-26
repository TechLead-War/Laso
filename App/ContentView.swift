import SwiftUI
import SwiftData

/// Root view with custom three-tab navigation and NavigationStack
struct ContentView: View {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let deviceSourceManager: DeviceSourceManager
    let healthDataStore: HealthDataStore

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @State private var showFeedback = false
    @State private var navigationPath = NavigationPath()

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

    private var mainApp: some View {
        NavigationStack(path: $navigationPath) {
            tabContent
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
                        deviceSourceManager: deviceSourceManager
                    )
                }
                .navigationDestination(for: HealthRiskType.self) { riskType in
                    if let risk = dashboardViewModel.healthRisks.first(where: { $0.riskType == riskType }) {
                        HealthRiskDetailView(risk: risk) { metric in
                            navigationPath.append(metric)
                        }
                    }
                }
                .navigationDestination(for: String.self) { route in
                    if route == "insightsDetail" {
                        InsightsDetailView(
                            insightsByCategory: dashboardViewModel.insightsByCategory,
                            onTapMetric: { metric in
                                navigationPath.append(metric)
                            }
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
        .task {
            await dashboardViewModel.load()
            liveViewModel.fetchHomeData()
        }
        .onAppear {
            FeedbackPromptManager.shared.recordAppOpen()
            AppAnalytics.shared.trackSessionStart()
            AppAnalytics.shared.trackReturnSession()
            if FeedbackPromptManager.shared.shouldShowFeedbackPrompt() {
                showFeedback = true
                FeedbackPromptManager.shared.markPromptShown()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                AppAnalytics.shared.trackSessionStart()
                AppAnalytics.shared.trackReturnSession()
                WatchMonitor.shared.evaluateWatchStatus()
            } else if newPhase == .background {
                AppAnalytics.shared.trackFirstSessionProfile()
                AppAnalytics.shared.trackSessionQuality()
                AppAnalytics.shared.trackSessionEnd()
            }
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            AppAnalytics.shared.trackTabSwitch(to: newTab.rawValue, from: oldTab.rawValue)
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
            LiveView(viewModel: liveViewModel)
        case .explore:
            ExploreView(
                viewModel: dashboardViewModel,
                navigationPath: $navigationPath
            )
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
