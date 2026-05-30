import SwiftUI

struct ExploreNeedsAttentionSection: View {
    let scoreExplanation: HealthScorer.ScoreExplanation?
    let onFactorTapped: (HealthScorer.ScoreFactor) -> Void
    let onWeakCategoryTapped: (HealthScorer.CategoryContribution) -> Void

    /// Routes weak-category colour through `HealthScoreBand` so the red/orange
    /// split matches the bands used everywhere else in Explore.
    private func weakCategoryColor(score: Int) -> Color {
        switch HealthScoreBand.from(score: score) {
        case .critical, .needsAttention: return AppColour.danger
        case .fair: return AppColour.warning
        case .good, .excellent: return AppColour.warning
        }
    }

    var body: some View {
        if let explanation = scoreExplanation {
            let negativeFactors = explanation.topFactors.filter { !$0.isPositive }
            let weakCategories = explanation.categoryContributions
                .filter { HealthScoreBand.from(score: $0.score).requiresAttention }
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

                                Text(Copy.Explore.xText(factor.impact))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                            .padding(.vertical, DS.space1)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Copy.Explore.needsAttentionLabel(factor.metric.displayName))
                        .accessibilityValue(Copy.Explore.impactValue(factor.impact, factor.reason))
                        .accessibilityHint(Copy.Explore.opensMetricDetailsHint)
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
                                    VStack(spacing: DS.space1) {
                                        Image(systemName: contrib.category.systemImageName)
                                            .font(.caption2)
                                            .foregroundStyle(contrib.category.color)
                                        Text(Copy.Explore.xText2(contrib.score))
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(weakCategoryColor(score: contrib.score))
                                        Text(contrib.category.shortName)
                                            .font(.caption2)
                                            .foregroundStyle(AppColour.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(Copy.Explore.categoryLabel(contrib.category.displayName))
                                .accessibilityValue(Copy.Explore.scoreValue(contrib.score))
                                .accessibilityHint(Copy.Explore.opensTheCategoryDetailHint(contrib.category.displayName))
                            }
                        }
                    }
                }
                .padding(DS.space4)
                .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            }
        }
    }
}
