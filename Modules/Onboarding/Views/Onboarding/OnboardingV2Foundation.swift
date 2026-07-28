import SwiftUI

// MARK: - Profile state

enum OnbV2Sex: String, CaseIterable, Codable {
    case female, male, other
    var label: String {
        switch self {
        case .female: return "Female"
        case .male:   return "Male"
        case .other:  return "Other"
        }
    }

    var asGender: Gender {
        switch self {
        case .female: return .female
        case .male:   return .male
        case .other:  return .other
        }
    }
}

enum OnbV2Goal: String, CaseIterable, Codable {
    case sleep, energy, training, stress, longevity, weight

    /// Maps a V2 onboarding goal to the legacy HealthFocus enum so existing
    /// dashboard filtering (DashboardViewModel.updateCachedProperties uses
    /// HealthFocus.categories) automatically respects V2 selections.
    var asHealthFocus: HealthFocus {
        switch self {
        case .sleep:     return .sleep
        case .energy:    return .recovery
        case .training:  return .fitness
        case .stress:    return .recovery
        case .longevity: return .heartHealth
        case .weight:    return .weightBody
        }
    }
}

enum OnbV2Symptom: String, CaseIterable, Codable {
    case tiredMorning, restless, foggy, anxious, lowMotivation, sore, moody, none
}

@Observable
final class OnboardingV2Profile {
    var age: Int = 26
    var sex: OnbV2Sex?
    /// Multi-select. Order preserved so the first picked goal drives the
    /// goal-conditional bridge copy and downstream personalisation.
    var goals: [OnbV2Goal] = []
    var symptoms: Set<OnbV2Symptom> = []

    var primaryGoal: OnbV2Goal? { goals.first }

    func toggleGoal(_ g: OnbV2Goal) {
        if let idx = goals.firstIndex(of: g) {
            goals.remove(at: idx)
        } else {
            goals.append(g)
        }
    }

    func toggleSymptom(_ s: OnbV2Symptom) {
        if s == .none {
            if symptoms.contains(.none) {
                symptoms.remove(.none)
            } else {
                symptoms = [.none]
            }
            return
        }
        symptoms.remove(.none)
        if symptoms.contains(s) {
            symptoms.remove(s)
        } else {
            symptoms.insert(s)
        }
    }
}

// MARK: - Flow constants

/// Single source of truth for the progress-bar denominator. The three router
/// screens (verdict / cliffhanger / journalFirst) are mutually exclusive and
/// hide their progress bar, so they count as the one linear step they replace.
/// Linear steps: welcome, about, goal, symptoms, bridge, scan, [reveal on the
/// rich branch, router screen otherwise], heart, sleep, hrv, [verdict on the
/// rich branch, reveal otherwise], signIn, paywall.
enum OnbV2Flow {
    static let total = 13
}

// MARK: - V2 design tokens

enum OnbV2 {

    // Colors. Aliases onto AppColour so the whole V2 flow follows the theme.
    static let bg       = AppColour.surfaceBase
    static let bg2      = AppColour.surfaceRaised
    static let bg3      = AppColour.surfaceElevated
    static let line     = AppColour.borderLow
    static let fg       = AppColour.textPrimary
    static let fg2      = AppColour.textSecondary
    static let fg3      = AppColour.textTertiary
    static let fg4      = AppColour.textQuaternary

    static let blue     = AppColour.primary
    static let blueGlow = AppColour.glowTint
    static let blueLight = AppColour.accent
    static let rose     = AppColour.danger
    static let green    = AppColour.success
    /// Computed, not stored: categorySleep reads Remote Config on every access, so a
    /// `let` would freeze whichever value happened to be live at first use.
    static var purple: Color { AppColour.categorySleep }
    static let amber    = AppColour.warning
    static let teal     = AppColour.vitalityDeltaNegative

    // Radii
    static let rMd: CGFloat   = 16

    // Spacing
    static let bodyPadH: CGFloat = 24

    // Animation
    static let entryEase = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)
    static func staggeredEntry(_ delaySec: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.7).delay(delaySec)
    }
}

