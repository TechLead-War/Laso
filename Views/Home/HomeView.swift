import SwiftUI

/// Main home screen composing visual hero, key metrics, period trends, categories, and compact alerts
struct HomeView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    let deviceSourceManager: DeviceSourceManager
    @Binding var navigationPath: NavigationPath
    @Binding var showSettings: Bool

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
        }
        .sensoryFeedback(.success, trigger: viewModel.lastRefresh)
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

                    // 3. Insights — what needs your attention right now
                    ActionCardsSection(
                        insights: viewModel.topActionableInsights
                    ) { metric in
                        navigationPath.append(metric)
                    }

                    // 4. Focus Areas — where to improve
                    FocusAreasSection(
                        risks: viewModel.healthRisks
                    ) { risk in
                        navigationPath.append(risk.riskType)
                    }

                    // 5. Period selector — 7D / 30D / 3M / 6M
                    PeriodSummarySection(
                        viewModel: viewModel
                    ) { metric in
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

    private var stressIconColor: Color {
        switch liveViewModel.stressColor {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }

    private var stressNudge: String {
        guard let level = liveViewModel.stressLevel else { return "" }
        if level >= 60 { return "Try 5 min breathing" }
        if level >= 40 { return "Take a short break" }
        return "Looking good"
    }

    private var activeNudge: String {
        let minutes = liveViewModel.todayExerciseMinutes
        let goal = liveViewModel.exerciseGoal
        if minutes >= goal { return "Goal reached!" }
        let remaining = Int(goal - minutes)
        return "\(remaining) min to goal"
    }

    private var mindfulNudge: String {
        liveViewModel.todayMindfulMinutes > 0 ? "Keep it up" : "Start a session"
    }

    private func recoveryCard(score: Int) -> some View {
        VStack(spacing: 16) {
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

                    Text(recoveryDescription(score))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Workout Recommendation
            HStack(spacing: 8) {
                Image(systemName: workoutRecommendation(score).icon)
                    .font(.caption)
                    .foregroundStyle(recoveryColor(score))
                Text("Today: \(workoutRecommendation(score).text)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(10)
            .background(recoveryColor(score).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            // Vitals row: RHR + HRV
            HStack(spacing: 0) {
                if let rhr = liveViewModel.latestRestingHeartRate {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Resting HR")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(Int(rhr)) bpm")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let hrv = liveViewModel.latestHRV {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("HRV")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(Int(hrv)) ms")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            // Action nudges: Stress, Active, Mindful
            HStack(spacing: 0) {
                recoveryNudgeItem(
                    icon: "brain.head.profile",
                    iconColor: stressIconColor,
                    title: liveViewModel.stressLabel,
                    nudge: stressNudge
                )

                Divider().frame(height: 36)

                recoveryNudgeItem(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: liveViewModel.todayExerciseMinutes > 0
                        ? "\(Int(liveViewModel.todayExerciseMinutes)) min"
                        : "0 min",
                    nudge: activeNudge
                )

                Divider().frame(height: 36)

                recoveryNudgeItem(
                    icon: "leaf.fill",
                    iconColor: .mint,
                    title: liveViewModel.todayMindfulMinutes > 0
                        ? "\(Int(liveViewModel.todayMindfulMinutes)) min"
                        : "0 min",
                    nudge: mindfulNudge
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func recoveryNudgeItem(icon: String, iconColor: Color, title: String, nudge: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            if !nudge.isEmpty {
                Text(nudge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(iconColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
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

    private func recoveryDescription(_ score: Int) -> String {
        switch score {
        case 80...100: return "Your body is well-rested. Great day for intense training."
        case 60..<80: return "Good recovery. You can handle moderate to high effort."
        case 40..<60: return "Partial recovery. Consider lighter activity today."
        case 20..<40: return "Your body needs rest. Focus on recovery activities."
        default: return "High strain detected. Prioritize sleep and recovery."
        }
    }

    private func workoutRecommendation(_ score: Int) -> (icon: String, text: String) {
        switch score {
        case 80...100: return ("bolt.heart.fill", "HIIT, Strength, or Long Run")
        case 60..<80: return ("figure.run", "Moderate Run, Cycling, or Swim")
        case 40..<60: return ("figure.walk", "Light Cardio, Yoga, or Walking")
        case 20..<40: return ("figure.mind.and.body", "Stretching, Breathing, or Rest")
        default: return ("bed.double.fill", "Rest Day — Sleep & Hydrate")
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
