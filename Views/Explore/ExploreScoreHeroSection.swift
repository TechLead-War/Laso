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
                                .foregroundStyle(.secondary)

                            Button {
                                onScoreInfoTapped()
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(Copy.Explore.healthScoreSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(grade)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(gradeColor)
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
                            .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var grade: String {
        "\(overallScore)"
    }

    private var gradeColor: Color {
        DS.scoreColor(overallScore)
    }

    private var scoreLabel: String {
        switch overallScore {
        case 85...100: return Copy.Explore.excellentShape
        case 70..<85: return Copy.Explore.lookingGood
        case 55..<70: return Copy.Explore.roomToImprove
        default: return Copy.Explore.needsAttention
        }
    }
}
