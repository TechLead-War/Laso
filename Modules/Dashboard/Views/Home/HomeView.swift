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
    @State private var showJournalEntry = false
    @State private var showMirrorMoment = false
    @State private var showMirrorCapture = false
    @State private var showShareCard = false
    /// Yesterday's marked-done action result, surfaced this morning (loop closer).
    @State private var dailyResult: DailyActionResultStore.Result?
    /// Not @State on purpose: see `ScrollDepthTracker`. Every write here
    /// used to re-run this whole body while the user was scrolling.
    @State private var scrollDepth = ScrollDepthTracker()
    /// The merged life-context affordance on the moves card: false shows one
    /// line, true expands the chip picker in place.
    @State private var showContextPicker = false
    @State private var showSoftLockPaywall = false
    /// One-shot full live fetch on first appear. Without it, Home only starts the
    /// tiered refresh timers, which defer the slow tier (HRV, resting HR, sleep),
    /// so the brief reads only Energy until the user pulls to refresh.
    @State private var didInitialLiveFetch = false
    // Section trackers
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var verdictTracker = SectionTracker(section: .homeVerdict, tab: .home)
    @State private var statusTracker = SectionTracker(section: .homeStatus, tab: .home)
    @State private var driversTracker = SectionTracker(section: .homeDrivers, tab: .home)
    @State private var movesTracker = SectionTracker(section: .homeMoves, tab: .home)
    @State private var focusTracker = SectionTracker(section: .homeFocus, tab: .home)

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
                // The capture card sits six sections down the scroll, which is
                // past two full screens, so on first open there is nothing about
                // the Daily Mirror visible at all. This is the door that is
                // always on screen. Hidden without a camera, matching the card.
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    let capturedToday = MirrorPhotoStore.shared.hasPhoto(on: .now)
                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Capture today's you",
                            type: .mirrorCaptureStarted,
                            screen: .home,
                            metadata: ["source": "home_toolbar", "is_retake": capturedToday]
                        )
                        showMirrorCapture = true
                    } label: {
                        Image(systemName: capturedToday ? "camera.fill" : "camera")
                            .overlay(alignment: .topTrailing) {
                                // During a prompt quiet period the sheet stays
                                // away, so this passive dot is the only reminder
                                // left until today is captured. Reading
                                // `revision` subscribes this body to the
                                // manager's state.
                                if MirrorMomentManager.shared.revision >= 0,
                                   MirrorMomentManager.shared.showsQuietBadge() {
                                    Circle()
                                        .fill(AppColour.primary)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 3, y: -3)
                                }
                            }
                    }
                    .accessibilityLabel(capturedToday ? Copy.Mirror.toolbarDoneLabel : Copy.Mirror.toolbarLabel)
                    .accessibilityHint(Copy.Mirror.toolbarHint)
                    .accessibilityIdentifier("home.mirrorCaptureButton")
                }

                // The journal check-in previously had no visible entry point at
                // all: it opened only from the evening notification deep link.
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Open journal check-in",
                        type: .smartAction,
                        screen: .home,
                        metadata: ["source": "home_toolbar", "destination": "journal_entry"]
                    )
                    showJournalEntry = true
                } label: {
                    // No mirror badge here any more. The dot means "today's photo
                    // is still missing", and it now sits on the camera that
                    // takes it rather than on the button that opens the journal.
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(Copy.Journal.logEntryTitle)
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
        // UI-test only: zero-size accessible triggers for sheets that otherwise
        // lack a stable, always-visible entry point (the journal prompt only
        // appears after 6pm).
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
        .sheet(isPresented: $showJournalEntry) {
            JournalEntryView()
        }
        .sheet(isPresented: $showMirrorMoment) {
            MirrorMomentSheet()
        }
        // fullScreenCover, not a sheet: the camera owns the screen, and this
        // matches how both existing capture entries present it.
        .fullScreenCover(isPresented: $showMirrorCapture) {
            MirrorCaptureSheet()
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
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .home)
            AppAnalytics.shared.trackActivationMilestone(.firstPullToRefresh)
            AppAnalytics.shared.trackCoreAction(.pulledToRefresh, screen: .home)
            await viewModel.refresh()
            liveViewModel.fetchHomeData()
            rebuildFromLive()
        }
        .sensoryFeedback(.success, trigger: viewModel.lastRefresh)
        .onChange(of: viewModel.lastRefresh) { _, _ in
            rebuildFromLive()
        }
        // Without this the live sleep reading only reaches the view model on
        // appear, on pull to refresh and on a completed refresh, so a night that
        // lands while Home is open is stranded until one of those fires.
        .onChange(of: liveViewModel.sleep.tileDuration) { _, _ in
            rebuildFromLive()
        }
        .onChange(of: viewModel.focusStore.revision) { _, _ in
            viewModel.rebuildDailyBrief(liveVM: liveViewModel)
        }
        .onChange(of: viewModel.lifeContextStore.active) { _, _ in
            viewModel.rebuildDailyBrief(liveVM: liveViewModel)
        }
        .onAppear {
            if !didInitialLiveFetch {
                didInitialLiveFetch = true
                // Load HRV, resting HR and sleep right away so the brief is
                // complete on first open, not after a manual refresh.
                liveViewModel.fetchHomeData()
            }
            startHomeRefresh()
            startReadinessRefresh()
            rebuildFromLive()
            refreshDailyResult()
            AppAnalytics.shared.trackFeatureOpen(.home)
        }
        .onChange(of: liveReadinessScore) { _, _ in
            // The morning lock is written in the same pass that produces this
            // score, so a change here is the signal that it may now exist.
            refreshDailyResult()
            viewModel.rebuildDailyBrief(liveVM: liveViewModel)
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
    /// data is available, and stays nil when neither exists.
    private var liveReadinessScore: Int? {
        liveViewModel.recovery.readinessScore ?? viewModel.overallScore?.score
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

    /// Compute the loop-closer result once today's morning lock exists. Guarded on
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

    /// Rebuild the brief from everything the live model holds now.
    private func rebuildFromLive() {
        viewModel.rebuildDailyBrief(liveVM: liveViewModel)
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
            .textCase(.uppercase)
            .foregroundStyle(AppColour.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.screenPadding)
            .padding(.top, DS.space3)
    }

    private var homeContent: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: DS.itemSpacing) {
                if hasData {
                    // The app's only real safety signal leads the screen when
                    // it exists, and is never blurred behind a paywall.
                    compactAlertBanner
                        .padding(.top, DS.space1)

                    if let brief = viewModel.dailyBrief {
                        briefSections(brief)
                    } else {
                        LoadingView(Copy.Home.analyzingHealthData)
                            .onAppear { viewModel.rebuildDailyBrief(liveVM: liveViewModel) }
                    }
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

    /// Open, how am I doing, what is affecting me, what do I do, is it working.
    @ViewBuilder
    private func briefSections(_ brief: DailyBrief) -> some View {
        // Yesterday's verdict leads when it exists: it is the reason the
        // person came back this morning. Hosts the share entry on up mornings.
        if let verdict = brief.verdict {
            VerdictCard(verdict: verdict) {
                viewModel.dismissVerdict(liveVM: liveViewModel)
            }
            .padding(.horizontal, DS.screenPadding)
            .onAppear { verdictTracker.appeared() }
            .onDisappear { verdictTracker.disappeared() }

            if dailyResult?.direction == .up, !shareTemplates.isEmpty {
                resultShareButton
            }
        }

        StatusCard(status: brief.status)
            .padding(.horizontal, DS.screenPadding)
            .onAppear {
                statusTracker.appeared()
                scrollDepth.record(10)
                if let score = brief.status.readiness {
                    AppAnalytics.shared.trackScoreViewed(
                        score: score,
                        previousScore: viewModel.scores.scoreChangeFromYesterday.map { score - $0 }
                    )
                }
                // The engagement sequence times its day-2 push off the first real
                // readiness sighting; a fallback daily score is not that moment.
                if liveViewModel.recovery.isWearingWatch,
                   let live = liveViewModel.recovery.readinessScore, live > 0 {
                    let seenBefore = UserDefaults.standard.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen)
                    EngagementSequenceScheduler.markActivation(seenBefore ? .secondRecoveryScore : .firstRecoveryScore)
                }
            }
            .onDisappear { statusTracker.disappeared() }
            .softLocked(isSoftLocked, feature: "home_status", screen: .home) { showSoftLockPaywall = true }

        if !brief.drivers.isEmpty {
            sectionHeader(Copy.DailyBrief.sectionAffecting)

            DriversCard(drivers: brief.drivers) { kind in
                AppAnalytics.shared.trackBlockTap(
                    title: "Driver",
                    type: .driverRow,
                    screen: .home,
                    metadata: ["driver": kind.id]
                )
                navigationPath.append(Route.driverDetail(kind))
            }
            .padding(.horizontal, DS.screenPadding)
            .onAppear { driversTracker.appeared() }
            .onDisappear { driversTracker.disappeared() }
            .softLocked(isSoftLocked, feature: "home_drivers", screen: .home) { showSoftLockPaywall = true }
        }

        sectionHeader(Copy.DailyBrief.sectionToDo)

        // Never soft-locked: the one thing to do today is the product.
        MovesCard(
            day: brief.dayMove,
            night: brief.nightMove,
            onDone: { kind in viewModel.markMoveDone(kind, liveVM: liveViewModel) },
            onRemind: { kind in remind(kind) }
        ) {
            lifeContextSection
        }
        .padding(.horizontal, DS.screenPadding)
        .onAppear {
            movesTracker.appeared()
            scrollDepth.record(40)
        }
        .onDisappear { movesTracker.disappeared() }

        if let focus = brief.focus {
            sectionHeader(Copy.DailyBrief.sectionWorking)

            FocusCard(focus: focus) {
                AppAnalytics.shared.trackBlockTap(
                    title: focus.title,
                    type: .focusCard,
                    screen: .home,
                    metadata: ["driver": focus.record.driver.id, "destination": "progress"]
                )
                NotificationCenter.default.post(name: .healthPulseNavigateToExplore, object: AppTab.progress)
            }
            .padding(.horizontal, DS.screenPadding)
            .onAppear {
                focusTracker.appeared()
                scrollDepth.record(65)
            }
            .onDisappear { focusTracker.disappeared() }
            .softLocked(isSoftLocked, feature: "home_focus", screen: .home) { showSoftLockPaywall = true }
        }

        Text(brief.footer)
            .font(DS.Typography.caption)
            .foregroundStyle(AppColour.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.screenPadding)
            .padding(.top, DS.space2)

        // Last updated footer. always rendered so the user can confirm
        // the screen is alive; falls back to a pull-to-refresh hint
        // when no sync has happened yet (very first launch). Fresh
        // timestamps render statically instead of ticking.
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
    }

    /// Arms the reminder for one move. Both schedulers ask for notification
    /// permission themselves, so a tap never silently fails.
    private func remind(_ kind: DailyMoveLog.MoveKind) {
        Task {
            switch kind {
            case .day: await viewModel.remindDayMove(liveVM: liveViewModel)
            case .night: await viewModel.remindNightMove(liveVM: liveViewModel)
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

    // MARK: - Empty State. Waiting For First Sync

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
                // One-shot scale, no repeatForever: an autoreversing repeat holds
                // the display link for the whole life of this screen, and this
                // screen is up for the entire first HealthKit import and ML pass.
                // Matches LoadingView, which already dropped the repeat.
                Circle()
                    .fill(phase.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(firstLaunchIconScale == 1.0 ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 1.2), value: firstLaunchIconScale)

                Circle()
                    .fill(phase.color.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(firstLaunchIconScale == 1.0 ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.5), value: firstLaunchIconScale)

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

    /// Present the Mirror Moment when the manager's rules allow it and no
    /// other sheet holds the screen. The manager owns every frequency rule;
    /// this only owns "nothing else is up right now".
    private func presentMirrorMomentIfDue() {
        guard !viewModel.ui.showDiscovery, !showJournalEntry,
              !showSoftLockPaywall, !showShareCard,
              !showMirrorMoment, !showMirrorCapture else { return }
        let manager = MirrorMomentManager.shared
        guard manager.shouldShow(cameraAvailable: UIImagePickerController.isSourceTypeAvailable(.camera)) else { return }
        // The sheet stamps the day itself in onAppear: stamping here would
        // burn the daily impression even when presentation loses a race to a
        // root-level sheet the guard above cannot see.
        showMirrorMoment = true
    }

    /// Zero-size, UI-test-only buttons that expose entry points for sheets the
    /// production UI does not offer as a direct tap target. Only compiled into
    /// the tree when running under `UITestMode`; in production this returns an
    /// `EmptyView` and has zero visual or accessibility impact.
    @ViewBuilder
    private var uiTestHiddenTriggers: some View {
        if UITestMode.isEnabled {
            VStack(spacing: 0) {
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
