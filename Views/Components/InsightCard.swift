import SwiftUI

/// Action-first insight card. leads with what to do, not what happened
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

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

                // Causation context (only when data exists)
                if let becauseLine = causationLine {
                    Text(becauseLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let basisLine = dataBasisLine {
                    Text(basisLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

        }
        .frame(minHeight: 72, alignment: .center)
        .padding(DS.cardPadding)
        .cardStyle()
    }
}

private extension InsightCard {
    /// First sentence of the recommendation. the actionable part
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

    /// "Because" line explaining root cause, if context data exists
    var causationLine: String? {
        guard let context = insight.context else { return nil }
        if let rootMetric = context.rootCauseMetric {
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

    /// Data basis line showing sample size or confidence, if available
    var dataBasisLine: String? {
        guard let context = insight.context else { return nil }
        if let dayCount = context.dataPointCount, dayCount > 0 {
            return Copy.Insights.InsightCard.basedOnDays(dayCount)
        }
        if let confidence = context.confidenceLevel {
            let level: String = if confidence >= 0.8 {
                "High"
            } else if confidence >= 0.5 {
                "Moderate"
            } else {
                "Early"
            }
            return Copy.Insights.InsightCard.confidenceQualifier(level)
        }
        return nil
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
