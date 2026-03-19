import SwiftUI

struct ExploreCorrelationsSection: View {
    let correlations: [HealthCorrelation]
    let onSeeAllTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Copy.Explore.connections)
                    .font(.headline)

                Spacer()

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "See All Correlations",
                        type: .exploreSeeAllCorrelations,
                        screen: .explore,
                        metadata: ["correlations_count": correlations.count]
                    )
                    onSeeAllTapped()
                } label: {
                    HStack(spacing: 4) {
                        Text(Copy.Explore.seeAll)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ForEach(Array(correlations.prefix(2))) { correlation in
                correlationCard(correlation)
                    .padding(.horizontal)
            }
        }
    }

    private func correlationCard(_ c: HealthCorrelation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: c.metricA.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricA.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricA.category.color.opacity(0.12), in: Circle())

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: c.metricB.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricB.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricB.category.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(c.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(c.strengthLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}
