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
    @State private var showMirrorMoment = false
    @State private var showRecoveryInfo = false
    @State private var actionDoneToday = false
    @State private var actionReminderSet = false
    @State private var showShareCard = false
    /// Yesterday's marked-done action result, surfaced this morning (loop closer).
    @State private var dailyResult: DailyActionResultStore.Result?
    /// Not @State on purpose: see `ScrollDepthTracker`. Every write here
    /// used to re-run this whole body while the user was scrolling.
    @State private var scrollDepth = ScrollDepthTracker()
    /// The merged life-context affordance on the action card: false shows one
    /// line, true expands the chip picker in place.
    @State private var showContextPicker = false
    @State private var showSoftLockPaywall = false
    /// One-shot full live fetch on first appear. Without it, Home only starts the
    /// tiered refresh timers, which defer the slow tier (HRV, resting HR, sleep),
    /// so the "Why" list shows only Energy until the user pulls to refresh.
    @State private var didInitialLiveFetch = false
    // Section trackers
    @State private var recoveryTracker = SectionTracker(section: .homeRecovery, tab: .home)
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var weeklyReviewTracker = SectionTracker(section: .homeWeeklyReview, tab: .home)

    /// KEEP-KILL condition on the intraday card: before this hour the usual-day
    /// trace has no shape to compare against, so any verdict would be noise.
    private static let intradayMinimumHour = 10
    /// Founder override (KEEP-KILL): an action whose reminder lands at or after
    /// this hour is evening-anchored — a morning "Mark done" would log a thing
    /// that has not happened yet.
    private static let eveningAnchorHour = 18
    /// Under this age the footer renders a static caption. SwiftUI's relative
    /// date style ticks continuously, and a fresh timestamp does not need a
    /// live clock to be honest.
    private static let freshRefreshWindowSeconds: TimeInterval = 15 * 60


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
        // The Ask Your Data door moved off the scroll (KEEP-KILL merge list)
        // into the nav bar, so the bar is shown again after being hidden.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // The journal check-in previously had no visible entry point at
                // all: it opened only from the evening notification deep link.
                // The Daily Mirror capture lives inside it, so it needs a door
                // that exists every day, not only when a notification lands.
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Open journal check-in",
                        type: .mirrorCaptureStarted,
                        screen: .home,
                        metadata: ["source": "home_toolbar"]
                    )
                    showJournalEntry = true
                } label: {
                    Image(systemName: "camera")
                        .overlay(alignment: .topTrailing) {
                            // During a prompt quiet period the sheet stays
                            // away; this passive dot is the only reminder
                            // until today is captured. Reading `revision`
                            // subscribes this body to the manager's state.
                            if MirrorMomentManager.shared.revision >= 0,
                               MirrorMomentManager.shared.showsQuietBadge() {
                                Circle()
                                    .fill(AppColour.primary)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 3, y: -3)
                            }
                        }
                }
                .accessibilityLabel(Copy.Mirror.journalCardCTA)
                .accessibilityIdentifier("home.journalEntryButton")

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Ask Your Data",
                        type: .smartAction,
                        screen: .home,
                        metadata: ["source": "home_toolbar"]
                    )
                    if isSoftLocked {
                        AppAnalytics.shared.trackPremiumFeatureAttempted(feature: "ask_your_data", screen: .home)
                        showSoftLockPaywall = true
                    } else {
                        navigationPath.append(Route.askYourData)
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel(Copy.Home.AskYourData.title)
                .accessibilityHint(Copy.Home.opensAskYourDataHint)
                .accessibilityIdentifier("home.askYourDataButton")
            }
        }
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
                score: viewModel.overallScore?.score ?? 0,
                weakestCategoryName: weakestCategoryName,
                appStateStore: appStateStore
            )
        }
        .sheet(isPresented: $showJournalEntry) {
            JournalEntryView()
        }
        .sheet(isPresented: $showMirrorMoment) {
            MirrorMomentSheet()
        }
        // The Mirror Moment fires only after the score has rendered (an
        // arrival overlay is the most-rejected prompt pattern), at most once
        // per calendar day, and never on top of another sheet.
        .task(id: viewModel.ui.isLoading) {
            guard !viewModel.ui.isLoading else { return }
            MirrorPhotoStore.shared.syncWidgetSnapshot()
            MirrorReminderScheduler.refreshIfEnabled()
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            presentMirrorMomentIfDue()
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
            // A cold start can reach Home before the first analysis lands, and
            // the review card no longer loads itself (it renders only when a
            // review exists), so rebuild it whenever a refresh completes.
            weeklyReviewViewModel?.load()
        }
        .onAppear {
            ensureWeeklyReviewVM()
            // Loaded here, not in the entry card: the card now renders only
            // when a review exists, so its own onAppear could never run the
            // load that produces one.
            weeklyReviewViewModel?.load()
            if !didInitialLiveFetch {
                didInitialLiveFetch = true
                // Load HRV, resting HR and sleep right away so the Why list is
                // complete on first open, not after a manual refresh.
                liveViewModel.fetchHomeData()
            }
            startHomeRefresh()
            startReadinessRefresh()
            rebuildMetricTilesFromLive()
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
                    // An app kept in memory overnight never re-runs the load
                    // task, so day rollover is caught here: the first
                    // foreground of a new day is the Mirror Moment's cue.
                    if !viewModel.ui.isLoading {
                        presentMirrorMomentIfDue()
                    }
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

    /// Live readiness score. Falls back to the daily score when no readiness
    /// data is available, and stays nil when neither exists so the card can say
    /// so instead of drawing a ring around a stand-in number.
    private var liveReadinessScore: Int? {
        liveViewModel.recovery.readinessScore ?? viewModel.overallScore?.score
    }

    /// Empty strings when there is no score: the card hides the summary footer
    /// rather than narrating a number that was never computed.
    private var readinessSummary: (head: String, sub: String) {
        guard let liveReadinessScore else { return ("", "") }
        return viewModel.readinessSummary(score: liveReadinessScore)
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
                if hasData {
                    // ── Above the fold ──

                    // 1. The app's only real safety signal leads the screen
                    // when it exists (KEEP-KILL surviving-screen order), and is
                    // never blurred behind a paywall.
                    compactAlertBanner
                        .padding(.top, DS.space1)

                    // 2. Yesterday's result. When present, the proof that
                    // yesterday's action was logged leads the loop — it is the
                    // reason the user came back this morning. Hosts the share
                    // entry on up mornings (KEEP-KILL merge list).
                    if let dailyResult {
                        // No completions history exists yet (DailyActionCompletion
                        // stores a single day marker), so the aggregate line stays
                        // off rather than dressing thin data as a pattern.
                        DailyActionResultCard(result: dailyResult, aggregate: nil) {
                            DailyActionResultStore.clear()
                            withAnimation { self.dailyResult = nil }
                        }

                        if dailyResult.direction == .up, !shareTemplates.isEmpty {
                            resultShareButton
                        }
                    }

                    // 3. Next Up. the daily action leads the screen: Laso's core
                    // promise is telling you what to do next, so the step comes
                    // before the score that explains it.
                    primaryActionCard

                    // 4. Score card. live readiness score (updates every 30 min)
                    // shown as one ring plus the plain-word reasons behind it.
                    RecoveryHeroCard(
                        score: liveReadinessScore,
                        summaryHead: readinessSummary.head,
                        summarySub: readinessSummary.sub,
                        whyReasons: viewModel.recoveryWhyReasons(liveVM: liveViewModel),
                        isFallbackScore: !hasLiveReadiness,
                        isWearingWatch: liveViewModel.recovery.isWearingWatch,
                        missingSignals: viewModel.scoreFedMissingSignalNames(),
                        // When live Recovery exists the tap opens the Recovery
                        // explainer; otherwise the headline is the fallback
                        // health score so we open the matching guide.
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
                        onFixCoverage: { openHealthAppForCoverage() },
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
                    .onAppear {
                        recoveryTracker.appeared()
                        scrollDepth.record(10)
                        if let liveReadinessScore {
                            AppAnalytics.shared.trackScoreViewed(
                                score: liveReadinessScore,
                                previousScore: viewModel.scores.scoreChangeFromYesterday.map { liveReadinessScore - $0 }
                            )
                        }
                    }
                    .onDisappear { recoveryTracker.disappeared() }
                    .softLocked(isSoftLocked, feature: "home_recovery_score") { showSoftLockPaywall = true }

                    // 5. Last seven days, right under the score they are the
                    // history of. Tapping opens the full month in Biology.
                    // Today's dial is pinned to the exact score the ring above
                    // shows: the stored snapshot carries the analysis score,
                    // which is a different model from the live readiness score,
                    // and two numbers for today on one screen reads as a bug.
                    WeekScoreStrip(scoresByDay: {
                        var scores = viewModel.cachedDailyScoresByDay
                        // No score today leaves today's dial empty rather than
                        // pinning it to a number the ring above never showed.
                        if let liveReadinessScore {
                            scores[Date.cal.startOfDay(for: .now)] = liveReadinessScore
                        }
                        return scores
                    }()) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Week Strip",
                            type: .exploreCalendarDay,
                            screen: .home,
                            metadata: ["destination": "explore"]
                        )
                        NotificationCenter.default.post(name: .healthPulseNavigateToExplore, object: nil)
                    }
                    // Depth marker repointed from the deleted AskYourDataCard
                    // onto a card that always renders, so the funnel keeps its
                    // mid-scroll rung.
                    .onAppear { scrollDepth.record(40) }

                    // 6. When today actually happened, read against the user's
                    // own usual day. Hidden until the day has energy logged AND
                    // the morning has enough shape to compare against.
                    if Date.cal.component(.hour, from: Date()) >= Self.intradayMinimumHour,
                       liveViewModel.activity.intradayActiveEnergy.contains(where: { $0 > 0 }) {
                        IntradayActivityCard(
                            buckets: liveViewModel.activity.intradayActiveEnergy,
                            usualBuckets: liveViewModel.usualIntradayEnergy
                        )
                    }

                    // 7. Sleep bank. The only running total on the screen, so
                    // it sits right under the score it helps explain. Hidden
                    // entirely until the balance is big enough to act on.
                    if let bank = viewModel.sleepBank {
                        SleepBankCard(debtHours: bank.debtHours,
                                      personalBaseline: bank.personalBaseline,
                                      deficits: bank.deficits,
                                      nightsRecorded: bank.nightsRecorded)
                    }

                    // 8. Watch face complication nudge. Only when a watch is paired
                    // with the app installed and the complication is not on the face.
                    WatchComplicationCard(linkState: PhoneWatchSession.shared.linkState)

                    sectionHeader("VITALS")
                        .padding(.top, DS.space3)

                    // 9. Metric Strip. horizontal scroll replacing 6 vertical cards
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

                    // 10. Weekly Review. Header and card render together only
                    // when a review exists, so a new user never sees a heading
                    // with nothing under it.
                    if let weeklyReviewViewModel, weeklyReviewViewModel.review != nil {
                        sectionHeader("REVIEW")
                            .padding(.top, DS.space3)

                        WeeklyReviewEntryCard(viewModel: weeklyReviewViewModel) {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Weekly Review",
                                type: .weeklyReviewCard,
                                screen: .home,
                                metadata: [
                                    "destination": "weekly_review",
                                    "score": liveReadinessScore ?? 0
                                ]
                            )
                            navigationPath.append(Route.weeklyReview)
                        }
                        .onAppear { weeklyReviewTracker.appeared() }
                        .onDisappear { weeklyReviewTracker.disappeared() }
                        .softLocked(isSoftLocked, feature: "home_weekly_review") { showSoftLockPaywall = true }
                    }

                    // Last updated footer. always rendered so the user can confirm
                    // the screen is alive; falls back to a pull-to-refresh hint
                    // when no sync has happened yet (very first launch). Fresh
                    // timestamps render statically instead of ticking.
                    Group {
                        if let lastRefresh = viewModel.lastRefresh {
                            Group {
                                if Date().timeIntervalSince(lastRefresh) < Self.freshRefreshWindowSeconds {
                                    Text(Copy.Home.lastUpdatedAgo(lastRefresh))
                                } else {
                                    Copy.Home.updatedAgo(lastRefresh)
                                }
                            }
                            .accessibilityLabel(Copy.Home.lastUpdatedAgo(lastRefresh))
                        } else {
                            Copy.Home.pullToRefresh
                                .accessibilityLabel(Copy.Home.notSyncedYetAccessibility)
                        }
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    // The 90 rung moved off the review card, which now renders
                    // on review weeks only; the footer always exists.
                    .onAppear { scrollDepth.record(90) }
                } else {
                    // The empty state is the unconditional fallback for no data,
                    // so the old blank gap state (greeting over nothing) is
                    // unreachable. Startup loading is caught before homeContent.
                    connectHealthView
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 32, for: .scrollContent)
        // Attached to the scroll, not a card: both share entries (result card
        // today, future earned moments) present the same tray.
        .sheet(isPresented: $showShareCard) {
            ShareWinSheet(templates: shareTemplates)
        }
        .safeAreaInset(edge: .bottom) {
            if isSoftLocked {
                softLockBottomBar
            }
        }
    }

    /// Share entry, result-card mornings only (KEEP-KILL merge list): the hero
    /// icon is gone, and an up morning is the one earned moment left on Home.
    private var resultShareButton: some View {
        Button {
            // Entry step of the share funnel: without this the first event is
            // the Share CTA inside the sheet, so open-then-dismiss users were
            // invisible.
            AppAnalytics.shared.trackBlockTap(
                title: "Share",
                type: .shareCard,
                screen: .home,
                metadata: ["source": "daily_result", "card_type": "template"]
            )
            showShareCard = true
        } label: {
            Label(Copy.Common.shareHealthCard, systemImage: "square.and.arrow.up")
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(AppColour.info)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.screenPadding + DS.cardPadding)
        .accessibilityIdentifier("home.dailyResultCard.share")
    }

    /// Opens the Health app so the user can fix a missing read permission.
    /// `x-apple-health://` is the public Health scheme; if the open fails the
    /// app settings screen is the fallback door. Never Laso's own settings —
    /// that was the coverage card's wrong-door CTA (KEEP-KILL merge list).
    private func openHealthAppForCoverage() {
        AppAnalytics.shared.trackBlockTap(
            title: "Check Health settings",
            type: .errorRetry,
            screen: .home,
            metadata: ["source": "hero_coverage_line"]
        )
        guard let healthURL = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(healthURL) { success in
            if !success, let settings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settings)
            }
        }
    }

    // MARK: - Empty State. Waiting For First Sync

    // The empty-state impression fires inside HomeConnectHealthView itself;
    // a second trackEmptyStateShown here double-counted the churn funnel.
    private var connectHealthView: some View {
        HomeConnectHealthView(
            deviceSourceManager: deviceSourceManager,
            healthKitManager: viewModel.healthKitManager
        ) {
            await viewModel.refresh()
            liveViewModel.fetchHomeData()
        }
    }

    // MARK: - Compact Alert Banner (illness early warning only)

    // The risk rows were deleted (KEEP-KILL): a near-open >=15/100 filter must
    // not ride the strict illness gate's credibility in the same red card. The
    // narrative renders at full body size — a health warning is never the line
    // that shrinks or truncates.
    @ViewBuilder
    private var compactAlertBanner: some View {
        if let warning = viewModel.analysis.topIllnessWarning {
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
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.danger)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Home.earlyWarning)
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(AppColour.danger)
                        Text(warning.narrative)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                .padding(DS.cardPadding)
            }
            .buttonStyle(.plain)
            .cardStyle(tint: AppColour.danger)
            .padding(.horizontal, DS.screenPadding)
            .onAppear { illnessTracker.appeared() }
            .onDisappear { illnessTracker.disappeared() }
        }
    }

    // MARK: - Next Up Card (single source of truth for what to do)

    /// Icons the advisor only assigns to bedtime and wind-down actions. A walk
    /// at noon is honestly done at noon, so the evening gate must key on what
    /// the action IS, not on the reminder hour — the scheduler's default is an
    /// evening time for every action, which gated daytime actions too.
    private static let eveningAnchoredIcons: Set<String> = ["bed.double.fill", "moon.zzz.fill", "moon.fill"]

    private func isEveningAnchored(_ action: DashboardViewModel.SmartAction) -> Bool {
        Self.eveningAnchoredIcons.contains(action.icon)
    }

    private var isEveningNow: Bool {
        Date.cal.component(.hour, from: Date()) >= Self.eveningAnchorHour
    }

    /// Mark done waits for the evening on evening-anchored actions: an 8am tap
    /// would log a thing that has not happened yet.
    private func markDoneWaitsForEvening(_ action: DashboardViewModel.SmartAction) -> Bool {
        isEveningAnchored(action) && !isEveningNow
    }

    @ViewBuilder
    private var primaryActionCard: some View {
        let action = viewModel.smartDailyAction(liveVM: liveViewModel)
        let actionRoute = Route.todaysAction
        VStack(alignment: .leading, spacing: 12) {
            if actionDoneToday {
                // Done state: the card gives the slot back, keeping only the
                // one-line confirmation.
                actionDoneLoggedRow(action: action)
            } else {
                Text(isEveningAnchored(action) && isEveningNow ? Copy.Home.nextUpHeaderTonight : Copy.Home.nextUpHeader)
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

                        // The advisor's hardcoded default is never dressed as
                        // personal advice (KEEP-KILL fix row).
                        if action.isFallback {
                            Text(Copy.Home.nextUpFallbackNote)
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

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

                // Before the evening the honest verb is Remind, so it leads and
                // Mark done waits ghosted; in the evening Done leads.
                HStack(spacing: 8) {
                    if markDoneWaitsForEvening(action) {
                        actionRemindButton(action: action)
                        actionMarkDoneButton(action: action)
                    } else {
                        actionMarkDoneButton(action: action)
                        actionRemindButton(action: action)
                    }
                }

                if markDoneWaitsForEvening(action) {
                    Text(Copy.Home.nextUpDoneTonightHint)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                }
            }

            lifeContextSection
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal, DS.screenPadding)
        .accessibilityIdentifier("home.todaysActionCard")
        // On the card, not the button: marking done swaps the button subtree
        // out for the confirmation row, which would drop the haptic with it.
        .sensoryFeedback(.success, trigger: actionDoneToday) { _, new in new }
        .onChange(of: viewModel.lifeContextStore.active) { _, _ in
            // The action is cached for the day, so without this the card keeps
            // yesterday's advice after a toggle.
            viewModel.invalidateDailyActionCache()
        }
        .onAppear {
            actionDoneToday = DailyActionCompletion.isDoneToday
        }
    }

    /// The collapsed confirmation after Mark done. One row, no buttons: the
    /// loop's next beat is tomorrow's result card, not more chrome today.
    private func actionDoneLoggedRow(action: DashboardViewModel.SmartAction) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textPrimary)
                    .lineLimit(1)
                Text(Copy.Home.nextUpDoneLogged)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.action.doneLogged")
    }

    /// Primary green "Mark done" pill. Marks today's one thing done and records
    /// it so tomorrow morning can show whether it moved the score (loop closer).
    /// Ghosted until the evening for evening-anchored actions.
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
                Image(systemName: "checkmark")
                    .font(DS.Typography.captionSemibold)
                Text(Copy.Home.nextUpMarkDone)
                    .font(DS.Typography.subheadlineSemibold)
            }
            .foregroundStyle(markDoneWaitsForEvening(action) ? AppColour.textTertiary : AppColour.scoreGood)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                markDoneWaitsForEvening(action)
                    ? AnyShapeStyle(AppColour.surfaceSubtle)
                    : AnyShapeStyle(AppColour.scoreGood.opacity(0.15)),
                in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .disabled(markDoneWaitsForEvening(action))
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

    // MARK: - Life Context (merged onto the action card)

    /// Ordered active contexts. `store.active` is a Set, so `allCases` order
    /// keeps the line stable across renders.
    private var activeLifeContexts: [LifeContextStore.Context] {
        LifeContextStore.Context.allCases.filter { viewModel.lifeContextStore.isActive($0) }
    }

    /// The merged LifeContextChipRow (KEEP-KILL merge list). Idle: one line.
    /// Tapped: the chips inline. Active: the adjusted-for line that reopens the
    /// picker, so the card whose advice a context overrides is where it lives.
    @ViewBuilder
    private var lifeContextSection: some View {
        let store = viewModel.lifeContextStore
        let active = activeLifeContexts

        Divider().overlay(AppColour.borderLow)

        if showContextPicker {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.space2) {
                    ForEach(LifeContextStore.Context.allCases, id: \.self) { context in
                        lifeContextChip(context)
                    }
                }
            }
            .accessibilityIdentifier("home.lifeContextChips")
        } else if !active.isEmpty {
            Button {
                // The picker-open step was invisible in the funnel, so chip
                // toggle rates could not be computed against opens.
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["source": "context_picker_open", "active_count": active.count]
                )
                showContextPicker = true
            } label: {
                Text(Copy.Home.nextUpContextAdjusted(active.map(\.displayName).sentenceList))
                    .font(DS.Typography.footnoteMedium)
                    .foregroundStyle(AppColour.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.lifeContext.active")
        } else {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["source": "context_picker_open", "active_count": 0]
                )
                showContextPicker = true
            } label: {
                Text(Copy.Home.nextUpContextPrompt)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Copy.Home.contextAddHint)
            .accessibilityIdentifier("home.lifeContext.prompt")
        }

        // Nothing switches itself off, so the only thing keeping a stale
        // context from suppressing advice for months is asking.
        ForEach(store.needingConfirmation(), id: \.self) { context in
            lifeContextConfirmRow(context)
        }
    }

    private func lifeContextChip(_ context: LifeContextStore.Context) -> some View {
        let store = viewModel.lifeContextStore
        let isOn = store.isActive(context)
        let tint = context.requiresRest ? AppColour.danger : AppColour.accent

        return Button {
            store.toggle(context)
            AppAnalytics.shared.trackBlockTap(
                title: context.rawValue,
                type: .homeDailyAction,
                screen: .home,
                metadata: ["life_context": context.rawValue, "turned_on": !isOn]
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: context.systemImage)
                    .font(DS.Typography.caption)
                Text(lifeContextChipLabel(for: context, isOn: isOn))
                    .font(DS.Typography.footnoteMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? tint : AppColour.textSecondary)
            .padding(.horizontal, DS.space3)
            .padding(.vertical, DS.space2)
            .background(
                Capsule().fill(isOn ? tint.opacity(DS.badgeBg) : AppColour.surfaceRaised)
            )
            .overlay(
                Capsule().strokeBorder(isOn ? tint.opacity(0.45) : AppColour.borderLow, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lifeContextChipLabel(for: context, isOn: isOn))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityHint(Copy.Home.contextAddHint)
    }

    /// An active chip shows the day it was switched on. That is a fact we know;
    /// an end date would be a guess about how long the person stays injured.
    private func lifeContextChipLabel(for context: LifeContextStore.Context, isOn: Bool) -> String {
        guard isOn, let start = viewModel.lifeContextStore.startDate(for: context) else {
            return context.displayName
        }
        return Copy.Home.contextSince(context.displayName, start.formatted(.dateTime.day().month(.abbreviated)))
    }

    private func lifeContextConfirmRow(_ context: LifeContextStore.Context) -> some View {
        HStack(spacing: DS.space2) {
            Text(Copy.Home.contextStillOn(context.displayName.lowercasedFirst))
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)

            Spacer(minLength: 8)

            Button(Copy.Home.contextStillYes) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context Confirmed",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["life_context": context.rawValue, "still_on": true]
                )
                viewModel.lifeContextStore.confirm(context)
            }
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(AppColour.accent)

            Button(Copy.Home.contextStillNo) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Life Context Confirmed",
                    type: .homeDailyAction,
                    screen: .home,
                    metadata: ["life_context": context.rawValue, "still_on": false]
                )
                viewModel.lifeContextStore.toggle(context)
            }
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(AppColour.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("home.lifeContext.confirm")
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
    /// Present the Mirror Moment when the manager's rules allow it and no
    /// other sheet holds the screen. The manager owns every frequency rule;
    /// this only owns "nothing else is up right now".
    private func presentMirrorMomentIfDue() {
        guard !viewModel.ui.showDiscovery, !showJournalEntry, !showScoreGuide,
              !showSoftLockPaywall, !showRecoveryInfo, !showShareCard,
              !showMirrorMoment else { return }
        let manager = MirrorMomentManager.shared
        guard manager.shouldShow(cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera)) else { return }
        // The sheet stamps the day itself in onAppear: stamping here would
        // burn the daily impression even when presentation loses a race to a
        // root-level sheet the guard above cannot see.
        showMirrorMoment = true
    }

    @ViewBuilder
    private var uiTestHiddenTriggers: some View {
        if UITestMode.isEnabled {
            VStack(spacing: 0) {
                Button(Copy.Home.openScoreGuideButton) { showScoreGuide = true }
                    .accessibilityIdentifier("uitest.openScoreGuide")
                Button(Copy.Home.openJournalEntryButton) { showJournalEntry = true }
                    .accessibilityIdentifier("uitest.openJournalEntry")
                Button(Copy.Home.openMirrorMomentButton) { showMirrorMoment = true }
                    .accessibilityIdentifier("uitest.openMirrorMoment")
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
