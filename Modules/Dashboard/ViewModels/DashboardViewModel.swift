import Foundation
import Observation
import SwiftUI
import os

/// Smoothing parameters for the Explore weekly score (`computeRollingAverageScore`).
/// Anchored to EWMA literature and commercial wearable practice; see that
/// function's doc comment for source links.
enum WeeklyScoreSmoothing {
    /// EWMA decay parameter. 0.05–0.25 is the standard tutorial range for
    /// non-stationary health time series; 0.2 trends recent days without
    /// over-reacting to a single outlier day.
    static let lambda: Double = 0.2

    /// Two weeks of completed daily snapshots. Long enough that one bad day
    /// cannot dominate the visible weekly number, short enough to track real
    /// adaptations in HRV / sleep / activity.
    static let windowDays: Int = 14
}

/// ViewModel for the main dashboard showing overall score, top insights, and category cards.
/// Properties are grouped into nested @Observable sub-objects to reduce unnecessary SwiftUI re-renders.
@MainActor @Observable
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
    private static let syncRetryMinInterval: TimeInterval = 600  // 10 minutes
    private static let connectivityRecoveryMinInterval: TimeInterval = 900  // 15 minutes
    private static let foregroundRefreshMinInterval: TimeInterval = 30  // 30 seconds
    private var lastConnectivityRecoverySync: Date?
    private var lastForegroundRefresh: Date?
    @MainActor private var refreshRunToken = UUID()
    /// Handles for detached Phase 2A/2B tasks so we can cancel stale work on new refresh
    private var deferredEssentialsTask: Task<Void, Never>?
    private var deferredHeavyTask: Task<Void, Never>?

    /// Deduplicates overlapping refresh calls (e.g., ContentView .task + HomeView .onAppear + scene phase .active).
    /// Each new call cancels the previous task and debounces by 0.5s so rapid-fire triggers coalesce into one refresh.
    private var refreshTask: Task<Void, Never>?

    /// Previous trend directions. used for trend reversal detection
    private var previousTrends: [HealthMetric: TrendDirection] = [:]

    /// Fingerprint of timeSeries input from last computeNewEngines call.
    /// Scorers skip recomputation if data hasn't changed within the same calendar day.
    @MainActor private var lastScorerInputHash: Int = 0
    @MainActor private var lastScorerDay: Int = 0

    /// Fingerprint of the inputs that drive the expensive derived caches (trend
    /// metrics, historical highlights, correlations). updateCachedProperties runs
    /// 4-5× per refresh; this lets those heavy recomputes run only when their
    /// inputs actually changed, while the cheap assignments still run every call.
    @MainActor private var lastExpensiveCacheHash: Int = 0

    /// Cached daily action. computed once per calendar day (or after analysis refresh)
    @MainActor private var _cachedDailyAction: SmartAction?
    @MainActor private var _cachedDailyActionDate: Date?

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
        /// EWMA-vs-EWMA-7-days-ago delta. Used by Explore so the weekly badge
        /// describes the same series as the displayed weekly score.
        fileprivate(set) var cachedWeeklyScoreChange: Int?
        /// Yesterday's stored score, kept separately from the delta above.
        fileprivate(set) var cachedYesterdayScore: Int?
        /// Set by parent after each analysis refresh
        fileprivate(set) var overallScore: HealthScore = HealthScore(score: 0)
        fileprivate(set) var categoryScores: [HealthScore] = []

        var scoreChangeFromLastWeek: Int? { cachedScoreChangeFromLastWeek }
        var scoreChangeFromYesterday: Int? { cachedScoreChangeFromYesterday }
        var weeklyScoreChange: Int? { cachedWeeklyScoreChange }

        /// Same delta as `scoreChangeFromYesterday` but keeping an explicit
        /// zero. That one folds zero into nil so analytics and push stay quiet
        /// on flat days; the Home chip has to show "same as yesterday" and
        /// stay blank only when yesterday has no reading at all.
        var scoreDeltaFromYesterday: Int? {
            cachedYesterdayScore.map { overallScore.score - $0 }
        }

        var recoveryState: RecoveryState {
            RecoveryState(score: overallScore.score)
        }

        /// Score explanation for transparency
        fileprivate(set) var scoreExplanation: HealthScorer.ScoreExplanation?

        /// 7-day rolling average score for Explore tab (differs from today's overallScore).
        /// Falls back to overallScore when insufficient history.
        fileprivate(set) var rollingAverageScore: Int = 0
    }

    @Observable
    final class TrendState {
        /// Pre-computed trend metrics keyed by timeframe (7, 30, 90 days)
        fileprivate(set) var cachedTrendMetricsByTimeframe: [Int: [TrendMetricItem]] = [:]

        /// Returns pre-computed trend metrics for the given timeframe
        func trendMetrics(for days: Int) -> [TrendMetricItem] {
            cachedTrendMetricsByTimeframe[days] ?? []
        }
    }

    @Observable
    final class InsightState {
        /// Raw health focuses from encrypted store. cached to avoid repeated Keychain + AES-GCM decryption.
        fileprivate(set) var cachedHealthFocuses: Set<HealthFocus> = []
        fileprivate(set) var cachedFocusCategories: Set<HealthCategory> = []
        fileprivate(set) var cachedFocusedInsights: [Insight] = []

        var focusCategories: Set<HealthCategory> { cachedFocusCategories }
        var focusedInsights: [Insight] { cachedFocusedInsights }

        var headlineInsight: Insight? { focusedInsights.first }
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
        fileprivate(set) var compoundInsights: [CompoundInsightEngine.CompoundInsight] = []
        fileprivate(set) var interactionEffects: [InteractionEffectEngine.InteractionEffect] = []
        fileprivate(set) var doseResponseCurves: [InteractionEffectEngine.DoseResponseCurve] = []
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

        /// Single source of truth for the recovery state colour. Mirrors the
        /// 3-band model (green/yellow/red), so the home recovery card's title,
        /// pill, and ring all paint from the same threshold table.
        var color: Color {
            switch self {
            case .green: AppColour.scoreOptimal
            case .yellow: AppColour.scoreFair
            case .red: AppColour.scorePoor
            }
        }
    }

    // MARK: - Convenience accessors (kept for backward compat with internal methods)

    var overallScore: HealthScore { scores.overallScore }
    var recoveryState: RecoveryState { scores.recoveryState }

    var lastRefresh: Date? {
        healthKitManager.lastRefresh
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
    }

    struct MetricChange: Identifiable {
        var id: String { metric.rawValue }
        let metric: HealthMetric
        let changePercent: Double
    }

    struct PeriodSummary {
        let topImproved: [MetricChange]
        let topDeclined: [MetricChange]
        let stableMetrics: [MetricChange]

        var improvedCount: Int { topImproved.count }
        var declinedCount: Int { topDeclined.count }
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

        // Previous-period window abuts the current one and reuses the same
        // day-shifted boundary as samples(lastDays:), resolved by O(log n) binary
        // search instead of a per-sample calendar diff over the full history.
        let now = Date()
        let prevEnd = Date.cal.date(byAdding: .day, value: -days, to: now) ?? now
        let prevStart = Date.cal.date(byAdding: .day, value: -days * 2, to: now) ?? now

        for (metric, series) in healthKitManager.timeSeries {
            let currentSamples = series.samples(lastDays: days)
            let previousSamples = series.samples(from: prevStart, until: prevEnd)

            guard !currentSamples.isEmpty, !previousSamples.isEmpty else { continue }

            let currentAvg = currentSamples.map(\.value).mean
            let previousAvg = previousSamples.map(\.value).mean

            guard previousAvg != 0 else { continue }

            let change = ((currentAvg - previousAvg) / previousAvg) * 100
            let isImproved = metric.higherIsBetter ? change > 2 : change < -2
            let isDeclined = metric.higherIsBetter ? change < -2 : change > 2

            let mc = MetricChange(metric: metric, changePercent: change)

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
    let todayIntelligenceEngine = TodayIntelligenceEngine()

    /// Intelligence briefing cards. non-obvious findings from ML algorithms
    @MainActor var intelligenceBriefing: [IntelligenceCard] = []

    // MARK: - Cached View Properties (computed once per refresh, not per render)

    /// Name of the lowest-scoring category. used by ScoreGuideSheet for personalized explanation
    @MainActor var cachedWeakestCategoryName: String?

    /// Pre-built metric tiles for MetricStripView. rebuilt after scorer computation
    @MainActor var cachedMetricTiles: [MetricTile] = []

    // MARK: - Research-Backed Feature State (Papers 1-10)

    /// Personal health forecast cards (Paper 3: Conformal Prediction + Digital Twin)
    @MainActor var healthForecasts: [MetricForecast] = []

    /// Activation sequence state (Paper 8: 8-Day Hook Window)
    @MainActor var activationState: ActivationSequenceManager.ActivationState = ActivationSequenceManager.loadState()
    @MainActor var latestMilestoneEvent: ActivationSequenceManager.MilestoneEvent?

    /// Circadian biomarkers (Paper 7: Chronomedicine)
    @MainActor var circadianBiomarkers: CircadianHealthAnalyzer.CircadianBiomarkers?

    /// Morning check-in adjustment applied to readiness (Paper 10: HRV + Subjective)
    @MainActor var subjectiveReadinessAdjustment: Int = 0

    init(
        healthKitManager: HealthKitManager,
        analysisEngine: AnalysisEngine,
        store: HealthDataStore,
        persistence: PersistenceManager = PersistenceManager(),
        appStateStore: AppStateStore = AppStateStore(),
        intentCacheStore: IntentCacheStore = IntentCacheStore(),
        smartActionAdvisor: DashboardSmartActionAdvisor = DashboardSmartActionAdvisor(),
        housekeepingService: DashboardHousekeepingService,
        derivedStateBuilder: DashboardDerivedStateBuilder = DashboardDerivedStateBuilder()
    ) {
        self.persistence = persistence
        self.appStateStore = appStateStore
        self.intentCacheStore = intentCacheStore
        self.smartActionAdvisor = smartActionAdvisor
        self.housekeepingService = housekeepingService
        self.derivedStateBuilder = derivedStateBuilder
        ui = UIState(appStateStore: appStateStore)
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
        self.store = store
        // Build the initial metric tiles synchronously from whatever the
        // scorers restored from their on-disk snapshots. This way the very
        // first frame after launch shows the last known Vitality and Strain
        // instead of an empty strip (or zeros from a default scorer state).
        // Sleep tile is omitted here since live sleep data isn't available
        // until LiveViewModel populates; HomeView.onAppear rebuilds with sleep.
        rebuildMetricTiles()
        // If a scorer had no on-disk snapshot to restore (fresh install,
        // app update from a build without snapshots, or expired daily Strain
        // snapshot), compute it once synchronously from the persisted
        // SwiftData store so the user sees real values on the very first
        // frame instead of waiting for the async HealthKit refresh to land.
        prewarmScorersFromStoreIfNeeded()
    }

    /// One-shot synchronous warm-up that populates every Intelligence-strip
    /// scorer from persisted SwiftData on launch so the first frame shows
    /// all four tiles (Vitality, Strain, Brain, Stress) together rather
    /// than only the snapshot-restored ones with the rest popping in a
    /// second later. Skips Vitality/Strain when their snapshots already
    /// restored, and skips them entirely if no real chronological age is
    /// available — we never feed engines a fabricated age.
    @MainActor
    private func prewarmScorersFromStoreIfNeeded() {
        let needsVitality = !vitalityScorer.isReady
        let needsStrain = !strainScorer.isReady
        // Brain + Stress have no on-disk snapshot today and their tiles only
        // appear once `currentScore` / `currentStress` is non-nil, so always
        // run them on launch when missing.
        let needsBrain = brainHealthScorer.currentScore == nil
        let needsStress = stressScorer.currentStress == nil

        guard needsVitality || needsStrain || needsBrain || needsStress else { return }

        if needsBrain {
            brainHealthScorer.compute(from: store, timeSeries: nil)
        }
        if needsStress {
            stressScorer.compute(from: store, timeSeries: nil)
        }
        if let age = resolveChronologicalAge() {
            if needsStrain {
                strainScorer.compute(
                    from: store,
                    age: age,
                    restingHR: nil,
                    todayHRSamples: [],
                    timeSeries: nil
                )
            }
            if needsVitality {
                vitalityScorer.compute(from: store, chronologicalAge: age, timeSeries: nil)
            }
        }
        // Tiles built before prewarm reflected the empty default scorer
        // state; rebuild now so the first rendered frame uses the freshly
        // computed values.
        rebuildMetricTiles()
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
        invalidateDailyActionCache()
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
            AppAnalytics.shared.trackScoreGenerationFailed(reason: "healthkit_unavailable")
            return
        }

        await healthKitManager.requestAuthorization()

        guard healthKitManager.isAuthorized else {
            let msg = healthKitManager.error ?? "HealthKit authorization required"
            ui.errorMessage = msg
            AppAnalytics.shared.trackError(type: "healthkit_auth_failed", screen: .home, message: msg)
            AppAnalytics.shared.trackScoreGenerationFailed(reason: "healthkit_unauthorized")
            return
        }

        // Denied-branch payoff: a user who got the re-permission push and then
        // granted Health access here has converted. Fire once.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: AppKeys.Prediction.repermissionFired),
           !defaults.bool(forKey: AppKeys.Prediction.repermissionConverted) {
            defaults.set(true, forKey: AppKeys.Prediction.repermissionConverted)
            AppAnalytics.shared.trackRepermissionConversion()
        }

        await refresh(
            awaitDeferredAnalysis: awaitDeferredAnalysis,
            forceHeavyDeferred: forceHeavyDeferred,
            runHousekeeping: runHousekeeping
        )
        ui.hasCompletedInitialLoad = true

        // Day 0 discovery generation. after refresh so all data is available.
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

    /// Refresh on foreground return so users see today's latest data without pull-to-refresh.
    /// Throttled to 30s to avoid thrashing during quick app switches.
    func refreshOnForegroundIfNeeded() async {
        guard ui.hasCompletedInitialLoad else { return }
        guard healthKitManager.isAuthorized else { return }
        guard !ui.isLoading, !isSyncRetryInProgress else { return }

        if let lastForeground = lastForegroundRefresh,
           Date().timeIntervalSince(lastForeground) < Self.foregroundRefreshMinInterval {
            return
        }

        lastForegroundRefresh = Date()
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
    /// Note: Does NOT manage `isLoading`. callers (`load()`, `.refreshable`) manage their own loading state.
    ///
    /// Deduplicates overlapping calls: cancels any pending debounced refresh, waits 0.5s for
    /// rapid-fire triggers to coalesce, then runs the actual refresh. Callers that pass
    /// `awaitDeferredAnalysis: true` (e.g., onboarding calibration) bypass the debounce.
    func refresh(
        awaitDeferredAnalysis: Bool = false,
        forceHeavyDeferred: Bool = false,
        runHousekeeping: Bool = true
    ) async {
        // Calibration/onboarding needs immediate execution — skip debounce
        if awaitDeferredAnalysis {
            await refreshCore(
                awaitDeferredAnalysis: true,
                forceHeavyDeferred: forceHeavyDeferred,
                runHousekeeping: runHousekeeping
            )
            return
        }

        // Cancel any pending debounced refresh so the latest call wins
        refreshTask?.cancel()

        let task = Task { @MainActor [weak self] in
            // Debounce: wait 0.5s for rapid-fire calls to coalesce
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            await self?.refreshCore(
                awaitDeferredAnalysis: false,
                forceHeavyDeferred: forceHeavyDeferred,
                runHousekeeping: runHousekeeping
            )
        }
        refreshTask = task

        // Await the debounced task so callers (e.g., .refreshable) know when it finishes
        await task.value
    }

    /// Core refresh implementation. Called by the debounced `refresh()` wrapper.
    private func refreshCore(
        awaitDeferredAnalysis: Bool = false,
        forceHeavyDeferred: Bool = false,
        runHousekeeping: Bool = true
    ) async {
        // Cancel any in-flight deferred work from a previous refresh.
        // The refreshRunToken prevents stale results from being applied, but the CPU work
        // itself kept running until hitting a token check. Cancelling here stops it sooner.
        deferredEssentialsTask?.cancel()
        deferredHeavyTask?.cancel()

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
        let thermalManager = ThermalManager.shared
        let recentlyAnalyzed = lastAnalysisDate.map { now.timeIntervalSince($0) < thermalManager.analysisRefreshInterval } ?? false
        let sameDay = lastAnalysisDate.map { Date.cal.isDate($0, inSameDayAs: now) } ?? false
        let shouldReuseThermalSnapshot = thermalManager.shouldThrottle && lastAnalysisDate != nil
        if recentlyAnalyzed && sameDay && !syncResult.isFirstSync {
            if !syncResult.hasNewData || thermalManager.shouldThrottle {
                // Still refresh lightweight cached properties (data depth, scores display)
                await MainActor.run {
                    updateCachedProperties()
                    writeWidgetSnapshots()
                }
                return
            }
        }

        if ui.isFirstLaunchSync { ui.syncPhase = .analyzing }

        let ts = healthKitManager.timeSeries
        async let cycleFlowSamplesTask = healthKitManager.fetchMenstrualFlowSamples(days: 365)
        // Fetch raw per-sample HR for today. needed for accurate strain zone classification.
        // The stored time series only has daily averages, losing per-minute granularity.
        async let todayRawHRTask = healthKitManager.fetchTodayRawHeartRateSamples()

        // Phase 1: Core analysis. scores, trends, baselines (blocks until done, UI needs these)
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
        await Task.detached(priority: .utility) { [analysisEngine, focusCats] in
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
            // Invalidate score history cache after saving. the new snapshot is now part of the data
            invalidateScoreHistoryCache()
            // Seed historical snapshots from HK history so EWMA on Explore has
            // real per-day scores immediately on a fresh install instead of
            // needing two weeks of app usage. No-op once history is full.
            backfillScoreHistoryIfNeeded()
            updateCachedProperties()
            if !shouldReuseThermalSnapshot {
                computeNewEngines(todayRawHR: todayRawHR)
            }
        }

        // Mark analysis timestamp so subsequent no-change refreshes can skip
        lastAnalysisDate = Date()
        await MainActor.run {
            invalidateDailyActionCache()
            if !shouldReuseThermalSnapshot {
                refreshIntelligenceBriefing()
                refreshHealthForecasts()
                refreshCircadianBiomarkers()
                checkActivationMilestones()
            }
            writeWidgetSnapshots()
            pushTodayScoreLiveActivity()
        }

        // Store current trends for next refresh comparison
        previousTrends = analysisEngine.trends.mapValues { $0.direction }

        if thermalManager.shouldThrottle {
            return
        }

        // Phase 2: Deferred analysis + housekeeping (fire-and-forget background)
        // Insight generators, health risks, notifications, analytics. all non-blocking
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
            // ML pipeline. runs after rule-based analysis completes
            await runMLPhase(timeSeries: ts)

            return
        }

        // Phase 2A: Essential insights. lightweight (~15K ops), runs immediately
        let cycleFlowSamples = await cycleFlowSamplesTask

        // Resolve cycle applicability BEFORE compute so the very first refresh
        // gates correctly. Default `isApplicable` is `true`, so without this
        // hoist a male user (or female with cycle tracking off) would run a
        // full cycle compute on first launch. Mirrors the assignment in
        // computeNewEngines exactly so the two stay in sync.
        let cycleProfile = UserProfileStore.shared.loadLocal()
        let cycleIsFemale = cycleProfile?.gender == .female
        let cyclePref = UserDefaults.standard.object(forKey: AppKeys.Cycle.trackingEnabled) as? Bool
        let cycleEnabled = cyclePref ?? true
        menstrualCycleTracker.isApplicable = cycleIsFemale && cycleEnabled

        // Compute menstrual cycle if applicable
        if menstrualCycleTracker.isApplicable {
            await menstrualCycleTracker.compute(from: healthKitManager)
        }

        deferredEssentialsTask = Task.detached(priority: .utility) { [weak self, analysisEngine] in
            guard let self else { return }
            try? Task.checkCancellation()
            analysisEngine.runDeferredEssentials(
                timeSeries: ts,
                cycleFlowSamples: cycleFlowSamples
            )
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }
            await MainActor.run { self.updateCachedProperties() }
        }

        // Phase 2B: Heavy analysis + housekeeping. delayed for thermal relief
        deferredHeavyTask = Task.detached(priority: .background) { [weak self, prevTrends, analysisEngine] in
            guard let self else { return }
            let logger = Logger(subsystem: "com.healthpulse", category: "Dashboard")

            // Thermal break. let CPU cool after core + essentials
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            guard await MainActor.run(resultType: Bool.self, body: { self.refreshRunToken == refreshToken }) else { return }

            // Gate on thermal state. skip heavy work entirely if device is overheating
            if ThermalManager.shared.shouldThrottle {
                logger.warning("Skipping deferred heavy analysis. thermal state is elevated")
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

            // ML pipeline. runs after rule-based analysis completes
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
        // Store is @MainActor. hop to main actor for SwiftData reads
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

        // Circadian analysis (weekly, hourly data fetch). The remote kill
        // switch is enforced inside MLOrchestrator.runCircadianAnalysis.
        if analysisEngine.mlOrchestrator.needsCircadianAnalysis
            && !ThermalManager.shared.shouldThrottle {
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

        // Re-detect wake-up time weekly so daily notification timing stays current
        _ = await WakeUpTimeDetector.detectAndPersist(healthStore: healthKitManager.healthStore)

        let periodSummary7d = await MainActor.run { self.periodSummary(for: .sevenDays) }
        let currentIntelligence = await MainActor.run { self.intelligenceBriefing }
        // SleepNeedCalculator.currentNeed is populated by runHeavyAnalysis earlier in the
        // refresh cycle. Pull the real target bedtime here; nil is a valid "skip wind-down"
        // signal so WindDownScheduler never fakes a number.
        let recommendedBedtime = await MainActor.run { sleepNeedCalculator.currentNeed?.recommendedBedtime }
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
                improvingDays: computeImprovingDays(),
                periodSummary: periodSummary7d,
                intelligenceBriefing: currentIntelligence,
                recommendedBedtime: recommendedBedtime
            )
        )
    }

    // MARK: - ML Pipeline

    /// Runs the on-device ML analysis pipeline after rule-based analysis completes.
    /// Uses score history from SwiftData and anomaly counts derived from stored snapshots.
    private func runMLPhase(timeSeries: [HealthMetric: MetricTimeSeries]) async {
        // Use cached score history. already fetched earlier in the refresh cycle
        guard !ThermalManager.shared.shouldThrottle else { return }

        let scoreHistory = await MainActor.run { scoreHistoryCached() }

        // Build anomaly counts per day from stored analysis snapshots.
        // Each snapshot records the anomaly count for that day's analysis run.
        var anomalyCounts: [Date: Int] = [:]
        for entry in scoreHistory {
            // Score history entries correspond to daily analysis runs;
            // use today's live anomaly count for the current day, 0 for historical.
            anomalyCounts[entry.date] = 0
        }
        let today = Date.cal.startOfDay(for: Date())
        anomalyCounts[today] = analysisEngine.anomalies.count

        // Use cached focus categories. already loaded by refresh() or updateCachedProperties()
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
        // Cache raw focuses + derived categories (Keychain + AES-GCM decrypt. do once, not per view access)
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
        scores.cachedYesterdayScore = computeYesterdayScore()
        scores.rollingAverageScore = computeRollingAverageScore()
        scores.cachedWeeklyScoreChange = computeWeeklyScoreChange()
        scores.scoreExplanation = analysisEngine.scoreExplanation

        // North-star activation event: fire exactly once per install when the
        // first non-zero score is computed. Gate on a UserDefaults flag so
        // re-launches don't double-fire. Without this, activation rate cannot
        // be measured for ad-driven cohorts.
        let firstScore = analysisEngine.overallScore.score
        if firstScore > 0 && !UserDefaults.standard.bool(forKey: "laso.firstScoreFired") {
            UserDefaults.standard.set(true, forKey: "laso.firstScoreFired")
            let installTs = UserDefaults.standard.double(forKey: AppKeys.Lifecycle.installDate)
            let secondsSinceInstall = installTs > 0 ? Int(Date().timeIntervalSince1970 - installTs) : 0
            AppAnalytics.shared.trackFirstScoreGenerated(
                score: firstScore,
                timeSinceInstallSec: secondsSinceInstall,
                metricsUsed: healthKitManager.timeSeries.count
            )
        }

        // Update weakest category name (used by ScoreGuideSheet)
        cachedWeakestCategoryName = scores.categoryScores
            .compactMap { s -> (String, Int)? in
                guard let cat = s.category else { return nil }
                return (cat.displayName, s.score)
            }
            .min(by: { $0.1 < $1.1 })?
            .0

        // The heavy derived caches (trend metrics ×3, historical highlights, top
        // correlations) only need recomputing when their inputs changed — within a
        // single refresh this method runs 4-5× with identical timeSeries/analysis.
        let expensiveHash = cacheInputFingerprint()
        let expensiveInputsChanged = expensiveHash != lastExpensiveCacheHash
        lastExpensiveCacheHash = expensiveHash

        // Update trend state
        if (expensiveInputsChanged || trends.cachedTrendMetricsByTimeframe.isEmpty),
           !(ThermalManager.shared.shouldThrottle && !trends.cachedTrendMetricsByTimeframe.isEmpty) {
            trends.cachedTrendMetricsByTimeframe = [
                7: computeTrendMetrics(days: 7),
                30: computeTrendMetrics(days: 30),
                90: computeTrendMetrics(days: 90),
            ]
        }

        // Update analysis state
        if (expensiveInputsChanged || analysis.cachedHistoricalHighlights.isEmpty),
           !(ThermalManager.shared.shouldThrottle && !analysis.cachedHistoricalHighlights.isEmpty) {
            analysis.cachedHistoricalHighlights = computeHistoricalHighlights()
        }
        if (expensiveInputsChanged || analysis.cachedTopCorrelations.isEmpty),
           !(ThermalManager.shared.shouldThrottle && !analysis.cachedTopCorrelations.isEmpty) {
            analysis.cachedTopCorrelations = computeTopCorrelations()
        }
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
        analysis.compoundInsights = analysisEngine.mlOrchestrator.compoundInsights
        analysis.interactionEffects = analysisEngine.mlOrchestrator.interactionEffects
        analysis.doseResponseCurves = analysisEngine.mlOrchestrator.doseResponseCurves

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

    /// Fingerprint of the inputs that drive the expensive derived caches. Changes
    /// when timeSeries (per-metric sample count + latest date), correlations, or the
    /// overall score change — i.e. whenever trend metrics / highlights / correlations
    /// would actually differ. Stable across the 4-5 phase calls of one refresh.
    @MainActor
    private func cacheInputFingerprint() -> Int {
        var hasher = Hasher()
        let ts = healthKitManager.timeSeries
        hasher.combine(ts.count)
        for (metric, series) in ts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(metric)
            hasher.combine(series.samples.count)
            hasher.combine(series.samples.last?.date ?? .distantPast)
        }
        hasher.combine(analysisEngine.correlations.count)
        hasher.combine(analysisEngine.overallScore.score)
        return hasher.finalize()
    }

    // MARK: - Age Resolution

    /// Return the user's chronological age from the most authoritative real
    /// source available, in priority order: stored profile, then HealthKit.
    /// Returns `nil` when no real DOB is available so callers can skip
    /// age-dependent computation instead of falling back to a fake number.
    @MainActor
    private func resolveChronologicalAge(profile: UserProfile? = nil) -> Int? {
        let resolvedProfile = profile ?? UserProfileStore.shared.loadLocal()
        if let years = resolvedProfile?.ageFromDateOfBirth, years > 0 {
            return years
        }
        if let dob = try? healthKitManager.healthStore.dateOfBirthComponents(),
           let birthDate = Date.cal.date(from: dob),
           let years = Date.cal.dateComponents([.year], from: birthDate, to: Date()).year,
           years > 0 {
            return years
        }
        return nil
    }

    // MARK: - New Engine Computation

    @MainActor
    private func computeNewEngines(todayRawHR: [MetricSample] = []) {
        let timeSeries = healthKitManager.timeSeries

        // Memoize: skip recomputation if timeSeries hasn't changed within the same calendar day.
        // Scorers produce identical output for identical input, so this saves ~300-500ms per refresh.
        let today = Date.cal.ordinality(of: .day, in: .year, for: Date()) ?? 0
        var inputHasher = Hasher()
        inputHasher.combine(timeSeries.count)
        for (metric, series) in timeSeries {
            inputHasher.combine(metric)
            inputHasher.combine(series.sortedSamples.count)
            if let last = series.sortedSamples.last {
                inputHasher.combine(last.value)
                inputHasher.combine(Int(last.date.timeIntervalSinceReferenceDate))
            }
        }
        inputHasher.combine(todayRawHR.count)
        let inputHash = inputHasher.finalize()
        if inputHash == lastScorerInputHash && today == lastScorerDay {
            return
        }
        lastScorerInputHash = inputHash
        lastScorerDay = today

        let profile = UserProfileStore.shared.loadLocal()
        // Resolve chronological age from real sources only — no hardcoded
        // fallback. Profile DOB first, HealthKit DOB second. Age-dependent
        // engines (Strain, Sleep Need, Vitality) only run when we have a
        // real age; the others run regardless so the rest of the dashboard
        // stays populated even when DOB is missing.
        let resolvedAge = resolveChronologicalAge(profile: profile)
        let sleepSeries = timeSeries[.sleepDuration]

        // Strain. pass raw per-sample HR for accurate zone classification,
        // and in-memory time series for freshest data (avoids SwiftData read lag).
        if let age = resolvedAge {
            strainScorer.compute(
                from: store,
                age: age,
                restingHR: analysisEngine.baselines[.restingHeartRate]?.mean,
                todayHRSamples: todayRawHR,
                timeSeries: timeSeries
            )
        }

        // Strain Coach
        let _ = strainCoach.computeTarget(
            recoveryState: recoveryState,
            currentStrain: strainScorer.currentStrain,
            recentStrainHistory: strainScorer.weeklyStrainHistory,
            daysOfData: analysis.dataDepth.daysOfData
        )

        // Stress
        stressScorer.compute(from: store, timeSeries: timeSeries)

        // Brain Health. pass in-memory timeSeries for guaranteed freshness
        brainHealthScorer.compute(from: store, timeSeries: timeSeries)

        // Sleep debt
        sleepDebtTracker.compute(from: store, sleepSeries: sleepSeries)

        // Sleep need
        let debtHours = sleepDebtTracker.currentDebt?.totalDebtHours ?? 0

        // Use circadian analyzer's optimal sleep window end as wake time if available
        let circadianWakeTime: Date? = {
            let sleepRec = analysisEngine.mlOrchestrator.circadianAnalyzer.recommendations
                .first(where: { $0.activity == .sleep })
            guard let rec = sleepRec, analysisEngine.mlOrchestrator.circadianAnalyzer.isReady else {
                return nil
            }
            let calendar = Date.cal
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            guard let base = tomorrow else { return nil }
            return calendar.date(bySettingHour: rec.optimalWindowEnd, minute: 0, second: 0, of: base)
        }()

        if let age = resolvedAge {
            let need = sleepNeedCalculator.compute(
                from: store,
                currentStrain: strainScorer.currentStrain,
                sleepDebt: debtHours,
                targetWakeTime: circadianWakeTime,
                age: age,
                recoveryScore: Double(scores.overallScore.score),
                sleepSeries: sleepSeries
            )
            _ = need  // stored internally in sleepNeedCalculator
        }

        // Gamification
        let sessionDays = SessionTracker.shared.daysSinceInstall
        let scoreHistory = scoreHistoryCached().map { (date: $0.date, score: $0.score) }
        gamificationEngine.compute(
            from: store,
            sessionDays: sessionDays,
            scores: scoreHistory,
            timeSeries: timeSeries
        )

        // Vitality Age. pass in-memory timeSeries for guaranteed freshness
        if let age = resolvedAge {
            vitalityScorer.compute(from: store, chronologicalAge: age, timeSeries: timeSeries)
        }

        // Menstrual cycle applicability is resolved at the top of refresh()
        // (just before the cycle compute call) so that ordering is correct on
        // the very first refresh. Do not duplicate the assignment here.
    }

    // MARK: - Sleep Tile Snapshot

    /// On-disk snapshot of the most recent sleep tile values. DashboardViewModel
    /// doesn't own LiveViewModel's sleep state, so we cache the values it
    /// provides and replay them on the next launch's first frame instead of
    /// waiting for LiveViewModel to refetch from HealthKit.
    private struct SleepTileSnapshot: Codable {
        var duration: TimeInterval
        var quality: String
        var savedAt: Date
    }

    private static let sleepSnapshotKey = "DashboardViewModel.sleepTile.v1"

    /// Persist the latest live sleep values for use on the next launch's
    /// first frame. Skips zero-duration "no data" inputs so we never restore
    /// an empty placeholder.
    private static func saveSleepSnapshot(duration: TimeInterval, quality: String) {
        guard duration > 0 else { return }
        let snap = SleepTileSnapshot(duration: duration, quality: quality, savedAt: Date())
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: sleepSnapshotKey)
        }
    }

    /// Restore the saved sleep tile values only when they're recent enough to
    /// still represent "last night". 36h covers app launches throughout the
    /// next day without surfacing stale multi-day-old sleep.
    private static func loadFreshSleepSnapshot() -> SleepTileSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: sleepSnapshotKey),
              let snap = try? JSONDecoder().decode(SleepTileSnapshot.self, from: data) else {
            return nil
        }
        if Date().timeIntervalSince(snap.savedAt) > 36 * 3600 { return nil }
        return snap
    }

    // MARK: - Metric Tiles Cache

    /// Rebuild the cached metric tiles array. Call after scorer computation or when live sleep data changes.
    /// Accepts sleep data from LiveViewModel since DashboardViewModel doesn't own it.
    @MainActor
    func rebuildMetricTiles(
        hasSleepData: Bool = false,
        lastNightSleepDuration: TimeInterval = 0,
        sleepQualityLabel: String = ""
    ) {
        var tiles: [MetricTile] = []

        // Vitality
        let vDelta = vitalityScorer.delta
        let vBadge: String
        if vDelta < 0 { vBadge = "\(abs(vDelta))y younger" }
        else if vDelta > 0 { vBadge = "\(vDelta)y older" }
        else { vBadge = "On track" }
        let vColor: Color = vDelta <= 0 ? .green : (vDelta <= 3 ? .orange : .red)
        tiles.append(MetricTile(
            id: "vitality_detail", icon: "figure.run", label: "Vitality",
            value: "\(vitalityScorer.vitalityAge)",
            badge: vBadge, color: vColor, route: .vitalityDetail
        ))

        // Sleep
        // Use the live values when LiveViewModel has them, otherwise fall
        // back to the most recent snapshot so the tile shows on the very
        // first frame after launch instead of waiting for LiveViewModel to
        // finish its async fetch.
        let effectiveSleep: (duration: TimeInterval, quality: String)? = {
            if hasSleepData {
                Self.saveSleepSnapshot(duration: lastNightSleepDuration, quality: sleepQualityLabel)
                return (lastNightSleepDuration, sleepQualityLabel)
            }
            if let snap = Self.loadFreshSleepSnapshot() {
                return (snap.duration, snap.quality)
            }
            return nil
        }()
        if let sleep = effectiveSleep, sleep.duration > 0 {
            let sleepHours = sleep.duration / 3600
            let h = Int(sleepHours)
            let m = Int((sleepHours - Double(h)) * 60)
            let sleepValue = h == 0 ? "\(m)m" : "\(h)h \(String(format: "%02d", m))m"
            let sleepTileColor: Color = sleep.quality == "Great" || sleep.quality == "Good" ? .indigo : .orange
            tiles.append(MetricTile(
                id: "sleep_coach", icon: "moon.fill", label: "Sleep",
                value: sleepValue, badge: sleep.quality, color: sleepTileColor, route: .sleepCoach
            ))
        }

        // Strain
        let strain = strainScorer
        tiles.append(MetricTile(
            id: "strain_detail", icon: "flame.fill", label: "Strain",
            value: String(format: "%.1f", strain.currentStrain),
            badge: strain.strainLevel.displayName, color: strain.strainLevel.color, route: .strainDetail
        ))

        // Brain Health
        if let brain = brainHealthScorer.currentScore {
            let brainColor: Color = brain.score >= 80 ? .green : brain.score >= 65 ? .blue : brain.score >= 45 ? .gray : .orange
            tiles.append(MetricTile(
                id: "brain_health", icon: "brain", label: "Brain",
                value: "\(brain.score)", badge: brain.state.displayName, color: brainColor, route: .brainHealth
            ))
        }

        // Stress
        if let stress = stressScorer.currentStress {
            tiles.append(MetricTile(
                id: "stress_monitor", icon: "waveform.path.ecg", label: "Stress",
                value: String(format: "%.1f", stress.score),
                badge: stress.level.displayName, color: stress.level.color, route: .stressMonitor
            ))
        }

        // Cycle. require isApplicable so a male user (or female with tracking
        // off) never sees a cycle tile even when stray flow samples exist in
        // HealthKit (shared device, family member's data).
        if menstrualCycleTracker.isApplicable, let cycle = menstrualCycleTracker.currentCycle {
            tiles.append(MetricTile(
                id: "cycle_detail", icon: cycle.currentPhase.icon, label: "Cycle",
                value: "Day \(cycle.dayInCycle)",
                badge: cycle.currentPhase.displayName, color: cycle.currentPhase.color, route: .cycleDetail
            ))
        }

        cachedMetricTiles = tiles
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
        let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all.filter { $0.date >= cutoff }
    }

    /// Clears the cached score history so the next access re-fetches from the store.
    @MainActor
    private func invalidateScoreHistoryCache() {
        _cachedScoreHistory = nil
    }

    /// Replays the scorer over the last `WeeklyScoreSmoothing.windowDays`
    /// calendar days using the user's existing HK history and writes one
    /// `StoredAnalysisSnapshot` per missing day. Idempotent: existing rows
    /// are never overwritten and the loop short-circuits once the history
    /// already meets the window length, so this stays cheap on warm launches.
    @MainActor
    private func backfillScoreHistoryIfNeeded() {
        let cal = Date.cal
        let history = scoreHistoryCached()
        if history.count >= WeeklyScoreSmoothing.windowDays { return }

        let today = cal.startOfDay(for: Date())
        let presentDays = Set(history.map { cal.startOfDay(for: $0.date) })
        let timeSeries = healthKitManager.timeSeries
        var inserted = 0

        for offset in 1...WeeklyScoreSmoothing.windowDays {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  !presentDays.contains(day) else { continue }
            guard let result = AnalysisEngine.replay(asOf: day, timeSeries: timeSeries) else { continue }
            store.saveBackfillSnapshot(
                date: day,
                overallScore: result.overallScore,
                categoryScores: result.categoryScores,
                baselines: result.baselines
            )
            inserted += 1
        }

        if inserted > 0 {
            invalidateScoreHistoryCache()
        }
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

    /// Yesterday's own score, so a flat day can be told apart from a day with
    /// no reading behind it. Same window the delta above uses.
    @MainActor
    private func computeYesterdayScore() -> Int? {
        let cal = Date.cal
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return nil }
        // A stored zero means the day was never scored, not that the user scored
        // zero, so it must not become a delta. The rest of the app applies the
        // same `> 0` rule to a persisted score.
        return scoreHistoryCached(days: 3)
            .last { $0.date >= yesterday && $0.date < today }
            .map(\.score)
            .flatMap { $0 > 0 ? $0 : nil }
    }

    /// EWMA-smoothed weekly score for the Explore tab.
    ///
    /// Why EWMA over completed days only: today's overall score is recomputed
    /// live from whatever HealthKit currently has, so including it makes the
    /// "weekly" number swing every time the watch syncs. Both WHOOP Recovery
    /// and Oura Readiness lock per completed day for the same reason; clinical
    /// longitudinal monitoring uses EWMA for the same reason.
    ///
    /// Sources:
    ///   - Luxenberg & Boyd, Exponentially Weighted Moving Models, Stanford
    ///     https://web.stanford.edu/~boyd/papers/pdf/ewmm.pdf
    ///   - PMC10248291, EWMA tutorial for longitudinal psychological data
    ///   - whoop.com/.../how-does-whoop-recovery-work-101
    ///   - livity-app.com/en/blog/readiness-score-explained (Oura)
    @MainActor
    private func computeRollingAverageScore() -> Int {
        let today = Date.cal.startOfDay(for: Date())
        return ewmaWeeklyScore(asOf: today) ?? overallScore.score
    }

    /// EWMA over completed daily snapshots strictly before `asOf`.
    /// Returns nil when no completed-day data is available for the anchor.
    @MainActor
    private func ewmaWeeklyScore(asOf anchor: Date) -> Int? {
        let cal = Date.cal
        var perDay: [Date: Int] = [:]
        for entry in scoreHistoryCached() {
            let day = cal.startOfDay(for: entry.date)
            if day < anchor { perDay[day] = entry.score }
        }
        let recent = perDay
            .sorted { $0.key < $1.key }
            .suffix(WeeklyScoreSmoothing.windowDays)
        guard let first = recent.first else { return nil }
        let lambda = WeeklyScoreSmoothing.lambda
        var ewma = Double(first.value)
        for (_, score) in recent.dropFirst() {
            ewma = lambda * Double(score) + (1.0 - lambda) * ewma
        }
        return Int(ewma.rounded())
    }

    /// EWMA-now minus EWMA-anchored-7-days-ago. Used by the Explore hero
    /// badge so the "± pts this week" label describes the same EWMA series
    /// as the headline number, instead of mixing live daily with smoothed.
    @MainActor
    private func computeWeeklyScoreChange() -> Int? {
        let cal = Date.cal
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: today),
              let current = ewmaWeeklyScore(asOf: today),
              let old = ewmaWeeklyScore(asOf: weekAgo) else { return nil }
        let delta = current - old
        return delta == 0 ? nil : delta
    }

    /// Count consecutive recent days where the score improved day-over-day.
    @MainActor
    private func computeImprovingDays() -> Int {
        let history = scoreHistoryCached(days: 7)
        guard history.count >= 2 else { return 0 }
        var count = 0
        let sorted = history.sorted { $0.date > $1.date }
        for i in 0..<(sorted.count - 1) {
            if sorted[i].score > sorted[i + 1].score {
                count += 1
            } else {
                break
            }
        }
        return count
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
        let calendar = Date.cal
        // Anchor windows at start-of-day so "this week" / "last week" do not
        // slide by seconds and re-shuffle the surfaced highlights between
        // refreshes within the same day.
        let now = calendar.startOfDay(for: Date())
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: now),
              let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: now) else {
            return []
        }

        // Week-over-week comparison for the Home/Coach screen
        for (metric, series) in healthKitManager.timeSeries {
            let thisWeek = series.samples(lastDays: 7)
            let lastWeek = series.samples(from: lastWeekStart, until: thisWeekStart)

            guard !thisWeek.isEmpty, !lastWeek.isEmpty else { continue }

            let thisAvg = thisWeek.mean(of: \.value)
            let lastAvg = lastWeek.mean(of: \.value)
            guard lastAvg != 0 else { continue }

            let change = ((thisAvg - lastAvg) / lastAvg) * 100
            guard abs(change) > 3 else { continue }

            let improving = metric.higherIsBetter ? change > 0 : change < 0
            let direction = change > 0 ? "up" : "down"
            let rec = improving
                ? "Good trend. keep it going this week."
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
    /// Cached per calendar day. stable within a day, refreshed on new day or after analysis re-run.
    @MainActor
    func smartDailyAction(liveVM: LiveViewModel) -> SmartAction {
        let today = Date.cal.startOfDay(for: Date())
        if let cached = _cachedDailyAction,
           let cachedDate = _cachedDailyActionDate,
           Date.cal.isDate(cachedDate, inSameDayAs: today) {
            return cached
        }

        let sortedInsights = insights.focusedInsights
        let recentActionKeys = loadRecentActionKeys()

        // Filter insights: deprioritize ones shown 2+ consecutive days
        let rotatedInsights = rotateInsights(sortedInsights, recentKeys: recentActionKeys)

        let recommendation = smartActionAdvisor.recommend(
            live: DashboardSmartActionAdvisor.LiveSnapshot(
                hour: Date.cal.component(.hour, from: Date()),
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
                userFocuses: insights.cachedHealthFocuses,
                topInsights: rotatedInsights
            )
        )

        let proofSummary = RecommendationEvaluator.buildActionProof(store: store)

        let action = SmartAction(
            icon: recommendation.icon,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            source: recommendation.source,
            rationale: recommendation.rationale,
            supportingInsights: Array(sortedInsights.prefix(2)),
            proofSummary: proofSummary
        )

        _cachedDailyAction = action
        _cachedDailyActionDate = today
        saveActionKey(recommendation.title)
        // Persist it too: `refresh` clears the in-memory cache immediately before
        // writing widget snapshots, so the widget and the watch would otherwise get
        // nothing. Surfaces outside this view model read the stored copy.
        DailyActionStore.save(title: action.title, subtitle: action.subtitle, icon: action.icon)

        return action
    }

    /// Invalidate the cached daily action. called after analysis refresh so new data takes effect.
    @MainActor
    func invalidateDailyActionCache() {
        _cachedDailyAction = nil
        _cachedDailyActionDate = nil
    }

    // MARK: - Intelligence Briefing

    /// Regenerate the intelligence briefing from current ML outputs.
    @MainActor
    func refreshIntelligenceBriefing() {
        guard analysisEngine.mlOrchestrator.hasRunOnce else { return }
        intelligenceBriefing = todayIntelligenceEngine.generateBriefing(
            orchestrator: analysisEngine.mlOrchestrator,
            baselines: analysisEngine.baselines,
            trends: analysisEngine.trends,
            timeSeries: healthKitManager.timeSeries,
            liveHRV: nil,
            liveRestingHR: nil,
            sleepHours: 0,
            deepSleepMinutes: 0,
            exerciseMinutes: 0,
            exerciseGoal: 30,
            readinessScore: nil
        )
    }

    // MARK: - Widget Snapshots

    /// Write current analysis state to App Group UserDefaults for widgets.
    @MainActor
    func writeWidgetSnapshots() {
        let grade = overallScore.grade

        // Prefer today's morning Recovery lock when one exists so the widget
        // matches the Home hero card. Fall back to the overall daily health
        // score only when no morning lock has been set yet today (very early
        // first day, or no overnight wear).
        let readinessStore = ReadinessStore()
        let widgetScore = readinessStore.loadMorningLock(for: Date()) ?? overallScore.score

        let readiness = WidgetReadinessSnapshot(
            score: widgetScore,
            grade: grade,
            dayType: strainCoach.currentTarget?.zone.displayName ?? "Maintain",
            updatedAt: Date()
        )

        // Sleep. pull from latest time series if available
        let sleepSeries = healthKitManager.timeSeries[.sleepDuration]
        let sleepHours = sleepSeries?.latestValue ?? 0
        let sleep = WidgetSleepSnapshot(
            hoursSlept: sleepHours,
            deepMinutes: (healthKitManager.timeSeries[.sleepDeep]?.latestValue ?? 0) * 60,  // series is in hours; field is minutes
            remMinutes: (healthKitManager.timeSeries[.sleepREM]?.latestValue ?? 0) * 60,
            quality: sleepHours >= 7 ? "Good" : sleepHours >= 6 ? "Fair" : "Low",
            updatedAt: Date()
        )

        // Action. from the stored copy, because `refresh` clears the in-memory
        // cache on the line before this method is called.
        let action = DailyActionStore.today().map {
            WidgetActionSnapshot(
                headline: $0.title,
                detail: $0.subtitle,
                icon: $0.icon,
                updatedAt: Date()
            )
        }

        // Intelligence. top card
        let intelligence = intelligenceBriefing.first.map {
            WidgetIntelligenceSnapshot(
                headline: $0.headline,
                severityRaw: $0.severity.rawValue,
                cardType: $0.type.rawValue,
                updatedAt: Date()
            )
        }

        // Recovery debt
        let debtHours = sleepDebtTracker.currentDebt?.totalDebtHours ?? 0
        let recoveryDebt = WidgetRecoveryDebtSnapshot(
            debtHours: debtHours,
            trend: debtHours < 1 ? "stable" : debtHours > 3 ? "worsening" : "improving",
            detail: debtHours < 0.5 ? "Fully recovered" : String(format: "%.1fh deficit", debtHours),
            updatedAt: Date()
        )

        // Watch: send the number the Home hero card shows, not the widget's morning
        // lock. Someone who glances at their wrist and then opens the app has to see
        // the same value. `loadCachedScore` is the live score LiveViewModel mirrors
        // for exactly this cross-surface use.
        PhoneWatchSession.shared.push(
            readinessScore: readinessStore.loadCachedScore() ?? overallScore.score,
            grade: grade,
            dayType: readiness.dayType
        )

        let snapshotsWritten = WidgetDataStore.shared.writeAllSnapshots(
            readiness: readiness,
            sleep: sleep,
            action: action,
            intelligence: intelligence,
            recoveryDebt: recoveryDebt
        )
        guard snapshotsWritten > 0 else { return }

        AppAnalytics.shared.trackWidgetSnapshotUpdated(
            trigger: "analysis_refresh",
            snapshotsWritten: snapshotsWritten,
            hasReadiness: true,
            hasSleep: true,
            hasAction: action != nil,
            hasIntelligence: intelligence != nil,
            hasRecoveryDebt: true
        )
    }

    /// Push the latest Today's Score state to the Live Activity after a successful refresh.
    /// Skips when we have no meaningful data yet (empty time series or score 0) so the
    /// activity doesn't start with a blank slate during the first sync.
    @MainActor
    private func pushTodayScoreLiveActivity() {
        guard !healthKitManager.timeSeries.isEmpty else { return }
        let score = overallScore.score
        guard score > 0 else { return }

        // Weakest pillar: same source used by HomeView via cachedWeakestCategoryName
        // (HomeView.swift:160-162 → viewModel.cachedWeakestCategoryName). Fall back to
        // "Recovery" when no categories have been scored yet.
        let weakestEntry = scores.categoryScores
            .compactMap { s -> (name: String, score: Int)? in
                guard let cat = s.category else { return nil }
                return (cat.displayName, s.score)
            }
            .min(by: { $0.score < $1.score })
        let weakestName = weakestEntry?.name ?? cachedWeakestCategoryName ?? "Recovery"
        let weakestScore = weakestEntry?.score

        // Steps: latest daily sample from HealthKit time series.
        let stepsValue = Int(healthKitManager.timeSeries[.steps]?.latestValue ?? 0)

        // HRV & RHR: read latest daily value from HealthKitManager.timeSeries, same
        // source of truth as AlertEvaluator.swift:156/221 and RecoveryAnalyzer.swift:36.
        let hrvValue: Int? = healthKitManager.timeSeries[.heartRateVariability]?.latestValue
            .map { Int($0.rounded()) }
        let rhrValue: Int? = healthKitManager.timeSeries[.restingHeartRate]?.latestValue
            .map { Int($0.rounded()) }

        TodayScoreLiveActivityManager.shared.updateOrStart(
            overallScore: score,
            weakestPillar: weakestName,
            weakestPillarScore: weakestScore,
            steps: stepsValue,
            stepsGoal: 10000,
            hrvMs: hrvValue,
            restingHR: rhrValue
        )

        // Evaluate wind-down sleep outcome after each refresh. The tracker no-ops
        // unless a pending bedtime is stored AND at least 6 hours have elapsed —
        // so in practice this fires on the morning refresh following a wind-down,
        // correlating the activity with actual sleep onset from HealthKit.
        Task { @MainActor [healthKitManager] in
            await WindDownOutcomeTracker.evaluatePendingOutcome(
                healthKitManager: healthKitManager
            )
        }
    }

    // MARK: - Action Rotation (avoid repeating same action 3+ days)

    private static let recentActionKeysKey = "dailyAction_recentKeys"
    private static let maxConsecutiveRepeat = 2

    private func loadRecentActionKeys() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.recentActionKeysKey) ?? []
    }

    private func saveActionKey(_ key: String) {
        var recent = loadRecentActionKeys()
        recent.append(key)
        // Keep last 7 days worth
        if recent.count > 7 { recent = Array(recent.suffix(7)) }
        UserDefaults.standard.set(recent, forKey: Self.recentActionKeysKey)
    }

    /// Reorder insights so that if the same metric/directive drove the action 2+ consecutive days,
    /// it drops down in priority to let a fresh insight surface.
    private func rotateInsights(_ insights: [Insight], recentKeys: [String]) -> [Insight] {
        guard recentKeys.count >= Self.maxConsecutiveRepeat else { return insights }

        // Check if the last N action keys are the same
        let tail = recentKeys.suffix(Self.maxConsecutiveRepeat)
        guard let repeatedKey = tail.first, tail.allSatisfy({ $0 == repeatedKey }) else {
            return insights
        }

        // Move insights whose title matches the repeated key to the back
        var prioritized: [Insight] = []
        var deprioritized: [Insight] = []
        for insight in insights {
            if insight.title == repeatedKey {
                deprioritized.append(insight)
            } else {
                prioritized.append(insight)
            }
        }
        return prioritized + deprioritized
    }

    struct SmartAction {
        let icon: String
        let title: String
        let subtitle: String
        var source: String = "context_rules"
        var rationale: String = ""
        var supportingInsights: [Insight] = []
        /// Full proof summary for the detail view
        var proofSummary: RecommendationEvaluator.ActionProofSummary?
    }

    /// Snapshot of the three core recovery signals for the Today's Action detail view.
    /// Each field is optional so the view can render whatever the user's data supports.
    struct RecoverySignalsSnapshot {
        let hrvCurrent: Double?
        let hrvBaseline: Double?
        let rhrCurrent: Double?
        let rhrBaseline: Double?
        let sleepHoursLast: Double?
        let sleepHoursGoal: Double

        var hasAny: Bool {
            hrvCurrent != nil || rhrCurrent != nil || sleepHoursLast != nil
        }
    }

    /// One signal row in the score card's "Why" list. The three signals (Sleep,
    /// Heart, Energy) ALWAYS show so the card is never half empty; a signal with
    /// no reading shows `.noData` (never a faked value).
    struct RecoveryWhyReason: Identifiable {
        enum Kind: Hashable, CaseIterable {
            case sleep, heart, restingHR, energy, stress

            /// Plain name, shown when there is no reading to interpret.
            var displayName: String {
                switch self {
                case .sleep:     return Copy.Home.whyNameSleep
                case .heart:     return Copy.Home.whyNameHeart
                case .restingHR: return Copy.Home.whyNameRestingHR
                case .energy:    return Copy.Home.whyNameEnergy
                case .stress:    return Copy.Home.whyNameStress
                }
            }
        }
        enum Tone { case good, okay, concern, noData }
        /// Stable per-signal id so SwiftUI diffs the rows instead of rebuilding
        /// all three on every home refresh (a fresh UUID would churn every time).
        var id: Kind { kind }
        let kind: Kind
        let label: String    // the plain interpretation, e.g. "Sleep was short"
        let value: String    // "5h 40m" / "Good" / "No reading yet"
        let tone: Tone

        /// Placeholder row for a signal that has no reading yet.
        static func noData(kind: Kind) -> RecoveryWhyReason {
            .init(kind: kind, label: kind.displayName, value: Copy.Home.whyNoData, tone: .noData)
        }
    }

    /// The "Why" list. Every signal (sleep, heart/HRV, resting heart rate,
    /// energy, stress) always gets a row, so the card keeps the same shape day
    /// to day and the score card can say how many signals it actually had.
    /// Signals with a reading come first, ranked by how far they are from your
    /// usual (times a small weight for the ones that matter most), each labelled
    /// with the plain interpretation and the real value. Signals with no reading
    /// follow as greyed placeholders instead of being dropped.
    @MainActor
    func recoveryWhyReasons(liveVM: LiveViewModel) -> [RecoveryWhyReason] {
        let s = todayRecoverySignals(liveVM: liveVM)
        var candidates: [(reason: RecoveryWhyReason, relevance: Double)] = []

        // Sleep — vs your goal.
        if let sleep = s.sleepHoursLast {
            let short = sleep < s.sleepHoursGoal - 0.75
            let h = Int(sleep), m = Int((sleep - Double(h)) * 60)
            let dev = abs(sleep - s.sleepHoursGoal) / s.sleepHoursGoal
            candidates.append((.init(kind: .sleep,
                label: short ? Copy.Home.whySleepShort : Copy.Home.whySleepGood,
                value: "\(h)h \(m)m",
                tone: short ? .concern : .good), dev * 1.0))
        }

        // Heart / HRV — vs your baseline. Highest weight.
        if let hrv = s.hrvCurrent, let base = s.hrvBaseline, base > 0 {
            let calm = hrv >= base * 0.95
            let dev = abs(hrv - base) / base
            candidates.append((.init(kind: .heart,
                label: calm ? Copy.Home.whyHeartCalm : Copy.Home.whyHeartWorking,
                value: calm ? Copy.Home.whyHeartGoodValue : Copy.Home.whyHeartHighValue,
                tone: calm ? .good : .concern), dev * 1.2))
        }

        // Resting heart rate — vs your baseline.
        if let rhr = s.rhrCurrent, let base = s.rhrBaseline, base > 0 {
            let up = rhr > base * 1.05
            let dev = abs(rhr - base) / base
            candidates.append((.init(kind: .restingHR,
                label: up ? Copy.Home.whyRhrUp : Copy.Home.whyRhrCalm,
                value: up ? Copy.Home.whyRhrValueUp : Copy.Home.whyRhrValueCalm,
                tone: up ? .concern : .good), dev * 1.1))
        }

        // Energy — the same score the ring shows (readiness, or daily score).
        if let score = liveVM.recovery.readinessScore ?? (overallScore.score > 0 ? overallScore.score : nil) {
            let low = score < 60
            let dev = abs(Double(score) - 70) / 70
            candidates.append((.init(kind: .energy,
                label: low ? Copy.Home.whyEnergyLow : Copy.Home.whyEnergyGood,
                value: low ? Copy.Home.whyEnergyLowValue : Copy.Home.whyEnergyGoodValue,
                tone: low ? .concern : .good), dev * 0.8))
        }

        // Stress — high stress is worth surfacing more than low.
        if let stress = liveVM.recovery.stressLevel {
            let high = stress >= 60
            let dev = abs(Double(stress) - 30) / 70
            candidates.append((.init(kind: .stress,
                label: high ? Copy.Home.whyStressHigh : Copy.Home.whyStressLow,
                value: ReadinessScorer.stressLabel(for: stress),
                tone: high ? .concern : .good), high ? dev * 1.1 : dev * 0.6))
        }

        // Swift's sort is not stable, so ties fall back to the order the signals
        // are appended above. Without it two equally relevant rows swap places
        // on every refresh and the list looks like it is jumping around.
        let withReading = candidates.enumerated()
            .sorted {
                $0.element.relevance == $1.element.relevance
                    ? $0.offset < $1.offset
                    : $0.element.relevance > $1.element.relevance
            }
            .map(\.element.reason)
        let readKinds = Set(withReading.map(\.kind))
        let missing = RecoveryWhyReason.Kind.allCases
            .filter { !readKinds.contains($0) }
            .map { RecoveryWhyReason.noData(kind: $0) }
        return withReading + missing
    }

    /// Plain-English summary under the score as a bold heading + a lighter sub
    /// line, keyed to the 3-band model.
    func readinessSummary(score: Int) -> (head: String, sub: String) {
        if score < 60 { return (Copy.Home.scoreSummaryLowHead, Copy.Home.scoreSummaryLowSub) }
        if score <= 75 { return (Copy.Home.scoreSummaryModerateHead, Copy.Home.scoreSummaryModerateSub) }
        return (Copy.Home.scoreSummaryHighHead, Copy.Home.scoreSummaryHighSub)
    }

    /// Build the recovery signals snapshot from current live values and personal baselines.
    @MainActor
    func todayRecoverySignals(liveVM: LiveViewModel) -> RecoverySignalsSnapshot {
        let sleepHours: Double? = liveVM.sleep.hasSleepData ? liveVM.sleep.lastNightSleepDuration / 3600 : nil
        return RecoverySignalsSnapshot(
            hrvCurrent: liveVM.recovery.latestHRV,
            hrvBaseline: analysisEngine.baselines[.heartRateVariability]?.mean,
            rhrCurrent: liveVM.recovery.latestRestingHeartRate,
            rhrBaseline: analysisEngine.baselines[.restingHeartRate]?.mean,
            sleepHoursLast: sleepHours,
            sleepHoursGoal: 7.5
        )
    }

    // MARK: - Research-Backed Features

    /// Refresh personal health forecasts from MLOrchestrator multi-horizon output (Paper 3)
    @MainActor
    func refreshHealthForecasts() {
        healthForecasts = ForecastBuilder.buildForecasts(
            multiHorizonForecasts: analysisEngine.mlOrchestrator.multiHorizonForecasts,
            timeSeries: healthKitManager.timeSeries
        )
    }

    /// Check and advance activation milestones (Paper 8)
    @MainActor
    func checkActivationMilestones() {
        let orch = analysisEngine.mlOrchestrator
        let newEvents = ActivationSequenceManager.checkMilestones(
            state: &activationState,
            metricsAvailable: healthKitManager.timeSeries.count,
            hasBaselines: !analysisEngine.baselines.isEmpty,
            hasTrends: !analysisEngine.trends.isEmpty,
            hasCorrelations: !orch.mlCorrelations.isEmpty,
            hasAnomalyDetection: orch.anomalyDetector.isReady,
            hasPredictions: orch.tomorrowRiskPrediction != nil
        )

        if let latest = newEvents.last {
            latestMilestoneEvent = latest
            // Map activation sequence milestones to analytics milestones
            switch latest.milestone {
            case .firstCorrelation:
                AppAnalytics.shared.trackActivationMilestone(.firstCorrelation)
            case .firstPrediction:
                AppAnalytics.shared.trackActivationMilestone(.firstPrediction)
            case .fullUnlock:
                AppAnalytics.shared.trackActivationMilestone(.fullCalibration)
            default:
                break // Other milestones tracked via activation state persistence
            }
        }
    }

    /// Compute circadian biomarkers from current time series (Paper 7)
    @MainActor
    func refreshCircadianBiomarkers() {
        let context = AnalysisContext(
            timeSeries: healthKitManager.timeSeries,
            baselines: analysisEngine.baselines,
            trends: analysisEngine.trends,
            anomalies: []
        )
        circadianBiomarkers = CircadianHealthAnalyzer.computeBiomarkers(from: context)
    }

    /// Apply morning check-in to readiness scoring (Paper 10)
    @MainActor
    func applyMorningCheckIn(_ checkIn: MorningCheckIn) {
        MorningCheckInManager.record(checkIn)
        subjectiveReadinessAdjustment = checkIn.readinessAdjustment
    }

    struct HealthDataQueryRequest {
        let engine: any HealthQueryEngine
        let context: HealthDataQueryEngine.QueryContext

        func execute(question: String) async -> HealthDataQueryEngine.QueryResult {
            do {
                return try await engine.query(question: question, context: context)
            } catch {
                return HealthDataQueryEngine.QueryResult(
                    question: question,
                    answer: "Something went wrong processing your question. Try asking again.",
                    dataPoints: [],
                    confidence: 0.0,
                    relatedQuestions: ["How am I doing overall?"]
                )
            }
        }
    }

    // MARK: - Explore Tab Derived Data

    var exploreSortedCategories: [(category: HealthCategory, score: Int?)] {
        let focuses = insights.focusCategories
        return HealthCategory.allCases.map { cat in
            (category: cat, score: analysisEngine.score(for: cat)?.score)
        }
        .sorted { a, b in
            let aHasScore = a.score != nil
            let bHasScore = b.score != nil
            if aHasScore != bHasScore { return aHasScore }
            guard let aScore = a.score, let bScore = b.score else { return false }
            let aFocused = focuses.contains(a.category)
            let bFocused = focuses.contains(b.category)
            if aFocused != bFocused { return aFocused }
            if aScore != bScore { return aScore < bScore }
            // Stable tiebreak so the list order does not flip across refreshes
            // when two categories share the same score.
            return a.category.rawValue < b.category.rawValue
        }
    }

    var exploreWeakestCategory: (category: HealthCategory, score: Int)? {
        let scored = HealthCategory.allCases.compactMap { cat -> (category: HealthCategory, score: Int)? in
            guard let score = analysisEngine.score(for: cat)?.score else { return nil }
            return (category: cat, score: score)
        }
        return scored.min(by: { a, b in
            if a.score != b.score { return a.score < b.score }
            return a.category.rawValue < b.category.rawValue
        })
    }

    func makeHealthDataQueryRequest() -> HealthDataQueryRequest {
        let orch = analysisEngine.mlOrchestrator
        let context = HealthDataQueryEngine.QueryContext(
            timeSeries: healthKitManager.timeSeries,
            baselines: analysisEngine.baselines,
            trends: analysisEngine.trends,
            correlations: orch.mlCorrelations,
            forecasts: orch.multiHorizonForecasts,
            healthSignalReport: orch.healthSignalReport,
            currentHealthState: orch.currentHealthState,
            discoveredPatterns: orch.discoveredPatterns,
            circadianProfile: orch.circadianProfile,
            timingRecommendations: orch.timingRecommendations,
            optimalProfile: orch.optimalProfile,
            idealDay: orch.idealDay,
            scoreSensitivities: orch.scoreSensitivities,
            tomorrowRiskPrediction: orch.tomorrowRiskPrediction,
            compoundInsights: orch.compoundInsights,
            temporalSequences: orch.temporalSequences,
            overallScore: scores.overallScore.score
        )

        let engine: any HealthQueryEngine
        #if canImport(FoundationModels)
        if #available(iOS 26, *), !ThermalManager.shared.shouldThrottle {
            engine = FoundationModelQueryEngine(fallback: orch.healthDataQueryEngine)
        } else {
            engine = orch.healthDataQueryEngine
        }
        #else
        engine = orch.healthDataQueryEngine
        #endif

        return HealthDataQueryRequest(engine: engine, context: context)
    }

    /// Execute a health data query with thermal-aware priority
    nonisolated func executeHealthQuery(_ question: String) async -> HealthDataQueryEngine.QueryResult {
        let request = await makeHealthDataQueryRequest()
        let priority: TaskPriority = ThermalManager.shared.shouldThrottle ? .background : .utility
        return await Task.detached(priority: priority) {
            await request.execute(question: question)
        }.value
    }
}
