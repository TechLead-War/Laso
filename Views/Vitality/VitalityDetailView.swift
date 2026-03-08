import SwiftUI
import Charts

/// Full breakdown view showing the user's Vitality Age with per-metric analysis,
/// historical trend chart, and actionable improvement suggestions.
struct VitalityDetailView: View {
    let scorer: VitalityScorer

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // 1. Hero header
                heroSection

                // 2. Per-metric breakdown
                if !scorer.componentAges.isEmpty {
                    metricsBreakdownSection
                }

                // 3. Historical chart
                if scorer.history.count >= 7 {
                    historicalChartSection
                }

                // 4. How to improve
                if !scorer.topImprovementOpportunities.isEmpty {
                    improvementSection
                }

                // 5. Methodology note
                methodologyNote
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Vitality Age")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 1. Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Large vitality age display
            ZStack {
                Circle()
                    .stroke(heroColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(heroColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(scorer.vitalityAge)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Delta badge
            HStack(spacing: 8) {
                Text("Chronological Age: \(scorer.chronologicalAge)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                heroDeltaBadge
            }

            // Pace of aging
            HStack(spacing: 6) {
                Image(systemName: paceIcon)
                    .font(.caption.weight(.bold))
                Text("Pace: \(scorer.paceLabel)")
                    .font(.subheadline.weight(.medium))

                Text(paceExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(paceColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(paceColor.opacity(0.1), in: Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var heroDeltaBadge: some View {
        let delta = scorer.delta
        let text: String
        if delta == 0 {
            text = "Right on track"
        } else if delta < 0 {
            text = "\(abs(delta)) years younger"
        } else {
            text = "\(delta) years older"
        }

        return Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(heroColor, in: Capsule())
    }

    // MARK: - 2. Per-Metric Breakdown

    private var metricsBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.bar.fill", title: "Metric Breakdown")

            VStack(spacing: 0) {
                ForEach(Array(scorer.componentAges.enumerated()), id: \.element.id) { index, component in
                    metricRow(component)

                    if index < scorer.componentAges.count - 1 {
                        Divider()
                            .padding(.leading, rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func metricRow(_ component: VitalityComponent) -> some View {
        let componentDelta = component.delta(chronologicalAge: scorer.chronologicalAge)

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: component.healthMetric?.systemImageName ?? "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(metricColor(delta: componentDelta))
                    .frame(width: 30, height: 30)
                    .background(metricColor(delta: componentDelta).opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 7))

                // Name and values
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(component.metric)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        // Metric age badge
                        Text("Age \(component.metricAge)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(metricColor(delta: componentDelta))
                    }

                    HStack {
                        Text("Current: \(formatValue(component.currentValue, unit: component.unit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Delta from chronological
                        let deltaText = componentDelta == 0 ? "On track" :
                            componentDelta < 0 ? "\(abs(componentDelta))y younger" :
                            "+\(componentDelta)y older"
                        Text(deltaText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(metricColor(delta: componentDelta))
                    }
                }
            }

            // Population comparison gauge
            metricGauge(component)
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 11)
    }

    private func metricGauge(_ component: VitalityComponent) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let median = component.populationMedian
            let current = component.currentValue
            let isHigherBetter = component.healthMetric?.higherIsBetter ?? true

            // Compute position: 0.5 = at median, 0 = worst, 1 = best
            let range = median * 0.6 // Show +/- 60% of median
            let position: Double
            if range > 0 {
                let raw = (current - (median - range)) / (2 * range)
                position = isHigherBetter ? max(0, min(1, raw)) : max(0, min(1, 1 - raw))
            } else {
                position = 0.5
            }

            ZStack(alignment: .leading) {
                // Background gradient bar
                LinearGradient(
                    colors: [.red.opacity(0.3), .orange.opacity(0.3), .green.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 6)
                .clipShape(Capsule())

                // Median marker
                Rectangle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 1, height: 10)
                    .offset(x: width * 0.5)

                // User position marker
                Circle()
                    .fill(metricColor(delta: component.delta(chronologicalAge: scorer.chronologicalAge)))
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: max(0, min(width - 10, width * position)))
            }
        }
        .frame(height: 12)

        // Legend
        HStack {
            Text("Worse")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Spacer()
            Text("Median for age \(scorer.chronologicalAge)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Spacer()
            Text("Better")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 3. Historical Chart

    private var historicalChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.xyaxis.line", title: "90-Day Trend")

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    // Chronological age reference line
                    RuleMark(y: .value("Chronological", scorer.chronologicalAge))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("Age \(scorer.chronologicalAge)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                    // Vitality age line
                    ForEach(Array(scorer.history.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Vitality Age", point.age)
                        )
                        .foregroundStyle(heroColor.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Base", scorer.chronologicalAge),
                            yEnd: .value("Vitality Age", point.age)
                        )
                        .foregroundStyle(
                            scorer.delta < 0
                                ? Color.green.opacity(0.1)
                                : Color.red.opacity(0.1)
                        )
                    }
                }
                .chartYScale(domain: chartYRange)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 30)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let age = value.as(Int.self) {
                                Text("\(age)")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 180)

                // Chart legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(heroColor).frame(width: 6, height: 6)
                        Text("Vitality Age")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 12, height: 1)
                        Text("Actual Age")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private var chartYRange: ClosedRange<Int> {
        guard !scorer.history.isEmpty else {
            return (scorer.chronologicalAge - 10)...(scorer.chronologicalAge + 10)
        }
        let ages = scorer.history.map(\.age) + [scorer.chronologicalAge]
        let minAge = (ages.min() ?? scorer.chronologicalAge) - 3
        let maxAge = (ages.max() ?? scorer.chronologicalAge) + 3
        return minAge...maxAge
    }

    // MARK: - 4. How to Improve

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "lightbulb.fill", title: "How to Improve")

            VStack(spacing: 0) {
                ForEach(Array(scorer.topImprovementOpportunities.enumerated()), id: \.element.id) { index, component in
                    improvementRow(component)

                    if index < scorer.topImprovementOpportunities.count - 1 {
                        Divider()
                            .padding(.leading, rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func improvementRow(_ component: VitalityComponent) -> some View {
        let componentDelta = component.delta(chronologicalAge: scorer.chronologicalAge)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: component.healthMetric?.systemImageName ?? "arrow.up.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
                .frame(width: 30, height: 30)
                .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(component.metric)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("+\(componentDelta)y")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(.orange, in: Capsule())
                }

                Text(component.improvementSuggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 11)
    }

    // MARK: - 5. Methodology

    private var methodologyNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Vitality Age compares your key health metrics against age-adjusted population norms to estimate how old your body is performing. It is not a medical diagnosis. Consult your doctor for health advice.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
    }

    // MARK: - Shared Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private let rowDividerLeading: CGFloat = DS.cardPadding + 30 + 10

    private var heroColor: Color {
        let delta = scorer.delta
        if delta <= -5 { return .green }
        if delta < 0 { return .green }
        if delta == 0 { return .blue }
        if delta <= 3 { return .orange }
        return .red
    }

    /// Ring fill: 1.0 when vitality age is 10+ years younger, 0.0 when 10+ years older
    private var ringProgress: Double {
        let clamped = max(-10, min(10, -scorer.delta))
        return Double(clamped + 10) / 20.0
    }

    private func metricColor(delta: Int) -> Color {
        if delta <= -3 { return .green }
        if delta < 0 { return .green }
        if delta == 0 { return .blue }
        if delta <= 3 { return .orange }
        return .red
    }

    private var paceIcon: String {
        if scorer.paceOfAging < 0.85 { return "arrow.down.right" }
        if scorer.paceOfAging <= 1.15 { return "arrow.right" }
        return "arrow.up.right"
    }

    private var paceColor: Color {
        if scorer.paceOfAging < 0.85 { return .green }
        if scorer.paceOfAging <= 1.15 { return .gray }
        return .red
    }

    private var paceExplanation: String {
        if scorer.paceOfAging < 0.85 { return "Your body is improving over time" }
        if scorer.paceOfAging <= 1.15 { return "Holding steady" }
        return "Some metrics are trending worse"
    }

    private func formatValue(_ value: Double, unit: String) -> String {
        if value >= 1000 {
            return "\(Int(value)) \(unit)"
        } else if value == value.rounded() {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.1f", value) + " \(unit)"
        }
    }
}
