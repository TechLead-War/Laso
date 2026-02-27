import SwiftUI

/// Compact insight card for the Home screen — visual-first, minimal text.
/// Shows metric identity, severity, and a brief action in a condensed layout.
struct ActionCard: View {
    let insight: Insight
    let onTap: () -> Void

    private var categoryColor: Color {
        insight.metric.category.color
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 12) {
                    // Metric icon in colored circle
                    Image(systemName: insight.metric.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(categoryColor, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Metric name + current value
                        HStack {
                            Text(insight.metric.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(formattedCurrent)
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.primary)
                        }

                        // Short action text
                        Text(shortAction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // Single status line
                        HStack(spacing: 6) {
                            SeverityBadge(severity: insight.severity)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .background(
                categoryColor.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(categoryColor.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.metric.displayName), \(insight.severity == .critical ? "critical" : insight.severity == .warning ? "warning" : "info"), \(shortAction)")
        .accessibilityValue("\(formattedCurrent), \(insight.trend == .improving ? "improving" : insight.trend == .declining ? "declining" : "stable")")
        .accessibilityHint("View details and recommendations")
        .accessibilityAddTraits(.isButton)
    }

    /// First sentence of the recommendation, truncated
    private var shortAction: String {
        let rec = insight.recommendation
        var searchStart = rec.startIndex
        while searchStart < rec.endIndex {
            guard let dotIndex = rec[searchStart...].firstIndex(of: ".") else { break }
            let beforeDot = rec[searchStart..<dotIndex]
            if beforeDot.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) {
                searchStart = rec.index(after: dotIndex)
                continue
            }
            return String(rec[rec.startIndex...dotIndex])
        }
        return rec
    }

    private var formattedCurrent: String {
        let v = insight.currentValue
        let formatted: String
        if v >= 1000 {
            formatted = String(format: "%.0f", v)
        } else if v >= 10 {
            formatted = String(format: "%.1f", v)
        } else {
            formatted = String(format: "%.1f", v)
        }
        return "\(formatted) \(insight.metric.unit)"
    }
}

/// Inline badge showing deviation percentage from baseline
struct DeviationBadge: View {
    let percent: Double

    var body: some View {
        let arrow = percent >= 0 ? "↑" : "↓"
        let formatted = String(format: "%.0f%%", abs(percent))

        Text("\(arrow)\(formatted)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(percent >= 0 ? .red : .blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (percent >= 0 ? Color.red : Color.blue).opacity(0.1),
                in: Capsule()
            )
    }
}

#Preview {
    let insights = SampleDataProvider.generateSampleInsights()
    ScrollView {
        VStack(spacing: 10) {
            ForEach(insights.prefix(3)) { insight in
                ActionCard(insight: insight, onTap: {})
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
