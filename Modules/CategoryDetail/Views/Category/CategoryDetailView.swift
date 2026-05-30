import SwiftUI

/// Detail view for a health category showing score, analytics, trends, and all metrics
struct CategoryDetailView: View {
    @State var viewModel: CategoryDetailViewModel

    @State private var scoreTracker = SectionTracker(section: .categoryDetailScore, tab: .categoryDetail)
    @State private var analyticsTracker = SectionTracker(section: .categoryDetailAnalytics, tab: .categoryDetail)
    @State private var historyTracker = SectionTracker(section: .categoryDetailHistory, tab: .categoryDetail)
    @State private var insightsTracker = SectionTracker(section: .categoryDetailInsights, tab: .categoryDetail)
    @State private var metricsTracker = SectionTracker(section: .categoryDetailMetrics, tab: .categoryDetail)

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // Category Score (timeframe-independent overall score)
                if let score = viewModel.categoryScore {
                    HealthScoreRing(
                        score: score.score,
                        label: viewModel.category.displayName,
                        size: 120,
                        lineWidth: 10
                    )
                    .padding(.top)
                    .onAppear { scoreTracker.appeared() }
                    .onDisappear { scoreTracker.disappeared() }
                }

                // Historical highlights for this category
                if !viewModel.historicalHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: DS.space2) {
                        HStack(spacing: DS.space2) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.tint)
                            Text(Copy.CategoryDetail.fromYourHistory)
                                .font(DS.Typography.headline)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(viewModel.historicalHighlights, id: \.metric) { item in
                                NavigationLink(value: item.metric) {
                                    HStack(spacing: DS.itemSpacing) {
                                        Image(systemName: item.icon)
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(.tint)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: DS.space1 / 2) {
                                            Text(item.metric.displayName)
                                                .font(DS.Typography.caption)
                                                .foregroundStyle(AppColour.textSecondary)
                                            Text(item.text)
                                                .font(DS.Typography.subheadlineMedium)
                                                .foregroundStyle(AppColour.textPrimary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(DS.Typography.caption2)
                                            .foregroundStyle(AppColour.textTertiary)
                                    }
                                    .padding(.horizontal, DS.cardPadding)
                                    .padding(.vertical, DS.space3 - DS.space1 / 2)
                                }
                                .buttonStyle(.dsPress)
                                .contentShape(Rectangle())
                            }
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }
                    .onAppear { historyTracker.appeared() }
                    .onDisappear { historyTracker.disappeared() }
                }

                // Insights for this category
                if !viewModel.insights.isEmpty {
                    let displayLimit = FeatureGate.isFreeTier ? FeatureGate.insightLimit : Int.max
                    let visibleInsights = Array(viewModel.insights.prefix(displayLimit))
                    let hiddenInsights = max(0, viewModel.insights.count - visibleInsights.count)

                    VStack(alignment: .leading, spacing: DS.itemSpacing) {
                        Text(Copy.CategoryDetail.insights)
                            .font(DS.Typography.headline)
                            .padding(.horizontal)

                        ForEach(visibleInsights) { insight in
                            Button {
                                AppAnalytics.shared.trackInsightTapped(
                                    category: insight.category.rawValue,
                                    severity: insight.severity.rawValue,
                                    metric: insight.metric.rawValue,
                                    screen: .categoryDetail
                                )
                                insightsTracker.tapped(target: insight.metric.rawValue)
                            } label: {
                                InsightCard(insight: insight)
                            }
                            .buttonStyle(.dsPress)
                            .padding(.horizontal)
                        }

                        if hiddenInsights > 0 {
                            LockedInsightsCTA(hiddenCount: hiddenInsights)
                                .padding(.horizontal)
                        }
                    }
                    .onAppear { insightsTracker.appeared() }
                    .onDisappear { insightsTracker.disappeared() }
                }

                // Time Range Selector — grouped with the timeframe-aware
                // sections below (counters + per-metric values + trends) so
                // tapping a range visibly refreshes the cluster it controls.
                TimeRangeSelector(selectedDays: Binding(
                    get: { viewModel.selectedTimeRange },
                    set: { newRange in
                        let oldRange = viewModel.selectedTimeRange
                        viewModel.selectedTimeRange = newRange
                        if oldRange != newRange {
                            AppAnalytics.shared.trackTimeRangeChanged(
                                screen: .categoryDetail,
                                context: viewModel.category.displayName,
                                fromDays: oldRange,
                                toDays: newRange
                            )
                            AppAnalytics.shared.trackCoreAction(.changedTimeRange, screen: .categoryDetail)
                        }
                    }
                ))
                .padding(.horizontal)

                // Category Analytics Summary (Improving/Stable/Declining + attention badge)
                categoryAnalyticsSection
                    .onAppear { analyticsTracker.appeared() }
                    .onDisappear { analyticsTracker.disappeared() }

                // Metric List. sorted by severity
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    HStack {
                        Text(Copy.CategoryDetail.metrics)
                            .font(DS.Typography.headline)

                        Spacer()

                        Text(Copy.Common.activeText(viewModel.activeMetricCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    .padding(.horizontal)

                    ForEach(viewModel.metricsSortedBySeverity) { metric in
                        NavigationLink(value: metric) {
                            metricRow(metric)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.dsPress)
                        .accessibilityIdentifier("category.metric.\(metric.rawValue)")
                    }
                }
                .onAppear { metricsTracker.appeared() }
                .onDisappear { metricsTracker.disappeared() }

                Text(Copy.Analysis.RiskDetail.disclaimer)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                    .padding(.top, DS.space6)
                    .padding(.bottom, DS.space4)
            }
            .padding(.bottom)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(viewModel.category.displayName)
        .accessibilityIdentifier("screen.categoryDetail")
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.categoryDetail, metadata: [
                "category": viewModel.category.displayName,
                "insight_count": viewModel.insights.count
            ])
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.categoryDetail, metadata: ["category": viewModel.category.displayName]) }
    }

    // MARK: - Category Analytics

    private var categoryAnalyticsSection: some View {
        VStack(spacing: DS.itemSpacing) {
            // Trend summary counters
            let trends = viewModel.trendSummary
            HStack(spacing: 0) {
                analyticsPill(
                    count: trends.improving,
                    label: "Improving",
                    icon: "arrow.up.right",
                    color: AppColour.success
                )
                Divider().frame(height: DS.dividerHeight)
                analyticsPill(
                    count: trends.stable,
                    label: "Stable",
                    icon: "arrow.right",
                    color: AppColour.textSecondary
                )
                Divider().frame(height: DS.dividerHeight)
                analyticsPill(
                    count: trends.declining,
                    label: "Declining",
                    icon: "arrow.down.right",
                    color: AppColour.danger
                )
            }
            .padding(.vertical, DS.space3 - DS.space1 / 2)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal)

            // Anomaly count badge
            if viewModel.anomalousMetricCount > 0 {
                HStack(spacing: DS.space2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.warning)
                    Text("\(viewModel.anomalousMetricCount) metric\(viewModel.anomalousMetricCount == 1 ? "" : "s") need\(viewModel.anomalousMetricCount == 1 ? "s" : "") attention")
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(AppColour.textSecondary)
                }
                .padding(.horizontal, DS.cardPadding)
                .padding(.vertical, DS.space2)
                .background(AppColour.warning.opacity(DS.badgeBg), in: Capsule())
                .padding(.horizontal)
            }
        }
    }

    private func analyticsPill(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.space1) {
            HStack(spacing: DS.space1) {
                Image(systemName: icon)
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(color)
                Text(Copy.Common.xText(count))
                    .font(DS.Typography.title3)
            }
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Common.metricsLabel(count, label.lowercased()))
    }

    // MARK: - Metric Row

    private func metricRow(_ metric: HealthMetric) -> some View {
        HStack {
            Image(systemName: metric.systemImageName)
                .font(DS.Typography.body)
                .foregroundStyle(viewModel.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: DS.space1 / 2) {
                Text(metric.displayName)
                    .font(DS.Typography.subheadlineMedium)

                if let severity = viewModel.severity(for: metric) {
                    SeverityBadge(severity: severity)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.space1 / 2) {
                Text(Copy.Common.xText2(viewModel.valueForRange(for: metric), metric.unit))
                    .font(DS.Typography.subheadlineSemibold)

                HStack(spacing: DS.space1) {
                    if let trend = viewModel.trend(for: metric) {
                        TrendBadge(
                            direction: trend,
                            numericChange: viewModel.numericWeekOverWeekChange(for: metric)
                        )
                    }

                    let wow = viewModel.weekOverWeekChange(for: metric)
                    if wow != "--" {
                        Text(wow)
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Common.xLabel(metric.displayName, viewModel.valueForRange(for: metric), metric.unit))
        .accessibilityHint(Copy.Common.viewDetailsHint(metric.displayName))
    }
}

#Preview {
    NavigationStack {
        let hkManager = HealthKitManager()
        let engine = AnalysisEngine()

        CategoryDetailView(
            viewModel: CategoryDetailViewModel(
                category: .heart,
                healthKitManager: hkManager,
                analysisEngine: engine
            )
        )
    }
}
