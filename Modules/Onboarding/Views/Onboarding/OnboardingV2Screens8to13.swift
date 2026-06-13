import SwiftUI

// MARK: - Screen 8 — Bridge

struct OnbV2Screen8Bridge: View {
    let goal: OnbV2Goal?
    let onBack: () -> Void
    let onCTA: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 9, total: OnbV2Flow.total, onBack: onBack)

                Spacer(minLength: 0)

                OnbV2HeartHero(size: 200, color: OnbV2.blue)

                Spacer().frame(height: 28)

                Text(Copy.OnboardingV2.s8Title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer().frame(height: 16)

                Text(Copy.OnboardingV2.bridgeLede(for: goal))
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer().frame(height: 24)

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
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().stroke(OnbV2.line, lineWidth: 1))

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.s8CTA, action: onCTA)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Screen 10 — Scan

struct OnbV2Screen10Scan: View {
    let snapshot: OnboardingHealthSnapshot
    let onComplete: () -> Void

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
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 10, total: OnbV2Flow.total, onBack: nil, hideProgress: false)

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
                            Capsule().fill(Color.white.opacity(0.08))
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
                        .foregroundStyle(.white)
                        .font(.system(size: 30, weight: .bold))
                )
                .scaleEffect(pulse ? 1.08 : 0.96)
                .animation(
                    .timingCurve(0.4, 0, 0.6, 1, duration: 0.9)
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
                .fill(visible && hasData ? OnbV2.blue.opacity(0.08) : Color.white.opacity(0.03))
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

        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            spin1 = 360
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            spin2 = -360
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            spin3 = 360
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

    private var hasData: Bool { snapshot.restingHR != nil }

    var body: some View {
        OnbV2ScreenContainer(ambient: .rose) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 12, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text(Copy.OnboardingV2.s11Eyebrow)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(OnbV2.rose)
                            Text(hasData ? Copy.OnboardingV2.s11TitleHasData : Copy.OnboardingV2.s11TitleEmpty)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        ekgCard

                        if let bpm = snapshot.restingHR {
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                OnbV2CountUp(
                                    target: Double(bpm),
                                    duration: 1.6,
                                    font: .system(size: 88, weight: .bold).monospacedDigit(),
                                    color: OnbV2.rose
                                )
                                Text(Copy.OnboardingV2.s11Unit)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)
                            }
                        } else {
                            Text(Copy.Onboarding.x)
                                .font(.system(size: 88, weight: .bold).monospacedDigit())
                                .foregroundStyle(OnbV2.fg4)
                        }

                        Text(hasData ? Copy.OnboardingV2.s11BodyHasData : Copy.OnboardingV2.s11BodyEmpty)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)

                        if let months = snapshot.restingHRMonthsCovered {
                            Text(Copy.OnboardingV2.s11Footnote(months: months))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s11CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).delay(0.2)) {
                traceProgress = 1
            }
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

    @State private var barsRevealed: Bool = false

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private var hasData: Bool { snapshot.sleepAvgHours != nil }
    private var nightlyHours: [Double] { snapshot.sleepLast7Nights }

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 13, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text(Copy.OnboardingV2.s12Eyebrow)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(OnbV2.purple)
                            Text(hasData ? Copy.OnboardingV2.s12TitleHasData : Copy.OnboardingV2.s12TitleEmpty)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        sleepCard

                        if let hours = snapshot.sleepAvgHours, let mins = snapshot.sleepAvgMins {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                OnbV2CountUp(
                                    target: Double(hours),
                                    duration: 1.2,
                                    font: .system(size: 88, weight: .bold).monospacedDigit(),
                                    color: OnbV2.purple
                                )
                                Text(Copy.Onboarding.h)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(OnbV2.fg3)

                                Spacer().frame(width: 8)

                                OnbV2CountUp(
                                    target: Double(mins),
                                    duration: 1.5,
                                    delay: 0.2,
                                    font: .system(size: 88, weight: .bold).monospacedDigit(),
                                    color: OnbV2.purple
                                )
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
                        } else {
                            Text(Copy.Onboarding.x2)
                                .font(.system(size: 88, weight: .bold).monospacedDigit())
                                .foregroundStyle(OnbV2.fg4)

                            Text(Copy.OnboardingV2.s12BodyEmpty)
                                .font(.system(size: 16))
                                .foregroundStyle(OnbV2.fg2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }

                        if let months = snapshot.sleepMonthsCovered {
                            Text(Copy.OnboardingV2.s12Footnote(months: months))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s12CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            barsRevealed = true
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
                .stroke(Color.white.opacity(0.25),
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
                                .animation(
                                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.8)
                                        .delay(Double(idx) * 0.09),
                                    value: barsRevealed
                                )
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
}

// MARK: - Screen 13 — HRV reveal

struct OnbV2Screen13HRV: View {
    let snapshot: OnboardingHealthSnapshot
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var lineProgress: CGFloat = 0

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

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 14, total: OnbV2Flow.total, onBack: onBack)

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

                        hrvCard

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
                        } else {
                            Text(Copy.OnboardingV2.s13BodyEmpty)
                                .font(.system(size: 16))
                                .foregroundStyle(OnbV2.fg2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }

                        if let weeks = snapshot.hrvWeeksCovered, weeks > 0 {
                            Text(Copy.OnboardingV2.s13Footnote(weeks: weeks))
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s13CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9)) {
                lineProgress = 1
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
                        .font(.system(size: 11, weight: isWorst ? .bold : .medium))
                        .foregroundStyle(isWorst ? OnbV2.teal : OnbV2.fg3)
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
    /// as a faint placeholder.
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
                        .scaleEffect(y: lineProgress, anchor: .bottom)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)
                }
            }
        }
    }
}

