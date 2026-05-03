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
                .font(DS.Typography.largeIcon)
                .foregroundStyle(AppColour.info)
                .frame(width: 88, height: 88)
                .background(AppColour.info.opacity(DS.badgeBg), in: Circle())
                .padding(.bottom, DS.space7)

            VStack(spacing: DS.itemSpacing) {
                Text(runningTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)

                Text(runningMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
            }

            if case .running = state {
                runningProgress
                    .padding(.top, DS.space5)
            }

            Spacer()

            if case .failed = state {
                failedFooter
                    .padding(.bottom, DS.space8)
            } else {
                Spacer().frame(height: 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var runningProgress: some View {
        if let progress = healthKitManager.syncProgress {
            VStack(spacing: DS.itemSpacing) {
                let percent = Int((Double(progress.metricsCompleted) / Double(max(progress.totalMetrics, 1))) * 100)

                ProgressView(value: Double(progress.metricsCompleted), total: Double(max(progress.totalMetrics, 1)))
                    .tint(AppColour.info)
                    .padding(.horizontal, DS.space8)

                HStack(spacing: DS.space2) {
                    Text("\(percent)%")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.textPrimary)
                        .contentTransition(.numericText())
                    Text("•")
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                    Text(progress.phase.title)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }
                .animation(.smooth, value: percent)

                VStack(spacing: DS.space1) {
                    Text("\(progress.metricsCompleted) of \(max(progress.totalMetrics, 1)) metrics synced")
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .contentTransition(.numericText())

                    if progress.samplesDiscovered > 0 {
                        Text("\(Self.formatCount(progress.samplesDiscovered)) data points found")
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                            .contentTransition(.numericText())
                    }
                }

                Text(Copy.Onboarding.calibrationReassurance[reassuranceIndex % Copy.Onboarding.calibrationReassurance.count])
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .padding(.top, DS.space1)
                    .id(reassuranceIndex)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        } else {
            // Pre-progress fallback gets a label so the spinner has context.
            VStack(spacing: DS.space2) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text(Copy.Onboarding.mirrorStartingCalibration)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }
            .padding(.top, DS.space1)
        }
    }

    private var failedFooter: some View {
        VStack(spacing: DS.itemSpacing) {
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
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, DS.space6)
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
            .buttonStyle(.dsTertiary)
            .accessibilityIdentifier("onboarding.mirrorSkip")
        }
    }

    // MARK: - Success reveal

    private func completeView(discovery: CalibrationDiscovery) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sparkles")
                .font(DS.Typography.mediumIcon)
                .foregroundStyle(AppColour.info)
                .frame(width: 72, height: 72)
                .background(AppColour.info.opacity(DS.badgeBg), in: Circle())
                .padding(.bottom, DS.space5)

            Text(Copy.Onboarding.mirrorCompleteTitle)
                .font(DS.Typography.title2)
                .padding(.bottom, DS.space1)

            if let span = discovery.dataSpanDescription {
                Text(Copy.Onboarding.mirrorCompleteSubtitle(span))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
            }

            if !discovery.highlights.isEmpty {
                highlightCard(discovery: discovery)
                    .padding(.top, DS.space5)
            } else {
                Text(Copy.Onboarding.mirrorNoDataMessage)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .padding(.top, DS.space5)
            }

            if let observation = Copy.Onboarding.mirrorObservation(
                for: selectedFocuses,
                metricsWithData: discovery.metricsWithData
            ) {
                Text(observation)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
                    .padding(.top, DS.space4)
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
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .accessibilityIdentifier("onboarding.mirrorContinue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func highlightCard(discovery: CalibrationDiscovery) -> some View {
        VStack(spacing: 0) {
            ForEach(discovery.highlights) { highlight in
                HStack(spacing: DS.itemSpacing) {
                    Image(systemName: highlight.icon)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(highlight.color)
                        .frame(width: 32, height: 32)
                        .background(highlight.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text("\(highlight.metricName): **\(highlight.stat)**")
                            .font(DS.Typography.subheadline)
                        Text(highlight.detail)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, DS.space2)
            }
        }
        .padding(.horizontal, DS.space4)
        .padding(.vertical, DS.space2)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .padding(.horizontal, DS.space6)
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
                    PostHogManager.shared.capture(event: "calibration_failed", properties: [
                        "error_message": errorMessage,
                        "elapsed_sec": elapsed,
                    ])
                } else {
                    let built = CalibrationDiscovery.build(from: healthKitManager.timeSeries)
                    discovery = built
                    withAnimation(.smooth(duration: 0.5)) {
                        state = .success
                    }
                    PostHogManager.shared.capture(event: "calibration_completed", properties: [
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
