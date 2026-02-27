import SwiftUI

/// "Body Insights" section on the Home tab — surfaces sleep, patterns, smart actions, and anomalies
struct BodyInsightsSection: View {
    let viewModel: DashboardViewModel
    let liveVM: LiveViewModel
    let onTapMetric: (HealthMetric) -> Void
    let onTapSeeAll: () -> Void

    private var sleepBaseline: Double? {
        viewModel.analysisEngine.baselines[.sleepDuration]?.mean
    }

    private var sleepInsight: Insight? {
        viewModel.analysisEngine.insights.first { $0.category == .sleepPerformance }
    }

    private var smartAction: DashboardViewModel.SmartAction? {
        // Only show if there's real, fresh data driving it (not generic defaults or stale readings)
        guard liveVM.readinessScore != nil || liveVM.stressLevel != nil ||
              liveVM.hasSleepData || liveVM.todayExerciseMinutes > 0 else {
            return nil
        }
        // Don't show readiness/stress-based actions when underlying data is stale
        guard liveVM.isReadinessDataFresh || liveVM.hasSleepData || liveVM.todayExerciseMinutes > 0 else {
            return nil
        }
        return viewModel.smartDailyAction(liveVM: liveVM)
    }

    private var totalInsightCount: Int {
        viewModel.focusedInsights.count
    }

    /// Section shows if there's a headline insight or meaningful data to surface
    private var hasAnyContent: Bool {
        viewModel.headlineInsight != nil ||
        liveVM.hasSleepData ||
        liveVM.readinessScore != nil
    }

    var body: some View {
        if hasAnyContent {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(spacing: 8) {

                    Text("Today's Briefing")
                        .font(.headline)

                    Spacer()

                    if totalInsightCount > 0 {
                        Button(action: {
                            AppAnalytics.shared.trackBlockTap(title: "See All Insights", type: .seeAllInsights, screen: .home)
                            onTapSeeAll()
                        }) {
                            HStack(spacing: 4) {
                                Text("See all")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // 1. Headline: prefer causal chain (explains WHY), fall back to top insight
                if let chain = viewModel.topCausalChain {
                    causalChainCard(chain)
                } else if let headline = viewModel.headlineInsight {
                    headlineInsightCard(headline)
                }

                // 2. Smart daily action (only when driven by real data)
                if smartAction != nil {
                    smartActionCard
                }
            }
        }
    }

    // MARK: - Headline Insight Card

    private func headlineInsightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Context line: what's happening
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(insight.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            // Main message: what to DO about it
            Text(insight.recommendation)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Causal Chain Card

    private func causalChainCard(_ chain: CausalChain) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Why This Is Happening")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(chain.narrative)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Smart Action Card

    @ViewBuilder
    private var smartActionCard: some View {
        if let action = smartAction {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [.yellow.opacity(0.2), .orange.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.yellow.opacity(0.06), .orange.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.yellow.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .padding(.horizontal)
        }
    }

}
