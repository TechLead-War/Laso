import SwiftUI

// MARK: - Screen 8 — Bridge

struct OnbV2Screen8Bridge: View {
    let onBack: () -> Void
    let onCTA: () -> Void

    @State private var connectTapped = false

    private var uses: [String] {
        [Copy.OnboardingV2.s8Use1, Copy.OnboardingV2.s8Use2, Copy.OnboardingV2.s8Use3]
    }

    var body: some View {
        OnbV2ScreenContainer(ambient: .blueDual) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 5, total: OnbV2Flow.total, onBack: onBack)

                Spacer(minLength: 0)

                permissionSheetPreview

                Spacer().frame(height: 20)

                Text(Copy.OnboardingV2.s8Title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer().frame(height: 14)

                usesList

                Spacer().frame(height: 16)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OnbV2.fg2)
                    Text(Copy.OnboardingV2.s8PrivacyChip)
                        .font(.system(size: 13))
                        .foregroundStyle(OnbV2.fg2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColour.surfaceRaised))
                .overlay(Capsule().stroke(OnbV2.line, lineWidth: 1))

                Spacer(minLength: 0)

                // This CTA opens the system HealthKit consent sheet, so it earns
                // the .impact(.medium) reserved for the connect + purchase asks.
                OnbV2PrimaryCTA(Copy.OnboardingV2.s8CTA) {
                    connectTapped.toggle()
                    onCTA()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: connectTapped)
    }

    /// A greyed mock of the system Health permission sheet. HealthKit never
    /// reports which read categories were granted, so a user who leaves
    /// switches off quietly gets weaker scores forever and neither side can
    /// detect it. This screen is the only chance to point at "Turn On All".
    private var permissionSheetPreview: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(Copy.OnboardingV2.s8SheetTurnOnAll)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OnbV2.fg)
                    Spacer(minLength: 0)
                    togglePill(on: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(OnbV2.blue.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(OnbV2.blue.opacity(0.45), lineWidth: 1)
                )
                .padding(.horizontal, 12)

                ForEach(placeholderRowWidths, id: \.self) { width in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(OnbV2.fg4)
                            .frame(width: 14, height: 14)
                        Capsule()
                            .fill(OnbV2.fg4)
                            .frame(width: width, height: 8)
                        Spacer(minLength: 0)
                        togglePill(on: false)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: 264)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColour.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OnbV2.line, lineWidth: 1)
            )

            Text(Copy.OnboardingV2.s8SheetCaption)
                .font(.system(size: 13))
                .foregroundStyle(OnbV2.fg3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(.horizontal, OnbV2.bodyPadH)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.OnboardingV2.s8SheetCaption)
    }

    /// Widths only, so the muted rows read as unnamed categories rather than
    /// naming permissions the sheet may not actually list. Values stay distinct
    /// because they are the ForEach identity.
    private var placeholderRowWidths: [CGFloat] { [96, 72, 88] }

    private func togglePill(on: Bool) -> some View {
        Capsule()
            .fill(on ? OnbV2.blue : AppColour.trackNeutral)
            .frame(width: 28, height: 17)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle()
                    .fill(AppColour.textOnAccent)
                    .frame(width: 13, height: 13)
                    .padding(2)
            }
    }

    private var usesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(uses, id: \.self) { use in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OnbV2.blue)
                    Text(use)
                        .font(.system(size: 14))
                        .foregroundStyle(OnbV2.fg2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .padding(.horizontal, OnbV2.bodyPadH)
    }
}

// MARK: - Screen 10 — Scan

struct OnbV2Screen10Scan: View {
    let snapshot: OnboardingHealthSnapshot
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin1: Double = 0
    @State private var spin2: Double = 0
    @State private var spin3: Double = 0
    @State private var pulse: Bool = false
    @State private var progress: Double = 0
    @State private var foundCount: Int = 0
    @State private var startDate: Date?
    @State private var timer: Timer?

    private let totalDuration: Double = 6.5
    private let completeDelay: Double = 7.2
    private let foundTriggers: [Double] = [0.8, 1.9, 3.0, 4.1, 5.2]

    private var foundLabels: [String] {
        [
            Copy.OnboardingV2.s10Found1,
            Copy.OnboardingV2.s10Found2,
            Copy.OnboardingV2.s10Found3,
            Copy.OnboardingV2.s10Found4,
            Copy.OnboardingV2.s10Found5
        ]
    }

    /// Real durations from Apple Health, formatted as "1y 4mo" / "6mo" / "today".
    /// nil entries render as "Not recorded" to keep the screen honest when the
    /// user has no data for that metric.
    private var foundValues: [String?] {
        [
            OnbHealthFormat.duration(from: snapshot.heartRateAge),
            OnbHealthFormat.duration(from: snapshot.sleepAge),
            OnbHealthFormat.duration(from: snapshot.workoutsAge),
            OnbHealthFormat.duration(from: snapshot.hrvAge),
            snapshot.hasRecoverySignal ? "found" : nil
        ]
    }

    private var longestDuration: String? {
        let ages = [snapshot.heartRateAge, snapshot.sleepAge, snapshot.workoutsAge, snapshot.hrvAge]
            .compactMap { $0 }
        guard let max = ages.max() else { return nil }
        return OnbHealthFormat.duration(from: max)
    }

    var body: some View {
        OnbV2ScreenContainer(ambient: .blueDual) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 6, total: OnbV2Flow.total, onBack: nil, hideProgress: false)

                Spacer().frame(height: 8)

                scanAnimation
                    .frame(height: 260)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    Text(Copy.OnboardingV2.s10Eyebrow)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(OnbV2.blue)
                    Text(Copy.OnboardingV2.s10Title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, OnbV2.bodyPadH)