// MARK: - Screen — Prediction (pre-registered claim)

/// Shown after the symptom capture, before the HealthKit ask. States the claim
/// Laso will test, built from the user's own goal + symptom words, with no
/// timing promise — the data branch decides when the answer is ready.
struct OnbV2ScreenPrediction: View {
    let prediction: PreRegisteredPrediction
    let onBack: () -> Void
    let onCTA: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 6, total: OnbV2Flow.total, onBack: onBack)

                Spacer(minLength: 0)

                OnbV2HeartHero(size: 180, color: OnbV2.blue)

                Spacer().frame(height: 28)

                Text(Copy.OnboardingV2.predictionEyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(OnbV2.blue)

                Spacer().frame(height: 12)

                Text(Copy.OnboardingV2.predictionTitle(
                    claim: Copy.OnboardingV2.metricClaimPhrase(prediction.metric),
                    outcome: outcomePhrase
                ))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(OnbV2.fg)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, OnbV2.bodyPadH)

                Spacer().frame(height: 16)

                Text(Copy.OnboardingV2.predictionFootnote)
                    .font(.system(size: 14))
                    .foregroundStyle(OnbV2.fg3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.predictionCTA, action: onCTA)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            AnalyticsBackend.provider.capture(
                event: "promise_shown",
                properties: ["metric": prediction.metric.rawValue]
            )
        }
    }

    /// The user's own symptom or goal words, lowercased so it reads naturally
    /// inside the sentence. Falls back to a neutral phrase if somehow empty.
    private var outcomePhrase: String {
        let phrase = prediction.userPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return phrase.isEmpty ? Copy.OnboardingV2.metricWatchLabel(prediction.metric) : phrase.lowercasedFirst
    }
}

// MARK: - Screen — Verdict (rich branch)

/// Instant verdict on the pre-registered prediction, shown only when the
/// snapshot is data-rich. Confirmed, refuted, and inconclusive each get an
/// honest framing. Side discoveries appear under a mandatory label and never
/// replace the prediction's answer.
struct OnbV2ScreenVerdict: View {
    let prediction: PreRegisteredPrediction
    let verdict: PredictionVerdict
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: ambient) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text(eyebrow)
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(accent)
                            Text(title)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 24)

                        Text(bodyText)
                            .font(.system(size: 17))
                            .foregroundStyle(OnbV2.fg2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 340)
                            .fixedSize(horizontal: false, vertical: true)

                        if let side = sideDiscoveryText {
                            Text(side)
                                .font(.system(size: 13.5))
                                .foregroundStyle(OnbV2.fg3)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 16)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.verdictCTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            AnalyticsBackend.provider.capture(
                event: "verdict_delivered",
                properties: [
                    "zone": verdict.zone.rawValue,
                    "magnitude_band": verdict.magnitude?.band.rawValue ?? "",
                    "weekday": verdict.weekday ?? -1,
                    "nights_remaining": verdict.nightsRemaining ?? -1,
                    "side_discovery_count": verdict.sideDiscoveries.count
                ]
            )
        }
    }

    private var ambient: OnbV2Ambient {
        switch verdict.zone {
        case .confirmed:    return .blue
        case .refuted:      return .blue
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
    /// Fires the system notification prompt; returns the granted state.
    let onNotifyYes: () async -> Void
    let onContinue: () -> Void

    @State private var notifyHandled = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                Spacer(minLength: 0)

                OnbV2HeartHero(size: 180, color: OnbV2.blue)

                Spacer().frame(height: 28)

                Text(Copy.OnboardingV2.cliffhangerEyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(OnbV2.blue)

                Spacer().frame(height: 12)

                Text(Copy.OnboardingV2.cliffhangerTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 14)

                Text(Copy.OnboardingV2.cliffhangerBody(nights: nightsRemaining))
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Text(Copy.OnboardingV2.cliffhangerNotifyTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    OnbV2PrimaryCTA(Copy.OnboardingV2.cliffhangerNotifyYes, isEnabled: !notifyHandled) {
                        notifyHandled = true
                        Task {
                            await onNotifyYes()
                            onContinue()
                        }
                    }

                    OnbV2GhostCTA(Copy.OnboardingV2.cliffhangerSkip, action: onContinue)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            AnalyticsBackend.provider.capture(
                event: "promise_shown",
                properties: ["branch": "cliffhanger", "nights_remaining": nightsRemaining]
            )
        }
    }
}

// MARK: - Screen — Journal first (denied branch)

/// Shown when no Health data is available. Pitches the morning check in and
/// journal so the user can still benefit, with no instant verdict.
struct OnbV2ScreenJournalFirst: View {
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .rose) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: nil, hideProgress: true)

                Spacer(minLength: 0)

                OnbV2HeartHero(size: 180, color: OnbV2.rose)

                Spacer().frame(height: 28)

                Text(Copy.OnboardingV2.journalFirstEyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(OnbV2.rose)

                Spacer().frame(height: 12)

                Text(Copy.OnboardingV2.journalFirstTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 14)

                Text(Copy.OnboardingV2.journalFirstBody)
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, OnbV2.bodyPadH)

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.journalFirstCTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            AnalyticsBackend.provider.capture(
                event: "promise_shown",
                properties: ["branch": "journal_first"]
            )
        }
    }
}

// MARK: - String helper

private extension String {
    /// Lowercases only the first character so a user phrase like "Tired
    /// mornings" reads naturally mid-sentence without touching acronyms later
    /// in the string.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }
}
