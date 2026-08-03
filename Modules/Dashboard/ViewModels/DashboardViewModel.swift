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
    /// What the user told us is going on. Read on every action rebuild, so
    /// turning a chip on changes today's card immediately.
    let lifeContextStore: LifeContextStore
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

    /// Fingerprint of every input `updateCachedProperties` reads. It runs 4-5×
    /// per refresh, and each run republishes ~25 observable properties: most of
    /// the published types (HealthScore, [Insight], [MetricTile],
    /// [HealthCorrelation]) are not Equatable, so Observation cannot suppress an
    /// identical write and each call repaints Home (0.34 ms per body pass) and
    /// Explore (2.13 ms per body pass) in full. `nil` means "never computed", so
    /// the very first call always publishes.
    @MainActor private var lastCacheHash: Int?

    /// Bumped whenever the stored score history actually changes (a new analysis
    /// snapshot, or backfilled days). The fingerprint carries this counter
    /// instead of the history itself so deciding whether to publish never pays
    /// `loadScoreHistory`'s measured 3.16 ms SwiftData fetch.
    @MainActor private var scoreHistoryGeneration: Int = 0

    /// Fingerprint of the inputs behind the heavy derived caches alone (trend
    /// metrics ×3, historical highlights, top correlations). Kept separate from
    /// `lastCacheHash`: a phase that only rewrote insights has to republish, but
    /// must not pay to recompute trends whose inputs it never touched.
    @MainActor private var lastExpensiveCacheHash: Int = 0

    /// Cached daily action. computed once per calendar day (or after analysis refresh)
    /// Observation-ignored: `smartDailyAction` is called from inside HomeView's body,
    /// so writing these as tracked state re-invalidated the body that produced them
    /// and cost a second full pass and layout every time the cache missed.
    @ObservationIgnored @MainActor private var _cachedDailyAction: SmartAction?
    @ObservationIgnored @MainActor private var _cachedDailyActionDate: Date?

    /// Action proof, refreshed on the refresh path rather than on demand.
    /// `RecommendationEvaluator.buildActionProof` runs a predicated SwiftData fetch,
    /// which is the one piece of `smartDailyAction` that must never run in a frame.
    @ObservationIgnored @MainActor private var _cachedActionProof: RecommendationEvaluator.ActionProofSummary?

    /// Cached 365-day score history for the current refresh cycle.
    /// Fetched once on first access via `scoreHistoryCached()`, cleared at
    /// the start of each refresh and after saving a new analysis snapshot.
    @MainActor private var _cachedScoreHistory: [(date: Date, score: Int)]?

    /// Pre-fills every trend row's verdict memo off the main thread. Rows in
    /// Explore's lazy stack first render mid-scroll, and an unwarmed memo put
    /// the baseline maths (~1 ms per row at 90 days) inside a scroll frame.
    /// The maths runs detached over value-type copies; only the memo writes
    /// come back to the main actor.
    @MainActor
    private func warmTrendVerdicts(_ byTimeframe: [Int: [TrendMetricItem]]) {
        let inputs = byTimeframe.values.flatMap { items in
            items.map { (metric: $0.metric, samples: $0.sparklineSamples) }
        }
        guard !inputs.isEmpty else { return }
        let items = byTimeframe.values.flatMap { $0 }
        Task.detached(priority: .utility) {
            let verdicts = inputs.map {
                TrendMetricItem.computeVerdict(metric: $0.metric, samples: $0.samples)
            }
            await MainActor.run {
                for (item, verdict) in zip(items, verdicts) {
                    item.seedVerdict(verdict)
                }
            }
        }
    }

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
        /// EWMA-vs-EWMA-7-days-ago delta. Used by Explore so the weekly badge
        /// describes the same series as the displayed weekly score.
        fileprivate(set) var cachedWeeklyScoreChange: Int?
        /// Set by parent after each analysis refresh
        fileprivate(set) var overallScore: HealthScore = HealthScore(score: 0)
        fileprivate(set) var categoryScores: [HealthScore] = []

        var scoreChangeFromYesterday: Int? { cachedScoreChangeFromYesterday }
        var weeklyScoreChange: Int? { cachedWeeklyScoreChange }

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

        /// One word for the band, so a score can be read without knowing the
        /// thresholds. Used wherever a number appears without its ring.
        var plainName: String {
            switch self {
            case .green: Copy.Home.stateNameGood
            case .yellow: Copy.Home.stateNameSteady
            case .red: Copy.Home.stateNameLow
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

    /// Recorded days each side of a period comparison must have before the change
    /// is worth quoting.
    static let minimumPeriodComparisonDays = 3

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

    /// One score per calendar day for Explore's month calendar, keyed by start
    /// of day. Built at the end of every refresh path rather than from a SwiftUI
    /// body: building it measured 0.60 ms per Explore body pass, and the score
    /// history behind it is a 3.16 ms SwiftData fetch that used to be reached
    /// lazily from inside that body.
    @MainActor private(set) var cachedDailyScoresByDay: [Date: Int] = [:]

    /// Life contexts per calendar day, for the same window as the score map.
    /// A context covers a whole date range, so turning one off rewrites every
    /// past day it covered; the calendar compares this to know that happened.
    @MainActor private(set) var cachedContextsByDay: [Date: [LifeContextStore.Context]] = [:]

    /// Walks the window once and asks the store per day. Days with no context
    /// are left out so the dictionary stays small and comparing it is cheap.
    private static func contextsByDay(
        store: LifeContextStore,
        days: Int
    ) -> [Date: [LifeContextStore.Context]] {
        let today = Date.cal.startOfDay(for: Date())
        var byDay: [Date: [LifeContextStore.Context]] = [:]
        for offset in 0..<days {
            guard let day = Date.cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let contexts = store.contexts(on: day)
            if !contexts.isEmpty { byDay[day] = contexts }
        }
        return byDay
    }

    // MARK: - Research-Backed Feature State (Papers 1-10)

    /// Personal health forecast cards (Paper 3: Conformal Prediction + Digital Twin)
    @MainActor var healthForecasts: [MetricForecast] = []

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
        lifeContextStore: LifeContextStore = LifeContextStore()
    ) {
        self.lifeContextStore = lifeContextStore
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
    ///
    /// Sleep Need and Sleep Debt are warmed here too. They back no tile, but
    /// the Sleep Coach screen is reachable from the first frame and shows its
    /// empty state whenever they are nil.
    @MainActor
    private func prewarmScorersFromStoreIfNeeded() {
        let needsVitality = !vitalityScorer.isReady
        let needsStrain = !strainScorer.isReady
        // Brain + Stress have no on-disk snapshot today and their tiles only
        // appear once `currentScore` / `currentStress` is non-nil, so always
        // run them on launch when missing.
        let needsBrain = brainHealthScorer.currentScore == nil
        let needsStress = stressScorer.currentStress == nil
        // Sleep Coach gates its whole screen on `currentNeed`, and the Home sleep
        // tile that opens it is rebuilt from an on-disk snapshot. Without this the
        // tile shows real hours while the calculator is still empty, so tapping it
        // before the first HealthKit refresh lands renders "Building your sleep
        // profile" on a user who has years of nights.
        let needsSleepNeed = sleepNeedCalculator.currentNeed == nil

        guard needsVitality || needsStrain || needsBrain || needsStress || needsSleepNeed else { return }

        // Passed explicitly instead of letting each scorer fall through to
        // `store.loadAllTimeSeries()`. This runs inside `ContentView.init`, before
        // the first frame exists, and the unbounded load grows for the life of the
        // install. Every scorer window here fits inside a year.
        let recent = store.loadRecentTimeSeries(days: Self.prewarmLookbackDays)

        if needsBrain {
            brainHealthScorer.compute(from: store, timeSeries: recent)
        }
        if needsStress {
            stressScorer.compute(from: store, timeSeries: recent)
        }
        if let age = resolveChronologicalAge() {
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
                    age: age,
                    // recoveryScore is deliberately left at its default: today's
                    // score is still 0 at init and 0 reads as a low-recovery
                    // night, which would inflate the prewarmed need.
                    // `computeNewEngines` recomputes with the real score once
                    // the first refresh lands.
                    sleepSeries: sleepSeries
                )
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
            store.saveAnalysisSnapshot(
                overallScore: overallScore.score,
                categoryScores: analysisEngine.categoryScores,
                baselines: analysisEngine.baselines
            )
            // Invalidate score history cache after saving. the new snapshot is now part of the data
            invalidateScoreHistoryCache()
            updateCachedProperties()
            if !shouldReuseThermalSnapshot {
                computeNewEngines(todayRawHR: todayRawHR)
            }
        }

        // Seed historical snapshots from HK history so EWMA on Explore has
        // real per-day scores immediately on a fresh install instead of
        // needing two weeks of app usage. No-op once history is full.
        // Awaited: Explore's EWMA reads score history, so it must land first.
        await backfillScoreHistoryIfNeeded()

        // Mark analysis timestamp so subsequent no-change refreshes can skip
        lastAnalysisDate = Date()

        // Forecasts and circadian biomarkers build from value-type inputs, so only
        // the assignment needs the main actor. Running them inline put a second
        // stall right behind the scorer block and the two read as one freeze.
        // The briefing stays on main: `generateBriefing` takes the orchestrator
        // itself, and handing a live reference type to a detached task would trade
        // a stall for a data race.
        let forecasts = shouldReuseThermalSnapshot ? nil : await buildHealthForecastsOffMain()
        let circadian = shouldReuseThermalSnapshot ? nil : await buildCircadianBiomarkersOffMain()

        await MainActor.run {
            invalidateDailyActionCache()
            if !shouldReuseThermalSnapshot {
                refreshIntelligenceBriefing()
                if let forecasts { healthForecasts = forecasts }
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
        // the value is byte-identical: one call repaints Home and Explore in full.
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
        scores.rollingAverageScore = computeRollingAverageScore()
        scores.cachedWeeklyScoreChange = computeWeeklyScoreChange()
        scores.scoreExplanation = analysisEngine.scoreExplanation

        // Built here rather than from Explore's body. Explore rebuilt it on every
        // body pass (0.60 ms each, 9 passes per refresh burst) and reached the
        // 3.16 ms `loadScoreHistory` SwiftData fetch lazily from inside that body.
        // The lines above have already paid that fetch, so the map is close to free
        // at this point.
        cachedDailyScoresByDay = dailyScoresByDay(days: Self.scoreCalendarDays)

        // Contexts as a value, not a closure. The calendar used to call into the
        // store once per visible cell on every render; as a plain dictionary it
        // is built once per publish and lets the calendar compare its whole
        // input and skip redrawing when nothing moved.
        cachedContextsByDay = Self.contextsByDay(
            store: lifeContextStore,
            days: Self.scoreCalendarDays
        )

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
            warmTrendVerdicts(trends.cachedTrendMetricsByTimeframe)
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
        // first, HealthKit DOB second. Age-dependent engines (Strain, Sleep Need,
        // Vitality) only run when we have a real age; the others run regardless
        // so the rest of the dashboard stays populated even when DOB is missing.
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

        // A wake time the user set outranks the circadian estimate. Without
        // this the wind-down push keeps computing bedtime off a separate wake
        // estimate, and "we move your bedtime, not your mornings" is not true.
        let targetWakeTime = WakeUpTimeDetector.anchorDate(
            on: Date.cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        ) ?? circadianWakeTime

        if let age = resolvedAge {
            let need = sleepNeedCalculator.compute(
                from: store,
                currentStrain: strainScorer.currentStrain,
                sleepDebt: debtHours,
                targetWakeTime: targetWakeTime,
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

    /// The values last actually written to disk. Observation-ignored: pure write
    /// bookkeeping, and publishing it would repaint Home for no visible change.
    @ObservationIgnored @MainActor
    private var _lastWrittenSleepSnapshot: (duration: TimeInterval, quality: String, writtenAt: Date)?

    /// How long an unchanged snapshot may sit without being rewritten.
    /// `loadFreshSleepSnapshot` expires a snapshot at 36h, so refreshing `savedAt`
    /// hourly keeps skipped writes from ever flipping that freshness decision.
    private static let sleepSnapshotRefreshInterval: TimeInterval = 3600

    /// Persist the latest live sleep values for use on the next launch's
    /// first frame. Skips zero-duration "no data" inputs so we never restore
    /// an empty placeholder.
    ///
    /// Writes only on a real change: `rebuildMetricTiles` runs on every Home appear
    /// and every live-sleep update, and this JSON encode plus UserDefaults write was
    /// 97% of that function's measured 0.156 ms, each time re-writing a snapshot
    /// identical to the one already on disk.
    @MainActor
    private func saveSleepSnapshot(duration: TimeInterval, quality: String) {
        guard duration > 0 else { return }
        let now = Date()
        if let last = _lastWrittenSleepSnapshot,
           last.duration == duration,
           last.quality == quality,
           now.timeIntervalSince(last.writtenAt) < Self.sleepSnapshotRefreshInterval {
            return
        }
        let snap = SleepTileSnapshot(duration: duration, quality: quality, savedAt: now)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: Self.sleepSnapshotKey)
        _lastWrittenSleepSnapshot = (duration, quality, now)
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

        // Vitality. Gated on the scorer being ready: unguarded, a brand new
        // user's first impression was a body age of 0.
        if vitalityScorer.isReady {
        let vDelta = vitalityScorer.delta
        let vBadge: String
        if vDelta < 0 { vBadge = "\(abs(vDelta))y younger" }
        else if vDelta > 0 { vBadge = "\(vDelta)y older" }
        else { vBadge = "On track" }
        let vColor: Color = vDelta <= 0 ? AppColour.vitalityWhoopGreen : (vDelta <= 3 ? AppColour.vitalityPaceYellow : AppColour.vitalityPaceRed)
        tiles.append(MetricTile(
            id: "vitality_detail", icon: "figure.run", label: "Vitality",
            value: "\(vitalityScorer.vitalityAge) \(Copy.Vitality.yrs)",
            badge: vBadge, color: vColor, route: .vitalityDetail
        ))
        }

        // Sleep
        // Use the live values when LiveViewModel has them, otherwise fall
        // back to the most recent snapshot so the tile shows on the very
        // first frame after launch instead of waiting for LiveViewModel to
        // finish its async fetch.
        if hasSleepData {
            saveSleepSnapshot(duration: lastNightSleepDuration, quality: sleepQualityLabel)
        }
        let effectiveSleep: (duration: TimeInterval, quality: String)? = {
            if hasSleepData {
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
            let sleepTileColor: Color = sleep.quality == "Great" || sleep.quality == "Good" ? AppColour.categorySleep : AppColour.warning
            tiles.append(MetricTile(
                id: "sleep_coach", icon: "moon.fill", label: "Sleep",
                value: sleepValue, badge: sleep.quality, color: sleepTileColor, route: .sleepCoach
            ))
        }

        // Strain. A flat 0.0 means nothing was recorded, not an easy day, so the
        // tile stays away rather than reporting a reading the app does not have.
        let strain = strainScorer
        if strain.currentStrain > 0 {
            tiles.append(MetricTile(
                id: "strain_detail", icon: "flame.fill", label: "Strain",
                value: String(format: "%.1f", strain.currentStrain),
                badge: strain.strainLevel.displayName, color: strain.strainLevel.color, route: .strainDetail
            ))
        }

        // Brain Health
        if let brain = brainHealthScorer.currentScore {
            let brainColor: Color = brain.score >= 80 ? AppColour.scoreOptimal : brain.score >= 65 ? AppColour.info : brain.score >= 45 ? AppColour.stateDefault : AppColour.warning
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

    /// A full year plus the current day, so paging one month back in Explore's
    /// calendar never lands on a grid that was cut off at the window edge.
    private static let scoreCalendarDays = 366

    /// One score per calendar day for the month calendar, keyed by start of day.
    /// A day with two snapshots keeps the later one, which is the day's settled
    /// score rather than a partial morning read.
    ///
    /// Builds `cachedDailyScoresByDay` once per publish; views read that property
    /// rather than calling this from a body.
    @MainActor
    func dailyScoresByDay(days: Int) -> [Date: Int] {
        var byDay: [Date: Int] = [:]
        for entry in scoreHistoryCached(days: days) where entry.score > 0 {
            byDay[Date.cal.startOfDay(for: entry.date)] = entry.score
        }
        return byDay
    }

    // MARK: - Sleep Bank

    struct SleepBank {
        let debtHours: Double
        let personalBaseline: Double
        let deficits: [SleepDebtTracker.DailyDeficit]
        /// How many of the 14 nights actually recorded sleep. The card says so
        /// when the window is thin, rather than presenting a partial balance as
        /// a complete one.
        let nightsRecorded: Int
    }

    /// The running sleep balance, or nil when there is nothing worth showing:
    /// too few recorded nights, or a balance small enough that naming it would
    /// be noise. Home renders no card at all in that case rather than a
    /// reassuring zero.
    var sleepBank: SleepBank? {
        guard sleepDebtTracker.isReady, let debt = sleepDebtTracker.currentDebt else { return nil }
        guard debt.totalDebtHours >= SleepDebtTracker.actionableDebtHours else { return nil }
        return SleepBank(debtHours: debt.totalDebtHours,
                         personalBaseline: debt.personalBaseline,
                         deficits: debt.dailyDeficits,
                         nightsRecorded: debt.nightsRecorded)
    }

    // MARK: - One Day, Explained

    /// One signal as it read on a past day, next to the baseline the scorer was
    /// using then.
    struct DaySignal: Identifiable {
        /// Which side of the person's own usual the reading landed on. Nil when
        /// the day stored no baseline, and for strain, which has none in this
        /// model, so the card can stay silent rather than imply a comparison it
        /// cannot make.
        enum Usual { case above, atUsual, below }

        let title: String
        let valueText: String
        /// The row's second line, always present: the person's own usual as a
        /// real number, or why there is not one, or the strain level word. One
        /// slot for all three so a missing baseline cannot produce a
        /// differently shaped row.
        let subText: String
        /// "12 ms below your usual", or "At your usual". No longer drawn: the
        /// number opposite it says this now. Kept because it is what VoiceOver
        /// reads, so the spoken direction comes from the same place the arrow does.
        let gapText: String
        let usual: Usual?

        var id: String { title }
    }

    /// Everything the app can honestly say about one past day. Every field is
    /// read back from what was stored on that day; nothing is recomputed
    /// against today's baselines and nothing is filled in when missing.
    struct DayDetail {
        let date: Date
        let score: Int?
        let contexts: [LifeContextStore.Context]
        let signals: [DaySignal]
        /// Signals the day sheet would have shown if the day had recorded them.
        let missing: [HealthMetric]

        var state: RecoveryState? { score.map { RecoveryState(score: $0) } }
    }

    /// The signals a day is judged on, in the order the sheet lists them.
    private static let daySignalMetrics: [HealthMetric] = [
        .heartRateVariability, .restingHeartRate, .sleepDuration
    ]

    @MainActor
    func dayDetail(for day: Date) -> DayDetail {
        let dayStart = Date.cal.startOfDay(for: day)
        let snapshot = store.analysisSnapshot(on: dayStart)

        var signals: [DaySignal] = []
        var missing: [HealthMetric] = []

        for metric in Self.daySignalMetrics {
            // Values are stored in the unit `HealthMetric.unit` advertises, sleep
            // included, so nothing is converted on the way out.
            guard let value = dayValue(of: metric, on: dayStart) else {
                missing.append(metric)
                continue
            }
            let baseline = snapshot?.baselines[metric]?.mean
            let comparison = baseline.map {
                Self.usualComparison(current: value, baseline: $0, unit: metric.unit)
            }
            signals.append(DaySignal(
                title: metric.displayName,
                valueText: Self.dayValueText(value, of: metric),
                // Same formatter as the reading, so "48 ms" sits opposite
                // "usual 44 ms" and "6h 23m" opposite "usual 7h 30m".
                subText: baseline.map { Copy.Explore.dayUsualValue(Self.dayValueText($0, of: metric)) }
                    ?? Copy.Explore.dayNoBaseline,
                gapText: comparison?.text ?? Copy.Explore.dayNoBaseline,
                usual: comparison?.usual
            ))
        }

        if let strain = store.dailyStrain(on: dayStart) {
            signals.append(DaySignal(
                title: Copy.Explore.dayStrainTitle,
                valueText: String(format: "%.1f", strain.strain),
                // The store hands back the raw case name it persisted, so this
                // printed "allOut" on a hard day. Rebuild the level from the
                // number, the way ContentView and StrainDetailView already do.
                // The store keeps returning the raw string on purpose: the
                // illness check below matches it against raw case names.
                subText: StrainLevel(strain: strain.strain).displayName,
                gapText: Copy.Explore.dayStrainCaption,
                usual: nil
            ))
        }

        return DayDetail(date: dayStart,
                         score: snapshot?.score,
                         contexts: lifeContextStore.contexts(on: dayStart),
                         signals: signals,
                         missing: missing)
    }

    /// That day's reading for one metric, aggregated the way the metric is
    /// meant to be: sleep and steps accumulate across the day, a heart reading
    /// averages. Nil when the day recorded nothing, which the sheet says out
    /// loud rather than drawing a zero.
    @MainActor
    private func dayValue(of metric: HealthMetric, on dayStart: Date) -> Double? {
        guard let dayEnd = Date.cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let samples = (healthKitManager.timeSeries[metric]?.samples ?? [])
            .filter { $0.date >= dayStart && $0.date < dayEnd }
        guard !samples.isEmpty else { return nil }

        let total = samples.reduce(0.0) { $0 + $1.value }
        let value: Double
        switch metric {
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .steps,
             .activeCalories, .exerciseMinutes, .standHours:
            value = total
        default:
            value = total / Double(samples.count)
        }
        // A stored zero means the watch recorded nothing that day, not that the
        // person slept for zero hours. Printing "0h 0m" reads as a finding.
        return value > 0 ? value : nil
    }

    private static func dayValueText(_ value: Double, of metric: HealthMetric) -> String {
        switch metric {
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60)
            return Copy.Explore.dayHoursMinutes(hours, minutes)
        default:
            return Copy.Explore.dayValue(String(Int(value.rounded())), metric.unit)
        }
    }

    /// The reading placed on a bar that runs from half to one and a half times
    /// the person's own usual, so the bar answers "how far off was this" rather
    /// than pretending the metric has an absolute scale.

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
        derivedStateBuilder.scoreChangeFromYesterday(
            currentScore: overallScore.score,
            history: scoreHistoryCached(days: 3)
        )
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
        let recovery = liveVM.recovery.readinessScore ?? overallScore.score
        return ShareTemplateBuilder.build(
            vitalityAge: vitalityScorer.isReady ? vitalityScorer.vitalityAge : nil,
            realAge: vitalityScorer.isReady ? vitalityScorer.chronologicalAge : nil,
            recovery: recovery > 0 ? recovery : nil,
            masterStreak: gamificationEngine.streaks.masterStreak,
            actionResult: actionResult,
            lastNightSleepSeconds: liveVM.sleep.lastNightSleepDuration > 0
                ? liveVM.sleep.lastNightSleepDuration : nil,
            allTimeBestSleepHours: analysisEngine.historicalContext[.sleepDuration]?.allTimeHigh,
            mirrorPair: MirrorPhotoStore.shared.progressPair
        )
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
                topInsights: rotatedInsights,
                restContext: activeRestContext,
                sleepDebtHours: sleepBank?.debtHours ?? 0,
                sleepDebtIsGrowing: sleepDebtTracker.debtTrend == .increasing
            )
        )

        // Refreshed on the refresh path. Falling back to a live build only covers
        // the case where the card is read before the first refresh has landed.
        let proofSummary = _cachedActionProof ?? RecommendationEvaluator.buildActionProof(store: store)

        let action = SmartAction(
            icon: recommendation.icon,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            source: recommendation.source,
            rationale: recommendation.rationale,
            supportingInsights: Array(sortedInsights.prefix(2)),
            proofSummary: proofSummary,
            expectedBenefit: recommendation.expectedBenefit,
            // The advisor labels rungs 3-8 alike as "context_rules", so its
            // rung-8 hardcoded default is only identifiable by its fixed
            // headline; both sides resolve through the same Copy accessor.
            isFallback: recommendation.source == "context_rules"
                && recommendation.title == Copy.Home.SmartAction.defaultTitle
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
        // Rebuilt here, on the refresh path, so the next body pass that misses the
        // action cache does not have to reach SwiftData to fill in the proof.
        _cachedActionProof = RecommendationEvaluator.buildActionProof(store: store)
    }

    // MARK: - Intelligence Briefing

    /// Regenerate the intelligence briefing from current ML outputs.
    @MainActor
    func refreshIntelligenceBriefing() {
        guard analysisEngine.mlOrchestrator.hasRunOnce else { return }
        intelligenceBriefing = todayIntelligenceEngine.generateBriefing(
            orchestrator: analysisEngine.mlOrchestrator,
            baselines: analysisEngine.baselines,
            timeSeries: healthKitManager.timeSeries,
            liveHRV: nil,
            liveRestingHR: nil,
            sleepHours: 0,
            deepSleepMinutes: 0,
            exerciseMinutes: 0,
            exerciseGoal: 30
        )
    }

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

        // Watch: send the number the Home hero card shows, not the widget's morning
        // lock. Someone who glances at their wrist and then opens the app has to see
        // the same value. `loadCachedScore` is the live score LiveViewModel mirrors
        // for exactly this cross-surface use.
        let watchScore = readinessStore.loadCachedScore() ?? overallScore.score
        PhoneWatchSession.shared.push(
            readinessScore: watchScore,
            grade: grade,
            dayType: readiness.dayType,
            facts: watchVerdictFacts(readinessScore: watchScore)
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
        /// What doing this is forecast to change. Empty for rule-based actions.
        var expectedBenefit: String = ""
        /// True when the advisor fell through every rung to the hardcoded
        /// default, so the card can say so instead of dressing standard advice
        /// as personal (KEEP-KILL fix row).
        var isFallback: Bool = false
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
                value: Self.gapToUsual(current: hrv, baseline: base, unit: HealthMetric.heartRateVariability.unit),
                tone: calm ? .good : .concern), dev * 1.2))
        }

        // Resting heart rate — vs your baseline.
        if let rhr = s.rhrCurrent, let base = s.rhrBaseline, base > 0 {
            let up = rhr > base * 1.05
            let dev = abs(rhr - base) / base
            candidates.append((.init(kind: .restingHR,
                label: up ? Copy.Home.whyRhrUp : Copy.Home.whyRhrCalm,
                value: Self.gapToUsual(current: rhr, baseline: base, unit: HealthMetric.restingHeartRate.unit),
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

        // Out-of-range signals lead outright: the hero card blindly shows the
        // first three rows, and a big deviation on a signal that reads fine
        // (e.g. HRV well above baseline) must not push a concern off the card.
        // Swift's sort is not stable, so ties fall back to the order the signals
        // are appended above. Without it two equally relevant rows swap places
        // on every refresh and the list looks like it is jumping around.
        let withReading = candidates.enumerated()
            .sorted {
                let lhsConcern = $0.element.reason.tone == .concern
                let rhsConcern = $1.element.reason.tone == .concern
                if lhsConcern != rhsConcern { return lhsConcern }
                return $0.element.relevance == $1.element.relevance
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

    /// The signals the readiness score is actually built from (`ReadinessScorer`
    /// inputs: HRV, resting HR, sleep). Steps and blood oxygen are read for
    /// coverage but feed no scorer input, so they must never appear in the
    /// hero's honesty line (KEEP-KILL merge list).
    private static let scoreFedSignals: [HealthMetric] = [
        .sleepDuration, .heartRateVariability, .restingHeartRate
    ]

    /// Display names of score-fed signals with no reading in the coverage
    /// window, for the hero card's one tappable coverage line.
    @MainActor
    func scoreFedMissingSignalNames() -> [String] {
        signalCoverage()
            .filter { $0.isMissing && Self.scoreFedSignals.contains($0.metric) }
            .map(\.metric.displayName)
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
    /// The sentence and the direction it describes, from one body. Both the 3%
    /// deadband and the rounds-to-zero guard live here, so an arrow can never
    /// point up on a row whose sentence reads "At your usual" — a sleep gap of
    /// 0.4h clears the 3% floor and then rounds away, and a separately computed
    /// direction would disagree exactly there.
    static func usualComparison(
        current: Double,
        baseline: Double,
        unit: String
    ) -> (text: String, usual: DaySignal.Usual) {
        let gap = current - baseline
        guard baseline > 0, abs(gap) / baseline >= 0.03 else {
            return (Copy.Home.whyValueAtUsual, .atUsual)
        }
        // A gap that rounds away is at usual. On an hours metric the 3% floor
        // above still lets a 0.4 hour gap through, which printed the nonsense
        // "0 hrs below usual".
        let rounded = Int(abs(gap).rounded())
        guard rounded > 0 else { return (Copy.Home.whyValueAtUsual, .atUsual) }
        let agreeing = (rounded == 1 && unit == HealthMetric.sleepDuration.unit)
            ? Copy.Home.unitHourSingular
            : unit
        return gap > 0
            ? (Copy.Home.whyValueAboveUsual(String(rounded), agreeing), .above)
            : (Copy.Home.whyValueBelowUsual(String(rounded), agreeing), .below)
    }

    static func gapToUsual(current: Double, baseline: Double, unit: String) -> String {
        usualComparison(current: current, baseline: baseline, unit: unit).text
    }

    /// Plain-English summary under the score as a bold heading + a lighter sub
    /// line, keyed to the 3-band model.
    /// Reads the same band as the ring colour. It used to carry its own 60/75
    /// split, so a 55 painted amber while this sentence called it low.
    func readinessSummary(score: Int) -> (head: String, sub: String) {
        switch RecoveryState(score: score) {
        case .red:    return (Copy.Home.scoreSummaryLowHead, Copy.Home.scoreSummaryLowSub)
        case .yellow: return (Copy.Home.scoreSummaryModerateHead, Copy.Home.scoreSummaryModerateSub)
        case .green:  return (Copy.Home.scoreSummaryHighHead, Copy.Home.scoreSummaryHighSub)
        }
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

    /// Snapshots the inputs on the main actor, then builds off it. Both arguments
    /// are value types, so nothing shared crosses the boundary.
    @MainActor
    private func buildHealthForecastsOffMain() async -> [MetricForecast] {
        let horizons = analysisEngine.mlOrchestrator.multiHorizonForecasts
        let series = healthKitManager.timeSeries
        return await Task.detached(priority: .utility) {
            ForecastBuilder.buildForecasts(multiHorizonForecasts: horizons, timeSeries: series)
        }.value
    }

    /// See `buildHealthForecastsOffMain`. `computeBiomarkers` is static over an
    /// `AnalysisContext` of value types.
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
