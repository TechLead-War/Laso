import SwiftUI

/// Full-screen view for browsing all discovered health correlations with filtering
struct CorrelationsView: View {
    let correlations: [HealthCorrelation]
    let onTapMetric: (HealthMetric) -> Void

    @State private var selectedFilter: CorrelationFilter = .all

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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if filteredCorrelations.isEmpty {
                    emptyState
                } else {
                    // Correlation list
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCorrelations) { correlation in
                            CorrelationDetailCard(correlation: correlation) {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "\(correlation.causeLabel) \u{2192} \(correlation.effectLabel)",
                                    type: .correlationCard,
                                    screen: .correlations
                                )
                                onTapMetric(correlation.metricA)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Correlations")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.correlations) }
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

/// Expanded correlation card for the full-screen view
private struct CorrelationDetailCard: View {
    let correlation: HealthCorrelation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Metric A → Metric B header
                HStack(spacing: 10) {
                    metricLabel(
                        icon: correlation.metricA.systemImageName,
                        name: correlation.metricA.displayName,
                        color: correlation.metricA.category.color
                    )

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.purple)

                    metricLabel(
                        icon: correlation.metricB.systemImageName,
                        name: correlation.metricB.displayName,
                        color: correlation.metricB.category.color
                    )

                    Spacer()

                    StrengthBadge(label: correlation.strengthLabel)
                }

                // Cause → Effect labels
                HStack(spacing: 6) {
                    Text(correlation.causeLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Text(correlation.effectLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                // Effect summary
                Text(correlation.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Bottom row: offset label + correlation value + chevron
                HStack {
                    Label(
                        correlation.dayOffset == 0 ? "Same day" : "Next day effect",
                        systemImage: correlation.dayOffset == 0 ? "calendar" : "calendar.badge.clock"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("r = \(String(format: "%.2f", correlation.correlation))")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(correlation.causeLabel) leads to \(correlation.effectLabel)")
        .accessibilityValue("\(correlation.strengthLabel) correlation, \(correlation.effectSummary)")
        .accessibilityHint("View \(correlation.metricA.displayName) details")
        .accessibilityAddTraits(.isButton)
    }

    private func metricLabel(icon: String, name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
