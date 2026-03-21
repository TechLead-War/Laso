import SwiftUI

/// Full-width hero card showing recovery score ring, recovery state label,
/// score delta badge, and day classification. Designed to sit at the very top
/// of HomeView as the single most important piece of daily information.
struct RecoveryHeroCard: View {
    let score: Int
    let dailyScore: Int?
    let recoveryLabel: String
    let dayType: String
    let scoreChangeFromLastWeek: Int?
    var hasLiveReadiness: Bool = true
    var lastRefresh: Date? = nil
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
                // Score ring. hero size
                HealthScoreRing(
                    score: score,
                    label: hasLiveReadiness ? "Recovery" : "Health",
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

                    // Score change from last week (stable comparison, not intra-day noise)
                    if let weekDelta = scoreChangeFromLastWeek, weekDelta != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: weekDelta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.bold))
                            Text(weekDelta > 0 ? "+\(weekDelta)" : "\(weekDelta)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text("vs last week")
                                .font(.caption)
                        }
                        .foregroundStyle(weekDelta > 0 ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (weekDelta > 0 ? Color.green : Color.red).opacity(DS.badgeBg),
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

                    // Staleness indicator or fallback hint
                    if !hasLiveReadiness {
                        Text("Wear Apple Watch for recovery data")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if let refresh = lastRefresh, isStale(refresh) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                            Text("Updated \(refresh, style: .relative) ago")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                    } else if let daily = dailyScore, daily != score {
                        Text("Daily baseline: \(daily)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
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
        .accessibilityLabel("\(hasLiveReadiness ? "Recovery" : "Health") score \(score). \(recoveryLabel). \(dayType).")
        .accessibilityHint("Opens score breakdown")
        .accessibilityIdentifier("home.recoveryCard")
    }

    /// Score is stale if last refresh was more than 30 minutes ago
    private func isStale(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) > 30 * 60
    }
}

#Preview {
    VStack(spacing: 20) {
        RecoveryHeroCard(
            score: 82,
            dailyScore: 78,
            recoveryLabel: "Fully Recovered",
            dayType: "Green Day. Push Hard",
            scoreChangeFromLastWeek: 5
        )

        RecoveryHeroCard(
            score: 58,
            dailyScore: 78,
            recoveryLabel: "Moderate Recovery",
            dayType: "Yellow Day. Maintain",
            scoreChangeFromLastWeek: -3
        )

        RecoveryHeroCard(
            score: 32,
            dailyScore: 78,
            recoveryLabel: "Low Recovery",
            dayType: "Red Day. Recover",
            scoreChangeFromLastWeek: -12
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
