import SwiftUI

// MARK: - Breathing Protocol

enum BreathingProtocol: String, CaseIterable, Identifiable {
    case cyclicSighing = "Relax"
    case boxBreathing = "Focus"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .cyclicSighing: return "Cyclic Sighing"
        case .boxBreathing: return "Box Breathing"
        }
    }

    var description: String {
        switch self {
        case .cyclicSighing:
            return Copy.Breathwork.cyclicSighingDescription
        case .boxBreathing:
            return Copy.Breathwork.boxBreathingDescription
        }
    }

    var icon: String {
        switch self {
        case .cyclicSighing: return "leaf.fill"
        case .boxBreathing: return "square.dashed"
        }
    }

    var accentColor: Color {
        switch self {
        case .cyclicSighing: return AppColour.accent
        case .boxBreathing: return AppColour.categorySleep
        }
    }

    /// Total session duration in seconds.
    var sessionDuration: Double {
        switch self {
        case .cyclicSighing: return 5 * 60 // 5 minutes
        case .boxBreathing: return 4 * 60  // 4 minutes
        }
    }

    /// Ordered phases for one cycle.
    var phases: [BreathPhase] {
        switch self {
        case .cyclicSighing:
            return [.inhale, .inhaleTop, .exhale]
        case .boxBreathing:
            return [.inhale, .holdAfterInhale, .exhale, .holdAfterExhale]
        }
    }

    /// Duration in seconds for a given phase.
    func duration(for phase: BreathPhase) -> Double {
        switch self {
        case .cyclicSighing:
            switch phase {
            case .inhale: return 2.0
            case .inhaleTop: return 1.0
            case .exhale: return 6.0
            case .holdAfterInhale, .holdAfterExhale: return 0
            }
        case .boxBreathing:
            switch phase {
            case .inhale: return 4.0
            case .holdAfterInhale: return 4.0
            case .exhale: return 4.0
            case .holdAfterExhale: return 4.0
            case .inhaleTop: return 0
            }
        }
    }
}

// MARK: - Breath Phase

enum BreathPhase: String {
    case inhale
    case inhaleTop       // second half of cyclic sighing double-inhale
    case holdAfterInhale
    case exhale
    case holdAfterExhale

    var label: String {
        switch self {
        case .inhale: return "Breathe In"
        case .inhaleTop: return "Breathe In"
        case .holdAfterInhale: return "Hold"
        case .exhale: return "Breathe Out"
        case .holdAfterExhale: return "Hold"
        }
    }

    /// Circle scale: 1.0 = fully expanded, 0.4 = contracted.
    var targetScale: CGFloat {
        switch self {
        case .inhale: return 0.75
        case .inhaleTop: return 1.0
        case .holdAfterInhale: return 1.0
        case .exhale: return 0.4
        case .holdAfterExhale: return 0.4
        }
    }
}

// MARK: - Post-Session Mood

enum PostSessionMood: String, CaseIterable {
    case better = "Better"
    case same = "Same"
    case worse = "Worse"

    var icon: String {
        switch self {
        case .better: return "face.smiling"
        case .same: return "face.dashed"
        case .worse: return "cloud.rain"
        }
    }
}

// MARK: - Session State

private enum SessionState {
    case idle
    case active
    case paused
    case complete
}

// MARK: - Session Clock

/// The two countdowns, ticked at 10 Hz. Held in an observable box rather than
/// screen-root `@State`: as root state every tick rebuilt the whole session view,
/// roughly 3,000 body passes over a five minute session, to move two numbers and
/// a ring. Only the three leaves below read it, so only they rebuild.
@Observable
private final class BreathSessionClock {
    var sessionRemaining: Double = 0
    var phaseRemaining: Double = 0
}

private func formattedDuration(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let m = totalSeconds / 60
    let s = totalSeconds % 60
    return String(format: "%d:%02d", m, s)
}

private struct BreathProgressRing: View {
    let clock: BreathSessionClock
    let total: Double
    let accent: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return 1.0 - (clock.sessionRemaining / total)
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(-90))
    }
}

