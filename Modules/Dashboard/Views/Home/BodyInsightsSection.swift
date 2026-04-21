import SwiftUI

/// Compact insight card on Home. shows a single actionable headline (causal chain or top insight).
/// No section header, no extra chrome. just the card.
struct BodyInsightsSection: View {
    let viewModel: DashboardViewModel
    let liveVM: LiveViewModel
    let onTapMetric: (HealthMetric) -> Void
    let onTapSeeAll: () -> Void

    /// Section shows only if there's an actual card to display
    private var hasAnyContent: Bool {
        viewModel.analysis.topCausalChain != nil || viewModel.insights.headlineInsight != nil
    }

    var body: some View {
        if hasAnyContent {
            Button {
                let source: String = viewModel.analysis.topCausalChain != nil ? "causal_chain" : "headline_insight"
                AppAnalytics.shared.trackBlockTap(
                    title: "Briefing Card",
                    type: .seeAllInsights,
                    screen: .home,
                    metadata: [
                        "source": source
                    ]
                )
                onTapSeeAll()
            } label: {
                if let chain = viewModel.analysis.topCausalChain {
                    compactCausalCard(chain)
                } else if let headline = viewModel.insights.headlineInsight {
                    compactInsightCard(headline)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.insightsCard")
        }
    }

    // MARK: - Compact Insight Card

    private func compactInsightCard(_ insight: Insight) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.recommendation)
                    .font(.system(size: 14.4).weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let causeLine = compactCausationLine(for: insight) {
                    Text(causeLine)
                        .font(.system(size: 13.2))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13.2))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(DS.cardPadding)
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal, DS.screenPadding)
    }

    /// Build a short causation summary for the compact card
    private func compactCausationLine(for insight: Insight) -> String? {
        if let context = insight.context, let rootMetric = context.rootCauseMetric {
            if let deviation = context.rootCauseDeviation {
                return Copy.Insights.InsightCard.linkedToMetric(
                    rootMetric.displayName,
                    deviationPercent: abs(Int(deviation))
                )
            }
            return Copy.Insights.InsightCard.connectedToMetric(rootMetric.displayName)
        }
        return nil
    }

    // MARK: - Compact Causal Chain Card

    private func compactCausalCard(_ chain: CausalChain) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 3) {
                Text(chain.narrative)
                    .font(.system(size: 14.4).weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let confidenceLine = causalChainConfidenceLine(chain) {
                    Text(confidenceLine)
                        .font(.system(size: 13.2))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13.2))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(DS.cardPadding)
        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal, DS.screenPadding)
    }

    /// Confidence qualifier for a causal chain
    private func causalChainConfidenceLine(_ chain: CausalChain) -> String? {
        let confidence = chain.confidence
        guard confidence > 0 else { return nil }
        let level: String = if confidence >= 0.8 {
            "High"
        } else if confidence >= 0.5 {
            "Moderate"
        } else {
            "Early"
        }
        return Copy.Insights.InsightCard.confidenceQualifier(level)
    }
}
