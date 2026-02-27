import SwiftUI

/// Action-first insight card — leads with what to do, not what happened
struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(spacing: 12) {
            // Metric icon
            Image(systemName: insight.metric.systemImageName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(insight.metric.category.color, in: Circle())

            // Action + context
            VStack(alignment: .leading, spacing: 4) {
                Text(actionText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(insight.metric.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(insight.severity.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(insight.severity.color)
                }
            }

        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension InsightCard {
    /// First sentence of the recommendation — the actionable part
    var actionText: String {
        let rec = insight.recommendation
        // Find the first "." that ends a real sentence, not a numbered prefix like "1."
        var searchStart = rec.startIndex
        while searchStart < rec.endIndex {
            guard let dotIndex = rec[searchStart...].firstIndex(of: ".") else { break }
            let prefix = rec[rec.startIndex...dotIndex]
            let beforeDot = rec[searchStart..<dotIndex]
            // Skip if this is just a number (e.g., "1." in a numbered list)
            if beforeDot.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) {
                searchStart = rec.index(after: dotIndex)
                continue
            }
            return String(prefix)
        }
        return rec
    }
}

#Preview {
    let insights = SampleDataProvider.generateSampleInsights()
    ScrollView {
        VStack(spacing: 8) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
