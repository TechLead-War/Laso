import SwiftUI
import SwiftData

/// Main home screen composing visual hero, key metrics, period trends, categories, and compact alerts
struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var livePulse = false
    @State private var homeRefreshTimer: Timer?
    @State private var weeklyReviewViewModel: WeeklyReviewViewModel?
    @State private var showScoreGuide = false
    @State private var showRecoveryInfo = false

    // Section trackers
    @State private var recoveryTracker = SectionTracker(section: .homeRecovery, tab: .home)
    @State private var illnessTracker = SectionTracker(section: .homeIllness, tab: .home)
    @State private var bodyInsightsTracker = SectionTracker(section: .homeBodyInsights, tab: .home)
    @State private var trendsTracker = SectionTracker(section: .homeTrends, tab: .home)
    @State private var risksTracker = SectionTracker(section: .homeRisks, tab: .home)
    @State private var weeklyReviewTracker = SectionTracker(section: .homeWeeklyReview, tab: .home)
    @State private var historicalTracker = SectionTracker(section: .homeHistorical, tab: .home)

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
        .sheet(isPresented: $showRecoveryInfo) {
            RecoveryInfoSheet()
                .presentationDetents([.medium])
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
            livePulse = true
            startHomeRefresh()
            AppAnalytics.shared.trackFeatureOpen(.home)
            showScoreGuideIfNeeded()
        }
        .onDisappear {
            stopHomeRefresh()
            stopFirstLaunchDotTimer()
            livePulse = false
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
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showScoreGuideIfNeeded()
                }
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

    private func showScoreGuideIfNeeded() {
        guard hasData,
              !viewModel.showDiscovery,
              !UserDefaults.standard.bool(forKey: AppKeys.App.hasSeenScoreGuide) else { return }
        showScoreGuide = true
    }

    private func stopHomeRefresh() {
        homeRefreshTimer?.invalidate()
        homeRefreshTimer = nil
    }

    /// Lazily created and reused WeeklyReviewViewModel to avoid re-allocation on every body render
    private var weeklyReviewVM: WeeklyReviewViewModel {
        if let existing = weeklyReviewViewModel { return existing }
        let vm = WeeklyReviewViewModel(dashboardViewModel: viewModel)
        // Can't mutate @State in a computed property body, so we dispatch
        DispatchQueue.main.async { weeklyReviewViewModel = vm }
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
        ScrollView {
            VStack(spacing: 20) {
                // 1. Greeting header
                CoachGreetingView(
                    showSettings: $showSettings,
                    streakDays: SessionTracker.shared.streakDays,
                    scoreChangeFromYesterday: viewModel.scoreChangeFromYesterday,
                    currentScore: hasData ? viewModel.overallScore.score : nil,
                    onTapScoreInfo: { showScoreGuide = true }
                )
                    .padding(.top, 12)

                if shouldShowEmptyState {
                    connectHealthView
                } else if hasData {
                    // 2. Recovery
                    todaySection
                        .onAppear { recoveryTracker.appeared() }
                        .onDisappear { recoveryTracker.disappeared() }

                    // 3. Illness Warning (only when active)
                    illnessWarningCard
                        .onAppear { illnessTracker.appeared() }
                        .onDisappear { illnessTracker.disappeared() }

                    // 4. Today's Briefing — actionable insights only
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
                    .onAppear { bodyInsightsTracker.appeared() }
                    .onDisappear { bodyInsightsTracker.disappeared() }

                    // 5. Your Trends — improving/stable/declining + top movers
                    todayTrendsSection
                        .onAppear { trendsTracker.appeared() }
                        .onDisappear { trendsTracker.disappeared() }

                    // 6. Health Risks — moderate+ only
                    todayRisksSection
                        .onAppear { risksTracker.appeared() }
                        .onDisappear { risksTracker.disappeared() }

                    // 7. Weekly Review
                    WeeklyReviewEntryCard(
                        viewModel: weeklyReviewVM
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
                    .onAppear { weeklyReviewTracker.appeared() }
                    .onDisappear { weeklyReviewTracker.disappeared() }

                    // 8. From Your History / Health Tips
                    historicalOrTipsSection
                        .onAppear { historicalTracker.appeared() }
                        .onDisappear { historicalTracker.disappeared() }

                    // Last updated footer
                    if let lastRefresh = viewModel.lastRefresh {
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                            .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                    }
                }
            }
        }
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

    // MARK: - Historical Insights / Health Tips

    @ViewBuilder
    private var historicalOrTipsSection: some View {
        let daysOfData = viewModel.dataDepth.daysOfData
        if daysOfData >= 14 {
            let highlights = Array(viewModel.historicalHighlights.prefix(3))
            if !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This Week")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(highlights) { highlight in
                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: highlight.metric.displayName,
                                type: .homeHistoricalHighlight,
                                screen: .home,
                                metadata: [
                                    "metric_id": highlight.metric.rawValue,
                                    "metric_category": highlight.metric.category.rawValue,
                                    "highlight_type": highlight.typeLabel
                                ]
                            )
                            historicalTracker.tapped(target: highlight.metric.rawValue)
                            navigationPath.append(highlight.metric)
                        } label: {
                            historicalHighlightCard(highlight)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        } else if hasData {
            healthTipsSection(daysRemaining: 14 - daysOfData)
        }
    }

    private func historicalHighlightCard(_ highlight: DashboardViewModel.HistoricalHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.metric.systemImageName)
                .font(.title3)
                .foregroundStyle(highlight.metric.category.color)
                .frame(width: 36, height: 36)
                .background(highlight.metric.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlight.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    highlightTypeBadge(highlight.type)
                }

                Text(highlight.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func highlightTypeBadge(_ type: DashboardViewModel.HistoricalHighlight.HighlightType) -> some View {
        let (label, color): (String, Color) = switch type {
        case .weekOverWeek: ("Week", .blue)
        case .yearOverYear: ("YoY", .blue)
        case .allTimeExtreme: ("Record", .orange)
        case .seasonal: ("Seasonal", .purple)
        case .longTermTrajectory: ("Trend", .green)
        }
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(color.opacity(DS.badgeBg), in: Capsule())
    }

    private func healthTipsSection(daysRemaining: Int) -> some View {
        let tips: [(icon: String, title: String)] = [
            ("figure.walk", "Move Every Hour"),
            ("bed.double.fill", "Consistent Sleep Schedule"),
            ("drop.fill", "Stay Hydrated"),
            ("heart.fill", "Monitor Resting Heart Rate"),
            ("wind", "Practice Deep Breathing"),
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Health Tips")
                .font(.headline)
                .padding(.horizontal)

            ForEach(tips.prefix(3), id: \.title) { tip in
                HStack(spacing: 12) {
                    Image(systemName: tip.icon)
                        .font(.body)
                        .foregroundStyle(.tint)
                        .frame(width: 28)
                    Text(tip.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            }

            Text("\(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") until your coach can compare weeks")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
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

    // MARK: - Today Trends Section

    @ViewBuilder
    private var todayTrendsSection: some View {
        let summary = viewModel.trendsSummary
        if summary.improving + summary.declining > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Trends")
                    .font(.headline)
                    .padding(.horizontal)

                // Counters row
                HStack(spacing: 0) {
                    trendCounter(count: summary.improving, label: "Improving", icon: "arrow.up.right", color: .green)
                    Divider().frame(height: DS.dividerHeight)
                    trendCounter(count: summary.stable, label: "Stable", icon: "arrow.right", color: .secondary)
                    Divider().frame(height: DS.dividerHeight)
                    trendCounter(count: summary.declining, label: "Declining", icon: "arrow.down.right", color: .red)
                }
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.cardRadius))
                .padding(.horizontal)

                // Top movers (max 3)
                if !summary.topMovers.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(summary.topMovers.prefix(3))) { mover in
                            Button {
                                AppAnalytics.shared.trackBlockTap(
                                    title: mover.metric.displayName,
                                    type: .homeTrendMetric,
                                    screen: .home,
                                    metadata: [
                                        "metric_id": mover.metric.rawValue,
                                        "metric_category": mover.metric.category.rawValue,
                                        "change_percent": mover.changePercent
                                    ]
                                )
                                trendsTracker.tapped(target: mover.metric.rawValue)
                                navigationPath.append(mover.metric)
                            } label: {
                                moverRow(mover)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
            }
        }
    }

    private func trendCounter(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Text("\(count)")
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func moverRow(_ mover: DashboardViewModel.MetricMover) -> some View {
        HStack(spacing: 12) {
            Image(systemName: mover.metric.systemImageName)
                .font(.body)
                .foregroundStyle(mover.metric.category.color)
                .frame(width: 28)
            Text(mover.metric.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(TrendAnalyzer.formattedPercentChange(mover.changePercent))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(mover.improving ? .green : .red)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

                ForEach(risks.prefix(3)) { risk in
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

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            if let score = liveViewModel.recovery.readinessScore {
                if liveViewModel.recovery.isReadinessDataFresh {
                    recoveryCard(score: score)
                } else {
                    staleRecoveryCard
                }
            }
        }
    }

    private var staleRecoveryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.applewatch")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery Unavailable")
                    .font(.subheadline.weight(.semibold))

                Text("Wear your Apple Watch overnight to update your readiness score.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .orange)
        .padding(.horizontal)
    }

    // MARK: - Timestamp Helpers

    /// Shows whichever is more recent: last sync time or latest data timestamp.
    /// After pull-to-refresh, this ensures the timestamp updates even if no new RHR data arrived.
    private var mostRecentTimestamp: Date? {
        let candidates = [
            liveViewModel.recovery.latestRestingHeartRateTimestamp,
            viewModel.lastRefresh,
        ].compactMap { $0 }
        return candidates.max()
    }

    // MARK: - Time-of-Day Helpers

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var dayPeriod: String {
        switch currentHour {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }

    private var timeGreeting: String {
        switch dayPeriod {
        case "morning": return "Rise & recover"
        case "afternoon": return "Midday check-in"
        case "evening": return "Wind down"
        default: return "Rest up"
        }
    }

    private func recoveryCard(score: Int) -> some View {
        VStack(spacing: 16) {
            // Live header: time-aware label + live indicator
            HStack {
                Text(timeGreeting)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(liveViewModel.vitals.hasFreshData ? .green : .orange)
                        .frame(width: 6, height: 6)
                        .scaleEffect(liveViewModel.vitals.hasFreshData && livePulse ? 1.0 : 0.5)
                        .opacity(liveViewModel.vitals.hasFreshData && livePulse ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: livePulse)

                    if let displayTs = mostRecentTimestamp {
                        Text(displayTs, style: .relative)
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Syncing")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Hero: Score ring + Recovery status
            HStack(spacing: 16) {
                HealthScoreRing(
                    score: score,
                    label: "Readiness",
                    size: 90,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Recovery")
                            .font(.title3.weight(.semibold))

                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Recovery Info",
                                type: .homeRecoveryInfoButton,
                                screen: .home,
                                metadata: [
                                    "destination": "recovery_info_sheet",
                                    "readiness_score": score
                                ]
                            )
                            recoveryTracker.tapped(target: "recovery_info")
                            showRecoveryInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(Self.recoveryLabel(score))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Self.recoveryColor(score))
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: score)
                }

                Spacer()
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onAppear {
            showRecoveryInfoIfNeeded()
        }
    }

    private func showRecoveryInfoIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: AppKeys.App.hasSeenRecoveryInfo) else { return }
        UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenRecoveryInfo)
        // Slight delay so the card renders first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showRecoveryInfo = true
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
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
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
