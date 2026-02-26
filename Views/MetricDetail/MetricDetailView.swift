import SwiftUI
import Charts

/// Deep-dive view for a single metric with charts, stats, moving averages, baselines, and insights
struct MetricDetailView: View {
    let viewModel: MetricDetailViewModel
    var deviceSourceManager: DeviceSourceManager? = nil

    @State private var autoExpandedRange: Int?

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
                            }
                        }
                    ))
                    .padding(.horizontal)

                    // Chart
                    chartSection

                    // Contextual Summary (replaces raw stats grid)
                    contextualSummary

                    // Score Breakdown
                    if !viewModel.scoreBreakdown.isEmpty {
                        scoreBreakdownSection
                    }

                    // Insights
                    if !viewModel.insights.isEmpty {
                        insightsSection
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
            AppAnalytics.shared.trackFeatureOpen(.metricDetail, metadata: ["metric": viewModel.metric.rawValue])
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

            Text("We don't have enough \(viewModel.metric.displayName.lowercased()) data to show trends. Make sure your device is syncing to Apple Health.")
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
        .onAppear {
            AppAnalytics.shared.trackEmptyStateShown(screen: .metricDetail, stateType: "no_metric_data")
        }
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
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
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.metric.displayName), current value \(viewModel.currentValue) \(viewModel.metric.unit), \(viewModel.trendDirection == .improving ? "improving" : viewModel.trendDirection == .declining ? "declining" : "stable")\(viewModel.isOutsideNormalRange ? ", outside normal range" : "")")
    }

    private var chartSection: some View {
        VStack(alignment: .leading) {
            MetricChartView(
                samples: viewModel.chartSamples,
                metric: viewModel.metric,
                baseline: viewModel.baseline?.mean,
                normalRange: viewModel.normalRange
            )
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
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
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var scoreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score Impact")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(viewModel.scoreBreakdown) { component in
                    HStack {
                        Image(systemName: component.points >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(component.points >= 0 ? .green : .red)
                            .font(.body)

                        Text(component.reason)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(component.points > 0 ? "+" : "")\(component.points) pts")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(component.points >= 0 ? .green : .red)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(viewModel.insights) { insight in
                    InsightCard(insight: insight)
                }
            }
            .padding(.horizontal)
        }
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
