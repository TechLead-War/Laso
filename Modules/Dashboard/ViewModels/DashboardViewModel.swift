import Foundation
import Observation
import SwiftUI
import os

/// How much completed score history the backfill makes sure exists, so the
/// readiness trend on Today has two weeks to draw from on a new install.
enum WeeklyScoreSmoothing {
    /// Long enough that one bad day cannot dominate the trend, short enough to
    /// track real adaptations in HRV, sleep and activity.
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
    /// What the user told us is going on. Read on every action rebuild, so
    /// turning a chip on changes today's card immediately.
    let lifeContextStore: LifeContextStore
    /// The running three-week focus. The brief starts, updates and expires it.
    let focusStore: FocusStore
    private let housekeepingService: DashboardHousekeepingService
    private let derivedStateBuilder: DashboardDerivedStateBuilder

    // MARK: - Nested Observable State Groups

    /// UI state: loading, errors, discovery, time period selection
    let ui: UIState
    /// Score-related state: overall score, category scores, score changes, recovery
    let scores = ScoreState()
    /// Insight-related state: focused insights, headline, focus categories
    let insights = InsightState()
    /// Anomaly-related state: anomalous metrics, alert counts
    let anomalies = AnomalyState()
    /// Analysis-related state: data depth, correlations, risks, illness, causal chains
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

    /// Fingerprint of every input `updateCachedProperties` reads. It runs 4-5×
    /// per refresh, and each run republishes ~25 observable properties: most of
    /// the published types (HealthScore, [Insight], [HealthCorrelation]) are not
    /// Equatable, so Observation cannot suppress an identical write and each call
    /// repaints Home (0.34 ms per body pass)
    /// in full. `nil` means "never computed", so
    /// the very first call always publishes.
    @MainActor private var lastCacheHash: Int?

    /// Bumped whenever the stored score history actually changes (a new analysis
    /// snapshot, or backfilled days). The fingerprint carries this counter
    /// instead of the history itself so deciding whether to publish never pays
    /// `loadScoreHistory`'s measured 3.16 ms SwiftData fetch.
    @MainActor private var scoreHistoryGeneration: Int = 0

    /// Cached 365-day score history for the current refresh cycle.
    /// Fetched once on first access via `scoreHistoryCached()`, cleared at
    /// the start of each refresh and after saving a new analysis snapshot.
    @MainActor private var _cachedScoreHistory: [(date: Date, score: Int)]?

    /// Whether cycle tracking applies to this user. Read before the flow query is
    /// launched and reused for the tracker's own gate, so the two cannot drift.
    @MainActor
    static func resolveCycleApplicability() -> Bool {
        let isFemale = UserProfileStore.shared.loadLocal()?.gender == .female
        let enabled = UserDefaults.standard.object(forKey: AppKeys.Cycle.trackingEnabled) as? Bool ?? true
        return isFemale && enabled
    }

    /// Lookback the launch scorer prewarm loads. One year is the longest window
    /// any scorer here looks at: vitality age and strain baselines both cap at
    /// 365 days, so a longer read changes no score it produces.
    private static let prewarmLookbackDays = 365

    /// Memoized baseline-drift insights. See the note at the compute site.
    /// Observation-ignored: pure cache state, and writing it mid-refresh would
    /// invalidate every view observing this model for no visible change.
    @ObservationIgnored @MainActor private var _cachedDriftInsights: [Insight] = []
    @ObservationIgnored @MainActor private var _driftInsightsComputedAt: Date?
    private static let driftInsightsTTL: TimeInterval = 3600

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
        fileprivate(set) var cachedScoreChangeFromYesterday: Int?
        /// Set by parent after each analysis refresh. Nil until an analysis has
        /// actually scored something, so a user with no data (or with HealthKit
        /// denied) is never handed a stand-in number.
        fileprivate(set) var overallScore: HealthScore?
        fileprivate(set) var categoryScores: [HealthScore] = []

        var scoreChangeFromYesterday: Int? { cachedScoreChangeFromYesterday }

