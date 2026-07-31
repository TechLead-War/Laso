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
                Text(Copy.Explore.x7d).tag(7)
                Text(Copy.Explore.x30d).tag(30)
                Text(Copy.Explore.x90d).tag(90)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Copy.Explore.trendTimeframeLabel)
            .accessibilityValue(Copy.Explore.daysValue(trendTimeframe))
            .accessibilityHint(Copy.Explore.switchesBetween7Day30DayHint)
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
                let verdict = item.verdict
                Button {
                    // block_tapped for this row is emitted by the owner of
                    // `onMetricTapped`, which knows the timeframe and the
                    // period change. Emitting here too doubled the CTR.
                    onMetricTapped(item)
                } label: {
                    trendMetricRow(item, verdict: verdict)
                }
                .buttonStyle(.dsPress)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Copy.Explore.trendLabel(item.metric.displayName))
                .accessibilityValue(verdict.map { "\($0.label), \($0.rangeText)" } ?? item.rateLabel)
                .accessibilityHint(Copy.Explore.opensDetailedMetricHistoryHint)
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }

    private func trendMetricRow(_ item: TrendMetricItem, verdict: MetricVerdict?) -> some View {
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

                if let verdict {
                    Text(verdict.label)
                        .font(DS.Typography.caption)
                        .foregroundStyle(verdict.color)
                } else {
                    Text(item.rateLabel)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }

            Spacer()

            SparklineView(
                values: item.sparklineValues,
                color: item.trendColor
            )
            .frame(width: 52, height: 24)

            HStack(spacing: DS.space1) {
                Image(systemName: TrendDirection.arrowImageName(forChange: item.trend.weekOverWeekChange))
                    .font(DS.Typography.caption2Semibold)
                Text(TrendAnalyzer.formattedPercentChange(item.trend.weekOverWeekChange))
                    .font(DS.Typography.captionSemibold.monospacedDigit())
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

/// A reference so the memo survives `TrendMetricItem` being copied by value into every
/// SwiftUI body pass. `isComputed` is separate because a nil verdict is a real answer
/// (no usable band) and must be cached too, not retried on every render.
private final class TrendVerdictCache {
    var isComputed = false
    var value: MetricVerdict?
}

struct TrendMetricItem: Identifiable {
    var id: String { metric.rawValue }
    let metric: HealthMetric
    let trend: TrendAnalyzer.TrendResult
    let sparklineSamples: [MetricSample]

    /// Shared by every copy of this item, so the verdict is paid for once per item
    /// instead of once per body pass. See `verdict` for the measured cost.
    private let verdictCache = TrendVerdictCache()

    /// Spelled out because the memberwise initializer's access level is tied to the
    /// access level of every stored property, and `verdictCache` is private.
    init(metric: HealthMetric, trend: TrendAnalyzer.TrendResult, sparklineSamples: [MetricSample]) {
        self.metric = metric
        self.trend = trend
        self.sparklineSamples = sparklineSamples
    }

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

    /// The row only carries its own samples, so the band is built from the visible window
    /// with the same calculator the rest of the app uses.
    ///
    /// Memoised: re-wrapping the window in a `MetricTimeSeries` re-sorts, re-filters and
    /// re-walks it before the baseline calculator even starts, measured at 0.35 ms per
    /// Explore body pass over the visible rows at 30 days and 1.09 ms at 90 days, and the
    /// section's body runs 9 times per refresh burst. The cache is a reference so it
    /// survives SwiftUI copying the struct into each pass. Never stale: a data refresh
    /// rebuilds the items, and a rebuilt item carries a fresh empty cache.
    ///
    /// Main-thread only, which is where the view model builds these and where SwiftUI
    /// reads them. Nothing here is safe to call off the main thread.
    var verdict: MetricVerdict? {
        if verdictCache.isComputed { return verdictCache.value }
        let computed = Self.computeVerdict(metric: metric, samples: sparklineSamples)
        verdictCache.value = computed
        verdictCache.isComputed = true
        return computed
    }

    /// Pure over value types, so the warmer can run it off the main thread.
    static func computeVerdict(metric: HealthMetric, samples: [MetricSample]) -> MetricVerdict? {
        MetricVerdict.make(
            metric: metric,
            series: MetricTimeSeries(metric: metric, samples: samples)
        )
    }

    /// Lets the view model pre-fill the memo after building items off the render
    /// path. Rows in the lazy stack first render mid-scroll, and computing the
    /// verdict there put baseline maths inside a scroll frame.
    func seedVerdict(_ value: MetricVerdict?) {
        verdictCache.value = value
        verdictCache.isComputed = true
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
