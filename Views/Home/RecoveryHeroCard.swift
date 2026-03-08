import SwiftUI

/// Full-width hero card showing recovery score ring, recovery state label,
/// score delta badge, and day classification. Designed to sit at the very top
/// of HomeView as the single most important piece of daily information.
struct RecoveryHeroCard: View {
    let score: Int
    let recoveryLabel: String
    let dayType: String
    let scoreDelta: Int?
    var onTap: (() -> Void)? = nil

    @State private var appeared = false

    private var scoreColor: Color {
        DS.scoreColor(score)
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .onAppear { appeared = true }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Score ring — hero size
                HealthScoreRing(
                    score: score,
                    label: "Recovery",
                    size: 120,
                    lineWidth: 12
                )

                // Recovery details
                VStack(alignment: .leading, spacing: 8) {
                    // Recovery state label
                    Text(recoveryLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    // Score delta badge
                    if let delta = scoreDelta, delta != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.bold))
                            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("from yesterday")
                                .font(.caption)
                        }
                        .foregroundStyle(delta > 0 ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (delta > 0 ? Color.green : Color.red).opacity(DS.badgeBg),
                            in: Capsule()
                        )
                    }

                    // Day classification badge
                    Text(dayType)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(scoreColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(scoreColor.opacity(DS.badgeBg), in: Capsule())
                }

                Spacer(minLength: 0)
            }

            // Subtle tap hint
            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(.caption2)
                Text("Tap to understand your score")
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding + 4)
        .background(DS.recoveryGradient(score))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(scoreColor.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: scoreColor.opacity(0.15), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery score \(score). \(recoveryLabel). \(dayType).")
        .accessibilityHint("Opens score breakdown")
    }
}

#Preview {
    VStack(spacing: 20) {
        RecoveryHeroCard(
            score: 82,
            recoveryLabel: "Fully Recovered",
            dayType: "Green Day — Push Hard",
            scoreDelta: 5
        )

        RecoveryHeroCard(
            score: 58,
            recoveryLabel: "Moderate Recovery",
            dayType: "Yellow Day — Maintain",
            scoreDelta: -3
        )

        RecoveryHeroCard(
            score: 32,
            recoveryLabel: "Low Recovery",
            dayType: "Red Day — Recover",
            scoreDelta: -12
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
