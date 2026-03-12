import SwiftUI
import SwiftData
import AppIntents

/// Main home screen composing visual hero, key metrics, period trends, categories, and compact alerts
struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var homeRefreshTimer: Timer?
    @State private var weeklyReviewViewModel: WeeklyReviewViewModel?
    @State private var showScoreGuide = false
    // Section trackers
    @State private var recoveryTracker = SectionTracker(section: .homeRecovery, tab: .home)
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var bodyInsightsTracker = SectionTracker(section: .homeBodyInsights, tab: .home)
    @State private var risksTracker = SectionTracker(section: .homeRisks, tab: .home)
    @State private var weeklyReviewTracker = SectionTracker(section: .homeWeeklyReview, tab: .home)


    var body: some View {
        Group {
            if viewModel.isLoading {
                if viewModel.isFirstLaunchSync {
                    firstLaunchLoadingView
                } else {
                    LoadingView("Analyzing your health data...")
                }
            } else if let error = viewModel.errorMessage {
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
            get: { viewModel.showDiscovery },
            set: { if !$0 { viewModel.dismissDiscovery() } }
        )) {
            DiscoveryView(
                discoveries: viewModel.discoveries,
                dataDepth: viewModel.dataDepth,
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
            startHomeRefresh()
            AppAnalytics.shared.trackFeatureOpen(.home)
        }
        .onDisappear {
            stopHomeRefresh()
            stopFirstLaunchDotTimer()
            AppAnalytics.shared.trackFeatureClose(.home)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                startHomeRefresh()
            } else {
                stopHomeRefresh()
                stopFirstLaunchDotTimer()
            }
        }
    }

    /// Periodically refresh home data — uses tiered polling to minimize HealthKit queries.
    /// Fast-changing data (steps, calories) every 60s; slow-changing (sleep, workout) every 10min.
    /// If timeSeries is empty (bad initial sync), retries the full sync instead of lightweight fetches.
    private static let minHomeRefreshInterval: TimeInterval = 60
    private func startHomeRefresh() {
        homeRefreshTimer?.invalidate()
        let requestedInterval = TimeInterval(RemoteConfigManager.shared.homeRefreshIntervalSeconds)
        let interval = max(requestedInterval, Self.minHomeRefreshInterval)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if viewModel.needsSyncRetry {
                Task { await viewModel.retrySyncIfNeeded() }
            } else {
                liveViewModel.fetchHomeDataTiered()
            }
        }
        timer.tolerance = min(10, interval * 0.2)
        homeRefreshTimer = timer
    }


    private func stopHomeRefresh() {
        homeRefreshTimer?.invalidate()
        homeRefreshTimer = nil
    }

    /// Lazily created and reused WeeklyReviewViewModel
    private func getOrCreateWeeklyReviewVM() -> WeeklyReviewViewModel {
        if let existing = weeklyReviewViewModel { return existing }
        let vm = WeeklyReviewViewModel(dashboardViewModel: viewModel)
        weeklyReviewViewModel = vm
        return vm
    }

    private var hasData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    /// Only show the "Connect Your Health Data" empty state after the initial load
    /// has completed AND there is genuinely no data. This prevents the empty state
    /// from flashing during startup before HealthKit data has been loaded.
    private var shouldShowEmptyState: Bool {
        viewModel.hasCompletedInitialLoad && !hasData
    }

    private var homeContent: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // 1. Greeting header — context-aware with recovery state
                CoachGreetingView(
                    showSettings: $showSettings,
                    streakDays: SessionTracker.shared.streakDays,
                    scoreChangeFromYesterday: viewModel.scoreChangeFromYesterday,
                    currentScore: hasData ? viewModel.overallScore.score : nil,
                    recoveryState: hasData ? viewModel.recoveryState : nil,
                    onTapScoreInfo: { showScoreGuide = true }
                )
                .padding(.top, 12)

                if shouldShowEmptyState {
                    connectHealthView
                } else if hasData {
                    // ── Above the fold (matches design: Recovery → Vitality + Sleep) ──

                    // 1. Recovery Hero — readiness score
                    RecoveryHeroCard(
                        score: viewModel.overallScore.score,
                        recoveryLabel: viewModel.recoveryState.label,
                        dayType: viewModel.dayClassification,
                        scoreDelta: viewModel.scoreChangeFromYesterday,
                        onTap: { showScoreGuide = true }
                    )
                    .onAppear { recoveryTracker.appeared() }
                    .onDisappear { recoveryTracker.disappeared() }

                    // 2. Today's Action — single source of truth for what to do
                    primaryActionCard
                        .padding(.top, 8)

                    // 3. Vitality Age card
                    VitalityCard(
                        scorer: viewModel.vitalityScorer,
                        onTap: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Vitality Age",
                                type: .recoveryCard,
                                screen: .home,
                                metadata: ["destination": "vitality_detail"]
                            )
                            navigationPath.append("vitalityDetail")
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // 4. Sleep Coach Card
                    if let sleepNeed = viewModel.sleepNeedCalculator.currentNeed {
                        SleepCoachCard(
                            hoursNeeded: sleepNeed.totalHoursNeeded,
                            bedtime: sleepNeed.recommendedBedtime.map {
                                $0.formatted(date: .omitted, time: .shortened)
                            },
                            debtHours: {
                                guard let debt = viewModel.sleepDebtTracker.currentDebt,
                                      debt.totalDebtHours > 0.5 else { return nil }
                                return debt.totalDebtHours
                            }(),
                            onTap: {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "Sleep Coach",
                                    type: .sleepCard,
                                    screen: .home,
                                    metadata: ["destination": "sleep_coach"]
                                )
                                navigationPath.append("sleepCoach")
                            }
                        )
                        .padding(.top, 8)
                    }

                    // 5. Strain Card
                    StrainCard(
                        strainValue: viewModel.strainScorer.currentStrain,
                        strainLevel: viewModel.strainScorer.strainLevel,
                        zoneMinutes: viewModel.strainScorer.zoneMinutes,
                        onTap: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Strain",
                                type: .recoveryCard,
                                screen: .home,
                                metadata: ["destination": "strain_detail"]
                            )
                            navigationPath.append("strainDetail")
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // 6. Stress Card
                    if let stress = viewModel.stressScorer.currentStress {
                        StressCard(
                            stressScore: stress.score,
                            stressLevel: stress.level.displayName,
                            levelColor: stress.level.color,
                            trend: viewModel.stressScorer.stressTrend.rawValue,
                            onTap: {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "Stress",
                                    type: .recoveryCard,
                                    screen: .home,
                                    metadata: ["destination": "stress_monitor"]
                                )
                                navigationPath.append("stressMonitor")
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // 7. Cycle Phase Card (female users with cycle data)
                    if let cycle = viewModel.menstrualCycleTracker.currentCycle {
                        CyclePhaseCard(
                            phaseName: cycle.currentPhase.displayName,
                            phaseIcon: cycle.currentPhase.icon,
                            phaseColor: cycle.currentPhase.color,
                            dayInCycle: cycle.dayInCycle,
                            cycleLength: cycle.cycleLength,
                            daysUntilPeriod: cycle.daysUntilNextPeriod ?? 0,
                            onTap: {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "Cycle Phase",
                                    type: .recoveryCard,
                                    screen: .home,
                                    metadata: ["destination": "cycle_detail"]
                                )
                                navigationPath.append("cycleDetail")
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // ── Below the fold ──

                    // 8. Illness Warning (only when active)
                    illnessWarningCard
                        .onAppear { illnessTracker.appeared() }
                        .onDisappear { illnessTracker.disappeared() }
                        .padding(.top, 8)

                    // 9. Body Insights
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
                            navigationPath.append("insightsDetail")
                        }
                    )
                    .padding(.top, 8)
                    .onAppear { bodyInsightsTracker.appeared() }
                    .onDisappear { bodyInsightsTracker.disappeared() }

                    // 10. Health Risks — "Needs Attention"
                    todayRisksSection
                        .padding(.top, 8)
                        .onAppear { risksTracker.appeared() }
                        .onDisappear { risksTracker.disappeared() }

                    // 11. Weekly Review
                    WeeklyReviewEntryCard(
                        viewModel: getOrCreateWeeklyReviewVM()
                    ) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Weekly Review",
                            type: .weeklyReviewCard,
                            screen: .home,
                            metadata: [
                                "destination": "weekly_review",
                                "score": viewModel.overallScore.score
                            ]
                        )
                        navigationPath.append("weeklyReview")
                    }
                    .padding(.top, 8)
                    .onAppear { weeklyReviewTracker.appeared() }
                    .onDisappear { weeklyReviewTracker.disappeared() }

                    // 12. Level & Streaks
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
                            navigationPath.append("achievements")
                        }
                    )
                    .padding(.top, 8)

                    // 13. Journal prompt — contextual check-in (evening only)
                    journalPromptCard
                        .padding(.top, 8)

                    // AI confidence pill — subtle, near footer
                    DataConfidenceBadge(
                        daysOfData: viewModel.dataDepth.daysOfData,
                        metricsTracked: viewModel.dataDepth.metricsTracked
                    )
                    .padding(.top, 8)

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

    // MARK: - Empty State — Connect Health Data

    private var connectHealthView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)

            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Connect Your Health Data")
                    .font(.title3.weight(.semibold))

                Text("Laso reads from Apple Health, which syncs with your wearable automatically. No extra setup needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Supported devices — dynamic from SupportedDevice
            VStack(alignment: .leading, spacing: 14) {
                Text("Works with")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                ForEach(SupportedDevice.discoverableDevices.prefix(6)) { device in
                    deviceRow(
                        icon: device.systemImageName,
                        name: device.displayName,
                        detail: device == .appleWatch
                            ? "Syncs automatically"
                            : "Via \(device.companionAppName) app",
                        color: device.iconColor
                    )
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // How to connect
            VStack(alignment: .leading, spacing: 14) {
                Text("How to connect")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal)

                stepRow(number: 1, text: "Open the Settings app on your iPhone")
                stepRow(number: 2, text: "Tap Health → Data Access & Devices")
                stepRow(number: 3, text: "Enable your wearable's companion app")
                stepRow(number: 4, text: "Come back here — data appears automatically")
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Manage Devices link
            NavigationLink {
                ConnectedDevicesView(
                    viewModel: ConnectedDevicesViewModel(
                        deviceSourceManager: deviceSourceManager,
                        healthKitManager: viewModel.healthKitManager
                    )
                )
            } label: {
                Label("Manage Devices", systemImage: "gear")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalytics.shared.trackBlockTap(
                    title: "Manage Devices",
                    type: .emptyStateManageDevices,
                    screen: .home,
                    metadata: [
                        "destination": "connected_devices",
                        "source": "empty_state"
                    ]
                )
            })

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Refresh",
                    type: .emptyStateRefresh,
                    screen: .home,
                    metadata: [
                        "source": "empty_state"
                    ]
                )
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)

            Spacer()
        }
    }

    private func deviceRow(icon: String, name: String, detail: String, color: Color = .blue) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.blue, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    // MARK: - Illness Warning Card

    @ViewBuilder
    private var illnessWarningCard: some View {
        if let warning = viewModel.topIllnessWarning {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                    Text("Early Warning")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                    Spacer()
                    // severity badge
                    Text(warning.severity == .critical ? "High" : warning.severity == .warning ? "Moderate" : "Low")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(warning.severity == .critical ? .red : warning.severity == .warning ? .orange : .yellow, in: Capsule())
                }

                Text(warning.narrative)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)

                // Show active signals as pills
                HStack(spacing: 6) {
                    ForEach(warning.activeSignals, id: \.metric) { signal in
                        HStack(spacing: 3) {
                            Image(systemName: signal.metric.systemImageName)
                                .font(.caption2)
                            Text(signal.metric.displayName)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1), in: Capsule())
                    }
                }
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.red.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Today Health Risks Section

    @ViewBuilder
    private var todayRisksSection: some View {
        let risks = viewModel.todayHealthRisks
        if !risks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Health Risks")
                    .font(.headline)
                    .padding(.horizontal)

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
                        riskRow(risk)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func riskRow(_ risk: HealthRisk) -> some View {
        HStack(spacing: 12) {
            Image(systemName: risk.riskType.systemImageName)
                .font(.title3)
                .foregroundStyle(risk.riskGrade.color)
                .frame(width: 36, height: 36)
                .background(risk.riskGrade.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(risk.riskType.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(risk.riskGrade.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(risk.riskGrade.color)
            }

            Spacer()

            // Mini gauge
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: Double(risk.level) / 100.0)
                    .stroke(risk.riskGrade.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)
                Text("\(risk.level)")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - Today's Action Card (single source of truth)

    @ViewBuilder
    private var primaryActionCard: some View {
        let action = viewModel.smartDailyAction(liveVM: liveViewModel)
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: action.title,
                type: .homeDailyAction,
                screen: .home,
                metadata: [
                    "source": action.source,
                    "recovery_state": viewModel.recoveryState.rawValue
                ]
            )
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Today's Action")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                HStack(spacing: 12) {
                    Image(systemName: action.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(DS.scoreColor(viewModel.overallScore.score), in: RoundedRectangle(cornerRadius: 10))

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
            NavigationLink(value: "journalEntry") {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("How was today?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("A quick check-in helps track patterns over time")
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

    static func recoveryLabel(_ score: Int) -> String {
        switch score {
        case 80...100: return "Fully Recovered"
        case 60..<80: return "Well Recovered"
        case 40..<60: return "Moderate"
        case 20..<40: return "Fatigued"
        default: return "Strained"
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
    @State private var firstLaunchDotTimer: Timer?

    private var firstLaunchPhase: (icon: String, text: String, color: Color) {
        switch viewModel.syncPhase {
        case .idle, .importing:
            return ("brain.head.profile", "Syncing your last 1 years of health data", .purple)
        case .analyzing:
            let points = viewModel.dataDepth.totalDataPoints
            let label = points > 0 ? "Analyzing \(points) data points" : "Analyzing your data"
            return ("brain.head.profile", label, .purple)
        case .discovering:
            return ("sparkles", "Discovering patterns", .orange)
        case .complete:
            return ("checkmark.circle.fill", "Ready", .green)
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
                    .animation(.easeInOut(duration: 0.3), value: viewModel.syncPhase)

                Text("This only happens once")
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
        stopFirstLaunchDotTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard firstLaunchAppeared else {
                timer.invalidate()
                return
            }
            firstLaunchDotCount = (firstLaunchDotCount % 3) + 1
        }
        timer.tolerance = 0.1
        firstLaunchDotTimer = timer
    }

    private func stopFirstLaunchDotTimer() {
        firstLaunchDotTimer?.invalidate()
        firstLaunchDotTimer = nil
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Unable to Load Data")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
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
