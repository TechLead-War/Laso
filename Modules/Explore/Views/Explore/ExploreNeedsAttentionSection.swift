import SwiftUI

struct ExploreNeedsAttentionSection: View {
    let scoreExplanation: HealthScorer.ScoreExplanation?
    let onFactorTapped: (HealthScorer.ScoreFactor) -> Void
    let onWeakCategoryTapped: (HealthScorer.CategoryContribution) -> Void

    var body: some View {
        if let explanation = scoreExplanation {
            let negativeFactors = explanation.topFactors.filter { !$0.isPositive }
            let weakCategories = explanation.categoryContributions
                .filter { $0.score < 75 }
                .sorted { $0.score < $1.score }

            if !negativeFactors.isEmpty || !weakCategories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Copy.Explore.needsAttentionHeader)
                        .font(.headline)

                    ForEach(Array(negativeFactors.prefix(3).enumerated()), id: \.offset) { _, factor in
                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: factor.metric.displayName,
                                type: .exploreNeedsAttentionMetric,
                                screen: .explore,
                                metadata: [
                                    "metric_id": factor.metric.rawValue,
                                    "impact": factor.impact
                                ]
                            )
                            onFactorTapped(factor)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: factor.metric.systemImageName)
                                    .font(.caption)
                                    .foregroundStyle(factor.metric.category.color)
                                    .frame(width: DS.iconSize, height: DS.iconSize)
                                    .background(factor.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(factor.metric.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(factor.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text("\(factor.impact)")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                            .padding(.vertical, DS.space1)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if weakCategories.count >= 2 {
                        Divider()
                            .padding(.vertical, DS.space1)

                        HStack(spacing: 0) {
                            ForEach(weakCategories.prefix(4), id: \.category) { contrib in
                                Button {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: contrib.category.displayName,
                                        type: .exploreWeakCategory,
                                        screen: .explore,
                                        metadata: [
                                            "category": contrib.category.rawValue,
                                            "score": contrib.score
                                        ]
                                    )
                                    onWeakCategoryTapped(contrib)
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: contrib.category.systemImageName)
                                            .font(.caption2)
                                            .foregroundStyle(contrib.category.color)
                                        Text("\(contrib.score)")
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(contrib.score < 60 ? .red : .orange)
                                        Text(contrib.category.shortName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(DS.space4)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
