import SwiftUI
import SwiftData

struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    let appStateStore: AppStateStore
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var thermalManager = ThermalManager.shared
    @State private var homeRefreshTimer = RepeatTimer()
    @State private var readinessRefreshTimer = RepeatTimer()
    @State private var weeklyReviewViewModel: WeeklyReviewViewModel?
    @State private var showScoreGuide = false
    @State private var showRecoveryInfo = false
    @State private var maxScrollDepth: Int = 0
    @State private var showMorningCheckIn = false
    // Section trackers
    @State private var recoveryTracker = SectionTracker(section: .homeRecovery, tab: .home)
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var bodyInsightsTracker = SectionTracker(section: .homeBodyInsights, tab: .home)
    @State private var risksTracker = SectionTracker(section: .homeRisks, tab: .home)
    @State private var weeklyReviewTracker = SectionTracker(section: .homeWeeklyReview, tab: .home)


    var body: some View {
        Group {
            if viewModel.ui.isLoading {
                if viewModel.ui.isFirstLaunchSync {
                    firstLaunchLoadingView
                } else {
                    LoadingView(Copy.Home.analyzingHealthData)
                }
            } else if let error = viewModel.ui.errorMessage {
                errorView(error)
            } else {
                homeContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.home")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.ui.showDiscovery },
            set: { if !$0 { viewModel.dismissDiscovery() } }
        )) {
            DiscoveryView(
                discoveries: viewModel.ui.discoveries,
                dataDepth: viewModel.analysis.dataDepth,
                onDismiss: { viewModel.dismissDiscovery() }
            )
        }
        .sheet(isPresented: $showScoreGuide) {
            ScoreGuideSheet(
                score: viewModel.overallScore.score,
                weakestCategoryName: weakestCategoryName,
                appStateStore: appStateStore
            )
        }
        .sheet(isPresented: $showRecoveryInfo) {
            RecoveryInfoSheet(score: liveReadinessScore)
        }
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .home)
            AppAnalytics.shared.trackActivationMilestone(.firstPullToRefresh)
            AppAnalytics.shared.trackCoreAction(.pulledToRefresh, screen: .home)
            await viewModel.refresh()
            liveViewModel.fetchHomeData()
            rebuildMetricTilesFromLive()
        }
        .sensoryFeedback(.success, trigger: viewModel.lastRefresh)
        .onChange(of: viewModel.lastRefresh) { _, _ in
            rebuildMetricTilesFromLive()
        }
        .onAppear {
            ensureWeeklyReviewVM()
            startHomeRefresh()
            startReadinessRefresh()
            rebuildMetricTilesFromLive()
            showMorningCheckIn = MorningCheckInManager.shouldShowCheckIn()
            if let checkIn = MorningCheckInManager.todaysCheckIn() {
                viewModel.subjectiveReadinessAdjustment = checkIn.readinessAdjustment
            }
            AppAnalytics.shared.trackFeatureOpen(.home)
        }
        .onDisappear {
            stopHomeRefresh()
            stopReadinessRefresh()
            stopFirstLaunchDotTimer()
            if maxScrollDepth > 0 {
                AppAnalytics.shared.trackScrollDepth(screen: .home, maxDepthPercent: maxScrollDepth)
            }
            AppAnalytics.shared.trackFeatureClose(.home)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                startHomeRefresh()
                startReadinessRefresh()
                // Only force an immediate fetch after true background return.
                if oldPhase == .background {
                    liveViewModel.fetchHomeDataTiered()
                }
            } else {
                stopHomeRefresh()
                stopReadinessRefresh()
                stopFirstLaunchDotTimer()
            }
        }
        .onChange(of: thermalManager.currentState) { _, _ in
            guard scenePhase == .active else { return }
            startHomeRefresh()
            startReadinessRefresh()
        }
    }

    /// Periodically refresh home data. uses tiered polling to minimize HealthKit queries.
    /// Fast-changing data (steps, calories) every 60s; slow-changing (sleep, workout) every 10min.
    /// If timeSeries is empty (bad initial sync), retries the full sync instead of lightweight fetches.
    private func startHomeRefresh() {
        homeRefreshTimer.stop()

        let requestedInterval = TimeInterval(RemoteConfigManager.shared.homeRefreshIntervalSeconds)
        guard let interval = thermalManager.homeRefreshInterval(for: requestedInterval) else { return }

        homeRefreshTimer.start(interval: interval, tolerance: min(60, interval * 0.25)) {
            if viewModel.needsSyncRetry {
                Task { await viewModel.retrySyncIfNeeded() }
            } else {
                liveViewModel.fetchHomeDataTiered()
            }
        }
    }

    private func stopHomeRefresh() {
        homeRefreshTimer.stop()
    }

    // MARK: - Live Readiness Score (30-minute refresh)

    /// Live readiness score. falls back to daily score when no readiness data is available
    private var liveReadinessScore: Int {
        liveViewModel.recovery.readinessScore ?? viewModel.overallScore.score
    }

    /// Whether we have a real live readiness score (not a fallback)
    private var hasLiveReadiness: Bool {
        liveViewModel.recovery.readinessScore != nil
    }

    /// Name of the lowest-scoring category for personalized score explanation.
    /// Cached in DashboardViewModel.updateCachedProperties() to avoid recomputing on every render.
    private var weakestCategoryName: String? {
        viewModel.cachedWeakestCategoryName
    }

    private func startReadinessRefresh() {
        readinessRefreshTimer.stop()
        guard let interval = thermalManager.liveReadinessRefreshInterval else { return }

        readinessRefreshTimer.start(interval: interval, tolerance: min(120, interval * 0.2)) {
            liveViewModel.fetchHomeDataTiered()
        }
    }

    private func stopReadinessRefresh() {
        readinessRefreshTimer.stop()
    }

    /// Ensure the WeeklyReviewViewModel is created before the body needs it.
    private func ensureWeeklyReviewVM() {
        if weeklyReviewViewModel == nil {
            weeklyReviewViewModel = WeeklyReviewViewModel(dashboardViewModel: viewModel)
        }
    }

    /// Rebuild cached metric tiles, passing current live sleep data to the viewModel.
    private func rebuildMetricTilesFromLive() {
        viewModel.rebuildMetricTiles(
            hasSleepData: liveViewModel.sleep.hasSleepData,
            lastNightSleepDuration: liveViewModel.sleep.lastNightSleepDuration,
            sleepQualityLabel: liveViewModel.sleep.sleepQualityLabel
        )
    }

    private var hasData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    /// Only show the "Connect Your Health Data" empty state after the initial load
    /// has completed AND there is genuinely no data. This prevents the empty state
    /// from flashing during startup before HealthKit data has been loaded.
    private var shouldShowEmptyState: Bool {
        viewModel.ui.hasCompletedInitialLoad && !hasData
    }

    private var homeContent: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                // 1. Greeting header. context-aware with recovery state
                CoachGreetingView(
                    showSettings: $showSettings,
                    streakDays: SessionTracker.shared.streakDays,
                    scoreChangeFromYesterday: viewModel.scores.scoreChangeFromYesterday,
                    currentScore: hasData ? liveReadinessScore : nil,
                    recoveryState: hasData && hasLiveReadiness ? DashboardViewModel.RecoveryState(score: liveReadinessScore) : nil,
                    onTapScoreInfo: { showScoreGuide = true }
                )
                .padding(.top, 12)

                if shouldShowEmptyState {
                    connectHealthView
                } else if hasData {
                    // ── Above the fold ──

                    // 1. Recovery Hero. live readiness score (updates every 30 min)
                    RecoveryHeroCard(
                        score: liveReadinessScore,
                        dailyScore: viewModel.overallScore.score,
                        recoveryLabel: hasLiveReadiness
                            ? HomeView.recoveryLabel(liveReadinessScore)
                            : "Daily Health Score",
                        dayType: DashboardViewModel.RecoveryState(score: liveReadinessScore).dayType,
                        scoreChangeFromLastWeek: viewModel.scores.scoreChangeFromLastWeek,
                        recoveryWhyLine: recoveryWhyLine,
                        hasLiveReadiness: hasLiveReadiness,
                        lastRefresh: viewModel.lastRefresh,
                        onTap: { showRecoveryInfo = true }
                    )
                    .onAppear {
                        recoveryTracker.appeared()
                        maxScrollDepth = max(maxScrollDepth, 10)
                        AppAnalytics.shared.trackScoreViewed(
                            score: liveReadinessScore,
                            previousScore: viewModel.scores.scoreChangeFromYesterday.map { liveReadinessScore - $0 }
                        )
                    }
                    .onDisappear { recoveryTracker.disappeared() }

                    // 1b. Activation Progress (first 8 days. Paper 8)
                    ActivationProgressBanner(
                        state: viewModel.activationState,
                        latestMilestone: viewModel.latestMilestoneEvent,
                        onDismissCelebration: { viewModel.latestMilestoneEvent = nil }
                    )
                    .padding(.top, 4)

                    // 1c. Morning Check-In (Paper 10: Subjective + Objective)
                    if showMorningCheckIn {
                        MorningCheckInView(
                            onComplete: { checkIn in
                                viewModel.applyMorningCheckIn(checkIn)
                                withAnimation { showMorningCheckIn = false }
                            },
                            onDismiss: {
                                withAnimation { showMorningCheckIn = false }
                            }
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 2. Today's Action. single source of truth for what to do
                    primaryActionCard
                        .padding(.top, 8)

                    // 2b. Body Intelligence. non-obvious ML findings
                    TodayBriefingView(cards: viewModel.intelligenceBriefing)
                        .padding(.top, 8)

                    // 2c. Personal Health Forecast (Paper 3: Conformal Prediction)
                    PersonalHealthForecastCard(
                        forecasts: viewModel.healthForecasts,
                        onTapMetric: { metric in
                            AppAnalytics.shared.trackBlockTap(
                                title: metric.displayName,
                                type: .metricRow,
                                screen: .home,
                                metadata: ["source": "forecast_card"]
                            )
                            navigationPath.append(metric)
                        }
                    )
                    .padding(.top, 8)

                    // 2d. Ask Your Data (Papers 1 & 2: PHIA)
                    AskYourDataCard {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Ask Your Data",
                            type: .smartAction,
                            screen: .home,
                            metadata: ["source": "home_card"]
                        )
                        navigationPath.append(Route.askYourData)
                    }
                    .padding(.top, 8)

                    // 3. Compact alert banner (illness + health risks)
                    compactAlertBanner
                        .padding(.top, 8)
                        .onAppear { illnessTracker.appeared(); risksTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 20) }
                        .onDisappear { illnessTracker.disappeared(); risksTracker.disappeared() }

                    // 4. Metric Strip. horizontal scroll replacing 6 vertical cards
                    MetricStripView(tiles: viewModel.cachedMetricTiles) { tile in
                        AppAnalytics.shared.trackBlockTap(
                            title: tile.label,
                            type: .recoveryCard,
                            screen: .home,
                            metadata: ["destination": tile.id]
                        )
                        navigationPath.append(tile.route)
                    }
                    .padding(.top, 12)

                    // 5. Level & Streaks. gamification (Endowed Progress)
                    LevelBadgeCard(
                        level: viewModel.gamificationEngine.currentLevel,
                        totalDaysTracked: viewModel.gamificationEngine.totalDaysTracked,
                        progressToNext: viewModel.gamificationEngine.progressToNextLevel,
                        streaks: viewModel.gamificationEngine.streaks,
                        onTap: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Level Badge",
                                type: .recoveryCard,
                                screen: .home,
                                metadata: ["destination": "achievements"]
                            )
                            navigationPath.append(Route.achievements)
                        }
                    )
                    .padding(.top, 8)

                    // ── Below the fold ──

                    // 6. Body Insights
                    BodyInsightsSection(
                        viewModel: viewModel,
                        liveVM: liveViewModel,
                        onTapMetric: { metric in
                            AppAnalytics.shared.trackBlockTap(
                                title: metric.displayName,
                                type: .metricRow,
                                screen: .home,
                                metadata: [
                                    "metric_id": metric.rawValue,
                                    "metric_category": metric.category.rawValue
                                ]
                            )
                            navigationPath.append(metric)
                        },
                        onTapSeeAll: {
                            navigationPath.append(Route.insightsDetail)
                        }
                    )
                    .padding(.top, 8)
                    .onAppear { bodyInsightsTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 50) }
                    .onDisappear { bodyInsightsTracker.disappeared() }

                    // 7. Weekly Review
                    WeeklyReviewEntryCard(
                        viewModel: weeklyReviewViewModel ?? WeeklyReviewViewModel(dashboardViewModel: viewModel)
                    ) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Weekly Review",
                            type: .weeklyReviewCard,
                            screen: .home,
                            metadata: [
                                "destination": "weekly_review",
                                "score": liveReadinessScore
                            ]
                        )
                        navigationPath.append(Route.weeklyReview)
                    }
                    .padding(.top, 8)
                    .onAppear { weeklyReviewTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
                    .onDisappear { weeklyReviewTracker.disappeared() }

                    // Last updated footer
                    if let lastRefresh = viewModel.lastRefresh {
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State. Waiting For First Sync

    private var connectHealthView: some View {
        HomeConnectHealthView(
            deviceSourceManager: deviceSourceManager,
            healthKitManager: viewModel.healthKitManager
        ) {
            await viewModel.refresh()
            liveViewModel.fetchHomeData()
        }
    }

    // MARK: - Pro Feature Teaser

    private func proTeaser(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
        .onTapGesture {
            AppAnalytics.shared.trackPremiumFeatureAttempted(feature: title, screen: .home)
        }
    }

    // MARK: - Compact Alert Banner (illness + health risks merged)

    @ViewBuilder
    private var compactAlertBanner: some View {
        let warning = viewModel.analysis.topIllnessWarning
        let risks = viewModel.analysis.todayHealthRisks

        if warning != nil || !risks.isEmpty {
            VStack(spacing: 6) {
                if let warning {
                    Button {
                        navigationPath.append(Route.insightsDetail)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Copy.Home.earlyWarning)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red)
                                Text(warning.narrative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(warning.severity == .critical ? Copy.Home.severityHigh : warning.severity == .warning ? Copy.Home.severityModerate : Copy.Home.severityLow)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(warning.severity == .critical ? .red : warning.severity == .warning ? .orange : .yellow, in: Capsule())

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                ForEach(risks.prefix(2)) { risk in
                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: risk.riskType.displayName,
                            type: .homeRiskRow,
                            screen: .home,
                            metadata: [
                                "risk_id": risk.riskType.rawValue,
                                "risk_grade": risk.riskGrade.rawValue
                            ]
                        )
                        risksTracker.tapped(target: risk.riskType.rawValue)
                        navigationPath.append(risk.riskType)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: risk.riskType.systemImageName)
                                .font(.subheadline)
                                .foregroundStyle(risk.riskGrade.color)
                                .frame(width: 28, height: 28)
                                .background(risk.riskGrade.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                            Text(risk.riskType.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(risk.riskGrade.displayName)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(risk.riskGrade.color)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(risk.riskGrade.color.opacity(DS.strokeAlpha), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Today's Action Card (single source of truth)

    @ViewBuilder
    private var primaryActionCard: some View {
        let action = viewModel.smartDailyAction(liveVM: liveViewModel)
        let actionRoute = routeForAction(action)
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: action.title,
                type: .homeDailyAction,
                screen: .home,
                metadata: [
                    "source": action.source,
                    "recovery_state": viewModel.recoveryState.rawValue,
                    "routed_to": "\(actionRoute)"
                ]
            )
            navigationPath.append(actionRoute)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(Copy.Home.todaysAction)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(liveReadinessScore), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if let proof = action.proofLine {
                            Text(proof)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Journal Prompt Card

    @ViewBuilder
    private var journalPromptCard: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        // Show journal prompt in the evening (after 6pm)
        if hour >= 18 {
            NavigationLink(value: Route.journalEntry) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Home.howWasToday)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(Copy.Home.journalSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .purple)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    /// Routes Today's Action card contextually based on action text content.
    /// Sleep-related actions go to sleep coach, strain/workout to strain detail,
    /// recovery/rest to insights. Defaults to insightsDetail.
    private func routeForAction(_ action: DashboardViewModel.SmartAction) -> Route {
        .todaysAction
    }

    // MARK: - Recovery Why Line

    /// Builds a short plain-English explanation of why the recovery score is what it is.
    /// Inspects live HRV, resting heart rate, sleep duration, and recent workout data to
    /// identify the top contributing factors, then templates them via Copy.Home.RecoveryHero.
    private var recoveryWhyLine: String? {
        guard hasLiveReadiness else { return nil }

        let score = liveReadinessScore
        let state = DashboardViewModel.RecoveryState(score: score)

        // Gather factor descriptions based on whether each signal is positive or negative.
        var positiveFactors: [String] = []
        var negativeFactors: [String] = []

        // HRV (40% weight, most important)
        if let hrv = liveViewModel.recovery.latestHRV {
            // Without baseline, use a rough heuristic: above 40ms is decent
            if hrv >= 50 {
                positiveFactors.append(Copy.Home.RecoveryHero.hrvBounced)
            } else if hrv >= 35 {
                positiveFactors.append(Copy.Home.RecoveryHero.hrvHigh)
            } else if hrv < 25 {
                negativeFactors.append(Copy.Home.RecoveryHero.hrvLow)
            } else {
                negativeFactors.append(Copy.Home.RecoveryHero.hrvBelow)
            }
        }

        // Resting Heart Rate (35% weight)
        if let rhr = liveViewModel.recovery.latestRestingHeartRate {
            if rhr <= 55 {
                positiveFactors.append(Copy.Home.RecoveryHero.rhrLow)
            } else if rhr <= 65 {
                positiveFactors.append(Copy.Home.RecoveryHero.rhrDropped)
            } else if rhr > 75 {
                negativeFactors.append(Copy.Home.RecoveryHero.rhrHigh)
            } else {
                negativeFactors.append(Copy.Home.RecoveryHero.rhrElevated)
            }
        }

        // Sleep Duration (15% weight)
        let sleepHours = liveViewModel.sleep.lastNightSleepDuration / 3600.0
        if sleepHours > 0 {
            if sleepHours >= 7.5 {
                positiveFactors.append(Copy.Home.RecoveryHero.sleepGreat)
            } else if sleepHours >= 6.5 {
                positiveFactors.append(Copy.Home.RecoveryHero.sleepGood)
            } else if sleepHours >= 5.5 {
                negativeFactors.append(Copy.Home.RecoveryHero.sleepShort)
            } else {
                negativeFactors.append(Copy.Home.RecoveryHero.sleepShort)
            }
        }

        // Recent Workout (4% weight, only mention if it is a drag)
        if let workoutTime = liveViewModel.workout.lastWorkoutTimestamp {
            let hoursSince = Date().timeIntervalSince(workoutTime) / 3600.0
            if hoursSince < 18, (liveViewModel.workout.lastWorkoutDuration ?? 0) > 30 {
                negativeFactors.append(Copy.Home.RecoveryHero.recentHardWorkout)
            }
        }

        // Build the line based on recovery state
        switch state {
        case .green:
            let top = positiveFactors.first ?? Copy.Home.RecoveryHero.hrvBounced
            let second = positiveFactors.dropFirst().first ?? Copy.Home.RecoveryHero.sleepSolid
            return Copy.Home.RecoveryHero.whyLineGreen(topFactor: top, secondFactor: second)

        case .yellow:
            // Lead with the top negative factor if available, otherwise the top positive one
            let factor = negativeFactors.first ?? positiveFactors.first
            guard let top = factor else { return nil }
            return Copy.Home.RecoveryHero.whyLineYellow(topFactor: top)

        case .red:
            let top = negativeFactors.first ?? Copy.Home.RecoveryHero.hrvLow
            let second = negativeFactors.dropFirst().first ?? Copy.Home.RecoveryHero.sleepShort
            return Copy.Home.RecoveryHero.whyLineRed(topFactor: top, secondFactor: second)
        }
    }

    static func recoveryLabel(_ score: Int) -> String {
        switch score {
        case 80...100: return Copy.Home.fullyRecovered
        case 60..<80: return Copy.Home.wellRecovered
        case 40..<60: return Copy.Home.moderate
        case 20..<40: return Copy.Home.fatigued
        default: return Copy.Home.strained
        }
    }

    static func recoveryColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .green.opacity(0.8)
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }

    // MARK: - First Launch Loading

    @State private var firstLaunchIconScale: CGFloat = 0.8
    @State private var firstLaunchDotCount = 0
    @State private var firstLaunchAppeared = false
    @State private var firstLaunchDotTimer = RepeatTimer()

    private var firstLaunchPhase: (icon: String, text: String, color: Color) {
        switch viewModel.ui.syncPhase {
        case .idle, .importing:
            return ("brain.head.profile", Copy.Home.syncingHealthData, .purple)
        case .analyzing:
            let points = viewModel.analysis.dataDepth.totalDataPoints
            let label = points > 0 ? Copy.Home.analyzingDataPoints(points) : Copy.Home.analyzingYourData
            return ("brain.head.profile", label, .purple)
        case .discovering:
            return ("sparkles", Copy.Home.discoveringPatterns, .orange)
        case .complete:
            return ("checkmark.circle.fill", Copy.Home.ready, .green)
        }
    }

    private var firstLaunchLoadingView: some View {
        let phase = firstLaunchPhase
        return VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(phase.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(firstLaunchIconScale == 1.0 ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: firstLaunchIconScale)

                Circle()
                    .fill(phase.color.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(firstLaunchIconScale == 1.0 ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: firstLaunchIconScale)

                Image(systemName: phase.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(phase.color)
                    .frame(width: 80, height: 80)
                    .background(phase.color.opacity(0.12), in: Circle())
                    .scaleEffect(firstLaunchIconScale)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 8) {
                Text(phase.text + String(repeating: ".", count: firstLaunchDotCount))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: viewModel.ui.syncPhase)

                Text(Copy.Home.thisOnlyHappensOnce)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            firstLaunchAppeared = true
            firstLaunchIconScale = 1.0
            startFirstLaunchDotTimer()
        }
        .onDisappear {
            firstLaunchAppeared = false
            stopFirstLaunchDotTimer()
        }
    }

    private func startFirstLaunchDotTimer() {
        firstLaunchDotTimer.start(interval: 0.5, tolerance: 0.1) {
            guard firstLaunchAppeared else {
                firstLaunchDotTimer.stop()
                return
            }
            firstLaunchDotCount = (firstLaunchDotCount % 3) + 1
        }
    }

    private func stopFirstLaunchDotTimer() {
        firstLaunchDotTimer.stop()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(Copy.Home.unableToLoadData)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(Copy.Home.tryAgain) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Try Again",
                    type: .errorRetry,
                    screen: .home,
                    metadata: [
                        "source": "home_error_view"
                    ]
                )
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Retry loading health data")
        }
        .padding()
        .accessibilityElement(children: .combine)
        .onAppear {
            AppAnalytics.shared.trackError(type: "data_load_failed", screen: .home, message: message)
        }
    }
}

#Preview {
    let hkManager = HealthKitManager()
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        HomeView(
            viewModel: DashboardViewModel(
                healthKitManager: hkManager,
                analysisEngine: AnalysisEngine(),
                store: HealthDataStore(modelContainer: container),
                housekeepingService: DashboardHousekeepingService(
                    persistenceManager: PersistenceManager(),
                    analytics: AppAnalytics.shared,
                    sessionTracker: SessionTracker.shared
                )
            ),
            liveViewModel: LiveViewModel(healthKitManager: hkManager),
            deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
            appStateStore: AppStateStore(),
            navigationPath: .constant(NavigationPath()),
            showSettings: .constant(false)
        )
    }
}
