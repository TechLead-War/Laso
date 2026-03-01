import SwiftUI
import HealthKit

// MARK: - HealthFocus

enum HealthFocus: String, Codable, Identifiable, Hashable, CaseIterable {
    case sleep
    case fitness
    case heartHealth
    case weightBody
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .fitness: "Fitness"
        case .heartHealth: "Heart Health"
        case .weightBody: "Weight & Body"
        case .recovery: "Recovery"
        }
    }

    var systemImageName: String {
        switch self {
        case .sleep: "bed.double.fill"
        case .fitness: "figure.run"
        case .heartHealth: "heart.fill"
        case .weightBody: "scalemass.fill"
        case .recovery: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleep: .indigo
        case .fitness: .green
        case .heartHealth: .red
        case .weightBody: .orange
        case .recovery: .purple
        }
    }

    /// Maps this focus to one or more HealthCategory values for insight filtering
    var healthCategories: Set<HealthCategory> {
        switch self {
        case .sleep: [.sleep]
        case .fitness: [.activity]
        case .heartHealth: [.heart]
        case .weightBody: [.body]
        case .recovery: [.heart, .respiratory]
        }
    }

    /// All HealthCategory values covered by a set of focuses
    static func categories(for focuses: Set<HealthFocus>) -> Set<HealthCategory> {
        var result = Set<HealthCategory>()
        for focus in focuses {
            result.formUnion(focus.healthCategories)
        }
        return result
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var selectedFocuses: Set<HealthFocus> = []
    @State private var onboardingStartDate = Date()
    @State private var stepStartDate = Date()

    let healthKitManager: HealthKitManager
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    private let totalPages = 7
    private let stepNames = [
        "culture_actionable", "culture_privacy", "culture_you_vs_you", "culture_engine",
        "connect_health", "focus_selection", "initial_calibration"
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                CulturePage(
                    icon: "sparkles",
                    color: .blue,
                    title: "Only What Matters",
                    message: "We don't show things already in good shape. You only see what needs your attention — no noise, no vanity stats."
                ) { currentPage = 1 }
                .tag(0)

                CulturePage(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Your Data Stays Here",
                    message: "Your health data never leaves your device. No cloud uploads, no names, no tracking. Everything is completely private."
                ) { currentPage = 2 }
                .tag(1)

                CulturePage(
                    icon: "person.fill.checkmark",
                    color: .purple,
                    title: "You vs You",
                    message: "We never compare you to world averages or country norms. We only compare you to yourself — if something drops, we catch it."
                ) { currentPage = 3 }
                .tag(2)

                CulturePage(
                    icon: "cpu.fill",
                    color: .orange,
                    title: "Gets Smarter Over Time",
                    message: "An engine runs entirely on your device, learning your patterns. Over time, the insights rival a professional health coach."
                ) { currentPage = 4 }
                .tag(3)

                ConnectHealthPage(healthKitManager: healthKitManager) {
                    currentPage = 5
                }
                .tag(4)

                FocusPage(selectedFocuses: $selectedFocuses) {
                    currentPage = 6
                }
                .tag(5)

                CalibrationPage(
                    isActive: currentPage == 6,
                    healthKitManager: healthKitManager,
                    runCalibration: runCalibration,
                    onComplete: finishOnboarding
                )
                .tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(
                            width: index == currentPage ? 8 : 6,
                            height: index == currentPage ? 8 : 6
                        )
                        .animation(.spring(response: 0.4), value: currentPage)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: currentPage)
        .onAppear {
            onboardingStartDate = Date()
            stepStartDate = Date()
            AppAnalytics.shared.trackFeatureOpen(.onboarding)
        }
        .onChange(of: currentPage) { oldPage, newPage in
            // Track step completion for the step we just left
            let stepDuration = Int(Date().timeIntervalSince(stepStartDate))
            AppAnalytics.shared.trackOnboardingStepCompleted(
                step: oldPage,
                stepName: stepNames[oldPage],
                durationSec: stepDuration
            )
            stepStartDate = Date()
        }
        .onDisappear {
            // If onboarding disappears without completion, track drop-off
            if !UserDefaults.standard.bool(forKey: AppKeys.App.onboardingCompleted) {
                let totalDuration = Int(Date().timeIntervalSince(onboardingStartDate))
                AppAnalytics.shared.trackOnboardingDropOff(
                    lastStep: currentPage,
                    lastStepName: stepNames[currentPage],
                    durationSec: totalDuration
                )
            }
        }
    }

    private func finishOnboarding() {
        let focuses = selectedFocuses.isEmpty ? Set(HealthFocus.allCases) : selectedFocuses
        PersistenceManager().saveHealthFocuses(focuses)

        let totalDuration = Int(Date().timeIntervalSince(onboardingStartDate))
        AppAnalytics.shared.trackOnboardingCompleted(
            focuses: focuses.map(\.rawValue),
            durationSec: totalDuration,
            stepsCompleted: totalPages
        )
        AppAnalytics.shared.trackFeatureClose(.onboarding)
        onComplete()
    }
}

