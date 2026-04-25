import SwiftUI
import SwiftData

/// Time-range comparison section: 7D/30D/3M/6M tabs with focus-filtered metric rows
struct PeriodSummarySection: View {
    let viewModel: DashboardViewModel
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space3) {
            Text(Copy.Home.trends)
                .font(DS.Typography.title3)
                .padding(.horizontal, DS.screenPadding)

            // Period picker
            Picker("Period", selection: Binding(
                get: { viewModel.ui.selectedPeriod },
                set: { viewModel.ui.selectedPeriod = $0 }
            )) {
                ForEach(DashboardViewModel.TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.screenPadding)
            .sensoryFeedback(.selection, trigger: viewModel.ui.selectedPeriod)
            .accessibilityLabel("Time period selector")
            .onChange(of: viewModel.ui.selectedPeriod) { oldPeriod, newPeriod in
                AppAnalytics.shared.trackBlockTap(
                    title: newPeriod.rawValue,
                    type: .periodSelector,
                    screen: .home,
                    metadata: [
                        "from_period": oldPeriod.rawValue,
                        "to_period": newPeriod.rawValue
                    ]
                )
            }

            let summary = viewModel.focusFilteredPeriodSummary(for: viewModel.ui.selectedPeriod)

            // Metric rows. declined first, then improved, capped at 4
            let allChanges = (summary.topDeclined + summary.topImproved)
                .sorted { abs($0.changePercent) > abs($1.changePercent) }
            let visibleChanges = Array(allChanges.prefix(4))

            if !visibleChanges.isEmpty {
                VStack(spacing: 8) {
                    ForEach(visibleChanges) { change in
                        let nudge: String? = (!change.improved && abs(change.changePercent) > 2)
                            ? MetricChangeRow.nudgeFor(change.metric)
                            : nil
                        MetricChangeRow(change: change, actionNudge: nudge) {
                            AppAnalytics.shared.trackBlockTap(
                                title: change.metric.displayName,
                                type: .metricRow,
                                screen: .home,
                                metadata: [
                                    "metric_id": change.metric.rawValue,
                                    "metric_category": change.metric.category.rawValue,
                                    "period": viewModel.ui.selectedPeriod.rawValue
                                ]
                            )
                            onTapMetric(change.metric)
                        }
                    }
                }
                .padding(.horizontal, DS.screenPadding)
            }
        }
    }
}

/// Counter pill showing improved/stable/declined count. tappable to filter
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
            VStack(spacing: DS.space1) {
                HStack(spacing: DS.space1) {
                    Image(systemName: icon)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(color)
                    Text("\(count)")
                        .font(DS.Typography.displayS)
                        .foregroundStyle(AppColour.textPrimary)
                }
                Text(label)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space1)
            .background(isSelected ? color.opacity(DS.badgeBg) : .clear, in: RoundedRectangle(cornerRadius: 8))
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
        if isStable { return AppColour.textSecondary }
        return change.improved ? AppColour.success : AppColour.danger
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
                    .font(.system(size: 14.4).weight(.semibold))
                    .foregroundStyle(categoryColor)
                    .frame(width: 20)

                // Metric name + current value + nudge
                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(change.metric.displayName)
                        .font(DS.Typography.bodyMedium)
                        .foregroundStyle(AppColour.textPrimary)

                    Text("\(formattedAvg) \(change.metric.unit)")
                        .font(DS.Typography.footnote.monospacedDigit())
                        .foregroundStyle(AppColour.textSecondary)

                    if let nudge = actionNudge {
                        Text(nudge)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.warning)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer()

                // Change percentage
                HStack(spacing: DS.space1) {
                    Image(systemName: changeIcon)
                        .font(DS.Typography.captionSemibold)

                    Text(String(format: "%.1f%%", abs(change.changePercent)))
                        .font(DS.Typography.calloutSemibold.monospacedDigit())
                }
                .foregroundStyle(changeColor)
                .padding(.horizontal, DS.badgeH)
                .padding(.vertical, DS.badgeV)
                .background(
                    changeColor.opacity(DS.badgeBg),
                    in: Capsule()
                )

                Image(systemName: "chevron.right")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textTertiary)
            }
            .padding(.vertical, DS.space2)
            .padding(.horizontal, DS.space3)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.iconRadius))
        }
        .buttonStyle(.dsPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(change.metric.displayName), \(formattedAvg) \(change.metric.unit), \(isStable ? "stable" : change.improved ? "improved" : "declined") \(String(format: "%.1f", abs(change.changePercent))) percent")
        .accessibilityHint("View \(change.metric.displayName) details")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    PeriodSummarySection(
        viewModel: DashboardViewModel(
            healthKitManager: HealthKitManager(),
            analysisEngine: AnalysisEngine(),
            store: HealthDataStore(modelContainer: container),
            housekeepingService: DashboardHousekeepingService(
                persistenceManager: PersistenceManager(),
                analytics: AppAnalytics.shared,
                sessionTracker: SessionTracker.shared
            )
        ),
        onTapMetric: { _ in }
    )
}