private struct BreathPhaseCountdown: View {
    let clock: BreathSessionClock

    var body: some View {
        Text("\(max(Int(ceil(clock.phaseRemaining)), 0))")
            .font(DS.Typography.displayM)
            .foregroundStyle(.primary.opacity(0.8))
            .contentTransition(.numericText())
    }
}

private struct BreathSessionCountdown: View {
    let clock: BreathSessionClock
    let total: Double

    var body: some View {
        Text(Copy.StressMonitor.xText(formattedDuration(total - clock.sessionRemaining), formattedDuration(total)))
            .font(DS.Typography.subheadlineMedium.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

// MARK: - BreathworkView

struct BreathworkView: View {
    @State private var selectedProtocol: BreathingProtocol = .cyclicSighing
    @State private var sessionState: SessionState = .idle
    @State private var currentPhase: BreathPhase = .inhale
    @State private var clock = BreathSessionClock()
    /// Wall-clock deadlines. The countdowns are read off these rather than
    /// decremented by a fixed 0.1 per tick, which made every dropped tick run the
    /// session long by exactly that much.
    @State private var sessionEndDate: Date?
    @State private var phaseEndDate: Date?
    @State private var circleScale: CGFloat = 0.4
    @State private var showStopConfirmation = false
    @State private var selectedMood: PostSessionMood?
    @State private var phaseTransitionTrigger = false
    @State private var sessionStartedAt: Date?
    @State private var pauseCount = 0
    @State private var didTrackCompletedSession = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// `@State`, so a parent re-render does not throw the publisher away and drop
    /// the ticks it had already scheduled.
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var accent: Color { selectedProtocol.accentColor }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                switch sessionState {
                case .idle:
                    protocolPicker
                case .active, .paused:
                    activeSessionView
                case .complete:
                    completionView
                }
            }
        }
        .navigationTitle(Copy.StressMonitor.breathworkNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard sessionState == .active else { return }
            tick()
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phaseTransitionTrigger)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.breathwork)
        }
        .onDisappear {
            if sessionState == .complete {
                trackCompletedSessionIfNeeded()
            } else if sessionStartedAt != nil, sessionState == .active || sessionState == .paused {
                endSession()
            }
            AppAnalytics.shared.trackFeatureClose(.breathwork)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // onDisappear does not run when the app is backgrounded, and a suspended
            // app can be killed without ever returning, so a finished session left on
            // the mood screen would otherwise emit no completed event at all.
            // `.background` is the last callback before a possible kill.
            guard newPhase == .background, sessionState == .complete else { return }
            trackCompletedSessionIfNeeded()
        }
        .alert(Copy.Breathwork.endSessionTitle, isPresented: $showStopConfirmation) {
            Button(Copy.Breathwork.endSessionConfirm, role: .destructive) { endSession() }
            Button(Copy.Breathwork.continueSession, role: .cancel) { }
        } message: {
            Text(Copy.Breathwork.sessionInProgress)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.06),
                AppColour.surfaceBase
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Protocol Picker

    private var protocolPicker: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lungs.fill")
                        .font(DS.Typography.largeIcon)
                        .foregroundStyle(accent)
                        .padding(.top, DS.space6)

                    Text(Copy.Breathwork.chooseYourPractice)
                        .font(DS.Typography.title2)

                    Text(Copy.Breathwork.selectTechnique)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, DS.space2)

                // Protocol cards
                ForEach(BreathingProtocol.allCases) { proto in
                    protocolCard(proto)
                }

                // Start button
                Button {
                    startSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(DS.Typography.bodySemibold)

                        Text(Copy.Breathwork.beginSession)
                            .font(DS.Typography.bodySemibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space4)
                    .foregroundStyle(AppColour.textOnAccent)
                    .background(accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                    .shadow(color: AppColour.shadowAmbient, radius: 8, y: 4)
                }
                .buttonStyle(.dsPress)
                .padding(.top, DS.space1)

                // Session info
                HStack(spacing: 16) {
                    infoChip(icon: "clock", text: formattedDuration(selectedProtocol.sessionDuration))
                    infoChip(icon: "repeat", text: cycleDescription)
                }
                .padding(.bottom, DS.space7)
            }
            .padding(.horizontal)
        }
    }

    private func protocolCard(_ proto: BreathingProtocol) -> some View {
        let isSelected = selectedProtocol == proto

        return Button {
            guard selectedProtocol != proto else { return }
            AppAnalytics.shared.trackBreathworkProtocolSelected(proto)
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedProtocol = proto
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: proto.icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(proto.accentColor)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(proto.accentColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(proto.title)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)

                        Text(proto.subtitle)
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(proto.accentColor)
                            .padding(.horizontal, DS.badgeH)
                            .padding(.vertical, DS.badgeV)
                            .background(proto.accentColor.opacity(DS.badgeBg), in: Capsule())
                    }

                    Text(proto.description)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title3)
                    .foregroundStyle(isSelected ? proto.accentColor : Color(.tertiaryLabel))
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: isSelected ? proto.accentColor : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .strokeBorder(
                        isSelected ? proto.accentColor.opacity(0.4) : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.dsPress)
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(accent)

            Text(text)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .background(AppColour.surfaceRaised, in: Capsule())
    }

    private var cycleDescription: String {
        let phases = selectedProtocol.phases
        let cycleDuration = phases.reduce(0) { $0 + selectedProtocol.duration(for: $1) }
        let cycleCount = Int(selectedProtocol.sessionDuration / cycleDuration)
        return "\(cycleCount) cycles"
    }

    // MARK: - Active Session

    private var activeSessionView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Phase label
            Text(currentPhase.label)
                .font(DS.Typography.title2)
                .foregroundStyle(accent)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: currentPhase)

            Spacer()
                .frame(height: 24)

            // Breathing circle
            breathingCircle

            Spacer()
                .frame(height: 24)

            // Phase countdown
            BreathPhaseCountdown(clock: clock)

            Spacer()
                .frame(height: 8)

            // Session timer
            BreathSessionCountdown(clock: clock, total: selectedProtocol.sessionDuration)

            Spacer()

            // Controls
            sessionControls

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal)
    }

    private var breathingCircle: some View {
        ZStack {
            // Session progress ring (outer)
            Circle()
                .stroke(accent.opacity(0.12), lineWidth: 4)
                .frame(width: 240, height: 240)

            BreathProgressRing(clock: clock, total: selectedProtocol.sessionDuration, accent: accent)

            // Breathing circle (inner, animated)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.4),
                            accent.opacity(0.15),
                            accent.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(circleScale)

            Circle()
                .strokeBorder(accent, lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(circleScale)

            // Inner glow dot
            Circle()
                .fill(accent.opacity(0.6))
                .frame(width: 12, height: 12)
                .blur(radius: 4)
                .scaleEffect(circleScale)
        }
    }

    private var sessionControls: some View {
        HStack(spacing: 32) {
            // Stop button
            Button {
                // Intent to stop, not the stop itself: the abandoned event only
                // fires if the user confirms in the alert.
                AppAnalytics.shared.trackBlockTap(
                    title: "Stop Breathwork Session",
                    type: .smartAction,
                    screen: .breathwork,
                    metadata: [
                        "source": "breathwork_controls",
                        "action": "stop_tapped",
                        "phase": currentPhase.rawValue
                    ]
                )
                showStopConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 56, height: 56)
                    .background(AppColour.surfaceRaised, in: Circle())
            }
            .buttonStyle(.dsPress)

            // Play / Pause button
            Button {
                togglePause()
            } label: {
                Image(systemName: sessionState == .paused ? "play.fill" : "pause.fill")
                    .font(DS.Typography.title2)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(width: 72, height: 72)
                    .background(accent, in: Circle())
                    .shadow(color: AppColour.shadowAmbient, radius: 8, y: 4)
            }
            .buttonStyle(.dsPress)

            // Spacer for symmetry
            Color.clear
                .frame(width: 56, height: 56)
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: DS.sectionSpacing) {
            Spacer()

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.largeIcon)
                .foregroundStyle(accent)

            VStack(spacing: 6) {
                Text(Copy.Breathwork.sessionComplete)
                    .font(DS.Typography.title)

                Text(Copy.StressMonitor.ofText(formattedDuration(selectedProtocol.sessionDuration), selectedProtocol.subtitle.lowercased()))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 12)

            // Mood selector
            VStack(spacing: DS.itemSpacing) {
                Text(Copy.Breathwork.howDoYouFeel)
                    .font(DS.Typography.headline)

                HStack(spacing: 16) {
                    ForEach(PostSessionMood.allCases, id: \.rawValue) { mood in
                        moodButton(mood)
                    }
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)

            Spacer()

            // Done button
            Button {
                trackCompletedSessionIfNeeded()
                dismiss()
            } label: {
                Text(Copy.Breathwork.done)
                    .font(DS.Typography.bodySemibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space4)
                    .foregroundStyle(AppColour.textOnAccent)
                    .background(accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                    .shadow(color: AppColour.shadowAmbient, radius: 8, y: 4)
            }
            .buttonStyle(.dsPress)
            .padding(.horizontal)
            .padding(.bottom, DS.space7)
        }
    }

    private func moodButton(_ mood: PostSessionMood) -> some View {
        let isSelected = selectedMood == mood

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMood = mood
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mood.icon)
                    .font(DS.Typography.title2)
                    .foregroundStyle(isSelected ? accent : .secondary)

                Text(mood.rawValue)
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(isSelected ? accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space3)
            .background(
                isSelected ? accent.opacity(DS.badgeBg) : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isSelected ? accent.opacity(0.4) : Color(.tertiarySystemFill), lineWidth: 1)
            )
        }
        .buttonStyle(.dsPress)
    }

    // MARK: - Timer Logic

    private func startSession() {
        let proto = selectedProtocol
        let firstPhase = proto.phases[0]
        let cycleDuration = max(proto.phases.reduce(0.0) { $0 + proto.duration(for: $1) }, 1)

        let now = Date()
        let firstPhaseDuration = proto.duration(for: firstPhase)
        clock.sessionRemaining = proto.sessionDuration
        clock.phaseRemaining = firstPhaseDuration
        sessionEndDate = now.addingTimeInterval(proto.sessionDuration)
        phaseEndDate = now.addingTimeInterval(firstPhaseDuration)
        currentPhase = firstPhase
        selectedMood = nil
        pauseCount = 0
        didTrackCompletedSession = false
        sessionStartedAt = now

        // Animate circle to target scale
        withAnimation(.easeInOut(duration: proto.duration(for: firstPhase))) {
            circleScale = firstPhase.targetScale
        }

        sessionState = .active
        AppAnalytics.shared.trackBreathworkSessionStarted(proto, cycleCount: Int(proto.sessionDuration / cycleDuration))
        AppAnalytics.shared.trackRecommendationStarted(type: "breathwork_session", metric: proto.subtitle)
        BreathworkLiveActivityManager.shared.start(
            protocol: proto,
            phase: firstPhase,
            sessionTimeRemaining: clock.sessionRemaining
        )
    }

    private func tick() {
        guard let sessionEnd = sessionEndDate, let phaseEnd = phaseEndDate else { return }
        let now = Date()
        clock.sessionRemaining = max(0, sessionEnd.timeIntervalSince(now))
        clock.phaseRemaining = max(0, phaseEnd.timeIntervalSince(now))

        // Session complete
        if clock.sessionRemaining <= 0 {
            completeSession()
            return
        }

        // Phase complete. advance
        if clock.phaseRemaining <= 0 {
            advancePhase()
        }
    }

    private func advancePhase() {
        let phases = selectedProtocol.phases
        guard let currentIndex = phases.firstIndex(of: currentPhase) else { return }

        let nextIndex = (currentIndex + 1) % phases.count
        let nextPhase = phases[nextIndex]
        let duration = selectedProtocol.duration(for: nextPhase)

        currentPhase = nextPhase
        clock.phaseRemaining = duration
        // Anchored to now, not to the deadline that just passed: after a long
        // background gap this resyncs in one step instead of racing the user
        // through every phase it missed.
        phaseEndDate = Date().addingTimeInterval(duration)

        // Haptic on phase transition
        phaseTransitionTrigger.toggle()

        // Animate circle to new target
        withAnimation(.easeInOut(duration: duration)) {
            circleScale = nextPhase.targetScale
        }

        BreathworkLiveActivityManager.shared.update(
            protocol: selectedProtocol,
            phase: nextPhase,
            sessionTimeRemaining: clock.sessionRemaining,
            isPaused: false
        )
    }

    private func togglePause() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sessionState = sessionState == .active ? .paused : .active
        }

        if sessionState == .paused {
            pauseCount += 1
            AppAnalytics.shared.trackBreathworkSessionPaused(
                selectedProtocol,
                phase: currentPhase,
                remainingSec: max(Int(ceil(clock.sessionRemaining)), 0),
                pauseCount: pauseCount
            )
        } else {
            // Push both deadlines out by however long the pause lasted.
            let now = Date()
            sessionEndDate = now.addingTimeInterval(clock.sessionRemaining)
            phaseEndDate = now.addingTimeInterval(clock.phaseRemaining)
            AppAnalytics.shared.trackBreathworkSessionResumed(
                selectedProtocol,
                phase: currentPhase,
                remainingSec: max(Int(ceil(clock.sessionRemaining)), 0),
                pauseCount: pauseCount
            )
        }

        BreathworkLiveActivityManager.shared.update(
            protocol: selectedProtocol,
            phase: currentPhase,
            sessionTimeRemaining: clock.sessionRemaining,
            isPaused: sessionState == .paused
        )
    }

    private func endSession() {
        let actualDurationSec = max(Int(selectedProtocol.sessionDuration - clock.sessionRemaining), 0)
        if sessionStartedAt != nil {
            AppAnalytics.shared.trackBreathworkSessionAbandoned(
                selectedProtocol,
                phase: currentPhase,
                actualDurationSec: actualDurationSec,
                pauseCount: pauseCount
            )
            AppAnalytics.shared.trackRecommendationSkipped(
                type: "breathwork_session",
                metric: selectedProtocol.subtitle,
                reason: "abandoned"
            )
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            sessionState = .idle
            circleScale = 0.4
        }
        sessionStartedAt = nil
        pauseCount = 0
        sessionEndDate = nil
        phaseEndDate = nil
        BreathworkLiveActivityManager.shared.end(after: 0)
    }

    private func completeSession() {
        withAnimation(.easeInOut(duration: 0.5)) {
            sessionState = .complete
            circleScale = 0.4
        }
        sessionEndDate = nil
        phaseEndDate = nil
        BreathworkLiveActivityManager.shared.end(after: 30)
    }

    private func trackCompletedSessionIfNeeded() {
        guard !didTrackCompletedSession else { return }
        didTrackCompletedSession = true

        // Active elapsed time, the same measure endSession reports on abandon, so the
        // two events are comparable. Wall clock since session start would also count
        // paused time and the whole dwell on the mood screen.
        let actualDurationSec = max(Int(selectedProtocol.sessionDuration - clock.sessionRemaining), 0)

        AppAnalytics.shared.trackBreathworkSessionCompleted(
            selectedProtocol,
            actualDurationSec: actualDurationSec,
            pauseCount: pauseCount,
            mood: selectedMood
        )
        // delay_sec is time-to-act latency, not session length; breathwork has no
        // such delay, so leave it at the default 0. Session duration already ships
        // via trackBreathworkSessionCompleted above.
        AppAnalytics.shared.trackRecommendationCompleted(
            type: "breathwork_session",
            metric: selectedProtocol.subtitle
        )
        sessionStartedAt = nil
    }
}

// MARK: - Preview

#Preview("Breathwork") {
    NavigationStack {
        BreathworkView()
    }
}
