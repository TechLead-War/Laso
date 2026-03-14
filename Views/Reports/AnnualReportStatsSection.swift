import SwiftUI

struct AnnualReportStatsSection: View {
    let annualStats: AnnualStats

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.annualStats, icon: "chart.bar.fill", color: .blue)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                annualStatCell(
                    value: "\(annualStats.totalActiveDays)",
                    label: Copy.Reports.activeDays,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                annualStatCell(
                    value: AnnualReportHelpers.formatHours(annualStats.totalExerciseHours),
                    label: Copy.Reports.exerciseHours,
                    icon: "flame.fill",
                    color: .orange
                )
                annualStatCell(
                    value: AnnualReportHelpers.formatDistance(annualStats.totalDistanceKm),
                    label: Copy.Reports.distanceKm,
                    icon: "figure.walk",
                    color: .cyan
                )
                annualStatCell(
                    value: AnnualReportHelpers.formatSteps(annualStats.averageDailySteps),
                    label: Copy.Reports.avgStepsPerDay,
                    icon: "shoe.fill",
                    color: .purple
                )
                annualStatCell(
                    value: String(format: "%.1fh", annualStats.averageSleepHours),
                    label: Copy.Reports.avgSleep,
                    icon: "bed.double.fill",
                    color: .indigo
                )
                annualStatCell(
                    value: "\(Int(annualStats.sleepOver7HoursPercent))%",
                    label: Copy.Reports.sevenPlusHourNights,
                    icon: "moon.stars.fill",
                    color: .blue
                )
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
    }

    private func annualStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 8))

            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
