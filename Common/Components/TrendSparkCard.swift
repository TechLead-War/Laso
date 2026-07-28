import SwiftUI
import Charts

struct TrendSparkPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

/// One reading against the person's own usual range, with the recent days that
/// produced it. Shared so Stress, Strain and Cognitive all read the same way.
struct TrendSparkCard: View {
    let icon: String
    let title: String
    let value: String
    let points: [TrendSparkPoint]
    /// nil when there is not enough history to claim a usual range. The card
    /// then shows the line alone rather than a band the data cannot support.
    let band: PersonalBand?
    let tint: Color

    /// Fewest recorded days before the card is worth drawing at all.
    static let minimumPoints = 7

    private var status: TrendBandStatus? {
        guard let band, let latest = points.last else { return nil }
        return band.status(for: latest.value)
    }

    private var statusText: String {
        guard let status else { return Copy.Common.Trend.buildingUsualRange }
        switch status {
        case .belowUsual: return Copy.Common.Trend.belowUsual
        case .usual: return Copy.Common.Trend.inUsualRange
        case .aboveUsual: return Copy.Common.Trend.aboveUsual
        }
    }

    private var statusIcon: String {
        guard let status else { return "hourglass" }
        switch status {
        case .belowUsual: return "arrow.down.circle.fill"
        case .usual: return "checkmark.circle.fill"
        case .aboveUsual: return "arrow.up.circle.fill"
        }
    }

    private var statusColor: Color {
        guard let status else { return AppColour.textSecondary }
        switch status {
        case .usual: return AppColour.success
        case .belowUsual, .aboveUsual: return AppColour.warning
        }
    }

    /// Padded so the line never touches the card edge, and always wide enough
    /// that a flat run of days does not stretch into a fake zigzag.
    private var yRange: ClosedRange<Double> {
        let values = points.map(\.value)
        var low = values.min() ?? 0
        var high = values.max() ?? 1
        if let band {
            low = Swift.min(low, band.low)
            high = Swift.max(high, band.high)
        }
        let span = Swift.max(high - low, 1)
        let padding = span * 0.15
        return (low - padding)...(high + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            HStack(spacing: DS.space2) {
                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(DS.Typography.subheadlineSemibold)
                Spacer()
            }

            HStack(alignment: .center, spacing: DS.space3) {
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(value)
                        .font(DS.Typography.displayS)
                        .postHogMask()

                    HStack(spacing: DS.space1) {
                        Image(systemName: statusIcon)
                            .font(DS.Typography.caption2)
                        Text(statusText)
                            .font(DS.Typography.caption2Medium)
                    }
                    .foregroundStyle(statusColor)
                }

                Spacer(minLength: DS.space3)

                sparkline
                    .frame(width: 132, height: 56)
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(Copy.Common.Trend.accessibilityValue(value: value, status: statusText)))
    }

    private var sparkline: some View {
        Chart {
            if let band, let first = points.first, let last = points.last {
                RectangleMark(
                    xStart: .value("Start", first.date),
                    xEnd: .value("End", last.date),
                    yStart: .value("Usual low", band.low),
                    yEnd: .value("Usual high", band.high)
                )
                .foregroundStyle(AppColour.chartBandFill)
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Day", point.date),
                    y: .value("Value", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            if let latest = points.last {
                PointMark(
                    x: .value("Day", latest.date),
                    y: .value("Value", latest.value)
                )
                .symbolSize(30)
                .foregroundStyle(tint)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yRange)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}

/// A "Trends" block of one or more spark cards, so every detail screen puts
/// this section together the same way.
struct TrendSection<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.Common.Trend.sectionTitle)
                .font(DS.Typography.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