// MARK: - Screen container with ambient gradient + fade-up

enum OnbV2Ambient {
    // blueHero is a brighter, on-screen bloom used only by the welcome screen so
    // the orb sits in a visible glow; plain blue keeps the faint off-screen tail
    // every other screen uses.
    case blue, blueHero, greenHero, roseHero, blueDual, paywallBlue, purpleDual, tealDual, rose, mix, none
}

struct OnbV2ScreenContainer<Content: View>: View {
    let ambient: OnbV2Ambient
    /// When true the screen runs its own per-element reveal (P1 stagger / P2
    /// clock), so the container skips its block fade to avoid double-animating.
    /// Default false keeps every existing screen byte-for-byte unchanged.
    var staggerOwnsEntry: Bool = false
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        ZStack {
            OnbV2.bg.ignoresSafeArea()
            ambientGradient.ignoresSafeArea().allowsHitTesting(false)
            if staggerOwnsEntry {
                content()
            } else {
                content()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                    .animation(OnbV2.entryEase, value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    @ViewBuilder
    private var ambientGradient: some View {
        switch ambient {
        case .blue:
            ZStack {
                radial(OnbV2.blue.opacity(0.18), x: -0.30, y: -0.20, r: 280)
                radial(OnbV2.blueLight.opacity(0.10), x: 1.20, y: 0.10, r: 220)
            }
        case .blueHero:
            // Match the welcome mockup exactly: a visible blue bloom from the
            // top-left and a faint cool wash lower-right. The orb supplies its own
            // centre glow through its shadows, so the background is just ambient.
            ZStack {
                radial(OnbV2.blue.opacity(0.22), x: 0.16, y: 0.10, r: 340)
                radial(OnbV2.blueLight.opacity(0.10), x: 0.92, y: 0.80, r: 300)
            }
        case .greenHero:
            // Green blooms in both corners (upper-left and lower-right), for the
            // About screen.
            ZStack {
                radial(OnbV2.green.opacity(0.20), x: 0.16, y: 0.10, r: 260)
                radial(OnbV2.green.opacity(0.24), x: 0.92, y: 0.90, r: 280)
            }
        case .roseHero:
            // Rose blooms in both corners (upper-left and lower-right), for the
            // Symptoms screen.
            ZStack {
                radial(OnbV2.rose.opacity(0.20), x: 0.16, y: 0.10, r: 260)
                radial(OnbV2.rose.opacity(0.24), x: 0.92, y: 0.90, r: 280)
            }
        case .blueDual:
            // Subtle blue blooms in both corners (top-left and bottom-right),
            // kept light so the verdict chart stays the focus.
            ZStack {
                radial(OnbV2.blue.opacity(0.28), x: 0.14, y: 0.10, r: 280)
                radial(OnbV2.blue.opacity(0.16), x: 0.88, y: 0.94, r: 300)
            }
        case .paywallBlue:
            // Paywall only: same top-left blue as blueDual, but a stronger
            // bottom-right bloom sitting slightly above the bottom edge so it
            // reads as a glow rising from the lower-right, not hugging the floor.
            ZStack {
                radial(OnbV2.blue.opacity(0.28), x: 0.14, y: 0.10, r: 280)
                radial(OnbV2.blue.opacity(0.22), x: 0.90, y: 0.86, r: 320)
            }
        case .purpleDual:
            // Purple blooms in both corners, for the Sleep reveal.
            ZStack {
                radial(OnbV2.purple.opacity(0.18), x: 0.14, y: 0.10, r: 240)
                radial(OnbV2.purple.opacity(0.18), x: 0.90, y: 0.92, r: 260)
            }
        case .tealDual:
            // Teal blooms in both corners, for the HRV reveal.
            ZStack {
                radial(OnbV2.teal.opacity(0.16), x: 0.14, y: 0.10, r: 240)
                radial(OnbV2.teal.opacity(0.16), x: 0.90, y: 0.92, r: 260)
            }
        case .rose:
            ZStack {
                radial(OnbV2.rose.opacity(0.16), x: -0.10, y: 0.12, r: 280)
                radial(OnbV2.purple.opacity(0.10), x: 1.10, y: 1.10, r: 220)
            }
        case .mix:
            ZStack {
                radial(OnbV2.blue.opacity(0.15), x: -0.20, y: 0.10, r: 260)
                radial(OnbV2.rose.opacity(0.13), x: 1.15, y: 1.10, r: 240)
            }
        case .none:
            EmptyView()
        }
    }

    private func radial(_ color: Color, x: CGFloat, y: CGFloat, r: CGFloat) -> some View {
        GeometryReader { geo in
            let cx = geo.size.width * x
            let cy = geo.size.height * y
            RadialGradient(
                colors: [color, .clear],
                center: UnitPoint(x: x, y: y),
                startRadius: 0, endRadius: r
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .opacity(0.999)
            .blur(radius: 30)
            .allowsHitTesting(false)
            // (cx, cy) referenced via UnitPoint above; keep var bound to silence unused warning
            .onAppear { _ = (cx, cy) }
        }
    }
}

// MARK: - Top bar

struct OnbV2TopBar: View {
    let step: Int            // 1-indexed
    let total: Int
    let onBack: (() -> Void)?
    var hideProgress: Bool = false
    var tint: Color = OnbV2.blue

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnbV2.fg2)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColour.surfaceRaised))
                        .overlay(Circle().stroke(OnbV2.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            if !hideProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColour.trackNeutral)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [tint.opacity(0.75), tint],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: max(0, geo.size.width * progress))
                            .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6), value: progress)
                    }
                }
                .frame(height: 4)

                Text(Copy.Onboarding.progressStepText(step, total))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(OnbV2.fg3)
            }
        }
        .padding(.horizontal, OnbV2.bodyPadH)
        .padding(.top, 8)
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(step) / CGFloat(total)
    }
}

