import SwiftUI

struct ExploreCorrelationsSection: View {
    let correlations: [HealthCorrelation]
    let topCompoundInsight: CompoundInsightEngine.CompoundInsight?
    let topCausalChain: CausalChain?
    let onSeeAllTapped: () -> Void

    init(
        correlations: [HealthCorrelation],
        topCompoundInsight: CompoundInsightEngine.CompoundInsight? = nil,
        topCausalChain: CausalChain? = nil,
        onSeeAllTapped: @escaping () -> Void
    ) {
        self.correlations = correlations
        self.topCompoundInsight = topCompoundInsight
        self.topCausalChain = topCausalChain
        self.onSeeAllTapped = onSeeAllTapped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                    Text("Health Intelligence")
                        .font(.headline)
                }

                Spacer()

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "See All Intelligence",
                        type: .exploreSeeAllCorrelations,
                        screen: .explore,
                        metadata: ["correlations_count": correlations.count]
                    )
                    onSeeAllTapped()
                } label: {
                    HStack(spacing: 4) {
                        Text(Copy.Explore.seeAll)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("explore.correlations.seeAll")
            }
            .padding(.horizontal)

            // Show a compound insight if available, otherwise fall back to correlation cards
            if let insight = topCompoundInsight {
                insightPreviewCard(insight)
                    .padding(.horizontal)
            } else if let chain = topCausalChain {
                chainPreviewCard(chain)
                    .padding(.horizontal)
            } else {
                ForEach(Array(correlations.prefix(2))) { correlation in
                    correlationCard(correlation)
                        .padding(.horizontal)
                }
            }
        }
    }

    private func insightPreviewCard(_ insight: CompoundInsightEngine.CompoundInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(insight.narrative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(insight.involvedMetrics.prefix(3), id: \.rawValue) { metric in
                    Image(systemName: metric.systemImageName)
                        .font(.caption2)
                        .foregroundStyle(metric.category.color)
                        .frame(width: 18, height: 18)
                        .background(metric.category.color.opacity(0.12), in: Circle())
                }

                Spacer()

                Text(insight.category.rawValue.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .purple)
    }

    private func chainPreviewCard(_ chain: CausalChain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chain icons
            HStack(spacing: 6) {
                ForEach(Array(chain.links.enumerated()), id: \.offset) { index, link in
                    if index == 0 {
                        Image(systemName: link.causeMetric.systemImageName)
                            .font(.caption)
                            .foregroundStyle(link.causeMetric.category.color)
                            .frame(width: 22, height: 22)
                            .background(link.causeMetric.category.color.opacity(0.12), in: Circle())
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.purple.opacity(0.5))
                    Image(systemName: link.effectMetric.systemImageName)
                        .font(.caption)
                        .foregroundStyle(link.effectMetric.category.color)
                        .frame(width: 22, height: 22)
                        .background(link.effectMetric.category.color.opacity(0.12), in: Circle())
                }
            }

            Text(chain.narrative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: .purple)
    }

    private func correlationCard(_ c: HealthCorrelation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: c.metricA.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricA.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricA.category.color.opacity(0.12), in: Circle())

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: c.metricB.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricB.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricB.category.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(c.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(c.strengthLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}
