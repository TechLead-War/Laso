import SwiftUI

/// Full-screen view showing all insights as a prioritized action list
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void

    /// All insights flattened and sorted by priority (most important first)
    private var sortedInsights: [Insight] {
        insightsByCategory
            .flatMap(\.insights)
            .sorted { $0.priorityScore > $1.priorityScore }
    }

    /// Top priority items that need action
    private var needsAttention: [Insight] {
        sortedInsights.filter { $0.severity == .critical || $0.severity == .warning }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !needsAttention.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("Needs your attention")
                                .font(.headline)

                            Spacer()

                            Text("\(needsAttention.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.red, in: Capsule())
                        }
                        .padding(.horizontal)

                        ForEach(needsAttention) { insight in
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
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("You're all good")
                            .font(.title3.weight(.semibold))
                        Text("Nothing needs your attention right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("What To Focus On")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.insightsDetail) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.insightsDetail) }
    }
}
