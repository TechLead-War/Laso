import SwiftUI

struct AnnualReportDiscoveriesSection: View {
    let discoveries: [AnnualDiscovery]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.topDiscoveries, icon: "lightbulb.fill", color: .yellow)

            ForEach(Array(discoveries.prefix(5))) { discovery in
                discoveryCard(discovery)
            }
        }
    }

    private func discoveryCard(_ discovery: AnnualDiscovery) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: discovery.category.systemImageName)
                .font(.caption)
                .foregroundStyle(discovery.category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(discovery.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(discovery.title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text(AnnualReportHelpers.monthAbbreviation(discovery.month))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }

                Text(discovery.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: discovery.category.color)
    }
}
