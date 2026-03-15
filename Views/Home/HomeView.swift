import SwiftUI
import SwiftData
import AppIntents

struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var homeRefreshTimer = RepeatTimer()
    @State private var readinessRefreshTimer = RepeatTimer()
    @State private var weeklyReviewViewModel: WeeklyReviewViewModel?
    @State private var showScoreGuide = false
    @State private var maxScrollDepth: Int = 0
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
            ScoreGuideSheet()
        }
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .home)
            AppAnalytics.shared.trackActivationMilestone(.firstPullToRefresh)
            AppAnalytics.shared.trackCoreAction(.pulledToRefresh, screen: .home)
            await viewModel.refresh()
            liveViewModel.fetchHomeData()
        }
        .sensoryFeedback(.success, trigger: viewModel.lastRefresh)
        .onAppear {
            ensureWeeklyReviewVM()
            startHomeRefresh()
            startReadinessRefresh()
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                startHomeRefresh()
                startReadinessRefresh()
                // Immediately refresh readiness on foreground return
                liveViewModel.fetchHomeData()
            } else {
                stopHomeRefresh()
                stopReadinessRefresh()
                stopFirstLaunchDotTimer()
            }
        }
    }

    /// Periodically refresh home data — uses tiered polling to minimize HealthKit queries.
    /// Fast-changing data (steps, calories) every 60s; slow-changing (sleep, workout) every 10min.
    /// If timeSeries is empty (bad initial sync), retries the full sync instead of lightweight fetches.
    private static let minHomeRefreshInterval: TimeInterval = 60
    private func startHomeRefresh() {
        let requestedInterval = TimeInterval(RemoteConfigManager.shared.homeRefreshIntervalSeconds)
        let interval = max(requestedInterval, Self.minHomeRefreshInterval)
        homeRefreshTimer.start(interval: interval) {
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

    /// Live readiness score — falls back to daily score when no readiness data is available
    private var liveReadinessScore: Int {
        liveViewModel.recovery.readinessScore ?? viewModel.overallScore.score
    }

    /// Delta from the daily baseline score (positive = above baseline, negative = below)
    private var readinessDelta: Int? {
        guard let readiness = liveViewModel.recovery.readinessScore else {
            return viewModel.scores.scoreChangeFromYesterday
        }
        let delta = readiness - viewModel.overallScore.score
        return delta == 0 ? nil : delta
    }

    private static let readinessRefreshInterval: TimeInterval = 30 * 60

    private func startReadinessRefresh() {
        readinessRefreshTimer.start(interval: Self.readinessRefreshInterval, tolerance: 60) {
            liveViewModel.fetchHomeData()
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
            VStack(spacing: 0) {
                // 1. Greeting header — context-aware with recovery state
                CoachGreetingView(
                    showSettings: $showSettings,
                    streakDays: SessionTracker.shared.streakDays,
                    scoreChangeFromYesterday: viewModel.scores.scoreChangeFromYesterday,
                    currentScore: hasData ? liveReadinessScore : nil,
                    recoveryState: hasData ? DashboardViewModel.RecoveryState(score: liveReadinessScore) : nil,
                    onTapScoreInfo: { showScoreGuide = true }
                )
                .padding(.top, 12)

                if shouldShowEmptyState {
                    connectHealthView
                } else if hasData {
                    // ── Above the fold ──

                    // 1. Recovery Hero — live readiness score (updates every 30 min)
                    RecoveryHeroCard(
                        score: liveReadinessScore,
                        dailyScore: viewModel.overallScore.score,
                        recoveryLabel: HomeView.recoveryLabel(liveReadinessScore),
                        dayType: DashboardViewModel.RecoveryState(score: liveReadinessScore).dayType,
                        scoreDelta: readinessDelta,
                        onTap: { showScoreGuide = true }
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

                    // 2. Today's Action — single source of truth for what to do
                    primaryActionCard
                        .padding(.top, 8)

                    // 3. Compact alert banner (illness + health risks)
                    compactAlertBanner
                        .padding(.top, 8)
                        .onAppear { illnessTracker.appeared(); risksTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 20) }
                        .onDisappear { illnessTracker.disappeared(); risksTracker.disappeared() }

                    // 4. Metric Strip — horizontal scroll replacing 6 vertical cards
                    MetricStripView(tiles: buildMetricTiles()) { tile in
                        AppAnalytics.shared.trackBlockTap(
                            title: tile.label,
                            type: .recoveryCard,
                            screen: .home,
                            metadata: ["destination": tile.id]
                        )
                        navigationPath.append(tile.route)
                    }
                    .padding(.top, 12)

                    // 5. Level & Streaks — gamification (Endowed Progress)
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

    // MARK: - Empty State — Waiting For First Sync

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

    // MARK: - Metric Strip Tile Builder

    private func buildMetricTiles() -> [MetricTile] {
        var tiles: [MetricTile] = []

        // Vitality
        let vDelta = viewModel.vitalityScorer.delta
        let vBadge: String
        if vDelta < 0 { vBadge = "\(abs(vDelta))y younger" }
        else if vDelta > 0 { vBadge = "\(vDelta)y older" }
        else { vBadge = "On track" }
        let vColor: Color = vDelta <= 0 ? .green : (vDelta <= 3 ? .orange : .red)
        tiles.append(MetricTile(
            id: "vitality_detail", icon: "figure.run", label: "Vitality",
            value: "\(viewModel.vitalityScorer.vitalityAge)",
            badge: vBadge, color: vColor, route: .vitalityDetail
        ))

        // Sleep
        if liveViewModel.sleep.hasSleepData {
            let sleepHours = liveViewModel.sleep.lastNightSleepDuration / 3600
            let h = Int(sleepHours)
            let m = Int((sleepHours - Double(h)) * 60)
            let sleepValue = h == 0 ? "\(m)m" : "\(h)h \(String(format: "%02d", m))m"
            let qualityLabel = liveViewModel.sleep.sleepQualityLabel
            let sleepTileColor: Color = qualityLabel == "Great" || qualityLabel == "Good" ? .indigo : .orange
            tiles.append(MetricTile(
                id: "sleep_coach", icon: "moon.fill", label: "Sleep",
                value: sleepValue, badge: qualityLabel, color: sleepTileColor, route: .sleepCoach
            ))
        }

        // Strain
        let strain = viewModel.strainScorer
        tiles.append(MetricTile(
            id: "strain_detail", icon: "flame.fill", label: "Strain",
            value: String(format: "%.1f", strain.currentStrain),
            badge: strain.strainLevel.displayName, color: strain.strainLevel.color, route: .strainDetail
        ))

        // Brain Health
        if let brain = viewModel.brainHealthScorer.currentScore {
            let brainColor: Color = brain.score >= 80 ? .green : brain.score >= 65 ? .blue : brain.score >= 45 ? .gray : .orange
            tiles.append(MetricTile(
                id: "brain_health", icon: "brain", label: "Brain",
                value: "\(brain.score)", badge: brain.state.displayName, color: brainColor, route: .brainHealth
            ))
        }

        // Stress
        if let stress = viewModel.stressScorer.currentStress {
            tiles.append(MetricTile(
                id: "stress_monitor", icon: "waveform.path.ecg", label: "Stress",
                value: String(format: "%.1f", stress.score),
                badge: stress.level.displayName, color: stress.level.color, route: .stressMonitor
            ))
        }

        // Cycle
        if let cycle = viewModel.menstrualCycleTracker.currentCycle {
            tiles.append(MetricTile(
                id: "cycle_detail", icon: cycle.currentPhase.icon, label: "Cycle",
                value: "Day \(cycle.dayInCycle)",
                badge: cycle.currentPhase.displayName, color: cycle.currentPhase.color, route: .cycleDetail
            ))
        }

        return tiles
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
        let text = (action.title + " " + action.subtitle).lowercased()
        if text.contains("sleep") || text.contains("bedtime") || text.contains("rest tonight") {
            return .sleepCoach
        } else if text.contains("strain") || text.contains("workout") || text.contains("exercise") || text.contains("training") {
            return .strainDetail
        } else if text.contains("recovery") || text.contains("rest") || text.contains("ease off") {
            return .insightsDetail
        }
        return .insightsDetail
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
                store: HealthDataStore(modelContainer: container)
            ),
            liveViewModel: LiveViewModel(healthKitManager: hkManager),
            deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
            navigationPath: .constant(NavigationPath()),
            showSettings: .constant(false)
        )
    }
}
