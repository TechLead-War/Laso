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
    @State private var showJournalEntry = false
    @State private var showRecoveryInfo = false
    @State private var actionDoneToday = false
    @State private var actionReminderSet = false
    @State private var showShareCard = false
    /// Yesterday's marked-done action result, surfaced this morning (loop closer).
    @State private var dailyResult: DailyActionResultStore.Result?
    /// Master-streak milestone just crossed and not yet celebrated, if any.
    @State private var streakMilestone: Int?
    /// Not @State on purpose: see `ScrollDepthTracker`. Every write here
    /// used to re-run this whole body while the user was scrolling.
    @State private var scrollDepth = ScrollDepthTracker()
    @State private var showMorningCheckIn = false
    @State private var showSoftLockPaywall = false
    /// One-shot full live fetch on first appear. Without it, Home only starts the
    /// tiered refresh timers, which defer the slow tier (HRV, resting HR, sleep),
    /// so the "Why" list shows only Energy until the user pulls to refresh.
    @State private var didInitialLiveFetch = false
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
        .background(AppColour.surfaceSunken.ignoresSafeArea())
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
        .sheet(isPresented: $showJournalEntry) {
            JournalEntryView()
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
            if !didInitialLiveFetch {
                didInitialLiveFetch = true
                // Load HRV, resting HR and sleep right away so the Why list is
                // complete on first open, not after a manual refresh.
                liveViewModel.fetchHomeData()
            }
            startHomeRefresh()
            startReadinessRefresh()
            rebuildMetricTilesFromLive()
            showMorningCheckIn = MorningCheckInManager.shouldShowCheckIn()
                || (UITestMode.isEnabled && UITestMode.forceMorningCheckIn)
            if let checkIn = MorningCheckInManager.todaysCheckIn() {
                viewModel.subjectiveReadinessAdjustment = checkIn.readinessAdjustment
            }
            refreshDailyResult()
            AppAnalytics.shared.trackFeatureOpen(.home)
        }
        .onChange(of: liveReadinessScore) { _, _ in
            // The morning lock is written in the same pass that produces this
            // score, so a change here is the signal that it may now exist.
            refreshDailyResult()
        }
        .onDisappear {
            stopHomeRefresh()
            stopReadinessRefresh()
            stopFirstLaunchDotTimer()
            if scrollDepth.maxDepth > 0 {
                AppAnalytics.shared.trackScrollDepth(screen: .home, maxDepthPercent: scrollDepth.maxDepth)
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
        // `initial: true` covers the streak already being computed when Home
        // opens; the change side covers it landing after the first analysis pass.
        .onChange(of: viewModel.gamificationEngine.streaks.masterStreak, initial: true) { _, _ in
            refreshStreakMilestone()
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

    /// The wins the user has actually earned right now. Empty is a valid answer
    /// and hides the share affordance: every template here is gated so the card
    /// can only ever carry a number the user would be glad to post.
    ///
    /// `allTimeBestSleepHours` comes from the deferred heavy analysis tier, so it
    /// is nil until that has run. The personal-best card simply does not appear
    /// until then.
    private var shareTemplates: [ShareTemplate] {
        viewModel.shareTemplates(liveVM: liveViewModel, actionResult: dailyResult)
    }

    /// Compute the loop-closer card once today's morning lock exists. Guarded on
    /// `dailyResult == nil` so it resolves once per morning and the shown event
    /// fires a single time despite the 30-minute score refresh.
    private func refreshDailyResult() {
        guard dailyResult == nil,
              let result = DailyActionResultStore.resultToShow() else { return }
        dailyResult = result
        let direction: String
        switch result.direction {
        case .up:     direction = "up"
        case .steady: direction = "steady"
        case .down:   direction = "down"
        }
        AppAnalytics.shared.trackDailyResultShown(direction: direction, delta: result.delta)
    }

    /// Resolve the milestone offer once per Home session. Guarded on
    /// `streakMilestone == nil` so the repeated streak recomputes behind the
    /// refresh timers cannot re-raise a card the user just dismissed.
    private func refreshStreakMilestone() {
        guard streakMilestone == nil,
              let milestone = StreakMilestoneStore.pending(
                streak: viewModel.gamificationEngine.streaks.masterStreak) else { return }
        streakMilestone = milestone
    }

    /// Retires the milestone for good. Both dismissing and opening the share
    /// sheet end the offer: it is tied to the moment, not to whether the user
    /// actually posted.
    private func closeStreakMilestone(_ milestone: Int) {
        StreakMilestoneStore.markCelebrated(milestone)
        withAnimation { streakMilestone = nil }
    }

    /// One time offer to share a streak the user has just crossed. Matches
    /// `DailyActionResultCard` so the two never compete for weight above the fold.
    private func streakMilestoneCard(_ milestone: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Home.streakMilestoneHeader)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .foregroundStyle(AppColour.success)

            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(width: 40, height: 40)
                    .background(AppColour.success, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(Copy.Home.streakMilestoneTitle(days: milestone))
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textPrimary)

                    Text(Copy.Home.streakMilestoneBody)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: DS.space3) {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Share",
                        type: .shareCard,
                        screen: .home,
                        metadata: ["source": "streak_milestone", "milestone_days": milestone]
                    )
                    closeStreakMilestone(milestone)
                    showShareCard = true
                } label: {
                    Text(Copy.Home.streakMilestoneShare)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.success)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.streakMilestoneCard.share")

                Button {
                    // Same card_id as the Share button above so the offer has a
                    // decline rate; without it a dismiss is indistinguishable
                    // from never seeing the card.
                    AppAnalytics.shared.trackBlockTap(
                        title: "Dismiss",
                        type: .shareCard,
                        screen: .home,
                        metadata: ["source": "streak_milestone", "milestone_days": milestone]
                    )
                    closeStreakMilestone(milestone)
                } label: {
                    Text(Copy.Home.streakMilestoneDismiss)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: AppColour.success)
        .padding(.horizontal, DS.screenPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.streakMilestoneCard")
    }

    /// Opens the screen behind one Why row on the score card. Energy has no
    /// screen of its own — it is the ring's own number — so it opens the same
    /// explainer the ring does.
    private func openWhySignal(_ kind: DashboardViewModel.RecoveryWhyReason.Kind) {
        let destination: String
        switch kind {
        case .sleep:
            destination = "sleep_coach"
            navigationPath.append(Route.sleepCoach)
        case .heart:
            destination = HealthMetric.heartRateVariability.rawValue
            navigationPath.append(HealthMetric.heartRateVariability)
        case .restingHR:
            destination = HealthMetric.restingHeartRate.rawValue
            navigationPath.append(HealthMetric.restingHeartRate)
        case .stress:
            destination = "stress_monitor"
            navigationPath.append(Route.stressMonitor)
        case .energy:
            destination = "score_explainer"
            if hasLiveReadiness {
                showRecoveryInfo = true
            } else {
                showScoreGuide = true
            }
        }
        AppAnalytics.shared.trackBlockTap(
            title: "Why row",
            type: .metricRow,
            screen: .home,
            metadata: ["source": "recovery_hero_why", "destination": destination]
        )
    }

    /// Name of the lowest-scoring category for personalized score explanation.
    /// Cached in DashboardViewModel.updateCachedProperties() to avoid recomputing on every render.
    private var weakestCategoryName: String? {
        viewModel.cachedWeakestCategoryName
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
                AppAnalytics.shared.trackPremiumFeatureAttempted(feature: "home_unlock_bar", screen: .home)
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

                    // 0b. What the watch cannot see. Sits above the action card
                    // because an active rest chip overrides what that card says.
                    LifeContextChipRow(store: viewModel.lifeContextStore)
                        .onChange(of: viewModel.lifeContextStore.active) { _, _ in
                            // The action is cached for the day, so without this
                            // the card keeps yesterday's advice after a toggle.
                            viewModel.invalidateDailyActionCache()
                        }

                    // 0a. Yesterday's result. When present, the proof that
                    // yesterday's action moved the score leads the screen — it
                    // is the reason the user came back this morning.
                    if let dailyResult {
                        DailyActionResultCard(result: dailyResult) {
                            DailyActionResultStore.clear()
                            withAnimation { self.dailyResult = nil }
                        }
                    }

                    // 0a2. A streak milestone just crossed. Sits with the other
                    // above-the-fold moment cards and retires itself for good on
                    // either button, so it can never become daily furniture.
                    if let streakMilestone {
                        streakMilestoneCard(streakMilestone)
                    }

                    // 0. Next Up. the daily action leads the screen: Laso's core
                    // promise is telling you what to do next, so the step comes
                    // before the score that explains it.
                    primaryActionCard

                    // 1. Score card. live readiness score (updates every 30 min)
                    // shown as one ring plus the plain-word reasons behind it.
                    RecoveryHeroCard(
                        score: liveReadinessScore,
                        summaryHead: viewModel.readinessSummary(score: liveReadinessScore).head,
                        summarySub: viewModel.readinessSummary(score: liveReadinessScore).sub,
                        whyReasons: viewModel.recoveryWhyReasons(liveVM: liveViewModel),
                        hasLiveReadiness: hasLiveReadiness,
                        scoreChange: viewModel.scores.scoreDeltaFromYesterday,
                        isWearingWatch: liveViewModel.recovery.isWearingWatch,
                        scoreUncertainty: liveViewModel.recovery.readinessUncertainty,
                        // When live Recovery exists the tap opens the Recovery
                        // explainer; otherwise the headline is the Daily Health
                        // Score (fallback) so we open the matching guide.
                        onTap: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Recovery Score",
                                type: .homeRecoveryInfoButton,
                                screen: .home,
                                metadata: ["has_live_readiness": hasLiveReadiness]
                            )
                            if hasLiveReadiness {
                                showRecoveryInfo = true
                            } else {
                                showScoreGuide = true
                            }
                        },
                        onTapWhy: { kind in openWhySignal(kind) },
                        // No earned win means no share icon at all. Offering the
                        // sheet with nothing in it would train users to ignore it.
                        onShare: shareTemplates.isEmpty ? nil : {
                            // Entry step of the share funnel: without this the
                            // first event is the Share CTA inside the sheet, so
                            // open-then-dismiss users were invisible.
                            AppAnalytics.shared.trackBlockTap(
                                title: "Share",
                                type: .shareCard,
                                screen: .home,
                                metadata: ["source": "recovery_hero", "card_type": "template"]
                            )
                            showShareCard = true
                        }
                    )
                    .sheet(isPresented: $showShareCard) {
                        ShareWinSheet(templates: shareTemplates)
                    }
                    .onAppear {
                        recoveryTracker.appeared()
                        scrollDepth.record(10)
                        AppAnalytics.shared.trackScoreViewed(
                            score: liveReadinessScore,
                            previousScore: viewModel.scores.scoreChangeFromYesterday.map { liveReadinessScore - $0 }
                        )
                    }
                    .onDisappear { recoveryTracker.disappeared() }
                    .softLocked(isSoftLocked, feature: "home_recovery_score") { showSoftLockPaywall = true }

                    // 1a0. Sleep bank. The only running total on the screen, so
                    // it sits right under the score it helps explain. Hidden
                    // entirely until the balance is big enough to act on.
                    if let bank = viewModel.sleepBank {
                        SleepBankCard(debtHours: bank.debtHours,
                                      personalBaseline: bank.personalBaseline,
                                      deficits: bank.deficits,
                                      nightsRecorded: bank.nightsRecorded)
                    }

                    // 1a. What Apple Health has actually sent. Only rendered
                    // when a signal is empty, so a full read carries no clutter.
                    DataCoverageCard(coverage: viewModel.signalCoverage()) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Check Health settings",
                            type: .errorRetry,
                            screen: .home,
                            metadata: ["source": "data_coverage"]
                        )
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }

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

                    // 1d. Watch face complication nudge. Only when a watch is paired
                    // with the app installed and the complication is not on the face.
                    WatchComplicationCard(linkState: PhoneWatchSession.shared.linkState)

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
                            AppAnalytics.shared.trackPremiumFeatureAttempted(feature: "ask_your_data", screen: .home)
                            showSoftLockPaywall = true
                        } else {
                            navigationPath.append(Route.askYourData)
                        }
                    }
                    // Depth marker on a card that always renders. The old 20
                    // marker sat on the alert banner, which is absent for a
                    // healthy user, so their depth jumped 10 -> 90.
                    .onAppear { scrollDepth.record(40) }

                    // 3. Compact alert banner (illness + health risks)
                    // Each tracker is attached to its own sub-block inside the
                    // banner, not here: the banner renders when either an
                    // illness warning or a risk exists.
                    compactAlertBanner
                        .softLocked(isSoftLocked, feature: "home_alerts") { showSoftLockPaywall = true }

                    sectionHeader("VITALS")
                        .padding(.top, DS.space3)

                    // 4. Metric Strip. horizontal scroll replacing 6 vertical cards
                    MetricStripView(tiles: viewModel.cachedMetricTiles) { tile in
                        AppAnalytics.shared.trackBlockTap(
                            title: tile.label,
                            type: .metricRow,
                            screen: .home,
                            metadata: ["destination": tile.id]
                        )
                        navigationPath.append(tile.route)
                    }
                    .onAppear { scrollDepth.record(65) }
                    .softLocked(isSoftLocked, feature: "home_vitals") { showSoftLockPaywall = true }

                    // ── Below the fold ──

                    // The header used to render unconditionally while the card
                    // below returns an empty Group with no review, so a new user
                    // saw a heading with nothing under it.
                    if weeklyReviewViewModel?.review != nil {
                        sectionHeader("REVIEW")
                            .padding(.top, DS.space3)
                    }

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
                    .onAppear { weeklyReviewTracker.appeared(); scrollDepth.record(90) }
                    .onDisappear { weeklyReviewTracker.disappeared() }
                    .softLocked(isSoftLocked, feature: "home_weekly_review") { showSoftLockPaywall = true }

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
                        AppAnalytics.shared.trackBlockTap(
                            title: "Early Warning",
                            type: .headlineInsight,
                            screen: .home,
                            metadata: [
                                "severity": warning.severity.rawValue,
                                "destination": "insights_detail"
                            ]
                        )
                        illnessTracker.tapped(target: "early_warning")
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
                                .foregroundStyle(AppColour.textOnAccent)
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
                    .onAppear { illnessTracker.appeared() }
                    .onDisappear { illnessTracker.disappeared() }
                }

                // Wrapped so the impression fires once for the risk block, not
                // once per row, and only when a risk actually rendered.
                if !risks.isEmpty {
                    VStack(spacing: 6) {
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
                    .onAppear { risksTracker.appeared() }
                    .onDisappear { risksTracker.disappeared() }
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
        let actionRoute = Route.todaysAction
        VStack(alignment: .leading, spacing: 12) {
            Text(Copy.Home.nextUpHeader)
                .font(DS.Typography.captionSemibold)
                .tracking(1.2)
                .foregroundStyle(AppColour.scoreGood)

            // The action is the headline; tapping opens the full detail.
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(action.title)
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(action.subtitle)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // The payoff sits in its own row rather than in the sentence:
                    // it is the one line that answers "what do I get", and keeping
                    // it out of the paragraph stops the reason growing back into
                    // the four-sentence block this card used to show.
                    if !action.expectedBenefit.isEmpty {
                        Label(action.expectedBenefit, systemImage: "arrow.up.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.scoreGood)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, DS.space1 + 2)
                            .padding(.horizontal, DS.space2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                AppColour.scoreGood.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                            )
                            .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                actionMarkDoneButton(action: action)
                actionRemindButton(action: action)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal, DS.screenPadding)
        .accessibilityIdentifier("home.todaysActionCard")
        .onAppear {
            actionDoneToday = DailyActionCompletion.isDoneToday
        }
    }

    /// Primary green "Mark done" pill. Marks today's one thing done and records
    /// it so tomorrow morning can show whether it moved the score (loop closer).
    private func actionMarkDoneButton(action: DashboardViewModel.SmartAction) -> some View {
        Button {
            // Locked once done for the day: a mark can't be undone, it auto-resets
            // tomorrow. The guard lives inside `markDone` so a wrist tap earlier in
            // the day cannot be overwritten from here.
            DailyActionCompletion.markDone(
                actionTitle: action.title,
                actionIcon: action.icon,
                source: "next_up_mark_done"
            )
            actionDoneToday = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: actionDoneToday ? "checkmark.circle.fill" : "checkmark")
                    .font(DS.Typography.captionSemibold)
                Text(actionDoneToday ? Copy.Home.nextUpMarkedDone : Copy.Home.nextUpMarkDone)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .foregroundStyle(actionDoneToday ? AppColour.textOnAccent : AppColour.scoreGood)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                actionDoneToday
                    ? AnyShapeStyle(AppColour.success)
                    : AnyShapeStyle(AppColour.scoreGood.opacity(0.15)),
                in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: actionDoneToday) { _, new in new }
        .accessibilityIdentifier("home.action.markDone")
    }

    /// Label for the remind pill. Past the reminder time the scheduler rolls to
    /// tomorrow, so the pill must not offer a time that has already gone by.
    private var actionRemindLabel: String {
        let time = ActionReminderScheduler.timeLabel()
        return ActionReminderScheduler.firesTomorrow()
            ? Copy.Home.nextUpRemindTomorrow(time)
            : Copy.Home.nextUpRemind(time)
    }

    /// Ghost "Remind 9:30" pill. Schedules a one-off reminder for the action.
    private func actionRemindButton(action: DashboardViewModel.SmartAction) -> some View {
        Button {
            Task {
                let ok = await ActionReminderScheduler.schedule(action: action.title)
                actionReminderSet = ok
                AppAnalytics.shared.trackBlockTap(
                    title: action.title, type: .homeDailyAction, screen: .home,
                    metadata: ["source": "next_up_remind", "set": "\(ok)"])
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: actionReminderSet ? "bell.fill" : "clock")
                    .font(DS.Typography.captionSemibold)
                Text(actionReminderSet ? Copy.Home.nextUpReminderSet : actionRemindLabel)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .foregroundStyle(AppColour.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(AppColour.surfaceSubtle, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.action.remind")
    }

    // MARK: - First Launch Loading

    @State private var firstLaunchIconScale: CGFloat = 0.8
    @State private var firstLaunchDotCount = 0
    @State private var firstLaunchAppeared = false
    @State private var firstLaunchDotTimer = RepeatTimer()

    private var firstLaunchPhase: (icon: String, text: String, color: Color) {
        switch viewModel.ui.syncPhase {
        case .idle, .importing:
            return ("brain.head.profile", Copy.Home.syncingHealthData, AppColour.info)
        case .analyzing:
            let points = viewModel.analysis.dataDepth.totalDataPoints
            let label = points > 0 ? Copy.Home.analyzingDataPoints(points) : Copy.Home.analyzingYourData
            return ("brain.head.profile", label, AppColour.info)
        case .discovering:
            return ("sparkles", Copy.Home.discoveringPatterns, AppColour.info)
        case .complete:
            return ("checkmark.circle.fill", Copy.Home.ready, AppColour.success)
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
                Button(Copy.Home.openJournalEntryButton) { showJournalEntry = true }
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
    /// Names the blocked surface, so the six Home walls stay separable instead of
    /// collapsing into one paywall_viewed(source: "soft_lock_home").
    let feature: String
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
                .onTapGesture {
                    AppAnalytics.shared.trackPremiumFeatureAttempted(feature: feature, screen: .home)
                    onTap()
                }
        } else {
            content
        }
    }
}

private extension View {
    func softLocked(_ isLocked: Bool, feature: String, onTap: @escaping () -> Void) -> some View {
        modifier(SoftLockModifier(isLocked: isLocked, feature: feature, onTap: onTap))
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
