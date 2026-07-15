import SwiftUI

// Vitality Age reveal. Step 7 on the rich branch (right after the scan,
// where it also primes the notification ask), step 11 on sparse/denied.
// The user's age counts up, four health signals fly into a particle orb and
// recalculate it, then it settles on the Vitality Age. Native port of the
// approved web prototype. NOTE: the metric values and deltas here are
// illustrative placeholders for the reveal; wiring real snapshot data is a
// follow-up.

// MARK: - Particle model

private struct OrbParticle {
    let x, y, z: Double
    let size, alpha, twS, twPhase: Double
    let white: Bool
}

private func makeOrbParticles(_ count: Int = 720) -> [OrbParticle] {
    var out: [OrbParticle] = []
    out.reserveCapacity(count)
    for _ in 0..<count {
        let u = Double.random(in: 0...1), v = Double.random(in: 0...1)
        let th = 2 * Double.pi * u
        let ph = acos(2 * v - 1)
        let rr = 0.80 + 0.20 * Double.random(in: 0...1)
        out.append(OrbParticle(
            x: sin(ph) * cos(th) * rr,
            y: cos(ph) * rr,
            z: sin(ph) * sin(th) * rr,
            size: 0.7 + 1.6 * Double.random(in: 0...1),
            alpha: 0.45 + 0.55 * Double.random(in: 0...1),
            twS: 0.8 + 1.3 * Double.random(in: 0...1),
            twPhase: Double.random(in: 0...(2 * Double.pi)),
            white: Double.random(in: 0...1) < 0.16
        ))
    }
    return out
}

// MARK: - Rotating particle sphere

private struct OrbCanvas: View {
    let particles: [OrbParticle]
    let start: Date
    let lastFeed: Date?
    let tint: Color
    let tintBright: Color

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let now = tl.date
                let t = now.timeIntervalSince(start)
                let intro = min(1, t / 1.4)
                // brightness/size pulse decays from the last metric feed
                let fb = lastFeed.map { max(0, exp(-3.2 * now.timeIntervalSince($0))) } ?? 0
                let flare = 0.9 * fb
                let pulse = 1.0 * fb

                let cx = size.width / 2, cy = size.height / 2
                let R = min(size.width, size.height) * 0.5 * 0.86
                let idle = 0.022 * sin(t * 0.85)
                let bx = 1 + 0.03 * sin(t * 0.55)
                let by = 1 - 0.03 * sin(t * 0.55)
                let reff = R * (1 + pulse * 0.07 + idle)
                let ay = t * 0.22, tilt = -0.32
                let cay = cos(ay), say = sin(ay), ctt = cos(tilt), stt = sin(tilt)

                ctx.blendMode = .plusLighter
                for p in particles {
                    let x = p.x * cay + p.z * say
                    let z = -p.x * say + p.z * cay
                    let y = p.y
                    let y2 = y * ctt - z * stt
                    let z2 = y * stt + z * ctt
                    let depth = (z2 + 1) / 2
                    let sx = cx + x * reff * bx
                    let sy = cy + y2 * reff * by
                    let tw = 0.55 + 0.45 * sin(t * p.twS + p.twPhase)
                    let sz = p.size * (0.55 + 1.20 * depth) * (1 + pulse * 0.5)
                    var a = p.alpha * tw * (0.34 + 0.85 * depth) * intro * (1 + flare * 1.1)
                    if a > 1 { a = 1 }
                    let rect = CGRect(x: sx - sz / 2, y: sy - sz / 2, width: sz, height: sz)
                    let col = p.white ? tintBright : tint
                    ctx.fill(Path(ellipseIn: rect), with: .color(col.opacity(a)))
                }

                ctx.blendMode = .normal
                let rw = reff * 1.02 * bx, rh = reff * 1.02 * by
                let rimRect = CGRect(x: cx - rw, y: cy - rh, width: 2 * rw, height: 2 * rh)
                ctx.stroke(Path(ellipseIn: rimRect),
                           with: .color(tintBright.opacity((0.28 + 0.4 * flare) * intro)),
                           lineWidth: 1.2 + pulse)
            }
        }
    }
}

// MARK: - Metric chip

private struct OnbV2Metric: Identifiable {
    let id: Int
    let name: String
    let valueLabel: String   // e.g. "6,840 Steps"
    let minLabel: String     // scale start, e.g. "0K"
    let maxLabel: String     // scale end, e.g. "12K"
    let markerP: Double      // 0..1 marker position on the bar
    let delta: Double        // years added (older) or removed (younger)
    var good: Bool { delta < 0 }
}

private struct OnbV2MetricChip: View {
    let metric: OnbV2Metric