        /// Nil until something has been scored. Banding a missing score put
        /// every no-data user in the red recovery tier, which drove a rest-day
        /// strain target the app never actually computed.
        var recoveryState: RecoveryState? {
            overallScore.map { RecoveryState(score: $0.score) }
        }
    }

    @Observable
    final class InsightState {
        /// Raw health focuses from encrypted store. cached to avoid repeated Keychain + AES-GCM decryption.
        fileprivate(set) var cachedHealthFocuses: Set<HealthFocus> = []
        fileprivate(set) var cachedFocusCategories: Set<HealthCategory> = []
        fileprivate(set) var cachedFocusedInsights: [Insight] = []

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

        /// Delegates to `DS.recoveryTier`, the app's only readiness threshold
        /// table. This used to carry its own 75/50 split, which is why a 55
        /// could paint amber here while the explainer sheet called it decent.
        init(score: Int) {
            switch DS.recoveryTier(for: score) {
            case .optimal: self = .green
            case .fair:    self = .yellow
            case .poor:    self = .red
            }
        }
    }

    // MARK: - Convenience accessors (kept for backward compat with internal methods)

    var overallScore: HealthScore? { scores.overallScore }
    var recoveryState: RecoveryState? { scores.recoveryState }

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

        var improvedCount: Int { topImproved.count }
        var declinedCount: Int { topDeclined.count }
    }

    /// Recorded days each side of a period comparison must have before the change
    /// is worth quoting.
    static let minimumPeriodComparisonDays = 3

    func periodSummary(for period: TimePeriod) -> PeriodSummary {
        let days = period.days
        var improved: [MetricChange] = []
        var declined: [MetricChange] = []

        // Previous-period window abuts the current one and reuses the same
        // day-shifted boundary as samples(lastDays:), resolved by O(log n) binary
        // search instead of a per-sample calendar diff over the full history.
        let now = Date()
        let prevEnd = Date.cal.date(byAdding: .day, value: -days, to: now) ?? now
        let prevStart = Date.cal.date(byAdding: .day, value: -days * 2, to: now) ?? now

        for (metric, series) in healthKitManager.timeSeries {
            let currentSamples = series.completedDaySamples(lastDays: days)
            let previousSamples = series.samples(from: prevStart, until: prevEnd)

            // One day against one day is noise, and printing it as a headline
            // percentage was how a fresh install produced "63% better this week".
            guard currentSamples.count >= Self.minimumPeriodComparisonDays,
                  previousSamples.count >= Self.minimumPeriodComparisonDays else { continue }

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
            }
        }

        improved.sort { abs($0.changePercent) > abs($1.changePercent) }
        declined.sort { abs($0.changePercent) > abs($1.changePercent) }

        return PeriodSummary(
            topImproved: improved,
            topDeclined: declined
        )
    }

    // MARK: - New Engines

    let strainScorer = StrainScorer()
    let sleepNeedCalculator = SleepNeedCalculator()
    let sleepDebtTracker = SleepDebtTracker()
    let menstrualCycleTracker = MenstrualCycleTracker()
    let gamificationEngine = GamificationEngine()
    let vitalityScorer = VitalityScorer()
    let strainCoach = StrainCoach()
    let todayIntelligenceEngine = TodayIntelligenceEngine()

    /// Intelligence briefing cards. non-obvious findings from ML algorithms
    @MainActor var intelligenceBriefing: [IntelligenceCard] = []

    // MARK: - Cached View Properties (computed once per refresh, not per render)

    /// Name of the lowest-scoring category. The Today Live Activity names it as the pillar to watch.
    @MainActor var cachedWeakestCategoryName: String?

    // MARK: - Research-Backed Feature State (Papers 1-10)

    /// Activation sequence state (Paper 8: 8-Day Hook Window). The banner that
    /// displayed it is gone; the state still advances so the milestone
    /// analytics funnel other teams read keeps firing.
    @MainActor var activationState: ActivationSequenceManager.ActivationState = ActivationSequenceManager.loadState()

    /// Circadian biomarkers (Paper 7: Chronomedicine)
    @MainActor var circadianBiomarkers: CircadianHealthAnalyzer.CircadianBiomarkers?

    init(
        healthKitManager: HealthKitManager,
        analysisEngine: AnalysisEngine,
        store: HealthDataStore,
        persistence: PersistenceManager = PersistenceManager(),
        appStateStore: AppStateStore = AppStateStore(),
        intentCacheStore: IntentCacheStore = IntentCacheStore(),
        smartActionAdvisor: DashboardSmartActionAdvisor = DashboardSmartActionAdvisor(),
        housekeepingService: DashboardHousekeepingService,
        derivedStateBuilder: DashboardDerivedStateBuilder = DashboardDerivedStateBuilder(),
        lifeContextStore: LifeContextStore = LifeContextStore(),
        focusStore: FocusStore = FocusStore()
    ) {
        self.lifeContextStore = lifeContextStore
        self.focusStore = focusStore
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
        // If a scorer had no on-disk snapshot to restore (fresh install,
        // app update from a build without snapshots, or expired daily Strain
        // snapshot), compute it once synchronously from the persisted
        // SwiftData store so the user sees real values on the very first
        // frame instead of waiting for the async HealthKit refresh to land.
        prewarmScorersFromStoreIfNeeded()
    }

    /// One-shot synchronous warm-up that populates every Intelligence-strip
    /// scorer from persisted SwiftData on launch so the first frame shows
    /// both tiles (Vitality, Strain) together rather
    /// than only the snapshot-restored ones with the rest popping in a
    /// second later. The tiles derive from these scorers, so filling them in
    /// here is all it takes. Skips Vitality/Strain when their snapshots already
    /// restored, and skips them entirely if no real chronological age is
    /// available — we never feed engines a fabricated age.
    ///
    /// Sleep Need and Sleep Debt are warmed here too, age or no age. They back
    /// no tile, but the Sleep Coach screen is reachable from the first frame and
    /// shows its empty state whenever they are nil.
    @MainActor
    private func prewarmScorersFromStoreIfNeeded() {
        let needsVitality = !vitalityScorer.isReady
        let needsStrain = !strainScorer.isReady
        // Sleep Coach gates its whole screen on `currentNeed`, and the Home sleep
        // tile that opens it is rebuilt from an on-disk snapshot. Without this the
        // tile shows real hours while the calculator is still empty, so tapping it
        // before the first HealthKit refresh lands renders "Building your sleep
        // profile" on a user who has years of nights.
        let needsSleepNeed = sleepNeedCalculator.currentNeed == nil

        guard needsVitality || needsStrain || needsSleepNeed else { return }

        // Passed explicitly instead of letting each scorer fall through to
        // `store.loadAllTimeSeries()`. This runs inside `ContentView.init`, before
        // the first frame exists, and the unbounded load grows for the life of the
        // install. Every scorer window here fits inside a year.
        let recent = store.loadRecentTimeSeries(days: Self.prewarmLookbackDays)

        let resolvedAge = resolveChronologicalAge()
        if let age = resolvedAge {
            if needsStrain {
                strainScorer.compute(
                    from: store,
                    age: age,
                    restingHR: nil,
                    todayHRSamples: [],
                    timeSeries: recent
                )
            }
            if needsVitality {
                vitalityScorer.compute(from: store, chronologicalAge: age, timeSeries: recent)
            }
        }
        // Outside the age gate: age only nudges the sleep target by a fraction of
        // an hour, and gating on it hid the whole Sleep Coach screen from anyone
        // whose profile never stored a date of birth.
        if needsSleepNeed {
            let sleepSeries = recent[.sleepDuration]
            // Sleep Coach reads the debt for its 14-day history, so warming
            // the need alone would open the screen with an empty chart.
            sleepDebtTracker.compute(from: store, sleepSeries: sleepSeries)
            _ = sleepNeedCalculator.compute(
                from: store,
                currentStrain: strainScorer.currentStrain,
                sleepDebt: sleepDebtTracker.currentDebt?.totalDebtHours ?? 0,
                targetWakeTime: WakeUpTimeDetector.anchorDate(
                    on: Date.cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                ),
                age: resolvedAge,
                // recoveryScore is deliberately left at its neutral default:
                // no analysis has run at init, and a stand-in low score would
                // inflate the prewarmed need. `computeNewEngines` recomputes
                // with the real score once the first refresh lands.
                sleepSeries: sleepSeries
            )
        }
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
        // Clear any error from a previous attempt: without this a successful retry
        // still renders the error screen, because nothing else ever resets it.
        ui.errorMessage = nil
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
        // Gated here rather than only at the compute below: unconditionally
        // launching a 365-day menstrual query ran it for every user the feature
        // does not apply to.
        let cycleApplicable = Self.resolveCycleApplicability()
        async let cycleFlowSamplesTask: [HealthKitManager.MenstrualFlowSample] = cycleApplicable
            ? await healthKitManager.fetchMenstrualFlowSamples(days: 365)
            : []
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
            // No score means no snapshot row: a stand-in 0 would land in the
            // score history every caller reads and drag every average down.
            if let overallScore = self.overallScore {
                store.saveAnalysisSnapshot(
                    overallScore: overallScore.score,
                    categoryScores: analysisEngine.categoryScores,
                    baselines: analysisEngine.baselines
                )
            }
            // Invalidate score history cache after saving. the new snapshot is now part of the data
            invalidateScoreHistoryCache()
            updateCachedProperties()
            if !shouldReuseThermalSnapshot {
                computeNewEngines(todayRawHR: todayRawHR)
            }
        }

        // Seed historical snapshots from HK history so the readiness trend has
        // real per-day scores immediately on a fresh install instead of
        // needing two weeks of app usage. No-op once history is full.
        // Awaited: the brief reads score history, so it must land first.
        await backfillScoreHistoryIfNeeded()

        // Mark analysis timestamp so subsequent no-change refreshes can skip
        lastAnalysisDate = Date()

        // Circadian biomarkers build from value-type inputs, so only
        // the assignment needs the main actor. Running them inline put a second
        // stall right behind the scorer block and the two read as one freeze.
        // The briefing stays on main: `generateBriefing` takes the orchestrator
        // itself, and handing a live reference type to a detached task would trade
        // a stall for a data race.
        let circadian = shouldReuseThermalSnapshot ? nil : await buildCircadianBiomarkersOffMain()

        await MainActor.run {
            if !shouldReuseThermalSnapshot {
                refreshIntelligenceBriefing()
                if let circadian { circadianBiomarkers = circadian }
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
        let currentScore = overallScore?.score
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
        menstrualCycleTracker.isApplicable = cycleApplicable

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
        currentScore: Int?,
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
        var extraInsights = trajectoryInsights
        // Drift compares today against 30/90/180/365 days ago, and at most one
        // snapshot row is written per day, so recomputing it more than hourly
        // cannot change the answer. It is memoized because the uncached path
        // decodes every stored snapshot's full baseline dictionary on the main
        // actor, and this phase runs on every refresh, not on the heavy TTL.
        let cachedDrift = await MainActor.run { () -> [Insight]? in
            guard let computedAt = _driftInsightsComputedAt,
                  Date().timeIntervalSince(computedAt) < Self.driftInsightsTTL else { return nil }
            return _cachedDriftInsights
        }
        if let cachedDrift {
            extraInsights.append(contentsOf: cachedDrift)
        } else {
            let baselineHistory = await MainActor.run { store.loadAllBaselineHistory(forMetrics: Set(currentBaselines.keys)) }
            let driftInsights = baselineHistory.isEmpty ? [] : BaselineDriftDetector.generateInsights(
                currentBaselines: currentBaselines,
                baselineHistory: baselineHistory,
                correlations: currentCorrelations
            )
            await MainActor.run {
                _cachedDriftInsights = driftInsights
                _driftInsightsComputedAt = Date()
            }
            extraInsights.append(contentsOf: driftInsights)
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

        // Housekeeping writes this number into weekly score history and into the
        // daily push copy, so a day with nothing scored is skipped rather than
        // reported as a zero.
        guard runHousekeeping, let currentScore else { return }

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

        // Every assignment below writes an observable property, and most of the
        // published types are not Equatable, so Observation republishes even when
        // the value is byte-identical: one call repaints Home in full.
        // Refuse the whole call when nothing this function reads has moved — the
        // no-new-data early-out in refreshCore reaches here on every foreground
        // return with nothing to say.
        let fingerprint = cachePublishFingerprint(focuses: focuses)
        guard fingerprint != lastCacheHash else { return }
        lastCacheHash = fingerprint

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
        scores.cachedScoreChangeFromYesterday = computeScoreChangeFromYesterday()

        // North-star activation event: fire exactly once per install when the
        // first non-zero score is computed. Gate on a UserDefaults flag so
        // re-launches don't double-fire. Without this, activation rate cannot
        // be measured for ad-driven cohorts.
        let firstScore = analysisEngine.overallScore?.score ?? 0
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
        let topAreas = analysisEngine.categoryScores
            .sorted { $0.score < $1.score }
            .prefix(2)
            .compactMap { s -> String? in
                guard let cat = s.category else { return nil }
                return "\(cat.shortName) \(s.score)"
            }
        let summaryText = topAreas.isEmpty ? "" : "Areas to watch: \(topAreas.joined(separator: ", "))."
        // Siri answers from this cache verbatim, so it is left untouched until a
        // real score exists rather than being filled with a placeholder.
        if let overallScore {
            intentCacheStore.saveHealthSummary(
                score: overallScore.score,
                grade: overallScore.grade,
                summary: summaryText
            )
        }

        // Save shown recommendations for outcome tracking
        let insightsToSave = insights.cachedFocusedInsights.prefix(10)
        Task { @MainActor [store] in
            for insight in insightsToSave {
                store.saveRecommendation(insight)
            }
        }
    }

    /// Fingerprint of the time series (per-metric sample count + latest date),
    /// correlation count and overall score. Stable across the 4-5 phase calls of
    /// one refresh.
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
        hasher.combine(analysisEngine.overallScore?.score)
        return hasher.finalize()
    }

    /// Fingerprint of every input `updateCachedProperties` publishes from, i.e. a
    /// superset of `cacheInputFingerprint()`.
    ///
    /// The analysis arrays are fingerprinted by element id, not by content. Every
    /// analysis phase (`runDeferredEssentials`, `runDeferredHeavy`, `runMLAnalysis`)
    /// rebuilds its output array from freshly constructed values, so new ids mean
    /// "a phase actually produced something" and unchanged ids mean "that phase's
    /// own gate skipped it and the published values are still current". That is
    /// cheaper than comparing content and it can never read as unchanged when it is.
    @MainActor
    private func cachePublishFingerprint(focuses: Set<HealthFocus>) -> Int {
        var objectIDs: [UUID] = []
        objectIDs.append(contentsOf: analysisEngine.insights.map(\.id))
        objectIDs.append(contentsOf: analysisEngine.correlations.map(\.id))
        objectIDs.append(contentsOf: analysisEngine.healthRisks.map(\.id))
        objectIDs.append(contentsOf: analysisEngine.illnessWarnings.map(\.id))

        // Category scores carry their value, not just their shape: the ring and the
        // weakest-category name change without any array being rebuilt.
        var counts = analysisEngine.categoryScores.map(\.score)
        counts.append(analysisEngine.anomalies.count)
        counts.append(analysisEngine.crossMetricAnomalies.count)
        counts.append(analysisEngine.causalChains.count)
        counts.append(analysisEngine.mlOrchestrator.compoundInsights.count)
        counts.append(analysisEngine.mlOrchestrator.interactionEffects.count)
        counts.append(analysisEngine.mlOrchestrator.doseResponseCurves.count)

        // A context covers a date range, so toggling one rewrites past calendar
        // days without touching a single score. Without this the gate would
        // refuse to republish and the calendar would show stale contexts.
        counts.append(lifeContextStore.revision)
        counts.append(focusStore.revision)

        return Self.cachePublishFingerprint(
            expensiveInputsHash: cacheInputFingerprint(),
            focuses: focuses,
            scoreHistoryGeneration: scoreHistoryGeneration,
            // The yesterday, weekly and EWMA numbers are all anchored to "today",
            // so a session left open across midnight has to republish even though
            // no other input moved.
            today: Date.cal.startOfDay(for: Date()),
            objectIDs: objectIDs,
            counts: counts
        )
    }

    /// Pure core of the publish gate, split out from the instance method so it can
    /// be exercised in tests: building a `DashboardViewModel` needs HealthKit, a
    /// live SwiftData store and the analysis engine.
    nonisolated static func cachePublishFingerprint(
        expensiveInputsHash: Int,
        focuses: Set<HealthFocus>,
        scoreHistoryGeneration: Int,
        today: Date,
        objectIDs: [UUID],
        counts: [Int]
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(expensiveInputsHash)
        hasher.combine(focuses)
        hasher.combine(scoreHistoryGeneration)
        hasher.combine(today)
        hasher.combine(objectIDs)
        hasher.combine(counts)
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

        // Resolved before the memo key, not after: age gates the Strain, Sleep
        // Need and Vitality blocks below. Onboarding calibration runs this pass
        // before the profile is written, so without age in the key that first
        // ageless pass memoizes itself as done and every later pass that day
        // short-circuits — the age-gated engines then never run at all.
        let profile = UserProfileStore.shared.loadLocal()
        let resolvedAge = resolveChronologicalAge(profile: profile)

        var inputHasher = Hasher()
        inputHasher.combine(resolvedAge)
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

        // Age comes from real sources only — no hardcoded fallback. Profile DOB
        // first, HealthKit DOB second. Strain and Vitality only run with a real
        // age; Sleep Need takes it as an optional nudge and the rest ignore it,
        // so the dashboard stays populated even when DOB is missing.
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
        strainCoach.computeTarget(
            recoveryState: recoveryState,
            recentStrainHistory: strainScorer.weeklyStrainHistory
        )

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

        // A wake time the user set outranks the circadian estimate. Without
        // this the wind-down push keeps computing bedtime off a separate wake
        // estimate, and "we move your bedtime, not your mornings" is not true.
        let targetWakeTime = WakeUpTimeDetector.anchorDate(
            on: Date.cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        ) ?? circadianWakeTime

        // Runs with or without a real age: `age` only nudges the target, and
        // skipping it left Sleep Coach on its empty state for anyone missing a
        // date of birth.
        _ = sleepNeedCalculator.compute(
            from: store,
            currentStrain: strainScorer.currentStrain,
            sleepDebt: debtHours,
            targetWakeTime: targetWakeTime,
            age: resolvedAge,
            // No score falls back to the calculator's own neutral value: a 0 here
            // reads as a low-recovery night and inflates the sleep need.
            recoveryScore: scores.overallScore.map { Double($0.score) } ?? SleepNeedConfig.neutralRecoveryScore,
            sleepSeries: sleepSeries
        )

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

    // MARK: - Sleep Bank

    struct SleepBank {
        let debtHours: Double
    }

    /// The running sleep balance, or nil when there is nothing worth showing:
    /// too few recorded nights, or a balance small enough that naming it would
    /// be noise. Home renders no card at all in that case rather than a
    /// reassuring zero.
    var sleepBank: SleepBank? {
        guard sleepDebtTracker.isReady, let debt = sleepDebtTracker.currentDebt else { return nil }
        guard debt.totalDebtHours >= SleepDebtTracker.actionableDebtHours else { return nil }
        return SleepBank(debtHours: debt.totalDebtHours)
    }

    /// Clears the cached score history so the next access re-fetches from the store.
    @MainActor
    private func invalidateScoreHistoryCache() {
        _cachedScoreHistory = nil
        // Both callers have just written a snapshot row, so this is also the only
        // place the stored history changes. The publish gate takes the counter as
        // its "history moved" signal because re-reading the history to compare it
        // would cost the 3.16 ms SwiftData fetch the gate exists to avoid.
        scoreHistoryGeneration &+= 1
    }

    /// Replays the scorer over the last `WeeklyScoreSmoothing.windowDays`
    /// calendar days using the user's existing HK history and writes one
    /// `StoredAnalysisSnapshot` per missing day. Idempotent: existing rows
    /// are never overwritten and the loop short-circuits once the history
    /// already meets the window length, so this stays cheap on warm launches.
    /// Replays run off the main actor because there are up to `windowDays` of them
    /// and each one slices every metric's full series, computes a baseline and runs
    /// an anomaly pass per metric. `AnalysisEngine.replay` is static over value
    /// types, so only the resulting writes need to come back to main.
    @MainActor
    private func backfillScoreHistoryIfNeeded() async {
        let cal = Date.cal
        let history = scoreHistoryCached()
        if history.count >= WeeklyScoreSmoothing.windowDays { return }

        let today = cal.startOfDay(for: Date())
        let presentDays = Set(history.map { cal.startOfDay(for: $0.date) })
        let timeSeries = healthKitManager.timeSeries

        let replayed = await Task.detached(priority: .utility) {
            var out: [(day: Date, overallScore: Int, categoryScores: [HealthScore], baselines: [HealthMetric: UserBaseline])] = []
            for offset in 1...WeeklyScoreSmoothing.windowDays {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                      !presentDays.contains(day) else { continue }
                guard let result = AnalysisEngine.replay(asOf: day, timeSeries: timeSeries) else { continue }
                out.append((day, result.overallScore, result.categoryScores, result.baselines))
            }
            return out
        }.value

        for entry in replayed {
            store.saveBackfillSnapshot(
                date: entry.day,
                overallScore: entry.overallScore,
                categoryScores: entry.categoryScores,
                baselines: entry.baselines
            )
        }

        if !replayed.isEmpty {
            invalidateScoreHistoryCache()
        }
    }

    @MainActor
    private func computeScoreChangeFromYesterday() -> Int? {
        guard let overallScore else { return nil }
        return derivedStateBuilder.scoreChangeFromYesterday(
            currentScore: overallScore.score,
            history: scoreHistoryCached(days: 3)
        )
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

    /// The wins the user has actually earned right now. Empty is a valid answer
    /// and hides every share affordance: each template is gated so a card can
    /// only ever carry a number the user would be glad to post.
    ///
    /// Lives here rather than on Home because the screenshot handler at the root
    /// needs the same list from any tab, and two copies of this composition would
    /// drift apart. `actionResult` is passed in because Home caches it in view
    /// state to keep its shown-event firing once per morning.
    @MainActor
    func shareTemplates(
        liveVM: LiveViewModel,
        actionResult: DailyActionResultStore.Result?
    ) -> [ShareTemplate] {
        let recovery = liveVM.recovery.readinessScore ?? overallScore?.score
        return ShareTemplateBuilder.build(
            vitalityAge: vitalityScorer.isReady ? vitalityScorer.vitalityAge : nil,
            realAge: vitalityScorer.isReady ? vitalityScorer.chronologicalAge : nil,
            recovery: recovery.flatMap { $0 > 0 ? $0 : nil },
            masterStreak: gamificationEngine.streaks.masterStreak,
            actionResult: actionResult,
            lastNightSleepSeconds: liveVM.sleep.lastNightSleepDuration > 0
                ? liveVM.sleep.lastNightSleepDuration : nil,
            allTimeBestSleepHours: analysisEngine.historicalContext[.sleepDuration]?.allTimeHigh,
            mirrorPair: MirrorPhotoStore.shared.progressPair,
            correlation: strongestShareableCorrelation,
            recentBadge: mostRecentlyEarnedBadge
        )
    }

    /// The correlation worth putting on a card: the one with the largest effect
    /// the user's own data supports. Ranked by |r| rather than by sample count,
    /// because the builder already floors the sample size and, past that floor,
    /// a stronger relationship is the more interesting claim.
    @MainActor
    private var strongestShareableCorrelation: HealthCorrelation? {
        analysisEngine.correlations
            .filter { $0.sampleCount >= ShareTemplateGates.minCorrelationDays }
            .max { abs($0.correlation) < abs($1.correlation) }
    }

    /// The newest unlocked achievement. The builder decides whether it is still
    /// recent enough to offer; this only answers which one is newest.
    @MainActor
    private var mostRecentlyEarnedBadge: Achievement? {
        gamificationEngine.achievements
            .filter { $0.isUnlocked && $0.unlockedDate != nil }
            .max { ($0.unlockedDate ?? .distantPast) < ($1.unlockedDate ?? .distantPast) }
    }

    /// The advisor's view of right now.
    @MainActor
    private func advisorLiveSnapshot(liveVM: LiveViewModel) -> DashboardSmartActionAdvisor.LiveSnapshot {
        DashboardSmartActionAdvisor.LiveSnapshot(
            hour: Date.cal.component(.hour, from: Date()),
            stressLevel: liveVM.recovery.stressLevel,
            readinessScore: liveVM.recovery.readinessScore,
            hasSleepData: liveVM.sleep.hasSleepData,
            sleepHours: liveVM.sleep.lastNightSleepDuration / 3600,
            deepSleepMinutes: liveVM.sleep.lastNightDeepSleep / 60,
            exerciseMinutes: liveVM.activity.todayExerciseMinutes,
            exerciseGoal: liveVM.activity.exerciseGoal,
            latestRestingHeartRate: liveVM.recovery.latestRestingHeartRate,
            // Same number the status card renders, fallback and all, so the
            // action cannot argue with the card above it.
            heroRecoveryScore: liveVM.recovery.readinessScore ?? overallScore?.score
        )
    }

    @MainActor
    private func advisorAnalysisSnapshot(topInsights: [Insight]) -> DashboardSmartActionAdvisor.AnalysisSnapshot {
        DashboardSmartActionAdvisor.AnalysisSnapshot(
            policyDecision: analysisEngine.mlOrchestrator.policyDecision,
            restingHeartRateBaselineMean: analysisEngine.baselines[.restingHeartRate]?.mean,
            userFocuses: insights.cachedHealthFocuses,
            topInsights: topInsights,
            restContext: activeRestContext,
            sleepDebtHours: sleepBank?.debtHours ?? 0,
            sleepDebtIsGrowing: sleepDebtTracker.debtTrend == .increasing
        )
    }

    // MARK: - Daily Brief

    /// The Today tab. Written only by `rebuildDailyBrief`, which runs from a
    /// few explicit call sites and skips itself when nothing it reads has moved.
    @MainActor private(set) var dailyBrief: DailyBrief?
    @ObservationIgnored @MainActor private var briefFingerprint: Int?
    /// Reminders armed this session. The notification centre only answers
    /// asynchronously, so the labels read these instead of a pending-request
    /// lookup; a relaunch forgets them and the label falls back to "Remind me".
    @ObservationIgnored @MainActor private var dayReminderFire: Date?
    @ObservationIgnored @MainActor private var nightReminderFire: Date?
    /// Bumped when the verdict is dismissed, so the brief gate sees the change.
    @ObservationIgnored @MainActor private var verdictDismissRevision = 0

    /// Mirrors the builder's learning week: under this many morning locks the
    /// stored analysis scores stand in, since a new install has history in
    /// SwiftData before its first lock.
    private static let minMorningLocks = 7
    /// How far back the verdict looks for the last rest day before yesterday.
    private static let restLookbackDays = 28

    /// Everything the builder needs, read from the engines as they stand now.
    @MainActor
    func briefSnapshot(liveVM: LiveViewModel) -> DailyBriefBuilder.Snapshot {
        let now = Date()
        let series = healthKitManager.timeSeries
        let baselines = analysisEngine.baselines
        let readinessStore = ReadinessStore()
        let readiness = liveVM.recovery.readinessScore
            ?? readinessStore.loadMorningLock(for: now)
            ?? overallScore?.score

        var locks: [(date: Date, score: Int)] = []
        for back in stride(from: DailyBriefConfig.readinessBandDays - 1, through: 0, by: -1) {
            guard let day = Date.cal.date(byAdding: .day, value: -back, to: now),
                  let score = readinessStore.loadMorningLock(for: day) else { continue }
            locks.append((date: Date.cal.startOfDay(for: day), score: score))
        }
        let history = locks.count >= Self.minMorningLocks
            ? locks
            : scoreHistoryCached(days: DailyBriefConfig.readinessBandDays)
        let trajectory = history.count >= Self.minMorningLocks
            ? ScoreTrajectoryAnalyzer.generateInsights(scoreHistory: history).first?.trend
            : nil

        var latest: [HealthMetric: Double] = [:]
        for metric in [HealthMetric.vo2Max, .heartRateVariability, .restingHeartRate, .sleepDuration] {
            latest[metric] = series[metric]?.latestValue
        }
        // Today is still filling up for these, so the last completed day is the reading.
        for metric in [HealthMetric.steps, .activeCalories] {
            latest[metric] = series[metric]?.completedDaySamples(lastDays: 7).last?.value
        }
        // Overnight HRV, resting heart rate and sleep land on the live model
        // before the stored series is rebuilt, so they win when present.
        latest[.heartRateVariability] = liveVM.recovery.latestHRV ?? latest[.heartRateVariability]
        latest[.restingHeartRate] = liveVM.recovery.latestRestingHeartRate ?? latest[.restingHeartRate]
        if liveVM.sleep.hasSleepData { latest[.sleepDuration] = liveVM.sleep.tileDuration / 3600 }
        // The deep-sleep series is stored in hours; the focus KPI reads minutes.
        if liveVM.sleep.lastNightDeepSleep > 0 {
            latest[.sleepDeep] = liveVM.sleep.lastNightDeepSleep / 60
        } else if let hours = series[.sleepDeep]?.latestValue {
            latest[.sleepDeep] = hours * 60
        }

        let hrr: (current: Double, baseline: UserBaseline)? = {
            guard let current = series[.heartRateRecovery]?.completedDaySamples(lastDays: 30).last?.value,
                  let baseline = baselines[.heartRateRecovery] else { return nil }
            return (current, baseline)
        }()

        let workoutDays = series[.workoutDuration].map(RecoveryAnalyzer.workoutDays) ?? []
        let restWeek = Self.restDaysThisWeek(workoutDays: workoutDays, now: now)
        let debt = sleepDebtTracker.currentDebt?.totalDebtHours
        let dismissedDay = UserDefaults.standard.object(forKey: AppKeys.Data.verdictDismissedDay) as? Date
        let verdict = dismissedDay.map { Date.cal.isDate($0, inSameDayAs: now) } == true
            ? nil
            : DailyVerdictBuilder.make(DailyVerdictBuilder.Input(
                yesterday: DailyMoveLog.yesterday(relativeTo: now),
                dayResult: DailyActionResultStore.resultToShow(),
                sleepDebtNow: debt,
                lastNightSeconds: liveVM.sleep.hasSleepData ? liveVM.sleep.tileDuration : nil,
                sleepOnset: WindDownOutcomeTracker.lastOutcome,
                restDaysThisWeekBefore: restWeek?.before,
                restDaysThisWeekAfter: restWeek?.after,
                restDaysSinceLastRest: Self.daysSinceLastRest(workoutDays: workoutDays, now: now)))

        let rotatedInsights = rotateInsights(insights.focusedInsights, recentKeys: loadRecentActionKeys())
        return DailyBriefBuilder.Snapshot(
            now: now,
            readiness: readiness,
            readinessHistory: history,
            trajectory: trajectory,
            anomalies: analysisEngine.anomalies,
            restDeficit: RecoveryAnalyzer.restDeficit(timeSeries: series, baselines: baselines),
            restSummary: RecoveryAnalyzer.restSummary(timeSeries: series, baselines: baselines),
            sleepDebt: sleepDebtTracker.currentDebt,
            sleepDebtTrend: sleepDebtTracker.debtTrend,
            hrr: hrr,
            // Today's strain is still accumulating, so the six completed days
            // before it are the ones judged against the target.
            strainLast6: strainScorer.weeklyStrainHistory.dropLast().suffix(6).map(\.strain),
            strainTarget: strainCoach.currentTarget,
            baselines: baselines,
            latest: latest,
            stressLevel: liveVM.recovery.stressLevel,
            advisor: smartActionAdvisor.recommend(
                live: advisorLiveSnapshot(liveVM: liveVM),
                analysis: advisorAnalysisSnapshot(topInsights: rotatedInsights),
                daytimeOnly: true),
            exerciseMinutes: liveVM.activity.todayExerciseMinutes,
            exerciseGoal: liveVM.activity.exerciseGoal,
            sleepNeed: sleepNeedCalculator.currentNeed,
            restContext: activeRestContext,
            dayDone: DailyMoveLog.isDone(.day) || DailyActionCompletion.isDoneToday,
            nightDone: DailyMoveLog.isDone(.night),
            nightDoneYesterday: DailyMoveLog.yesterday(relativeTo: now)?.nightMove?.doneAt != nil,
            dayReminderFire: dayReminderFire,
            nightReminderFire: nightReminderFire,
            focus: focusStore.active,
            verdict: verdict
        )
    }

    /// Rest days from Monday to yesterday, without and with yesterday's own
    /// count, for the verdict's "1 → 2 this week". Nil with no workout history:
    /// with nothing logged every day reads as rest, which is not worth printing.
    nonisolated static func restDaysThisWeek(workoutDays: Set<Date>, now: Date) -> (before: Int, after: Int)? {
        guard !workoutDays.isEmpty,
              let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date.cal.startOfDay(for: now)) else {
            return nil
        }
        // The reference counts the training week Monday to Sunday whatever the
        // locale's first weekday is.
        var mondayFirst = Date.cal
        mondayFirst.firstWeekday = 2
        guard let weekStart = mondayFirst.dateInterval(of: .weekOfYear, for: yesterday)?.start else { return nil }
        var before = 0
        var day = weekStart
        while day < yesterday {
            if !workoutDays.contains(day) { before += 1 }
            guard let next = Date.cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (before, before + (workoutDays.contains(yesterday) ? 0 : 1))
    }

    /// Days from the last rest day before yesterday up to yesterday, e.g. 9 in
    /// "your first proper rest day in 9". Nil when none sits inside the window.
    nonisolated static func daysSinceLastRest(workoutDays: Set<Date>, now: Date) -> Int? {
        guard !workoutDays.isEmpty,
              let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date.cal.startOfDay(for: now)) else {
            return nil
        }
        for back in 1...restLookbackDays {
            guard let day = Date.cal.date(byAdding: .day, value: -back, to: yesterday) else { return nil }
            if !workoutDays.contains(day) { return back }
        }
        return nil
    }

    /// Pure gate for `rebuildDailyBrief`, split out so a test can prove which
    /// inputs republish the brief without raising a view model.
    nonisolated static func briefFingerprint(
        day: Date,
        cacheHash: Int?,
        focusRevision: Int,
        contextRevision: Int,
        moveLogRevision: Int,
        verdictDismissRevision: Int,
        readiness: Int?,
        sleepSeconds: Int,
        stress: Int?,
        exerciseMinutes: Int,
        hour: Int,
        dayReminderFire: Date?,
        nightReminderFire: Date?
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(day)
        hasher.combine(cacheHash)
        hasher.combine(focusRevision)
        hasher.combine(contextRevision)
        hasher.combine(moveLogRevision)
        hasher.combine(verdictDismissRevision)
        hasher.combine(readiness)
        hasher.combine(sleepSeconds)
        hasher.combine(stress)
        hasher.combine(exerciseMinutes)
        hasher.combine(hour)
        hasher.combine(dayReminderFire)
        hasher.combine(nightReminderFire)
        return hasher.finalize()
    }

    @MainActor
    private func currentBriefFingerprint(liveVM: LiveViewModel) -> Int {
        let now = Date()
        return Self.briefFingerprint(
            day: Date.cal.startOfDay(for: now),
            cacheHash: lastCacheHash,
            focusRevision: focusStore.revision,
            contextRevision: lifeContextStore.revision,
            moveLogRevision: DailyMoveLog.revision,
            verdictDismissRevision: verdictDismissRevision,
            readiness: liveVM.recovery.readinessScore,
            sleepSeconds: Int(liveVM.sleep.tileDuration),
            stress: liveVM.recovery.stressLevel,
            exerciseMinutes: Int(liveVM.activity.todayExerciseMinutes),
            hour: Date.cal.component(.hour, from: now),
            dayReminderFire: dayReminderFire,
            nightReminderFire: nightReminderFire
        )
    }

    /// Rebuilds the Today tab and runs the side effects that belong to a
    /// shown brief: the focus lifecycle, the move log and the widget action.
    /// Skips itself when nothing it reads has moved since the last build.
    @MainActor
    func rebuildDailyBrief(liveVM: LiveViewModel) {
        guard currentBriefFingerprint(liveVM: liveVM) != briefFingerprint else { return }

        var snapshot = briefSnapshot(liveVM: liveVM)
        var brief = DailyBriefBuilder().build(snapshot)
        let now = Date()

        let focusRevisionBefore = focusStore.revision
        let lastClosedBefore = focusStore.past.first?.id
        focusStore.expireIfNeeded(now: now)
        if let active = focusStore.active, let isOff = DailyBriefBuilder.isDriverOff(active.driver, snapshot) {
            focusStore.noteDriver(isOff: isOff, now: now)
        }
        if let closed = focusStore.past.first, closed.id != lastClosedBefore {
            AppAnalytics.shared.trackFocusLifecycle(
                state: "closed", driver: closed.driver.id,
                outcome: closed.outcome?.rawValue,
                days: closed.dayIndex(now: closed.endedAt ?? now))
        }

        let kpiValues = DailyBriefBuilder.kpiValues(snapshot)
        if focusStore.active == nil, let top = brief.drivers.first {
            startFocus(top.kind, kpiValues: kpiValues, now: now)
        } else {
            focusStore.updateLatest(kpiValues, now: now)
        }
        if focusStore.revision != focusRevisionBefore {
            snapshot.focus = focusStore.active
            brief = DailyBriefBuilder().build(snapshot)
        }

        let debt = sleepDebtTracker.currentDebt?.totalDebtHours
        DailyMoveLog.recordShown(
            day: now,
            dayMove: DailyMoveLog.Move(
                title: brief.dayMove.title, icon: brief.dayMove.icon, source: brief.dayMove.source,
                shownAt: now, doneAt: nil, bedtimeTarget: nil, sleepDebtHoursAtShow: debt),
            nightMove: brief.nightMove.map {
                DailyMoveLog.Move(
                    title: $0.title, icon: $0.icon, source: $0.source,
                    shownAt: now, doneAt: nil, bedtimeTarget: $0.bedtime, sleepDebtHoursAtShow: debt)
            })
        // The widget and the watch read the stored copy, so they show the same
        // move as Today.
        DailyActionStore.save(title: brief.dayMove.title, subtitle: brief.dayMove.reason, icon: brief.dayMove.icon)

        dailyBrief = brief
        // Taken after the writes above: the log and the focus store bump their
        // revisions on every write, and the gate must not chase its own tail.
        briefFingerprint = currentBriefFingerprint(liveVM: liveVM)
    }

    /// Starts a focus on `kind` from today's readings. A focus with no number
    /// behind it could never be graded, so a kind with no readable KPI is skipped.
    @MainActor
    private func startFocus(_ kind: DriverKind, kpiValues: [FocusStore.KPIKind: Double], now: Date) {
        let kpis = kind.focusKPIs.compactMap { kpi in
            kpiValues[kpi].map { FocusStore.KPISnapshot(kind: kpi, day1: $0, latest: $0, latestAt: now) }
        }
        guard !kpis.isEmpty else { return }
        focusStore.start(driver: kind, kpis: kpis, now: now)
        AppAnalytics.shared.trackFocusLifecycle(state: "started", driver: kind.id, outcome: nil, days: 0)
    }

    /// The driver detail's "Start a 3-week focus" button.
    @MainActor
    func startFocus(_ kind: DriverKind, liveVM: LiveViewModel) {
        startFocus(kind, kpiValues: DailyBriefBuilder.kpiValues(briefSnapshot(liveVM: liveVM)), now: Date())
        rebuildDailyBrief(liveVM: liveVM)
    }

    @MainActor
    func markMoveDone(_ kind: DailyMoveLog.MoveKind, liveVM: LiveViewModel) {
        switch kind {
        case .day:
            guard let move = dailyBrief?.dayMove else { return }
            // Writes the move log itself, so phone and wrist share one funnel.
            DailyActionCompletion.markDone(actionTitle: move.title, actionIcon: move.icon, source: "today_moves")
        case .night:
            DailyMoveLog.markDone(.night)
            AppAnalytics.shared.trackBlockTap(
                title: dailyBrief?.nightMove?.title ?? "",
                type: .moveDone, screen: .home, metadata: ["move": "night"])
        }
        rebuildDailyBrief(liveVM: liveVM)
    }

    /// Hides this morning's verdict. The result store is cleared too so the
    /// old loop-closer cannot resurface the same day.
    @MainActor
    func dismissVerdict(liveVM: LiveViewModel) {
        DailyActionResultStore.clear()
        UserDefaults.standard.set(Date.cal.startOfDay(for: Date()), forKey: AppKeys.Data.verdictDismissedDay)
        verdictDismissRevision &+= 1
        rebuildDailyBrief(liveVM: liveVM)
    }

    /// Arms the one-shot day reminder. On success the move's label names the
    /// time it fires at.
    @MainActor
    func remindDayMove(liveVM: LiveViewModel) async {
        guard let move = dailyBrief?.dayMove else { return }
        let ok = await ActionReminderScheduler.schedule(action: move.title)
        AppAnalytics.shared.trackBlockTap(
            title: move.title, type: .moveRemind, screen: .home, metadata: ["move": "day", "set": "\(ok)"])
        guard ok else { return }
        dayReminderFire = ActionReminderScheduler.nextFireDate()
        rebuildDailyBrief(liveVM: liveVM)
    }

    /// Re-arms tonight's wind-down push, switching the preference on when the
    /// person had it off: asking to be reminded is the clearest opt-in there is.
    @MainActor
    func remindNightMove(liveVM: LiveViewModel) async {
        guard let move = dailyBrief?.nightMove, let bedtime = move.bedtime else { return }
        var authorized = await NotificationManager.shared.isCurrentlyAuthorized()
        if !authorized {
            authorized = await NotificationManager.shared.requestAuthorization(source: "night_move_reminder")
        }
        let fire = Date.cal.date(byAdding: .minute, value: -WindDownScheduler.leadMinutes, to: bedtime)
        let ok = authorized && fire.map { $0 > Date() } == true
        AppAnalytics.shared.trackBlockTap(
            title: move.title, type: .moveRemind, screen: .home, metadata: ["move": "night", "set": "\(ok)"])
        guard ok else { return }

        var preferences = persistence.loadPreferences()
        if !preferences.windDownEnabled {
            preferences.windDownEnabled = true
            persistence.savePreferences(preferences)
        }
        let hrv = DashboardHousekeepingService.hrvSnapshot(
            timeSeries: healthKitManager.timeSeries, trends: analysisEngine.trends)
        WindDownScheduler.schedule(
            recommendedBedtime: bedtime,
            lastHRV: hrv?.valueMs,
            hrvIsLow: hrv?.isLow ?? false,
            preferences: preferences)
        nightReminderFire = fire
        rebuildDailyBrief(liveVM: liveVM)
    }

    // MARK: - Intelligence Briefing

    /// Regenerate the intelligence briefing from current ML outputs.
    @MainActor
    func refreshIntelligenceBriefing() {
        guard analysisEngine.mlOrchestrator.hasRunOnce else { return }
        let timeSeries = healthKitManager.timeSeries
        // Same-day reading only, matching how the engine resolves every other
        // metric. A stale value from last week is not today's autonomic state,
        // and nil is what the card generators expect when a signal is absent.
        func todaysValue(_ metric: HealthMetric) -> Double? {
            timeSeries[metric]?.samples(lastDays: 1).last?.value
        }
        intelligenceBriefing = todayIntelligenceEngine.generateBriefing(
            orchestrator: analysisEngine.mlOrchestrator,
            baselines: analysisEngine.baselines,
            timeSeries: timeSeries,
            liveHRV: todaysValue(.heartRateVariability),
            liveRestingHR: todaysValue(.restingHeartRate),
            sleepHours: todaysValue(.sleepDuration) ?? 0,
            // The sleep series is stored in hours; this parameter is minutes.
            deepSleepMinutes: (todaysValue(.sleepDeep) ?? 0) * 60,
            exerciseMinutes: todaysValue(.exerciseMinutes) ?? 0,
            exerciseGoal: Self.defaultExerciseGoalMinutes
        )
    }

    /// Apple's out-of-the-box Move-ring exercise target, and the value
    /// `LiveViewModel` starts from before HealthKit reports the wearer's own.
    /// The briefing runs on the analysis path, which has no live activity
    /// summary to read the personalised goal from.
    private static let defaultExerciseGoalMinutes: Double = 30

    // MARK: - Widget Snapshots

    /// Write current analysis state to App Group UserDefaults for widgets.
    @MainActor
    /// The values the wrist needs and cannot measure, gathered from what this refresh
    /// already computed.
    ///
    /// Nothing here is a new model. Each field reuses a number the phone was going to
    /// produce anyway, because a second formula for "how recovered are you" would be a
    /// second answer the two screens could disagree about. Any field the phone cannot
    /// produce yet stays nil, and the matching rung on the wrist skips instead of
    /// guessing.
    private func watchVerdictFacts(readinessScore: Int) -> WatchVerdictFacts {
        let hrv = analysisEngine.baselines[.heartRateVariability]

        return WatchVerdictFacts(
            // The phone's multi-day read, never a single night. `WatchVerdict` gates its
            // `rest` rung on this so the wrist cannot call a rest day off one bad sleep.
            bodyStressElevated: analysisEngine.illnessWarnings.isEmpty ? false : true,
            restingHeartRateBaseline: analysisEngine.baselines[.restingHeartRate]?.mean,
            // The floor of the usual range, not the mean: "suppressed" means under this
            // wearer's normal spread, and a mean would flag half of all healthy nights.
            hrvBaselineFloor: hrv.map { $0.mean - $0.standardDeviation },
            hoursSinceHardDay: hoursSinceHardDay(),
            // Reuses the existing workout programmer rather than inventing a second
            // "how much is wise today" rule.
            //
            // Called with the same two inputs the app's own plan uses — the quantised
            // recovery band and the live cycle phase, see ContentView.swift where
            // TodaysActionDetailView is built. Passing the raw score and no cycle phase
            // produced a different target duration from the one the app displays, so the
            // wrist could offer more room than the phone did.
            exerciseCeilingMinutes: WorkoutProgrammer
                .generatePlan(
                    recoveryBand: WorkoutRecoveryBand(score: readinessScore),
                    cyclePhase: menstrualCycleTracker.currentCycle?.currentPhase.workoutModifier
                )
                .targetDuration,
            bedtimeTarget: sleepNeedCalculator.currentNeed?.recommendedBedtime,
            nightsOfHistory: healthKitManager.timeSeries[.sleepDuration]?.daysOfData
        )
    }

    /// Whole days since the last high-strain day, expressed in hours.
    ///
    /// Day granularity on purpose: the stored strain is one row per day, so quoting an
    /// hour count would imply a precision the source does not have. The wrist turns this
    /// straight back into "2 days after your hard day".
    private func hoursSinceHardDay(now: Date = Date()) -> Double? {
        let hardLevels: Set<String> = [
            StrainLevel.high.rawValue,
            StrainLevel.overreaching.rawValue,
            StrainLevel.allOut.rawValue
        ]
        let today = Date.cal.startOfDay(for: now)

        // Starts at yesterday, not today.
        //
        // Today's strain row is written and rewritten intraday, so a hard session
        // finishing at 18:00 would report 0 hours, and the wrist renders 0 with the same
        // sentence it uses for 24 ("a day after your hard day"). A hard day still in
        // progress is also not something to recover from yet — the recovery it explains
        // has not started.
        //
        // Only as far back as the recovering window reaches. Beyond it a suppressed HRV
        // needs a different explanation, and blaming a workout the body has already
        // finished paying for would be wrong.
        let maxDays = Int(WatchVerdictThresholds.recoveringWindowHours / 24)
        for daysAgo in 1...maxDays {
            guard let day = Date.cal.date(byAdding: .day, value: -daysAgo, to: today),
                  let strain = store.dailyStrain(on: day),
                  hardLevels.contains(strain.level) else { continue }
            return Double(daysAgo) * 24
        }
        return nil
    }

    func writeWidgetSnapshots() {
        // Empty when nothing has been scored yet. The widget and the wrist both
        // render a blank grade, which is honest; a stand-in letter is not.
        let grade = overallScore?.grade ?? ""

        // Prefer today's morning Recovery lock when one exists so the widget
        // matches the Home hero card. Fall back to the overall daily health
        // score only when no morning lock has been set yet today (very early
        // first day, or no overnight wear).
        let readinessStore = ReadinessStore()
        // Stays nil when neither exists. The widget renders its own no-data
        // state for that; a 0 would paint the worst readiness band on a home
        // screen the user cannot tap for context.
        let widgetScore = readinessStore.loadMorningLock(for: Date()) ?? overallScore?.score

        let readiness = WidgetReadinessSnapshot(
            score: widgetScore,
            grade: grade,
            // Empty when the strain coach has no target yet. The widget and the
            // wrist both skip an empty day type, which is honest; a stand-in
            // label reads as a call the app never made.
            dayType: strainCoach.currentTarget?.zone.displayName ?? "",
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

        // The wrist shows the same morning lock the widget and Home do. Skipped
        // entirely without a real score: `watchVerdictFacts` seeds the wrist's
        // exercise ceiling from the score's recovery band, so a 0 would hand the
        // watch a red-day ceiling derived from nothing.
        if let watchScore = widgetScore {
            PhoneWatchSession.shared.push(
                readinessScore: watchScore,
                grade: grade,
                dayType: readiness.dayType,
                facts: watchVerdictFacts(readinessScore: watchScore)
            )
        }

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
            hasReadiness: widgetScore != nil,
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
        guard let score = overallScore?.score, score > 0 else { return }

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
        // RHR carries the evaluator's staleness gate too: the island's night act
        // shows it as tonight's number, so a days-old reading must drop out rather
        // than render as current.
        let hrvValue: Int? = healthKitManager.timeSeries[.heartRateVariability]?.latestValue
            .map { Int($0.rounded()) }
        let rhrSeries = healthKitManager.timeSeries[.restingHeartRate]
        let rhrIsFresh = rhrSeries.map { !$0.isStale(thresholdDays: 1) } ?? false
        let rhrLatestRaw: Double? = rhrIsFresh ? rhrSeries?.latestValue : nil
        let rhrValue: Int? = rhrLatestRaw.map { Int($0.rounded()) }

        // Guardian baseline mirrors AlertEvaluator's spike rule: 7 day mean off
        // the same non-stale series, passed unrounded so the island's threshold
        // math matches the push's exactly.
        let rhrBaselineRaw: Double? = {
            guard rhrIsFresh, let series = rhrSeries else { return nil }
            let avg7d = series.mean(lastDays: 7)
            return avg7d > 0 ? avg7d : nil
        }()
        let debtHours: Double? = sleepDebtTracker.isReady
            ? sleepDebtTracker.currentDebt?.totalDebtHours
            : nil

        TodayScoreLiveActivityManager.shared.updateOrStart(
            overallScore: score,
            weakestPillar: weakestName,
            weakestPillarScore: weakestScore,
            steps: stepsValue,
            stepsGoal: 10000,
            hrvMs: hrvValue,
            restingHR: rhrValue,
            targetBedtime: sleepNeedCalculator.currentNeed?.recommendedBedtime,
            sleepDebtHours: debtHours,
            rhrLatestRaw: rhrLatestRaw,
            rhrBaseline7dRaw: rhrBaselineRaw,
            spikeAlertsEnabled: persistence.loadPreferences().heartRateSpikeAlertsEnabled
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

    /// How many of the last N days actually produced a reading for one signal.
    struct SignalCoverage: Identifiable, Equatable {
        let metric: HealthMetric
        let daysWithData: Int
        let window: Int
        var id: HealthMetric { metric }
        var isMissing: Bool { daysWithData == 0 }
    }

    /// Coverage for the signals the readiness score is built from. Counted off
    /// the same in-memory series the score uses, so the card can never claim
    /// data the score did not have.
    @MainActor
    func signalCoverage(window: Int = 14) -> [SignalCoverage] {
        let signals: [HealthMetric] = [.sleepDuration, .heartRateVariability, .restingHeartRate, .steps, .bloodOxygen]
        let cutoff = Date.cal.date(byAdding: .day, value: -window, to: Date.cal.startOfDay(for: Date())) ?? Date()

        // Home calls this on every body pass, and it was the only reading here that
        // got slower as history grew: 0.238 ms at one year of data, 0.436 ms at
        // three, because it filtered all five metrics' full sample arrays. The
        // binary-searched window and the arithmetic day bucket land on exactly the
        // same days as the old filter plus `startOfDay`, with no upper bound so a
        // sample dated slightly ahead of now still counts as it did before.
        return signals.map { metric in
            let inWindow = healthKitManager.timeSeries[metric]?
                .samples(from: cutoff, until: .distantFuture) ?? []
            let days = Set(inWindow.map { MetricSample.localDayBucket(for: $0.date) }).count
            return SignalCoverage(metric: metric, daysWithData: days, window: window)
        }
    }

    /// The rest context in force today, if any. Nothing expires on a timer here:
    /// only the user turns a context off, and Home nudges them to confirm it is
    /// still true so it cannot sit on unnoticed.
    private var activeRestContext: LifeContextStore.Context? {
        lifeContextStore.active.first { $0.requiresRest }
    }

    /// The gap between today's reading and the person's own usual, in their own
    /// unit. A row that said only "Good" gave nothing to act on; a row that says
    /// "6 bpm above usual" does. Gaps under 3% read as at-usual, since a rounded
    /// "0 bpm above usual" is noise, not a finding.
    static func usualComparison(
        current: Double,
        baseline: Double,
        unit: String
    ) -> String {
        let gap = current - baseline
        guard baseline > 0, abs(gap) / baseline >= 0.03 else {
            return Copy.Home.whyValueAtUsual
        }
        // A gap that rounds away is at usual. On an hours metric the 3% floor
        // above still lets a 0.4 hour gap through, which printed the nonsense
        // "0 hrs below usual".
        let rounded = Int(abs(gap).rounded())
        guard rounded > 0 else { return Copy.Home.whyValueAtUsual }
        let agreeing = (rounded == 1 && unit == HealthMetric.sleepDuration.unit)
            ? Copy.Home.unitHourSingular
            : unit
        return gap > 0
            ? Copy.Home.whyValueAboveUsual(String(rounded), agreeing)
            : Copy.Home.whyValueBelowUsual(String(rounded), agreeing)
    }

    // MARK: - Research-Backed Features

    /// Snapshots the inputs on the main actor, then builds off it. `computeBiomarkers`
    /// is static over an `AnalysisContext` of value types, so nothing shared crosses.
    @MainActor
    private func buildCircadianBiomarkersOffMain() async -> CircadianHealthAnalyzer.CircadianBiomarkers? {
        let context = AnalysisContext(
            timeSeries: healthKitManager.timeSeries,
            baselines: analysisEngine.baselines,
            trends: analysisEngine.trends,
            anomalies: []
        )
        return await Task.detached(priority: .utility) {
            CircadianHealthAnalyzer.computeBiomarkers(from: context)
        }.value
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

        // Every event, not just the last: firstPrediction and fullUnlock land in
        // the same day-7 pass, and `.last` permanently swallowed the earlier one.
        for event in newEvents {
            switch event.milestone {
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

    struct HealthDataQueryRequest {
        let engine: any HealthQueryEngine
        let context: HealthDataQueryEngine.QueryContext

        func execute(question: String) async -> HealthDataQueryEngine.QueryResult {
            do {
                return try await engine.query(question: question, context: context)
            } catch {
                return HealthDataQueryEngine.QueryResult(
                    answer: "Something went wrong processing your question. Try asking again.",
                    dataPoints: [],
                    confidence: 0.0,
                    relatedQuestions: ["How am I doing overall?"]
                )
            }
        }
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
            overallScore: scores.overallScore?.score
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
