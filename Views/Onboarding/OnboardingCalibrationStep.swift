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
    @State private var discovery: CalibrationDiscovery?
    @State private var reassuranceIndex = 0
    @State private var reassuranceTimer: Timer?

    private static let reassuranceMessages = [
        "Reading your Apple Watch history",
        "Finding patterns in your heart rate",
        "Analyzing sleep cycles",
        "Building your personal baseline",
        "This may take a moment for large histories",
        "Almost there, finalizing your profile"
    ]

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
        Group {
            if case .success = state, let discovery {
                OnboardingCompletionView(discovery: discovery, onStart: onComplete)
            } else {
                calibrationView
            }
        }
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
            stopReassuranceTimer()
        }
    }

    private var calibrationView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Final step")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            Text(Copy.Labels.appName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 88, height: 88)
                .background(Color.blue.opacity(0.12), in: Circle())
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
                if let progress = healthKitManager.syncProgress {
                    VStack(spacing: 12) {
                        let percent = Int((Double(progress.metricsCompleted) / Double(max(progress.totalMetrics, 1))) * 100)

                        ProgressView(value: Double(progress.metricsCompleted), total: Double(max(progress.totalMetrics, 1)))
                            .tint(.blue)
                            .padding(.horizontal, 48)

                        HStack(spacing: 6) {
                            Text("\(percent)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(progress.phase.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .animation(.smooth, value: percent)

                        if let currentMetric = progress.latestMetric {
                            Text("Processing: \(currentMetric.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                                .id(currentMetric)
                        }

                        VStack(spacing: 4) {
                            Text("\(progress.metricsCompleted) of \(max(progress.totalMetrics, 1)) metrics synced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())

                            if progress.samplesDiscovered > 0 {
                                Text("\(Self.formatCount(progress.samplesDiscovered)) data points found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())
                            }
                            if let oldest = progress.oldestSampleDate {
                                Text("Data going back to \(oldest.formatted(.dateTime.month(.wide).year()))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .animation(.smooth, value: progress.samplesDiscovered)

                        Text(Self.reassuranceMessages[reassuranceIndex % Self.reassuranceMessages.count])
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                            .id(reassuranceIndex)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    .padding(.top, 12)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.top, 4)
                }
            }

            Spacer()

            footerActions
                .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var footerActions: some View {
        switch state {
        case .idle, .running, .success:
            EmptyView()
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
                .accessibilityIdentifier("onboarding.calibrationRetry")

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
                .accessibilityIdentifier("onboarding.calibrationSkip")
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
        discovery = nil
        calibrationStartTime = Date()
        startDotTimer()
        startReassuranceTimer()

        let task = Task {
            let errorMessage = await runCalibration()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                stopDotTimer()
                stopReassuranceTimer()
                let elapsed = calibrationStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
                if let errorMessage {
                    state = .failed(errorMessage)
                    PostHogManager.shared.capture(event: "onboarding_calibration_failed", properties: [
                        "error_message": errorMessage,
                        "elapsed_sec": elapsed,
                    ])
                } else {
                    discovery = CalibrationDiscovery.build(from: healthKitManager.timeSeries)
                    withAnimation(.smooth(duration: 0.5)) {
                        state = .success
                    }
                    PostHogManager.shared.capture(event: "onboarding_calibration_completed", properties: [
                        "elapsed_sec": elapsed,
                        "metrics_with_data": discovery?.metricsWithData ?? 0,
                        "highlights_count": discovery?.highlights.count ?? 0,
                    ])
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

    private func startReassuranceTimer() {
        stopReassuranceTimer()
        reassuranceIndex = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            withAnimation(.smooth(duration: 0.4)) {
                reassuranceIndex += 1
            }
        }
        timer.tolerance = 0.5
        reassuranceTimer = timer
    }

    private func stopReassuranceTimer() {
        reassuranceTimer?.invalidate()
        reassuranceTimer = nil
    }
}
