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
        if FeatureGate.isFreeTier && !FeatureGate.allowedFreeMetrics.contains(viewModel.metric.rawValue) {
            ProFeatureOverlay(
                feature: viewModel.metric.displayName,
                icon: viewModel.metric.systemImageName,
                description: "Deep-dive charts, baselines, and insights for \(viewModel.metric.displayName.lowercased()) are part of Pro."
            )
            .navigationTitle(viewModel.metric.displayName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            metricDetailBody
        }
    }

    private var metricDetailBody: some View {
        ScrollView {
            VStack(spacing: DS.space5) {
                if viewModel.chartSamples.isEmpty {
                    noDataView
                } else {
                    // Notify user if time range was auto-expanded
                    if let expandedTo = autoExpandedRange {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(DS.Typography.caption)
                            Text(Copy.Insights.MetricDetail.expandedRangeNotice(expandedTo))
                                .font(DS.Typography.caption)
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
                            Label(Copy.MetricDetail.logMenuLabel(viewModel.metric.displayName), systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    // Action Banner. show recommendation if insight exists
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

                Text(Copy.Analysis.RiskDetail.disclaimer)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                    .padding(.top, DS.space6)
                    .padding(.bottom, DS.space4)
            }
            .padding(.bottom)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(viewModel.metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.metricDetail")
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
                .font(DS.Typography.largeIcon)
                .foregroundStyle(viewModel.metric.category.color.opacity(0.6))

            Text(Copy.Insights.MetricDetail.noDataYet)
                .font(DS.Typography.title3)

            Text(Copy.Insights.MetricDetail.noDataDescription(viewModel.metric.displayName.lowercased()))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            // Still show insights if they exist (they come from analysis, not chart data)
            if !viewModel.insights.isEmpty {
                let displayLimit = FeatureGate.isFreeTier ? FeatureGate.insightLimit : Int.max
                let visibleInsights = Array(viewModel.insights.prefix(displayLimit))
                let hiddenInsights = max(0, viewModel.insights.count - visibleInsights.count)

                VStack(alignment: .leading, spacing: 10) {
                    Text(Copy.Insights.MetricDetail.insights)
                        .font(DS.Typography.headline)
                        .padding(.horizontal)

                    ForEach(visibleInsights) { insight in
                        InsightCard(insight: insight)
                            .padding(.horizontal)
                    }

                    if hiddenInsights > 0 {
                        LockedInsightsCTA(hiddenCount: hiddenInsights)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, DS.space2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Verdict for the latest reading, so the badge always judges the number printed next to it.
    private var latestVerdict: MetricVerdict? {
        guard let value = viewModel.timeSeries?.latestValue else { return nil }
        return MetricVerdict.make(metric: viewModel.metric, value: value, baseline: viewModel.baseline)
    }

    /// Verdict for the period average shown in the summary card, judged against the same band.
    private var periodAverageVerdict: MetricVerdict? {
        guard let series = viewModel.timeSeries,
              !series.samples(lastDays: viewModel.selectedTimeRange).isEmpty else { return nil }
        return MetricVerdict.make(
            metric: viewModel.metric,
            value: series.mean(lastDays: viewModel.selectedTimeRange),
            baseline: viewModel.baseline
        )
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(viewModel.currentValue)
                    .font(DS.Typography.displayL)

                Text(viewModel.metric.unit)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TrendBadge(
                    direction: viewModel.trendDirection,
                    changeText: viewModel.weekOverWeekChange,
                    numericChange: viewModel.trend?.weekOverWeekChange
                )

                if let verdict = latestVerdict {
                    Text(verdict.label)
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(verdict.color, in: Capsule())
                }
            }

            if let verdict = latestVerdict {
                Text(verdict.rangeText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Deviation from baseline
            if viewModel.baseline != nil {
                Text(Copy.Insights.MetricDetail.baselineDeviation(viewModel.deviationFromBaseline))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // Data source attribution
            if let sourceManager = deviceSourceManager,
               let sourceDevice = sourceManager.sourceDevice(for: viewModel.metric) {
                DataSourceBadge(device: sourceDevice.device, sourceName: sourceDevice.sourceName)
            }
        }
        .padding(.vertical, DS.space4)
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.metric.displayName), current value \(viewModel.currentValue) \(viewModel.metric.unit), \(viewModel.trendDirection == .improving ? "improving" : viewModel.trendDirection == .declining ? "declining" : "stable")\(latestVerdict.map { ", \($0.label), \($0.rangeText)" } ?? "")")
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricChartView(
                samples: viewModel.chartSamples,
                metric: viewModel.metric,
                baseline: viewModel.baseline?.mean,
                verdict: latestVerdict,
                trendLine: viewModel.trendLineSamples.isEmpty ? nil : viewModel.trendLineSamples,
                forecastPoints: viewModel.forecastSamples.isEmpty ? nil : viewModel.forecastSamples
            )

            // Chart legend when trend or forecast are shown
            if !viewModel.trendLineSamples.isEmpty || !viewModel.forecastSamples.isEmpty {
                HStack(spacing: 16) {
                    if !viewModel.trendLineSamples.isEmpty {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(AppColour.warning.opacity(0.7))
                                .frame(width: 16, height: 2)
                            Text(Copy.Insights.MetricDetail.trend)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !viewModel.forecastSamples.isEmpty {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(viewModel.metric.category.color.opacity(0.5))
                                .frame(width: 16, height: 2)
                            Text(Copy.Insights.MetricDetail.forecast)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.space1)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    private func actionBanner(_ recommendation: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(DS.Typography.body)
                .foregroundStyle(AppColour.warning)

            Text(recommendation)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(tint: AppColour.warning)
        .padding(.horizontal)
    }

    private var contextualSummary: some View {
        HStack(spacing: 0) {
            // Period Average + Range Status
            VStack(spacing: 6) {
                Text(viewModel.averageValue)
                    .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                Text(Copy.Insights.MetricDetail.periodAvg)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
                if let verdict = periodAverageVerdict {
                    Text(verdict.label)
                        .font(DS.Typography.caption2Semibold)
                        .foregroundStyle(verdict.color)
                }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            // Period Change + Trend
            VStack(spacing: 6) {
                Text(viewModel.weekOverWeekChange)
                    .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                Text(viewModel.periodChangeLabel)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.secondary)
                TrendBadge(
                    direction: viewModel.trendDirection,
                    changeText: nil,
                    numericChange: viewModel.trend?.weekOverWeekChange
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, DS.space4)
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Month Comparison

    @ViewBuilder
    private var monthComparisonSection: some View {
        if let comp = viewModel.monthComparison {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(icon: "calendar", title: Copy.Insights.MetricDetail.thisMonthVsLastMonth)

                HStack(spacing: 0) {
                    // This month
                    VStack(spacing: 6) {
                        Text(viewModel.metric.formatValue(comp.thisMonthAvg))
                            .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                        Text(comp.thisMonthLabel)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Arrow + change
                    VStack(spacing: 4) {
                        Image(systemName: comp.improving ? "arrow.up.right" : abs(comp.changePercent) < 2 ? "arrow.right" : "arrow.down.right")
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(comp.improving ? AppColour.success : abs(comp.changePercent) < 2 ? AppColour.textSecondary : AppColour.danger)

                        Text(TrendAnalyzer.formattedPercentChange(comp.changePercent))
                            .font(DS.Typography.captionSemibold.monospacedDigit())
                            .foregroundStyle(comp.improving ? AppColour.success : abs(comp.changePercent) < 2 ? AppColour.textSecondary : AppColour.danger)
                    }
                    .frame(maxWidth: .infinity)

                    // Last month
                    VStack(spacing: 6) {
                        Text(viewModel.metric.formatValue(comp.lastMonthAvg))
                            .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(comp.lastMonthLabel)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, DS.space4)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Shared Row Builder

    /// Single row builder used by ALL sections. guarantees pixel-perfect alignment.
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
                .font(DS.Typography.footnote)
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)

                if let detail {
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(detailColor)
                }
            }

            Spacer(minLength: 4)

            if let trailing {
                Text(trailing)
                    .font(DS.Typography.subheadlineSemibold.monospacedDigit())
                    .foregroundStyle(trailingColor)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.itemSpacing)
    }

    private static let rowDividerLeading: CGFloat = DS.cardPadding + 30 + 10

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(DS.Typography.headline)
        }
        .padding(.horizontal)
    }

    // MARK: - Score Breakdown

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "chart.bar.fill", title: Copy.Insights.MetricDetail.scoreImpact)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.scoreBreakdown.enumerated()), id: \.element.id) { index, component in
                    sectionRow(
                        icon: component.points >= 0 ? "plus.circle.fill" : "minus.circle.fill",
                        iconColor: component.points >= 0 ? AppColour.success : AppColour.danger,
                        text: component.reason,
                        trailing: "\(component.points > 0 ? "+" : "")\(component.points) pts",
                        trailingColor: component.points >= 0 ? AppColour.success : AppColour.danger
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
            sectionHeader(icon: "clock.arrow.circlepath", title: Copy.Insights.MetricDetail.historicalContext)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.historicalFacts.enumerated()), id: \.element.id) { index, fact in
                    sectionRow(
                        icon: fact.icon,
                        iconColor: AppColour.info,
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
                Text(Copy.Insights.MetricDetail.dataPointsSummary(ctx.totalDataPoints))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        let displayLimit = FeatureGate.isFreeTier ? FeatureGate.insightLimit : Int.max
        let visibleInsights = Array(viewModel.insights.prefix(displayLimit))
        let hiddenInsights = max(0, viewModel.insights.count - visibleInsights.count)

        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "lightbulb.fill", title: Copy.Insights.MetricDetail.insights)

            VStack(spacing: 0) {
                ForEach(Array(visibleInsights.enumerated()), id: \.element.id) { index, insight in
                    sectionRow(
                        icon: insight.metric.systemImageName,
                        iconColor: insight.metric.category.color,
                        text: insightActionText(insight),
                        detail: "\(insight.metric.displayName)  ·  \(insight.severity.displayName)",
                        detailColor: insight.severity.color
                    )

                    if index < visibleInsights.count - 1 {
                        Divider().padding(.leading, Self.rowDividerLeading)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)

            if hiddenInsights > 0 {
                LockedInsightsCTA(hiddenCount: hiddenInsights)
                    .padding(.horizontal)
            }
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