                Spacer().frame(height: 16)

                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { idx in
                        foundRow(label: foundLabels[idx],
                                 value: foundValues[idx] ?? Copy.OnboardingV2.s10NotRecorded,
                                 hasData: foundValues[idx] != nil,
                                 visible: foundCount > idx)
                    }
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5), value: foundCount)

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColour.trackNeutral)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [OnbV2.blue, OnbV2.blueLight],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(0, geo.size.width * CGFloat(progress)))
                        }
                    }
                    .frame(height: 4)

                    Text(Copy.OnboardingV2.s10Status(Int(progress * 100), longestDuration: longestDuration))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(OnbV2.fg3)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 24)
            }
        }
        .onAppear { startAnimations() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    @ViewBuilder
    private var scanAnimation: some View {
        ZStack {
            ring(diameter: 240, rotation: spin1)
            ring(diameter: 188, rotation: spin2)
            ring(diameter: 134, rotation: spin3)

            Circle()
                .fill(LinearGradient(
                    colors: [OnbV2.blue, OnbV2.blue.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 90, height: 90)
                .shadow(color: OnbV2.blueGlow, radius: 24, x: 0, y: 0)
                .overlay(
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppColour.textOnAccent)
                        .font(.system(size: 30, weight: .bold))
                )
                // Reduce Motion: hold the core at rest size with no repeating
                // pulse; the load-bearing scan Timer still runs below.
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.08 : 0.96))
                .animation(
                    reduceMotion ? nil
                    : .timingCurve(0.4, 0, 0.6, 1, duration: 0.9)
                        .repeatForever(autoreverses: true),
                    value: pulse
                )
        }
    }

    @ViewBuilder
    private func ring(diameter: CGFloat, rotation: Double) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    OnbV2.blue.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 6])
                )
                .frame(width: diameter, height: diameter)

            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(OnbV2.blue)
                    .frame(width: 6, height: 6)
                    .shadow(color: OnbV2.blueGlow, radius: 6)
                    .offset(satelliteOffset(index: i, radius: diameter / 2))
            }
        }
        .rotationEffect(.degrees(rotation))
    }

    private func satelliteOffset(index: Int, radius: CGFloat) -> CGSize {
        switch index {
        case 0: return CGSize(width: 0, height: -radius)
        case 1: return CGSize(width: radius, height: 0)
        case 2: return CGSize(width: 0, height: radius)
        default: return CGSize(width: -radius, height: 0)
        }
    }

    @ViewBuilder
    private func foundRow(label: String, value: String, hasData: Bool, visible: Bool) -> some View {
        let iconName: String = visible ? (hasData ? "checkmark.circle.fill" : "minus.circle") : "circle"
        let iconColor: Color = visible ? (hasData ? OnbV2.green : OnbV2.fg4) : OnbV2.fg4
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(visible ? OnbV2.fg : OnbV2.fg3)

            Spacer(minLength: 8)

            Text(visible ? value : "···")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(visible ? (hasData ? OnbV2.fg2 : OnbV2.fg4) : OnbV2.fg4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(visible && hasData ? OnbV2.blue.opacity(0.08) : AppColour.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(visible && hasData ? OnbV2.blue.opacity(0.3) : OnbV2.line, lineWidth: 1)
        )
        .opacity(visible ? 1 : 0.5)
    }

    private func startAnimations() {
        pulse = true

#if DEBUG
        // Screenshot harness: freeze on the "all metrics found, 100%" frame and
        // skip the completion timer so the scan screen stays put for capture
        // instead of auto-advancing to the heart screen after ~7s.
        if UITestMode.isEnabled {
            foundCount = foundLabels.count
            progress = 1.0
            return
        }
#endif

        // Decorative ring spins only. Reduce Motion holds the rings still; the
        // foundCount / progress / onComplete Timer below still runs so the
        // screen always finds its metrics and auto-advances.
        if !reduceMotion {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                spin1 = 360
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                spin2 = -360
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                spin3 = 360
            }
        }

        startDate = Date()
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { ticker in
            guard let start = startDate else { return }
            let elapsed = Date().timeIntervalSince(start)
            progress = min(1.0, elapsed / totalDuration)

            var nextCount = foundCount
            for (idx, threshold) in foundTriggers.enumerated() {
                if elapsed >= threshold && idx >= nextCount {
                    nextCount = idx + 1
                }
            }
            if nextCount != foundCount {
                foundCount = nextCount
            }

            if elapsed >= completeDelay {
                ticker.invalidate()
                timer = nil
                onComplete()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}

// MARK: - Screen 11 — Heart reveal

struct OnbV2Screen11Heart: View {
    let snapshot: OnboardingHealthSnapshot
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var traceProgress: CGFloat = 0
    @State private var phase: RevealPhase = .hidden
    @State private var numberLanded = false
    @State private var revealTracked = false
    @State private var tracePulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasData: Bool { snapshot.restingHR != nil }

    /// Resting-HR band, using the central BiologicalAgeConfig anchors so the
    /// reveal copy adapts to the value instead of always reading "calm".
    private enum RHRBand { case athletic, normal, elevated }
    private var rhrBand: RHRBand {
        guard let bpm = snapshot.restingHR else { return .normal }
        if Double(bpm) <= BiologicalAgeConfig.rhrYoungFitCeiling { return .athletic }
        if Double(bpm) > BiologicalAgeConfig.rhrElevatedCeiling { return .elevated }
        return .normal
    }
    private var heartSub: String {
        switch rhrBand {
        case .athletic: return Copy.OnboardingV2.s11SubAthletic
        case .normal:   return Copy.OnboardingV2.s11SubNormal
        case .elevated: return Copy.OnboardingV2.s11SubElevated
        }
    }
    private var heartBody: String {
        guard hasData else { return Copy.OnboardingV2.s11BodyEmpty }
        switch rhrBand {
        case .athletic: return Copy.OnboardingV2.s11BodyAthletic
        case .normal:   return Copy.OnboardingV2.s11BodyNormal
        case .elevated: return Copy.OnboardingV2.s11BodyElevated
        }
    }

    var body: some View {
        OnbV2ScreenContainer(ambient: .roseHero, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 8, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Copy.OnboardingV2.s11Eyebrow)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(OnbV2.rose)
                            Text(hasData ? Copy.OnboardingV2.s11TitleHasData : Copy.OnboardingV2.s11TitleEmpty)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.chart))

                        ekgCard
                            .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.chart))

                        if let bpm = snapshot.restingHR {
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                if phase.hasReached(.number) {
                                    OnbV2CountUp(
                                        target: Double(bpm),
                                        duration: 1.1,
                                        font: .system(size: 88, weight: .bold).monospacedDigit(),
                                        color: OnbV2.rose
                                    )
                                } else {
                                    Text("0")
                                        .font(.system(size: 88, weight: .bold).monospacedDigit())
                                        .foregroundStyle(OnbV2.rose)
                                }
                                Text(Copy.OnboardingV2.s11Unit)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)
                            }
                        } else {
                            Text(Copy.Onboarding.x)
                                .font(.system(size: 88, weight: .bold).monospacedDigit())
                                .foregroundStyle(OnbV2.fg4)
                        }

                        if hasData {
                            Text(heartSub)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(OnbV2.fg3)
                                .padding(.top, 4)
                                .opacity(phase.hasReached(.number) ? 1 : 0)
                                .animation(.easeOut(duration: 0.3), value: phase)
                        }

                        Text(heartBody)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                            .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.body))

                        if let months = snapshot.restingHRMonthsCovered {
                            Text(Copy.OnboardingV2.s11Footnote(months: months))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                                .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.body))
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s11CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
                    .opacity(phase.hasReached(.cta) ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: phase)
            }
        }
        // Number-only verticals get .number for free; gate the chart clock on
        // hasData so an empty-state heart still reveals body + CTA in order.
        .onbV2RevealClock($phase)
        // .success when the BPM lands (outcome), never on a request.
        .sensoryFeedback(.success, trigger: numberLanded)
        .onChange(of: phase) { _, new in
            // EKG draws on the chart beat (700ms), retimed from the old 1.8s so
            // the trace finishes before the number lands. Reduce Motion shows it
            // already drawn (the clock jumps straight to .cta).
            if new.hasReached(.chart), traceProgress == 0 {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.7)) {
                    traceProgress = 1
                }
            }
            guard hasData, new.hasReached(.number), !numberLanded else { return }
            numberLanded = true
            // One-shot trace pulse the instant the number arrives.
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { tracePulse = true }
            }
        }
        .onAppear {
            guard !revealTracked else { return }
            revealTracked = true
            AppAnalytics.shared.trackOnboardingHeartRevealed(
                hasData: hasData, monthsCovered: snapshot.restingHRMonthsCovered)
        }
    }

    private var ekgCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Copy.Onboarding.restingHRLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OnbV2.fg3)
                Spacer()
                if let months = snapshot.restingHRMonthsCovered {
                    Text("last \(months >= 12 ? "\(months / 12)y" : "\(months)mo")")
                        .font(.system(size: 11))
                        .foregroundStyle(OnbV2.fg3)
                } else {
                    Text(Copy.Onboarding.noDataYet)
                        .font(.system(size: 11))
                        .foregroundStyle(OnbV2.fg3)
                }
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 60
                ekgPath(width: w, height: h)
                    .trim(from: 0, to: traceProgress)
                    .stroke(
                        OnbV2.rose,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .scaleEffect(tracePulse ? 1.04 : 1, anchor: .center)
            }
            .frame(height: 60)
        }
        .padding(16)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnbV2.rose.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnbV2.rose.opacity(0.18), lineWidth: 1)
        )
    }

    private func ekgPath(width: CGFloat, height: CGFloat) -> Path {
        let pts: [CGPoint] = [
            CGPoint(x: 0,   y: 30),
            CGPoint(x: 40,  y: 30),
            CGPoint(x: 48,  y: 18),
            CGPoint(x: 56,  y: 42),
            CGPoint(x: 64,  y: 8),
            CGPoint(x: 72,  y: 30),
            CGPoint(x: 120, y: 30),
            CGPoint(x: 128, y: 22),
            CGPoint(x: 136, y: 38),
            CGPoint(x: 144, y: 30),
            CGPoint(x: 240, y: 30)
        ]
        let scaleX = width / 240
        let scaleY = height / 60
        var path = Path()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

// MARK: - Screen 12 — Sleep reveal

struct OnbV2Screen12Sleep: View {
    let snapshot: OnboardingHealthSnapshot
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var phase: RevealPhase = .hidden
    @State private var numberLanded = false
    @State private var targetLineEmphasis = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var hasData: Bool { snapshot.sleepAvgHours != nil }
    private var nightlyHours: [Double] { snapshot.sleepLast7Nights }

    /// Bars draw on the chart beat. The card's per-bar 0.09s cascade is now
    /// driven by the reveal clock instead of a bare onAppear flag.
    private var barsRevealed: Bool { phase.hasReached(.chart) }

    /// "Where you want to be": the upper of the standard 7-8h adult range that
    /// the body copy already frames as the goal. (The readiness scorer's 7.5h
    /// target is for daily scoring, a different purpose.)
    private let sleepGoalHours: Double = 8

    /// Minutes short of the goal, or nil when already at/above it.
    private var sleepGapMinutes: Int? {
        guard let h = snapshot.sleepAvgHours, let m = snapshot.sleepAvgMins else { return nil }
        let gap = Int(sleepGoalHours * 60) - (h * 60 + m)
        return gap > 0 ? gap : nil
    }

    /// Dynamic title: the gap phrase tinted purple, or the on-target variant.
    private var sleepTitleAttributed: AttributedString {
        guard let gap = sleepGapMinutes else {
            return AttributedString(Copy.OnboardingV2.s12TitleOnTarget)
        }
        let phrase = Copy.OnboardingV2.sleepGapPhrase(minutes: gap)
        var a = AttributedString(Copy.OnboardingV2.s12TitleGap(gap: phrase))
        if let r = a.range(of: phrase) {
            a[r].foregroundColor = OnbV2.purple
        }
        return a
    }

    var body: some View {
        OnbV2ScreenContainer(ambient: .purpleDual, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 9, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(Copy.OnboardingV2.s12Eyebrow)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(OnbV2.purple)
                            Group {
                                if hasData {
                                    Text(sleepTitleAttributed)
                                } else {
                                    Text(Copy.OnboardingV2.s12TitleEmpty)
                                }
                            }
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 20)
                        .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.chart))

                        sleepCard
                            .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.chart))

                        if let hours = snapshot.sleepAvgHours, let mins = snapshot.sleepAvgMins {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                if phase.hasReached(.number) {
                                    OnbV2CountUp(
                                        target: Double(hours),
                                        duration: 1.0,
                                        font: .system(size: 88, weight: .bold).monospacedDigit(),
                                        color: OnbV2.purple
                                    )
                                } else {
                                    Text("0")
                                        .font(.system(size: 88, weight: .bold).monospacedDigit())
                                        .foregroundStyle(OnbV2.purple)
                                }
                                Text(Copy.Onboarding.h)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)

                                Spacer().frame(width: 8)

                                if phase.hasReached(.number) {
                                    OnbV2CountUp(
                                        target: Double(mins),
                                        duration: 1.2,
                                        delay: 0.2,
                                        font: .system(size: 88, weight: .bold).monospacedDigit(),
                                        color: OnbV2.purple
                                    )
                                } else {
                                    Text("0")
                                        .font(.system(size: 88, weight: .bold).monospacedDigit())
                                        .foregroundStyle(OnbV2.purple)
                                }
                                Text(Copy.Onboarding.m)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)
                            }

                            (
                                Text(Copy.OnboardingV2.s12BodyPrefix)
                                    .foregroundStyle(OnbV2.fg2)
                                + Text(Copy.Onboarding.hMText(hours, mins))
                                    .foregroundStyle(OnbV2.fg).bold()
                                + Text(Copy.OnboardingV2.s12BodySuffix)
                                    .foregroundStyle(OnbV2.fg2)
                            )
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                            .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.body))
                        } else {
                            Text(Copy.Onboarding.x2)
                                .font(.system(size: 88, weight: .bold).monospacedDigit())
                                .foregroundStyle(OnbV2.fg4)

                            Text(Copy.OnboardingV2.s12BodyEmpty)
                                .font(.system(size: 16))
                                .foregroundStyle(OnbV2.fg2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                                .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.body))
                        }

                        if let months = snapshot.sleepMonthsCovered {
                            Text(Copy.OnboardingV2.s12Footnote(months: months))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                                .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.body))
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s12CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
                    .opacity(phase.hasReached(.cta) ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: phase)
            }
        }
        // staggeredBars: the card draws bar-by-bar, so the number beat waits for
        // the cascade to finish before the hours/mins count up.
        .onbV2RevealClock($phase, staggeredBars: true)
        .sensoryFeedback(.success, trigger: numberLanded)
        .onChange(of: phase) { _, new in
            guard hasData, new.hasReached(.number), !numberLanded else { return }
            numberLanded = true
            // Target line brightens the moment the average lands, tying the
            // 7h goal to the number the user just saw.
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.4)) {
                targetLineEmphasis = true
            }
        }
    }

    private var sleepCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Copy.Onboarding.last7NightsLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OnbV2.fg3)
                Spacer()
                Text(Copy.Onboarding.target7h)
                    .font(.system(size: 11))
                    .foregroundStyle(OnbV2.fg3)
            }

            ZStack(alignment: .top) {
                Path { p in
                    let y = (1 - 7.0 / 9.0) * 80
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: 10000, y: y))
                }
                // Brightens to the sleep accent once the average number lands,
                // visually tying the 7h target to the value just revealed.
                .stroke(targetLineEmphasis ? OnbV2.purple.opacity(0.7) : AppColour.chartZeroLine,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 80)

                if nightlyHours.isEmpty {
                    Text(Copy.Onboarding.noNightsRecorded)
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(height: 80)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(nightlyHours.enumerated()), id: \.offset) { idx, h in
                            let barHeight = CGFloat((h / 9.0) * 80)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [
                                        OnbV2.purple,
                                        Color(red: 0.43, green: 0.18, blue: 0.64)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .frame(maxWidth: .infinity)
                                .frame(height: barHeight)
                                .scaleEffect(y: barsRevealed ? 1 : 0, anchor: .bottom)
                                .animation(barAnimation(idx), value: barsRevealed)
                        }
                    }
                    .frame(height: 80, alignment: .bottom)
                }
            }
            .frame(height: 80)

            HStack(spacing: 8) {
                ForEach(Array(dayLetters.enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(OnbV2.fg3)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnbV2.purple.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnbV2.purple.opacity(0.18), lineWidth: 1)
        )
    }

    /// Per-bar entrance retimed off the reveal clock. Reduce Motion collapses
    /// the 0.09s cascade to a single short crossfade so bars land at once.
    private func barAnimation(_ idx: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        return .timingCurve(0.22, 1, 0.36, 1, duration: 0.8).delay(Double(idx) * 0.09)
    }
}

