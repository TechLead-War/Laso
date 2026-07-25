import SwiftUI

/// Merged "Why this week" section: each declining metric expands inline to
/// show its causal explanation (chain narrative + evidence) so users see
/// what dropped and why in one place. When no causal chain exists for a
/// metric, the row stays collapsed-only with the basic recommendation.
struct ExploreDecliningTrendsSection: View {
    let decliningHighlights: [DashboardViewModel.HistoricalHighlight]
    let causalChains: [CausalChain]
    let onHighlightTapped: (DashboardViewModel.HistoricalHighlight) -> Void
    let onSeeAllIntelligenceTapped: (() -> Void)?

    @State private var expandedMetricIDs: Set<String> = []

    init(
        decliningHighlights: [DashboardViewModel.HistoricalHighlight],
        causalChains: [CausalChain] = [],
        onHighlightTapped: @escaping (DashboardViewModel.HistoricalHighlight) -> Void,
        onSeeAllIntelligenceTapped: (() -> Void)? = nil
    ) {
        self.decliningHighlights = decliningHighlights
        self.causalChains = causalChains
        self.onHighlightTapped = onHighlightTapped
        self.onSeeAllIntelligenceTapped = onSeeAllIntelligenceTapped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.Explore.decliningTrends)
                        .font(.headline)
                    Text(Copy.Explore.whyExplainerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let onSeeAll = onSeeAllIntelligenceTapped, !causalChains.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text(Copy.Explore.seeAll)
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Copy.Explore.seeAllCausalExplanationsLabel)
                    .accessibilityHint(Copy.Explore.opensTheFullHealthIntelligenceViewHint)
                }
            }
            .padding(.horizontal)

            ForEach(decliningHighlights) { highlight in
                let chain = matchingChain(for: highlight)
                whyCard(highlight: highlight, chain: chain)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Card

    private func whyCard(highlight: DashboardViewModel.HistoricalHighlight, chain: CausalChain?) -> some View {
        let isExpanded = expandedMetricIDs.contains(highlight.metric.rawValue)
        let canExpand = chain != nil

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: highlight.metric.displayName,
                    type: .exploreDecliningMetric,
                    screen: .explore,
                    metadata: [
                        "metric_id": highlight.metric.rawValue,
                        "highlight_type": highlight.typeLabel,
                        "has_causal_chain": canExpand
                    ]
                )
                if canExpand {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedMetricIDs.remove(highlight.metric.rawValue)
                        } else {
                            expandedMetricIDs.insert(highlight.metric.rawValue)
                        }
                    }
                } else {
                    onHighlightTapped(highlight)
                }
            } label: {
                summaryRow(highlight: highlight, canExpand: canExpand, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Copy.Explore.decliningTrendLabel(highlight.metric.displayName, highlight.title))
            .accessibilityValue(isExpanded ? "Expanded" : (canExpand ? "Collapsed" : ""))
            .accessibilityHint(canExpand ? "Toggles a causal explanation for why this metric declined" : "Opens detailed metric history")

            if isExpanded, let chain = chain {
                Divider().opacity(0.5).padding(.vertical, DS.space2)
                explanationView(chain: chain, highlight: highlight)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func summaryRow(highlight: DashboardViewModel.HistoricalHighlight, canExpand: Bool, isExpanded: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlight.metric.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text(highlight.typeLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Color.orange.opacity(DS.badgeBg), in: Capsule())
                }

                Text(highlight.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(canExpand ? Copy.Explore.whyTapToExplain : highlight.recommendation)
                    .font(.caption)
                    .foregroundStyle(canExpand ? .purple : .secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: canExpand ? (isExpanded ? "chevron.up" : "chevron.down") : "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func explanationView(chain: CausalChain, highlight: DashboardViewModel.HistoricalHighlight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Chain narrative
            Text(chain.narrative)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Inline mini chain (cause → effect icons) + confidence
            HStack(spacing: 6) {
                ForEach(Array(chain.links.enumerated()), id: \.offset) { index, link in
                    if index == 0 {
                        Image(systemName: link.causeMetric.systemImageName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(link.causeMetric.category.color)
                            .frame(width: 22, height: 22)
                            .background(link.causeMetric.category.color.opacity(0.12), in: Circle())
                    }
                    Image(systemName: "arrow.right")
                        .font(DS.Typography.caption2.weight(.bold))
                        .foregroundStyle(.purple.opacity(0.5))
                    Image(systemName: link.effectMetric.systemImageName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(link.effectMetric.category.color)
                        .frame(width: 22, height: 22)
                        .background(link.effectMetric.category.color.opacity(0.12), in: Circle())
                }
                Spacer()
                Text(Copy.Explore.confidencePercent(Int(chain.confidence * 100)))
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Open full metric detail
            Button {
                onHighlightTapped(highlight)
            } label: {
                HStack(spacing: 4) {
                    Text(Copy.Explore.openMetric(highlight.metric.displayName))
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.Explore.openMetric(highlight.metric.displayName))
            .accessibilityHint(Copy.Explore.opensDetailViewHint(highlight.metric.displayName))
        }
    }

    // MARK: - Matching

    private func matchingChain(for highlight: DashboardViewModel.HistoricalHighlight) -> CausalChain? {
        causalChains.first { $0.affectedMetric == highlight.metric }
    }
}
