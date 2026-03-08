import SwiftUI

/// Section wrapper for prescriptive action cards on the Home screen.
///
/// Displays up to 2 cards in a direct, prescriptive format:
/// bold action -> body-focused reason -> expected benefit.
struct ActionCardsSection: View {
    let insights: [Insight]
    let onTapInsight: (HealthMetric) -> Void

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Your Next Move")
                        .font(.headline)

                    Spacer()

                    if insights.count > 0 {
                        Text("\(insights.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(urgencyColor, in: Capsule())
                    }
                }
                .padding(.horizontal)

                ForEach(Array(insights.prefix(2)), id: \.id) { insight in
                    ActionCard(insight: insight) {
                        AppAnalytics.shared.trackInsightTapped(
                            category: insight.category.rawValue,
                            severity: insight.severity.rawValue,
                            metric: insight.metric.rawValue,
                            screen: .home
                        )
                        onTapInsight(insight.metric)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    /// Urgency color based on the most severe insight present
    private var urgencyColor: Color {
        if insights.contains(where: { $0.severity == .critical }) {
            return .red
        } else if insights.contains(where: { $0.severity == .warning }) {
            return .orange
        }
        return .blue
    }
}

#Preview {
    ActionCardsSection(
        insights: SampleDataProvider.generateSampleInsights(),
        onTapInsight: { _ in }
    )
}
