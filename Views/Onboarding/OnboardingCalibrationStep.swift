import SwiftUI

struct OnboardingCalibrationStep: View {
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

            Text(Copy.Labels.appName)
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
                        "step_name": "focus_calibration",
                        "calibration_state": "success"
                    ]
                )
                onComplete()
            } label: {
                Text(Copy.Onboarding.enterLaso)
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
                            "step_name": "focus_calibration",
                            "calibration_state": "failed"
                        ]
                    )
                    startCalibration()
                } label: {
                    Text(Copy.Onboarding.retryCalibration)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, 24)

                Button(Copy.Buttons.skipForNow) {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Skip for Now",
                        type: .onboardingCalibrationSkip,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "focus_calibration",
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
            return "\(Copy.Onboarding.calibratingTitle)\(animatedDots)"
        case .success:
            return Copy.Onboarding.calibrationComplete
        case .failed:
            return Copy.Onboarding.calibrationIncomplete
        }
    }

    private var message: String {
        switch state {
        case .idle, .running:
            return Copy.Onboarding.calibratingMessage
        case .success:
            return Copy.Onboarding.calibrationSuccessMessage
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
            Text(Copy.Onboarding.liveCalibrationStats)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let progress = healthKitManager.syncProgress {
                statRow(
                    icon: "dial.medium",
                    label: Copy.Onboarding.stageLabel,
                    value: progress.phase.title
                )
                statRow(
                    icon: "chart.bar.fill",
                    label: Copy.Onboarding.metricsScanned,
                    value: "\(progress.metricsCompleted)/\(max(progress.totalMetrics, 1))"
                )
                statRow(
                    icon: "waveform.path.ecg",
                    label: Copy.Onboarding.dataPointsFound,
                    value: Self.formatCount(progress.samplesDiscovered)
                )
                if let oldest = progress.oldestSampleDate {
                    statRow(
                        icon: "clock.arrow.circlepath",
                        label: Copy.Onboarding.oldestData,
                        value: Self.relativeDuration(from: oldest, to: Date())
                    )
                }
                if let latestMetric = progress.latestMetric {
                    statRow(
                        icon: latestMetric.systemImageName,
                        label: Copy.Onboarding.currentlyProcessing,
                        value: latestMetric.displayName
                    )
                }
            } else {
                statRow(
                    icon: "chart.bar.fill",
                    label: Copy.Onboarding.stageLabel,
                    value: Copy.Onboarding.analyzingPatterns
                )
            }

            statRow(
                icon: "timer",
                label: Copy.Onboarding.elapsed,
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
                    Text(Copy.Onboarding.worksWithSiri)
                        .font(.subheadline.weight(.semibold))
                    Text(Copy.Onboarding.siriTip)
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
