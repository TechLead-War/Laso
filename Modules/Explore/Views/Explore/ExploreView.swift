import SwiftUI
import SwiftData

/// Data exploration tab. deep-dive dashboard surfacing score breakdown,
/// historical context, correlations, and category scores from the analysis engine.
struct ExploreView: View {
    let viewModel: DashboardViewModel
    let appStateStore: AppStateStore
    @Binding var navigationPath: NavigationPath
    @State private var showScoreGuide = false
    @State private var trendTimeframe: Int = 30
    /// Not @State on purpose: see `ScrollDepthTracker`. Every write here
    /// used to re-run this whole body while the user was scrolling.
    @State private var scrollDepth = ScrollDepthTracker()

    // Section trackers
    @State private var scoreHeroTracker = SectionTracker(section: .exploreScoreHero, tab: .explore)
    @State private var dataSummaryTracker = SectionTracker(section: .exploreDataSummary, tab: .explore)
    @State private var needsAttentionTracker = SectionTracker(section: .exploreNeedsAttention, tab: .explore)
    @State private var decliningTrendsTracker = SectionTracker(section: .exploreDecliningTrends, tab: .explore)
    @State private var correlationsTracker = SectionTracker(section: .exploreCorrelations, tab: .explore)
    @State private var categoriesTracker = SectionTracker(section: .exploreCategories, tab: .explore)
    @State private var yourTrendsTracker = SectionTracker(section: .exploreYourTrends, tab: .explore)

    /// A full year plus the current day, matching the window the view model builds
    /// `cachedDailyScoresByDay` over, so the fallback and the cache show the same grid.
    private static let calendarDays = 366

