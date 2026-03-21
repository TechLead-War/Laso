import SwiftUI

/// Full-screen view showing all analysis insights. explains why things are happening.
/// The Today screen tells you what to do; this screen tells you why.
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void
    var headlineSummary: String?

    @State private var selectedFilter: FocusFilter = .all

    // Section trackers
    @State private var sectionTracker = SectionTracker(section: .insightsAllInsights, tab: .insightsDetail)

    var store: HealthDataStore?

    // MARK: - Focus Filters

    enum FocusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case sleep = "Sleep"
        case activity = "Activity"
        case heart = "Heart"
        case body = "Body"

        var id: String { rawValue }

        var categories: Set<HealthCategory> {
            switch self {
            case .all: return Set(HealthCategory.allCases)
            case .sleep: return [.sleep]
            case .activity: return [.activity]
            case .heart: return [.heart]
            case .body: return [.body, .respiratory, .mindfulness, .mobility, .hearing]
            }
        }

        var chipColor: Color {
            switch self {
            case .all: return .blue
            case .sleep: return .indigo
            case .activity: return .green
            case .heart: return .red
            case .body: return .orange
            }
        }
    }

    // MARK: - Data Pipeline

    private var allInsights: [Insight] {
        insightsByCategory.flatMap(\.insights)
            .sorted { lhs, rhs in
                if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
                return lhs.priorityScore > rhs.priorityScore
            }
    }

    /// Currently displayed items based on filter
    private var displayedItems: [Insight] {
        if selectedFilter == .all { return allInsights }
        let cats = selectedFilter.categories
        return allInsights.filter { cats.contains($0.metric.category) }
    }

    private func count(for filter: FocusFilter) -> Int {
        if filter == .all { return allInsights.count }
        let cats = filter.categories
        return allInsights.filter { cats.contains($0.metric.category) }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Headline summary from the Home card (shown in full here)
                if let headline = headlineSummary {
                    Text(headline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FocusFilter.allCases) { filter in
                            let itemCount = count(for: filter)
                            if filter == .all || itemCount > 0 {
                                focusChip(filter: filter, count: itemCount)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize)

                if !displayedItems.isEmpty {
                    ForEach(displayedItems) { insight in
                        Button {
                            AppAnalytics.shared.trackInsightTapped(
                                category: insight.category.rawValue,
                                severity: insight.severity.rawValue,
                                metric: insight.metric.rawValue,
                                screen: .insightsDetail
                            )
                            AppAnalytics.shared.trackInsightEngagement(
                                category: insight.category.rawValue,
                                metric: insight.metric.rawValue,
                                action: "tap_detail"
                            )
                            store?.recordRecommendationTapped(insightId: insight.id)
                            onTapMetric(insight.metric)
                        } label: {
                            EnrichedInsightCard(insight: insight, showCategory: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No insights yet")
                            .font(.title3.weight(.semibold))
                        Text(selectedFilter == .all
                             ? "More data will unlock deeper insights over time."
                             : "No \(selectedFilter.rawValue.lowercased()) insights right now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.insightsDetail, metadata: [
                "total_count": allInsights.count
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstInsightViewed)
            AppAnalytics.shared.trackCoreAction(.viewedInsight, screen: .insightsDetail)
            sectionTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.insightsDetail)
            sectionTracker.disappeared()
        }
        .onChange(of: selectedFilter) { oldFilter, newFilter in
            if oldFilter != newFilter {
                AppAnalytics.shared.trackFilterChanged(
                    screen: .insightsDetail,
                    filterType: "focus_filter",
                    from: oldFilter.rawValue,
                    to: newFilter.rawValue
                )
            }
        }
    }

    // MARK: - Filter Chip

    private func focusChip(filter: FocusFilter, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
            AppAnalytics.shared.trackBlockTap(
                title: filter.rawValue,
                type: .trendFilter,
                screen: .insightsDetail,
                metadata: [
                    "filter": filter.rawValue,
                    "results_count": count
                ]
            )
            sectionTracker.tapped(target: "filter_\(filter.rawValue.lowercased())")
        } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.subheadline.weight(selectedFilter == filter ? .semibold : .regular))

                if count > 0 && selectedFilter == filter {
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
            }
            .foregroundStyle(selectedFilter == filter ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedFilter == filter ? filter.chipColor : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

}

/// Enriched insight card showing category badge, action text, and quantified impact
private struct EnrichedInsightCard: View {
    let insight: Insight
    let showCategory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: metric icon + category + severity
            HStack(spacing: 12) {
                Image(systemName: insight.metric.systemImageName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(insight.metric.category.color, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(insight.metric.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if showCategory {
                            Text(insight.category.displayName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(insight.category.color.opacity(DS.badgeBg), in: Capsule())
                        }
                    }

                    Text(impactText)
                        .font(.caption2)
                        .foregroundStyle(severityColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            // Title
            Text(insight.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Action text
            if !actionText.isEmpty {
                Text(actionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var severityColor: Color {
        switch insight.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private var actionText: String {
        let sentences = insight.recommendation.components(separatedBy: ". ")
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.isEmpty { continue }
            // Skip numbered list prefixes like "1", "2"
            if trimmed.allSatisfy(\.isNumber) { continue }
            let isGeneric = lower.hasPrefix("monitor") || lower.hasPrefix("track") ||
                lower.hasPrefix("continue") || lower.hasPrefix("your") ||
                lower.hasPrefix("keep an eye") || lower.hasPrefix("consult")
            if !isGeneric {
                return trimmed.hasSuffix(".") ? trimmed : trimmed + "."
            }
        }
        return ""
    }

    private var impactText: String {
        let dev = abs(insight.deviationPercent)
        if dev > 0.5 {
            let direction = insight.deviationPercent > 0 ? "above" : "below"
            return String(format: "%.0f%% %@ your baseline", dev, direction)
        }
        return insight.trend.displayName
    }
}