// MARK: - Primary CTA

struct OnbV2PrimaryCTA: View {
    let title: String
    let isEnabled: Bool
    let tint: Color
    let action: () -> Void
    @State private var pressed = false

    init(_ title: String, isEnabled: Bool = true, tint: Color = OnbV2.blue, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? AppColour.textOnAccent : OnbV2.fg3)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                        .fill(isEnabled ? tint : AppColour.surfaceRaised)
                )
                .scaleEffect(pressed ? 0.985 : 1)
                .opacity(pressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

struct OnbV2GhostCTA: View {
    let title: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnbV2.fg2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .scaleEffect(pressed && !reduceMotion ? 0.985 : 1)
                .opacity(pressed ? 0.9 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
    }
}

// MARK: - Select row (single-select goal/activity/wearable)

struct OnbV2SelectRow: View {
    let icon: String          // SF Symbol name
    let title: String
    let subtitle: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: title,
                type: .onboardingFocusChip,
                screen: .onboarding
            )
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(isSelected ? 0.22 : 0.14))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnbV2.fg)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(OnbV2.fg3)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle().stroke(isSelected ? accent : OnbV2.fg4, lineWidth: 1.5)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.10) : OnbV2.bg2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                    .stroke(isSelected ? accent : OnbV2.line, lineWidth: 1)
            )
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Pill chip (multi-select symptoms)

