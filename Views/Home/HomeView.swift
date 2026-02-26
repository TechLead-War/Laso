import SwiftUI
import SwiftData

/// Main home screen composing visual hero, key metrics, period trends, categories, and compact alerts
struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool

    @State private var livePulse = false
    @State private var refreshTick = 0
    @State private var homeRefreshTimer: Timer?

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView("Analyzing your health data...")
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                homeContent
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        }
        .onDisappear {
            homeRefreshTimer?.invalidate()
            homeRefreshTimer = nil
            AppAnalytics.shared.trackFeatureClose(.home)
        }
    }

    /// Periodically refresh home data every 60s so the Recovery card stays fresh
    private func startHomeRefresh() {
        homeRefreshTimer?.invalidate()
        homeRefreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(RemoteConfigManager.shared.homeRefreshIntervalSeconds), repeats: true) { _ in
            liveViewModel.fetchHomeData()
            refreshTick += 1
        }
    }

    private var hasData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Greeting header
                CoachGreetingView(showSettings: $showSettings)
                    .padding(.top, 12)

                if hasData {
                    // 2. Recovery
                    todaySection

                    // 3. Illness Warning (only when active)
                    illnessWarningCard

                    // 4. Today's Briefing — actionable insights only
                    BodyInsightsSection(
                        viewModel: viewModel,
                        liveVM: liveViewModel,
                        onTapMetric: { metric in
                            AppAnalytics.shared.trackBlockTap(title: metric.displayName, type: .metricRow, screen: .home)
                            navigationPath.append(metric)
                        },
                        onTapSeeAll: {
                            navigationPath.append("insightsDetail")
                        }
                    )

                    // 5. Your Trends — improving/stable/declining + top movers
                    todayTrendsSection

                    // 6. Health Risks — moderate+ only
                    todayRisksSection

                    // 7. Weekly Review
                    WeeklyReviewEntryCard(
                        viewModel: WeeklyReviewViewModel(dashboardViewModel: viewModel)
                    ) {
                        AppAnalytics.shared.trackBlockTap(title: "Weekly Review", type: .weeklyReviewCard, screen: .home)
                        navigationPath.append("weeklyReview")
                    }
                    .onAppear {
                        AppAnalytics.shared.trackSectionImpression(section: .weeklyReviewSection, screen: .home)
                    }

                    // Last updated footer
                    if let lastRefresh = viewModel.lastRefresh {
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                            .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                            .onAppear {
                                AppAnalytics.shared.trackSectionImpression(section: .lastUpdatedFooter, screen: .home)
                            }
                    }
                } else {
                    connectHealthView
                        .onAppear {
                            AppAnalytics.shared.trackEmptyStateShown(screen: .home, stateType: "no_health_data")
                            AppAnalytics.shared.trackSectionImpression(section: .connectHealthSection, screen: .home)
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

                Text("HealthPulse reads from Apple Health, which syncs with your wearable automatically. No extra setup needed.")
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
                AppAnalytics.shared.trackBlockTap(title: "Manage Devices", type: .emptyStateManageDevices, screen: .home)
            })

            Button {
                AppAnalytics.shared.trackBlockTap(title: "Refresh", type: .emptyStateRefresh, screen: .home)
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
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
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
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
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
                    Divider().frame(height: 36)
                    trendCounter(count: summary.stable, label: "Stable", icon: "arrow.right", color: .secondary)
                    Divider().frame(height: 36)
                    trendCounter(count: summary.declining, label: "Declining", icon: "arrow.down.right", color: .red)
                }
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // Top movers (max 3)
                if !summary.topMovers.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(summary.topMovers.prefix(3))) { mover in
                            Button {
                                navigationPath.append(mover.metric)
                            } label: {
                                moverRow(mover)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
            Text("\(mover.changePercent > 0 ? "+" : "")\(String(format: "%.1f", mover.changePercent))%")
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
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            if let score = liveViewModel.readinessScore {
                if liveViewModel.isReadinessDataFresh {
                    recoveryCard(score: score)
                        .onAppear {
                            AppAnalytics.shared.trackCardImpression(cardType: .recoveryCard, screen: .home)
                            AppAnalytics.shared.trackSectionImpression(section: .recoveryCard, screen: .home, metadata: ["score": score])
                        }
                } else {
                    staleRecoveryCard
                        .onAppear {
                            AppAnalytics.shared.trackSectionImpression(section: .staleRecoveryCard, screen: .home)
                        }
                }
            }
        }
    }

    private var staleRecoveryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.applewatch")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

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
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.orange.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    // MARK: - Timestamp Helpers

    /// Shows whichever is more recent: last sync time or latest data timestamp.
    /// After pull-to-refresh, this ensures the timestamp updates even if no new RHR data arrived.
    private var mostRecentTimestamp: Date? {
        let candidates = [
            liveViewModel.latestRestingHeartRateTimestamp,
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
                        .fill(liveViewModel.hasFreshLiveData ? .green : .orange)
                        .frame(width: 6, height: 6)
                        .scaleEffect(liveViewModel.hasFreshLiveData && livePulse ? 1.0 : 0.5)
                        .opacity(liveViewModel.hasFreshLiveData && livePulse ? 1.0 : 0.4)
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
                    Text("Recovery")
                        .font(.title3.weight(.semibold))

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
                AppAnalytics.shared.trackBlockTap(title: "Try Again", type: .errorRetry, screen: .home)
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
