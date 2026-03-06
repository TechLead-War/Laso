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
        "culture_you_vs_you", "culture_engine", "culture_actionable", "culture_privacy",
        "connect_health", "focus_selection", "initial_calibration"
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                CulturePage(
                    icon: "person.fill.checkmark",
                    color: .purple,
                    title: "You vs You",
                    message: "We never compare you to world averages or country norms. We only compare you to yourself — if something drops, we catch it."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 1 } }
                .tag(0)

                CulturePage(
                    icon: "cpu.fill",
                    color: .orange,
                    title: "Gets Smarter Over Time",
                    message: "An engine runs entirely on your device, learning your patterns. Over time, the insights rival a professional health coach."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 2 } }
                .tag(1)

                CulturePage(
                    icon: "sparkles",
                    color: .blue,
                    title: "Only What Matters",
                    message: "We don't show things already in good shape. You only see what needs your attention — no noise, no vanity stats."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 3 } }
                .tag(2)

                CulturePage(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Your Data Stays Here",
                    message: "Your health data never leaves your device. No cloud uploads, no names, no tracking. Everything is completely private."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 4 } }
                .tag(3)

                ConnectHealthPage(healthKitManager: healthKitManager) {
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 5 }
                }
                .tag(4)

                FocusPage(selectedFocuses: $selectedFocuses) {
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 6 }
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
        .accessibilityIdentifier("screen.onboarding")
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

        // Notification permission is requested from the main app after the
        // dashboard loads — asking here interrupts the onboarding→app transition.

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
        VStack(spacing: 0) {
            Spacer()

            Image("LaunchIcon")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.bottom, 24)

            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 88, height: 88)
                .background(Color.red.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text("Your health, understood.")
                    .font(.title2.weight(.bold))

                Text("Laso turns your Apple Watch data into clear health scores and insights — privately, on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 0) {
                benefitRow(icon: "waveform.path.ecg", color: .red, text: "Scores, trends, and live vitals")
                Divider().padding(.leading, 52)
                benefitRow(icon: "cross.case.fill", color: .blue, text: "Safety Triage Engine: clear monitor vs seek-care guidance")
                Divider().padding(.leading, 52)
                benefitRow(icon: "figure.walk.motion", color: .green, text: "Progressive Coach: starts at 4K steps and adapts weekly")
                Divider().padding(.leading, 52)
                benefitRow(icon: "calendar.badge.clock", color: .pink, text: "Cycle Phase Analyzer: phase-aware energy and recovery insights")
                Divider().padding(.leading, 52)
                benefitRow(icon: "lock.fill", color: .orange, text: "All health data stays on your device")
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .padding(.top, 24)

            Spacer()
            Spacer()

            if HKHealthStore.isHealthDataAvailable() {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Connect Apple Health",
                        type: .onboardingConnectHealth,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "connect_health",
                            "healthkit_available": 1
                        ]
                    )
                    Task {
                        await healthKitManager.requestAuthorization()
                        // PostHog: Track HealthKit authorization request (top of conversion funnel)
                        PostHogManager.shared.capture(event: "healthkit_authorized", properties: [
                            "healthkit_available": true,
                        ])
                        onContinue()
                    }
                } label: {
                    Text("Connect Apple Health")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            } else {
                VStack(spacing: 12) {
                    Text("HealthKit is not available on this device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Continue Anyway",
                            type: .onboardingContinueAnyway,
                            screen: .onboarding,
                            metadata: [
                                "step_name": "connect_health",
                                "healthkit_available": 0
                            ]
                        )
                        onContinue()
                    } label: {
                        Text("Continue Anyway")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .padding(.horizontal, 24)
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
        VStack(spacing: 0) {
            Spacer()

            Image("LaunchIcon")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text("What matters most to you?")
                    .font(.title2.weight(.bold))

                Text("Pick your areas — we'll prioritize those insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)

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
                            screen: .onboarding,
                            metadata: [
                                "step_name": "focus_selection",
                                "focus_id": focus.rawValue,
                                "is_selected": selectedFocuses.contains(focus) ? 1 : 0,
                                "selected_count": selectedFocuses.count
                            ]
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
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Continue",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "focus_selection",
                        "selected_focuses_count": selectedFocuses.count
                    ]
                )
                onContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
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
        VStack(spacing: 0) {
            Spacer()

            Text("Laso")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            let iconName = state == .success ? "checkmark.seal.fill" : "gearshape.2.fill"
            let iconColor: Color = state == .success ? .green : .blue
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 88, height: 88)
                .background(iconColor.opacity(0.12), in: Circle())
                .contentTransition(.symbolEffect(.replace))
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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

            if case .success = state {
                siriTipCard
                    .padding(.top, 20)
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
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Enter Laso",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "initial_calibration",
                        "calibration_state": "success"
                    ]
                )
                onComplete()
            } label: {
                Text("Enter Laso")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
        case .failed:
            VStack(spacing: 10) {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Retry Calibration",
                        type: .onboardingCalibrationRetry,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "initial_calibration",
                            "calibration_state": "failed"
                        ]
                    )
                    startCalibration()
                } label: {
                    Text("Retry Calibration")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, 24)

                Button("Skip for Now") {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Skip for Now",
                        type: .onboardingCalibrationSkip,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "initial_calibration",
                            "calibration_state": "failed"
                        ]
                    )
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
                let elapsed = calibrationStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
                if let errorMessage {
                    state = .failed(errorMessage)
                    // PostHog: Track calibration failure
                    PostHogManager.shared.capture(event: "calibration_failed", properties: [
                        "error_message": errorMessage,
                        "elapsed_sec": elapsed,
                    ])
                } else {
                    state = .success
                    // PostHog: Track successful calibration (user is now fully set up)
                    PostHogManager.shared.capture(event: "calibration_completed", properties: [
                        "elapsed_sec": elapsed,
                    ])
                }
            }
        }
        calibrationTask = task
    }

    private var siriTipCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Works with Siri")
                        .font(.subheadline.weight(.semibold))
                    Text("Try saying \"Hey Siri, what's my health score in Laso\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
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
        VStack(spacing: 0) {
            Spacer()

            // Branding
            Text("Laso")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 88, height: 88)
                .background(color.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            // Title + Message
            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.bold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: title,
                    type: .onboardingCultureContinue,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "culture_page",
                        "page_title": title
                    ]
                )
                onContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