// MARK: - Screen 13 — HRV reveal

struct OnbV2Screen13HRV: View {
    let snapshot: OnboardingHealthSnapshot
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var phase: RevealPhase = .hidden
    @State private var numberLanded = false
    @State private var worstBarPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var hasPattern: Bool { snapshot.hrvWorstWeekday != nil }
    private var worstWeekdayName: String? { OnbHealthFormat.weekdayName(snapshot.hrvWorstWeekday) }

    /// Maps Calendar weekday (1=Sun..7=Sat) to dayLetters index (0=Mon..6=Sun).
    private var worstWeekdayLetterIndex: Int? {
        guard let w = snapshot.hrvWorstWeekday else { return nil }
        return w == 1 ? 6 : (w - 2)
    }

    /// Has at least 4 weekdays with real means — enough to draw a meaningful
    /// per-weekday chart. Below that we hide the bars and surface copy only.
    private var hasChartData: Bool {
        snapshot.hrvWeekdayMeans.compactMap { $0 }.count >= 4
    }

    /// The worst day's mean SDNN in ms, promoted to the hero number. Present
    /// only when a real worst-weekday pattern exists and that day has a mean.
    private var worstDayMs: Double? {
        guard hasPattern, let idx = worstWeekdayLetterIndex else { return nil }
        return snapshot.hrvWeekdayMeans[idx]
    }

