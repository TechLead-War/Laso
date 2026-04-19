import SwiftUI

/// Screen 5: The Mirror Moment.
/// Runs one time calibration, then reveals the user's actual baseline numbers plus a priority aware
/// soft pattern observation. Absorbs the old Calibration + Completion screens into a single reveal.
struct OnboardingMirrorMomentStep: View {
    enum CalibrationState: Equatable {
        case idle
        case running
        case success
        case failed(String)
    }

    let isActive: Bool
    let selectedFocuses: Set<HealthFocus>
    let healthKitManager: HealthKitManager
    let runCalibration: () async -> String?
    let onContinue: (CalibrationDiscovery) -> Void

    @State private var state: CalibrationState = .idle
    @State private var discovery: CalibrationDiscovery?
    @State private var calibrationTask: Task<Void, Never>?
    @State private var calibrationStartTime: Date?
    @State private var reassuranceIndex = 0
    @State private var reassuranceTimer: Timer?

    var body: some View {
        Group {
            if case .success = state, let discovery {
                completeView(discovery: discovery)
            } else {
                calibrationView
            }
        }
        .onAppear {
            if isActive { startCalibrationIfNeeded() }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue { startCalibrationIfNeeded() }
        }
        .onDisappear {
            calibrationTask?.cancel()
            calibrationTask = nil
            calibrationStartTime = nil
            stopReassuranceTimer()
        }
    }

    // MARK: - Calibration running / failed

    private var calibrationView: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 88, height: 88)
                .background(Color.blue.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text(runningTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(runningMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if case .running = state {
                runningProgress
                    .padding(.top, 20)
            }

            Spacer()

            if case .failed = state {
                failedFooter
                    .padding(.bottom, 48)
            } else {
                Spacer().frame(height: 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var runningProgress: some View {
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
                }

                Text(Copy.Onboarding.calibrationReassurance[reassuranceIndex % Copy.Onboarding.calibrationReassurance.count])
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                    .id(reassuranceIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .padding(.top, 4)
        }
    }

    private var failedFooter: some View {
        VStack(spacing: 10) {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Retry",
                    type: .onboardingCalibrationRetry,
                    screen: .onboarding,
                    metadata: ["step_name": "mirror", "state": "failed"]
                )
                startCalibration()
            } label: {
                Text(Copy.Onboarding.mirrorRetry)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("onboarding.mirrorRetry")

            Button(Copy.Onboarding.mirrorSkip) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Skip Mirror",
                    type: .onboardingCalibrationSkip,
                    screen: .onboarding,
                    metadata: ["step_name": "mirror", "state": "failed"]
                )
                onContinue(discovery ?? CalibrationDiscovery())
            }
            .buttonStyle(.bordered)
            .font(.subheadline.weight(.medium))
            .accessibilityIdentifier("onboarding.mirrorSkip")
        }
    }

    // MARK: - Success reveal

    private func completeView(discovery: CalibrationDiscovery) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 72, height: 72)
                .background(Color.blue.opacity(0.12), in: Circle())
                .padding(.bottom, 20)

            Text(Copy.Onboarding.mirrorCompleteTitle)
                .font(.title2.weight(.bold))
                .padding(.bottom, 4)

            if let span = discovery.dataSpanDescription {
                Text(Copy.Onboarding.mirrorCompleteSubtitle(span))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if !discovery.highlights.isEmpty {
                highlightCard(discovery: discovery)
                    .padding(.top, 20)
            } else {
                Text(Copy.Onboarding.mirrorNoDataMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
            }

            if let observation = Copy.Onboarding.mirrorObservation(
                for: selectedFocuses,
                metricsWithData: discovery.metricsWithData
            ) {
                Text(observation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
            }

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Mirror Continue",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "mirror",
                        "state": "success",
                        "metrics_discovered": discovery.metricsWithData,
                        "highlights_shown": discovery.highlights.count
                    ]
                )
                onContinue(discovery)
            } label: {
                Text(Copy.Onboarding.mirrorContinue)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .accessibilityIdentifier("onboarding.mirrorContinue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func highlightCard(discovery: CalibrationDiscovery) -> some View {
        VStack(spacing: 0) {
            ForEach(discovery.highlights) { highlight in
                HStack(spacing: 12) {
                    Image(systemName: highlight.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(highlight.color)
                        .frame(width: 32, height: 32)
                        .background(highlight.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(highlight.metricName): **\(highlight.stat)**")
                            .font(.subheadline)
                        Text(highlight.detail)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    // MARK: - Titles

    private var runningTitle: String {
        switch state {
        case .idle, .running: return Copy.Onboarding.mirrorCalibratingTitle
        case .success: return Copy.Onboarding.mirrorCompleteTitle
        case .failed: return Copy.Onboarding.mirrorIncomplete
        }
    }

    private var runningMessage: String {
        switch state {
        case .idle, .running: return Copy.Onboarding.mirrorCalibratingMessage
        case .success: return ""
        case .failed(let error): return error
        }
    }

    // MARK: - Calibration lifecycle

    private func startCalibrationIfNeeded() {
        guard state == .idle else { return }
        startCalibration()
    }

    private func startCalibration() {
        calibrationTask?.cancel()
        state = .running
        discovery = nil
        calibrationStartTime = Date()
        startReassuranceTimer()

        let task = Task {
            let errorMessage = await runCalibration()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                stopReassuranceTimer()
                let elapsed = calibrationStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
                if let errorMessage {
                    state = .failed(errorMessage)
                    PostHogManager.shared.capture(event: "onboarding_calibration_failed", properties: [
                        "error_message": errorMessage,
                        "elapsed_sec": elapsed,
                    ])
                } else {
                    let built = CalibrationDiscovery.build(from: healthKitManager.timeSeries)
                    discovery = built
                    withAnimation(.smooth(duration: 0.5)) {
                        state = .success
                    }
                    PostHogManager.shared.capture(event: "onboarding_calibration_completed", properties: [
                        "elapsed_sec": elapsed,
                        "metrics_with_data": built.metricsWithData,
                        "highlights_count": built.highlights.count,
                    ])
                }
            }
        }
        calibrationTask = task
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

    private static func formatCount(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }
}
