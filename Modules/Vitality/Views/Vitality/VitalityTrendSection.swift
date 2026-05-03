import SwiftUI
import Charts

struct VitalityTrendSection: View {
    let scorer: VitalityScorer

    private var paceTint: Color { vitalityPaceTint(for: scorer) }

    @State private var selectedTrendDate: Date?

    private var selectedTrendPoint: (date: Date, age: Int)? {
        guard let selectedTrendDate, !scorer.history.isEmpty else { return nil }
        return scorer.history.min(by: { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedTrendDate)) < abs(rhs.date.timeIntervalSince(selectedTrendDate))
        })
    }

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
                        .accessibilityHidden(true)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Age", Double(point.age))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        // Per-mark VoiceOver readout so users can
                        // navigate each daily vitality-age point.
                        .accessibilityLabel(Text(point.date.formatted(date: .abbreviated, time: .omitted)))
                        .accessibilityValue(Text(Copy.Vitality.chartPointAccessibilityValue(age: point.age)))
                    }

                    if let latest = scorer.history.last {
                        PointMark(
                            x: .value("Latest Date", latest.date),
                            y: .value("Latest Age", Double(latest.age))
                        )
                        .symbolSize(42)
                        .foregroundStyle(historyLineColor)
                    }

                    if let selected = selectedTrendPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(historyLineColor.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                        PointMark(
                            x: .value("Selected", selected.date),
                            y: .value("Age", Double(selected.age))
                        )
                        .foregroundStyle(.white)
                        .symbolSize(70)

                        PointMark(
                            x: .value("Selected", selected.date),
                            y: .value("Age", Double(selected.age))
                        )
                        .foregroundStyle(historyLineColor)
                        .symbolSize(28)
                    }
                }
                .chartXSelection(value: $selectedTrendDate)
                .chartYScale(domain: chartYRange)
                // Chart-level VoiceOver summary.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(Copy.Vitality.chartAccessibilityLabel(dayCount: scorer.history.count)))
                .accessibilityValue(Text(vitalityChartAccessibilityValue))
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
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geometry[plotFrame].origin
                                        let x = value.location.x - origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedTrendDate = date
                                        }
                                    }
                            )
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                let x = location.x - origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    if let current = selectedTrendDate,
                                       Date.cal.isDate(current, inSameDayAs: date) {
                                        selectedTrendDate = nil
                                    } else {
                                        selectedTrendDate = date
                                    }
                                }
                            }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let selected = selectedTrendPoint {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(selected.age)")
                                    .font(.callout.weight(.bold).monospacedDigit())
                                    .foregroundStyle(historyLineColor)
                                Text("yrs")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            let delta = selected.age - scorer.chronologicalAge
                            if delta != 0 {
                                Text(delta > 0 ? "+\(delta) vs actual" : "\(delta) vs actual")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(delta < 0 ? AppColour.success : AppColour.danger)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .padding(DS.space1)
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedTrendPoint?.date)

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

    private var vitalityChartAccessibilityValue: String {
        guard let latest = scorer.history.last?.age else {
            return "No history available"
        }
        let delta = latest - scorer.chronologicalAge
        let comparison: String
        if delta > 0 {
            comparison = "\(delta) years older than chronological age"
        } else if delta < 0 {
            comparison = "\(-delta) years younger than chronological age"
        } else {
            comparison = "matches chronological age"
        }
        return "Latest vitality age \(latest), \(comparison)"
    }

    private var historyChangeColor: Color {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return .secondary
        }
        return vitalityDeltaColor(for: last - first)
    }
}
