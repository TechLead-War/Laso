import SwiftUI

/// Full-screen view showing all analysis insights. explains why things are happening.
/// The Today screen tells you what to do; this screen tells you why.
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void
    var headlineSummary: String?
    /// Timestamp of the parent dashboard's most recent refresh.
    /// Drives a small "Updated …" caption at the top of the screen.
    var lastUpdated: Date? = nil

    @State private var selectedFilter: FocusFilter = .all
    @State private var showAhaPaywall = false

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
            case .all: return AppColour.info
            case .sleep: return AppColour.categorySleep
            case .activity: return AppColour.categoryActivity
            case .heart: return AppColour.categoryHeart
            case .body: return AppColour.warning
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
            VStack(alignment: .leading, spacing: DS.space4) {
                // Headline summary from the Home card (shown in full here)
                if let headline = headlineSummary {
                    Text(headline)
                        .font(DS.Typography.subheadlineMedium)
                        .foregroundStyle(AppColour.textSecondary)
                        .padding(.horizontal)
                }

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.space2) {
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
                    let displayLimit = FeatureGate.isFreeTier ? FeatureGate.insightLimit : Int.max
                    let visibleItems = Array(displayedItems.prefix(displayLimit))
                    let hiddenItems = max(0, displayedItems.count - visibleItems.count)

                    ForEach(visibleItems) { insight in
                        Button {
                            AppAnalytics.shared.trackInsightOpened(
                                metricCategory: insight.metric.category
                            )
                            store?.recordRecommendationTapped(insightId: insight.id)
                            onTapMetric(insight.metric)
                        } label: {
                            EnrichedInsightCard(insight: insight, showCategory: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.dsPress)
                        .padding(.horizontal)
                    }

                    if hiddenItems > 0 {
                        LockedInsightsCTA(hiddenCount: hiddenItems)
                            .padding(.horizontal)
                    }
                } else {
                    DSEmptyState(
                        icon: "magnifyingglass",
                        title: Copy.Insights.Detail.emptyTitle,
                        message: selectedFilter == .all
                            ? Copy.Insights.Detail.emptyMessageAll
                            : Copy.Insights.Detail.emptyMessageFiltered(selectedFilter.rawValue.lowercased())
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.space7)
                }

                Text(Copy.Analysis.RiskDetail.disclaimer)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                    .padding(.top, DS.space6)
                    .padding(.bottom, DS.space4)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Insights.Detail.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.insightsDetail, metadata: [
                "total_count": allInsights.count
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstInsightViewed)
            AppAnalytics.shared.trackCoreAction(.viewedInsight, screen: .insightsDetail)
            sectionTracker.appeared()
            maybeShowAhaPaywall()
        }
        .fullScreenCover(isPresented: $showAhaPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared, source: "aha_moment")
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

    // MARK: - Aha Paywall Trigger

    /// Hard paywall after the aha moment (`first_insight_viewed`). Published PMF
    /// research: health & fitness top-decile trial→paid is 68%, and 80–90% of
    /// trials start Day 0 — so the highest-ROI paywall surface is immediately
    /// after the user experiences personal value for the first time.
    /// Only fires once per user (UserDefault-gated) and only for users without
    /// active access (i.e. not currently in trial / subscribed / billing grace).
    private func maybeShowAhaPaywall() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: AppKeys.Session.ahaPaywallShown) {
            return
        }
        guard !SubscriptionManager.shared.hasAccess else {
            // Already a paying / trialing user — don't show. Mark seen so we
            // never re-evaluate when their status changes later.
            defaults.set(true, forKey: AppKeys.Session.ahaPaywallShown)
            return
        }
        defaults.set(true, forKey: AppKeys.Session.ahaPaywallShown)
        // paywall_viewed fires once from PaywallView.onAppear with source
        // "aha_moment" passed into the fullScreenCover above. Do not emit it
        // here too, or the aha path double-fires the event.
        showAhaPaywall = true
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
            HStack(spacing: DS.space1) {
                Text(filter.rawValue)
                    .font(selectedFilter == filter ? DS.Typography.subheadlineSemibold : DS.Typography.subheadline)

                if count > 0 && selectedFilter == filter {
                    Text(Copy.Insights.xText(count))
                        .font(DS.Typography.caption2Semibold.monospacedDigit())
                }
            }
            .foregroundStyle(selectedFilter == filter ? .white : AppColour.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, DS.space2)
            .background(selectedFilter == filter ? filter.chipColor : AppColour.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.dsPress)
    }

}

/// Enriched insight card showing category badge, action text, and quantified impact
private struct EnrichedInsightCard: View {
    let insight: Insight
    let showCategory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            // Top: metric icon + category + severity
            HStack(spacing: DS.space3) {
                Image(systemName: insight.metric.systemImageName)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(insight.metric.category.color, in: Circle())

                VStack(alignment: .leading, spacing: DS.space1) {
                    HStack(spacing: DS.space2) {
                        Text(insight.metric.displayName)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)

                        if showCategory {
                            Text(insight.category.displayName)
                                .font(DS.Typography.caption2Semibold)
                                .foregroundStyle(insight.category.color)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(insight.category.color.opacity(DS.badgeBg), in: Capsule())
                        }
                    }

                    Text(impactText)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(severityColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(.tertiary)
            }

            // Title
            Text(insight.title)
                .font(DS.Typography.subheadlineMedium)
                .foregroundStyle(AppColour.textPrimary)
                .lineLimit(2)

            // Action text
            if !actionText.isEmpty {
                Text(actionText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private var severityColor: Color {
        switch insight.severity {
        case .critical: return AppColour.danger
        case .warning: return AppColour.warning
        case .info: return AppColour.info
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
