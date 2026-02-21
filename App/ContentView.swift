import SwiftUI

/// Root view with custom three-tab navigation and NavigationStack
struct ContentView: View {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let deviceSourceManager: DeviceSourceManager

    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @State private var navigationPath = NavigationPath()

    @State private var dashboardViewModel: DashboardViewModel
    @State private var liveViewModel: LiveViewModel
    @State private var webExportViewModel: WebExportViewModel

    init(
        healthKitManager: HealthKitManager,
        analysisEngine: AnalysisEngine,
        deviceSourceManager: DeviceSourceManager
    ) {
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
        self.deviceSourceManager = deviceSourceManager
        _dashboardViewModel = State(wrappedValue: DashboardViewModel(healthKitManager: healthKitManager, analysisEngine: analysisEngine))
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
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                webExportViewModel: webExportViewModel,
                deviceSourceManager: deviceSourceManager,
                healthKitManager: healthKitManager
            )
        }
        .task {
            await dashboardViewModel.load()
            liveViewModel.fetchHomeData()
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
    ContentView(
        healthKitManager: hkManager,
        analysisEngine: AnalysisEngine(),
        deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore)
    )
}
