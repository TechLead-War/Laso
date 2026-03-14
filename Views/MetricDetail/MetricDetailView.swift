import SwiftUI
import Charts

/// Deep-dive view for a single metric with charts, stats, moving averages, baselines, and insights
struct MetricDetailView: View {
    @State var viewModel: MetricDetailViewModel
    var deviceSourceManager: DeviceSourceManager? = nil
    var healthKitManager: HealthKitManager? = nil
    var healthDataStore: HealthDataStore? = nil

    @State private var autoExpandedRange: Int?
    @State private var showLogSheet = false

    @State private var headerTracker = SectionTracker(section: .metricDetailHeader, tab: .metricDetail)
    @State private var chartTracker = SectionTracker(section: .metricDetailChart, tab: .metricDetail)
    @State private var summaryTracker = SectionTracker(section: .metricDetailSummary, tab: .metricDetail)
    @State private var historyTracker = SectionTracker(section: .metricDetailHistory, tab: .metricDetail)
    @State private var scoreImpactTracker = SectionTracker(section: .metricDetailScoreImpact, tab: .metricDetail)
    @State private var insightsTracker = SectionTracker(section: .metricDetailInsights, tab: .metricDetail)
    @State private var comparisonTracker = SectionTracker(section: .metricDetailComparison, tab: .metricDetail)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.chartSamples.isEmpty {
                    noDataView
                } else {
                    // Notify user if time range was auto-expanded
                    if let expandedTo = autoExpandedRange {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Showing \(expandedTo)-day range — no data found in the last 30 days")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                    // Current Value Header
                    headerSection
                        .onAppear { headerTracker.appeared() }
                        .onDisappear { headerTracker.disappeared() }

                    // Log button for writable metrics
                    if HealthKitManager.writableMetrics.contains(viewModel.metric) {
                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Log \(viewModel.metric.displayName)",
                                type: .metricLogOpen,
                                screen: .metricDetail,
                                metadata: [
                                    "metric_id": viewModel.metric.rawValue,
                                    "destination": "metric_log_sheet"
                                ]
                            )
                            showLogSheet = true
                        } label: {
                            Label("Log \(viewModel.metric.displayName)", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // Action Banner — show recommendation if insight exists
                    if let recommendation = viewModel.insights.first?.recommendation {
                        actionBanner(recommendation)
                    }

                    // Time Range Selector
                    TimeRangeSelector(selectedDays: Binding(
                        get: { viewModel.selectedTimeRange },
                        set: { newRange in
                            let oldRange = viewModel.selectedTimeRange
                            viewModel.selectedTimeRange = newRange
                            autoExpandedRange = nil
                            if oldRange != newRange {
                                AppAnalytics.shared.trackTimeRangeChanged(
                                    screen: .metricDetail,
                                    context: viewModel.metric.rawValue,
                                    fromDays: oldRange,
                                    toDays: newRange
                                )
                                AppAnalytics.shared.trackCoreAction(.changedTimeRange, screen: .metricDetail)
                            }
                        }
                    ))
                    .padding(.horizontal)

                    // Chart
                    chartSection
                        .onAppear { chartTracker.appeared() }
                        .onDisappear { chartTracker.disappeared() }

                    // Contextual Summary (replaces raw stats grid)
                    contextualSummary
                        .onAppear { summaryTracker.appeared() }
                        .onDisappear { summaryTracker.disappeared() }

                    // Month-over-Month Comparison
                    if viewModel.monthComparison != nil {
                        monthComparisonSection
                            .onAppear { comparisonTracker.appeared() }
                            .onDisappear { comparisonTracker.disappeared() }
                    }

                    // Historical Context
                    if !viewModel.historicalFacts.isEmpty {
                        historicalContextSection
                            .onAppear { historyTracker.appeared() }
                            .onDisappear { historyTracker.disappeared() }
                    }

                    // Score Breakdown
                    if !viewModel.scoreBreakdown.isEmpty {
                        scoreBreakdownSection
                            .onAppear { scoreImpactTracker.appeared() }
                            .onDisappear { scoreImpactTracker.disappeared() }
                    }

                    // Insights
                    if !viewModel.insights.isEmpty {
                        insightsSection
                            .onAppear { insightsTracker.appeared() }
                            .onDisappear { insightsTracker.disappeared() }
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogSheet) {
            if let hkManager = healthKitManager, let store = healthDataStore {
                MetricLogSheet(
                    metric: viewModel.metric,
                    healthKitManager: hkManager,
                    healthDataStore: store
                )
                .presentationDetents([.medium])
            }
        }
        .onAppear {
            // If default 30-day range is empty, try broader ranges and notify the user
            if viewModel.chartSamples.isEmpty {
                for range in [90, 180, 365] {
                    viewModel.selectedTimeRange = range
                    if !viewModel.chartSamples.isEmpty {
                        autoExpandedRange = range
                        break
                    }
                }
            }
            AppAnalytics.shared.trackFeatureOpen(.metricDetail, metadata: [
                "metric": viewModel.metric.rawValue,
                "trend": viewModel.trendDirection.rawValue,
                "change_pct": viewModel.weekOverWeekChange,
                "has_anomaly": viewModel.isOutsideNormalRange
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstMetricDetail)
            AppAnalytics.shared.trackCoreAction(.viewedMetricDetail, screen: .metricDetail)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "viewed_metric_detail", screen: .metricDetail)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.metricDetail, metadata: ["metric": viewModel.metric.rawValue]) }
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Image(systemName: viewModel.metric.systemImageName)
                .font(.system(size: 44))
                .foregroundStyle(viewModel.metric.category.color.opacity(0.6))

            Text("No Data Yet")
                .font(.title3.weight(.semibold))

            Text("We don't have enough \(viewModel.metric.displayName.lowercased()) data to show trends yet. Keep your Health data syncing and check back after the next import.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Still show insights if they exist (they come from analysis, not chart data)
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Insights")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(viewModel.insights) { insight in
                        InsightCard(insight: insight)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(viewModel.currentValue)
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text(viewModel.metric.unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TrendBadge(
                    direction: viewModel.trendDirection,
                    changeText: viewModel.weekOverWeekChange
                )

                if viewModel.isOutsideNormalRange {
                    Text("Outside Normal Range")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(.red, in: Capsule())
                }
            }

            // Deviation from baseline
            if viewModel.baseline != nil {
                Text("Baseline deviation: \(viewModel.deviationFromBaseline)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Data source attribution
            if let sourceManager = deviceSourceManager,
               let sourceDevice = sourceManager.sourceDevice(for: viewModel.metric) {
                DataSourceBadge(device: sourceDevice.device, sourceName: sourceDevice.sourceName)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.metric.displayName), current value \(viewModel.currentValue) \(viewModel.metric.unit), \(viewModel.trendDirection == .improving ? "improving" : viewModel.trendDirection == .declining ? "declining" : "stable")\(viewModel.isOutsideNormalRange ? ", outside normal range" : "")")
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricChartView(
                samples: viewModel.chartSamples,
                metric: viewModel.metric,
                baseline: viewModel.baseline?.mean,
                normalRange: viewModel.normalRange,
                trendLine: viewModel.trendLineSamples.isEmpty ? nil : viewModel.trendLineSamples,
                forecastPoints: viewModel.forecastSamples.isEmpty ? nil : viewModel.forecastSamples
            )

            // Chart legend when trend or forecast are shown
            if !viewModel.trendLineSamples.isEmpty || !viewModel.forecastSamples.isEmpty {
                HStack(spacing: 16) {
                    if !viewModel.trendLineSamples.isEmpty {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.orange.opacity(0.7))
                                .frame(width: 16, height: 2)
                            Text("Trend")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !viewModel.forecastSamples.isEmpty {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(viewModel.metric.category.color.opacity(0.5))
                                .frame(width: 16, height: 2)
                            Text("Forecast")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    private func actionBanner(_ recommendation: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(.yellow)

            Text(recommendation)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: .yellow)
        .padding(.horizontal)
    }

    private var contextualSummary: some View {
        HStack(spacing: 0) {
            // Period Average + Range Status
            VStack(spacing: 6) {
                Text(viewModel.averageValue)
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("Period Avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.isOutsideNormalRange ? "Outside Range" : "Within Range")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(viewModel.isOutsideNormalRange ? .red : .green)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            // Period Change + Trend
            VStack(spacing: 6) {
                Text(viewModel.weekOverWeekChange)
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(viewModel.periodChangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TrendBadge(
                    direction: viewModel.trendDirection,
                    changeText: nil
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Month Comparison

    @ViewBuilder
    private var monthComparisonSection: some View {
        if let comp = viewModel.monthComparison {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(icon: "calendar", title: "This Month vs Last Month")

                HStack(spacing: 0) {
                    // This month
                    VStack(spacing: 6) {
                        Text(viewModel.metric.formatValue(comp.thisMonthAvg))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text(comp.thisMonthLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Arrow + change
                    VStack(spacing: 4) {
                        Image(systemName: comp.improving ? "arrow.up.right" : abs(comp.changePercent) < 2 ? "arrow.right" : "arrow.down.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(comp.improving ? .green : abs(comp.changePercent) < 2 ? .secondary : .red)

                        Text(TrendAnalyzer.formattedPercentChange(comp.changePercent))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(comp.improving ? .green : abs(comp.changePercent) < 2 ? .secondary : .red)
                    }
                    .frame(maxWidth: .infinity)

                    // Last month
                    VStack(spacing: 6) {
                        Text(viewModel.metric.formatValue(comp.lastMonthAvg))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(comp.lastMonthLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Shared Row Builder

    /// Single row builder used by ALL sections — guarantees pixel-perfect alignment.
    /// The icon, spacing, padding, and text position are identical for every row on the page.
    private func sectionRow(
        icon: String,
        iconColor: Color,
        text: String,
        detail: String? = nil,
        detailColor: Color = .secondary,
        trailing: String? = nil,
        trailingColor: Color = .primary
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(detailColor)
                }
            }

            Spacer(minLength: 4)

            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(trailingColor)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 11)
    }

    private static let rowDividerLeading: CGFloat = DS.cardPadding + 30 + 10

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

    // MARK: - Score Breakdown

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "chart.bar.fill", title: "Score Impact")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.scoreBreakdown.enumerated()), id: \.element.id) { index, component in
                    sectionRow(
                        icon: component.points >= 0 ? "plus.circle.fill" : "minus.circle.fill",
                        iconColor: component.points >= 0 ? .green : .red,
                        text: component.reason,
                        trailing: "\(component.points > 0 ? "+" : "")\(component.points) pts",
                        trailingColor: component.points >= 0 ? .green : .red
                    )

                    if index < viewModel.scoreBreakdown.count - 1 {
                        Divider().padding(.leading, Self.rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - Historical Context

    private var historicalContextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "clock.arrow.circlepath", title: "Historical Context")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.historicalFacts.enumerated()), id: \.element.id) { index, fact in
                    sectionRow(
                        icon: fact.icon,
                        iconColor: .blue,
                        text: fact.text
                    )

                    if index < viewModel.historicalFacts.count - 1 {
                        Divider().padding(.leading, Self.rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)

            if let ctx = viewModel.historicalContext {
                Text("Based on \(ctx.totalDataPoints) data points over the past year")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "lightbulb.fill", title: "Insights")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.insights.enumerated()), id: \.element.id) { index, insight in
                    sectionRow(
                        icon: insight.metric.systemImageName,
                        iconColor: insight.metric.category.color,
                        text: insightActionText(insight),
                        detail: "\(insight.metric.displayName)  ·  \(insight.severity.displayName)",
                        detailColor: insight.severity.color
                    )

                    if index < viewModel.insights.count - 1 {
                        Divider().padding(.leading, Self.rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    /// First sentence of the recommendation
    private func insightActionText(_ insight: Insight) -> String {
        let rec = insight.recommendation
        var searchStart = rec.startIndex
        while searchStart < rec.endIndex {
            guard let dotIndex = rec[searchStart...].firstIndex(of: ".") else { break }
            let beforeDot = rec[searchStart..<dotIndex]
            if beforeDot.trimmingCharacters(in: .whitespaces).allSatisfy(\.isNumber) {
                searchStart = rec.index(after: dotIndex)
                continue
            }
            return String(rec[rec.startIndex...dotIndex])
        }
        return rec
    }
}

#Preview {
    NavigationStack {
        let hkManager = HealthKitManager()
        let engine = AnalysisEngine()

        MetricDetailView(
            viewModel: MetricDetailViewModel(
                metric: .restingHeartRate,
                healthKitManager: hkManager,
                analysisEngine: engine
            ),
            deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore)
        )
    }
}
