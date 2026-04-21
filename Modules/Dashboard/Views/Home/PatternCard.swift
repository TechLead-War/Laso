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
                        .font(.system(size: 20.4).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(insight.category.color, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 18).weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(insight.summary)
                            .font(.system(size: 14.4))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // Category badge
                        HStack(spacing: 6) {
                            Text(insight.category.displayName)
                                .font(.system(size: 13.2).weight(.medium))
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(insight.category.color.opacity(DS.badgeBg), in: Capsule())

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13.2).weight(.semibold))
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
