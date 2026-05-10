import SwiftUI

struct ExploreScoreHeroSection: View {
    let overallScore: Int
    let scoreChangeFromLastWeek: Int?
    let weakestCategory: (category: HealthCategory, score: Int)?
    let onScoreInfoTapped: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                HealthScoreRing(
                    score: overallScore,
                    label: DS.scoreLabel(overallScore),
                    size: 100,
                    lineWidth: 10,
                    showScore: false
                )

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(Copy.Explore.healthScore)
                                .font(.subheadline)
                                .foregroundStyle(AppColour.textSecondary)

                            Button {
                                onScoreInfoTapped()
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(AppColour.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Health score info")
                            .accessibilityHint("Opens an explanation of how your health score is calculated")
                        }

                        Text(Copy.Explore.healthScoreSubtitle)
                            .font(.caption2)
                            .foregroundStyle(AppColour.textTertiary)
                    }

                    Text(displayScore)
                        .font(DS.Typography.displayL)
                        .foregroundStyle(displayScoreColor)
                        .postHogMask()

                    if let delta = scoreChangeFromLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text(Copy.Explore.ptsThisWeek(delta))
                                .font(.caption.weight(.medium))
                                .postHogMask()
                        }
                        .foregroundStyle(delta > 0 ? .green : .red)
                    } else {
                        Text(scoreLabel)
                            .font(.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }

                Spacer()
            }

            if let weakest = weakestCategory {
                HStack(spacing: 6) {
                    Image(systemName: weakest.category.systemImageName)
                        .font(.caption)
                        .foregroundStyle(weakest.category.color)
                    Text(Copy.Explore.focusToImprove(weakest.category.displayName))
                        .font(.caption)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                }
                .padding(DS.space3)
                .background(AppColour.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .padding(DS.space4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    private var displayScore: String {
        "\(overallScore)"
    }

    /// Routes through `HealthScoreBand` so the score-number colour and the
    /// status label below it always sit in the same band — using `DS.scoreColor`
    /// here would mix the recovery-tier scheme (75/50) with the band scheme
    /// (85/70/55/40) and let, e.g., a 72 colour yellow while reading "Good".
    private var displayScoreColor: Color {
        switch HealthScoreBand.from(score: overallScore) {
        case .excellent: return AppColour.success
        case .good: return AppColour.scoreOptimal
        case .fair: return AppColour.scoreFair
        case .needsAttention, .critical: return AppColour.scorePoor
        }
    }

    private var scoreLabel: String {
        switch HealthScoreBand.from(score: overallScore) {
        case .excellent: return Copy.Explore.excellentShape
        case .good: return Copy.Explore.lookingGood
        case .fair: return Copy.Explore.roomToImprove
        case .needsAttention, .critical: return Copy.Explore.needsAttention
        }
    }
}
