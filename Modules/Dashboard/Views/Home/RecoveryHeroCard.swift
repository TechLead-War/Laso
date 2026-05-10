import SwiftUI

/// Full-width hero card showing recovery score ring, recovery state label,
/// score delta badge, and day classification. Designed to sit at the very top
/// of HomeView as the single most important piece of daily information.
struct RecoveryHeroCard: View {
    let score: Int
    let recoveryLabel: String
    let dayType: String
    let scoreChangeFromLastWeek: Int?
    var recoveryWhyLine: String? = nil
    var hasLiveReadiness: Bool = true
    var lastRefresh: Date? = nil
    var scoreLabel: String = "Recovery"
    var isWearingWatch: Bool = true
    var weeklyTrendCaption: String? = nil
    var onTap: (() -> Void)? = nil

    @State private var appeared = false
    @State private var pulse = false

    /// Derived from RecoveryState so title, pill, and ring all share one threshold table.
    private var recoveryState: DashboardViewModel.RecoveryState {
        DashboardViewModel.RecoveryState(score: score)
    }

    private var scoreColor: Color {
        recoveryState.color
    }

    private var isFresh: Bool {
        guard hasLiveReadiness else { return false }
        guard let refresh = lastRefresh else { return true }
        return !isStale(refresh)
    }

    /// True when there is no morning lock today AND the watch is currently off.
    /// In every other state (lock present, or watch on streaming live energy)
    /// the normal card content shows the legitimate score.
    private var shouldShowWearWatch: Bool {
        !isWearingWatch && score == 0
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            Group {
                if shouldShowWearWatch {
                    wearWatchEmptyState
                } else {
                    cardContent
                }
            }
        }
        .buttonStyle(.dsPress)
        .padding(.horizontal, DS.screenPadding)
        .onAppear {
            appeared = true
            // Activation gate for the engagement sequence. Skip when there is
            // nothing legitimate to show — placeholder Health rings, watch-off
            // empty states, and zero scores must not promote the user toward
            // the "second recovery score" milestone.
            guard isWearingWatch, hasLiveReadiness, score > 0 else { return }
            if UserDefaults.standard.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) {
                EngagementSequenceScheduler.markActivation(.secondRecoveryScore)
            } else {
                EngagementSequenceScheduler.markActivation(.firstRecoveryScore)
            }
        }
    }

    // MARK: - Wear Watch Empty State

    private var wearWatchEmptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(DS.Typography.title2)
                .foregroundStyle(AppColour.textTertiary)
                .frame(width: 56, height: 56)
                .background(AppColour.surfaceRaised, in: Circle())

            Text(Copy.Home.wearAppleWatchForRecovery)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.textTertiary.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.wearAppleWatchForRecovery)
        .accessibilityIdentifier("home.recoveryCard.wearWatch")
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 12) {
            // Real-time indicator. tells user this score reflects their body right now
            if isFresh {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColour.scoreOptimal)
                        .frame(width: 7, height: 7)
                        .opacity(pulse ? 0.35 : 1.0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                    Text(Copy.Home.Cards.rightNow)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { pulse = true }
            }

            HStack(spacing: 20) {
                // Score ring. hero size. tinted by RecoveryState so the colour
                // agrees with the title and the day-type pill.
                HealthScoreRing(
                    score: score,
                    label: hasLiveReadiness ? scoreLabel : "Health",
                    size: 120,
                    lineWidth: 12,
                    tint: hasLiveReadiness ? recoveryState.color : nil
                )

                // Recovery details
                VStack(alignment: .leading, spacing: 8) {
                    // Recovery state label
                    Text(recoveryLabel)
                        .font(DS.Typography.title2)
                        .foregroundStyle(AppColour.textPrimary)
                        .contentTransition(.numericText())

                    // Why line: full explanation of the score, no truncation.
                    if let whyLine = recoveryWhyLine {
                        Text(whyLine)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Score change from last week (stable comparison, not intra-day noise)
                    if let weekDelta = scoreChangeFromLastWeek, weekDelta != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: weekDelta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(DS.Typography.footnoteMedium)
                            Text(weekDelta > 0 ? "+\(weekDelta)" : "\(weekDelta)")
                                .font(DS.Typography.bodySemibold.monospacedDigit())
                                .postHogMask()
                            Text(Copy.Home.Cards.vsLastWeek)
                                .font(DS.Typography.footnote)
                        }
                        .foregroundStyle(weekDelta > 0 ? AppColour.scoreOptimal : AppColour.scorePoor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (weekDelta > 0 ? AppColour.scoreOptimal : AppColour.scorePoor).opacity(DS.badgeBg),
                            in: Capsule()
                        )
                    }

                    // Day classification badge
                    Text(dayType)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(scoreColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(scoreColor.opacity(DS.badgeBg), in: Capsule())

                    // 7-day HRV trend caption (only when we have a live score, a
                    // real number to attach the caption to, and a definitive
                    // trend — `.insufficientData` returns nil from the caller).
                    if hasLiveReadiness, score > 0, let caption = weeklyTrendCaption {
                        Text(caption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    }

                    // Staleness indicator or fallback hint
                    if !hasLiveReadiness {
                        Text(Copy.Home.wearAppleWatchForRecovery)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textTertiary)
                    } else if let refresh = lastRefresh, isStale(refresh) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(DS.Typography.caption)
                            Copy.Home.updatedAgo(refresh)
                                .font(DS.Typography.caption)
                        }
                        .foregroundStyle(AppColour.warning)
                        .padding(.horizontal, DS.space2)
                        .padding(.vertical, 3)
                        .background(AppColour.warning.opacity(0.1), in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }

            // Subtle tap hint
            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(DS.Typography.caption)
                Text(Copy.Home.tapToUnderstandScore)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(AppColour.textTertiary)
        }
        .padding(DS.cardPadding + 4)
        .background(
            LinearGradient(
                colors: [scoreColor.opacity(0.28), scoreColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(scoreColor.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hasLiveReadiness ? scoreLabel : "Health") score \(score). \(recoveryLabel). \(recoveryWhyLine ?? ""). \(dayType). \(weeklyTrendCaption ?? "")")
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
            recoveryLabel: "Fully Recovered",
            dayType: "Green Day. Push Hard",
            scoreChangeFromLastWeek: 5,
            recoveryWhyLine: "HRV bounced back and resting heart rate is low",
            scoreLabel: "Recovery",
            weeklyTrendCaption: "HRV trending up this week"
        )

        RecoveryHeroCard(
            score: 58,
            recoveryLabel: "Moderate Recovery",
            dayType: "Yellow Day. Maintain",
            scoreChangeFromLastWeek: -3,
            recoveryWhyLine: "Sleep was short, keeping recovery moderate",
            scoreLabel: "Energy",
            weeklyTrendCaption: "HRV steady this week"
        )

        RecoveryHeroCard(
            score: 0,
            recoveryLabel: "",
            dayType: "",
            scoreChangeFromLastWeek: nil,
            isWearingWatch: false
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