    private var barGradient: LinearGradient {
        LinearGradient(stops: [
            .init(color: OnbV2.amber, location: 0),
            .init(color: OnbV2.amber, location: 0.42),
            .init(color: OnbV2.bg3, location: 0.42),
            .init(color: OnbV2.bg3, location: 0.58),
            .init(color: OnbV2.blue, location: 0.58),
            .init(color: OnbV2.blue, location: 1)
        ], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(metric.name)
                    .font(.system(size: 11, weight: .bold)).tracking(0.9)
                    .foregroundStyle(OnbV2.fg)
                    .lineLimit(1).minimumScaleFactor(0.7)

                // value label sitting above its marker
                GeometryReader { g in
                    let x = min(max(g.size.width * metric.markerP, 20), g.size.width - 20)
                    Text(metric.valueLabel)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(OnbV2.fg)
                        .fixedSize()
                        .position(x: x, y: 7)
                }
                .frame(height: 14)

                // scale bar with a downward value marker
                GeometryReader { g in
                    let x = min(max(g.size.width * metric.markerP, 5), g.size.width - 5)
                    ZStack(alignment: .leading) {
                        Capsule().fill(barGradient)
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                            .position(x: x, y: 0)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(metric.minLabel).foregroundStyle(OnbV2.amber)
                    Spacer()
                    Text(metric.maxLabel).foregroundStyle(OnbV2.blueLight)
                }
                .font(.system(size: 9.5, weight: .bold))
            }

            VStack(spacing: 0) {
                Text(String(format: "%+.1f", metric.delta))
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(metric.good ? OnbV2.blueLight : OnbV2.amber)
                Text(Copy.OnboardingV2.revealYearsUnit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OnbV2.fg3)
            }
            .fixedSize()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(width: 250)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.10).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10)))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
    }
}

// MARK: - The screen

struct OnbV2VitalityRevealScreen: View {
    // Branch-dependent progress position (7 rich, 11 sparse/denied), supplied
    // by the router which owns the branch order.
    let step: Int
    // Rich branch only: the CTA fires the system notification prompt, so a
    // priming line above it sets up the ask.
    let showsNotificationPrimer: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    // Real estimate, computed once from the onboarding snapshot.
    private let chronoAge: Int
    private let vitalityAge: Int
    private let metrics: [OnbV2Metric]
    private let feedOrder: [Int]
    private let realMetricCount: Int

    /// First concrete action, from the metric costing the most years. All
    /// deltas <= 0 means nothing is dragging the age up: maintain instead.
    private var nextStepText: String {
        guard let weakest = metrics.filter({ $0.delta > 0 }).max(by: { $0.delta < $1.delta }) else {
            return Copy.OnboardingV2.revealNextStepMaintain
        }
        return Copy.OnboardingV2.revealNextStep(forMetric: weakest.name)
    }

    init(profile: OnboardingV2Profile, snapshot: OnboardingHealthSnapshot,
         step: Int, showsNotificationPrimer: Bool,
         onBack: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.step = step
        self.showsNotificationPrimer = showsNotificationPrimer
        self.onBack = onBack
        self.onContinue = onContinue
        let est = VitalityScorer.onboardingEstimate(
            chronologicalAge: profile.age,
            restingHR: snapshot.restingHR.map(Double.init),
            hrvMs: snapshot.hrvWeeklyAvgMs,
            steps: snapshot.stepsDailyAvg,
            vo2Max: snapshot.vo2Max,
            exerciseMinutes: snapshot.exerciseDailyAvg,
            walkingSpeedKmh: snapshot.walkingSpeedKmh)
        self.chronoAge = profile.age
        self.vitalityAge = est.vitalityAge
        // the number uses every available metric; the cards show the 4 most impactful
        let top = est.metrics.sorted { abs($0.delta) > abs($1.delta) }.prefix(4)
        self.metrics = top.enumerated().map { idx, m in
            OnbV2Metric(id: idx, name: m.name, valueLabel: m.valueLabel,
                        minLabel: "", maxLabel: "", markerP: m.goodness, delta: Double(m.delta))
        }
        self.feedOrder = Array(self.metrics.indices)
        self.realMetricCount = est.metrics.count
        _consumed = State(initialValue: [Bool](repeating: false, count: self.metrics.count))
    }

    private var yearsDiff: Double { Double(chronoAge - vitalityAge) }   // positive = younger
    // younger → blue, a little older → amber, a lot older → red
    private var resultColor: Color {
        if yearsDiff >= 0 { return OnbV2.blueLight }
        else if yearsDiff >= -3 { return OnbV2.amber }
        else { return OnbV2.rose }
    }
    private var payoffText: String {
        let n = Int(abs(yearsDiff).rounded())
        if n == 0 { return Copy.OnboardingV2.revealPayoffOnAge }
        return yearsDiff > 0 ? Copy.OnboardingV2.revealPayoffYounger(n) : Copy.OnboardingV2.revealPayoffOlder(n)
    }
    // the whole orb (particles, glow, rim, number) takes the verdict colour
    private var orbTint: Color {
        if yearsDiff >= 0 { return OnbV2.blue }
        else if yearsDiff >= -3 { return OnbV2.amber }
        else { return OnbV2.rose }
    }
    private var orbTintBright: Color {
        yearsDiff >= 0 ? OnbV2.blueLight : resultColor
    }
    private var ctaCaption: String {
        yearsDiff > 0 ? Copy.OnboardingV2.revealSubYounger : Copy.OnboardingV2.revealSubOlder
    }