struct OnbV2Chip: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: .onboardingFocusChip,
                screen: .onboarding
            )
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? OnbV2.blue : OnbV2.fg)
            .background(
                Capsule().fill(isSelected ? OnbV2.blue.opacity(0.12) : OnbV2.bg2)
            )
            .overlay(
                Capsule().stroke(isSelected ? OnbV2.blue : OnbV2.line, lineWidth: 1)
            )
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        .animation(.easeOut(duration: 0.16), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Heart hero (pulsing rings + center heart)

struct OnbV2HeartHero: View {
    var size: CGFloat = 220
    var color: Color = OnbV2.blue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = false

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                PulseRing(delay: Double(i) * 0.6, color: color, reduceMotion: reduceMotion)
                    .frame(width: size * 0.85, height: size * 0.85)
            }

            Circle()
                // Bright glossy hotspot off-center, fading to the base colour, so
                // the disc reads as a lit orb instead of a flat fill. Stays white in
                // both modes: it is a specular highlight on a saturated fill, so it
                // must not flip dark the way textOnAccent does.
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.6), color],
                    center: UnitPoint(x: 0.36, y: 0.30),
                    startRadius: 0, endRadius: size * 0.26
                ))
                .frame(width: size * 0.4, height: size * 0.4)
                // Two layers like the mockup: a soft even halo, plus a grounded
                // downward glow. glowTint emits light on dark and degrades to a
                // neutral ambient lift on light, where a coloured bloom smears.
                .shadow(color: AppColour.glowTint, radius: size * 0.12, x: 0, y: 0)
                .shadow(color: AppColour.glowTint, radius: size * 0.08, x: 0, y: size * 0.05)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(AppColour.textOnAccent)
                )
                .scaleEffect(beat ? 1.18 : 1.0)
                .animation(
                    .timingCurve(0.4, 0, 0.6, 1, duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: beat
                )
        }
        .frame(width: size, height: size)
        // Reduce Motion: hold the heart still; PulseRing renders its static rest state.
        .onAppear { beat = reduceMotion ? false : true }
    }

    private struct PulseRing: View {
        let delay: Double
        let color: Color
        let reduceMotion: Bool
        @State private var animate = false

        var body: some View {
            Circle()
                .stroke(color.opacity(animate ? 0 : 0.7), lineWidth: 1.5)
                .scaleEffect(animate ? 2.0 : 0.85)
                .animation(
                    .easeOut(duration: 3.6).repeatForever(autoreverses: false).delay(delay),
                    value: animate
                )
                .onAppear { if !reduceMotion { animate = true } }
        }
    }
}

// MARK: - CountUp (animated number)

struct OnbV2CountUp: View {
    let target: Double
    var duration: Double = 1.6
    var delay: Double = 0
    var decimals: Int = 0
    var font: Font = .system(size: 88, weight: .bold).monospacedDigit()
    var color: Color = OnbV2.fg

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current: Double = 0
    @State private var started = false

    var body: some View {
        Text(format(current))
            .font(font)
            .foregroundStyle(color)
            .onAppear {
                guard !started else { return }
                started = true
                // Reduce Motion: land on the final value instantly, no tick loop.
                if reduceMotion {
                    current = target
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let start = Date()
                    let timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { t in
                        let elapsed = Date().timeIntervalSince(start)
                        let p = min(1, elapsed / duration)
                        // ease-out cubic
                        let eased = 1 - pow(1 - p, 3)
                        current = target * eased
                        if p >= 1 { current = target; t.invalidate() }
                    }
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
    }

    private func format(_ v: Double) -> String {
        if decimals == 0 {
            return "\(Int(v.rounded()))"
        }
        return String(format: "%.\(decimals)f", v)
    }
}

// MARK: - Watch list row (screen 16)

struct OnbV2WatchRow: View {
    let icon: String
    let color: Color
    let label: String
    let sub: String
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showDivider {
                Rectangle().fill(OnbV2.line).frame(height: 1)
            }
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(OnbV2.fg)
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OnbV2.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Plan card (screen 16, real StoreKit prices)

struct OnbV2PlanCard: View {
    let title: String
    let priceText: String      // from Product.displayPrice + period suffix
    let sublabel: String
    let badge: String?         // e.g. "Save 58%" computed at runtime
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? OnbV2.blue : OnbV2.fg4, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(OnbV2.blue).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnbV2.fg)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 13, weight: .bold))
                                .tracking(0.4)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(OnbV2.green.opacity(0.18)))
                                .foregroundStyle(OnbV2.green)
                        }
                    }
                    Text(sublabel)
                        .font(.system(size: 12.5))
                        .foregroundStyle(OnbV2.fg3)
                }

                Spacer(minLength: 8)

                Text(priceText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnbV2.fg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                    .fill(isSelected ? OnbV2.blue.opacity(0.10) : OnbV2.bg2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                    .stroke(isSelected ? OnbV2.blue : OnbV2.line, lineWidth: 1.5)
            )
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