    /// Bars draw on the chart beat with the same 0.09s cascade as the sleep
    /// card, replacing the old single-shot lineProgress.
    private var barsRevealed: Bool { phase.hasReached(.chart) }

    var body: some View {
        OnbV2ScreenContainer(ambient: .tealDual, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 10, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text(hasPattern ? Copy.OnboardingV2.s13EyebrowPattern : Copy.OnboardingV2.s13EyebrowEmpty)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(OnbV2.teal)
                            Text(hasPattern ? Copy.OnboardingV2.s13Title(weekday: worstWeekdayName ?? "Sunday") : Copy.OnboardingV2.s13TitleEmpty)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)
                        .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.chart))

                        hrvCard
                            .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.chart))

                        // Worst-day ms promoted to a hero number that fills the
                        // void the old layout left below the card. Only when a
                        // real worst-day mean exists; otherwise copy carries it.
                        if let ms = worstDayMs {
                            HStack(alignment: .lastTextBaseline, spacing: 6) {
                                if phase.hasReached(.number) {
                                    OnbV2CountUp(
                                        target: ms,
                                        duration: 1.1,
                                        font: .system(size: 88, weight: .bold).monospacedDigit(),
                                        color: OnbV2.teal
                                    )
                                } else {
                                    Text("0")
                                        .font(.system(size: 88, weight: .bold).monospacedDigit())
                                        .foregroundStyle(OnbV2.teal)
                                }
                                Text(Copy.Onboarding.ms)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)
                            }
                        }

                        if hasPattern, let weekday = worstWeekdayName {
                            (
                                Text(Copy.OnboardingV2.s13BodyPrefix(weekday: weekday))
                                    .foregroundStyle(OnbV2.fg2)
                                + Text(Copy.OnboardingV2.s13BodyBold)
                                    .foregroundStyle(OnbV2.fg).bold()
                                + Text(Copy.OnboardingV2.s13BodySuffix)
                                    .foregroundStyle(OnbV2.fg2)
                            )
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                            .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.body))
                        } else {
                            Text(Copy.OnboardingV2.s13BodyEmpty)
                                .font(.system(size: 16))
                                .foregroundStyle(OnbV2.fg2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                                .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.body))
                        }

                        if let weeks = snapshot.hrvWeeksCovered, weeks > 0 {
                            Text(Copy.OnboardingV2.s13Footnote(weeks: weeks))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                                .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.body))
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s13CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
                    .opacity(phase.hasReached(.cta) ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: phase)
            }
        }
        // staggeredBars only when there is a chart to cascade; without one the
        // clock should not stall on a 1350ms chart beat that draws nothing.
        .onbV2RevealClock($phase, staggeredBars: hasChartData)
        .sensoryFeedback(.success, trigger: numberLanded)
        .onChange(of: phase) { _, new in
            guard worstDayMs != nil, new.hasReached(.number), !numberLanded else { return }
            numberLanded = true
            // One-shot worst-bar pulse when the hero ms lands.
            if !reduceMotion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { worstBarPulse = true }
            }
        }
    }

    private var hrvCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text(Copy.Onboarding.hrvWeeklyAverage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(OnbV2.fg3)
                Spacer()
                if let avg = snapshot.hrvWeeklyAvgMs {
                    Text("\(String(format: "%.1f", avg)) ms")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(OnbV2.teal)
                } else {
                    Text(Copy.Onboarding.noDataYet2)
                        .font(.system(size: 11))
                        .foregroundStyle(OnbV2.fg3)
                }
            }

            if hasChartData {
                weekdayBarChart
                    .frame(height: 80)
            } else {
                Text(Copy.Onboarding.notEnoughHRVSamples)
                    .font(.system(size: 12))
                    .foregroundStyle(OnbV2.fg4)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }

            HStack(spacing: 8) {
                ForEach(Array(dayLetters.enumerated()), id: \.offset) { idx, d in
                    let isWorst = (idx == worstWeekdayLetterIndex)
                    Text(d)
                        // Worst-day letter morphs to bold + teal once the hero
                        // ms has landed, drawing the eye to the day it names.
                        .font(.system(size: 11, weight: isWorst && numberLanded ? .bold : .medium))
                        .foregroundStyle(isWorst && numberLanded ? OnbV2.teal : OnbV2.fg3)
                        .animation(.easeOut(duration: 0.3), value: numberLanded)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnbV2.teal.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnbV2.teal.opacity(0.18), lineWidth: 1)
        )
    }

    /// Renders one bar per weekday from real HRV means. Bars are normalized
    /// to the min/max range of present weekdays so visual differences are
    /// visible even when the absolute range is small. Missing weekdays render
    /// as a faint placeholder. The per-bar 0.09s cascade and worst-bar pulse
    /// are driven off the reveal clock.
    private var weekdayBarChart: some View {
        let means = snapshot.hrvWeekdayMeans
        let present = means.compactMap { $0 }
        let minVal = present.min() ?? 0
        let maxVal = present.max() ?? 1
        let range = max(1, maxVal - minVal)

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { idx in
                if let value = means[idx] {
                    let normalized = (value - minVal) / range
                    let barHeight: CGFloat = 12 + CGFloat(normalized) * 56
                    let isWorst = (idx == worstWeekdayLetterIndex)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(
                            colors: isWorst
                                ? [OnbV2.teal, OnbV2.teal.opacity(0.4)]
                                : [OnbV2.teal.opacity(0.7), OnbV2.teal.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight)
                        .scaleEffect(y: barsRevealed ? 1 : 0, anchor: .bottom)
                        .scaleEffect(isWorst && worstBarPulse ? 1.06 : 1, anchor: .bottom)
                        .animation(barAnimation(idx), value: barsRevealed)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColour.trackNeutral)
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)
                }
            }
        }
    }

    /// Per-bar entrance retimed off the clock, mirroring the sleep card's
    /// 0.09s reading-order cascade. Reduce Motion collapses to a single fade.
    private func barAnimation(_ idx: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        return .timingCurve(0.22, 1, 0.36, 1, duration: 0.8).delay(Double(idx) * 0.09)
    }
}