    @State private var particles = makeOrbParticles()
    @State private var start = Date()
    @State private var age = 0.0
    @State private var label = Copy.OnboardingV2.revealOrbYourAge
    @State private var consumed: [Bool]
    @State private var appeared = false
    @State private var done = false
    @State private var lastFeed: Date?
    @State private var rippleScale: CGFloat = 0.55
    @State private var rippleOpacity = 0.0
    @State private var rippleColor = OnbV2.blue

    var body: some View {
        OnbV2ScreenContainer(ambient: .none, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: step, total: OnbV2Flow.total, onBack: onBack, tint: orbTint)
                Text(Copy.OnboardingV2.revealHeader)
                    .font(.system(size: 12, weight: .bold)).tracking(2.2)
                    .foregroundStyle(orbTintBright)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let center = CGPoint(x: w / 2, y: h * 0.40)
                    ZStack {
                        // blue bloom behind the orb so it glows even at rest
                        Circle()
                            .fill(RadialGradient(
                                gradient: Gradient(colors: [orbTint.opacity(0.45), orbTint.opacity(0)]),
                                center: .center, startRadius: 0, endRadius: 170))
                            .frame(width: 360, height: 360)
                            .blur(radius: 36)
                            .position(center)
                            .opacity(appeared ? 1 : 0)
                            .animation(.easeOut(duration: 1.0), value: appeared)

                        OrbCanvas(particles: particles, start: start, lastFeed: lastFeed,
                                  tint: orbTint, tintBright: orbTintBright)
                            .frame(width: 236, height: 236)
                            .position(center)

                        Circle().stroke(rippleColor, lineWidth: 1.5)
                            .frame(width: 180, height: 180)
                            .scaleEffect(rippleScale)
                            .opacity(rippleOpacity)
                            .position(center)

                        VStack(spacing: 8) {
                            Text(String(format: "%.1f", age))
                                .font(.system(size: 64, weight: .heavy).monospacedDigit())
                                .foregroundStyle(.white)
                                .shadow(color: orbTint.opacity(0.5), radius: 18)
                            Text(label)
                                .font(.system(size: 12, weight: .bold)).tracking(3.2)
                                .foregroundStyle(OnbV2.fg2)
                                .opacity(appeared ? 1 : 0)
                        }
                        .position(center)

                        ForEach(metrics) { m in
                            OnbV2MetricChip(metric: m)
                                .scaleEffect(consumed[m.id] ? 0.12 : 1)
                                .opacity(consumed[m.id] ? 0 : 1)
                                .position(consumed[m.id] ? center
                                          : (appeared ? chipPos(m.id, geo.size) : chipStart(m.id, geo.size)))
                                .animation(.timingCurve(0.5, 0, 0.25, 1, duration: 0.8), value: consumed[m.id])
                                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62).delay(0.4 + Double(m.id) * 0.13), value: appeared)
                        }

                        VStack(spacing: 7) {
                            Text(payoffText)
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(resultColor)
                            Text(Copy.OnboardingV2.revealThanRealAge(chronoAge))
                                .font(.system(size: 13))
                                .foregroundStyle(OnbV2.fg3)

                            // The pathway starts here: hand over the first
                            // concrete step, picked from the weakest metric,
                            // before sign-in and before the paywall.
                            VStack(alignment: .leading, spacing: 5) {
                                Text(Copy.OnboardingV2.revealNextStepHeader)
                                    .font(.system(size: 10, weight: .bold)).tracking(1.4)
                                    .foregroundStyle(OnbV2.blueLight)
                                Text(nextStepText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OnbV2.fg)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(OnbV2.blue.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OnbV2.blue.opacity(0.35)))
                            .padding(.top, 8)
                            .padding(.horizontal, OnbV2.bodyPadH)
                        }
                        .frame(width: w)
                        .position(x: w / 2, y: h * 0.62)
                        .opacity(done ? 1 : 0)
                        .offset(y: done ? 0 : 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: done)

