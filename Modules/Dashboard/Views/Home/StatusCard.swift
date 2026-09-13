import SwiftUI
import Charts

/// How the person is doing today, in words: two chips, one headline, one
/// sentence, and two weeks of readiness against their own usual. No ring and
/// no big number; the sentence carries the score.
struct StatusCard: View {
    let status: DailyBrief.Status

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            HStack(spacing: DS.space2) {
                ForEach(Array(status.chips.enumerated()), id: \.offset) { _, chip in
                    Text(chip.text)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(Self.chipColor(chip.tone))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Self.chipBackground(chip.tone), in: Capsule())
                }
            }

            Text(status.headline)
                .font(DS.Typography.title2)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(status.sentence)
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if status.sparkline.count >= 2 {
                ReadinessSparkline(points: status.sparkline, band: status.band, latest: status.readiness)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.statusCard")
    }

    private static func chipColor(_ tone: DailyBrief.Tone) -> Color {
        switch tone {
        case .good: return AppColour.scoreGood
        case .fair: return AppColour.scoreFair
        case .poor: return AppColour.scorePoor
        case .neutral: return AppColour.textSecondary
        }
    }

    private static func chipBackground(_ tone: DailyBrief.Tone) -> Color {
        tone == .neutral ? AppColour.surfaceSubtle : chipColor(tone).opacity(DS.badgeBg)
    }
}

/// Two weeks of readiness with the usual band behind it. The captions name
/// the ends of the line so the chart needs no axes.
private struct ReadinessSparkline: View {
    let points: [TrendSparkPoint]
    let band: PersonalBand?
    let latest: Int?

    private static let height: CGFloat = 70

    private var yRange: ClosedRange<Double> {
        let values = points.map(\.value)
        var low = values.min() ?? 0
        var high = values.max() ?? 1
        if let band {
            low = Swift.min(low, band.low)
            high = Swift.max(high, band.high)
        }
        let pad = Swift.max(high - low, 1) * 0.15
        return (low - pad)...(high + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Chart {
                if let band, let first = points.first, let last = points.last {
                    RectangleMark(
                        xStart: .value("Start", first.date),
                        xEnd: .value("End", last.date),
                        yStart: .value("Usual low", band.low),
                        yEnd: .value("Usual high", band.high)
                    )
                    .foregroundStyle(AppColour.chartBandFill)
                    .annotation(position: .overlay, alignment: .trailing) {
                        Text(Copy.DailyBrief.Status.sparkUsual)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(AppColour.scoreGood)
                            .padding(.trailing, DS.space1)
                    }
                }

                ForEach(points) { point in
                    LineMark(x: .value("Day", point.date), y: .value("Readiness", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppColour.textPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                if let last = points.last {
                    PointMark(x: .value("Day", last.date), y: .value("Readiness", last.value))
                        .symbolSize(60)
                        .foregroundStyle(AppColour.scoreGood)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: yRange)
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(height: Self.height)

            HStack {
                Text(Copy.DailyBrief.Status.sparkStart)
                Spacer()
                if let latest {
                    Text(Copy.DailyBrief.Status.sparkToday(latest))
                }
            }
            .font(DS.Typography.caption2)
            .foregroundStyle(AppColour.textTertiary)
        }
        .accessibilityHidden(true)
    }
}