/// A horizontal line spanning its frame, drawn dashed for a reference rule.
struct DashedHLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Screen — Verdict (rich branch)

/// Instant verdict on the pre-registered prediction, shown only when the
/// snapshot is data-rich. Confirmed, refuted, and inconclusive each get an
/// honest framing. Side discoveries appear under a mandatory label and never
/// replace the prediction's answer.
///
/// Layout: a proof card fills what was empty space. Confirmed shows a weekday
/// bar chart with the driver day highlighted plus the magnitude as a CountUp
/// number; refuted shows an honest "what we checked" tile (no fake chart);
/// inconclusive shows a subtle forming-pattern state. A P2 reveal clock stages
/// the beats chart -> magnitude -> title+body -> CTA so the answer lands, not
/// dumps.
struct OnbV2ScreenVerdict: View {
    let prediction: PreRegisteredPrediction
    let verdict: PredictionVerdict
    /// Per-weekday means (Mon..Sun, index 0..6) for the proof chart. Threaded
    /// from the snapshot's HRV weekday analysis — no second HealthKit query.
    let weekdayMeans: [Double?]
    let onContinue: () -> Void

    @State private var phase: RevealPhase = .hidden
    @State private var titleLanded = false
    @State private var worstBarPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Confirmed-only: the driver weekday mapped from Calendar (1=Sun..7=Sat)
    /// into the chart's Mon..Sun index (0..6), matching the HRV screen's map.
    private var highlightLetterIndex: Int? {
        guard verdict.zone == .confirmed, let w = verdict.weekday else { return nil }
        return w == 1 ? 6 : (w - 2)
    }

