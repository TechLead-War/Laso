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