// MARK: - Page 4: Connect Health

private struct ConnectHealthPage: View {
    let healthKitManager: HealthKitManager
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: "heart.text.clipboard", color: .red)

            VStack(spacing: 12) {
                Text("Your health, understood.")
                    .font(.title3.weight(.semibold))

                Text("Laso turns your Apple Watch data into clear health scores and insights — privately, on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                benefitRow(icon: "waveform.path.ecg", color: .red, text: "Scores, trends, and live vitals")
                Divider().padding(.leading, 52)
                benefitRow(icon: "sparkles", color: .blue, text: "Personalized insights and alerts")
                Divider().padding(.leading, 52)
                benefitRow(icon: "lock.fill", color: .orange, text: "Health data stays on-device; anonymous usage analytics and optional feedback improve Laso")
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            if HKHealthStore.isHealthDataAvailable() {
                Button("Connect Apple Health") {
                    AppAnalytics.shared.trackBlockTap(title: "Connect Apple Health", type: .onboardingConnectHealth, screen: .onboarding)
                    Task {
                        await healthKitManager.requestAuthorization()
                        onContinue()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
            } else {
                VStack(spacing: 12) {
                    Text("HealthKit is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Continue Anyway") {
                        AppAnalytics.shared.trackBlockTap(title: "Continue Anyway", type: .onboardingContinueAnyway, screen: .onboarding)
                        onContinue()
                    }
                        .buttonStyle(.borderedProminent)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Page 5: Focus

private struct FocusPage: View {
    @Binding var selectedFocuses: Set<HealthFocus>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("What matters most to you?")
                    .font(.title3.weight(.semibold))

                Text("Pick your areas — we'll prioritize those insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            FlowLayout(spacing: 10) {
                ForEach(HealthFocus.allCases) { focus in
                    let isSelected = selectedFocuses.contains(focus)
                    Button {
                        if isSelected {
                            selectedFocuses.remove(focus)
                        } else {
                            selectedFocuses.insert(focus)
                        }
                        AppAnalytics.shared.trackBlockTap(
                            title: focus.displayName,
                            type: .onboardingFocusChip,
                            screen: .onboarding
                        )
                        AppAnalytics.shared.trackSettingChanged(
                            name: "onboarding_focus_\(focus.rawValue)",
                            value: !isSelected
                        )
                    } label: {
                        Label(focus.displayName, systemImage: focus.systemImageName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? focus.color.opacity(0.15) : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? focus.color : .secondary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? focus.color.opacity(0.4) : .clear, lineWidth: 1.5)
                            )
                    }
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button("Continue") {
                AppAnalytics.shared.trackBlockTap(title: "Continue", type: .onboardingGetStarted, screen: .onboarding)
                onContinue()
            }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Page 6: Initial Calibration

private struct CalibrationPage: View {
    enum CalibrationState: Equatable {
        case idle
        case running
        case success
        case failed(String)
    }

    let isActive: Bool
    let healthKitManager: HealthKitManager
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    @State private var state: CalibrationState = .idle
    @State private var dots = 0
    @State private var dotTimer: Timer?
    @State private var calibrationTask: Task<Void, Never>?
    @State private var calibrationStartTime: Date?

    init(
        isActive: Bool,
        healthKitManager: HealthKitManager,
        runCalibration: @escaping () async -> String?,
        onComplete: @escaping () -> Void
    ) {
        self.isActive = isActive
        self.healthKitManager = healthKitManager
        self.runCalibration = runCalibration
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(
                systemName: state == .success ? "checkmark.seal.fill" : "gearshape.2.fill",
                color: state == .success ? .green : .blue
            )

            VStack(spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if case .running = state {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 4)

                if shouldShowExtendedStats {
                    extendedStatsView
                        .padding(.top, 8)
                }
            }

            Spacer()

            footerActions
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isActive {
                startCalibrationIfNeeded()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startCalibrationIfNeeded()
            }
        }
        .onDisappear {
            calibrationTask?.cancel()
            calibrationTask = nil
            calibrationStartTime = nil
            stopDotTimer()
        }
    }

    @ViewBuilder
    private var footerActions: some View {
        switch state {
        case .idle, .running:
            EmptyView()
        case .success:
            Button("Enter HealthPulse") {
                AppAnalytics.shared.trackBlockTap(title: "Enter HealthPulse", type: .onboardingGetStarted, screen: .onboarding)
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .font(.subheadline.weight(.medium))
        case .failed:
            VStack(spacing: 10) {
                Button("Retry Calibration") {
                    startCalibration()
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.weight(.medium))

                Button("Skip for Now") {
                    onComplete()
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.medium))
            }
        }
    }

    private var title: String {
        switch state {
        case .idle, .running:
            return "Calibrating Your Baseline\(animatedDots)"
        case .success:
            return "Calibration Complete"
        case .failed:
            return "Calibration Incomplete"
        }
    }

    private var message: String {
        switch state {
        case .idle, .running:
            return "We are calculating your baseline from historical Apple Health data. This happens only once."
        case .success:
            return "Your historical baseline is ready. You will now start with personalized insights instead of generic ones."
        case .failed(let error):
            return error
        }
    }

    private var animatedDots: String {
        String(repeating: ".", count: dots)
    }

    private var calibrationElapsed: TimeInterval {
        guard let calibrationStartTime else { return 0 }
        return Date().timeIntervalSince(calibrationStartTime)
    }

    private var shouldShowExtendedStats: Bool {
        calibrationElapsed >= 60
    }

    @ViewBuilder
    private var extendedStatsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Calibration Stats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let progress = healthKitManager.syncProgress {
                statRow(
                    icon: "dial.medium",
                    label: "Stage",
                    value: progress.phase.title
                )
                statRow(
                    icon: "chart.bar.fill",
                    label: "Metrics Scanned",
                    value: "\(progress.metricsCompleted)/\(max(progress.totalMetrics, 1))"
                )
                statRow(
                    icon: "waveform.path.ecg",
                    label: "Data Points Found",
                    value: Self.formatCount(progress.samplesDiscovered)
                )
                if let oldest = progress.oldestSampleDate {
                    statRow(
                        icon: "clock.arrow.circlepath",
                        label: "Oldest Data",
                        value: Self.relativeDuration(from: oldest, to: Date())
                    )
                }
                if let latestMetric = progress.latestMetric {
                    statRow(
                        icon: latestMetric.systemImageName,
                        label: "Currently Processing",
                        value: latestMetric.displayName
                    )
                }
            } else {
                statRow(
                    icon: "chart.bar.fill",
                    label: "Stage",
                    value: "Analyzing Patterns"
                )
            }

            statRow(
                icon: "timer",
                label: "Elapsed",
                value: Self.elapsedLabel(calibrationElapsed)
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    private static func elapsedLabel(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        let mins = value / 60
        let secs = value % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private static func relativeDuration(from older: Date, to newer: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: older, to: newer).year ?? 0
        if years > 0 { return "\(years) yr ago" }
        let months = Calendar.current.dateComponents([.month], from: older, to: newer).month ?? 0
        if months > 0 { return "\(months) mo ago" }
        let days = Calendar.current.dateComponents([.day], from: older, to: newer).day ?? 0
        return "\(max(days, 0)) d ago"
    }

    private static func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func startCalibrationIfNeeded() {
        guard state == .idle else { return }
        startCalibration()
    }

    private func startCalibration() {
        calibrationTask?.cancel()
        state = .running
        calibrationStartTime = Date()
        startDotTimer()

        let task = Task {
            let errorMessage = await runCalibration()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                stopDotTimer()
                if let errorMessage {
                    state = .failed(errorMessage)
                } else {
                    state = .success
                }
            }
        }
        calibrationTask = task
    }

    private func startDotTimer() {
        stopDotTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dots = (dots % 3) + 1
        }
        timer.tolerance = 0.1
        dotTimer = timer
    }

    private func stopDotTimer() {
        dotTimer?.invalidate()
        dotTimer = nil
    }
}

// MARK: - Culture Page

private struct CulturePage: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            GlowIcon(systemName: icon, color: color)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button("Continue") {
                AppAnalytics.shared.trackBlockTap(title: title, type: .onboardingCultureContinue, screen: .onboarding)
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .font(.subheadline.weight(.medium))
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Glow Icon Component

private struct GlowIcon: View {
    let systemName: String
    let color: Color

    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(animate ? 1.3 : 0.9)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

            Circle()
                .fill(color.opacity(0.05))
                .frame(width: 160, height: 160)
                .scaleEffect(animate ? 1.5 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)

            Image(systemName: systemName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 80, height: 80)
                .background(color.opacity(0.12), in: Circle())
        }
        .onAppear { animate = true }
    }
}