    /// True only for confirmed verdicts that have enough present weekdays to
    /// draw a meaningful proof chart. Below that the confirmed branch still
    /// reads honestly from copy without a thin, misleading chart.
    private var hasChartData: Bool {
        verdict.zone == .confirmed && weekdayMeans.compactMap { $0 }.count >= 4
    }

    var body: some View {
        OnbV2ScreenContainer(ambient: ambient, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(accent)
                            .onbV2StaggerIn(index: 0, appeared: phase.hasReached(.chart))

                        Text(titleAttributed)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .onbV2StaggerIn(index: 1, appeared: phase.hasReached(.chart))

                        Text(bodyText)
                            .font(.system(size: 17))
                            .foregroundStyle(OnbV2.fg2)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .onbV2StaggerIn(index: 2, appeared: phase.hasReached(.chart))

                        proofCard
                            .opacity(phase.hasReached(.chart) ? 1 : 0)
                            .padding(.top, 10)

                        if let side = sideDiscoveryText {
                            Text(side)
                                .font(.system(size: 13.5))
                                .foregroundStyle(OnbV2.fg3)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                                .onbV2StaggerIn(index: 3, appeared: phase.hasReached(.body))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(ctaTitle, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
                    .opacity(phase.hasReached(.cta) ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: phase)
            }
        }
        .onbV2RevealClock($phase, staggeredBars: hasChartData)
        // Outcome haptic: the verdict title is the payoff, so .success lands
        // when the body beat reveals it (never on a request, per the ladder).
        .sensoryFeedback(.success, trigger: titleLanded)
        .onChange(of: phase) { _, new in
            if new.hasReached(.body) { titleLanded = true }
        }
        .onAppear {
            AppAnalytics.shared.trackVerdictDelivered(
                zone: verdict.zone.rawValue,
                magnitudeBand: verdict.magnitude?.band.rawValue ?? "",
                weekday: verdict.weekday ?? -1,
                nightsRemaining: verdict.nightsRemaining ?? -1,
                sideDiscoveryCount: verdict.sideDiscoveries.count
            )
        }
    }

    // MARK: - Proof card (fills the void with the verdict's own data)

    @ViewBuilder
    private var proofCard: some View {
        switch verdict.zone {
        case .confirmed:    confirmedProof
        case .refuted:      refutedProof
        case .inconclusive: inconclusiveProof
        }
    }

    /// Confirmed: the driver day highlighted in red against the weekly-average
    /// dashed line, with full weekday names and an honest source caption. The
    /// magnitude now lives in the body sentence, so there is no hero number.
    private var confirmedProof: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasChartData {
                weekdayBarChart
                    .frame(height: 96)
                    // Red dashed line at the weekly average so the driver day's
                    // shift reads against the norm. Fades in once the bars land.
                    .overlay(alignment: .bottom) {
                        DashedHLine()
                            .stroke(OnbV2.rose.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(height: 2)
                            .padding(.bottom, avgBarHeight)
                            .opacity(phase.hasReached(.number) ? 1 : 0)
                            .animation(.easeOut(duration: 0.3), value: phase)
                    }

                HStack(spacing: 6) {
                    ForEach(Array(dayNames.enumerated()), id: \.offset) { idx, d in
                        let isWorst = (idx == highlightLetterIndex)
                        Text(d)
                            .font(.system(size: 12, weight: isWorst ? .bold : .medium))
                            .foregroundStyle(isWorst ? OnbV2.rose : OnbV2.fg3)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Text(Copy.OnboardingV2.verdictChartCaption)
                    .font(.system(size: 13))
                    .foregroundStyle(OnbV2.fg4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Full weekday names for the confirmed proof chart's axis.
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// Height of the weekly-average bar, in the bars' own scale, so the red
    /// dashed reference line lands at the norm the driver day deviates from.
    private var avgBarHeight: CGFloat {
        let present = weekdayMeans.compactMap { $0 }
        guard !present.isEmpty else { return 0 }
        let minVal = present.min() ?? 0
        let maxVal = present.max() ?? 1
        let range = max(1, maxVal - minVal)
        let avg = present.reduce(0, +) / Double(present.count)
        return 16 + CGFloat((avg - minVal) / range) * 72
    }

    /// One bar per weekday from the threaded means, normalized to the present
    /// range so small absolute gaps stay visible. The driver day gets the full
    /// accent and a one-shot pulse on land; missing days render faint.
    private var weekdayBarChart: some View {
        let present = weekdayMeans.compactMap { $0 }
        let minVal = present.min() ?? 0
        let maxVal = present.max() ?? 1
        let range = max(1, maxVal - minVal)

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<7, id: \.self) { idx in
                if let value = weekdayMeans[idx] {
                    let normalized = (value - minVal) / range
                    let barHeight: CGFloat = 16 + CGFloat(normalized) * 72
                    let isWorst = (idx == highlightLetterIndex)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(
                            colors: isWorst
                                ? [OnbV2.rose, OnbV2.rose.opacity(0.4)]
                                : [accent.opacity(0.55), accent.opacity(0.2)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight)
                        .scaleEffect(y: phase.hasReached(.chart) ? 1 : 0, anchor: .bottom)
                        .scaleEffect(isWorst && worstBarPulse ? 1.06 : 1, anchor: .bottom)
                        .animation(barAnimation(idx), value: phase)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColour.trackNeutral)
                        .frame(maxWidth: .infinity)
                        .frame(height: 16)
                }
            }
        }
        // One-shot pulse on the driver bar once the chart finishes drawing.
        .onChange(of: phase) { _, new in
            guard !reduceMotion, new.hasReached(.number), !worstBarPulse else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { worstBarPulse = true }
        }
    }

    /// Per-bar draw retimed off the reveal clock so the chart fills bar-by-bar
    /// in reading order, finishing before the number beat lands. Reduce Motion
    /// collapses the cascade to one short crossfade.
    private func barAnimation(_ idx: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        return .timingCurve(0.22, 1, 0.36, 1, duration: 0.7).delay(Double(idx) * 0.09)
    }

    /// Refuted: no chart (there is no pattern to draw). An honest tile naming
    /// the dead end ruled out and the metric we keep watching instead. Built
    /// from existing copy — no fabricated visual.
    private var refutedProof: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.14))
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 60, height: 60)

            Text(Copy.OnboardingV2.metricWatchLabel(prediction.metric))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OnbV2.fg)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }

    /// Inconclusive: a subtle forming-pattern state — faint bars settling, no
    /// highlight, signalling the answer is still taking shape.
    private var inconclusiveProof: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: formingHeights[idx])
                        .scaleEffect(y: phase.hasReached(.chart) ? 1 : 0, anchor: .bottom)
                        .animation(barAnimation(idx), value: phase)
                }
            }
            .frame(height: 72)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }

    /// Fixed gentle silhouette for the forming state — deliberately even so it
    /// reads as "still settling", not a real pattern with a winner.
    private let formingHeights: [CGFloat] = [34, 46, 40, 52, 44, 38, 48]

    private var ambient: OnbV2Ambient {
        switch verdict.zone {
        case .confirmed:    return .blueDual
        case .refuted:      return .blueDual
        case .inconclusive: return .mix
        }
    }

    private var accent: Color {
        switch verdict.zone {
        case .confirmed:    return OnbV2.blue
        case .refuted:      return OnbV2.green
        case .inconclusive: return OnbV2.amber
        }
    }

    /// Confirmed gets a coaching CTA; the other zones keep the neutral Continue.
    private var ctaTitle: String {
        verdict.zone == .confirmed
            ? Copy.OnboardingV2.verdictConfirmedCTA
            : Copy.OnboardingV2.verdictCTA
    }

    private var eyebrow: String {
        switch verdict.zone {
        case .confirmed:    return Copy.OnboardingV2.verdictConfirmedEyebrow
        case .refuted:      return Copy.OnboardingV2.verdictRefutedEyebrow
        case .inconclusive: return Copy.OnboardingV2.verdictInconclusiveEyebrow
        }
    }

    private var title: String {
        switch verdict.zone {
        case .confirmed:    return Copy.OnboardingV2.verdictConfirmedTitle
        case .refuted:      return Copy.OnboardingV2.verdictRefutedTitle
        case .inconclusive: return Copy.OnboardingV2.verdictInconclusiveTitle
        }
    }

    /// Confirmed title tints its accent word ("Yours") blue; other zones plain.
    private var titleAttributed: AttributedString {
        var a = AttributedString(title)
        if verdict.zone == .confirmed,
           let r = a.range(of: Copy.OnboardingV2.verdictConfirmedTitleAccent) {
            a[r].foregroundColor = OnbV2.blueLight
        }
        return a
    }

    private var bodyText: String {
        switch verdict.zone {
        case .confirmed:
            let magnitude = verdict.magnitude.map {
                Copy.OnboardingV2.bandPhrase(band: $0.band, value: $0.value)
            } ?? Copy.OnboardingV2.metricWatchLabel(prediction.metric)
            let weekday = OnbHealthFormat.weekdayName(verdict.weekday) ?? ""
            return Copy.OnboardingV2.verdictConfirmedBody(
                metric: Copy.OnboardingV2.metricWatchLabel(prediction.metric),
                magnitude: magnitude,
                weekday: weekday,
                outcome: outcomePhrase
            )
        case .refuted:
            return Copy.OnboardingV2.verdictRefutedBody(
                outcome: outcomePhrase,
                watch: Copy.OnboardingV2.metricWatchLabel(prediction.metric)
            )
        case .inconclusive:
            // nightsRemaining is nil once the data bar is met; fall back to the
            // minimum data bar so copy never shows "0 more nights".
            let nights = verdict.nightsRemaining ?? InsightConfig.GroupDifference.minSamples
            return Copy.OnboardingV2.verdictInconclusiveBody(nights: nights)
        }
    }

    /// First side discovery only, under the mandatory label. Never shown for a
    /// refuted verdict (the honest pivot already names the metric to watch).
    private var sideDiscoveryText: String? {
        guard verdict.zone != .refuted,
              let side = verdict.sideDiscoveries.first,
              let weekday = OnbHealthFormat.weekdayName(side.weekday) else { return nil }
        return Copy.OnboardingV2.verdictSideDiscovery(
            metric: Copy.OnboardingV2.metricWatchLabel(side.metric),
            weekday: weekday
        )
    }

    private var outcomePhrase: String {
        let phrase = prediction.userPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return phrase.isEmpty ? Copy.OnboardingV2.metricWatchLabel(prediction.metric) : phrase.lowercasedFirst
    }
}

