import SwiftUI

struct AnnualReportCategorySection: View {
    let categoryScores: [AnnualCategoryScore]

    private var mostImprovedCategory: AnnualCategoryScore? {
        categoryScores.first(where: { $0.trend == .improving })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.categorySummary, icon: "square.grid.2x2.fill", color: .purple)

            VStack(spacing: 0) {
                let sorted = categoryScores.sorted { $0.averageScore < $1.averageScore }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    categoryRow(item, isMostImproved: mostImprovedCategory?.category == item.category)

                    if index < sorted.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .cardStyle()

            if let improved = mostImprovedCategory {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(Color.yellow.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Reports.mostImproved)
                            .font(.subheadline.weight(.semibold))
                        Text(Copy.Reports.mostImprovedDetail(improved.category.displayName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HealthScoreRing(
                        score: improved.averageScore,
                        label: "",
                        size: 36,
                        lineWidth: 4
                    )
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .yellow)
            }
        }
    }

    private func categoryRow(_ item: AnnualCategoryScore, isMostImproved: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.category.systemImageName)
                .font(.title3)
                .foregroundStyle(item.category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.category.displayName)
                        .font(.body.weight(.medium))

                    if isMostImproved {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                TrendBadge(direction: item.trend)
            }

            Spacer()

            HealthScoreRing(
                score: item.averageScore,
                label: "",
                size: 36,
                lineWidth: 4
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
