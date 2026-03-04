import SwiftUI
import SwiftData

/// Data exploration tab — deep-dive dashboard surfacing score breakdown,
/// historical context, correlations, and category scores from the analysis engine.
struct ExploreView: View {
    let viewModel: DashboardViewModel
    @Binding var navigationPath: NavigationPath
    @State private var showScoreGuide = false
    @State private var showSimulation = false

    // Section trackers
    @State private var scoreHeroTracker = SectionTracker(section: .exploreScoreHero, tab: .explore)
    @State private var dataSummaryTracker = SectionTracker(section: .exploreDataSummary, tab: .explore)
    @State private var needsAttentionTracker = SectionTracker(section: .exploreNeedsAttention, tab: .explore)
    @State private var decliningTrendsTracker = SectionTracker(section: .exploreDecliningTrends, tab: .explore)
    @State private var correlationsTracker = SectionTracker(section: .exploreCorrelations, tab: .explore)
    @State private var categoriesTracker = SectionTracker(section: .exploreCategories, tab: .explore)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if hasScoreData {
                    // 1. Score Hero with trend
                    scoreHeroSection
                        .padding(.horizontal)
                        .onAppear { scoreHeroTracker.appeared() }
                        .onDisappear { scoreHeroTracker.disappeared() }

                    // 2. Data depth bar — Metrics, Data Points, Days
                    dataSummaryBar
                        .padding(.horizontal)
                        .onAppear { dataSummaryTracker.appeared() }
                        .onDisappear { dataSummaryTracker.disappeared() }

                    // 3. Needs Attention — negative factors only
                    scoreBreakdownSection
                        .padding(.horizontal)
                        .onAppear { needsAttentionTracker.appeared() }
                        .onDisappear { needsAttentionTracker.disappeared() }

                    // 4. Declining metrics from history
                    if !decliningHighlights.isEmpty {
                        historicalSection
                            .onAppear { decliningTrendsTracker.appeared() }
                            .onDisappear { decliningTrendsTracker.disappeared() }
                    }

                    // 4b. What-If Simulation teaser
                    if FeatureGate.canAccess(.simulation) {
                        simulationTeaser
                            .padding(.horizontal)
                    }

                    // 4c. Health State Timeline link
                    if viewModel.analysisEngine.mlOrchestrator.stateClassifier.isReady {
                        healthStateLink
                            .padding(.horizontal)
                    }

                    // 5. Correlations preview
                    if FeatureGate.canAccess(.advancedAnalytics), !viewModel.topCorrelations.isEmpty {
                        correlationsPreview
                            .onAppear { correlationsTracker.appeared() }
                            .onDisappear { correlationsTracker.disappeared() }
                    }

                    // 6. Categories — worst first
                    categoriesSection
                        .padding(.horizontal)
                        .onAppear { categoriesTracker.appeared() }
                        .onDisappear { categoriesTracker.disappeared() }
                } else {
                    emptyState
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.explore, metadata: [
                "weakest_category": weakestCategory?.category.displayName ?? "none",
                "insights_count": viewModel.focusedInsights.count,
                "data_days": viewModel.dataDepth.daysOfData
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstScoreSeen)
            AppAnalytics.shared.trackCoreAction(.viewedScore, screen: .explore)
        }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.explore) }
        .sheet(isPresented: $showScoreGuide) {
            ScoreGuideSheet()
        }
        .sheet(isPresented: $showSimulation) {
            SimulationView(viewModel: SimulationViewModel(analysisEngine: viewModel.analysisEngine))
        }
        .refreshable {
            AppAnalytics.shared.trackPullToRefresh(screen: .explore)
            await viewModel.refresh()
        }
    }

    // MARK: - Data

    private var hasScoreData: Bool {
        !viewModel.analysisEngine.categoryScores.isEmpty
    }

    // MARK: - Simulation Teaser

    private var simulationTeaser: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(title: "What If?", type: .exploreSimulationTeaser, screen: .explore)
            showSimulation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(Color.cyan.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text("What If?")
                        .font(.subheadline.weight(.semibold))
                    Text("See how changes could improve your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Health State Link

    private var healthStateLink: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(title: "Health States", type: .exploreHealthStateTeaser, screen: .explore)
            navigationPath.append("healthStateTimeline")
        } label: {
            HStack(spacing: 12) {
                let state = viewModel.analysisEngine.currentHealthState
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.title3)
                    .foregroundStyle(.mint)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(Color.mint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Health States")
                        .font(.subheadline.weight(.semibold))
                    if let state {
                        Text("\(state.label) for \(state.daysInState) day\(state.daysInState == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("See your health state patterns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - 1. Score Hero

    private var scoreHeroSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                HealthScoreRing(
                    score: viewModel.overallScore.score,
                    label: "",
                    size: 100,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Health Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            AppAnalytics.shared.trackBlockTap(title: "Score Info", type: .exploreScoreInfo, screen: .explore)
                            scoreHeroTracker.tapped(target: "score_info")
                            showScoreGuide = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(grade)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)

                    // Score trend from last week
                    if let delta = viewModel.scoreChangeFromLastWeek {
                        HStack(spacing: 4) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text("\(delta > 0 ? "+" : "")\(delta) pts this week")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(delta > 0 ? .green : .red)
                    } else {
                        Text(scoreLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Weakest category suggestion
            if let weakest = weakestCategory {
                HStack(spacing: 6) {
                    Image(systemName: weakest.category.systemImageName)
                        .font(.caption)
                        .foregroundStyle(weakest.category.color)
                    Text("Focus on \(weakest.category.displayName) to improve your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(weakest.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 2. Data Summary Bar

    private var dataSummaryBar: some View {
        let depth = viewModel.dataDepth
        let insightCount = viewModel.focusedInsights.count

        return HStack(spacing: 0) {
            dataStat(value: "\(depth.metricsTracked)", label: "Metrics")
            Divider().frame(height: DS.dividerHeight)
            dataStat(value: formatDataPoints(depth.totalDataPoints), label: "Data Points")
            if depth.daysOfData > 0 {
                Divider().frame(height: DS.dividerHeight)
                dataStat(value: "\(depth.daysOfData)", label: depth.daysOfData == 1 ? "Day" : "Days")
            }
            Divider().frame(height: DS.dividerHeight)
            dataStat(value: "\(insightCount)", label: "Insights")
        }
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.cardRadius))
    }

    private func dataStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDataPoints(_ count: Int) -> String {
        if count >= 10_000 { return "\(count / 1000)k" }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    // MARK: - 3. Score Breakdown (negative factors only)

    @ViewBuilder
    private var scoreBreakdownSection: some View {
        if let explanation = viewModel.scoreExplanation {
            let negativeFactors = explanation.topFactors.filter { !$0.isPositive }
            let weakCategories = explanation.categoryContributions
                .filter { $0.score < 75 }
                .sorted { $0.score < $1.score }

            if !negativeFactors.isEmpty || !weakCategories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Needs Attention")
                        .font(.headline)

                    // Negative factors only — what's dragging the score down
                    ForEach(Array(negativeFactors.prefix(5).enumerated()), id: \.offset) { _, factor in
                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: factor.metric.displayName,
                                type: .exploreNeedsAttentionMetric,
                                screen: .explore
                            )
                            needsAttentionTracker.tapped(target: factor.metric.rawValue)
                            navigationPath.append(factor.metric)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: factor.metric.systemImageName)
                                    .font(.caption)
                                    .foregroundStyle(factor.metric.category.color)
                                    .frame(width: DS.iconSize, height: DS.iconSize)
                                    .background(factor.metric.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(factor.metric.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(factor.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Text("\(factor.impact)")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    // Weak categories bar
                    if !weakCategories.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 0) {
                            ForEach(weakCategories.prefix(4), id: \.category) { contrib in
                                Button {
                                    AppAnalytics.shared.trackBlockTap(
                                        title: contrib.category.displayName,
                                        type: .exploreWeakCategory,
                                        screen: .explore
                                    )
                                    needsAttentionTracker.tapped(target: contrib.category.rawValue)
                                    navigationPath.append(contrib.category)
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: contrib.category.systemImageName)
                                            .font(.caption2)
                                            .foregroundStyle(contrib.category.color)
                                        Text("\(contrib.score)")
                                            .font(.caption.weight(.bold).monospacedDigit())
                                            .foregroundStyle(contrib.score < 60 ? .red : .orange)
                                        Text(contrib.category.shortName)
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - 4. Declining Historical Trends

    /// Only show negative historical highlights — things getting worse
    private var decliningHighlights: [DashboardViewModel.HistoricalHighlight] {
        viewModel.historicalHighlights.filter { !$0.isPositive }
    }

    private var historicalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Declining Trends")
                .font(.headline)
                .padding(.horizontal)

            ForEach(decliningHighlights) { highlight in
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: highlight.metric.displayName,
                        type: .exploreDecliningMetric,
                        screen: .explore
                    )
                    decliningTrendsTracker.tapped(target: highlight.metric.rawValue)
                    navigationPath.append(highlight.metric)
                } label: {
                    historicalCard(highlight)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    private func historicalCard(_ highlight: DashboardViewModel.HistoricalHighlight) -> some View {
        HStack(spacing: 12) {
            Image(systemName: highlight.icon)
                .font(.body)
                .foregroundStyle(.orange)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlight.metric.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text(highlight.typeLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Color.orange.opacity(DS.badgeBg), in: Capsule())
                }

                Text(highlight.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(highlight.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 5. Correlations Preview

    private var correlationsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Connections")
                    .font(.headline)

                Spacer()

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "See all",
                        type: .exploreSeeAllCorrelations,
                        screen: .explore
                    )
                    correlationsTracker.tapped(target: "see_all")
                    navigationPath.append("correlationsDetail")
                } label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            ForEach(Array(viewModel.topCorrelations.prefix(2))) { correlation in
                correlationCard(correlation)
                    .padding(.horizontal)
            }
        }
    }

    private func correlationCard(_ c: HealthCorrelation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: c.metricA.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricA.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricA.category.color.opacity(0.12), in: Circle())

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: c.metricB.systemImageName)
                .font(.caption)
                .foregroundStyle(c.metricB.category.color)
                .frame(width: 24, height: 24)
                .background(c.metricB.category.color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(c.effectSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(c.strengthLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 6. Categories (worst-first)

    /// Categories sorted by score ascending — weakest areas first
    private var sortedCategories: [(category: HealthCategory, score: Int?)] {
        HealthCategory.allCases.map { cat in
            (category: cat, score: viewModel.analysisEngine.score(for: cat)?.score)
        }
        .sorted { a, b in
            // Categories with scores come first, sorted ascending (worst first)
            guard let aScore = a.score else { return false }
            guard let bScore = b.score else { return true }
            return aScore < bScore
        }
    }

    private var categoriesSection: some View {
        let categories = sortedCategories
        return VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.element.category) { index, item in
                    Button {
                        AppAnalytics.shared.trackBlockTap(title: item.category.displayName, type: .categoryRow, screen: .explore)
                        categoriesTracker.tapped(target: item.category.rawValue)
                        navigationPath.append(item.category)
                    } label: {
                        ExploreCategoryRow(
                            category: item.category,
                            score: item.score,
                            insightCount: viewModel.analysisEngine.insights(for: item.category).count
                        )
                    }
                    .buttonStyle(.plain)

                    if index < categories.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        }
    }

    // MARK: - Empty State

    private var hasAnyHealthData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    private var emptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: hasAnyHealthData ? "chart.line.text.clipboard" : "heart.text.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Health Score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(hasAnyHealthData ? "Almost there..." : "No data yet")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                Text(hasAnyHealthData
                     ? "A few more days of tracking and your score will be ready"
                     : "Open the Health app and allow access to see your analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Computed Helpers

    private var weakestCategory: (category: HealthCategory, score: Int)? {
        let scored = HealthCategory.allCases.compactMap { cat -> (category: HealthCategory, score: Int)? in
            guard let score = viewModel.analysisEngine.score(for: cat)?.score else { return nil }
            return (category: cat, score: score)
        }
        return scored.min(by: { $0.score < $1.score })
    }

    private var grade: String {
        switch viewModel.overallScore.score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private var gradeColor: Color {
        switch viewModel.overallScore.score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var scoreLabel: String {
        switch viewModel.overallScore.score {
        case 85...100: return "Excellent shape"
        case 70..<85: return "Looking good"
        case 55..<70: return "Room to improve"
        default: return "Needs attention"
        }
    }
}

/// A single category row in the Explore list
private struct ExploreCategoryRow: View {
    let category: HealthCategory
    let score: Int?
    let insightCount: Int

    private var needsAttention: Bool {
        guard let score else { return false }
        return score < 70
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.systemImageName)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(needsAttention ? .body.weight(.bold) : .body.weight(.medium))

                HStack(spacing: 8) {
                    Text(scoreStatus)
                        .font(.caption.weight(needsAttention ? .semibold : .regular))
                        .foregroundStyle(scoreStatusColor)

                    if insightCount > 0 {
                        Text("\(insightCount) insight\(insightCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let score {
                HealthScoreRing(
                    score: score,
                    label: "",
                    size: 36,
                    lineWidth: 4
                )
            } else {
                Text("--")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var scoreStatus: String {
        guard let score else { return "No data yet" }
        switch score {
        case 85...100: return "On track"
        case 70..<85: return "Doing well"
        case 55..<70: return "Room to improve"
        case 40..<55: return "Needs work"
        default: return "Needs attention"
        }
    }

    private var scoreStatusColor: Color {
        guard let score else { return .secondary }
        switch score {
        case 80...100: return .green
        case 60..<80: return .secondary
        case 40..<60: return .orange
        default: return .red
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        ExploreView(
            viewModel: DashboardViewModel(
                healthKitManager: HealthKitManager(),
                analysisEngine: AnalysisEngine(),
                store: HealthDataStore(modelContainer: container)
            ),
            navigationPath: .constant(NavigationPath())
        )
    }
}
