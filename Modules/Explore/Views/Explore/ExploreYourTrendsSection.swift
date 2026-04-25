import SwiftUI

struct ExploreYourTrendsSection: View {
    let trendMetrics: [TrendMetricItem]
    @Binding var trendTimeframe: Int
    let onMetricTapped: (TrendMetricItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack {
                Text(Copy.Explore.yourTrends)
                    .font(DS.Typography.headline)
                Spacer()
            }
            .padding(.horizontal, DS.screenPadding)

            Picker(Copy.Explore.trendPeriod, selection: $trendTimeframe) {
                Text("7D").tag(7)
                Text("30D").tag(30)
                Text("90D").tag(90)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Trend timeframe")
            .accessibilityValue("\(trendTimeframe) days")
            .accessibilityHint("Switches between 7-day, 30-day, and 90-day views")
            .padding(.horizontal, DS.screenPadding)
            .onChange(of: trendTimeframe) { oldValue, newValue in
                AppAnalytics.shared.trackBlockTap(
                    title: "\(newValue)D",
                    type: .exploreTrendTimeframeChanged,
                    screen: .explore,
                    metadata: ["from_days": oldValue, "to_days": newValue]
                )
            }

            ForEach(trendMetrics.prefix(8)) { item in
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: item.metric.displayName,
                        type: .exploreTrendMetric,
                        screen: .explore,
                        metadata: [
                            "metric_id": item.metric.rawValue,
                            "trend_direction": item.trend.direction.rawValue,
                            "timeframe_days": trendTimeframe
                        ]
                    )
                    onMetricTapped(item)
                } label: {
                    trendMetricRow(item)
                }
                .buttonStyle(.dsPress)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.metric.displayName) trend")
                .accessibilityValue(item.rateLabel)
                .accessibilityHint("Opens detailed metric history")
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func trendMetricRow(_ item: TrendMetricItem) -> some View {
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: item.metric.systemImageName)
                .font(DS.Typography.caption)
                .foregroundStyle(item.metric.category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(item.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(item.metric.displayName)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textPrimary)

                Text(item.rateLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer()

            SparklineView(
                values: item.sparklineValues,
                color: item.trendColor
            )
            .frame(width: 52, height: 24)

            HStack(spacing: DS.space1) {
                Image(systemName: item.trend.direction.systemImageName)
                    .font(DS.Typography.caption2Semibold)
                Text(TrendAnalyzer.formattedPercentChange(item.trend.weekOverWeekChange))
                    .font(DS.Typography.captionSemibold.monospacedDigit())
                    .postHogMask()
            }
            .foregroundStyle(item.trendColor)
            .frame(minWidth: 64, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption2Semibold)
                .foregroundStyle(AppColour.textTertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }
}

struct TrendMetricItem: Identifiable {
    var id: String { metric.rawValue }
    let metric: HealthMetric
    let trend: TrendAnalyzer.TrendResult
    let sparklineSamples: [MetricSample]

    var sparklineValues: [Double] {
        let samples = sparklineSamples
        guard samples.count > 2 else { return samples.map(\.value) }
        let step = max(1, samples.count / 12)
        var values: [Double] = []
        for i in stride(from: 0, to: samples.count, by: step) {
            values.append(samples[i].value)
        }
        if let last = samples.last?.value, values.last != last {
            values.append(last)
        }
        return values
    }

    var trendColor: Color {
        switch trend.direction {
        case .improving: return AppColour.success
        case .declining: return AppColour.danger
        case .stable: return AppColour.textSecondary
        }
    }

    var rateLabel: String {
        let rate = trend.rateOfChange
        switch trend.direction {
        case .improving: return "\(rate.displayLabel.capitalized) improvement"
        case .declining: return "\(rate.displayLabel.capitalized) decline"
        case .stable: return "Holding steady"
        }
    }
}

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = maxVal - minVal
            let safeRange = range > 0 ? range : 1

            Path { path in
                for (index, value) in values.enumerated() {
                    let x = w * CGFloat(index) / CGFloat(max(1, values.count - 1))
                    let y = h - (h * CGFloat((value - minVal) / safeRange))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
