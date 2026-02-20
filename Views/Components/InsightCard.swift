import SwiftUI

/// Card displaying a single health insight with severity, recommendation, and data
struct InsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: icon + title + badges
            HStack(alignment: .top) {
                Image(systemName: insight.metric.systemImageName)
                    .font(.title3)
                    .foregroundStyle(insight.metric.category.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 6) {
                        SeverityBadge(severity: insight.severity)
                        TrendBadge(direction: insight.trend)

                        // Category badge for new insight types
                        if insight.category != .anomaly && insight.category != .trend {
                            Text(insight.category.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(insight.category.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(insight.category.color)
                        }
                    }
                }

                Spacer()
            }

            // Summary
            Text(insight.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Recommendation
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)

                Text(insight.recommendation)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview {
    let insights = SampleDataProvider.generateSampleInsights()
    ScrollView {
        VStack(spacing: 12) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
        .padding()
    }
}
