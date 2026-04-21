import SwiftUI

/// Compact tappable card for correlation / sleep-performance / weekly-pattern insights
struct PatternCard: View {
    let insight: Insight
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            AppAnalytics.shared.trackInsightTapped(
                category: insight.category.rawValue,
                severity: insight.severity.rawValue,
                metric: insight.metric.rawValue,
                screen: .home
            )
            onTap()
        }) {
            HStack(spacing: 0) {
                // Left accent bar. category colour
                RoundedRectangle(cornerRadius: DS.accentRadius)
                    .fill(insight.category.color)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 12) {
                    // Category icon
                    Image(systemName: insight.category.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(insight.category.color, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(insight.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // Category badge
                        HStack(spacing: 6) {
                            Text(insight.category.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(insight.category.color.opacity(DS.badgeBg), in: Capsule())

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: insight.category.color)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.category.displayName) insight: \(insight.title)")
        .accessibilityHint("View metric details")
        .accessibilityAddTraits(.isButton)
    }
}
