import SwiftUI
import Charts

struct VitalityTrendSection: View {
    let scorer: VitalityScorer

    private var paceTint: Color { vitalityPaceTint(for: scorer) }

    @State private var selectedTrendDate: Date?
    @State private var isScrubbing = false

    /// A scroll view claims a pan at roughly 10pt, so scrubbing has to engage just
    /// under that to stay instant without stealing a vertical page scroll.
    private static let scrubMinimumDrag: CGFloat = 8

    private var selectedTrendPoint: (date: Date, age: Double)? {
        guard let selectedTrendDate, !scorer.history.isEmpty else { return nil }
        return scorer.history.min(by: { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedTrendDate)) < abs(rhs.date.timeIntervalSince(selectedTrendDate))
        })
    }

    var body: some View {
        // Resolved once: each read scans the whole history, and a scrub rebuilds
        // this body on every frame.
        let selected = selectedTrendPoint

        VStack(alignment: .leading, spacing: 10) {
            vitalitySectionHeader(icon: "chart.xyaxis.line", title: Copy.Vitality.trendTitle(days: scorer.historySpanDays))

            VStack(alignment: .leading, spacing: 12) {
                Chart {
                    RuleMark(y: .value("Chronological Age", Double(scorer.chronologicalAge)))
                        .foregroundStyle(AppColour.danger.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))

                    ForEach(Array(scorer.history.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Baseline", Double(scorer.chronologicalAge)),
                            yEnd: .value("Age", point.age)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyFillColor)
                        .accessibilityHidden(true)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Age", point.age)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(historyLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    if let latest = scorer.history.last {
                        PointMark(
                            x: .value("Latest Date", latest.date),
                            y: .value("Latest Age", latest.age)
                        )
                        .symbolSize(42)
                        .foregroundStyle(historyLineColor)
                    }

                    if let selected {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(historyLineColor.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                        PointMark(
                            x: .value("Selected", selected.date),
                            y: .value("Age", selected.age)
                        )
                        .foregroundStyle(AppColour.markerOnSurface)
                        .symbolSize(70)

                        PointMark(
                            x: .value("Selected", selected.date),
                            y: .value("Age", selected.age)
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
                    // Six or so labels whatever the span. A fixed 15 day stride
                    // printed a single tick once the chart stopped assuming 90 days.
                    AxisMarks(values: .stride(by: .day, count: max(1, scorer.historySpanDays / 6))) { _ in
                        AxisGridLine().foregroundStyle(AppColour.chartGridline)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.caption2)
                            .foregroundStyle(AppColour.chartAxisLabel)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(AppColour.chartGridline)
                        AxisValueLabel {
                            if let y = value.as(Double.self) {
                                Text(Copy.Vitality.xText(Int(y)))
                                    .font(.caption2)
                                    .foregroundStyle(AppColour.chartAxisLabel)
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
                                DragGesture(minimumDistance: Self.scrubMinimumDrag)
                                    .onChanged { value in
                                        // This chart sits in a scrolling page, so it only
                                        // takes the touch once the finger is clearly moving
                                        // sideways, and keeps it for the rest of the drag.
                                        guard isScrubbing || abs(value.translation.width) > abs(value.translation.height) else { return }
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        isScrubbing = true
                                        let origin = geometry[plotFrame].origin
                                        let x = value.location.x - origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedTrendDate = date
                                        }
                                    }
                                    .onEnded { _ in isScrubbing = false }
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
                    if let selected {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption2)
                                .foregroundStyle(AppColour.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(Copy.Vitality.xText2(Int(selected.age.rounded())))
                                    .font(.callout.weight(.bold).monospacedDigit())
                                    .foregroundStyle(historyLineColor)
                                Text(Copy.Vitality.yrs)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppColour.textSecondary)
                            }
                            let delta = Int(selected.age.rounded()) - scorer.chronologicalAge
                            if delta != 0 {
                                Text(Copy.Vitality.deltaVsActual(delta))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(delta < 0 ? AppColour.success : AppColour.danger)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColour.surfaceOverlay, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: AppColour.shadowFloating, radius: 4, y: 2)
                        .padding(DS.space1)
                    }
                }
                .sensoryFeedback(.selection, trigger: selected?.date)

                HStack(spacing: 0) {
                    trendStat(title: Copy.Vitality.changeOverDays(scorer.historySpanDays), value: historyChangeText, color: historyChangeColor)

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
                .foregroundStyle(AppColour.textSecondary)
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

        let values = scorer.history.map(\.age) + [Double(scorer.chronologicalAge)]
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

    /// One decimal, because the whole point of the fix is that a quarter's
    /// drift is a fraction of a year and rounding it away hides the trend.
    private var historyChangeText: String {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return Copy.Vitality.noValue
        }
        return Copy.Vitality.yearChange(last - first)
    }

    private var vitalityChartAccessibilityValue: String {
        guard let latest = scorer.history.last?.age else {
            return Copy.Vitality.noHistoryAvailable
        }
        let latestAge = Int(latest.rounded())
        let delta = latestAge - scorer.chronologicalAge
        let comparison: String
        if delta > 0 {
            comparison = Copy.Vitality.yearsOlderThanActual(delta)
        } else if delta < 0 {
            comparison = Copy.Vitality.yearsYoungerThanActual(-delta)
        } else {
            comparison = Copy.Vitality.matchesActualAge
        }
        return Copy.Vitality.chartAccessibilityValue(age: latestAge, comparison: comparison)
    }

    private var historyChangeColor: Color {
        guard let first = scorer.history.first?.age,
              let last = scorer.history.last?.age else {
            return AppColour.textSecondary
        }
        return vitalityDeltaColor(for: Int((last - first).rounded()))
    }
}
