import SwiftUI
import Network
import Observation

/// Root view with custom three-tab navigation and NavigationStack
struct ContentView: View {
    let container: AppContainer

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showNotificationReprompt = false
    @State private var showHealthKitReprompt = false
    /// One sheet slot for the whole root view. Two `.sheet` modifiers stacked on
    /// the same view lets SwiftUI honour only one of them, and the losing one can
    /// still present its container with no content — an empty card with no Skip
    /// button and no drag gesture, which the user can only escape by force-quit.
    @State private var rootSheet: RootSheet?
    @State private var navigationPath = NavigationPath()
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var connectivityMonitor = ConnectivityMonitor.shared

    @State private var dashboardViewModel: DashboardViewModel
    @State private var liveViewModel: LiveViewModel
    @State private var webExportViewModel: WebExportViewModel

    init(container: AppContainer) {
        self.container = container
        _dashboardViewModel = State(wrappedValue: container.dashboardViewModel)
        _liveViewModel = State(wrappedValue: container.liveViewModel)
        _webExportViewModel = State(wrappedValue: container.webExportViewModel)

        // App Store screenshot pre-positioning: if a launch flag asks to land on
        // a specific tab, honor it before the first render so the screenshot is
        // captured on that tab without tap navigation.
        if UITestMode.isEnabled, let tab = UITestMode.initialTab.flatMap(AppTab.init(rawValue:)) {
            _selectedTab = State(initialValue: tab)
        }
    }

    /// The sheets the root view can present, so they share a single `.sheet`.
    private enum RootSheet: Identifiable {
        case pmfSurvey
        case journalEntry
        /// Templates are captured at presentation time: the live scorers keep
        /// moving behind the sheet, and a card must not change under the user
        /// while they are choosing which one to post.
        case shareWin([ShareTemplate])
        case renewalReminder(RenewalReminderStore.Reminder)

        var id: String {
            switch self {
            case .pmfSurvey:        return "pmfSurvey"
            case .journalEntry:     return "journalEntry"
            case .shareWin:         return "shareWin"
            case .renewalReminder:  return "renewalReminder"
            }
        }
    }

    var body: some View {
        // Journal views write through `@Environment(\.modelContext)`. Without this
        // the environment hands them a container that is not the one
        // `HealthDataStore` owns, so a journal entry written from the wrist would
        // land in a different store than the one the Journal screen reads.
        if let modelContainer = container.healthDataStore.modelContainer {
            mainApp.modelContainer(modelContainer)
        } else {
            mainApp
        }
    }

    private var healthKitManager: HealthKitManager { container.healthKitManager }
    private var analysisEngine: AnalysisEngine { container.analysisEngine }
    private var deviceSourceManager: DeviceSourceManager { container.deviceSourceManager }
    private var healthDataStore: HealthDataStore { container.healthDataStore }
    private var appStateStore: AppStateStore { container.appStateStore }
    private var subscriptionManager: SubscriptionManager { container.subscriptionManager }

