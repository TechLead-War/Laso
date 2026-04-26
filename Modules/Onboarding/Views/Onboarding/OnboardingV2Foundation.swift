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

                Text("\(step)/\(total)")
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

// MARK: - Copy

extension Copy {
    enum OnboardingV2 {
        // Screen 1 — Welcome
        static let s1Eyebrow = "LASO"
        static let s1Title   = "You deserve\nto feel understood."
        static let s1Lede    = "Not another health app shouting numbers at you. Laso listens to what your body has been quietly telling you for years, and helps you finally hear it."
        static let s1CTA     = "Begin"

        // Screen 2 — A few things, before we start
        static let s2Title = "A few things,\nbefore we start."
        static let s2Lede  = "What we promise you, in plain words."
        static let s2Card1Title = "No noise. No panic."
        static let s2Card1Body  = "We won't bury you in numbers. Just what matters, in words you'll actually use."
        static let s2Card2Title = "Yours, and only yours."
        static let s2Card2Body  = "Your health data stays on your phone. We never sell it. We never share it."
        static let s2Card3Title = "You're not alone in this."
        static let s2Card3Body  = "Whether you're tired, off, or hopeful, we meet you where you are."
        static let s2CTA     = "I'm ready"
        static let s2Caption = "Takes about 2 minutes"

        // Screen 3 — About you
        static let s3Title = "First, the basics."
        static let s3Lede  = "Heart, sleep, and recovery shift at every life stage. Yours are yours alone."
        static let s3AgeLabel = "How old are you?"
        static let s3SexLabel = "Sex assigned at birth"
        static let s3Microcopy = "We use this only to set healthy ranges for things like resting heart rate. Never shared."
        static let s3CTA = "Continue"

        // Screen 4 — What brought you here?
        static let s4Title = "What brought you here?"
        static let s4Lede  = "Pick anything that fits today. You can change it later."
        static let s4CTA   = "Continue"
        static let s4ZeroCount = "Pick one or a few"

        struct GoalCopy {
            let icon: String
            let title: String
            let subtitle: String
            let accent: Color
        }
        static let goalCopy: [OnbV2Goal: GoalCopy] = [
            .sleep:     .init(icon: "moon.fill",                 title: "Sleep better",            subtitle: "Wake up rested. Stop tossing.",      accent: OnbV2.purple),
            .energy:    .init(icon: "bolt.fill",                 title: "More steady energy",      subtitle: "Even out the highs and crashes.",    accent: OnbV2.amber),
            .training:  .init(icon: "figure.run",                title: "Train smarter",           subtitle: "Push hard, recover faster.",         accent: OnbV2.green),
            .stress:    .init(icon: "brain.head.profile",        title: "Manage stress",           subtitle: "Notice it before it builds.",        accent: OnbV2.teal),
            .longevity: .init(icon: "heart",                     title: "Stay healthy long-term",  subtitle: "Spot small changes before they grow.", accent: OnbV2.rose),
            .weight:    .init(icon: "scalemass.fill",            title: "Move toward a weight goal", subtitle: "Without obsessing over it.",        accent: OnbV2.blue)
        ]

        // Screen 5 — Symptoms (multi)
        static let s5Title = "What's been bugging you?"
        static let s5Lede1 = "Pick "
        static let s5LedeBold = "any that ring true"
        static let s5Lede2 = ", you can choose more than one. We'll watch for them."
        static let s5CTA   = "Continue"
        static let s5ZeroCount = "Pick any. Or none."

        struct SymptomCopy {
            let icon: String
            let label: String
        }
        static let symptomCopy: [OnbV2Symptom: SymptomCopy] = [
            .tiredMorning:  .init(icon: "battery.25",               label: "Tired mornings"),
            .restless:      .init(icon: "moon.zzz",                 label: "Restless nights"),
            .foggy:         .init(icon: "cloud.fog",                label: "Foggy thinking"),
            .anxious:       .init(icon: "waveform.path",            label: "Anxious or wired"),
            .lowMotivation: .init(icon: "cloud",                    label: "Low motivation"),
            .sore:          .init(icon: "figure.run",               label: "Slow recovery"),
            .moody:         .init(icon: "drop",                     label: "Mood swings"),
            .none:          .init(icon: "sparkles",                 label: "Nothing major. Just curious.")
        ]

        // Screen 6 — Activity
        static let s6Title = "How active are you, usually?"
        static let s6Lede  = "Helps us read your recovery in context."
        static let s6CTA   = "Continue"

