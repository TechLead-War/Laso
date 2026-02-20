import SwiftUI

/// Animated circular ring showing a health score (0-100)
struct HealthScoreRing: View {
    let score: Int
    let label: String
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    init(score: Int, label: String = "Overall", size: CGFloat = 160, lineWidth: CGFloat = 14) {
        self.score = score
        self.label = label
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)

            // Center text — always perfectly centered regardless of 1 or 2 lines
            centerContent
                .frame(
                    width: size - (lineWidth * 2 + 16),
                    alignment: .center
                )
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.isEmpty ? "Score \(score)" : "\(label) score \(score) out of 100")
        .accessibilityValue("\(score) percent")
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: score) {
            animatedProgress = progress
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        VStack(spacing: 2) {
            Spacer(minLength: 0)

            Text("\(score)")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
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
