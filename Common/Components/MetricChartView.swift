import SwiftUI
import Charts

/// Line chart for displaying metric time series data using Swift Charts with touch selection
struct MetricChartView: View {
    let samples: [MetricSample]
    let metric: HealthMetric
    let baseline: Double?
    let normalRange: RulesConfiguration.NormalRange?
    let trendLine: [MetricSample]?
    let forecastPoints: [MetricSample]?
    private let dataSpanDays: Int
    private let periodLabel: String
    private let xAxisStride: (component: Calendar.Component, count: Int)
    private let xAxisDateFormat: Date.FormatStyle
    private let yDomain: ClosedRange<Double>

    @State private var selectedDate: Date?
    @State private var isDragging = false

    init(
        samples: [MetricSample],
        metric: HealthMetric,
        baseline: Double? = nil,
        normalRange: RulesConfiguration.NormalRange? = nil,
        trendLine: [MetricSample]? = nil,
        forecastPoints: [MetricSample]? = nil
    ) {
        let dataSpanDays = Self.makeDataSpanDays(samples: samples)
        self.samples = samples
        self.metric = metric
        self.baseline = baseline
        self.normalRange = normalRange
        self.trendLine = trendLine
        self.forecastPoints = forecastPoints
        self.dataSpanDays = dataSpanDays
        self.periodLabel = Self.makePeriodLabel(dataSpanDays: dataSpanDays)
        self.xAxisStride = Self.makeXAxisStride(dataSpanDays: dataSpanDays)
        self.xAxisDateFormat = Self.makeXAxisDateFormat(dataSpanDays: dataSpanDays)
        self.yDomain = Self.makeYDomain(
            samples: samples,
            baseline: baseline,
            trendLine: trendLine,
            forecastPoints: forecastPoints
        )
    }

    private var color: Color {
        metric.category.color
    }

    /// Find the closest sample to the selected date
    private var selectedSample: MetricSample? {
        guard let selectedDate, !samples.isEmpty else { return nil }
        let insertionIndex = Self.firstIndex(onOrAfter: selectedDate, in: samples)
        if insertionIndex <= 0 {
            return samples.first
        }
        if insertionIndex >= samples.count {
            return samples.last
        }

        let previous = samples[insertionIndex - 1]
        let next = samples[insertionIndex]
        return abs(previous.date.timeIntervalSince(selectedDate)) <= abs(next.date.timeIntervalSince(selectedDate))
            ? previous
            : next
    }

    var body: some View {
        if samples.count < 2 {
            ContentUnavailableView("Not Enough Data", systemImage: "chart.line.downtrend.xyaxis", description: Text("At least 2 data points needed"))
                .frame(height: 220)
        } else {
        chart
        }
    }

    private var chart: some View {
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

            // Data line + area under curve (single pass)
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(color.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", sample.date),
                    y: .value(metric.displayName, sample.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.15), .clear],
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

            // Trend overlay line (moving average)
            if let trendLine, trendLine.count >= 2 {
                ForEach(trendLine) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Trend", point.value),
                        series: .value("Series", "trend")
                    )
                    .foregroundStyle(.orange.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Forecast dashed extension
            if let forecastPoints, !forecastPoints.isEmpty {
                // Bridge from last data point to first forecast
                if let lastSample = samples.last, let firstForecast = forecastPoints.first {
                    let bridgePoints = [
                        MetricSample(date: lastSample.date, value: lastSample.value),
                        MetricSample(date: firstForecast.date, value: firstForecast.value)
                    ]
                    ForEach(bridgePoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Forecast", point.value),
                            series: .value("Series", "forecast")
                        )
                        .foregroundStyle(color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }

                ForEach(forecastPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Forecast", point.value),
                        series: .value("Series", "forecast")
                    )
                    .foregroundStyle(color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .interpolationMethod(.catmullRom)
                }

                // Forecast endpoint markers
                ForEach(forecastPoints) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Forecast", point.value)
                    )
                    .foregroundStyle(color.opacity(0.4))
                    .symbolSize(20)
                }
            }

            // Selection indicator
            if let sample = selectedSample {
                RuleMark(x: .value("Selected", sample.date))
                    .foregroundStyle(.secondary.opacity(0.5))
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
        .clipped()
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
                                        period: periodLabel,
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
                                    period: periodLabel,
                                    screen: .metricDetail
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
                                    period: periodLabel,
                                    screen: .metricDetail
                                )
                            } else {
                                selectedDate = date
                                AppAnalytics.shared.trackChartInteraction(
                                    metric: metric.rawValue,
                                    interactionType: "tap_select",
                                    period: periodLabel,
                                    screen: .metricDetail
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
            .padding(DS.space1)
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

    private static func makeDataSpanDays(samples: [MetricSample]) -> Int {
        guard let first = samples.first?.date, let last = samples.last?.date else { return 7 }
        return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 7)
    }

    private static func makePeriodLabel(dataSpanDays: Int) -> String {
        if dataSpanDays <= 1 { return "daily" }
        if dataSpanDays <= 7 { return "weekly" }
        if dataSpanDays <= 31 { return "monthly" }
        if dataSpanDays <= 93 { return "quarterly" }
        return "yearly"
    }

    private static func makeXAxisStride(dataSpanDays: Int) -> (component: Calendar.Component, count: Int) {
        switch dataSpanDays {
        case 0...10: return (.day, 2)
        case 11...35: return (.day, 7)
        case 36...100: return (.day, 14)
        case 101...200: return (.month, 1)
        case 201...400: return (.month, 2)
        default: return (.month, 3)
        }
    }

    private static func makeXAxisDateFormat(dataSpanDays: Int) -> Date.FormatStyle {
        switch dataSpanDays {
        case 0...35:
            return .dateTime.month(.abbreviated).day()
        case 36...200:
            return .dateTime.month(.abbreviated).day()
        default:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private static func makeYDomain(
        samples: [MetricSample],
        baseline: Double?,
        trendLine: [MetricSample]?,
        forecastPoints: [MetricSample]?
    ) -> ClosedRange<Double> {
        guard let firstSample = samples.first else { return 0...1 }

        var minVal = firstSample.value
        var maxVal = firstSample.value

        for sample in samples.dropFirst() {
            minVal = min(minVal, sample.value)
            maxVal = max(maxVal, sample.value)
        }

        if let baseline {
            minVal = min(minVal, baseline)
            maxVal = max(maxVal, baseline)
        }

        if let trendLine {
            for point in trendLine {
                minVal = min(minVal, point.value)
                maxVal = max(maxVal, point.value)
            }
        }

        if let forecastPoints {
            for point in forecastPoints {
                minVal = min(minVal, point.value)
                maxVal = max(maxVal, point.value)
            }
        }

        let span = maxVal - minVal
        let padding = max(span * 0.2, maxVal * 0.05)
        let low = max(0, minVal - padding)
        let high = maxVal + padding

        if low >= high {
            return max(0, low - 1)...(high + 1)
        }
        return low...high
    }

    private static func firstIndex(onOrAfter date: Date, in samples: [MetricSample]) -> Int {
        var low = 0
        var high = samples.count
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
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
