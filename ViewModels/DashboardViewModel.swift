import Foundation
import Observation
import os

/// ViewModel for the main dashboard showing overall score, top insights, and category cards.
/// Properties are grouped into nested @Observable sub-objects to reduce unnecessary SwiftUI re-renders.
@Observable
final class DashboardViewModel {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let store: HealthDataStore
    private let persistence: PersistenceManager
    private let appStateStore: AppStateStore
    private let intentCacheStore: IntentCacheStore
    private let smartActionAdvisor: DashboardSmartActionAdvisor
    private let housekeepingService: DashboardHousekeepingService
    private let derivedStateBuilder: DashboardDerivedStateBuilder

    // MARK: - Nested Observable State Groups

    /// UI state: loading, errors, discovery, time period selection
    let ui: UIState
    /// Score-related state: overall score, category scores, score changes, recovery
    let scores = ScoreState()
    /// Trend-related state: trends summary
    let trends = TrendState()
    /// Insight-related state: focused insights, headline, focus categories
    let insights = InsightState()
    /// Anomaly-related state: anomalous metrics, alert counts
    let anomalies = AnomalyState()
    /// Analysis-related state: historical highlights, data depth, correlations, risks, illness, causal chains
    let analysis = AnalysisState()

    private var isSyncRetryInProgress = false
    private var lastSyncRetryAttempt: Date?

    /// Tracks last full analysis to avoid redundant re-runs when no new data arrives
    private var lastAnalysisDate: Date?
    private static let analysisMinInterval: TimeInterval = 300  // 5 minutes
    private static let syncRetryMinInterval: TimeInterval = 600  // 10 minutes
    private static let connectivityRecoveryMinInterval: TimeInterval = 900  // 15 minutes
    private var lastConnectivityRecoverySync: Date?
    @MainActor private var refreshRunToken = UUID()

    /// Previous trend directions — used for trend reversal detection
    private var previousTrends: [HealthMetric: TrendDirection] = [:]

    /// Cached 365-day score history for the current refresh cycle.
    /// Fetched once on first access via `scoreHistoryCached()`, cleared at
    /// the start of each refresh and after saving a new analysis snapshot.
    @MainActor private var _cachedScoreHistory: [(date: Date, score: Int)]?

    // MARK: - Nested @Observable Classes

    @Observable
    final class UIState {
        private let appStateStore: AppStateStore

        var isLoading = false
        var hasCompletedInitialLoad = false
        var errorMessage: String?
        var discoveries: [Discovery] = []
        var showDiscovery = false
        var syncPhase: SyncPhase = .idle
        var selectedPeriod: TimePeriod = .sevenDays

        init(appStateStore: AppStateStore) {
            self.appStateStore = appStateStore
        }

        var isFirstLaunchSync: Bool {
            !appStateStore.hasSeenDiscovery
        }
    }

    @Observable
    final class ScoreState {
        fileprivate(set) var cachedScoreChangeFromLastWeek: Int?
        fileprivate(set) var cachedScoreChangeFromYesterday: Int?
        /// Set by parent after each analysis refresh
        fileprivate(set) var overallScore: HealthScore = HealthScore(score: 0)
        fileprivate(set) var categoryScores: [HealthScore] = []

        var scoreChangeFromLastWeek: Int? { cachedScoreChangeFromLastWeek }
        var scoreChangeFromYesterday: Int? { cachedScoreChangeFromYesterday }

        var recoveryState: RecoveryState {
            RecoveryState(score: overallScore.score)
        }

        var dayClassification: String {
            recoveryState.dayType
        }

        /// Score explanation for transparency
        fileprivate(set) var scoreExplanation: HealthScorer.ScoreExplanation?
    }

    @Observable
    final class TrendState {
        fileprivate(set) var cachedTrendsSummary: TrendsSummary?
        /// Pre-computed trend metrics keyed by timeframe (7, 30, 90 days)
        fileprivate(set) var cachedTrendMetricsByTimeframe: [Int: [TrendMetricItem]] = [:]

        var trendsSummary: TrendsSummary {
            cachedTrendsSummary ?? TrendsSummary(improving: 0, stable: 0, declining: 0, topMovers: [])
        }

        /// Trends summary for Today section (alias)
        var todayTrendsSummary: TrendsSummary {
            trendsSummary
        }

        /// Returns pre-computed trend metrics for the given timeframe
        func trendMetrics(for days: Int) -> [TrendMetricItem] {
            cachedTrendMetricsByTimeframe[days] ?? []
        }
    }

    @Observable
    final class InsightState {
        /// Raw health focuses from encrypted store — cached to avoid repeated Keychain + AES-GCM decryption.
        fileprivate(set) var cachedHealthFocuses: Set<HealthFocus> = []
        fileprivate(set) var cachedFocusCategories: Set<HealthCategory> = []
        fileprivate(set) var cachedFocusedInsights: [Insight] = []

        var focusCategories: Set<HealthCategory> { cachedFocusCategories }
        var focusedInsights: [Insight] { cachedFocusedInsights }

        var headlineInsight: Insight? { focusedInsights.first }
        var topInsights: [Insight] { Array(focusedInsights.prefix(3)) }
        var allInsights: [Insight] { focusedInsights }

        /// Insights grouped by InsightCategory, filtered by focus areas, excluding empty categories
        var insightsByCategory: [(category: InsightCategory, insights: [Insight])] {
            let focused = focusedInsights
            return InsightCategory.allCases.compactMap { category in
                let matching = focused.filter { $0.category == category }
                guard !matching.isEmpty else { return nil }
                return (category: category, insights: matching)
            }
        }
    }

    @Observable
    final class AnomalyState {
        fileprivate(set) var anomalousMetrics: [AnomalyDetector.AnomalyResult] = []
        fileprivate(set) var criticalAlertCount: Int = 0
        fileprivate(set) var warningAlertCount: Int = 0
    }

    @Observable
    final class AnalysisState {
        fileprivate(set) var cachedHistoricalHighlights: [HistoricalHighlight] = []
        fileprivate(set) var cachedTopCorrelations: [HealthCorrelation] = []

