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

    private var smartAction: DashboardViewModel.SmartAction {
        viewModel.smartDailyAction(liveVM: liveVM)
    }

    private var totalInsightCount: Int {
        viewModel.analysisEngine.insights.count
    }

    /// Section shows if any sub-component has data
    private var hasAnyContent: Bool {
        liveVM.hasSleepData ||
        true // SmartAction always renders
    }

    var body: some View {
        if hasAnyContent {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Body Insights")
                        .font(.headline)

                    if totalInsightCount > 0 {
                        Text("\(totalInsightCount)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.purple, in: Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // 1. Sleep card
                SleepCard(
                    liveVM: liveVM,
                    sleepBaseline: sleepBaseline,
                    sleepInsight: sleepInsight
                )
                .padding(.horizontal)

                // 2. Smart daily action
                smartActionCard

                // 3. See all button
                if totalInsightCount > 0 {
                    Button(action: {
                        AppAnalytics.shared.trackBlockTap(title: "See All Insights", type: .seeAllInsights, screen: .home)
                        onTapSeeAll()
                    }) {
                        HStack {
                            Text("See All Insights")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Smart Action Card

    private var smartActionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: smartAction.icon)
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
                Text(smartAction.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(smartAction.subtitle)
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
