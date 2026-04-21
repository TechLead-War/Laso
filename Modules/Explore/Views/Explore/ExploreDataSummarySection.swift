import SwiftUI

struct ExploreDataSummarySection: View {
    let metricsTracked: Int
    let totalDataPoints: Int
    let daysOfData: Int
    let insightCount: Int

    var body: some View {
        HStack(spacing: 0) {
            dataStat(value: "\(metricsTracked)", label: Copy.Explore.metrics)
            Divider().frame(height: DS.dividerHeight)
            dataStat(value: formatDataPoints(totalDataPoints), label: Copy.Explore.dataPoints)
            if daysOfData > 0 {
                Divider().frame(height: DS.dividerHeight)
                dataStat(value: "\(daysOfData)", label: daysOfData == 1 ? Copy.Explore.day : Copy.Explore.days)
            }
            Divider().frame(height: DS.dividerHeight)
            dataStat(value: "\(insightCount)", label: Copy.Explore.insights)
        }
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.cardRadius))
    }

    private func dataStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDataPoints(_ count: Int) -> String {
        if count >= 10_000 { return "\(count / 1000)k" }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }
}
