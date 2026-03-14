import SwiftUI

struct AnnualReportLookingAheadSection: View {
    let year: Int
    let categoryScores: [AnnualCategoryScore]
    let focusAreas: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.lookingAhead(year + 1), icon: "sparkles", color: .cyan)

            let weakest = categoryScores.sorted { $0.averageScore < $1.averageScore }.prefix(3)

            if !weakest.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Copy.Reports.biggestOpportunities)
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(weakest)) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.category.systemImageName)
                                .font(.caption)
                                .foregroundStyle(item.category.color)
                                .frame(width: 28, height: 28)
                                .background(item.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.displayName)
                                    .font(.subheadline.weight(.medium))
                                Text(Copy.Reports.averageScoreMessage(score: item.averageScore, message: AnnualReportHelpers.opportunityMessage(for: item.averageScore)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(item.averageScore)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(DS.scoreColor(item.averageScore))
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .cyan)
            }

            if !focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Copy.Reports.suggestedFocusAreas)
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(focusAreas.enumerated()), id: \.offset) { index, area in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.cyan, in: Circle())

                            Text(area)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
            }

            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text(Copy.Reports.heresTo(year + 1))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }
}
