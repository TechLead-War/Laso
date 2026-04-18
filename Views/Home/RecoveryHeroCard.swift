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
    var recoveryWhyLine: String? = nil
    var hasLiveReadiness: Bool = true
    var lastRefresh: Date? = nil
    var onTap: (() -> Void)? = nil

    @State private var appeared = false
    @State private var pulse = false

    private var scoreColor: Color {
        DS.scoreColor(score)
    }

    private var isFresh: Bool {
        guard hasLiveReadiness else { return false }
        guard let refresh = lastRefresh else { return true }
        return !isStale(refresh)
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .onAppear {
            appeared = true
            // Activation gate for the engagement sequence.
            // Only count this as "first recovery score seen" when it is a real
            // live readiness reading, not the placeholder health score card.
            if hasLiveReadiness, score > 0 {
                if UserDefaults.standard.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) {
                    // Promote to the second score gate on any subsequent real score.
                    EngagementSequenceScheduler.markActivation(.secondRecoveryScore)
                } else {
                    EngagementSequenceScheduler.markActivation(.firstRecoveryScore)
                }
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 12) {
            // Real-time indicator. tells user this score reflects their body right now
            if isFresh {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .opacity(pulse ? 0.35 : 1.0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    Text("Right now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { pulse = true }
            }

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

                    // Why line: one-line explanation of the score
                    if let whyLine = recoveryWhyLine {
                        Text(whyLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Score change from last week (stable comparison, not intra-day noise)
                    if let weekDelta = scoreChangeFromLastWeek, weekDelta != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: weekDelta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.bold))
                            Text(weekDelta > 0 ? "+\(weekDelta)" : "\(weekDelta)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .postHogMask()
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
                            .postHogMask()
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
        .accessibilityLabel("\(hasLiveReadiness ? "Recovery" : "Health") score \(score). \(recoveryLabel). \(recoveryWhyLine ?? ""). \(dayType).")
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
            scoreChangeFromLastWeek: 5,
            recoveryWhyLine: "HRV bounced back and resting heart rate is low"
        )

        RecoveryHeroCard(
            score: 58,
            dailyScore: 78,
            recoveryLabel: "Moderate Recovery",
            dayType: "Yellow Day. Maintain",
            scoreChangeFromLastWeek: -3,
            recoveryWhyLine: "Sleep was short, keeping recovery moderate"
        )

        RecoveryHeroCard(
            score: 32,
            dailyScore: 78,
            recoveryLabel: "Low Recovery",
            dayType: "Red Day. Recover",
            scoreChangeFromLastWeek: -12,
            recoveryWhyLine: "HRV has not recovered yet and sleep was short"
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
