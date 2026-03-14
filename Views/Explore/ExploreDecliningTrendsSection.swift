import SwiftUI

struct ExploreDecliningTrendsSection: View {
    let decliningHighlights: [DashboardViewModel.HistoricalHighlight]
    let onHighlightTapped: (DashboardViewModel.HistoricalHighlight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Explore.decliningTrends)
                .font(.headline)
                .padding(.horizontal)

            ForEach(decliningHighlights) { highlight in
                Button {
                    onHighlightTapped(highlight)
                } label: {
                    historicalCard(highlight)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private func historicalCard(_ highlight: DashboardViewModel.HistoricalHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlight.metric.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text(highlight.typeLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Color.orange.opacity(DS.badgeBg), in: Capsule())
                }

                Text(highlight.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(highlight.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}
