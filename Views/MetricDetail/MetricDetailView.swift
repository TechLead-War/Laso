import SwiftUI
import Charts

/// Deep-dive view for a single metric with charts, stats, moving averages, baselines, and insights
struct MetricDetailView: View {
    let viewModel: MetricDetailViewModel
    var deviceSourceManager: DeviceSourceManager? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Value Header
                headerSection

                // Action Banner — show recommendation if insight exists
                if let recommendation = viewModel.insights.first?.recommendation {
                    actionBanner(recommendation)
                }

                // Time Range Selector
                TimeRangeSelector(selectedDays: Binding(
                    get: { viewModel.selectedTimeRange },
                    set: { viewModel.selectedTimeRange = $0 }
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
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.metric.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
        .padding(.top)
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
                .padding(.horizontal)
                .padding(.vertical, 6)
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

            ForEach(viewModel.insights) { insight in
                InsightCard(insight: insight)
                    .padding(.horizontal)
            }
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
