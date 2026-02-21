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
        }
        .onDisappear {
            homeRefreshTimer?.invalidate()
            homeRefreshTimer = nil
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
        if level >= 60 {
            return dayPeriod == "night" ? "Breathe before bed" : "Try 5 min breathing"
        }
        if level >= 40 {
            return dayPeriod == "afternoon" ? "Afternoon reset" : "Take a short break"
        }
        return "Looking good"
    }

    private var activeNudge: String {
        let minutes = liveViewModel.todayExerciseMinutes
        let goal = liveViewModel.exerciseGoal
        if minutes >= goal { return "Goal reached!" }
        let remaining = Int(goal - minutes)
        if dayPeriod == "evening" || dayPeriod == "night" {
            return remaining <= 10 ? "Quick finish!" : "\(remaining) min left"
        }
        return "\(remaining) min to goal"
    }

    private var mindfulNudge: String {
        if liveViewModel.todayMindfulMinutes > 0 {
            return liveViewModel.todayMindfulMinutes >= 10 ? "Great work" : "Keep it up"
        }
        switch dayPeriod {
        case "morning": return "Morning calm?"
        case "evening", "night": return "Wind down"
        default: return "Start a session"
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

                    Text(recoveryDescription(score))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Workout Recommendation — time-aware
            HStack(spacing: 8) {
                Image(systemName: workoutRecommendation(score).icon)
                    .font(.caption)
                    .foregroundStyle(recoveryColor(score))
                    .contentTransition(.symbolEffect(.replace))
                Text("\(dayPeriod == "night" ? "Tomorrow" : "Today"): \(workoutRecommendation(score).text)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(10)
            .background(recoveryColor(score).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            // Vitals row: RHR + HRV with animated values
            HStack(spacing: 0) {
                if let rhr = liveViewModel.latestRestingHeartRate {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, options: .repeating.speed(0.5))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Resting HR")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(Int(rhr)) bpm")
                                .font(.subheadline.weight(.medium).monospacedDigit())
                                .contentTransition(.numericText())
                                .animation(.easeInOut, value: Int(rhr))
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
                                .contentTransition(.numericText())
                                .animation(.easeInOut, value: Int(hrv))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider()

            // Action nudges: Stress, Active (with progress), Mindful (with progress)
            HStack(spacing: 0) {
                recoveryNudgeItem(
                    icon: "brain.head.profile",
                    iconColor: stressIconColor,
                    title: liveViewModel.stressLabel,
                    nudge: stressNudge,
                    progress: nil
                )

                Divider().frame(height: 44)

                recoveryNudgeItem(
                    icon: "flame.fill",
                    iconColor: .orange,
                    title: liveViewModel.todayExerciseMinutes > 0
                        ? "\(Int(liveViewModel.todayExerciseMinutes)) min"
                        : "0 min",
                    nudge: activeNudge,
                    progress: liveViewModel.exerciseProgress
                )

                Divider().frame(height: 44)

                recoveryNudgeItem(
                    icon: "leaf.fill",
                    iconColor: .mint,
                    title: liveViewModel.todayMindfulMinutes > 0
                        ? "\(Int(liveViewModel.todayMindfulMinutes)) min"
                        : "0 min",
                    nudge: mindfulNudge,
                    progress: liveViewModel.todayMindfulMinutes > 0
                        ? min(liveViewModel.todayMindfulMinutes / 10.0, 1.0) // 10 min daily goal
                        : 0
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func recoveryNudgeItem(icon: String, iconColor: Color, title: String, nudge: String, progress: Double?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: title)
            }
            if let progress {
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(iconColor.opacity(0.15))
                            .frame(height: 3)
                        Capsule()
                            .fill(progress >= 1.0 ? .green : iconColor)
                            .frame(width: geo.size.width * min(progress, 1.0), height: 3)
                            .animation(.easeInOut(duration: 0.8), value: progress)
                    }
                }
                .frame(width: 40, height: 3)
            }
            if !nudge.isEmpty {
                Text(nudge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(progress != nil && progress! >= 1.0 ? .green : iconColor)
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
        let period = dayPeriod
        switch (score, period) {
        case (80...100, "morning"): return "Well-rested start. Great morning for intense training."
        case (80...100, "afternoon"): return "Strong recovery holding. Push through the afternoon."
        case (80...100, "evening"): return "Great day of recovery. Wind down and maintain gains."
        case (80...100, _): return "Excellent recovery. Get quality sleep to stay sharp."
        case (60..<80, "morning"): return "Good start. You can handle moderate to high effort."
        case (60..<80, "afternoon"): return "Solid recovery. Stay active but listen to your body."
        case (60..<80, "evening"): return "Good day. Stretch and prep for quality sleep tonight."
        case (60..<80, _): return "Decent recovery. Rest well for a stronger tomorrow."
        case (40..<60, "morning"): return "Partial recovery. Ease into the day with lighter activity."
        case (40..<60, "afternoon"): return "Take it easy this afternoon. A walk could help."
        case (40..<60, "evening"): return "Recovery still building. Prioritize sleep tonight."
        case (40..<60, _): return "Recovery in progress. Sleep is your best tool right now."
        case (20..<40, "morning"): return "Your body needs rest. Gentle movement only today."
        case (20..<40, _): return "Focus on recovery. Hydrate and rest."
        default:
            if period == "morning" { return "High strain. Start slow — breathing and stretching only." }
            return "High strain. Prioritize sleep and hydration."
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
