import SwiftUI

struct ExploreEmptyStateSection: View {
    let hasAnyHealthData: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: hasAnyHealthData ? "chart.line.text.clipboard" : "heart.text.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Explore.yourHealthScore)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(hasAnyHealthData ? Copy.Explore.almostThere : Copy.Explore.noDataYet)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                Text(hasAnyHealthData
                     ? Copy.Explore.almostThereBody
                     : Copy.Explore.noDataYetBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
