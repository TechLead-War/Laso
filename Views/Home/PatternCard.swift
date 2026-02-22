import SwiftUI

/// Compact tappable card for correlation / sleep-performance / weekly-pattern insights
struct PatternCard: View {
    let insight: Insight
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            AppAnalytics.shared.trackBlockTap(title: insight.title, type: .patternCard, screen: .home)
            onTap()
        }) {
            HStack(spacing: 0) {
                // Left accent bar — category colour
                RoundedRectangle(cornerRadius: 2)
                    .fill(insight.category.color)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 12) {
                    // Category icon
                    Image(systemName: insight.category.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(insight.category.color, in: Circle())

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(insight.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        // Category badge
                        HStack(spacing: 6) {
                            Text(insight.category.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(insight.category.color.opacity(0.12), in: Capsule())

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 14)
                .padding(.vertical, 10)
            }
            .background(
                insight.category.color.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(insight.category.color.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.category.displayName) insight: \(insight.title)")
        .accessibilityHint("View metric details")
        .accessibilityAddTraits(.isButton)
    }
}