    private var mainApp: some View {
        tabsRoot
        .overlay(alignment: .top) {
            // Show at most one reprompt banner at a time.
            // Notification reprompt takes priority since the user explicitly denied it.
            if showNotificationReprompt {
                NotificationRepromptBanner(isPresented: $showNotificationReprompt)
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.4), value: showNotificationReprompt)
            } else if showHealthKitReprompt {
                HealthKitRepromptBanner(isPresented: $showHealthKitReprompt)
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.4), value: showHealthKitReprompt)
            }
        }
        .sheet(item: $rootSheet) { sheet in
            switch sheet {
            case .pmfSurvey:                    PMFSurveySheet()
            case .journalEntry:                 JournalEntryView()
            case .shareWin(let templates):      ShareWinSheet(templates: templates)
            case .renewalReminder(let reminder): RenewalReminderSheet(reminder: reminder)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            presentShareCardForScreenshot()
        }
        .task(id: appStateStore.onboardingCompleted) {
            guard appStateStore.onboardingCompleted else { return }

            // Notification permission fallback: the onboarding prompt only fires
            // inside the Apple Sign-In success branch, so users who completed
            // onboarding via any other path land here in `.notDetermined` and
            // never receive notifications. Trigger the system prompt once.
            // iOS no-ops this call when status is already `.authorized`/`.denied`.
            // Runs BEFORE the initial load: housekeeping inside `load()` arms
            // the daily/evening summaries, and doing that with the permission
            // still undetermined would silently skip the user's first day.
            // Skip during UI-test screenshot capture: the system permission
            // alert would otherwise overlay every main-app screen we capture.
            if !UITestMode.isEnabled,
               await NotificationManager.shared.shouldRequestAuthorizationOnLaunch() {
                _ = await NotificationManager.shared.requestAuthorization(source: "launch_fallback")
            }

            if appStateStore.pendingCalibrationHydration && healthKitManager.lastRefresh != nil {
                dashboardViewModel.hydrateFromCalibration()
                appStateStore.setPendingCalibrationHydration(false)
            } else {
                // First cold launch (or any cold launch where the in-memory
                // scorers are still empty): force the heavy, non-debounced
                // calibration so VitalityScorer / StrainScorer / SleepNeed see
                // the full HealthKit pull before any detail screen reads them.
                // The default `load()` goes through the 500ms debounced path,
                // which makes detail screens read empty scorers and render
                // "Building your profile" / "No workout data yet" even when
                // years of watch history exist on disk.
                let needsFullCalibration = dashboardViewModel.lastRefresh == nil
                    || healthKitManager.timeSeries.isEmpty
                await dashboardViewModel.load(
                    awaitDeferredAnalysis: needsFullCalibration,
                    forceHeavyDeferred: needsFullCalibration
                )
            }
            await refreshDeviceSourcesIfNeeded()
            // HomeView.onAppear handles its own initial fetch. no duplicate needed here

            // Belt-and-suspenders: wire up HKObserverQueries for core dashboard
            // metrics so when Apple Watch delivers new HealthKit data in the
            // background, the dashboard auto-refreshes without pull-to-refresh.
            // `refreshOnForegroundIfNeeded` is already throttled + idempotent.
            healthKitManager.setupDashboardObservers { [weak dashboardViewModel] in
                await dashboardViewModel?.refreshOnForegroundIfNeeded()
            }

            // After initial load, check if HealthKit data is empty despite authorization
            let shouldShowHKReprompt = HealthKitRepromptManager.checkEmptyData(
                isAuthorized: healthKitManager.isAuthorized,
                timeSeriesCount: healthKitManager.timeSeries.count
            )
            if shouldShowHKReprompt {
                showHealthKitReprompt = true
            }

            // Deliberately at the end of this task, not in `onAppear`: setting a
            // sheet flag from `onAppear` fires the presentation inside the app's
            // first layout pass, before the root view controller is settled in the
            // window, and UIKit can then install the sheet with no content. By
            // here the initial load has already awaited real work, so the window
            // is up. Also skipped while a blocking fullScreenCover (disclaimer,
            // trial-expired paywall) owns the screen — a sheet cannot present over
            // one, and the failed attempt is what strands an empty card.
            // Mirrors LasoApp's own paywall condition, not just `shouldEnforcePaywall`:
            // a free-year user is expired at StoreKit but has full access, so no
            // cover is up and the survey is free to show.
            let paywallOwnsScreen = subscriptionManager.shouldEnforcePaywall && !FeatureGate.hasFullAccess
            guard appStateStore.disclaimerAcknowledged, !paywallOwnsScreen else { return }

            // Billing before feedback: this is the only sheet the user loses money
            // by missing, so it takes the single sheet slot ahead of the survey.
            // Once per day through the window, which is why the day is stamped
            // here rather than when the sheet closes — a force-quit before reading
            // it must not re-raise it on the next launch the same day.
            if let reminder = RenewalReminderStore.reminder(for: subscriptionManager) {
                RenewalReminderStore.markShownToday()
                rootSheet = .renewalReminder(reminder)
                return
            }

            if PMFSurveyManager.shared.shouldShowSurvey() {
                rootSheet = .pmfSurvey
            }
        }
        .onAppear {
            startSessionAnalytics()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                startSessionAnalytics()
                WatchMonitor.shared.evaluateWatchStatus()
                // A flaky-network launch can leave the whole session on baked-in
                // defaults; retry until the first fetch ever succeeds.
                if RemoteConfigManager.shared.lastFetchTime == nil {
                    Task { await RemoteConfigManager.shared.fetchAndActivate() }
                }
                // Reset the dismiss-without-open fatigue streak on every active
                // return, and confirm which scheduled notifications actually
                // landed so the delivery funnel is accurate.
                NotificationManager.shared.recordAppOpen()
                Task { await NotificationManager.shared.store?.reconcileDeliveredNotifications() }
                // Navigate to any route staged by a remote-push tap.
                if let route = NotificationRouter.shared.consumePending() {
                    navigate(to: route)
                }
                Task { await refreshDeviceSourcesIfNeeded() }
                // Consume any pending Live Activity action so we can attribute the
                // tap-through funnel (PMF) and eventually route the user to the
                // relevant surface (breathwork, intention, etc).
                if let pending = CoachActionBridge.consumePending() {
                    AppAnalytics.shared.trackLiveActivityAction(
                        kind: pending.source ?? "unknown",
                        actionKind: pending.kind.rawValue
                    )
                    // The expanded island buttons open the app but only logged before;
                    // route to the matching surface so the CTA is not a dead end.
                    switch pending.kind {
                    case .setIntention: navigate(to: .todaysAction)
                    case .breathe:      navigate(to: .stressMonitor)
                    case .windDown:     navigate(to: .sleepCoach)
                    case .noop:         break
                    }
                }
                Task {
                    if await NotificationRepromptManager.checkAndRecordDenial() {
                        showNotificationReprompt = true
                    }
                }
                // Check for HealthKit empty-data state (user authorized but toggled off all categories)
                if dashboardViewModel.ui.hasCompletedInitialLoad {
                    let shouldShow = HealthKitRepromptManager.checkEmptyData(
                        isAuthorized: healthKitManager.isAuthorized,
                        timeSeriesCount: healthKitManager.timeSeries.count
                    )
                    if shouldShow {
                        showHealthKitReprompt = true
                    } else {
                        showHealthKitReprompt = false
                    }
                }
                // A background relaunch cannot obtain HealthKit permission, so the
                // initial load can fail before the user ever sees the app. `.task`
                // does not re-run on a foreground return, so retry it here instead
                // of parking on the error screen until a manual tap.
                if appStateStore.onboardingCompleted,
                   !dashboardViewModel.ui.hasCompletedInitialLoad,
                   !dashboardViewModel.ui.isLoading {
                    Task { await dashboardViewModel.load() }
                }
                if selectedTab == .home {
                    // HomeView's own onChange(scenePhase) handles fetchHomeData. no duplicate needed here
                    // Retry sync only when Home is visible and potentially stuck.
                    Task { await dashboardViewModel.retrySyncIfNeeded() }
                }
                // Foreground return: refresh dashboard so users see today's latest data
                // without pull-to-refresh. Fires on any active-return (background, inactive,
                // notification banner dismiss, Control Center close). Throttled internally.
                Task { await dashboardViewModel.refreshOnForegroundIfNeeded() }
            } else if newPhase == .background {
                AppAnalytics.shared.trackAppBackgrounded()
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
            case .settings: .tabSettings
            }
            // The tap happened on the tab the user is LEAVING. Hardcoding .home
            // put every Settings→Live switch on Home, and trackBlockTap derives
            // element_id/action_id from this value too.
            let fromScreen: AppFeature = oldTab.feature
            AppAnalytics.shared.trackBlockTap(
                title: newTab.rawValue.capitalized,
                type: blockType,
                screen: fromScreen,
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
        .onChange(of: homePath.count) { _, newCount in
            AppAnalytics.shared.updateNavigationDepth(newCount)
        }
        .onChange(of: explorePath.count) { _, newCount in
            AppAnalytics.shared.updateNavigationDepth(newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .healthPulseNavigateToExplore)) { _ in
            selectedTab = .explore
        }
        .onChange(of: NotificationRouter.shared.pendingRoute) { _, newRoute in
            // Push taps arriving while the app is already foregrounded set the
            // pending route without a scenePhase transition; consume it here.
            guard newRoute != nil, let route = NotificationRouter.shared.consumePending() else { return }
            navigate(to: route)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .task(id: appStateStore.onboardingCompleted) {
            // Push the requested deep-link route once the dashboard has had a
            // moment to load mock data so the destination view renders with
            // populated values. UI-test-only.
            guard UITestMode.isEnabled,
                  appStateStore.onboardingCompleted,
                  let raw = UITestMode.initialRoute,
                  let route = Route.fromUITestIdentifier(raw) else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            navigate(to: route)
        }
    }

    @ViewBuilder
    private var tabsRoot: some View {
        if #available(iOS 26.0, *) {
            liquidGlassTabs
        } else {
            legacyNavStack
        }
    }

    @available(iOS 26.0, *)
    private var liquidGlassTabs: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.label, systemImage: AppTab.home.systemImageName, value: AppTab.home) {
                NavigationStack(path: $homePath) {
                    withNavigationDestinations(homeTabView(path: $homePath), path: $homePath)
                }
            }
            Tab(AppTab.live.label, systemImage: AppTab.live.systemImageName, value: AppTab.live) {
                NavigationStack {
                    liveTabView
                }
            }
            Tab(AppTab.explore.label, systemImage: AppTab.explore.systemImageName, value: AppTab.explore) {
                NavigationStack(path: $explorePath) {
                    withNavigationDestinations(exploreTabView(path: $explorePath), path: $explorePath)
                }
            }
            Tab(AppTab.settings.label, systemImage: AppTab.settings.systemImageName, value: AppTab.settings) {
                NavigationStack {
                    settingsTabView
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            billingGraceBanner
        }
    }

    private var legacyNavStack: some View {
        NavigationStack(path: $navigationPath) {
            withNavigationDestinations(tabContent, path: $navigationPath)
                .safeAreaInset(edge: .top, spacing: 0) {
                    billingGraceBanner
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    CustomTabBar(selectedTab: $selectedTab)
                }
        }
    }

    @ViewBuilder
    private func withNavigationDestinations<V: View>(_ content: V, path: Binding<NavigationPath>) -> some View {
        content
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
                    HealthRiskDetailView(
                        risk: risk,
                        onTapMetric: { metric in path.wrappedValue.append(metric) },
                        onRefresh: { await dashboardViewModel.refresh() }
                    )
                } else {
                    ContentUnavailableView(
                        Copy.Common.riskDataUnavailableTitle,
                        systemImage: "heart.text.clipboard",
                        description: Text(Copy.Common.thisHealthRiskAssessmentIsNo)
                    )
                }
            }
            .navigationDestination(for: Route.self) { route in
                routeDestination(for: route)
            }
    }

    @ViewBuilder
    private func homeTabView(path: Binding<NavigationPath>) -> some View {
        HomeView(
            viewModel: dashboardViewModel,
            liveViewModel: liveViewModel,
            deviceSourceManager: deviceSourceManager,
            appStateStore: appStateStore,
            navigationPath: path
        )
    }

    @ViewBuilder
    private var settingsTabView: some View {
        SettingsView(
            persistence: container.persistenceManager,
            webExportViewModel: webExportViewModel,
            deviceSourceManager: deviceSourceManager,
            healthKitManager: healthKitManager,
            healthDataStore: healthDataStore
        )
    }

    @ViewBuilder
    private func exploreTabView(path: Binding<NavigationPath>) -> some View {
        ExploreView(
            viewModel: dashboardViewModel,
            appStateStore: appStateStore,
            navigationPath: path
        )
    }

    @ViewBuilder
    private var liveTabView: some View {
        if !UITestMode.isEnabled && RemoteConfigManager.shared.killLiveTab {
            MaintenanceView(message: "Live monitoring is temporarily unavailable. We're working on a fix.")
        } else if UITestMode.isEnabled && UITestMode.forceProLock {
            ProFeatureOverlay(
                feature: "Live Vitals",
                icon: "waveform.path.ecg",
                description: "Monitor your heart rate, SpO2, activity rings, and readiness in real time."
            )
        } else if FeatureGate.canAccess(.liveTab) {
            LiveView(
                viewModel: liveViewModel,
                deviceSourceManager: deviceSourceManager
            )
        } else {
            ProFeatureOverlay(
                feature: "Live Vitals",
                icon: "waveform.path.ecg",
                description: "Monitor your heart rate, SpO2, activity rings, and readiness in real time."
            )
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
            homeTabView(path: $navigationPath)
        case .live:
            liveTabView
        case .explore:
            exploreTabView(path: $navigationPath)
        case .settings:
            settingsTabView
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
            // `navigate(to:)` diverts this route to a sheet before it can reach a
            // path, so this branch only exists to keep the switch exhaustive.
            JournalEntryView()
        case .todaysAction:
            let readinessScore = liveViewModel.recovery.readinessScore ?? dashboardViewModel.overallScore.score
            TodaysActionDetailView(
                action: dashboardViewModel.smartDailyAction(liveVM: liveViewModel),
                policyDecision: dashboardViewModel.analysisEngine.mlOrchestrator.policyDecision,
                readinessScore: readinessScore,
                workoutRecoveryBand: WorkoutRecoveryBand(score: readinessScore),
                cyclePhase: dashboardViewModel.menstrualCycleTracker.currentCycle?.currentPhase.workoutModifier,
                topCausalChain: dashboardViewModel.analysis.topCausalChain,
                recoverySignals: dashboardViewModel.todayRecoverySignals(liveVM: liveViewModel),
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
            trendPoints: scorer.trendStrainHistory.map {
                TrendSparkPoint(date: $0.date, value: $0.strain)
            }
        )
    }

    @ViewBuilder
    private var stressMonitorDestination: some View {
        if let stress = dashboardViewModel.stressScorer.currentStress {
            let history = dashboardViewModel.stressScorer.dailyStressHistory
            let weekScores = history.suffix(7).map {
                DailyStressPoint(date: $0.date,
                                 dayLabel: $0.date.formatted(.dateTime.weekday(.abbreviated)),
                                 score: $0.score)
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
                previousWeekAverage: prevAvg,
                trendPoints: history.map { TrendSparkPoint(date: $0.date, value: $0.score) }
            )
        } else {
            ContentUnavailableView(
                Copy.StressMonitor.buildingBaselineTitle,
                systemImage: "waveform.path.ecg",
                description: Text(Copy.StressMonitor.needHRVData)
            )
            .navigationTitle(Copy.StressMonitor.title)
        }
    }

    @ViewBuilder
    private var brainHealthDestination: some View {
        if let brain = dashboardViewModel.brainHealthScorer.currentScore {
            BrainHealthDetailView(
                brainScore: brain,
                weeklyHistory: dashboardViewModel.brainHealthScorer.weeklyHistory,
                weeklyAverage: dashboardViewModel.brainHealthScorer.weeklyAverage,
                trend: dashboardViewModel.brainHealthScorer.brainHealthTrend,
                trendPoints: dashboardViewModel.brainHealthScorer.weeklyHistory.map {
                    TrendSparkPoint(date: $0.date, value: Double($0.score))
                }
            )
        } else {
            ContentUnavailableView(
                Copy.BrainHealth.emptyStateTitle,
                systemImage: "brain",
                description: Text(Copy.BrainHealth.emptyStateMessage)
            )
            .navigationTitle(Copy.BrainHealth.title)
        }
    }

    @ViewBuilder
    private var sleepCoachDestination: some View {
        if let need = dashboardViewModel.sleepNeedCalculator.currentNeed {
            let debt = dashboardViewModel.sleepDebtTracker.currentDebt
            let baseline = debt?.personalBaseline ?? need.totalHoursNeeded
            let boundaries = healthKitManager.sleepSessionBoundaries
            let napsByDay = healthKitManager.napSessionBoundaries
            let dailyHistory = (debt?.dailyDeficits ?? []).suffix(14).map { entry in
                let boundary = boundaries[entry.date]
                let napTotalMin = (napsByDay[entry.date] ?? []).reduce(0.0) {
                    $0 + ($1.coreHours + $1.deepHours + $1.remHours) * 60.0
                }
                return SleepCoachView.DayEntry(
                    date: entry.date,
                    actual: max(0, baseline - entry.deficit),
                    needed: baseline,
                    bedtime: boundary?.bedtime,
                    wakeTime: boundary?.wakeTime,
                    coreHours: boundary?.coreHours,
                    deepHours: boundary?.deepHours,
                    remHours: boundary?.remHours,
                    awakeHours: boundary?.awakeHours,
                    napMinutes: napTotalMin >= 1 ? Int(napTotalMin.rounded()) : nil
                )
            }
            SleepCoachView(
                baseHoursNeeded: need.totalHoursNeeded,
                bedtime: need.recommendedBedtime,
                wakeTime: need.recommendedWakeTime,
                debtHours: debt?.totalDebtHours ?? 0,
                dailyHistory: dailyHistory,
                // Live overnight wake times, not stored sample dates: the
                // boundary query excludes naps and is re-run on open, so a
                // corrected night shows the corrected wake time.
                wakeTimes: boundaries.values.map(\.wakeTime),
                onRefresh: { await dashboardViewModel.refresh() }
            )
            .task {
                // Covers both consumers: the 14-day history section and the
                // wake window's 28-night consistency readout.
                await healthKitManager.refreshSleepBoundaries(
                    days: max(14, WakeAnchorConfig.consistencyWindowDays)
                )
            }
        } else {
            sleepCoachEmptyState
        }
    }

    private var sleepCoachEmptyState: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                VStack(spacing: 14) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.secondary)
                        .padding(.top, DS.space5)

                    Text(Copy.Common.buildingYourSleepProfile)
                        .font(DS.Typography.title3.weight(.semibold))

                    Text(Copy.Common.weNeedAFewNightsOf)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.space5)
                        .padding(.bottom, DS.space5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.space5)
                .cardStyle()
                .padding(.horizontal)

                sleepCoachEmptyTipsSection
            }
            .padding(.top, DS.space4)
            .padding(.bottom, DS.space6)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.SleepCoach.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await healthKitManager.refreshSleepBoundaries(days: 14)
        }
    }

    private var sleepCoachEmptyTipsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack(spacing: DS.space2) {
                Image(systemName: "lightbulb.fill")
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.categorySleep)
                Text(Copy.Common.whileYouWait)
                    .font(DS.Typography.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                sleepCoachEmptyTipRow(
                    icon: "clock.fill",
                    color: AppColour.categorySleep,
                    title: Copy.SleepCoach.tipConsistentScheduleTitle,
                    detail: Copy.SleepCoach.tipConsistentScheduleDetail
                )
                Divider().padding(.leading, 44)
                sleepCoachEmptyTipRow(
                    icon: "thermometer.snowflake",
                    color: AppColour.accent,
                    title: Copy.SleepCoach.tipCoolBedroomTitle,
                    detail: Copy.SleepCoach.tipCoolBedroomDetail
                )
                Divider().padding(.leading, 44)
                sleepCoachEmptyTipRow(
                    icon: "sun.max.fill",
                    color: AppColour.warning,
                    title: Copy.SleepCoach.tipMorningSunlightTitle,
                    detail: Copy.SleepCoach.tipMorningSunlightDetail
                )
            }
            .padding(.vertical, DS.space2)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func sleepCoachEmptyTipRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.subheadlineMedium)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space2)
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
                nextPeriodDate: cycle.nextPeriodEstimate,
                onRefresh: { await dashboardViewModel.refresh() }
            )
        } else {
            ContentUnavailableView(
                Copy.CycleTracking.emptyStateTitle,
                systemImage: "drop.fill",
                description: Text(Copy.CycleTracking.emptyStateMessage)
            )
            .navigationTitle(Copy.CycleTracking.title)
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
                id: a.id, title: a.title,
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

    // MARK: - Deep-link Routing

    /// Append a deep-link route onto the navigation path for the active tab,
    /// matching the per-tab NavigationStack bindings (home/explore have their
    /// own paths; live/settings share `navigationPath`).
    private func navigate(to route: Route) {
        // JournalEntryView owns its own NavigationStack. Pushing it into the tab
        // stack nests two stacks, which SwiftUI treats as undefined behavior and
        // pops straight back to the tab root, so present it modally instead.
        guard route != .journalEntry else {
            rootSheet = .journalEntry
            return
        }
        switch selectedTab {
        case .home: homePath.append(route)
        case .explore: explorePath.append(route)
        case .live, .settings: navigationPath.append(route)
        }
    }

    /// Route a `laso://route/<name>` widget deep link. Reuses the single
    /// string→Route map so widget and push routing stay in sync.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "laso", url.host == "route" else { return }
        let name = url.lastPathComponent
        guard let route = Route.fromUITestIdentifier(name) else { return }
        // Widgets and Live Activities are the only laso:// producers. Tag the
        // session before scenePhase-driven trackSessionStart consumes it so
        // these opens stop counting as organic (same pattern as the
        // notification tag in AppDelegate).
        //
        // These three routes are the widgetURLs of the three Live Activities and
        // nothing else links to them, so tagging every laso:// open as "widget"
        // put pure Live Activity traffic in the widget bucket. A home-screen
        // widget that gains a widgetURL lands in the default branch.
        let isLiveActivityRoute = route == .todaysAction || route == .sleepCoach || route == .stressMonitor
        SessionTracker.shared.pendingSessionSource = isLiveActivityRoute ? .liveActivity : .widget
        AppAnalytics.shared.trackDeepLinkOpened(
            url: url.absoluteString,
            source: isLiveActivityRoute ? "live_activity" : "widget"
        )
        navigate(to: route)
    }

    // MARK: - Screenshot Share Offer

    /// A screenshot is the strongest "I would show this to someone" signal the app
    /// gets, so it offers a proper card instead of letting the user post a raw
    /// screen grab. Fires on every screenshot, from any tab, by request.
    ///
    /// Nothing is presented when the user has no earned win to put on a card,
    /// when a blocking fullScreenCover owns the screen, or when any sheet is
    /// already up — that last guard also covers screenshotting the share sheet
    /// itself, which would otherwise re-raise it on top of itself.
    private func presentShareCardForScreenshot() {
        let paywallOwnsScreen = subscriptionManager.shouldEnforcePaywall && !FeatureGate.hasFullAccess
        guard rootSheet == nil,
              appStateStore.onboardingCompleted,
              appStateStore.disclaimerAcknowledged,
              !paywallOwnsScreen else { return }

        let templates = dashboardViewModel.shareTemplates(
            liveVM: liveViewModel,
            actionResult: DailyActionResultStore.resultToShow()
        )
        guard !templates.isEmpty else { return }

        // Entry step of the share funnel, matching Home's own Share CTA, so
        // screenshot-sourced opens are separable from tapped ones.
        AppAnalytics.shared.trackBlockTap(
            title: "Share",
            type: .shareCard,
            screen: selectedTab.feature,
            metadata: ["source": "screenshot", "card_type": "template"]
        )
        rootSheet = .shareWin(templates)
    }

    // MARK: - Session Analytics

    private func startSessionAnalytics() {
        let analytics = AppAnalytics.shared
        // The 30-min idle guard: a quick app-switch resumes the open session and
        // returns false, so the per-session events below do not re-fire and
        // inflate DAU. They only run when a genuinely new session starts.
        guard analytics.trackSessionStart() else { return }
        analytics.trackDailyActiveUser()
        analytics.trackReturnSession()
        analytics.trackRetentionMilestones()
        analytics.trackInactivityIfNeeded()

        // Wellness PMF snapshot — Watch-pair status, data completeness, permissions,
        // composite churn score. Needs async push-auth query so run in a Task.
        Task { await trackHealthSnapshot() }

        // Push re-engagement notification 3 days into the future on every session.
        // If the user keeps opening the app, this never fires.
        ReengagementScheduler.reschedule()

        // Cliffhanger payoff (Journey 4) and denied-branch re-permission
        // (Journey 5) are also evaluated on foreground so a returning user is
        // not left waiting on the next background refresh. Both are cheap
        // one-shot no-ops once fired or when their preconditions are unmet.
        AnswerReadyScheduler.checkAndFire(store: NotificationManager.shared.store)
        RepermissionScheduler.checkAndFire()
    }

    /// Gathers wellness-specific signals (Watch pair, data completeness, permissions)
    /// and emits a `user_health_snapshot` event + user properties so analysts can
    /// segment retention cohorts on the dimensions research calls out as the biggest
    /// levers for consumer health apps.
    private func trackHealthSnapshot() async {
        let watchPaired = deviceSourceManager.isAppleWatchPaired
        let coveredDays = healthKitManager.daysWithAnyDataInLast(days: 7)
        let heartHasData = (healthKitManager.timeSeries[.heartRate]?.samples.isEmpty == false)
        let sleepHasData = (healthKitManager.timeSeries[.sleepDuration]?.samples.isEmpty == false)
        let stepsHasData = (healthKitManager.timeSeries[.steps]?.samples.isEmpty == false)

        let pushAuthorized = await NotificationManager.shared.isCurrentlyAuthorized()

        let prefs = container.persistenceManager.loadPreferences()
        let enabledCount = [
            prefs.dailySummaryEnabled,
            prefs.eveningSummaryEnabled,
            prefs.windDownEnabled,
            prefs.weeklySummaryEnabled,
            prefs.criticalAlertsEnabled,
            prefs.warningAlertsEnabled,
            prefs.heartRateSpikeAlertsEnabled,
            prefs.trendReversalAlertsEnabled,
            prefs.improvementAlertsEnabled,
            prefs.watchNotWornReminderEnabled
        ].filter { $0 }.count

        AppAnalytics.shared.trackUserHealthSnapshot(
            watchPaired: watchPaired,
            dailyCompleteness7d: coveredDays,
            pushAuthorized: pushAuthorized,
            notifCategoriesEnabled: enabledCount,
            hkHeartHasData: heartHasData,
            hkSleepHasData: sleepHasData,
            hkStepsHasData: stepsHasData
        )
    }

    // MARK: - Billing Grace Banner (subtle, non-blocking, only after 16 days)

    @ViewBuilder
    private var billingGraceBanner: some View {
        if let days = subscriptionManager.billingGraceDays, days >= 16 {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(AppColour.warning)

                Text(Copy.Common.updateYourPaymentMethodToKeep)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let url = URL(string: AppSecrets.URLs.manageSubscriptions) {
                    Link("Update", destination: url)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColour.warning)
                        .simultaneousGesture(TapGesture().onEnded {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Update Payment Method",
                                type: .appStoreLink,
                                screen: .home,
                                metadata: [
                                    "destination": "app_store_subscriptions",
                                    "billing_grace_days": days
                                ]
                            )
                        })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassChrome(tinted: AppColour.warning, in: Rectangle())
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