    var body: some View {
        // Bound once per pass. The categories section calls insightCountProvider per
        // row, and each call ran the whole InsightCoordinator pipeline: 0.55 ms per
        // body pass for nine categories.
        let insightCounts = insightCountsByCategory
        ScrollView {
            // Lazy on purpose. A plain VStack evaluated every section body on
            // every pass, and a pass measured 2.13 ms across the 9 passes a
            // single refresh triggers. It also makes the per-section `onAppear`
            // handlers below honest: they used to all fire the instant the tab
            // opened, so `maxScrollDepth` reported 90 for a user who never
            // scrolled and every SectionTracker logged an impression nobody saw.
            // Expect a step change in those two metrics from this build on.
            LazyVStack(spacing: 24) {
                if hasScoreData {
                    // 1. Score Hero with trend
                    ExploreScoreHeroSection(
                        overallScore: viewModel.scores.rollingAverageScore,
                        scoreChangeFromLastWeek: viewModel.scores.weeklyScoreChange,
                        weakestCategory: weakestCategory,
                        onScoreInfoTapped: {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Score Info",
                                type: .exploreScoreInfo,
                                screen: .explore,
                                metadata: [
                                    // Send the same EWMA value the user sees,
                                    // not the live daily score, so analytics
                                    // never disagree with the UI.
                                    "score": viewModel.scores.rollingAverageScore,
                                    "grade": grade
                                ]
                            )
                            scoreHeroTracker.tapped(target: "score_info")
                            showScoreGuide = true
                        }
                    )
                    .padding(.horizontal)
                    .onAppear { scoreHeroTracker.appeared(); scrollDepth.record(15) }
                    .onDisappear { scoreHeroTracker.disappeared() }

                    // 2. Data depth bar. Metrics, Data Points, Days
                    ExploreDataSummarySection(
                        metricsTracked: viewModel.analysis.dataDepth.metricsTracked,
                        totalDataPoints: viewModel.analysis.dataDepth.totalDataPoints,
                        daysOfData: viewModel.analysis.dataDepth.daysOfData,
                        insightCount: viewModel.insights.focusedInsights.count
                    )
                    .padding(.horizontal)
                    .onAppear { dataSummaryTracker.appeared() }
                    .onDisappear { dataSummaryTracker.disappeared() }

                    // 3. Month calendar. the only view of whether anything is
                    // actually improving, and the surface the habit lives on.
                    // A year of scores, so paging back a month is not an empty
                    // grid the moment someone looks at it.
                    //
                    // The view model builds this map once per publish. Building it
                    // from here cost 0.60 ms per body pass (9 passes per refresh
                    // burst) and pulled a 3.16 ms SwiftData score-history fetch onto
                    // the main thread from inside a body. The fallback covers the one
                    // window the cached map misses: core analysis fills
                    // `categoryScores` on a background task, so `hasScoreData` can
                    // flip true a HealthKit fetch ahead of the publish that fills the
                    // map, and the calendar would flash empty. Same window length as
                    // the builder, so the fallback shows the same days.
                    ExploreMonthCalendarSection(
                        scoresByDay: viewModel.cachedDailyScoresByDay.isEmpty
                            ? viewModel.dailyScoresByDay(days: Self.calendarDays)
                            : viewModel.cachedDailyScoresByDay,
                        contextsByDay: viewModel.cachedContextsByDay,
                        detailForDay: { viewModel.dayDetail(for: $0) }
                    )
                    // The tab rebuilds for reasons that have nothing to do with
                    // the calendar. This makes SwiftUI compare its inputs first
                    // and skip the most expensive draw in the app when they have
                    // not moved.
                    .equatable()
                    .padding(.horizontal)

                    // 4. Your Trends. prominent trend-first section
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
                                        // Half-vs-half of the selected window,
                                        // not actual week-over-week unless the
                                        // user picked the 7D timeframe.
                                        "period_change_pct": item.trend.weekOverWeekChange,
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

                    // 3b. Body Intelligence and forecast. Both moved off Home,
                    // where they restated the score card. Here they sit beside
                    // the other analysis the user came to this tab to read.
                    TodayBriefingView(cards: viewModel.intelligenceBriefing)

                    PersonalHealthForecastCard(forecasts: viewModel.healthForecasts) { metric in
                        AppAnalytics.shared.trackBlockTap(
                            title: metric.displayName,
                            type: .exploreTrendMetric,
                            screen: .explore,
                            metadata: ["metric_id": metric.rawValue, "source": "forecast"]
                        )
                        navigationPath.append(metric)
                    }

                    // 4. Categories. primary navigation
                    ExploreCategoriesSection(
                        categories: sortedCategories,
                        // A category absent from the map has no insights at all,
                        // which is the 0 that `coordinate([])` returns for it.
                        insightCountProvider: { insightCounts[$0] ?? 0 },
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
                    .onAppear { categoriesTracker.appeared(); scrollDepth.record(45) }
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

                    // 6. Strongest area. positive anchor before negative content
                    if let strongest = viewModel.analysisEngine.categoryScores
                        .compactMap({ score -> (category: HealthCategory, score: Int)? in
                            guard let cat = score.category else { return nil }
                            return (category: cat, score: score.score)
                        })
                        // Stable tiebreak by category.rawValue — without this
                        // the displayed strongest pill flips between refreshes
                        // when two categories share the top score.
                        .max(by: { a, b in
                            if a.score != b.score { return a.score < b.score }
                            return a.category.rawValue > b.category.rawValue
                        }) {
                        HStack(spacing: 6) {
                            Image(systemName: strongest.category.systemImageName)
                                .font(.caption)
                                .foregroundStyle(AppColour.success)
                            Text(Copy.Explore.strongest(strongest.category.displayName))
                                .font(.caption)
                                .foregroundStyle(AppColour.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // 7. Needs Attention. negative factors
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
                    .onAppear { needsAttentionTracker.appeared(); scrollDepth.record(65) }
                    .onDisappear { needsAttentionTracker.disappeared() }

                    // 8. Why this week — declining metrics merged with their causal explanation
                    if viewModel.analysis.dataDepth.daysOfData >= 30, !decliningHighlights.isEmpty {
                        ExploreDecliningTrendsSection(
                            decliningHighlights: decliningHighlights,
                            causalChains: FeatureGate.canAccess(.advancedAnalytics) ? viewModel.analysis.causalChains : [],
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
                                decliningTrendsTracker.tapped(target: highlight.metric.rawValue)
                                navigationPath.append(highlight.metric)
                            },
                            onSeeAllIntelligenceTapped: FeatureGate.canAccess(.advancedAnalytics) ? {
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
                            } : nil
                        )
                        .onAppear { decliningTrendsTracker.appeared(); correlationsTracker.appeared() }
                        .onDisappear { decliningTrendsTracker.disappeared(); correlationsTracker.disappeared() }
                    }

                    // 9. Free tier upsell for advanced analytics. Pro users see the
                    // explanation inline inside section 8 above.
                    if !FeatureGate.canAccess(.advancedAnalytics) {
                        VStack(alignment: .leading, spacing: DS.itemSpacing) {
                            SectionHeaderView(icon: "link", title: Copy.Explore.connections)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(Copy.Explore.connections)
                                        .font(.headline)
                                    Spacer()
                                    Text(Copy.Explore.pro)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppColour.textPrimary)
                                        .padding(.horizontal, DS.space2)
                                        .padding(.vertical, DS.space1)
                                        .background(AppColour.primary, in: Capsule())
                                }
                                Text(Copy.Explore.discoverHiddenConnections)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColour.textSecondary)
                            }
                            .padding(DS.cardPadding)
                            .cardStyle()
                            .padding(.horizontal)
                        }
                        .onAppear { scrollDepth.record(90) }
                    }
                } else {
                    ExploreEmptyStateSection(
                        hasAnyHealthData: hasAnyHealthData,
                        isAuthorized: viewModel.healthKitManager.isAuthorized
                    )
                    .padding(.horizontal)
                    .onAppear {
                        AppAnalytics.shared.trackEmptyStateShown(
                            screen: .explore,
                            reason: hasAnyHealthData
                                ? "syncing"
                                : (viewModel.healthKitManager.isAuthorized ? "authorized_no_data" : "not_authorized")
                        )
                    }
                }
            }
            .padding(.bottom, DS.space4)
        }
        .contentMargins(.bottom, 72, for: .scrollContent)
        .accessibilityIdentifier("screen.explore")
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Explore.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            scrollDepth.reset()
            AppAnalytics.shared.trackFeatureOpen(.explore, metadata: [
                "weakest_category": weakestCategory?.category.displayName ?? "none",
                "insights_count": viewModel.insights.focusedInsights.count,
                "data_days": viewModel.analysis.dataDepth.daysOfData
            ])
            AppAnalytics.shared.trackActivationMilestone(.firstScoreSeen)
            AppAnalytics.shared.trackCoreAction(.viewedScore, screen: .explore)
        }
        .onDisappear {
            if scrollDepth.maxDepth > 0 {
                AppAnalytics.shared.trackScrollDepth(screen: .explore, maxDepthPercent: scrollDepth.maxDepth)
            }
            AppAnalytics.shared.trackFeatureClose(.explore)
        }
        .sheet(isPresented: $showScoreGuide) {
            ScoreGuideSheet(
                score: viewModel.scores.rollingAverageScore,
                weakestCategoryName: weakestCategory?.category.displayName,
                appStateStore: appStateStore,
                kind: .weekly
            )
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
        viewModel.exploreWeakestCategory
    }

    private var grade: String {
        HealthScore.grade(for: viewModel.scores.rollingAverageScore)
    }

    private var decliningHighlights: [DashboardViewModel.HistoricalHighlight] {
        viewModel.analysis.historicalHighlights.filter { !$0.isPositive }
    }

    private var trendMetrics: [TrendMetricItem] {
        viewModel.trends.trendMetrics(for: trendTimeframe)
    }

    private var sortedCategories: [(category: HealthCategory, score: Int?)] {
        viewModel.exploreSortedCategories
    }

    /// Same slice, same order and same coordinator as `AnalysisEngine.insights(for:)`,
    /// so the counts on screen do not move. One grouping pass replaces nine full-array
    /// filters, and the coordinator only runs for categories that have insights.
    private var insightCountsByCategory: [HealthCategory: Int] {
        var byCategory: [HealthCategory: [Insight]] = [:]
        for insight in viewModel.analysisEngine.insights {
            byCategory[insight.metric.category, default: []].append(insight)
        }
        return byCategory.mapValues { InsightCoordinator.coordinate($0).count }
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
                store: HealthDataStore(modelContainer: container),
                housekeepingService: DashboardHousekeepingService(
                    persistenceManager: PersistenceManager(),
                    analytics: AppAnalytics.shared,
                    sessionTracker: SessionTracker.shared
                )
            ),
            appStateStore: AppStateStore(),
            navigationPath: .constant(NavigationPath())
        )
    }
}
