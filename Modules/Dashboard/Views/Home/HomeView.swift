import SwiftUI
import SwiftData

struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    let appStateStore: AppStateStore
    @Binding var navigationPath: NavigationPath
    @Environment(\.scenePhase) private var scenePhase

    @State private var thermalManager = ThermalManager.shared
    @State private var homeRefreshTimer = RepeatTimer()
    @State private var readinessRefreshTimer = RepeatTimer()
    @State private var weeklyReviewViewModel: WeeklyReviewViewModel?
    @State private var showScoreGuide = false
    @State private var showRecoveryInfo = false
    @State private var actionDoneToday = false
    @State private var showShareCard = false
    @State private var maxScrollDepth: Int = 0
    @State private var showMorningCheckIn = false
    @State private var showSoftLockPaywall = false
    // Section trackers
    @State private var recoveryTracker = SectionTracker(section: .homeRecovery, tab: .home)
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var risksTracker = SectionTracker(section: .homeRisks, tab: .home)
    @State private var weeklyReviewTracker = SectionTracker(section: .homeWeeklyReview, tab: .home)


    var body: some View {
        Group {
            if viewModel.ui.isLoading && viewModel.healthKitManager.timeSeries.isEmpty {
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
        // UI-test only: zero-size accessible triggers for sheets that otherwise
        // lack a stable, always-visible entry point (ScoreGuideSheet is not
        // wired to any gesture; the journal prompt only appears after 6pm).
        .overlay(alignment: .topLeading) { uiTestHiddenTriggers }
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
        .sheet(isPresented: $showSoftLockPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared, source: "soft_lock_home")
        }
        .sheet(isPresented: $showRecoveryInfo) {
            // Nil-safe value: `liveReadinessScore` falls back to the daily
            // health score when no readiness exists, which would mislabel the
            // info sheet. Pass 0 in that case so the sheet renders neutrally.
            RecoveryInfoSheet(score: liveViewModel.recovery.readinessScore ?? 0)
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
                || (UITestMode.isEnabled && UITestMode.forceMorningCheckIn)
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

    /// Plain-English caption for the 7-day HRV trend. Returns nil when the
    /// trend is `.insufficientData` so the hero card hides the line cleanly.
    private var weeklyTrendCaptionString: String? {
        switch liveViewModel.recovery.weeklyTrend {
        case .improving:        return Copy.Home.RecoveryTrend.improving
        case .stable:           return Copy.Home.RecoveryTrend.stable
        case .declining:        return Copy.Home.RecoveryTrend.declining
        case .insufficientData: return nil
        }
    }

    /// Name of the lowest-scoring category for personalized score explanation.
    /// Cached in DashboardViewModel.updateCachedProperties() to avoid recomputing on every render.
    private var weakestCategoryName: String? {
        viewModel.cachedWeakestCategoryName
    }

    /// Build the payload for the on-device daily narrative card. Pulls live
    /// readiness, weakest pillar, latest HRV, and last night's sleep duration
    /// from the existing dashboard / live view models — no additional HealthKit queries.
    private func buildDailyNarrativeSignals() -> DailyNarrativeSignals {
        let hrv: Int? = liveViewModel.recovery.latestHRV.map { Int($0.rounded()) }
        let sleepHours: Double? = liveViewModel.sleep.lastNightSleepDuration > 0
            ? liveViewModel.sleep.lastNightSleepDuration
            : nil
        return DailyNarrativeSignals(
            userFirstName: nil,
            readinessScore: hasLiveReadiness ? liveReadinessScore : nil,
            weakestPillar: weakestCategoryName,
            hrvMs: hrv,
            sleepHours: sleepHours,
            streakDays: SessionTracker.shared.streakDays
        )
    }

    private func startReadinessRefresh() {
        readinessRefreshTimer.stop()
        // Hotfix kill switch — flip ON in Firebase Remote Config when watch
        // sync is thrashing battery. Live readiness card reverts to whatever
        // is already cached on the live view model.
        guard !RemoteConfigManager.shared.killHomeLiveReadiness else { return }
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

    // MARK: - Soft Lock (paywall decliner)

    /// Keyed off the explicit decline flag, never `!hasAccess`, so the
    /// `.unknown` status during startup never flashes the lock.
    private var isSoftLocked: Bool {
        appStateStore.paywallDeclined && !FeatureGate.hasFullAccess
    }

    /// Persistent quiet unlock bar pinned under the home scroll while soft locked.
    private var softLockBottomBar: some View {
        VStack(spacing: DS.space2) {
            Text(Copy.Home.softLockPatterns(viewModel.insights.allInsights.count))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textSecondary)

            Button {
                showSoftLockPaywall = true
            } label: {
                Text(Copy.Home.softLockCTA)
                    .font(DS.Typography.bodySemibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(DS.cardPadding)
        .background(AppColour.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(AppColour.borderHigh, lineWidth: 1)
        )
        .padding(.horizontal, DS.screenPadding)
        .padding(.bottom, DS.space2)
    }

    /// Only show the "Connect Your Health Data" empty state after the initial load
    /// has completed AND there is genuinely no data. This prevents the empty state
    /// from flashing during startup before HealthKit data has been loaded.
    private var shouldShowEmptyState: Bool {
        viewModel.ui.hasCompletedInitialLoad && !hasData
    }

    /// Uppercase tracked label that visually separates HomeView's sections.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.captionSemibold)
            .tracking(1.2)
            .foregroundStyle(AppColour.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.screenPadding)
    }

    private var homeContent: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: DS.itemSpacing) {
                // 1. Greeting header. context-aware with recovery state
                CoachGreetingView()
                .padding(.top, DS.space1)

                if shouldShowEmptyState {
                    connectHealthView
                } else if hasData {
                    // ── Above the fold ──

                    // 0. Next Up. the daily action leads the screen: Laso's core
                    // promise is telling you what to do next, so the step comes
                    // before the score that explains it.
                    primaryActionCard

                    // 1. Recovery Hero. live readiness score (updates every 30 min).
                    // Title, pill, and ring all derive from RecoveryState so the
                    // three-band threshold table agrees with itself.
                    RecoveryHeroCard(
                        score: liveReadinessScore,
                        recoveryLabel: hasLiveReadiness
                            ? DashboardViewModel.RecoveryState(score: liveReadinessScore).label
                            : "Daily Health Score",
                        dayType: DashboardViewModel.RecoveryState(score: liveReadinessScore).dayType,
                        // Use the EWMA-vs-EWMA-7-days-ago delta so the badge
                        // reflects a stable weekly comparison instead of two
                        // point-in-time snapshots. With the live headline
                        // moving every 30 min, the old daily-vs-snapshot
                        // delta could swing meaninglessly between refreshes.
                        scoreChangeFromLastWeek: viewModel.scores.weeklyScoreChange,
                        recoveryWhyLine: recoveryWhyLine,
                        hasLiveReadiness: hasLiveReadiness,
                        lastRefresh: viewModel.lastRefresh,
                        scoreLabel: liveViewModel.recovery.scoreLabel,
                        isWearingWatch: liveViewModel.recovery.isWearingWatch,
                        weeklyTrendCaption: weeklyTrendCaptionString,
                        // When live Recovery exists the (i) opens the Recovery
                        // explainer; otherwise the headline is the Daily Health
                        // Score (fallback) so we open the matching guide.
                        onTap: {
                            if hasLiveReadiness {
                                showRecoveryInfo = true
                            } else {
                                showScoreGuide = true
                            }
                        },
                        onShare: {
                            // Entry step of the share funnel: without this the
                            // first event is the Share CTA inside the sheet, so
                            // open-then-dismiss users were invisible.
                            AppAnalytics.shared.trackBlockTap(
                                title: "Share",
                                type: .shareCard,
                                screen: .home,
                                metadata: ["source": "recovery_hero", "card_type": "rings"]
                            )
                            showShareCard = true
                        }
                    )
                    .sheet(isPresented: $showShareCard) {
                        // vitalityAge/realAge are 0 until the scorer's snapshot
                        // exists; pass nil so empty rings never render.
                        ShareRingsSheet(
                            vitalityAge: viewModel.vitalityScorer.isReady ? viewModel.vitalityScorer.vitalityAge : nil,
                            realAge: viewModel.vitalityScorer.isReady ? viewModel.vitalityScorer.chronologicalAge : nil,
                            recovery: liveReadinessScore > 0 ? liveReadinessScore : nil,
                            sleepSeconds: liveViewModel.sleep.lastNightSleepDuration > 0 ? liveViewModel.sleep.lastNightSleepDuration : nil
                        )
                    }
                    .onAppear {
                        recoveryTracker.appeared()
                        maxScrollDepth = max(maxScrollDepth, 10)
                        AppAnalytics.shared.trackScoreViewed(
                            score: liveReadinessScore,
                            previousScore: viewModel.scores.scoreChangeFromYesterday.map { liveReadinessScore - $0 }
                        )
                    }
                    .onDisappear { recoveryTracker.disappeared() }
                    .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    // 1b. Activation Progress (first 8 days. Paper 8)
                    ActivationProgressBanner(
                        state: viewModel.activationState,
                        latestMilestone: viewModel.latestMilestoneEvent,
                        onDismissCelebration: { viewModel.latestMilestoneEvent = nil }
                    )

                    // 1c. Morning Check-In (Paper 10: Subjective + Objective)
                    if showMorningCheckIn {
                        MorningCheckInView(
                            onComplete: { checkIn in
                                viewModel.applyMorningCheckIn(checkIn)
                                withAnimation { showMorningCheckIn = false }
                            },
                            onDismiss: {
                                MorningCheckInManager.markDismissedToday()
                                withAnimation { showMorningCheckIn = false }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 2a-ii. On-device daily narrative (iOS 26+ Foundation Models).
                    // Proactive one-paragraph story of today, grounded in real signals.
                    DailyNarrativeCard(signals: buildDailyNarrativeSignals())
                        .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    // 2b. Body Intelligence. non-obvious ML findings
                    TodayBriefingView(cards: viewModel.intelligenceBriefing)
                        .softLocked(isSoftLocked) { showSoftLockPaywall = true }

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
                    .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    // 2d. Ask Your Data (Papers 1 & 2: PHIA)
                    // Stays visible and tappable while soft locked; the tap
                    // raises the unlock sheet instead of navigating.
                    AskYourDataCard {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Ask Your Data",
                            type: .smartAction,
                            screen: .home,
                            metadata: ["source": "home_card"]
                        )
                        if isSoftLocked {
                            showSoftLockPaywall = true
                        } else {
                            navigationPath.append(Route.askYourData)
                        }
                    }

                    // 3. Compact alert banner (illness + health risks)
                    compactAlertBanner
                        .onAppear { illnessTracker.appeared(); risksTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 20) }
                        .onDisappear { illnessTracker.disappeared(); risksTracker.disappeared() }
                        .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    sectionHeader("VITALS")
                        .padding(.top, DS.space3)

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
                    .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    // ── Below the fold ──

                    sectionHeader("REVIEW")
                        .padding(.top, DS.space3)

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
                    .onAppear { weeklyReviewTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
                    .onDisappear { weeklyReviewTracker.disappeared() }
                    .softLocked(isSoftLocked) { showSoftLockPaywall = true }

                    // Last updated footer. always rendered so the user can confirm
                    // the screen is alive; falls back to a pull-to-refresh hint
                    // when no sync has happened yet (very first launch).
                    Group {
                        if let lastRefresh = viewModel.lastRefresh {
                            Copy.Home.updatedAgo(lastRefresh)
                                .accessibilityLabel(Copy.Home.lastUpdatedAgo(lastRefresh))
                        } else {
                            Copy.Home.pullToRefresh
                                .accessibilityLabel(Copy.Home.notSyncedYetAccessibility)
                        }
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 32, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            if isSoftLocked {
                softLockBottomBar
            }
        }
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
        .onAppear {
            // Empty-state friction signal: fires when the user lands on Home
            // without HealthKit data, so analytics can isolate "no-data churn"
            // from authorized-but-engaged users.
            AppAnalytics.shared.trackEmptyStateShown(
                screen: .home,
                reason: viewModel.healthKitManager.isAuthorized ? "authorized_no_data" : "not_authorized"
            )
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
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(AppColour.danger)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Copy.Home.earlyWarning)
                                    .font(DS.Typography.footnoteMedium)
                                    .foregroundStyle(AppColour.danger)
                                Text(warning.narrative)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(AppColour.textSecondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                            }

                            Spacer()

                            Text(warning.severity == .critical ? Copy.Home.severityHigh : warning.severity == .warning ? Copy.Home.severityModerate : Copy.Home.severityLow)
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(warning.severity == .critical ? AppColour.danger : warning.severity == .warning ? AppColour.warning : AppColour.scoreFair, in: Capsule())

                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                        .padding(DS.space2 + 2)
                        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(AppColour.danger.opacity(0.2), lineWidth: 1)
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
                                .font(DS.Typography.body)
                                .foregroundStyle(risk.riskGrade.color)
                                .frame(width: 28, height: 28)
                                .background(risk.riskGrade.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                            Text(risk.riskType.displayName)
                                .font(DS.Typography.footnoteMedium)
                                .foregroundStyle(AppColour.textPrimary)

                            Spacer()

                            Text(risk.riskGrade.displayName)
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(risk.riskGrade.color)

                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                        .padding(DS.space2 + 2)
                        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(risk.riskGrade.color.opacity(DS.strokeAlpha), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: AppColour.danger)
            .padding(.horizontal, DS.screenPadding)
        }
    }

    // MARK: - Next Up Card (single source of truth for what to do)

    @ViewBuilder
    private var primaryActionCard: some View {
        let action = viewModel.smartDailyAction(liveVM: liveViewModel)
        let actionRoute = routeForAction(action)
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Home.nextUpHeader)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .foregroundStyle(DS.scoreColor(liveReadinessScore))

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
                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(DS.Typography.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(liveReadinessScore), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                            .lineLimit(2)

                        Text(action.subtitle)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)

                        if let proof = action.proofLine {
                            Text(proof)
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textTertiary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Button {
                actionDoneToday.toggle()
                if actionDoneToday {
                    UserDefaults.standard.set(Date(), forKey: AppKeys.Data.dailyActionDoneDay)
                } else {
                    UserDefaults.standard.removeObject(forKey: AppKeys.Data.dailyActionDoneDay)
                }
                AppAnalytics.shared.trackBlockTap(
                    title: action.title,
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["source": "next_up_mark_done", "done": "\(actionDoneToday)"]
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: actionDoneToday ? "checkmark.circle.fill" : "circle")
                        .font(DS.Typography.body)
                        .foregroundStyle(actionDoneToday ? AppColour.success : AppColour.textTertiary)
                    Text(actionDoneToday ? Copy.Home.nextUpDone : Copy.Home.nextUpMarkDone)
                        .font(DS.Typography.caption)
                        .foregroundStyle(actionDoneToday ? AppColour.success : AppColour.textSecondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal, DS.screenPadding)
        .accessibilityIdentifier("home.todaysActionCard")
        .onAppear {
            let stored = UserDefaults.standard.object(forKey: AppKeys.Data.dailyActionDoneDay) as? Date
            actionDoneToday = stored.map { Date.cal.isDateInToday($0) } ?? false
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
                    .font(DS.Typography.displayL)
                    .foregroundStyle(phase.color)
                    .frame(width: 80, height: 80)
                    .background(phase.color.opacity(0.12), in: Circle())
                    .scaleEffect(firstLaunchIconScale)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 8) {
                Text(phase.text + String(repeating: ".", count: firstLaunchDotCount))
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(AppColour.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: viewModel.ui.syncPhase)

                Text(Copy.Home.thisOnlyHappensOnce)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
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

    /// Zero-size, UI-test-only buttons that expose entry points for sheets the
    /// production UI does not offer as a direct tap target. Only compiled into
    /// the tree when running under `UITestMode`; in production this returns an
    /// `EmptyView` and has zero visual or accessibility impact.
    @ViewBuilder
    private var uiTestHiddenTriggers: some View {
        if UITestMode.isEnabled {
            VStack(spacing: 0) {
                Button(Copy.Home.openScoreGuideButton) { showScoreGuide = true }
                    .accessibilityIdentifier("uitest.openScoreGuide")
                NavigationLink("Open Journal", value: Route.journalEntry)
                    .accessibilityIdentifier("uitest.openJournalEntry")
            }
            .opacity(0.001)
            .frame(width: 1, height: 1)
            .allowsHitTesting(true)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(DS.Typography.displayL)
                .foregroundStyle(AppColour.warning)
                .accessibilityHidden(true)

            Text(Copy.Home.unableToLoadData)
                .font(DS.Typography.title3)

            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textSecondary)
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
            .accessibilityHint(Copy.Home.retryLoadingHealthDataHint)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .onAppear {
            AppAnalytics.shared.trackError(type: "data_load_failed", screen: .home, message: message)
        }
    }
}

/// Blurs a home card for paywall decliners and routes any tap to the unlock
/// sheet. Whole-card blur is deliberate; per-element granularity is skipped.
private struct SoftLockModifier: ViewModifier {
    let isLocked: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if isLocked {
            content
                .blur(radius: 10)
                .allowsHitTesting(false)
                .overlay(
                    HStack(spacing: DS.space1) {
                        Image(systemName: "lock.fill")
                        Text(Copy.Home.softLockBadge)
                    }
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(Color.accentColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.full))
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

private extension View {
    func softLocked(_ isLocked: Bool, onTap: @escaping () -> Void) -> some View {
        modifier(SoftLockModifier(isLocked: isLocked, onTap: onTap))
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
            navigationPath: .constant(NavigationPath())
        )
    }
}
