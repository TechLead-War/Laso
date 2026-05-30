import SwiftUI

struct ExploreCategoriesSection: View {
    let categories: [(category: HealthCategory, score: Int?)]
    let insightCountProvider: (HealthCategory) -> Int
    let onCategoryTapped: (HealthCategory, Int?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Explore.categories)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.category) { index, item in
                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: item.category.displayName,
                            type: .exploreCategoryRow,
                            screen: .explore,
                            metadata: [
                                "category": item.category.rawValue,
                                "score": item.score ?? 0
                            ]
                        )
                        onCategoryTapped(item.category, item.score)
                    } label: {
                        ExploreCategoryRow(
                            category: item.category,
                            score: item.score,
                            insightCount: insightCountProvider(item.category)
                        )
                    }
                    .buttonStyle(.dsPress)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("explore.category.\(item.category.rawValue)")
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Copy.Explore.categoryLabel(item.category.displayName))
                    .accessibilityValue(item.score.map { "Score \($0)" } ?? "No score yet")
                    .accessibilityHint(Copy.Explore.opensTheCategoryDetailHint(item.category.displayName))

                    if index < categories.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        }
    }
}

struct ExploreCategoryRow: View {
    let category: HealthCategory
    let score: Int?
    let insightCount: Int

    private var needsAttention: Bool {
        guard let score else { return false }
        return HealthScoreBand.from(score: score).requiresAttention
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.systemImageName)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(category.displayName)
                    .font(needsAttention ? .body.weight(.bold) : .body.weight(.medium))

                HStack(spacing: 8) {
                    Text(scoreStatus)
                        .font(.caption.weight(needsAttention ? .semibold : .regular))
                        .foregroundStyle(scoreStatusColor)

                    if insightCount > 0 {
                        Text(Copy.Explore.insightCount(insightCount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let score {
                HealthScoreRing(
                    score: score,
                    label: "",
                    size: 36,
                    lineWidth: 4
                )
            } else {
                Text(Copy.Explore.x)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.space4)
        .padding(.vertical, DS.space3)
    }

    private var scoreStatus: String {
        guard let score else { return Copy.Explore.noDataYet }
        switch HealthScoreBand.from(score: score) {
        case .excellent: return Copy.Explore.onTrack
        case .good: return Copy.Explore.doingWell
        case .fair: return Copy.Explore.roomToImprove
        case .needsAttention: return Copy.Explore.needsWork
        case .critical: return Copy.Explore.needsAttention
        }
    }

    private var scoreStatusColor: Color {
        guard let score else { return .secondary }
        switch HealthScoreBand.from(score: score) {
        case .excellent: return .green
        case .good: return .secondary
        case .fair: return .orange
        case .needsAttention, .critical: return .red
        }
    }
}
