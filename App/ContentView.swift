import SwiftUI
import SwiftData

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
        .task(id: onboardingCompleted) {
            guard onboardingCompleted else { return }

            if pendingCalibrationHydration && healthKitManager.lastRefresh != nil {
                dashboardViewModel.hydrateFromCalibration()
                pendingCalibrationHydration = false
            } else {
                await dashboardViewModel.load()
            }
            liveViewModel.fetchHomeData()
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
                // Retry sync if Home is stuck in empty state (e.g. user granted
                // permissions in Settings and returned, or initial sync failed)
                Task { await dashboardViewModel.retrySyncIfNeeded() }
            } else if newPhase == .background {
                AppAnalytics.shared.trackSessionEnd()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            SessionTracker.shared.currentTab = newTab.rawValue
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
