import SwiftUI

struct ExploreScoreHeroSection: View {
    let overallScore: Int
    let scoreChangeFromLastWeek: Int?
    let weakestCategory: (category: HealthCategory, score: Int)?
    let onScoreInfoTapped: () -> Void
    var onFocusTapped: ((HealthCategory) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: DS.space3) {
            Button(action: onScoreInfoTapped) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: DS.space3) {
                            scoreSummary
                            scoreGauge
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: DS.space4) {
                            scoreSummary.frame(maxWidth: .infinity, alignment: .leading)
                            scoreGauge
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
            }
            .buttonStyle(.plain)
            .accessibilityHint(Copy.Explore.opensAnExplanationOfHowYourHint)

            if let weakest = weakestCategory {
                Button { onFocusTapped?(weakest.category) } label: {
                    HStack(alignment: .center, spacing: DS.space3) {
                        Image(systemName: weakest.category.systemImageName)
                            .font(.title3)
                            .foregroundStyle(weakest.category.color)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: DS.space1) {
                            Text("A LITTLE FOCUS")
                                .font(.caption2.weight(.semibold))
                                .tracking(1.3)
                                .foregroundStyle(AppColour.textSecondary)
                            Text(weakest.category.displayName)
                                .font(.headline)
                                .foregroundStyle(AppColour.textPrimary)
                            Text(Copy.Explore.focusToImprove(weakest.category.displayName))
                                .font(.footnote)
                                .foregroundStyle(AppColour.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    .padding(DS.cardPadding)
                    .cardStyle()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("explore.focusCategory")
            }
        }
    }

    private var scoreGauge: some View {
        HealthScoreGauge(score: overallScore, label: Copy.Explore.healthScore,
                         tint: HealthScoreGauge.bandColor(overallScore), compact: true)
    }

    private var scoreSummary: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.Explore.healthScore)
                .font(.subheadline)
                .foregroundStyle(AppColour.textSecondary)
            Text(scoreLabel)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColour.textPrimary)
            if let delta = scoreChangeFromLastWeek {
                Label(Copy.Explore.ptsThisWeek(delta),
                      systemImage: delta == 0 ? "arrow.right" : delta > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnote)
                    .foregroundStyle(delta == 0 ? AppColour.textSecondary : delta > 0 ? AppColour.primary : AppColour.warning)
                    .postHogMask()
            } else {
                Text(Copy.Explore.healthScoreSubtitle)
                    .font(.footnote)
                    .foregroundStyle(AppColour.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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
