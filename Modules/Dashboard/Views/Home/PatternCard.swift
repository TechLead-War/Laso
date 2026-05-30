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
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(insight.category.color, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(insight.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(insight.summary)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)

                        // Category badge
                        HStack(spacing: DS.space1) {
                            Text(insight.category.displayName)
                                .font(DS.Typography.captionMedium)
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(insight.category.color.opacity(DS.badgeBg), in: Capsule())

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                    }
                }
                .padding(.leading, DS.accentLeading)
                .padding(.trailing, DS.accentTrailing)
                .padding(.vertical, DS.accentVertical)
            }
            .cardStyle(tint: insight.category.color)
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.insightLabel(insight.category.displayName, insight.title))
        .accessibilityHint(Copy.Home.viewMetricDetailsHint)
        .accessibilityAddTraits(.isButton)
    }
}
