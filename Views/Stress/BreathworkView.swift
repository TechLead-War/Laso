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
            return "Double inhale, long exhale. Backed by Stanford research for rapid calm."
        case .boxBreathing:
            return "Equal-timed breathing used by Navy SEALs for focus under pressure."
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
        case .cyclicSighing: return .teal
        case .boxBreathing: return .indigo
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

// MARK: - BreathworkView

struct BreathworkView: View {
    @State private var selectedProtocol: BreathingProtocol = .cyclicSighing
    @State private var sessionState: SessionState = .idle
    @State private var currentPhase: BreathPhase = .inhale
    @State private var phaseTimeRemaining: Double = 0
    @State private var sessionTimeRemaining: Double = 0
    @State private var circleScale: CGFloat = 0.4
    @State private var showStopConfirmation = false
    @State private var selectedMood: PostSessionMood?
    @State private var phaseTransitionTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var accent: Color { selectedProtocol.accentColor }

    private var sessionProgress: Double {
        let total = selectedProtocol.sessionDuration
        guard total > 0 else { return 0 }
        return 1.0 - (sessionTimeRemaining / total)
    }

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
        .navigationTitle("Breathwork")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard sessionState == .active else { return }
            tick()
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: phaseTransitionTrigger)
        .alert("End Session?", isPresented: $showStopConfirmation) {
            Button("End", role: .destructive) { endSession() }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Your breathing session is still in progress.")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.06),
                Color(.systemGroupedBackground)
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
                        .font(.system(size: 44))
                        .foregroundStyle(accent)
                        .padding(.top, 24)

                    Text("Choose Your Practice")
                        .font(.title2.weight(.bold))

                    Text("Select a breathing technique to begin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

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
                            .font(.body.weight(.semibold))

                        Text("Begin Session")
                            .font(.body.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                    .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                // Session info
                HStack(spacing: 16) {
                    infoChip(icon: "clock", text: formattedDuration(selectedProtocol.sessionDuration))
                    infoChip(icon: "repeat", text: cycleDescription)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal)
        }
    }

    private func protocolCard(_ proto: BreathingProtocol) -> some View {
        let isSelected = selectedProtocol == proto

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedProtocol = proto
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: proto.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(proto.accentColor)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(proto.accentColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(proto.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(proto.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(proto.accentColor)
                            .padding(.horizontal, DS.badgeH)
                            .padding(.vertical, DS.badgeV)
                            .background(proto.accentColor.opacity(DS.badgeBg), in: Capsule())
                    }

                    Text(proto.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
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
        .buttonStyle(.plain)
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
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
                .font(.title2.weight(.semibold))
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
            Text(phaseCountdownText)
                .font(.system(size: 48, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary.opacity(0.8))
                .contentTransition(.numericText())

            Spacer()
                .frame(height: 8)

            // Session timer
            Text("\(formattedDuration(selectedProtocol.sessionDuration - sessionTimeRemaining)) / \(formattedDuration(selectedProtocol.sessionDuration))")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)

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

            Circle()
                .trim(from: 0, to: sessionProgress)
                .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))

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
                .strokeBorder(accent.opacity(0.5), lineWidth: 2)
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

    private var phaseCountdownText: String {
        let seconds = max(Int(ceil(phaseTimeRemaining)), 0)
        return "\(seconds)"
    }

    private var sessionControls: some View {
        HStack(spacing: 32) {
            // Stop button
            Button {
                showStopConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            // Play / Pause button
            Button {
                togglePause()
            } label: {
                Image(systemName: sessionState == .paused ? "play.fill" : "pause.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

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
                .font(.system(size: 64))
                .foregroundStyle(accent)

            VStack(spacing: 6) {
                Text("Session Complete")
                    .font(.title.weight(.bold))

                Text("\(formattedDuration(selectedProtocol.sessionDuration)) of \(selectedProtocol.subtitle.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 12)

            // Mood selector
            VStack(spacing: DS.itemSpacing) {
                Text("How do you feel?")
                    .font(.headline)

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
                dismiss()
            } label: {
                Text("Done")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(accent, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                    .shadow(color: accent.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 32)
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
                    .font(.title2)
                    .foregroundStyle(isSelected ? accent : .secondary)

                Text(mood.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? accent.opacity(DS.badgeBg) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? accent.opacity(0.4) : Color(.tertiarySystemFill), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer Logic

    private func startSession() {
        let proto = selectedProtocol
        let firstPhase = proto.phases[0]

        sessionTimeRemaining = proto.sessionDuration
        currentPhase = firstPhase
        phaseTimeRemaining = proto.duration(for: firstPhase)

        // Animate circle to target scale
        withAnimation(.easeInOut(duration: proto.duration(for: firstPhase))) {
            circleScale = firstPhase.targetScale
        }

        sessionState = .active
    }

    private func tick() {
        let dt = 0.05

        phaseTimeRemaining -= dt
        sessionTimeRemaining -= dt

        // Session complete
        if sessionTimeRemaining <= 0 {
            sessionTimeRemaining = 0
            withAnimation(.easeInOut(duration: 0.5)) {
                sessionState = .complete
                circleScale = 0.4
            }
            return
        }

        // Phase complete — advance
        if phaseTimeRemaining <= 0 {
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
        phaseTimeRemaining = duration

        // Haptic on phase transition
        phaseTransitionTrigger.toggle()

        // Animate circle to new target
        withAnimation(.easeInOut(duration: duration)) {
            circleScale = nextPhase.targetScale
        }
    }

    private func togglePause() {
        withAnimation(.easeInOut(duration: 0.3)) {
            sessionState = sessionState == .active ? .paused : .active
        }
    }

    private func endSession() {
        withAnimation(.easeInOut(duration: 0.4)) {
            sessionState = .idle
            circleScale = 0.4
        }
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview("Breathwork") {
    NavigationStack {
        BreathworkView()
    }
}
