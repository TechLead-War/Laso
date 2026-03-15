import SwiftUI
import SwiftData

/// Data exploration tab — deep-dive dashboard surfacing score breakdown,
/// historical context, correlations, and category scores from the analysis engine.
struct ExploreView: View {
    let viewModel: DashboardViewModel
    @Binding var navigationPath: NavigationPath
    @State private var showScoreGuide = false
    @State private var trendTimeframe: Int = 30
    @State private var maxScrollDepth: Int = 0

    // Section trackers
    @State private var scoreHeroTracker = SectionTracker(section: .exploreScoreHero, tab: .explore)
    @State private var dataSummaryTracker = SectionTracker(section: .exploreDataSummary, tab: .explore)
    @State private var needsAttentionTracker = SectionTracker(section: .exploreNeedsAttention, tab: .explore)
    @State private var decliningTrendsTracker = SectionTracker(section: .exploreDecliningTrends, tab: .explore)
    @State private var correlationsTracker = SectionTracker(section: .exploreCorrelations, tab: .explore)
    @State private var categoriesTracker = SectionTracker(section: .exploreCategories, tab: .explore)
    @State private var yourTrendsTracker = SectionTracker(section: .exploreYourTrends, tab: .explore)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if hasScoreData {
                    // 1. Score Hero with trend
                    ExploreScoreHeroSection(
                        overallScore: viewModel.scores.overallScore.score,
                        scoreChangeFromLastWeek: viewModel.scores.scoreChangeFromLastWeek,
                        weakestCategory: weakestCategory,
                        onScoreInfoTapped: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Score Info",
                                type: .exploreScoreInfo,
                                screen: .explore,
                                metadata: [
                                    "score": viewModel.scores.overallScore.score,
                                    "grade": grade
                                ]
                            )
                            scoreHeroTracker.tapped(target: "score_info")
                            showScoreGuide = true
                        }
                    )
                    .padding(.horizontal)
                    .onAppear { scoreHeroTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 15) }
                    .onDisappear { scoreHeroTracker.disappeared() }

                    // 2. Data depth bar — Metrics, Data Points, Days
                    ExploreDataSummarySection(
                        metricsTracked: viewModel.analysis.dataDepth.metricsTracked,
                        totalDataPoints: viewModel.analysis.dataDepth.totalDataPoints,
                        daysOfData: viewModel.analysis.dataDepth.daysOfData,
                        insightCount: viewModel.insights.focusedInsights.count
                    )
                    .padding(.horizontal)
                    .onAppear { dataSummaryTracker.appeared() }
                    .onDisappear { dataSummaryTracker.disappeared() }

                    // 3. Your Trends — prominent trend-first section
                    if !trendMetrics.isEmpty {
                        ExploreYourTrendsSection(
                            trendMetrics: trendMetrics,
                            trendTimeframe: $trendTimeframe,
                            onMetricTapped: { item in
                                AppAnalytics.shared.trackBlockTap(
                                    title: item.metric.displayName,
                                    type: .exploreTrendMetric,
                                    screen: .explore,
                                    metadata: [
                                        "metric_id": item.metric.rawValue,
                                        "change_pct": item.trend.weekOverWeekChange,
                                        "direction": item.trend.direction.rawValue,
                                        "timeframe": trendTimeframe
                                    ]
                                )
                                yourTrendsTracker.tapped(target: item.metric.rawValue)
                                navigationPath.append(item.metric)
                            }
                        )
                        .onAppear { yourTrendsTracker.appeared() }
                        .onDisappear { yourTrendsTracker.disappeared() }
                    }

                    // 4. Categories — primary navigation
                    ExploreCategoriesSection(
                        categories: sortedCategories,
                        insightCountProvider: { category in
                            viewModel.analysisEngine.insights(for: category).count
                        },
                        onCategoryTapped: { category, score in
                            AppAnalytics.shared.trackBlockTap(
                                title: category.displayName,
                                type: .categoryRow,
                                screen: .explore,
                                metadata: [
                                    "category_id": category.rawValue,
                                    "category_score": score ?? -1
                                ]
                            )
                            categoriesTracker.tapped(target: category.rawValue)
                            navigationPath.append(category)
                        }
                    )
                    .padding(.horizontal)
                    .onAppear { categoriesTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 45) }
                    .onDisappear { categoriesTracker.disappeared() }

                    // 5. Health State Timeline link (requires 30+ days)
                    if viewModel.analysis.dataDepth.daysOfData >= 30,
                       viewModel.analysisEngine.mlOrchestrator.stateClassifier.isReady {
                        ExploreHealthStateLinkSection(
                            currentHealthState: viewModel.analysisEngine.currentHealthState,
                            onTapped: {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "Health States",
                                    type: .exploreHealthStateTeaser,
                                    screen: .explore,
                                    metadata: [
                                        "destination": "health_state_timeline",
                                        "state": viewModel.analysisEngine.currentHealthState?.label ?? "unknown"
                                    ]
                                )
                                navigationPath.append(Route.healthStateTimeline)
                            }
                        )
                        .padding(.horizontal)
                    }

                    // 6. Strongest area — positive anchor before negative content
                    if let strongest = viewModel.analysisEngine.categoryScores
                        .compactMap({ score -> (category: HealthCategory, score: Int)? in
                            guard let cat = score.category else { return nil }
                            return (category: cat, score: score.score)
                        })
                        .max(by: { $0.score < $1.score }) {
                        HStack(spacing: 6) {
                            Image(systemName: strongest.category.systemImageName)
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Strongest: \(strongest.category.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // 7. Needs Attention — negative factors
                    ExploreNeedsAttentionSection(
                        scoreExplanation: viewModel.scores.scoreExplanation,
                        onFactorTapped: { factor in
                            AppAnalytics.shared.trackBlockTap(
                                title: factor.metric.displayName,
                                type: .exploreNeedsAttentionMetric,
                                screen: .explore,
                                metadata: [
                                    "metric_id": factor.metric.rawValue,
                                    "metric_category": factor.metric.category.rawValue
                                ]
                            )
                            AppAnalytics.shared.trackInsightEngagement(
                                category: factor.metric.category.rawValue,
                                metric: factor.metric.rawValue,
                                action: "tap_needs_attention"
                            )
                            needsAttentionTracker.tapped(target: factor.metric.rawValue)
                            navigationPath.append(factor.metric)
                        },
                        onWeakCategoryTapped: { contrib in
                            AppAnalytics.shared.trackBlockTap(
                                title: contrib.category.displayName,
                                type: .exploreWeakCategory,
                                screen: .explore,
                                metadata: [
                                    "category_id": contrib.category.rawValue,
                                    "category_score": contrib.score
                                ]
                            )
                            needsAttentionTracker.tapped(target: contrib.category.rawValue)
                            navigationPath.append(contrib.category)
                        }
                    )
                    .padding(.horizontal)
                    .onAppear { needsAttentionTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 65) }
                    .onDisappear { needsAttentionTracker.disappeared() }

                    // 8. Declining metrics from history (requires 30+ days)
                    if viewModel.analysis.dataDepth.daysOfData >= 30, !decliningHighlights.isEmpty {
                        ExploreDecliningTrendsSection(
                            decliningHighlights: decliningHighlights,
                            onHighlightTapped: { highlight in
                                AppAnalytics.shared.trackBlockTap(
                                    title: highlight.metric.displayName,
                                    type: .exploreDecliningMetric,
                                    screen: .explore,
                                    metadata: [
                                        "metric_id": highlight.metric.rawValue,
                                        "metric_category": highlight.metric.category.rawValue,
                                        "highlight_type": highlight.typeLabel
                                    ]
                                )
                                AppAnalytics.shared.trackInsightEngagement(
                                    category: highlight.metric.category.rawValue,
                                    metric: highlight.metric.rawValue,
                                    action: "tap_declining_trend"
                                )
                                decliningTrendsTracker.tapped(target: highlight.metric.rawValue)
                                navigationPath.append(highlight.metric)
                            }
                        )
                        .onAppear { decliningTrendsTracker.appeared() }
                        .onDisappear { decliningTrendsTracker.disappeared() }
                    }

                    // 9. Correlations preview
                    if FeatureGate.canAccess(.advancedAnalytics), !viewModel.analysis.topCorrelations.isEmpty {
                        ExploreCorrelationsSection(
                            correlations: viewModel.analysis.topCorrelations,
                            onSeeAllTapped: {
                                AppAnalytics.shared.trackBlockTap(
                                    title: "See all",
                                    type: .exploreSeeAllCorrelations,
                                    screen: .explore,
                                    metadata: [
                                        "destination": "correlations_detail",
                                        "correlations_count": viewModel.analysis.topCorrelations.count
                                    ]
                                )
                                correlationsTracker.tapped(target: "see_all")
                                navigationPath.append(Route.correlationsDetail)
                            }
                        )
                        .onAppear { correlationsTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
                        .onDisappear { correlationsTracker.disappeared() }
                    } else if !FeatureGate.canAccess(.advancedAnalytics) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(Copy.Explore.connections)
                                    .font(.headline)
                                Spacer()
                                Text("PRO")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue, in: Capsule())
                            }
                            Text("Discover hidden connections between your metrics")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(DS.cardPadding)
                        .cardStyle()
                        .padding(.horizontal)
                        .onAppear { correlationsTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
                        .onDisappear { correlationsTracker.disappeared() }
                    }
                } else {
                    ExploreEmptyStateSection(
                        hasAnyHealthData: hasAnyHealthData,
                        isAuthorized: viewModel.healthKitManager.isAuthorized
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier("screen.explore")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Copy.Explore.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            maxScrollDepth = 0
            AppAnalytics.shared.trackFeatureOpen(.explore, metadata: [
                "weakest_category": weakestCategory?.category.displayName ?? "none",
                "insights_count": viewModel.insights.focusedInsights.count,
                "data_days": viewModel.analysis.dataDepth.daysOfData
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstScoreSeen)
            AppAnalytics.shared.trackCoreAction(.viewedScore, screen: .explore)
        }
        .onDisappear {
            if maxScrollDepth > 0 {
                AppAnalytics.shared.trackScrollDepth(screen: .explore, maxDepthPercent: maxScrollDepth)
            }
            AppAnalytics.shared.trackFeatureClose(.explore)
        }
        .sheet(isPresented: $showScoreGuide) {
            ScoreGuideSheet()
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

    private var hasAnyHealthData: Bool {
        !viewModel.healthKitManager.timeSeries.isEmpty
    }

    private var weakestCategory: (category: HealthCategory, score: Int)? {
        let scored = HealthCategory.allCases.compactMap { cat -> (category: HealthCategory, score: Int)? in
            guard let score = viewModel.analysisEngine.score(for: cat)?.score else { return nil }
            return (category: cat, score: score)
        }
        return scored.min(by: { $0.score < $1.score })
    }

    private var grade: String {
        switch viewModel.scores.overallScore.score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private var decliningHighlights: [DashboardViewModel.HistoricalHighlight] {
        viewModel.analysis.historicalHighlights.filter { !$0.isPositive }
    }

    private var trendMetrics: [TrendMetricItem] {
        viewModel.trends.trendMetrics(for: trendTimeframe)
    }

    private var sortedCategories: [(category: HealthCategory, score: Int?)] {
        let focuses = viewModel.insights.focusCategories
        return HealthCategory.allCases.map { cat in
            (category: cat, score: viewModel.analysisEngine.score(for: cat)?.score)
        }
        .sorted { a, b in
            let aHasScore = a.score != nil
            let bHasScore = b.score != nil
            if aHasScore != bHasScore { return aHasScore }
            guard let aScore = a.score, let bScore = b.score else { return false }
            let aFocused = focuses.contains(a.category)
            let bFocused = focuses.contains(b.category)
            if aFocused != bFocused { return aFocused }
            return aScore < bScore
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self,
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
