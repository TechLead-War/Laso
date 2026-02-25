import SwiftUI

/// Full-screen view showing actionable items the user can work on right now
struct InsightsDetailView: View {
    let insightsByCategory: [(category: InsightCategory, insights: [Insight])]
    let onTapMetric: (HealthMetric) -> Void

    @State private var selectedFilter: FocusFilter = .all

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

    /// All actionable insights — warning/critical, non-generic, sorted by priority
    private var allActionable: [Insight] {
        insightsByCategory
            .flatMap(\.insights)
            .filter { $0.severity == .critical || $0.severity == .warning }
            .filter { !isGenericAdvice($0.recommendation) }
            .sorted { $0.priorityScore > $1.priorityScore }
    }

    /// High-confidence items only — drop anything below 40% of the top score.
    /// This naturally limits the list to impactful items without a hardcoded cap.
    private var highConfidenceItems: [Insight] {
        guard let topScore = allActionable.first?.priorityScore, topScore > 0 else { return [] }
        let threshold = topScore * 0.4
        return allActionable.filter { $0.priorityScore >= threshold }
    }

    /// Filtered by the selected focus area
    private var filteredItems: [Insight] {
        if selectedFilter == .all { return highConfidenceItems }
        let cats = selectedFilter.categories
        return highConfidenceItems.filter { cats.contains($0.metric.category) }
    }

    private func count(for filter: FocusFilter) -> Int {
        if filter == .all { return highConfidenceItems.count }
        let cats = filter.categories
        return highConfidenceItems.filter { cats.contains($0.metric.category) }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FocusFilter.allCases) { filter in
                            let itemCount = count(for: filter)
                            // Only show filters that have items (always show All)
                            if filter == .all || itemCount > 0 {
                                focusChip(filter: filter, count: itemCount)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if !filteredItems.isEmpty {
                    ForEach(filteredItems) { insight in
                        Button {
                            AppAnalytics.shared.trackBlockTap(title: insight.title, type: .insightCard, screen: .insightsDetail)
                            onTapMetric(insight.metric)
                        } label: {
                            ActionableInsightCard(insight: insight)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("You're all good")
                            .font(.title3.weight(.semibold))
                        Text(selectedFilter == .all
                             ? "Nothing needs your attention right now."
                             : "Nothing in \(selectedFilter.rawValue) needs attention.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        AppAnalytics.shared.trackEmptyStateShown(
                            screen: .insightsDetail,
                            stateType: selectedFilter == .all ? "all_good" : "filter_empty_\(selectedFilter.rawValue.lowercased())"
                        )
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("What To Focus On")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.insightsDetail) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.insightsDetail) }
    }

    // MARK: - Filter Chip

    private func focusChip(filter: FocusFilter, count: Int) -> some View {
        Button {
            let oldFilter = selectedFilter
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
            if oldFilter != filter {
                AppAnalytics.shared.trackFilterChanged(
                    screen: .insightsDetail,
                    filterType: "focus_category",
                    from: oldFilter.rawValue,
                    to: filter.rawValue
                )
            }
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

    /// Filter out generic advice that doesn't tell the user what to DO
    private func isGenericAdvice(_ text: String) -> Bool {
        let lower = text.lowercased()
        let genericStarters = ["monitor ", "track ", "continue ", "keep an eye", "your .* is healthy", "your .* is normal"]
        return genericStarters.contains { starter in
            lower.hasPrefix(starter) || lower.range(of: "^" + starter, options: .regularExpression) != nil
        }
    }
}

/// Card that leads with what the user should DO, shows why, and shows impact
private struct ActionableInsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top: metric icon + what's happening
            HStack(spacing: 10) {
                Image(systemName: insight.metric.systemImageName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(insight.metric.category.color, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.metric.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(impactText)
                        .font(.caption2)
                        .foregroundStyle(insight.severity == .critical ? .red : .orange)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            // Action: the specific thing to do
            Text(actionText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Extract the actionable sentence — skip generic starters
    private var actionText: String {
        let sentences = insight.recommendation.components(separatedBy: ". ")
        for sentence in sentences {
            let lower = sentence.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.isEmpty { continue }
            let isGeneric = lower.hasPrefix("monitor") || lower.hasPrefix("track") ||
                lower.hasPrefix("continue") || lower.hasPrefix("your") ||
                lower.hasPrefix("keep an eye") || lower.hasPrefix("consult")
            if !isGeneric {
                let clean = sentence.trimmingCharacters(in: .whitespaces)
                return clean.hasSuffix(".") ? clean : clean + "."
            }
        }
        let first = sentences.first ?? insight.recommendation
        return first.hasSuffix(".") ? first : first + "."
    }

    /// Show quantified impact: "23% below your baseline"
    private var impactText: String {
        let dev = abs(insight.deviationPercent)
        if dev > 0.5 {
            let direction = insight.deviationPercent > 0 ? "above" : "below"
            return String(format: "%.0f%% %@ your baseline", dev, direction)
        }
        return insight.trend.displayName
    }
}
