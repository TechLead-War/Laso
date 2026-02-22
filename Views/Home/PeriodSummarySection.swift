import SwiftUI

/// Time-range comparison section: 7D/30D/3M/6M tabs with improved/declined metric counts and top movers
struct PeriodSummarySection: View {
    let viewModel: DashboardViewModel
    let onTapMetric: (HealthMetric) -> Void

    enum MetricFilter: String {
        case improved, stable, declined
    }

    @State private var isExpanded = false
    @State private var activeFilter: MetricFilter?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trends")
                .font(.headline)
                .padding(.horizontal)

            // Period picker
            Picker("Period", selection: Binding(
                get: { viewModel.selectedPeriod },
                set: { viewModel.selectedPeriod = $0 }
            )) {
                ForEach(DashboardViewModel.TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
            .accessibilityLabel("Time period selector")
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                AppAnalytics.shared.trackBlockTap(title: newPeriod.rawValue, type: .periodSelector, screen: .home)
                isExpanded = false
                activeFilter = nil
            }

            let summary = viewModel.periodSummary(for: viewModel.selectedPeriod)

            // Summary counters — tappable to filter
            HStack(spacing: 0) {
                PeriodCounter(
                    count: summary.improvedCount,
                    label: "Improved",
                    icon: "arrow.up.right",
                    color: .green,
                    isSelected: activeFilter == .improved
                ) {
                    AppAnalytics.shared.trackBlockTap(title: "Improved", type: .trendFilter, screen: .home)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        activeFilter = activeFilter == .improved ? nil : .improved
                        isExpanded = false
                    }
                }

                Divider().frame(height: 40)

                PeriodCounter(
                    count: summary.stableCount,
                    label: "Stable",
                    icon: "arrow.right",
                    color: .secondary,
                    isSelected: activeFilter == .stable
                ) {
                    AppAnalytics.shared.trackBlockTap(title: "Stable", type: .trendFilter, screen: .home)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        activeFilter = activeFilter == .stable ? nil : .stable
                        isExpanded = false
                    }
                }

                Divider().frame(height: 40)

                PeriodCounter(
                    count: summary.declinedCount,
                    label: "Declined",
                    icon: "arrow.down.right",
                    color: .red,
                    isSelected: activeFilter == .declined
                ) {
                    AppAnalytics.shared.trackBlockTap(title: "Declined", type: .trendFilter, screen: .home)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        activeFilter = activeFilter == .declined ? nil : .declined
                        isExpanded = false
                    }
                }
            }
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Metric rows based on filter
            let filteredChanges: [DashboardViewModel.MetricChange] = {
                switch activeFilter {
                case .improved:
                    return summary.topImproved
                case .declined:
                    return summary.topDeclined
                case .stable:
                    return summary.stableMetrics
                case nil:
                    // Default: declined first, then improved, sorted by |change| desc
                    return (summary.topDeclined + summary.topImproved)
                        .sorted { abs($0.changePercent) > abs($1.changePercent) }
                }
            }()

            if !filteredChanges.isEmpty {
                let maxCollapsed = 5
                let visibleChanges = isExpanded ? filteredChanges : Array(filteredChanges.prefix(maxCollapsed))

                VStack(spacing: 8) {
                    ForEach(visibleChanges) { change in
                        let nudge: String? = (!change.improved && abs(change.changePercent) > 2)
                            ? MetricChangeRow.nudgeFor(change.metric)
                            : nil
                        MetricChangeRow(change: change, actionNudge: nudge) {
                            AppAnalytics.shared.trackBlockTap(title: change.metric.displayName, type: .metricRow, screen: .home)
                            onTapMetric(change.metric)
                        }
                    }

                    if filteredChanges.count > maxCollapsed {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Show Less" : "Show All \(filteredChanges.count) Changes")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isExpanded ? "Show fewer changes" : "Show all \(filteredChanges.count) changes")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Counter pill showing improved/stable/declined count — tappable to filter
struct PeriodCounter: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                    Text("\(count)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) metrics \(label.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Filter to show \(label.lowercased()) metrics")
    }
}

/// Compact row showing a metric's change over the selected period
struct MetricChangeRow: View {
    let change: DashboardViewModel.MetricChange
    var actionNudge: String?
    let onTap: () -> Void

    /// Extract the first sentence of the recommendation for a declined metric
    static func nudgeFor(_ metric: HealthMetric) -> String? {
        let rec = RulesConfiguration.recommendation(for: metric, severity: .warning, trend: .declining)
        guard let dotIndex = rec.firstIndex(of: ".") else { return rec }
        return String(rec[rec.startIndex...dotIndex])
    }

    private var categoryColor: Color {
        change.metric.category.color
    }

    private var isStable: Bool {
        !change.improved && abs(change.changePercent) <= 2
    }

    private var changeIcon: String {
        if isStable { return "arrow.right" }
        return change.improved ? "arrow.up.right" : "arrow.down.right"
    }

    private var changeColor: Color {
        if isStable { return .secondary }
        return change.improved ? .green : .red
    }

    private var formattedAvg: String {
        let v = change.periodAvg
        if v >= 1000 { return String(format: "%.0f", v) }
        if v >= 10 { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Category color dot
                Circle()
                    .fill(categoryColor)
                    .frame(width: 8, height: 8)

                // Metric icon
                Image(systemName: change.metric.systemImageName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryColor)
                    .frame(width: 20)

                // Metric name + current value + nudge
                VStack(alignment: .leading, spacing: 1) {
                    Text(change.metric.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("\(formattedAvg) \(change.metric.unit)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if let nudge = actionNudge {
                        Text(nudge)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Change percentage
                HStack(spacing: 3) {
                    Image(systemName: changeIcon)
                        .font(.caption2.weight(.bold))

                    Text(String(format: "%.1f%%", abs(change.changePercent)))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(changeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    changeColor.opacity(0.1),
                    in: Capsule()
                )

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(change.metric.displayName), \(formattedAvg) \(change.metric.unit), \(isStable ? "stable" : change.improved ? "improved" : "declined") \(String(format: "%.1f", abs(change.changePercent))) percent")
        .accessibilityHint("View \(change.metric.displayName) details")
    }
}

#Preview {
    PeriodSummarySection(
        viewModel: DashboardViewModel(
            healthKitManager: HealthKitManager(),
            analysisEngine: AnalysisEngine()
        ),
        onTapMetric: { _ in }
    )
}
