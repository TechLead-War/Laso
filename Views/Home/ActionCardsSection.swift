import SwiftUI

/// Section wrapper for the compact actionable recommendation cards (max 3)
struct ActionCardsSection: View {
    let insights: [Insight]
    let onTapInsight: (HealthMetric) -> Void

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Needs Attention")
                        .font(.headline)

                    Spacer()

                    if insights.count > 0 {
                        Text("\(insights.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(alertCountColor, in: Capsule())
                    }
                }
                .padding(.horizontal)

                ForEach(Array(insights.prefix(3)), id: \.id) { insight in
                    ActionCard(insight: insight) {
                        onTapInsight(insight.metric)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var alertCountColor: Color {
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
