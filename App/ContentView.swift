import SwiftUI
import SwiftData
import Network
import Observation

/// Root view with custom three-tab navigation and NavigationStack
struct ContentView: View {
    let container: AppContainer

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showSettings = false
    @State private var showNotificationReprompt = false
    @State private var navigationPath = NavigationPath()
    @State private var connectivityMonitor = ConnectivityMonitor.shared

    @State private var dashboardViewModel: DashboardViewModel
    @State private var liveViewModel: LiveViewModel
    @State private var webExportViewModel: WebExportViewModel

    init(container: AppContainer) {
        self.container = container
        _dashboardViewModel = State(wrappedValue: container.makeDashboardViewModel())
        _liveViewModel = State(wrappedValue: container.makeLiveViewModel())
        _webExportViewModel = State(wrappedValue: container.makeWebExportViewModel())
    }

    var body: some View {
        mainApp
    }

    private var healthKitManager: HealthKitManager { container.healthKitManager }
    private var analysisEngine: AnalysisEngine { container.analysisEngine }
    private var deviceSourceManager: DeviceSourceManager { container.deviceSourceManager }
    private var healthDataStore: HealthDataStore { container.healthDataStore }
    private var appStateStore: AppStateStore { container.appStateStore }
    private var subscriptionManager: SubscriptionManager { container.subscriptionManager }

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
                    if let risk = dashboardViewModel.analysis.healthRisks.first(where: { $0.riskType == riskType }) {
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
                .navigationDestination(for: Route.self) { route in
                    routeDestination(for: route)
                }
        }
        .overlay(alignment: .top) {
            if showNotificationReprompt {
                NotificationRepromptBanner(isPresented: $showNotificationReprompt)
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.4), value: showNotificationReprompt)
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
        .task(id: appStateStore.onboardingCompleted) {
            guard appStateStore.onboardingCompleted else { return }

            if appStateStore.pendingCalibrationHydration && healthKitManager.lastRefresh != nil {
                dashboardViewModel.hydrateFromCalibration()
                appStateStore.setPendingCalibrationHydration(false)
            } else {
                await dashboardViewModel.load()
            }
            await refreshDeviceSourcesIfNeeded()
            // HomeView.onAppear handles its own initial fetch. no duplicate needed here
        }
        .onAppear {
            startSessionAnalytics()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                startSessionAnalytics()
                WatchMonitor.shared.evaluateWatchStatus()
                Task { await refreshDeviceSourcesIfNeeded() }
                Task {
                    if await NotificationRepromptManager.checkAndRecordDenial() {
                        showNotificationReprompt = true
                    }
                }
                if selectedTab == .home {
                    // HomeView's own onChange(scenePhase) handles fetchHomeData. no duplicate needed here
                    // Retry sync only when Home is visible and potentially stuck.
                    Task { await dashboardViewModel.retrySyncIfNeeded() }
                }
            } else if newPhase == .background {
                AppAnalytics.shared.trackSessionEnd()
                container.backgroundRefreshCoordinator.schedule()
            }
        }
        .onChange(of: connectivityMonitor.isOnline) { wasOnline, isOnline in
            guard wasOnline == false, isOnline == true else { return }
            guard appStateStore.onboardingCompleted, scenePhase == .active else { return }

            Task {
                let shouldRunSync = selectedTab == .home && !ThermalManager.shared.shouldThrottle
                let shouldRunBackup = !ThermalManager.shared.shouldThrottle
                let didSync: Bool

                if shouldRunSync && shouldRunBackup {
                    async let syncTask: Bool = dashboardViewModel.refreshAfterConnectivityRestoreIfNeeded()
                    async let backupTask: Void = container.cloudBackupManager.backupIfNeeded(
                        store: healthDataStore,
                        persistence: container.persistenceManager
                    )
                    didSync = await syncTask
                    _ = await backupTask
                } else if shouldRunSync {
                    didSync = await dashboardViewModel.refreshAfterConnectivityRestoreIfNeeded()
                } else {
                    didSync = false
                    if shouldRunBackup {
                        await container.cloudBackupManager.backupIfNeeded(
                            store: healthDataStore,
                            persistence: container.persistenceManager
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
        .onChange(of: selectedTab) { oldTab, newTab in
            SessionTracker.shared.currentTab = newTab.rawValue
            let blockType: BlockType = switch newTab {
            case .home: .tabHome
            case .live: .tabLive
            case .explore: .tabExplore
            }
            AppAnalytics.shared.trackBlockTap(
                title: newTab.rawValue.capitalized,
                type: blockType,
                screen: .home,
                metadata: ["from_tab": oldTab.rawValue, "to_tab": newTab.rawValue]
            )
            guard scenePhase == .active else { return }
            if newTab == .home {
                liveViewModel.fetchHomeDataTiered()
            }
        }
        .onChange(of: navigationPath.count) { _, newCount in
            AppAnalytics.shared.updateNavigationDepth(newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .healthPulseNavigateToExplore)) { _ in
            selectedTab = .explore
        }
    }

    private func refreshDeviceSourcesIfNeeded() async {
        guard healthKitManager.isAuthorized,
              deviceSourceManager.connectedDevices.isEmpty,
              !deviceSourceManager.isScanning else { return }
        await deviceSourceManager.scanSources()
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(
                viewModel: dashboardViewModel,
                liveViewModel: liveViewModel,
                deviceSourceManager: deviceSourceManager,
                appStateStore: appStateStore,
                navigationPath: $navigationPath,
                showSettings: $showSettings
            )
        case .live:
            if !UITestMode.isEnabled && RemoteConfigManager.shared.killLiveTab {
                MaintenanceView(message: "Live monitoring is temporarily unavailable. We're working on a fix.")
            } else if FeatureGate.canAccess(.liveTab) {
                LiveView(
                    viewModel: liveViewModel,
                    mlOrchestrator: dashboardViewModel.analysisEngine.mlOrchestrator,
                    deviceSourceManager: deviceSourceManager
                )
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
                appStateStore: appStateStore,
                navigationPath: $navigationPath
            )
        }
    }

    // MARK: - Route Destinations

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        switch route {
        case .insightsDetail:
            InsightsDetailView(
                insightsByCategory: dashboardViewModel.insights.insightsByCategory,
                onTapMetric: { metric in navigationPath.append(metric) },
                headlineSummary: dashboardViewModel.analysis.topCausalChain?.narrative ?? dashboardViewModel.insights.headlineInsight?.recommendation,
                store: healthDataStore
            )
        case .weeklyReview:
            WeeklyReviewView(viewModel: WeeklyReviewViewModel(dashboardViewModel: dashboardViewModel))
        case .correlationsDetail:
            CorrelationsView(
                correlations: dashboardViewModel.analysis.correlations,
                causalChains: dashboardViewModel.analysis.causalChains,
                compoundInsights: dashboardViewModel.analysis.compoundInsights,
                interactionEffects: dashboardViewModel.analysis.interactionEffects,
                onTapMetric: { metric in navigationPath.append(metric) }
            )
        case .healthStateTimeline:
            HealthStateTimelineView(
                viewModel: HealthStateTimelineViewModel(mlOrchestrator: dashboardViewModel.analysisEngine.mlOrchestrator)
            )
        case .vitalityDetail:
            VitalityDetailView(scorer: dashboardViewModel.vitalityScorer)
        case .strainDetail:
            strainDetailDestination
        case .stressMonitor:
            stressMonitorDestination
        case .brainHealth:
            brainHealthDestination
        case .sleepCoach:
            sleepCoachDestination
        case .cycleDetail:
            cycleDetailDestination
        case .achievements:
            achievementsDestination
        case .journalEntry:
            JournalEntryView()
        case .todaysAction:
            let readinessScore = liveViewModel.recovery.readinessScore ?? dashboardViewModel.overallScore.score
            TodaysActionDetailView(
                action: dashboardViewModel.smartDailyAction(liveVM: liveViewModel),
                policyDecision: dashboardViewModel.analysisEngine.mlOrchestrator.policyDecision,
                readinessScore: readinessScore,
                workoutRecoveryBand: WorkoutRecoveryBand(score: readinessScore),
                cyclePhase: dashboardViewModel.menstrualCycleTracker.currentCycle?.currentPhase.workoutModifier,
                onTapMetric: { metric in navigationPath.append(metric) }
            )
        case .askYourData:
            AskYourDataView(viewModel: dashboardViewModel)
        }
    }

    @ViewBuilder
    private var strainDetailDestination: some View {
        let scorer = dashboardViewModel.strainScorer
        let coach = dashboardViewModel.strainCoach
        let target = coach.currentTarget
        let readinessScore = liveViewModel.recovery.readinessScore ?? dashboardViewModel.overallScore.score
        let workoutRecoveryBand = WorkoutRecoveryBand(score: readinessScore)
        let cyclePhase = dashboardViewModel.menstrualCycleTracker.currentCycle?.currentPhase.workoutModifier
        let balance: StrainBalance = {
            switch coach.strainBalance {
            case .undertraining: return .under
            case .optimal: return .optimal
            case .overreaching: return .overreaching
            }
        }()
        StrainDetailView(
            strainValue: scorer.currentStrain,
            strainLevel: scorer.strainLevel,
            zoneMinutes: scorer.zoneMinutes,
            targetStrainRange: (target?.minStrain ?? 10)...(target?.maxStrain ?? 14),
            trainingZone: target?.zone.displayName ?? "Maintain Fitness",
            guidanceText: target?.guidance ?? "Stay active and listen to your body",
            weekHistory: scorer.weeklyStrainHistory.map {
                DailyStrainPoint(date: $0.date, strain: $0.strain, level: StrainLevel(strain: $0.strain))
            },
            strainBalance: balance,
            workoutRecoveryBand: workoutRecoveryBand,
            cyclePhase: cyclePhase
        )
    }

    @ViewBuilder
    private var stressMonitorDestination: some View {
        if let stress = dashboardViewModel.stressScorer.currentStress {
            let history = dashboardViewModel.stressScorer.dailyStressHistory
            let weekScores = history.suffix(7).map {
                DailyStressPoint(dayLabel: $0.date.formatted(.dateTime.weekday(.abbreviated)), score: $0.score)
            }
            let prevWeek = history.count > 7 ? Array(history.dropLast(7).suffix(7)) : [(date: Date, score: Double)]()
            let prevAvg = prevWeek.isEmpty
                ? (dashboardViewModel.stressScorer.weeklyAverage ?? 0)
                : prevWeek.map(\.score).reduce(0, +) / Double(prevWeek.count)
            StressMonitorView(
                stressScore: stress.score,
                stressLevel: stress.level.displayName,
                levelColor: stress.level.color,
                hrvDeviation: stress.hrvDeviation,
                hrElevation: stress.hrElevation,
                weeklyScores: weekScores,
                weeklyAverage: dashboardViewModel.stressScorer.weeklyAverage ?? 0,
                previousWeekAverage: prevAvg
            )
        }
    }

    @ViewBuilder
    private var brainHealthDestination: some View {
        if let brain = dashboardViewModel.brainHealthScorer.currentScore {
            BrainHealthDetailView(
                brainScore: brain,
                weeklyHistory: dashboardViewModel.brainHealthScorer.weeklyHistory,
                weeklyAverage: dashboardViewModel.brainHealthScorer.weeklyAverage,
                trend: dashboardViewModel.brainHealthScorer.brainHealthTrend
            )
        }
    }

    @ViewBuilder
    private var sleepCoachDestination: some View {
        if let need = dashboardViewModel.sleepNeedCalculator.currentNeed {
            let debt = dashboardViewModel.sleepDebtTracker.currentDebt
            let baseline = debt?.personalBaseline ?? need.totalHoursNeeded
            let dailyHistory = (debt?.dailyDeficits ?? []).suffix(7).map { entry in
                SleepCoachView.DayEntry(date: entry.date, actual: max(0, baseline - entry.deficit), needed: baseline)
            }
            SleepCoachView(
                baseHoursNeeded: need.totalHoursNeeded,
                bedtime: need.recommendedBedtime.map { $0.formatted(date: .omitted, time: .shortened) },
                wakeTime: need.recommendedWakeTime.map { $0.formatted(date: .omitted, time: .shortened) },
                debtHours: debt?.totalDebtHours ?? 0,
                dailyHistory: dailyHistory,
                consistencyScore: Int(dashboardViewModel.sleepNeedCalculator.sleepConsistencyScore)
            )
        }
    }

    @ViewBuilder
    private var cycleDetailDestination: some View {
        if let cycle = dashboardViewModel.menstrualCycleTracker.currentCycle {
            let trackerPhase = cycle.currentPhase
            let phaseDuration = trackerPhase.dayRange.count
            let dayInPhase = max(1, cycle.dayInCycle - trackerPhase.dayRange.lowerBound + 1)
            // Convert MenstrualCycleTracker.CyclePhase → CycleDetailView's CyclePhase
            let viewPhase: CyclePhase = {
                switch trackerPhase {
                case .menstrual: return .menstrual
                case .follicular: return .follicular
                case .ovulation: return .ovulatory
                case .luteal: return .luteal
                }
            }()
            CycleDetailView(
                currentPhase: viewPhase,
                dayInCycle: cycle.dayInCycle,
                cycleLength: cycle.cycleLength,
                daysUntilPeriod: cycle.daysUntilNextPeriod ?? 0,
                dayInPhase: dayInPhase,
                phaseDuration: phaseDuration,
                cycleHistory: dashboardViewModel.menstrualCycleTracker.cycleHistory.map {
                    CycleHistoryEntry(startDate: $0.startDate, length: $0.length)
                },
                nextPeriodDate: cycle.nextPeriodEstimate
            )
        }
    }

    @ViewBuilder
    private var achievementsDestination: some View {
        let engine = dashboardViewModel.gamificationEngine
        let streaks = engine.streaks
        let achievementItems: [AchievementItem] = engine.achievements.map { a in
            let cat: AchievementItem.AchievementCategory = {
                switch a.category {
                case .streak: return .streak
                case .milestone: return .milestone
                case .record: return .milestone
                case .consistency: return .consistency
                }
            }()
            return AchievementItem(
                id: a.id, title: a.title, description: a.description,
                icon: a.icon, requirement: a.description, category: cat,
                unlockDate: a.unlockedDate
            )
        }
        AchievementsView(
            levelInfo: LevelInfo.from(daysTracked: engine.totalDaysTracked),
            streaks: [
                StreakInfo(id: "activity", name: "Activity", icon: "figure.run", current: streaks.activityStreak, best: streaks.longestActivityStreak),
                StreakInfo(id: "sleep", name: "Sleep", icon: "moon.fill", current: streaks.sleepStreak, best: streaks.longestSleepStreak),
                StreakInfo(id: "recovery", name: "Recovery", icon: "heart.fill", current: streaks.recoveryStreak, best: streaks.longestRecoveryStreak),
                StreakInfo(id: "checkIn", name: "Check-In", icon: "checkmark.circle.fill", current: streaks.checkInStreak, best: streaks.longestCheckInStreak),
                StreakInfo(id: "master", name: "Master", icon: "crown.fill", current: streaks.masterStreak, best: streaks.longestMasterStreak),
            ],
            achievements: achievementItems,
            stats: AchievementsStats(
                totalDaysTracked: engine.totalDaysTracked,
                totalUnlocked: engine.achievements.filter(\.isUnlocked).count,
                totalAchievements: engine.achievements.count,
                longestStreakEver: max(streaks.longestActivityStreak, streaks.longestSleepStreak, streaks.longestRecoveryStreak, streaks.longestCheckInStreak, streaks.longestMasterStreak)
            )
        )
    }

    // MARK: - Session Analytics

    private func startSessionAnalytics() {
        let analytics = AppAnalytics.shared
        analytics.trackSessionStart()
        analytics.trackDailyActiveUser()
        analytics.trackReturnSession()
        analytics.trackRetentionMilestones()
        analytics.trackInactivityIfNeeded()

        // Push re-engagement notification 3 days into the future on every session.
        // If the user keeps opening the app, this never fires.
        ReengagementScheduler.reschedule()
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

                if let url = URL(string: AppSecrets.URLs.manageSubscriptions) {
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
    ContentView(container: AppContainer())
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
