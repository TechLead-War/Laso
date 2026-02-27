import SwiftUI
import Charts

/// Line chart for displaying metric time series data using Swift Charts with touch selection
struct MetricChartView: View {
    let samples: [MetricSample]
    let metric: HealthMetric
    let baseline: Double?
    let normalRange: RulesConfiguration.NormalRange?

    @State private var selectedDate: Date?
    @State private var isDragging = false

    init(
        samples: [MetricSample],
        metric: HealthMetric,
        baseline: Double? = nil,
        normalRange: RulesConfiguration.NormalRange? = nil
    ) {
        self.samples = samples
        self.metric = metric
        self.baseline = baseline
        self.normalRange = normalRange
    }

    private var color: Color {
        metric.category.color
    }

    /// Days spanned by the current sample set
    private var dataSpanDays: Int {
        guard let first = samples.first?.date, let last = samples.last?.date else { return 7 }
        return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 7)
    }

    /// Adaptive X-axis stride based on data span — keeps ~4-6 labels visible
    private var xAxisStride: (component: Calendar.Component, count: Int) {
        switch dataSpanDays {
        case 0...10:   return (.day, 2)       // 7D  → every 2 days  (~4 labels)
        case 11...35:  return (.day, 7)       // 30D → every 7 days  (~4 labels)
        case 36...100: return (.day, 14)      // 3M  → every 2 weeks (~6 labels)
        case 101...200: return (.month, 1)    // 6M  → every month   (~6 labels)
        case 201...400: return (.month, 2)    // 1Y  → every 2 months(~6 labels)
        default:       return (.month, 3)     // All → every quarter (~4-5 labels)
        }
    }

    /// Adaptive date format — shorter labels for longer spans
    private var xAxisDateFormat: Date.FormatStyle {
        switch dataSpanDays {
        case 0...35:   return .dateTime.month(.abbreviated).day()   // "Jan 15"
        case 36...200: return .dateTime.month(.abbreviated).day()   // "Jan 15"
        default:       return .dateTime.month(.abbreviated).year(.twoDigits) // "Jan '25"
        }
    }

    /// Focused Y-axis domain based on actual data, not the full normal range.
    /// Prevents small-variation metrics (e.g. walking asymmetry 2-5%) from looking
    /// flat when the normal range is much wider (0-15%).
    private var yDomain: ClosedRange<Double> {
        guard !samples.isEmpty else { return 0...1 }

        var minVal = samples.map(\.value).min()!
        var maxVal = samples.map(\.value).max()!

        // Include baseline in the visible range if present
        if let baseline {
            minVal = min(minVal, baseline)
            maxVal = max(maxVal, baseline)
        }

        let span = maxVal - minVal
        // Add 20% padding so the line doesn't hug the edges
        let padding = max(span * 0.2, maxVal * 0.05)

        let low = max(0, minVal - padding) // don't go below zero for most metrics
        let high = maxVal + padding

        // Ensure the domain isn't degenerate (all same values)
        if low >= high {
            return max(0, low - 1)...(high + 1)
        }
        return low...high
    }

    /// Find the closest sample to the selected date
    private var selectedSample: MetricSample? {
        guard let selectedDate else { return nil }
        return samples.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    var body: some View {
        Chart {
            // Normal range area
            if let range = normalRange {
                RectangleMark(
                    xStart: nil,
                    xEnd: nil,
                    yStart: .value("Low", range.low),
                    yEnd: .value("High", range.high)
                )
                .foregroundStyle(.green.opacity(0.05))
            }

            // Data line
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(color.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Area under curve
            ForEach(samples) { sample in
                AreaMark(
                    x: .value("Date", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Baseline reference line
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Baseline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            // Selection indicator
            if let sample = selectedSample {
                RuleMark(x: .value("Selected", sample.date))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Selected", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(color)
                .symbolSize(80)

                PointMark(
                    x: .value("Selected", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(.white)
                .symbolSize(30)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride.component, count: xAxisStride.count)) { _ in
                AxisValueLabel(format: xAxisDateFormat)
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
            }
        }
        .frame(height: 220)
        .contentShape(Rectangle())
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    AppAnalytics.shared.trackChartInteraction(
                                        metric: metric.rawValue,
                                        interactionType: "drag_start",
                                        screen: .metricDetail
                                    )
                                    AppAnalytics.shared.trackActivationMilestone(.firstChartInteraction)
                                    AppAnalytics.shared.trackCoreAction(.interactedWithChart, screen: .metricDetail)
                                }
                                isDragging = true
                                let origin = geometry[proxy.plotFrame!].origin
                                let locationX = value.location.x - origin.x
                                if let date: Date = proxy.value(atX: locationX) {
                                    selectedDate = date
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                AppAnalytics.shared.trackChartInteraction(
                                    metric: metric.rawValue,
                                    interactionType: "drag_end",
                                    screen: .metricDetail,
                                    metadata: ["selected_value": selectedSample?.value ?? 0]
                                )
                            }
                    )
                    .onTapGesture { location in
                        let origin = geometry[proxy.plotFrame!].origin
                        let locationX = location.x - origin.x
                        if let date: Date = proxy.value(atX: locationX) {
                            if selectedDate == date {
                                selectedDate = nil // Deselect on second tap
                                AppAnalytics.shared.trackChartInteraction(
                                    metric: metric.rawValue,
                                    interactionType: "tap_deselect",
                                    screen: .metricDetail
                                )
                            } else {
                                selectedDate = date
                                AppAnalytics.shared.trackChartInteraction(
                                    metric: metric.rawValue,
                                    interactionType: "tap_select",
                                    screen: .metricDetail,
                                    metadata: ["selected_value": selectedSample?.value ?? 0]
                                )
                            }
                        }
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            selectedValueOverlay
        }
        .sensoryFeedback(.selection, trigger: selectedSample?.id)
    }

    @ViewBuilder
    private var selectedValueOverlay: some View {
        if let sample = selectedSample {
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formattedValue(sample.value))
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)

                    Text(metric.unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // Show how far from baseline
                if let baseline, baseline > 0 {
                    let devPercent = ((sample.value - baseline) / baseline) * 100
                    let sign = devPercent >= 0 ? "+" : ""
                    Text("\(sign)\(String(format: "%.1f", devPercent))% from baseline")
                        .font(.caption2)
                        .foregroundStyle(abs(devPercent) > 10 ? .orange : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .padding(4)
        }
    }

    private func formattedValue(_ value: Double) -> String {
        switch metric {
        case .steps, .activeCalories, .basalCalories, .flightsClimbed,
             .heartRate, .restingHeartRate, .walkingHeartRateAverage,
             .heartRateRecovery, .bloodPressureSystolic, .bloodPressureDiastolic:
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    let samples = SampleDataProvider.generateTimeSeries(for: .restingHeartRate, days: 30).samples
    MetricChartView(
        samples: samples,
        metric: .restingHeartRate,
        baseline: 65,
        normalRange: RulesConfiguration.normalRange(for: .restingHeartRate)
    )
    .padding()
}
