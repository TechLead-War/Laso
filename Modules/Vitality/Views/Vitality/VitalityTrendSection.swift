import SwiftUI
import Charts

struct VitalityTrendSection: View {
    let scorer: VitalityScorer

    private var paceTint: Color { vitalityPaceTint(for: scorer) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            vitalitySectionHeader(icon: "chart.xyaxis.line", title: Copy.Vitality.ninetyDayTrend)

            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    RuleMark(y: .value("Chronological Age", Double(scorer.chronologicalAge)))
                        .foregroundStyle(AppColour.danger.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))

                    ForEach(Array(scorer.history.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", Double(scorer.chronologicalAge)),
                            yEnd: .value("Age", Double(point.age))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyFillColor)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Age", Double(point.age))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    if let latest = scorer.history.last {
                        PointMark(
                            x: .value("Latest Date", latest.date),
                            y: .value("Latest Age", Double(latest.age))
                        )
                        .symbolSize(42)
                        .foregroundStyle(historyLineColor)
                    }
                }
                .chartYScale(domain: chartYRange)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 15)) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let y = value.as(Double.self) {
                                Text("\(Int(y))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 196)

                HStack(spacing: 0) {
                    trendStat(title: Copy.Vitality.ninetyDayChange, value: historyChangeText, color: historyChangeColor)

                    Divider()
                        .frame(height: DS.dividerHeight)
                        .padding(.horizontal, DS.space3)

                    trendStat(title: Copy.Vitality.pace, value: scorer.paceLabel, color: paceTint)

                    Divider()
                        .frame(height: DS.dividerHeight)
                        .padding(.horizontal, DS.space3)

                    trendStat(title: Copy.Vitality.current, value: Copy.Vitality.ageLabel(scorer.vitalityAge), color: historyLineColor)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: historyLineColor)
            .padding(.horizontal)
        }
    }

    private func trendStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chartYRange: ClosedRange<Double> {
        guard !scorer.history.isEmpty else {
            return Double(scorer.chronologicalAge - 8)...Double(scorer.chronologicalAge + 8)
        }

        let values = scorer.history.map { Double($0.age) } + [Double(scorer.chronologicalAge)]
        let minValue = (values.min() ?? Double(scorer.chronologicalAge)) - 2
        let maxValue = (values.max() ?? Double(scorer.chronologicalAge)) + 2
        return minValue...maxValue
    }

    private var historyLineColor: Color {
        paceTint
    }

    private var historyFillColor: Color {
        paceTint.opacity(0.16)
    }

    private var historyChangeText: String {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return "--"
        }

        let change = last - first
        if change > 0 { return "+\(change)y" }
        if change < 0 { return "\(change)y" }
        return "0y"
    }

    private var historyChangeColor: Color {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return .secondary
        }
        return vitalityDeltaColor(for: last - first)
    }
}
