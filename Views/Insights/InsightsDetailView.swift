import SwiftUI

/// Full-screen view showing all analysis insights organized by type,
/// with both actionable items and data discoveries.
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void
    var headlineSummary: String?

    @State private var selectedTab: InsightTab = .actionItems
    @State private var selectedFilter: FocusFilter = .all

    // Section trackers
    @State private var sectionTracker = SectionTracker(section: .insightsActionItems, tab: .insightsDetail)

    var store: HealthDataStore?

    enum InsightTab: String, CaseIterable, Identifiable {
        case actionItems = "Action Items"
        case allInsights = "All Insights"

        var id: String { rawValue }
    }

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
            case .body: return [.body, .respiratory, .mindfulness, .mobility]
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
            .filter { InsightGenerator.actionabilityScore($0) >= 20 }
            .sorted { lhs, rhs in
                let lScore = InsightGenerator.actionabilityScore(lhs)
                let rScore = InsightGenerator.actionabilityScore(rhs)
                if lScore != rScore { return lScore > rScore }
                return lhs.priorityScore > rhs.priorityScore
            }
    }

    private var actionableItems: [Insight] {
        allInsights
            .filter { $0.severity == .critical || $0.severity == .warning }
            .filter { !isGenericAdvice($0.recommendation) }
    }

    /// High-confidence actionable items — must also pass actionability threshold
    private var highConfidenceActions: [Insight] {
        guard let topScore = actionableItems.first?.priorityScore, topScore > 0 else { return [] }
        let threshold = topScore * 0.4
        let filtered = actionableItems.filter {
            $0.priorityScore >= threshold && InsightGenerator.actionabilityScore($0) >= 40
        }
        return Array(filtered.prefix(5))
    }

    /// Currently displayed items based on tab and filter
    private var displayedItems: [Insight] {
        let base = selectedTab == .actionItems ? highConfidenceActions : allInsights
        if selectedFilter == .all { return base }
        let cats = selectedFilter.categories
        return base.filter { cats.contains($0.metric.category) }
    }

    private func count(for filter: FocusFilter) -> Int {
        let base = selectedTab == .actionItems ? highConfidenceActions : allInsights
        if filter == .all { return base.count }
        let cats = filter.categories
        return base.filter { cats.contains($0.metric.category) }.count
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

                // Tab picker: Action Items vs All Insights
                Picker("View", selection: $selectedTab) {
                    ForEach(InsightTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

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
                            store?.recordRecommendationTapped(insightId: insight.id)
                            onTapMetric(insight.metric)
                        } label: {
                            EnrichedInsightCard(insight: insight, showCategory: selectedTab == .allInsights)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: selectedTab == .actionItems ? "checkmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(selectedTab == .actionItems ? .green : .secondary)
                        Text(selectedTab == .actionItems ? "You're all good" : "No insights yet")
                            .font(.title3.weight(.semibold))
                        Text(selectedTab == .actionItems
                             ? (selectedFilter == .all
                                ? "Nothing needs your attention right now."
                                : "Nothing in \(selectedFilter.rawValue) needs attention.")
                             : "More data will unlock deeper insights over time.")
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
                "total_count": allInsights.count,
                "actionable_count": highConfidenceActions.count
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstInsightViewed)
            AppAnalytics.shared.trackCoreAction(.viewedInsight, screen: .insightsDetail)
            sectionTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.insightsDetail)
            sectionTracker.disappeared()
        }
        .onChange(of: selectedTab) { _, newTab in
            sectionTracker.disappeared()
            sectionTracker = SectionTracker(
                section: newTab == .actionItems ? .insightsActionItems : .insightsAllInsights,
                tab: .insightsDetail
            )
            sectionTracker.appeared()
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
                    "insight_tab": selectedTab.rawValue,
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

    // MARK: - Helpers

    private func isGenericAdvice(_ text: String) -> Bool {
        let lower = text.lowercased()
        let genericStarters = ["monitor ", "track ", "continue ", "keep an eye", "your .* is healthy", "your .* is normal"]
        return genericStarters.contains { starter in
            lower.hasPrefix(starter) || lower.range(of: "^" + starter, options: .regularExpression) != nil
        }
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