// MARK: - Screen — Cliffhanger (sparse branch)

/// Shown when Health is granted but the predicted metric has too little data
/// for a verdict. Promises a real answer in N nights and offers a contextual
/// notification opt-in. The system permission prompt fires only after the user
/// taps yes.
struct OnbV2ScreenCliffhanger: View {
    let nightsRemaining: Int
    /// The user's own goal or symptom words, used verbatim by the answer-ready
    /// push. nil only on the deep-linked test path, where no prediction exists —
    /// the sample notification is replaced by the heart rather than invented.
    let userPhrase: String?
    /// Fires the system notification prompt; returns the granted state.
    let onNotifyYes: () async -> Void
    let onContinue: () -> Void

    @State private var notifyHandled = false
    @State private var appeared = false
    @State private var notifyPressed = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blueDual, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                Spacer(minLength: 0)

                Group {
                    if let userPhrase {
                        lockScreenPreview(phrase: userPhrase)
                    } else {
                        OnbV2HeartHero(size: 180, color: OnbV2.blue)
                    }
                }
                .onbV2StaggerIn(index: 0, appeared: appeared)

                Spacer().frame(height: 28)

                // Group 1: eyebrow + title + body — the promise.
                VStack(spacing: 14) {
                    Text(Copy.OnboardingV2.cliffhangerEyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(OnbV2.blue)

                    Text(Copy.OnboardingV2.cliffhangerTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .multilineTextAlignment(.center)

                    // nightsRemaining stays inside the sentence — the copy does
                    // not split cleanly around it, so no CountUp (no copy surgery).
                    Text(Copy.OnboardingV2.cliffhangerBody(nights: nightsRemaining))
                        .font(.system(size: 16))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, OnbV2.bodyPadH)
                }
                .onbV2StaggerIn(index: 1, appeared: appeared)

                Spacer(minLength: 0)

                // Group 2: the notification opt-in.
                VStack(spacing: 12) {
                    Text(Copy.OnboardingV2.cliffhangerNotifyTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    OnbV2PrimaryCTA(Copy.OnboardingV2.cliffhangerNotifyYes, isEnabled: !notifyHandled) {
                        notifyHandled = true
                        notifyPressed.toggle()
                        Task {
                            await onNotifyYes()
                            onContinue()
                        }
                    }

                    OnbV2GhostCTA(Copy.OnboardingV2.cliffhangerSkip, action: {
                        AppAnalytics.shared.trackOnboardingNotificationSkipped(source: "cliffhanger")
                        onContinue()
                    })
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
                .onbV2StaggerIn(index: 2, appeared: appeared)
            }
        }
        // Notify is an ordinary CTA (not a HealthKit/Purchase ask), so the
        // press itself is .impact(.light); the system prompt that follows is
        // its own outcome, owned by iOS.
        .sensoryFeedback(.impact(weight: .light), trigger: notifyPressed)
        // promise_shown is fired by the flow router, which owns the one-shot
        // guard against the back-nav scan re-run recreating this screen.
        .onAppear { appeared = true }
    }

