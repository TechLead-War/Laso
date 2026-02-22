import SwiftUI

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
        homeRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
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
                    // 2. Today: Recovery + Body State
                    todaySection

                    // 3. Body Insights — sleep, patterns, actions, anomalies
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

                    // 4. Insights — what needs your attention right now
                    ActionCardsSection(
                        insights: viewModel.topActionableInsights
                    ) { metric in
                        navigationPath.append(metric)
                    }

                    // 5. Focus Areas — where to improve
                    FocusAreasSection(
                        risks: viewModel.healthRisks
                    ) { risk in
                        navigationPath.append(risk.riskType)
                    }

                    // 6. Period selector — 7D / 30D / 3M / 6M
                    PeriodSummarySection(
                        viewModel: viewModel
                    ) { metric in
                        AppAnalytics.shared.trackBlockTap(title: metric.displayName, type: .metricRow, screen: .home)
                        navigationPath.append(metric)
                    }

                    // Last updated footer
                    if let lastRefresh = viewModel.lastRefresh {
                        Text("Updated \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                            .accessibilityLabel("Last updated \(lastRefresh, style: .relative) ago")
                    }
                } else {
                    connectHealthView
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

            Button {
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

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            if let score = liveViewModel.readinessScore {
                recoveryCard(score: score)
            }
        }
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
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(livePulse ? 1.0 : 0.5)
                        .opacity(livePulse ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: livePulse)

                    if let lastRefresh = viewModel.lastRefresh {
                        Text(lastRefresh, style: .relative)
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

                    Text(recoveryLabel(score))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(recoveryColor(score))
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

    private func recoveryLabel(_ score: Int) -> String {
        switch score {
        case 80...100: return "Fully Recovered"
        case 60..<80: return "Well Recovered"
        case 40..<60: return "Moderate"
        case 20..<40: return "Fatigued"
        default: return "Strained"
        }
    }

    private func recoveryColor(_ score: Int) -> Color {
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
    NavigationStack {
        HomeView(
            viewModel: DashboardViewModel(
                healthKitManager: hkManager,
                analysisEngine: AnalysisEngine()
            ),
            liveViewModel: LiveViewModel(healthKitManager: hkManager),
            deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
            navigationPath: .constant(NavigationPath()),
            showSettings: .constant(false)
        )
    }
}
