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

    // Profile capture state
    @State private var profileName: String?
    @State private var profileEmail: String?
    @State private var profileGender: Gender = .preferNotToSay
    @State private var profileAge: Int?

    let healthKitManager: HealthKitManager
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    private let totalPages = 8
    private let stepNames = [
        "welcome", "culture_personal", "culture_intelligence", "culture_privacy",
        "profile_capture", "connect_health", "focus_selection", "initial_calibration"
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                // Page 0: Welcome
                WelcomePage {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Get Started",
                        type: .onboardingGetStarted,
                        screen: .onboarding,
                        metadata: ["step_name": "welcome"]
                    )
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 1 }
                }
                .tag(0)

                // Page 1: Culture — Health is personal
                CulturePage(
                    icon: "heart.fill",
                    color: .red,
                    title: "We believe health\nis personal",
                    message: "No two bodies are the same. HealthPulse learns your unique patterns, rhythms, and thresholds to give you insights that truly matter."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 2 } }
                .tag(1)

                // Page 2: Culture — Intelligence grows
                CulturePage(
                    icon: "cpu.fill",
                    color: .purple,
                    title: "Intelligence that\ngrows with you",
                    message: "Our on-device ML engine learns more every day. From forecasting trends to detecting anomalies, your insights get smarter over time."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 3 } }
                .tag(2)

                // Page 3: Culture — Data stays yours
                CulturePage(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Your data stays yours",
                    message: "All analysis runs on your device. Your health data is encrypted at rest and never leaves your phone. No cloud. No compromise."
                ) { withAnimation(.smooth(duration: 0.4)) { currentPage = 4 } }
                .tag(3)

                // Page 4: Profile Capture (name, email, age, gender + silent device ID)
                ProfileCaptureView { name, email, gender, age in
                    profileName = name
                    profileEmail = email
                    profileGender = gender
                    profileAge = age
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 5 }
                }
                .tag(4)

                // Page 5: Connect Apple Health
                ConnectHealthPage(healthKitManager: healthKitManager) {
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 6 }
                }
                .tag(5)

                // Page 6: Focus Selection
                FocusPage(selectedFocuses: $selectedFocuses) {
                    withAnimation(.smooth(duration: 0.4)) { currentPage = 7 }
                }
                .tag(6)

                // Page 7: Calibration
                CalibrationPage(
                    isActive: currentPage == 7,
                    healthKitManager: healthKitManager,
                    runCalibration: runCalibration,
                    onComplete: finishOnboarding
                )
                .tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Progress dots (visible on pages 1–7, hidden on Welcome)
            if currentPage > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        let dotPage = index + 1 // maps dot 0 → page 1, dot 6 → page 7
                        Circle()
                            .fill(dotPage <= currentPage ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(
                                width: dotPage == currentPage ? 8 : 6,
                                height: dotPage == currentPage ? 8 : 6
                            )
                            .animation(.spring(response: 0.4), value: currentPage)
                    }
                }
                .padding(.bottom, 16)
            }
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

        // Save user profile to local + Firestore
        saveUserProfile(focuses: focuses)

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

    private func saveUserProfile(focuses: Set<HealthFocus>) {
        // Convert age to approximate date of birth
        let dateOfBirth: Date
        if let age = profileAge {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
        } else {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        }

        let profile = UserProfileStore.shared.makeProfile(
            name: profileName ?? "",
            email: profileEmail ?? "",
            gender: profileGender,
            dateOfBirth: dateOfBirth,
            healthFocuses: focuses.map(\.rawValue)
        )
        UserProfileStore.shared.save(profile)

        // Persist individual fields for quick access
        if let name = profileName {
            UserDefaults.standard.set(name, forKey: AppKeys.Profile.name)
        }
        if let email = profileEmail {
            UserDefaults.standard.set(email, forKey: AppKeys.Profile.email)
        }
        UserDefaults.standard.set(profileGender.rawValue, forKey: AppKeys.Profile.gender)
        if let age = profileAge {
            UserDefaults.standard.set(age, forKey: AppKeys.Profile.dateOfBirth)
        }
        UserDefaults.standard.set(true, forKey: AppKeys.Profile.profileCompleted)
    }
}

// MARK: - Page 4: Connect Health

private struct ConnectHealthPage: View {
    let healthKitManager: HealthKitManager
    let onContinue: () -> Void

    private let permissions = [
        "Heart Rate",
        "Steps",
        "Sleep Analysis",
        "Heart Rate Variability",
        "Blood Oxygen",
        "Workouts",
        "Body Measurements"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Apple Health icon
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 70, height: 70)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text("Connect Apple Health")
                    .font(.title2.weight(.bold))

                Text("HealthPulse reads your health data to build\npersonalized insights and track your progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 20)

            // Permission checklist
            VStack(spacing: 0) {
                ForEach(permissions, id: \.self) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)

                        Text(permission)
                            .font(.body.weight(.medium))

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
            }
            .padding(.vertical, 8)

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
                        PostHogManager.shared.capture(event: "healthkit_authorized", properties: [
                            "healthkit_available": true,
                        ])
                        onContinue()
                    }
                } label: {
                    Text("Connect Health Data")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, 24)

                Button("Skip for now") {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Skip for now",
                        type: .onboardingContinueAnyway,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "connect_health",
                            "healthkit_available": 1,
                            "skipped": 1
                        ]
                    )
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
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

// MARK: - Welcome Page

private struct WelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("LaunchIcon")
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.bottom, 24)

            Text("HealthPulse")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)

            Text("Your health, understood.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Get Started")
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
