import SwiftUI

/// Animated circular ring showing a health score (0-100)
struct HealthScoreRing: View {
    let score: Int
    let label: String
    let size: CGFloat
    let lineWidth: CGFloat
    let showScore: Bool
    let tint: Color?

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringColor: Color {
        tint ?? DS.scoreColor(score)
    }

    /// `animatesOnAppear` is accepted but ignored: appearing never animates any
    /// more, so no caller needs to opt out. Kept only so the one existing call
    /// site still compiles — delete the argument there, then this parameter.
    init(score: Int, label: String = "Overall", size: CGFloat = 160, lineWidth: CGFloat = 14, showScore: Bool = true, tint: Color? = nil, animatesOnAppear: Bool = true) {
        self.score = score
        self.label = label
        self.size = size
        self.lineWidth = lineWidth
        self.showScore = showScore
        self.tint = tint
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppColour.trackNeutral, lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center text. always perfectly centered regardless of 1 or 2 lines
            centerContent
                .frame(
                    width: size - (lineWidth * 2 + 16),
                    alignment: .center
                )
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.isEmpty ? "Score \(score)" : "\(label) score \(score) out of 100")
        .accessibilityValue(Copy.Common.percentValue(score))
        .onAppear {
            // Seeded with animations off. A LazyVStack tears the row down on
            // scroll-off, so `@State` resets to 0 and an animated seed replayed
            // the full fill every scroll back, reading as a score that just
            // changed. Only a real score change should animate.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { animatedProgress = progress }
        }
        .onChange(of: score) {
            withAnimation(.easeInOut(duration: 1.0)) { animatedProgress = progress }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)

            if showScore {
                Text(Copy.Common.xText(score))
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(ringColor)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .postHogMask()
            }

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: showScore ? size * 0.12 : size * 0.15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColour.textSecondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    VStack(spacing: 30) {
        HealthScoreRing(score: 82)
        HealthScoreRing(score: 65, label: "Heart", size: 100, lineWidth: 10)
        HealthScoreRing(score: 45, label: "Sleep", size: 80, lineWidth: 8)
    }
    .padding()
}

/// A quiet, open dial for the primary score. Decorative ticks are hidden from
/// VoiceOver; the accessible value always includes the score's actual identity.
struct HealthScoreGauge: View {
    let score: Int
    let label: String
    var tint: Color = AppColour.primary
    var compact = false

    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 80
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var diameter: CGFloat { compact ? 100 : 236 }
    private var progress: CGFloat { CGFloat(min(100, max(0, score))) / 100 }

    static func bandColor(_ score: Int) -> Color {
        switch HealthScoreBand.from(score: score) {
        case .excellent, .good: return AppColour.primary
        case .fair: return AppColour.warning
        case .needsAttention, .critical: return AppColour.danger
        }
    }

    var body: some View {
        ZStack {
            if !compact { tickMarks.accessibilityHidden(true) }
            progressArc.accessibilityHidden(true)
            scoreLabel
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(score) out of 100")
    }

    private var tickMarks: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer: CGFloat = size.width / 2 - 1
            for tick in 0...40 {
                let degrees: CGFloat = 135 + CGFloat(tick) * 6.75
                let angle: CGFloat = degrees * .pi / 180
                let inner: CGFloat = outer - (tick.isMultiple(of: 5) ? 6 : 3)
                let start = CGPoint(x: center.x + cos(angle) * inner,
                                    y: center.y + sin(angle) * inner)
                let end = CGPoint(x: center.x + cos(angle) * outer,
                                  y: center.y + sin(angle) * outer)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(AppColour.borderMedium), lineWidth: 1)
            }
        }
    }

    private var progressArc: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(AppColour.trackNeutral, style: arcStroke)
            Circle().trim(from: 0, to: progress * 0.75)
                .stroke(tint, style: arcStroke)
            Circle().fill(tint)
                .frame(width: compact ? 6 : 9, height: compact ? 6 : 9)
                .offset(x: (diameter - (compact ? 8 : 26)) / 2)
                .rotationEffect(.degrees(Double(progress) * 270))
        }
        .rotationEffect(.degrees(135))
        .padding(compact ? 4 : 13)
    }

    private var arcStroke: StrokeStyle {
        StrokeStyle(lineWidth: compact ? 4 : 5, lineCap: .round)
    }

    private var scoreLabel: some View {
        VStack(spacing: compact ? 0 : 3) {
            if !compact {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
            }
            Text(score.formatted())
                .font(.system(size: compact ? 36 : min(numeralSize, 100), weight: .light).monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .contentTransition(.numericText())
                .postHogMask()
            if !compact {
                Text("OUT OF 100")
                    .font(.caption2.weight(.medium))
                    .tracking(1.6)
                    .foregroundStyle(AppColour.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, compact ? 12 : 30)
    }
}
