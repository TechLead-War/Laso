import SwiftUI

/// Full-screen view showing all insights grouped by category
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(insightsByCategory, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        // Category header
                        HStack(spacing: 8) {
                            Image(systemName: group.category.systemImageName)
                                .font(.headline)
                                .foregroundStyle(group.category.color)

                            Text(group.category.displayName)
                                .font(.headline)

                            Text("\(group.insights.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(group.category.color, in: Capsule())

                            Spacer()
                        }
                        .padding(.horizontal)

                        ForEach(group.insights) { insight in
                            Button {
                                AppAnalytics.shared.trackBlockTap(title: insight.title, type: .insightCard, screen: .insightsDetail)
                                onTapMetric(insight.metric)
                            } label: {
                                InsightCard(insight: insight)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("All Insights")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.insightsDetail) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.insightsDetail) }
    }
}
