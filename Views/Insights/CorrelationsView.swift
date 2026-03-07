import SwiftUI

/// Full-screen view for browsing all discovered health correlations with filtering
struct CorrelationsView: View {
    let correlations: [HealthCorrelation]
    let onTapMetric: (HealthMetric) -> Void

    /// Guard against free-tier access via deep navigation
    private var isGated: Bool { !FeatureGate.canAccess(.advancedAnalytics) }

    @State private var selectedFilter: CorrelationFilter = .all
    @State private var filtersTracker = SectionTracker(section: .correlationsFilters, tab: .correlations)
    @State private var listTracker = SectionTracker(section: .correlationsList, tab: .correlations)

    enum CorrelationFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case strong = "Strong"
        case moderate = "Moderate"
        case sleepRecovery = "Sleep"
        case exercise = "Exercise"
        case body = "Body"

        var id: String { rawValue }
    }

    var body: some View {
        if isGated {
            ProFeatureOverlay(
                feature: "Correlations",
                icon: "arrow.triangle.branch",
                description: "Discover how your health metrics influence each other."
            )
        }
        ScrollView {
            VStack(spacing: 16) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CorrelationFilter.allCases) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                count: filteredCount(for: filter)
                            ) {
                                let oldFilter = selectedFilter
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                                if oldFilter != filter {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: filter.rawValue,
                                        type: .correlationFilterChip,
                                        screen: .correlations,
                                        metadata: [
                                            "from_filter": oldFilter.rawValue,
                                            "to_filter": filter.rawValue,
                                            "results_count": filteredCount(for: filter)
                                        ]
                                    )
                                    filtersTracker.tapped(target: filter.rawValue.lowercased())
                                    AppAnalytics.shared.trackFilterChanged(
                                        screen: .correlations,
                                        filterType: "correlation_strength",
                                        from: oldFilter.rawValue,
                                        to: filter.rawValue
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear { filtersTracker.appeared() }
                .onDisappear { filtersTracker.disappeared() }

                if filteredCorrelations.isEmpty {
                    emptyState
                } else {
                    // Correlation list
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCorrelations) { correlation in
                            CorrelationDetailCard(correlation: correlation) {
                                AppAnalytics.shared.trackCorrelationTapped(
                                    metricA: correlation.metricA.rawValue,
                                    metricB: correlation.metricB.rawValue,
                                    strength: correlation.strengthLabel,
                                    screen: .correlations
                                )
                                listTracker.tapped(target: "\(correlation.metricA.rawValue)_\(correlation.metricB.rawValue)")
                                onTapMetric(correlation.metricA)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .onAppear { listTracker.appeared() }
                    .onDisappear { listTracker.disappeared() }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("What Affects What")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.correlations)
            AppAnalytics.shared.trackActivationMilestone(.firstCorrelation)
            AppAnalytics.shared.trackCoreAction(.viewedCorrelation, screen: .correlations)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "viewed_correlation", screen: .correlations)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.correlations) }
    }

    // MARK: - Filtering

    private var filteredCorrelations: [HealthCorrelation] {
        switch selectedFilter {
        case .all:
            return correlations
        case .strong:
            return correlations.filter { $0.strengthLabel == "Strong" }
        case .moderate:
            return correlations.filter { $0.strengthLabel == "Moderate" }
        case .sleepRecovery:
            return correlations.filter { $0.metricA.category == .sleep || $0.metricB.category == .sleep }
        case .exercise:
            return correlations.filter { $0.metricA.category == .activity || $0.metricB.category == .activity }
        case .body:
            return correlations.filter { $0.metricA.category == .body || $0.metricB.category == .body }
        }
    }

    private func filteredCount(for filter: CorrelationFilter) -> Int {
        switch filter {
        case .all:
            return correlations.count
        case .strong:
            return correlations.filter { $0.strengthLabel == "Strong" }.count
        case .moderate:
            return correlations.filter { $0.strengthLabel == "Moderate" }.count
        case .sleepRecovery:
            return correlations.filter { $0.metricA.category == .sleep || $0.metricB.category == .sleep }.count
        case .exercise:
            return correlations.filter { $0.metricA.category == .activity || $0.metricB.category == .activity }.count
        case .body:
            return correlations.filter { $0.metricA.category == .body || $0.metricB.category == .body }.count
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No correlations found")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Try a different filter or wait for more data to accumulate.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))

                if count > 0 && isSelected {
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Card

/// Actionable correlation card — leads with "do this → get this"
private struct CorrelationDetailCard: View {
    let correlation: HealthCorrelation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Action: what to do → what happens
                HStack(spacing: 8) {
                    Image(systemName: correlation.metricA.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(correlation.metricA.category.color)
                        .frame(width: 24)

                    Text(correlation.causeLabel)
                        .font(.subheadline.weight(.medium))

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.purple)

                    Image(systemName: correlation.metricB.systemImageName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(correlation.metricB.category.color)
                        .frame(width: 24)

                    Text(correlation.effectLabel)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    Spacer()
                }

                // What your data shows
                Text(correlation.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Bottom: strength + timing + chevron
                HStack(spacing: 8) {
                    StrengthBadge(label: correlation.strengthLabel)

                    Text(correlation.dayOffset == 0 ? "Same day" : "Next day effect")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(correlation.causeLabel) leads to \(correlation.effectLabel)")
        .accessibilityValue("\(correlation.strengthLabel) link, \(correlation.effectSummary)")
        .accessibilityHint("View \(correlation.metricA.displayName) details")
        .accessibilityAddTraits(.isButton)
    }
}
