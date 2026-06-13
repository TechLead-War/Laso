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

enum OnbV2Activity: String, CaseIterable, Codable {
    case low, mod, high, elite
}

enum OnbV2Wearable: String, CaseIterable, Codable {
    case apple, whoop, oura, garmin, fitbit, other, none
}

@Observable
final class OnboardingV2Profile {
    var age: Int = 26
    var sex: OnbV2Sex?
    /// Multi-select. Order preserved so the first picked goal drives the
    /// goal-conditional bridge copy and downstream personalisation.
    var goals: [OnbV2Goal] = []
    var symptoms: Set<OnbV2Symptom> = []
    var activity: OnbV2Activity?
    var wearable: OnbV2Wearable?

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
/// Linear steps: welcome, promise, about, goal, symptoms, prediction, activity,
/// wearable, bridge, scan, [router], heart, sleep, hrv, preview, signIn, paywall.
enum OnbV2Flow {
    static let total = 17
}

// MARK: - V2 design tokens

enum OnbV2 {

    // Colors (hex from design handoff)
    static let bg       = Color(red: 0,    green: 0,    blue: 0)
    static let bg1      = Color(red: 0.039, green: 0.039, blue: 0.047)
    static let bg2      = Color(red: 0.075, green: 0.075, blue: 0.090)
    static let bg3      = Color(red: 0.110, green: 0.110, blue: 0.133)
    static let line     = Color.white.opacity(0.08)
    static let line2    = Color.white.opacity(0.14)
    static let fg       = Color.white
    static let fg2      = Color.white.opacity(0.72)
    static let fg3      = Color.white.opacity(0.48)
    static let fg4      = Color.white.opacity(0.28)

    static let blue     = Color(red: 0.039, green: 0.518, blue: 1.0)    // #0A84FF
    static let blueGlow = Color(red: 0.039, green: 0.518, blue: 1.0).opacity(0.55)
    static let blueLight = Color(red: 0.353, green: 0.784, blue: 0.98)  // #5AC8FA
    static let rose     = Color(red: 1.0,   green: 0.357, blue: 0.420)  // #FF5B6B
    static let green    = Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
    static let purple   = Color(red: 0.749, green: 0.353, blue: 0.949)  // #BF5AF2
    static let amber    = Color(red: 1.0,   green: 0.624, blue: 0.039)  // #FF9F0A
    static let teal     = Color(red: 0.361, green: 0.878, blue: 0.847)  // #5CE0D8

    // Radii
    static let rSm: CGFloat   = 10
    static let rMd: CGFloat   = 16
    static let rLg: CGFloat   = 22
    static let rPill: CGFloat = 999

    // Spacing
    static let bodyPadH: CGFloat = 24
    static let cardPad: CGFloat  = 16

    // Animation
    static let entryEase = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)
    static func staggeredEntry(_ delaySec: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.7).delay(delaySec)
    }
}

// MARK: - Screen container with ambient gradient + fade-up

enum OnbV2Ambient {
    case blue, rose, mix, none
}

struct OnbV2ScreenContainer<Content: View>: View {
    let ambient: OnbV2Ambient
    @ViewBuilder let content: () -> Content
    @State private var appeared = false

    var body: some View {
        ZStack {
            OnbV2.bg.ignoresSafeArea()
            ambientGradient.ignoresSafeArea().allowsHitTesting(false)
            content()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(OnbV2.entryEase, value: appeared)
        }
        .onAppear { appeared = true }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var ambientGradient: some View {
        switch ambient {
        case .blue:
            ZStack {
                radial(OnbV2.blue.opacity(0.18), x: -0.30, y: -0.20, r: 280)
                radial(OnbV2.blueLight.opacity(0.10), x: 1.20, y: 0.10, r: 220)
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

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnbV2.fg2)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .overlay(Circle().stroke(OnbV2.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            if !hideProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [OnbV2.blue, OnbV2.blueLight],
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
    let action: () -> Void
    @State private var pressed = false

    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.white : OnbV2.fg3)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                        .fill(isEnabled ? OnbV2.blue : Color.white.opacity(0.08))
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
        }
        .buttonStyle(.plain)
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

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Pill chip (multi-select symptoms)

struct OnbV2Chip: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

// MARK: - Heart hero (pulsing rings + center heart)

struct OnbV2HeartHero: View {
    var size: CGFloat = 220
    var color: Color = OnbV2.blue
    @State private var beat = false

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                PulseRing(delay: Double(i) * 0.6, color: color)
                    .frame(width: size * 0.85, height: size * 0.85)
            }

            Circle()
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size * 0.4, height: size * 0.4)
                .shadow(color: color.opacity(0.55), radius: 20, x: 0, y: 14)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(.white)
                )
                .scaleEffect(beat ? 1.18 : 1.0)
                .animation(
                    .timingCurve(0.4, 0, 0.6, 1, duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: beat
                )
        }
        .frame(width: size, height: size)
        .onAppear { beat = true }
    }

    private struct PulseRing: View {
        let delay: Double
        let color: Color
        @State private var animate = false

        var body: some View {
            Circle()
                .stroke(color.opacity(animate ? 0 : 0.7), lineWidth: 1.5)
                .scaleEffect(animate ? 2.0 : 0.85)
                .animation(
                    .easeOut(duration: 3.6).repeatForever(autoreverses: false).delay(delay),
                    value: animate
                )
                .onAppear { animate = true }
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

    @State private var current: Double = 0
    @State private var started = false

    var body: some View {
        Text(format(current))
            .font(font)
            .foregroundStyle(color)
            .onAppear {
                guard !started else { return }
                started = true
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

// MARK: - Promise card (screen 2)

struct OnbV2PromiseCard: View {
    let icon: String       // SF Symbol
    let title: String
    let bodyText: String
    var accent: Color = OnbV2.blue

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnbV2.fg)
                Text(bodyText)
                    .font(.system(size: 13.5))
                    .foregroundStyle(OnbV2.fg3)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnbV2.bg2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnbV2.line, lineWidth: 1)
        )
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
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.4)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
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
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}
