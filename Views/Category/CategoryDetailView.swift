import SwiftUI

/// Detail view for a health category showing score, analytics, trends, and all metrics
struct CategoryDetailView: View {
    let viewModel: CategoryDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Category Score
                if let score = viewModel.categoryScore {
                    HealthScoreRing(
                        score: score.score,
                        label: viewModel.category.displayName,
                        size: 120,
                        lineWidth: 10
                    )
                    .padding(.top)
                }

                // Category Analytics Summary
                categoryAnalyticsSection

                // Time Range Selector
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

                // Historical highlights for this category
                if !viewModel.historicalHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                            Text("From Your History")
                                .font(.headline)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(viewModel.historicalHighlights, id: \.metric) { item in
                                NavigationLink(value: item.metric) {
                                    HStack(spacing: 10) {
                                        Image(systemName: item.icon)
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.metric.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(item.text)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }
                }

                // Insights for this category
                if !viewModel.insights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Insights")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.insights) { insight in
                            InsightCard(insight: insight)
                                .padding(.horizontal)
                                .onTapGesture {
                                    AppAnalytics.shared.trackInsightTapped(
                                        category: insight.category.rawValue,
                                        severity: insight.severity.rawValue,
                                        metric: insight.metric.rawValue,
                                        screen: .categoryDetail
                                    )
                                }
                        }
                    }
                }

                // Metric List — sorted by severity
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Metrics")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.activeMetricCount) active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    ForEach(viewModel.metricsSortedBySeverity) { metric in
                        NavigationLink(value: metric) {
                            metricRow(metric)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            AppAnalytics.shared.trackBlockTap(title: metric.displayName, type: .metricRow, screen: .categoryDetail)
                        })
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.category.displayName)
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
        VStack(spacing: 12) {
            // Trend summary counters
            let trends = viewModel.trendSummary
            HStack(spacing: 0) {
                analyticsPill(
                    count: trends.improving,
                    label: "Improving",
                    icon: "arrow.up.right",
                    color: .green
                )
                Divider().frame(height: 36)
                analyticsPill(
                    count: trends.stable,
                    label: "Stable",
                    icon: "arrow.right",
                    color: .secondary
                )
                Divider().frame(height: 36)
                analyticsPill(
                    count: trends.declining,
                    label: "Declining",
                    icon: "arrow.down.right",
                    color: .red
                )
            }
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Anomaly count badge
            if viewModel.anomalousMetricCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("\(viewModel.anomalousMetricCount) metric\(viewModel.anomalousMetricCount == 1 ? "" : "s") need\(viewModel.anomalousMetricCount == 1 ? "s" : "") attention")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: Capsule())
                .padding(.horizontal)
            }
        }
    }

    private func analyticsPill(count: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Text("\(count)")
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) metrics \(label.lowercased())")
    }

    // MARK: - Metric Row

    private func metricRow(_ metric: HealthMetric) -> some View {
        HStack {
            Image(systemName: metric.systemImageName)
                .font(.body)
                .foregroundStyle(viewModel.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.displayName)
                    .font(.subheadline.weight(.medium))

                if let severity = viewModel.severity(for: metric) {
                    SeverityBadge(severity: severity)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.latestValue(for: metric)) \(metric.unit)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())

                HStack(spacing: 4) {
                    if let trend = viewModel.trend(for: metric) {
                        TrendBadge(direction: trend)
                    }

                    let wow = viewModel.weekOverWeekChange(for: metric)
                    if wow != "--" {
                        Text(wow)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.displayName), \(viewModel.latestValue(for: metric)) \(metric.unit)")
        .accessibilityHint("View \(metric.displayName) details")
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