        struct ActivityCopy {
            let icon: String
            let title: String
            let subtitle: String
        }
        static let activityCopy: [OnbV2Activity: ActivityCopy] = [
            .low:   .init(icon: "figure.walk",  title: "Mostly desk-bound",   subtitle: "A walk here and there."),
            .mod:   .init(icon: "figure.walk",  title: "On my feet",          subtitle: "Walks, light workouts most weeks."),
            .high:  .init(icon: "figure.run",   title: "Train regularly",     subtitle: "3 to 5 sessions a week."),
            .elite: .init(icon: "figure.run",   title: "Athlete",             subtitle: "Daily, structured training.")
        ]

        // Screen 7 — Wearable
        static let s7Title = "Do you wear anything?"
        static let s7Lede  = "We don't connect to your watch directly. We read whatever it shares with Apple Health. Most modern wearables do."
        static let s7CTA   = "Continue"

        struct WearableCopy {
            let icon: String
            let title: String
            let subtitle: String
        }
        static let wearableCopy: [OnbV2Wearable: WearableCopy] = [
            .apple:  .init(icon: "applewatch",            title: "Apple Watch",          subtitle: "Best fit. Deepest signal."),
            .whoop:  .init(icon: "heart",                 title: "Whoop",                subtitle: "Strain, sleep, recovery."),
            .oura:   .init(icon: "circle",                title: "Oura Ring",            subtitle: "Sleep, HRV, body temp."),
            .garmin: .init(icon: "applewatch",            title: "Garmin / Polar",       subtitle: "Training-focused devices."),
            .fitbit: .init(icon: "applewatch",            title: "Fitbit",               subtitle: "Steps, sleep, heart rate."),
            .other:  .init(icon: "sparkles",              title: "Something else",       subtitle: "If it syncs to Apple Health, we'll read it."),
            .none:   .init(icon: "iphone",                title: "Just my iPhone for now", subtitle: "That's plenty to start.")
        ]

        // Screen 8 — Bridge
        static let s8Title = "Now Laso can read\nyour story."
        static let s8DefaultLede = "We'll learn the rhythms only you have."
        static let s8PrivacyChip = "Your data never leaves your phone."
        static let s8CTA = "Connect Apple Health"

        static func bridgeLede(for goal: OnbV2Goal?) -> String {
            switch goal {
            case .sleep:     return "We'll learn how your nights shape your days."
            case .energy:    return "We'll find where your energy goes."
            case .training:  return "We'll see how you push and how you recover."
            case .stress:    return "We'll catch the strain before you feel it."
            case .longevity: return "We'll track the small shifts that add up."
            case .weight:    return "We'll connect what's beyond the scale."
            case .none:      return s8DefaultLede
            }
        }

        // Screen 10 — Scan
        static let s10Eyebrow = "READING"
        static let s10Title   = "Laso is listening to your body."
        static let s10Found1  = "Heart rate"
        static let s10Found2  = "Sleep cycles"
        static let s10Found3  = "Workouts"
        static let s10Found4  = "HRV"
        static let s10Found5  = "Recovery patterns"
        // Honest empty-state value when no samples were found in Apple Health.
        static let s10NotRecorded = "Not recorded"
        static func s10Status(_ pct: Int, longestDuration: String?) -> String {
            if let longestDuration {
                return "Reading \(longestDuration) of history · \(pct)%"
            }
            return "Reading from Apple Health · \(pct)%"
        }

        // Screen 11 — Heart reveal
        static let s11Eyebrow  = "HEART"
        static let s11TitleHasData    = "Your heart beats steadily."
        static let s11TitleEmpty      = "We'll learn your heart's rhythm."
        static let s11BodyHasData     = "We'll watch for changes. They often mean something."
        static let s11BodyEmpty       = "No resting heart rate recorded yet. Wear your Apple Watch and we'll start tracking from your next quiet moment."
        static let s11Unit     = "BPM"
        static let s11CTA      = "Tell me more"
        static func s11Footnote(months: Int) -> String {
            if months >= 12 {
                let years = months / 12
                let rem = months % 12
                if rem == 0 { return "Based on \(years) year\(years == 1 ? "" : "s") of resting heart rate data" }
                return "Based on \(years)y \(rem)mo of resting heart rate data"
            }
            return "Based on \(months) month\(months == 1 ? "" : "s") of resting heart rate data"
        }