        var historicalHighlights: [HistoricalHighlight] { cachedHistoricalHighlights }
        var topCorrelations: [HealthCorrelation] { cachedTopCorrelations }

        fileprivate(set) var correlations: [HealthCorrelation] = []
        fileprivate(set) var healthRisks: [HealthRisk] = []
        fileprivate(set) var topHealthRisks: [HealthRisk] = []
        fileprivate(set) var todayHealthRisks: [HealthRisk] = []
        fileprivate(set) var illnessWarnings: [IllnessEarlyWarning.Warning] = []
        fileprivate(set) var hasIllnessWarning: Bool = false
        fileprivate(set) var topIllnessWarning: IllnessEarlyWarning.Warning?
        fileprivate(set) var crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] = []
        fileprivate(set) var causalChains: [CausalChain] = []
        fileprivate(set) var topCausalChain: CausalChain?
        fileprivate(set) var dataDepth: (metricsTracked: Int, totalDataPoints: Int, daysOfData: Int) = (0, 0, 0)
    }

    enum SyncPhase {
        case idle, importing, analyzing, discovering, complete
    }

    enum RecoveryState: String, CaseIterable {
        case green, yellow, red

        init(score: Int) {
            if score > 75 { self = .green }
            else if score >= 50 { self = .yellow }
            else { self = .red }
        }

        var label: String {
            switch self {
            case .green: Copy.Home.fullyRecovered
            case .yellow: Copy.Home.moderateRecovery
            case .red: Copy.Home.lowRecovery
            }
        }

        var dayType: String {
            switch self {
            case .green: Copy.Home.greenDayPushHard
            case .yellow: Copy.Home.yellowDayMaintain
            case .red: Copy.Home.redDayRecover
            }
        }

        var strainGuidance: String {
            switch self {
            case .green: Copy.Home.greenStrainGuidance
            case .yellow: Copy.Home.yellowStrainGuidance
            case .red: Copy.Home.redStrainGuidance
            }
        }
    }

    // MARK: - Convenience accessors (kept for backward compat with internal methods)

    var overallScore: HealthScore { scores.overallScore }
    var recoveryState: RecoveryState { scores.recoveryState }

    var strainGuidance: String {
        let trend = recentActivityTrendDirection

        switch recoveryState {
        case .green:
            switch trend {
            case .improving:
                return Copy.Home.greenImproving
            case .declining:
                return Copy.Home.greenDeclining
            case .stable:
                return Copy.Home.greenStable
            case .none:
                return Copy.Home.greenNone
            }
        case .yellow:
            switch trend {
            case .improving:
                return Copy.Home.yellowImproving
            case .declining:
                return Copy.Home.yellowDeclining
            case .stable:
                return Copy.Home.yellowStable
            case .none:
                return Copy.Home.yellowNone
            }
        case .red:
            switch trend {
            case .improving:
                return Copy.Home.redImproving
            case .declining:
                return Copy.Home.redDeclining
            case .stable:
                return Copy.Home.redStable
            case .none:
                return Copy.Home.redNone
            }
        }
    }

    /// Top 3 actionable insights for the compact card display, filtered by selected period
    var topActionableInsights: [Insight] {
        topActionableInsights(for: ui.selectedPeriod)
    }

    /// Period-aware insights: only include metrics that have data in the selected period, filtered by focus areas
    func topActionableInsights(for period: TimePeriod) -> [Insight] {
        let days = period.days
        let categories = insights.focusCategories
        let metricsWithData = Set(
            healthKitManager.timeSeries
                .filter { !$0.value.samples(lastDays: days).isEmpty }
                .map(\.key)
        )

        let filtered = analysisEngine.insights.filter { insight in
            metricsWithData.contains(insight.metric) &&
            insight.severity >= .warning &&
            (categories.isEmpty || categories.contains(insight.metric.category))
        }
        let sorted = filtered.sorted { a, b in
            if a.severity != b.severity {
                return a.severity > b.severity
            }
            return a.priorityScore > b.priorityScore
        }
        return Array(sorted.prefix(2))
    }

    var lastRefresh: Date? {
        healthKitManager.lastRefresh
    }

    // MARK: - Key Metrics Snapshots

    /// Featured metrics shown as visual number cards on the home screen
    static let featuredMetrics: [HealthMetric] = [
        .steps, .sleepDuration, .restingHeartRate, .activeCalories, .exerciseMinutes, .bloodOxygen
    ]

    struct MetricSnapshot: Identifiable {
        var id: String { metric.rawValue }
        let metric: HealthMetric
        let currentValue: Double
        let trend: TrendDirection
        let changePercent: Double
    }

    var keyMetricSnapshots: [MetricSnapshot] {
        keyMetricSnapshots(for: ui.selectedPeriod)
    }

    /// Period-aware key metric snapshots: shows period average and period-over-period change
    func keyMetricSnapshots(for period: TimePeriod) -> [MetricSnapshot] {
        let days = period.days
        return Self.featuredMetrics.compactMap { metric in
            guard let series = healthKitManager.timeSeries[metric] else { return nil }

            // Use period average instead of just latest value
            let periodSamples = series.samples(lastDays: days)
            guard !periodSamples.isEmpty else { return nil }
            let periodAvg = periodSamples.map(\.value).mean

            // Compare with previous equivalent period
            let previousSamples = series.sortedSamples.filter { sample in
                let daysAgo = Calendar.current.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
                return daysAgo >= days && daysAgo < days * 2
            }
            let previousAvg = previousSamples.isEmpty ? 0.0 : previousSamples.map(\.value).mean
            let changePercent: Double
            if previousAvg != 0 {
                changePercent = ((periodAvg - previousAvg) / previousAvg) * 100
            } else {
                changePercent = 0
            }

            // Determine trend direction for this period
            let trend: TrendDirection
            let effectiveChange = metric.higherIsBetter ? changePercent : -changePercent
            if effectiveChange > 2 {
                trend = .improving
            } else if effectiveChange < -2 {
                trend = .declining
            } else {
                trend = .stable
            }

            return MetricSnapshot(
                metric: metric,
                currentValue: periodAvg,
                trend: trend,
                changePercent: changePercent
            )
        }
    }

    // MARK: - Period Summaries

    enum TimePeriod: String, CaseIterable, Identifiable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case allTime = "All"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .allTime: return 3650
            }
        }

        var displayName: String {
            switch self {
            case .sevenDays: return "Last 7 Days"
            case .thirtyDays: return "Last 30 Days"
            case .threeMonths: return "Last 3 Months"
            case .sixMonths: return "Last 6 Months"
            case .oneYear: return "Last Year"
            case .allTime: return "All Time"
            }
        }
    }

    struct MetricChange: Identifiable {
        var id: String { metric.rawValue }
        let metric: HealthMetric
        let periodAvg: Double
        let previousPeriodAvg: Double
        let changePercent: Double
        let improved: Bool
    }

    struct PeriodSummary {
        let topImproved: [MetricChange]
        let topDeclined: [MetricChange]
        let stableMetrics: [MetricChange]

        var improvedCount: Int { topImproved.count }
        var declinedCount: Int { topDeclined.count }
        var stableCount: Int { stableMetrics.count }
    }

    /// Period summary filtered to only metrics matching user's health focuses
    func focusFilteredPeriodSummary(for period: TimePeriod) -> PeriodSummary {
        let base = periodSummary(for: period)
        let categories = insights.focusCategories
        guard !categories.isEmpty else { return base }
        return PeriodSummary(
            topImproved: base.topImproved.filter { categories.contains($0.metric.category) },
            topDeclined: base.topDeclined.filter { categories.contains($0.metric.category) },
            stableMetrics: base.stableMetrics.filter { categories.contains($0.metric.category) }
        )
    }

    func periodSummary(for period: TimePeriod) -> PeriodSummary {
        let days = period.days
        var improved: [MetricChange] = []
        var declined: [MetricChange] = []
        var stable: [MetricChange] = []

        for (metric, series) in healthKitManager.timeSeries {
            let currentSamples = series.samples(lastDays: days)
            let previousSamples = series.sortedSamples.filter { sample in
                let daysAgo = Calendar.current.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
                return daysAgo >= days && daysAgo < days * 2
            }

            guard !currentSamples.isEmpty, !previousSamples.isEmpty else { continue }

            let currentAvg = currentSamples.map(\.value).mean
            let previousAvg = previousSamples.map(\.value).mean

            guard previousAvg != 0 else { continue }

            let change = ((currentAvg - previousAvg) / previousAvg) * 100
            let isImproved = metric.higherIsBetter ? change > 2 : change < -2
            let isDeclined = metric.higherIsBetter ? change < -2 : change > 2

            let mc = MetricChange(
                metric: metric,
                periodAvg: currentAvg,
                previousPeriodAvg: previousAvg,
                changePercent: change,
                improved: isImproved
            )

            if isImproved {
                improved.append(mc)
            } else if isDeclined {
                declined.append(mc)
            } else {
                stable.append(mc)
            }
        }

        improved.sort { abs($0.changePercent) > abs($1.changePercent) }
        declined.sort { abs($0.changePercent) > abs($1.changePercent) }
        stable.sort { $0.metric.displayName < $1.metric.displayName }

        return PeriodSummary(
            topImproved: improved,
            topDeclined: declined,
            stableMetrics: stable
        )
    }

    // MARK: - New Engines

    let strainScorer = StrainScorer()
    let stressScorer = StressScorer()
    let sleepNeedCalculator = SleepNeedCalculator()
    let sleepDebtTracker = SleepDebtTracker()
    let menstrualCycleTracker = MenstrualCycleTracker()
    let gamificationEngine = GamificationEngine()
    let vitalityScorer = VitalityScorer()
    let brainHealthScorer = BrainHealthScorer()
    let strainCoach = StrainCoach()

    init(
        healthKitManager: HealthKitManager,
        analysisEngine: AnalysisEngine,
        store: HealthDataStore,
        persistence: PersistenceManager = PersistenceManager(),
        appStateStore: AppStateStore = AppStateStore(),
        intentCacheStore: IntentCacheStore = IntentCacheStore(),
        smartActionAdvisor: DashboardSmartActionAdvisor = DashboardSmartActionAdvisor(),
        housekeepingService: DashboardHousekeepingService? = nil,
        derivedStateBuilder: DashboardDerivedStateBuilder = DashboardDerivedStateBuilder()
    ) {
        self.persistence = persistence
        self.appStateStore = appStateStore
        self.intentCacheStore = intentCacheStore
        self.smartActionAdvisor = smartActionAdvisor
        self.housekeepingService = housekeepingService ?? DashboardHousekeepingService(persistenceManager: persistence)
        self.derivedStateBuilder = derivedStateBuilder
        ui = UIState(appStateStore: appStateStore)
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
        self.store = store
    }

    /// Use results produced by onboarding calibration without re-running heavy first-load work.
    /// Assumes shared `healthKitManager` + `analysisEngine` were already populated.
    @MainActor
    func hydrateFromCalibration() {
        ui.isLoading = false
        ui.errorMessage = nil
        ui.hasCompletedInitialLoad = true
        updateCachedProperties()
        computeNewEngines()
        lastAnalysisDate = Date()
    }

    /// Initial load: authorize, fetch, analyze.
    /// `skipDiscovery` is used by onboarding calibration to avoid extra first-day computation.
    @MainActor
    func load(
        skipDiscovery: Bool = false,
        awaitDeferredAnalysis: Bool = false,
        forceHeavyDeferred: Bool = false,
        runHousekeeping: Bool = true
    ) async {
        ui.isLoading = true
        defer { ui.isLoading = false }

        if UITestMode.isEnabled {
            ui.hasCompletedInitialLoad = true
            return
        }

        guard healthKitManager.isHealthKitAvailable else {
            ui.errorMessage = "HealthKit is not available on this device. Please run on a real iPhone with the Health app enabled."
            AppAnalytics.shared.trackError(type: "healthkit_unavailable", screen: .home)
            return
        }

        await healthKitManager.requestAuthorization()

        guard healthKitManager.isAuthorized else {
            let msg = healthKitManager.error ?? "HealthKit authorization required"
            ui.errorMessage = msg
            AppAnalytics.shared.trackError(type: "healthkit_auth_failed", screen: .home, message: msg)
            return
        }

        await refresh(
            awaitDeferredAnalysis: awaitDeferredAnalysis,
            forceHeavyDeferred: forceHeavyDeferred,
            runHousekeeping: runHousekeeping
        )
        ui.hasCompletedInitialLoad = true

        // Day 0 discovery generation — after refresh so all data is available.
        // Skipped when onboarding already provides a dedicated calibration flow.
        if ui.isFirstLaunchSync && !skipDiscovery {
            ui.syncPhase = .discovering
            let results = DiscoveryEngine.generateDiscoveries(
                timeSeries: healthKitManager.timeSeries,
                correlations: analysisEngine.correlations,
                historicalContext: analysisEngine.historicalContext
            )
            if results.count >= DiscoveryEngine.minimumDiscoveriesRequired {
                ui.discoveries = results
                ui.showDiscovery = true
            } else {
                // Do not keep users in perpetual "first launch sync" when data is still sparse.
                appStateStore.markDiscoverySeen()
            }
            ui.syncPhase = .complete
        }
    }

    /// Dismiss the discovery view and mark as seen
    func dismissDiscovery() {
        ui.showDiscovery = false
        appStateStore.markDiscoverySeen()
    }

    /// True when the initial load finished but no health data is available despite authorization.
    /// Used by Home timer and scene-phase recovery to trigger automatic retries.
    var needsSyncRetry: Bool {
        ui.hasCompletedInitialLoad && healthKitManager.timeSeries.isEmpty && healthKitManager.isAuthorized
    }

    /// Retry the full sync if Home is stuck in empty state.
    /// Debounced so concurrent calls from timer + scene-phase don't overlap.
    func retrySyncIfNeeded() async {
        guard needsSyncRetry, !isSyncRetryInProgress else { return }
        if let lastAttempt = lastSyncRetryAttempt,
           Date().timeIntervalSince(lastAttempt) < Self.syncRetryMinInterval {
            return
        }

        lastSyncRetryAttempt = Date()
        isSyncRetryInProgress = true
        defer { isSyncRetryInProgress = false }
        await refresh()
    }

    /// Re-sync after connectivity is restored, throttled to avoid repeated heavy work.
    /// Returns true when a refresh was actually triggered.
    func refreshAfterConnectivityRestoreIfNeeded() async -> Bool {
        guard ui.hasCompletedInitialLoad else { return false }
        guard healthKitManager.isAuthorized else { return false }
        guard !ui.isLoading, !isSyncRetryInProgress else { return false }

        if let lastRecovery = lastConnectivityRecoverySync,
           Date().timeIntervalSince(lastRecovery) < Self.connectivityRecoveryMinInterval {
            return false
        }

        lastConnectivityRecoverySync = Date()
        await refresh()
        return true
    }

    /// Refresh data from HealthKit, sync to on-device store, and re-run analysis.
    /// Skips the heavy analysis pipeline if no new data arrived and we analyzed recently.
    /// Note: Does NOT manage `isLoading` — callers (`load()`, `.refreshable`) manage their own loading state.
    func refresh(
        awaitDeferredAnalysis: Bool = false,
        forceHeavyDeferred: Bool = false,
        runHousekeeping: Bool = true
    ) async {
        let refreshToken = await MainActor.run { () -> UUID in
            let next = UUID()
            refreshRunToken = next
            // Invalidate cached score history so this refresh cycle re-fetches fresh data
            _cachedScoreHistory = nil
            return next
        }

        // Capture previous trends before re-analysis
        let prevTrends = previousTrends

        // Load stored data + incrementally sync new data from HealthKit
        if ui.isFirstLaunchSync { ui.syncPhase = .importing }
        let syncResult = await healthKitManager.loadAndSync(store: store)

        // Skip full analysis only if no new data, analyzed within 5 minutes, AND same calendar day
        let now = Date()
        let recentlyAnalyzed = lastAnalysisDate.map { now.timeIntervalSince($0) < Self.analysisMinInterval } ?? false
        let sameDay = lastAnalysisDate.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
        if !syncResult.hasNewData && recentlyAnalyzed && sameDay && !syncResult.isFirstSync {
            // Still refresh lightweight cached properties (data depth, scores display)
            await MainActor.run { updateCachedProperties() }
            return
        }

        if ui.isFirstLaunchSync { ui.syncPhase = .analyzing }

        let ts = healthKitManager.timeSeries
        async let cycleFlowSamplesTask = healthKitManager.fetchMenstrualFlowSamples(days: 365)
        // Fetch raw per-sample HR for today — needed for accurate strain zone classification.
        // The stored time series only has daily averages, losing per-minute granularity.
        async let todayRawHRTask = healthKitManager.fetchTodayRawHeartRateSamples()

        // Phase 1: Core analysis — scores, trends, baselines (blocks until done, UI needs these)
        // Pass user's onboarding focus categories so focused areas weigh more in scoring.
        // Use cached focuses if available; otherwise load once (first refresh before updateCachedProperties runs).
        let focusCats: Set<HealthCategory>
        if !insights.cachedFocusCategories.isEmpty {
            focusCats = insights.cachedFocusCategories
        } else {
            let freshFocuses = persistence.loadHealthFocuses()
            insights.cachedHealthFocuses = freshFocuses
            focusCats = HealthFocus.categories(for: freshFocuses)
            insights.cachedFocusCategories = focusCats
        }
        await Task.detached(priority: .userInitiated) { [analysisEngine, focusCats] in
            analysisEngine.runCoreAnalysis(timeSeries: ts, focusCategories: focusCats)
        }.value

        let todayRawHR = await todayRawHRTask

        // Persist snapshot, update caches, and compute engines on main actor.
        // HealthDataStore is @MainActor for ModelContext thread safety; updateCachedProperties
        // also reads score history from the store for score change computation.
        await MainActor.run {
            store.saveAnalysisSnapshot(
                overallScore: overallScore.score,
                categoryScores: analysisEngine.categoryScores,
                baselines: analysisEngine.baselines
            )
            // Invalidate score history cache after saving — the new snapshot is now part of the data
            invalidateScoreHistoryCache()
            updateCachedProperties()
            computeNewEngines(todayRawHR: todayRawHR)
        }

        // Mark analysis timestamp so subsequent no-change refreshes can skip
        lastAnalysisDate = Date()

        // Store current trends for next refresh comparison
        previousTrends = analysisEngine.trends.mapValues { $0.direction }

        // Phase 2: Deferred analysis + housekeeping (fire-and-forget background)
        // Insight generators, health risks, notifications, analytics — all non-blocking
        let currentScore = overallScore.score
        let currentAnomalies = analysisEngine.anomalies
        let currentTrends = analysisEngine.trends
        let currentCategoryScores = analysisEngine.categoryScores
        let currentBaselines = analysisEngine.baselines
        let metricsCount = healthKitManager.timeSeries.count

        // Calibration mode: wait for full deferred analysis before returning.
        if awaitDeferredAnalysis {
            let cycleFlowSamples = await cycleFlowSamplesTask
            await Task.detached(priority: .utility) { [analysisEngine] in
                analysisEngine.runDeferredEssentials(
                    timeSeries: ts,
                    cycleFlowSamples: cycleFlowSamples
                )
            }.value

            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
            await MainActor.run { updateCachedProperties() }

            await Task.detached(priority: .background) { [analysisEngine] in
                analysisEngine.runDeferredHeavy(timeSeries: ts, force: forceHeavyDeferred)
            }.value

            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
            await MainActor.run { updateCachedProperties() }

            await runPostHeavyPhase(
                timeSeries: ts,
                prevTrends: prevTrends,
                currentScore: currentScore,
                currentAnomalies: currentAnomalies,
                currentTrends: currentTrends,
                currentCategoryScores: currentCategoryScores,
                currentBaselines: currentBaselines,
                metricsCount: metricsCount,
                runHousekeeping: runHousekeeping
            )

            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
            // ML pipeline — runs after rule-based analysis completes
            await runMLPhase(timeSeries: ts)

            return
        }

        // Phase 2A: Essential insights — lightweight (~15K ops), runs immediately
        let cycleFlowSamples = await cycleFlowSamplesTask

        // Compute menstrual cycle if applicable
        if menstrualCycleTracker.isApplicable {
            await menstrualCycleTracker.compute(from: healthKitManager)
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            try? Task.checkCancellation()
            self.analysisEngine.runDeferredEssentials(
                timeSeries: ts,
                cycleFlowSamples: cycleFlowSamples
            )
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
            await MainActor.run { self.updateCachedProperties() }
        }

        // Phase 2B: Heavy analysis + housekeeping — delayed for thermal relief
        Task.detached(priority: .background) { [weak self, prevTrends] in
            guard let self else { return }
            let analysisEngine = self.analysisEngine
            let logger = Logger(subsystem: "com.healthpulse", category: "Dashboard")

            // Thermal break — let CPU cool after core + essentials
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }

            // Gate on thermal state — skip heavy work entirely if device is overheating
            if ThermalManager.shared.shouldThrottle {
                logger.warning("Skipping deferred heavy analysis — thermal state is elevated")
                return
            }

            // Wait for ML analysis to complete before starting heavy cross-metric work
            // so we don't stack CPU-intensive phases on top of each other
            var waitIterations = 0
            while analysisEngine.mlOrchestrator.isRunning {
                guard !Task.isCancelled else { return }
                guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
                waitIterations += 1
                if waitIterations > 120 { break } // Safety: max 60s wait
                try? await Task.sleep(for: .milliseconds(500))
            }

            // Heavy cross-metric analysis (correlations, historical, causal chains)
            // Skipped automatically if results are still fresh (1-hour TTL)
            analysisEngine.runDeferredHeavy(timeSeries: ts, force: forceHeavyDeferred)
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }

            // Update cached properties now that correlations + historicalContext are available
            await MainActor.run { self.updateCachedProperties() }

            await self.runPostHeavyPhase(
                timeSeries: ts,
                prevTrends: prevTrends,
                currentScore: currentScore,
                currentAnomalies: currentAnomalies,
                currentTrends: currentTrends,
                currentCategoryScores: currentCategoryScores,
                currentBaselines: currentBaselines,
                metricsCount: metricsCount,
                runHousekeeping: runHousekeeping
            )
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }

            // ML pipeline — runs after rule-based analysis completes
            await self.runMLPhase(timeSeries: ts)
        }
    }

    /// Runs post-heavy enrichments and optional housekeeping (backup/notifications/analytics).
    private func runPostHeavyPhase(
        timeSeries: [HealthMetric: MetricTimeSeries],
        prevTrends: [HealthMetric: TrendDirection],
        currentScore: Int,
        currentAnomalies: [AnomalyDetector.AnomalyResult],
        currentTrends: [HealthMetric: TrendAnalyzer.TrendResult],
        currentCategoryScores: [HealthScore],
        currentBaselines: [HealthMetric: UserBaseline],
        metricsCount: Int,
        runHousekeeping: Bool
    ) async {
        let currentCorrelations = analysisEngine.correlations

        // Score trajectory + baseline drift insights (need stored history)
        // Store is @MainActor — hop to main actor for SwiftData reads
        let scoreHistory = await MainActor.run { scoreHistoryCached(days: 60) }
        let trajectoryInsights = ScoreTrajectoryAnalyzer.generateInsights(
            scoreHistory: scoreHistory,
            categoryScores: currentCategoryScores
        )
        let baselineHistory = await MainActor.run { store.loadAllBaselineHistory(forMetrics: Set(currentBaselines.keys)) }
        var extraInsights = trajectoryInsights
        if !baselineHistory.isEmpty {
            extraInsights.append(contentsOf: BaselineDriftDetector.generateInsights(
                currentBaselines: currentBaselines,
                baselineHistory: baselineHistory,
                correlations: currentCorrelations
            ))
        }
        if !extraInsights.isEmpty {
            analysisEngine.insights.append(contentsOf: extraInsights)
            analysisEngine.insights = InsightCoordinator.coordinate(analysisEngine.insights)
        }

        // Circadian analysis (weekly, hourly data fetch)
        if analysisEngine.mlOrchestrator.needsCircadianAnalysis {
            let metricsForCircadian = CircadianAnalyzer.metricsToAnalyze + CircadianAnalyzer.optionalMetrics
            var hourlyData: [HealthMetric: [[Double]]] = [:]
            await withTaskGroup(of: (HealthMetric, [[Double]]?).self) { group in
                for metric in metricsForCircadian {
                    group.addTask { [healthKitManager] in
                        let data = await healthKitManager.fetchHourlySamples(metric, days: 30)
                        return (metric, data)
                    }
                }
                for await (metric, data) in group {
                    if let data { hourlyData[metric] = data }
                }
            }
            if !hourlyData.isEmpty {
                analysisEngine.mlOrchestrator.runCircadianAnalysis(hourlyData: hourlyData)
            }
        }

        guard runHousekeeping else { return }

        let periodSummary7d = await MainActor.run { self.periodSummary(for: .sevenDays) }
        await housekeepingService.perform(
            store: store,
            payload: DashboardHousekeepingService.Payload(
                currentScore: currentScore,
                currentAnomalies: currentAnomalies,
                currentTrends: currentTrends,
                previousTrends: prevTrends,
                currentCategoryScores: currentCategoryScores,
                metricsCount: metricsCount,
                timeSeries: timeSeries,
                insights: analysisEngine.insights,
                healthRisksCount: analysisEngine.healthRisks.count,
                correlationsCount: currentCorrelations.count,
                illnessWarningsCount: analysisEngine.illnessWarnings.count,
                strainLabel: strainScorer.strainLabel,
                scoreChangeFromYesterday: scores.cachedScoreChangeFromYesterday,
                periodSummary: periodSummary7d
            )
        )
    }

    // MARK: - ML Pipeline

    /// Runs the on-device ML analysis pipeline after rule-based analysis completes.
    /// Uses score history from SwiftData and anomaly counts derived from stored snapshots.
    private func runMLPhase(timeSeries: [HealthMetric: MetricTimeSeries]) async {
        // Use cached score history — already fetched earlier in the refresh cycle
        let scoreHistory = await MainActor.run { scoreHistoryCached() }

        // Build anomaly counts per day from stored analysis snapshots.
        // Each snapshot records the anomaly count for that day's analysis run.
        var anomalyCounts: [Date: Int] = [:]
        for entry in scoreHistory {
            // Score history entries correspond to daily analysis runs;
            // use today's live anomaly count for the current day, 0 for historical.
            anomalyCounts[entry.date] = 0
        }
        let today = Calendar.current.startOfDay(for: Date())
        anomalyCounts[today] = analysisEngine.anomalies.count

        guard !RemoteConfigManager.shared.killMLPipeline else { return }

        // Use cached focus categories — already loaded by refresh() or updateCachedProperties()
        let focusCats = insights.cachedFocusCategories
        await analysisEngine.runMLAnalysis(
            timeSeries: timeSeries,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts,
            focusCategories: focusCats
        )
        await MainActor.run { updateCachedProperties() }
    }

    // MARK: - Cache Update (called once per refresh, not per render)

    @MainActor
    private func updateCachedProperties() {
        // Cache raw focuses + derived categories (Keychain + AES-GCM decrypt — do once, not per view access)
        let focuses = persistence.loadHealthFocuses()
        insights.cachedHealthFocuses = focuses
        insights.cachedFocusCategories = HealthFocus.categories(for: focuses)

        // Cache focused insights (depends on focus categories)
        let categories = insights.cachedFocusCategories
        insights.cachedFocusedInsights = analysisEngine.insights.filter { insight in
            insight.severity >= .warning || categories.contains(insight.metric.category)
        }

        // Update score state
        scores.overallScore = analysisEngine.overallScore
        scores.categoryScores = analysisEngine.categoryScores
        scores.cachedScoreChangeFromLastWeek = computeScoreChangeFromLastWeek()
        scores.cachedScoreChangeFromYesterday = computeScoreChangeFromYesterday()
        scores.scoreExplanation = analysisEngine.scoreExplanation

        // Update trend state
        trends.cachedTrendsSummary = computeTrendsSummary()
        trends.cachedTrendMetricsByTimeframe = [
            7: computeTrendMetrics(days: 7),
            30: computeTrendMetrics(days: 30),
            90: computeTrendMetrics(days: 90),
        ]

        // Update analysis state
        analysis.cachedHistoricalHighlights = computeHistoricalHighlights()
        analysis.cachedTopCorrelations = computeTopCorrelations()
        analysis.correlations = analysisEngine.correlations
        analysis.healthRisks = analysisEngine.healthRisks
        analysis.topHealthRisks = analysisEngine.healthRisks.filter { $0.riskGrade != .low }
        analysis.todayHealthRisks = analysisEngine.healthRisks.filter { $0.riskGrade != .low }
        analysis.illnessWarnings = analysisEngine.illnessWarnings
        analysis.hasIllnessWarning = !analysisEngine.illnessWarnings.isEmpty
        analysis.topIllnessWarning = analysisEngine.illnessWarnings.first
        analysis.crossMetricAnomalies = analysisEngine.crossMetricAnomalies
        analysis.causalChains = analysisEngine.causalChains
        analysis.topCausalChain = analysisEngine.causalChains.first

        // Update data depth
        let series = healthKitManager.timeSeries
        let metrics = series.count
        let points = series.values.reduce(0) { $0 + $1.totalDataPoints }
        let maxDays = series.values.map(\.daysOfData).max() ?? 0
        analysis.dataDepth = (metrics, points, maxDays)

        // Update anomaly state
        anomalies.anomalousMetrics = analysisEngine.anomalies.filter { $0.severity >= .warning }
        anomalies.criticalAlertCount = analysisEngine.anomalies.filter { $0.severity == .critical }.count
        anomalies.warningAlertCount = analysisEngine.anomalies.filter { $0.severity == .warning }.count

        // Cache lightweight score data for Siri intents (avoids SwiftData conflicts)
        let score = overallScore.score
        let topAreas = analysisEngine.categoryScores
            .sorted { $0.score < $1.score }
            .prefix(2)
            .compactMap { s -> String? in
                guard let cat = s.category else { return nil }
                return "\(cat.shortName) \(s.score)"
            }
        let summaryText = topAreas.isEmpty ? "" : "Areas to watch: \(topAreas.joined(separator: ", "))."
        intentCacheStore.saveHealthSummary(
            score: score,
            grade: overallScore.grade,
            summary: summaryText
        )

        // Save shown recommendations for outcome tracking
        let insightsToSave = insights.cachedFocusedInsights.prefix(10)
        Task { @MainActor [store] in
            for insight in insightsToSave {
                store.saveRecommendation(insight)
            }
        }
    }

    // MARK: - New Engine Computation

    @MainActor
    private func computeNewEngines(todayRawHR: [MetricSample] = []) {
        let profile = UserProfileStore.shared.loadLocal()
        let age = profile?.ageFromDateOfBirth ?? 30
        let timeSeries = healthKitManager.timeSeries
        let sleepSeries = timeSeries[.sleepDuration]

        // Strain — pass raw per-sample HR for accurate zone classification,
        // and in-memory time series for freshest data (avoids SwiftData read lag).
        strainScorer.compute(
            from: store,
            age: age,
            restingHR: analysisEngine.baselines[.restingHeartRate]?.mean,
            todayHRSamples: todayRawHR,
            timeSeries: timeSeries
        )

        // Strain Coach
        let _ = strainCoach.computeTarget(
            recoveryState: recoveryState,
            currentStrain: strainScorer.currentStrain,
            recentStrainHistory: strainScorer.weeklyStrainHistory,
            daysOfData: analysis.dataDepth.daysOfData
        )

        // Stress
        stressScorer.compute(from: store, timeSeries: timeSeries)

        // Brain Health — pass in-memory timeSeries for guaranteed freshness
        brainHealthScorer.compute(from: store, timeSeries: timeSeries)

        // Sleep debt
        sleepDebtTracker.compute(from: store, sleepSeries: sleepSeries)

        // Sleep need
        let debtHours = sleepDebtTracker.currentDebt?.totalDebtHours ?? 0
        let need = sleepNeedCalculator.compute(
            from: store,
            currentStrain: strainScorer.currentStrain,
            sleepDebt: debtHours,
            targetWakeTime: nil,
            sleepSeries: sleepSeries
        )
        _ = need  // stored internally in sleepNeedCalculator

        // Gamification
        let sessionDays = SessionTracker.shared.daysSinceInstall
        let scoreHistory = scoreHistoryCached().map { (date: $0.date, score: $0.score) }
        gamificationEngine.compute(
            from: store,
            sessionDays: sessionDays,
            scores: scoreHistory,
            timeSeries: timeSeries
        )

        // Vitality Age — pass in-memory timeSeries for guaranteed freshness
        vitalityScorer.compute(from: store, chronologicalAge: age, timeSeries: timeSeries)

        // Menstrual cycle — female users + explicit onboarding opt-in.
        // Backward compatibility: if preference is absent (older installs), keep prior behavior.
        let isFemale = profile?.gender == .female
        let cyclePreference = UserDefaults.standard.object(forKey: AppKeys.Cycle.trackingEnabled) as? Bool
        let cycleTrackingEnabled = cyclePreference ?? true
        menstrualCycleTracker.isApplicable = isFemale && cycleTrackingEnabled
    }

    // MARK: - Score History Cache

    /// Returns the cached 365-day score history, fetching once per refresh cycle.
    /// All callers that need score history should use this instead of `store.loadScoreHistory()`
    /// to avoid redundant SwiftData fetches + JSON decoding during a single refresh.
    @MainActor
    private func scoreHistoryCached() -> [(date: Date, score: Int)] {
        if let cached = _cachedScoreHistory { return cached }
        let history = store.loadScoreHistory(days: 365)
        _cachedScoreHistory = history
        return history
    }

    /// Returns the cached score history filtered to the most recent N days.
    @MainActor
    private func scoreHistoryCached(days: Int) -> [(date: Date, score: Int)] {
        let all = scoreHistoryCached()
        guard days < 365 else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all.filter { $0.date >= cutoff }
    }

    /// Clears the cached score history so the next access re-fetches from the store.
    @MainActor
    private func invalidateScoreHistoryCache() {
        _cachedScoreHistory = nil
    }

    @MainActor
    private func computeScoreChangeFromLastWeek() -> Int? {
        derivedStateBuilder.scoreChangeFromLastWeek(
            currentScore: overallScore.score,
            history: scoreHistoryCached(days: 14)
        )
    }

    @MainActor
    private func computeScoreChangeFromYesterday() -> Int? {
        derivedStateBuilder.scoreChangeFromYesterday(
            currentScore: overallScore.score,
            history: scoreHistoryCached(days: 3)
        )
    }

    private func computeTrendsSummary() -> TrendsSummary {
        derivedStateBuilder.trendsSummary(
            trends: analysisEngine.trends.map { metric, trend in
                DashboardDerivedStateBuilder.TrendSnapshot(
                    metric: metric,
                    direction: trend.direction,
                    weekOverWeekChange: trend.weekOverWeekChange
                )
            },
            focusCategories: insights.focusCategories
        )
    }

    private func computeTrendMetrics(days: Int) -> [TrendMetricItem] {
        var items: [TrendMetricItem] = []
        for (metric, series) in healthKitManager.timeSeries {
            guard let trend = TrendAnalyzer.canonicalTrend(
                metric: metric,
                series: series,
                analysisEngine: analysisEngine,
                days: days
            ) else { continue }
            let samples = series.samples(lastDays: days)
            guard samples.count >= 3 else { continue }
            items.append(TrendMetricItem(
                metric: metric,
                trend: trend,
                sparklineSamples: samples
            ))
        }
        items.sort { abs($0.trend.weekOverWeekChange) > abs($1.trend.weekOverWeekChange) }
        return items
    }

    private func computeTopCorrelations() -> [HealthCorrelation] {
        derivedStateBuilder.topCorrelations(
            from: analysisEngine.correlations,
            focusCategories: insights.focusCategories
        )
    }

    private func computeHistoricalHighlights() -> [HistoricalHighlight] {
        var highlights: [HistoricalHighlight] = []
        let focuses = insights.focusCategories

        // Week-over-week comparison for the Home/Coach screen
        for (metric, series) in healthKitManager.timeSeries {
            let thisWeek = series.samples(lastDays: 7)
            let lastWeek = series.sortedSamples.filter { sample in
                let daysAgo = Calendar.current.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
                return daysAgo >= 7 && daysAgo < 14
            }

            guard !thisWeek.isEmpty, !lastWeek.isEmpty else { continue }

            let thisAvg = thisWeek.map(\.value).mean
            let lastAvg = lastWeek.map(\.value).mean
            guard lastAvg != 0 else { continue }

            let change = ((thisAvg - lastAvg) / lastAvg) * 100
            guard abs(change) > 3 else { continue }

            let improving = metric.higherIsBetter ? change > 0 : change < 0
            let direction = change > 0 ? "up" : "down"
            let rec = improving
                ? "Good trend — keep it going this week."
                : RulesConfiguration.recommendation(for: metric, severity: .warning, trend: .declining)

            highlights.append(HistoricalHighlight(
                metric: metric,
                type: .weekOverWeek,
                title: "\(metric.displayName) \(direction) \(String(format: "%.0f", abs(change)))% this week",
                recommendation: rec,
                isPositive: improving,
                significance: abs(change)
            ))
        }

        highlights.sort { a, b in
            let aFocus = !focuses.isEmpty && focuses.contains(a.metric.category)
            let bFocus = !focuses.isEmpty && focuses.contains(b.metric.category)
            if aFocus != bFocus { return aFocus }
            return a.significance > b.significance
        }
        return Array(highlights.prefix(5))
    }


    // MARK: - Struct Definitions (kept at DashboardViewModel level for external type references)

    /// Global trends summary across all tracked metrics
    struct TrendsSummary {
        let improving: Int
        let stable: Int
        let declining: Int
        let topMovers: [MetricMover]
    }

    struct MetricMover: Identifiable {
        var id: String { metric.rawValue }
        let metric: HealthMetric
        let changePercent: Double
        let improving: Bool
    }

    /// Historical highlights computed from deep analysis context
    struct HistoricalHighlight: Identifiable {
        let id = UUID()
        let metric: HealthMetric
        let type: HighlightType
        let title: String
        let recommendation: String
        let isPositive: Bool
        let significance: Double

        enum HighlightType {
            case weekOverWeek
            case yearOverYear
            case allTimeExtreme
            case seasonal
            case longTermTrajectory
        }

        var icon: String {
            switch type {
            case .weekOverWeek: return "calendar.badge.clock"
            case .yearOverYear: return "calendar.badge.clock"
            case .allTimeExtreme: return "trophy.fill"
            case .seasonal: return "leaf.fill"
            case .longTermTrajectory: return "chart.line.uptrend.xyaxis"
            }
        }

        var typeLabel: String {
            switch type {
            case .weekOverWeek: return "This Week"
            case .yearOverYear: return "Year-over-Year"
            case .allTimeExtreme: return "All-Time"
            case .seasonal: return "Seasonal"
            case .longTermTrajectory: return "Long-Term"
            }
        }
    }

    /// Single source of truth for what to do today.
    /// Weighs ML policy decision, recovery, strain, goals, trends, and risks — outputs one clear recommendation.
    func smartDailyAction(liveVM: LiveViewModel) -> SmartAction {
        let recommendation = smartActionAdvisor.recommend(
            live: DashboardSmartActionAdvisor.LiveSnapshot(
                hour: Calendar.current.component(.hour, from: Date()),
                stressLevel: liveVM.recovery.stressLevel,
                readinessScore: liveVM.recovery.readinessScore,
                hasSleepData: liveVM.sleep.hasSleepData,
                sleepHours: liveVM.sleep.lastNightSleepDuration / 3600,
                deepSleepMinutes: liveVM.sleep.lastNightDeepSleep / 60,
                exerciseMinutes: liveVM.activity.todayExerciseMinutes,
                exerciseGoal: liveVM.activity.exerciseGoal,
                latestRestingHeartRate: liveVM.recovery.latestRestingHeartRate
            ),
            analysis: DashboardSmartActionAdvisor.AnalysisSnapshot(
                policyDecision: analysisEngine.mlOrchestrator.policyDecision,
                restingHeartRateBaselineMean: analysisEngine.baselines[.restingHeartRate]?.mean,
                userFocuses: insights.cachedHealthFocuses
            )
        )
        return SmartAction(
            icon: recommendation.icon,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            source: recommendation.source
        )
    }

    struct SmartAction {
        let icon: String
        let title: String
        let subtitle: String
        var source: String = "context_rules"
    }

    private var recentActivityTrendDirection: TrendDirection? {
        let metrics: [HealthMetric] = [
            .exerciseMinutes, .activeCalories, .steps, .workoutDuration, .workoutCount, .distanceWalkingRunning
        ]
        let trends = metrics.compactMap { analysisEngine.trends[$0] }
        guard !trends.isEmpty else { return nil }

        let improvingCount = trends.filter { $0.direction == .improving }.count
        let decliningCount = trends.filter { $0.direction == .declining }.count
        if improvingCount > decliningCount { return .improving }
        if decliningCount > improvingCount { return .declining }

        let averageChange = trends.map(\.weekOverWeekChange).mean
        if averageChange > 2 { return .improving }
        if averageChange < -2 { return .declining }
        return .stable
    }
}
