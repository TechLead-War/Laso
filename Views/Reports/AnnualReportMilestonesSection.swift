import SwiftUI

struct AnnualReportMilestonesSection: View {
    let records: [AnnualRecord]
    let streakRecord: Int
    let totalInsightsGenerated: Int
    let totalDataPointsAnalyzed: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.milestonesAndRecords, icon: "trophy.fill", color: .orange)

            ForEach(records) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.icon)
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.subheadline.weight(.semibold))
                        Text(record.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(DS.cardPadding)
                .cardStyle()
            }

            HStack(spacing: 0) {
                milestoneStat(value: "\(streakRecord)", label: Copy.Reports.bestStreak, icon: "flame.fill")
                Divider().frame(height: DS.dividerHeight)
                milestoneStat(value: AnnualReportHelpers.formatCount(totalInsightsGenerated), label: Copy.Explore.insights, icon: "lightbulb.fill")
                Divider().frame(height: DS.dividerHeight)
                milestoneStat(value: AnnualReportHelpers.formatCount(totalDataPointsAnalyzed), label: Copy.Explore.dataPoints, icon: "chart.dots.scatter")
            }
            .padding(.vertical, 12)
            .cardStyle()
        }
    }

    private func milestoneStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
