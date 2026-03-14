import SwiftUI

/// Compact insight card on Home — shows a single actionable headline (causal chain or top insight).
/// No section header, no extra chrome — just the card.
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
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text(insight.recommendation)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(DS.cardPadding)
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal)
    }

    // MARK: - Compact Causal Chain Card

    private func compactCausalCard(_ chain: CausalChain) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text(chain.narrative)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(DS.cardPadding)
        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .padding(.horizontal)
    }
}