                        VStack(spacing: 11) {
                            if showsNotificationPrimer {
                                Text(Copy.OnboardingV2.notifPrimer)
                                    .font(.system(size: 12))
                                    .foregroundStyle(OnbV2.fg2)
                                    .multilineTextAlignment(.center)
                            }
                            OnbV2PrimaryCTA(Copy.OnboardingV2.revealCTA, tint: orbTint) { onContinue() }
                            Text(ctaCaption)
                                .font(.system(size: 11))
                                .foregroundStyle(OnbV2.fg3)
                        }
                        .padding(.horizontal, OnbV2.bodyPadH)
                        .frame(width: w)
                        // The block is centre-positioned, so give the primer's
                        // extra height back half above the anchor to keep the
                        // bottom caption clear of the home indicator.
                        .position(x: w / 2, y: h - (showsNotificationPrimer ? 70 : 56))
                        .opacity(done ? 1 : 0)
                        .allowsHitTesting(done)   // invisible-but-tappable would let a stray tap skip the reveal
                        .animation(.easeOut(duration: 0.5), value: done)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    RadialGradient(colors: [orbTint.opacity(0.22), Color.clear],
                                   center: .topLeading, startRadius: 0, endRadius: 360)
                    RadialGradient(colors: [orbTint.opacity(0.12), Color.clear],
                                   center: .bottomTrailing, startRadius: 0, endRadius: 320)
                }
                // Bleed the glow past the safe area so it fills behind the status
                // bar and home indicator, matching every other onboarding screen
                // (whose ambient is drawn by the container with ignoresSafeArea).
                .ignoresSafeArea()
            )
        }
        .task { await runSequence() }
    }

    // Varied, non-aligned resting spots (each a different x AND y) so the chips
    // float around the orb instead of sitting in a rigid grid.
    private func chipPos(_ i: Int, _ s: CGSize) -> CGPoint {
        switch i {
        // ordered so the first two cards flank the orb diagonally (balanced when
        // only 2 metrics exist), the next two fill the other corners
        case 0:  return CGPoint(x: s.width * 0.37, y: s.height * 0.13)   // top-left
        case 1:  return CGPoint(x: s.width * 0.63, y: s.height * 0.86)   // bottom-right
        case 2:  return CGPoint(x: s.width * 0.63, y: s.height * 0.28)   // upper-right
        default: return CGPoint(x: s.width * 0.37, y: s.height * 0.71)   // lower-left
        }
    }

    // Each chip starts off-screen on its own side and slides inward, so they
    // arrive from different places rather than appearing in formation.
    private func chipStart(_ i: Int, _ s: CGSize) -> CGPoint {
        let c = CGPoint(x: s.width / 2, y: s.height * 0.40)
        let p = chipPos(i, s)
        return CGPoint(x: c.x + (p.x - c.x) * 2.5, y: c.y + (p.y - c.y) * 2.5)
    }

    @MainActor
    private func tweenAge(from: Double, to: Double, duration: Double) async {
        let steps = max(1, Int(duration / 0.016))
        for i in 0...steps {
            let p = Double(i) / Double(steps)
            let e = 1 - pow(1 - p, 3)
            age = from + (to - from) * e
            try? await Task.sleep(for: .milliseconds(16))
        }
        age = to
    }

    @MainActor
    private func runSequence() async {
        withAnimation(OnbV2.entryEase) { appeared = true }
        try? await Task.sleep(for: .milliseconds(450))
        await tweenAge(from: 0, to: Double(chronoAge), duration: 1.0)
        try? await Task.sleep(for: .milliseconds(450))

        let n = feedOrder.count
        if n > 0 {
            // the chips are framed around the orb; hold so the user can read them
            try? await Task.sleep(for: .milliseconds(1700))
            label = Copy.OnboardingV2.revealOrbCalculating
            for (step, idx) in feedOrder.enumerated() {
                let d = metrics[idx].delta
                lastFeed = Date()
                rippleColor = d < 0 ? OnbV2.blueLight : OnbV2.amber
                rippleScale = 0.55
                rippleOpacity = 0.7
                withAnimation(.easeOut(duration: 0.85)) { rippleScale = 1.7; rippleOpacity = 0 }
                withAnimation(.timingCurve(0.5, 0, 0.25, 1, duration: 0.8)) { consumed[idx] = true }
                // walk the number from the real age toward the computed vitality age
                let target = Double(chronoAge) + Double(vitalityAge - chronoAge) * Double(step + 1) / Double(n)
                await tweenAge(from: age, to: target, duration: 0.6)
                // clear pause between each metric so the user sees them go in one by one
                try? await Task.sleep(for: .milliseconds(550))
            }
        }
        await tweenAge(from: age, to: Double(vitalityAge), duration: 0.3)
        label = Copy.OnboardingV2.revealOrbYears
        // let the final number land alone for a beat before the verdict appears
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { done = true }
        AppAnalytics.shared.trackOnboardingVitalityRevealed(
            vitalityAge: vitalityAge, realAge: chronoAge,
            metricCount: realMetricCount, hasHealthData: realMetricCount > 0)
    }
}