        // Screen 12 — Sleep reveal
        static let s12Eyebrow  = "SLEEP"
        static let s12TitleHasData = "Your body is asking for more."
        static let s12TitleEmpty   = "We'll learn how you sleep."
        static let s12BodyPrefix   = "You've been averaging "
        static let s12BodySuffix   = ". Most adults need 7 to 8. We'll watch the gap and help you close it."
        static let s12BodyEmpty    = "No sleep data recorded yet. Wear your Apple Watch to bed and we'll learn your nightly rhythm."
        static let s12CTA          = "What else?"
        static func s12Footnote(months: Int) -> String {
            if months >= 12 {
                let years = months / 12
                let rem = months % 12
                if rem == 0 { return "\(years) year\(years == 1 ? "" : "s") of nightly data" }
                return "\(years)y \(rem)mo of nightly data"
            }
            return "\(months) month\(months == 1 ? "" : "s") of nightly data"
        }

        // Screen 13 — HRV reveal
        static let s13EyebrowPattern = "A PATTERN WE NOTICED"
        static let s13EyebrowEmpty   = "STILL LEARNING"
        static let s13TitleEmpty     = "Your patterns are still emerging."
        static let s13BodyBold       = "Most people miss it."
        static let s13BodySuffix     = " We won't."
        static let s13BodyEmpty      = "Not enough HRV data yet to spot a clear weekly pattern. Keep wearing your watch overnight and we'll surface yours within a couple of weeks."
        static let s13CTA            = "Show me the rest"
        static func s13Title(weekday: String) -> String {
            "\(weekday)s land harder than the rest."
        }
        static func s13BodyPrefix(weekday: String) -> String {
            "Your HRV dips most \(weekday) nights, a quiet sign of stress catching up. "
        }
        static func s13Footnote(weeks: Int) -> String {
            "Pattern detected across \(weeks) week\(weeks == 1 ? "" : "s")"
        }

        // Screen 14 — Preview
        static let s14Eyebrow = "YOUR FIRST WEEK"
        static let s14Title   = "Here's what comes next."
        static let s14Lede    = "A gentle plan for your first 7 days with Laso."
        static let s14CTA     = "Continue"

        struct PreviewDay {
            let day: Int
            let title: String
            let body: String
        }
        static let previewDays: [PreviewDay] = [
            .init(day: 1, title: "Your baseline",         body: "We set what 'normal' looks like for you."),
            .init(day: 2, title: "Your sleep window",     body: "When your body actually wants to rest."),
            .init(day: 3, title: "Stress signals",        body: "The ones your body has been hiding."),
            .init(day: 5, title: "Recovery rhythm",       body: "How long it really takes to bounce back."),
            .init(day: 7, title: "Your first weekly read", body: "What changed. What it means. What to try.")
        ]

        // Screen 15 — Sign in
        static let s15Title    = "Save your read."
        static let s15Lede     = "Sign in so your insights stay with you — across iPhone, iPad, and Watch. No password to remember."
        static let s15CTA      = "Sign in with Apple"
        static let s15Footnote = "We never see your email. Apple keeps it private."

        // Screen 16 — Paywall
        static let s16Eyebrow = "YOUR LASO PLAN"
        static let s16Title   = "Based on what we read,\nhere's what we'll watch for you."
        static let s16AnnualTitle  = "Annual"
        static let s16MonthlyTitle = "Monthly"
        static let s16AnnualSubFmt = "That's about %@/month · %@-day free trial"
        static let s16MonthlySub   = "Cancel anytime"
        static let s16CTA          = "Start free trial"
        static let s16CTAFallback  = "Continue"
        static let s16Restore      = "Restore"
        static let s16Terms        = "Terms"
        static let s16Privacy      = "Privacy"
        static let s16NoProducts   = "Loading plans..."

        struct WatchListRow {
            let icon: String
            let color: Color
            let label: String
            let sub: String
        }
        static let watchListRows: [WatchListRow] = [
            .init(icon: "heart",            color: OnbV2.rose,   label: "Resting heart rate trends", sub: "See your daily and weekly trend at a glance."),
            .init(icon: "moon.fill",        color: OnbV2.purple, label: "Your sleep debt",           sub: "Personalized to your nights"),
            .init(icon: "waveform.path.ecg", color: OnbV2.teal,  label: "HRV recovery patterns",     sub: "Including the Sunday dip"),
            .init(icon: "chart.line.uptrend.xyaxis", color: OnbV2.green, label: "Patterns we already noticed", sub: "A handful are waiting for you"),
            .init(icon: "bell.fill",        color: OnbV2.blue,   label: "Smart alerts when things shift", sub: "Quiet, not pushy")
        ]

        // Done
        static let sDoneTitle = "Welcome to Laso."
        static let sDoneLede  = "Your first insights are ready. Let's take a look."
        static let sDoneCTA   = "Open my dashboard"
    }
}