    /// A lock screen carrying the exact push we send when the answer matures, so
    /// the opt-in shows the payoff instead of describing it. The clock is the
    /// real current time and the banner text comes from the shipped notification
    /// copy, so nothing on this preview is invented.
    private func lockScreenPreview(phrase: String) -> some View {
        VStack(spacing: 8) {
            Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.system(size: 12))
                .foregroundStyle(OnbV2.fg3)

            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(OnbV2.fg)

            pushBanner(phrase: phrase)
                .padding(.top, 6)

            // Dimmed stand-ins for everything else on a lock screen, so the Laso
            // banner reads as the top card rather than a floating tooltip.
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColour.borderLow)
                    .frame(height: 32)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [OnbV2.blue.opacity(0.22), OnbV2.bg2],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(OnbV2.line, lineWidth: 1)
        )
        .padding(.horizontal, OnbV2.bodyPadH)
        .accessibilityElement(children: .combine)
    }

    /// iOS renders banners on a light card in both themes, so this uses the
    /// fixed-polarity pair rather than the adaptive surface/text tokens.
    private func pushBanner(phrase: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image("LaunchIcon")
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Copy.Labels.appName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColour.textOnLightFixed.opacity(0.85))
                    Spacer(minLength: 0)
                    Text(Copy.OnboardingV2.cliffhangerPushTime)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColour.textOnLightFixed.opacity(0.5))
                }

                Text(Copy.Notifications.answerReadyTitle(phrase: phrase))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColour.textOnLightFixed)

                Text(Copy.Notifications.answerReadyBody(phrase: phrase))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColour.textOnLightFixed.opacity(0.62))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColour.surfaceFixedLight)
        )
    }
}

// MARK: - Screen — Journal first (denied branch)

/// Shown when no Health data is available. Pitches the morning check in and
/// journal so the user can still benefit, with no instant verdict.
struct OnbV2ScreenJournalFirst: View {
    let onContinue: () -> Void

    @State private var appeared = false
    @State private var ctaPressed = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blueDual, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                VStack(alignment: .leading, spacing: 14) {
                    Text(Copy.OnboardingV2.journalFirstEyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(OnbV2.blue)
                        .onbV2StaggerIn(index: 0, appeared: appeared)

                    Text(Copy.OnboardingV2.journalFirstTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onbV2StaggerIn(index: 1, appeared: appeared)

                    Text(Copy.OnboardingV2.journalFirstBody)
                        .font(.system(size: 16))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .onbV2StaggerIn(index: 2, appeared: appeared)

                    sampleChart
                        .padding(.top, 18)
                        .onbV2StaggerIn(index: 3, appeared: appeared)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.top, 8)

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.journalFirstCTA) {
                    ctaPressed.toggle()
                    onContinue()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
                .onbV2StaggerIn(index: 4, appeared: appeared)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaPressed)
        // promise_shown is fired by the flow router, which owns the one-shot
        // guard against the back-nav scan re-run recreating this screen.
        .onAppear { appeared = true }
    }

    /// Illustrative weekly trend. The denied branch has no real data yet, so the
    /// body frames this as an example of what a week of check-ins reads like —
    /// never the user's own numbers. Red days are the standouts a trend surfaces.
    private var sampleChart: some View {
        let bars: [(h: CGFloat, red: Bool, dim: Bool)] = [
            (0.55, false, false), (0.72, false, false), (0.40, false, true),
            (0.82, false, false), (0.88, true, false), (0.80, false, false), (1.0, true, false)
        ]
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(
                            colors: bars[i].red
                                ? [OnbV2.rose, OnbV2.rose.opacity(0.4)]
                                : (bars[i].dim
                                    ? [OnbV2.blue.opacity(0.3), OnbV2.blue.opacity(0.12)]
                                    : [OnbV2.blueLight, OnbV2.blue]),
                            startPoint: .top, endPoint: .bottom))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28 + bars[i].h * 92)
                        // Neutral glow so the bars read lit, not flat. A tinted
                        // zero-offset shadow smears into a coloured halo on light.
                        .shadow(color: bars[i].dim ? .clear : AppColour.glowTint, radius: 8, x: 0, y: 0)
                        .scaleEffect(y: appeared ? 1 : 0, anchor: .bottom)
                        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.7).delay(Double(i) * 0.06), value: appeared)
                }
            }
            .frame(height: 130, alignment: .bottom)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Text(names[i])
                        .font(.system(size: 12, weight: bars[i].red ? .bold : .medium))
                        .foregroundStyle(bars[i].red ? OnbV2.rose : OnbV2.fg3)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(Copy.OnboardingV2.journalFirstChartCaption)
                .font(.system(size: 13))
                .foregroundStyle(OnbV2.fg4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }
}

// MARK: - String helper

