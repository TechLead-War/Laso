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
                    label: "",
                    size: 100,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: 6) {
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

                    Text(grade)
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(gradeColor)

                    if let delta = scoreChangeFromLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text(Copy.Explore.ptsThisWeek(delta))
                                .font(.caption.weight(.medium))
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
        switch overallScore {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
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
