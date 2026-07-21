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
    private static let analysisMinInterval: TimeInterval = 300  // 5 minutes
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
        /// Set by parent after each analysis refresh
        fileprivate(set) var overallScore: HealthScore = HealthScore(score: 0)
        fileprivate(set) var categoryScores: [HealthScore] = []

        var scoreChangeFromLastWeek: Int? { cachedScoreChangeFromLastWeek }
        var scoreChangeFromYesterday: Int? { cachedScoreChangeFromYesterday }
        var weeklyScoreChange: Int? { cachedWeeklyScoreChange }

        var recoveryState: RecoveryState {
            RecoveryState(score: overallScore.score)
        }

        var dayClassification: String {
            recoveryState.dayType
        }

        /// Score explanation for transparency
        fileprivate(set) var scoreExplanation: HealthScorer.ScoreExplanation?

        /// 7-day rolling average score for Explore tab (differs from today's overallScore).
        /// Falls back to overallScore when insufficient history.
        fileprivate(set) var rollingAverageScore: Int = 0
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
        /// Raw health focuses from encrypted store. cached to avoid repeated Keychain + AES-GCM decryption.
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
                let daysAgo = Date.cal.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
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
                let daysAgo = Date.cal.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
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

        // Update trend state
        trends.cachedTrendsSummary = computeTrendsSummary()
        if !(ThermalManager.shared.shouldThrottle && !trends.cachedTrendMetricsByTimeframe.isEmpty) {
            trends.cachedTrendMetricsByTimeframe = [
                7: computeTrendMetrics(days: 7),
                30: computeTrendMetrics(days: 30),
                90: computeTrendMetrics(days: 90),
            ]
        }

        // Update analysis state
        if !(ThermalManager.shared.shouldThrottle && !analysis.cachedHistoricalHighlights.isEmpty) {
            analysis.cachedHistoricalHighlights = computeHistoricalHighlights()
        }
        if !(ThermalManager.shared.shouldThrottle && !analysis.cachedTopCorrelations.isEmpty) {
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
            proofLine: proofSummary.cardProofLine,
            proofSummary: proofSummary
        )

        _cachedDailyAction = action
        _cachedDailyActionDate = today
        saveActionKey(recommendation.title)

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

    /// Regenerate the intelligence briefing with live data from LiveViewModel.
    @MainActor
    func refreshIntelligenceBriefing(liveVM: LiveViewModel) {
        guard analysisEngine.mlOrchestrator.hasRunOnce else { return }
        intelligenceBriefing = todayIntelligenceEngine.generateBriefing(
            orchestrator: analysisEngine.mlOrchestrator,
            baselines: analysisEngine.baselines,
            trends: analysisEngine.trends,
            timeSeries: healthKitManager.timeSeries,
            liveHRV: liveVM.recovery.latestHRV,
            liveRestingHR: liveVM.recovery.latestRestingHeartRate,
            sleepHours: liveVM.sleep.lastNightSleepDuration / 3600,
            deepSleepMinutes: liveVM.sleep.lastNightDeepSleep / 60,
            exerciseMinutes: liveVM.activity.todayExerciseMinutes,
            exerciseGoal: liveVM.activity.exerciseGoal,
            readinessScore: liveVM.recovery.readinessScore
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
            deepMinutes: healthKitManager.timeSeries[.sleepDeep]?.latestValue ?? 0,
            remMinutes: healthKitManager.timeSeries[.sleepREM]?.latestValue ?? 0,
            quality: sleepHours >= 7 ? "Good" : sleepHours >= 6 ? "Fair" : "Low",
            updatedAt: Date()
        )

        // Action. from daily action cache
        let actionText = _cachedDailyAction
        let action = actionText.map {
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
        /// Historical proof line shown on the home card (e.g. "The last 5 times you followed this advice, things went well")
        var proofLine: String?
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
        enum Kind { case sleep, heart, energy }
        enum Tone { case good, okay, concern, noData }
        let id = UUID()
        let kind: Kind
        let name: String     // "Sleep"
        let sub: String      // short meaning line
        let value: String    // "6h 40m" / "Calm" / "—"
        let status: String   // "Good" / "Short" / "No reading yet"
        let tone: Tone

        /// Placeholder row for a signal that has no reading yet.
        static func noData(kind: Kind, name: String) -> RecoveryWhyReason {
            .init(kind: kind, name: name, sub: Copy.Home.whyNoData, value: "—", status: "", tone: .noData)
        }
    }

    /// The three signals behind today's readiness, always in order Sleep, Heart,
    /// Energy. Sleep from last-night duration vs goal, Heart from HRV vs your
    /// baseline, Energy from the readiness score. Missing signals return a
    /// `.noData` row instead of being dropped.
    @MainActor
    func recoveryWhyReasons(liveVM: LiveViewModel) -> [RecoveryWhyReason] {
        let s = todayRecoverySignals(liveVM: liveVM)

        // Sleep
        let sleepRow: RecoveryWhyReason
        if let sleep = s.sleepHoursLast {
            let h = Int(sleep), m = Int((sleep - Double(h)) * 60)
            let short = sleep < s.sleepHoursGoal - 1.0
            let okay = !short && sleep < s.sleepHoursGoal - 0.25
            sleepRow = .init(kind: .sleep, name: Copy.Home.whyNameSleep,
                             sub: short ? Copy.Home.whySubSleepShort : Copy.Home.whySubSleepGood,
                             value: "\(h)h \(m)m",
                             status: short ? Copy.Home.whyStatusShort : (okay ? Copy.Home.whyStatusOkay : Copy.Home.whyStatusGood),
                             tone: short ? .concern : (okay ? .okay : .good))
        } else {
            sleepRow = .noData(kind: .sleep, name: Copy.Home.whyNameSleep)
        }

        // Heart
        let heartRow: RecoveryWhyReason
        if let hrv = s.hrvCurrent, let hrvBase = s.hrvBaseline, hrvBase > 0 {
            let calm = hrv >= hrvBase * 0.95
            heartRow = .init(kind: .heart, name: Copy.Home.whyNameHeart,
                             sub: calm ? Copy.Home.whySubHeartCalm : Copy.Home.whySubHeartWorking,
                             value: calm ? Copy.Home.whyValueCalm : Copy.Home.whyValueWorking,
                             status: calm ? Copy.Home.whyStatusGood : Copy.Home.whyStatusElevated,
                             tone: calm ? .good : .concern)
        } else {
            heartRow = .noData(kind: .heart, name: Copy.Home.whyNameHeart)
        }

        // Energy — use the same score the ring shows (live readiness, or the
        // daily health score as fallback) so it always has a value when a score
        // exists, matching the number in the ring.
        let energyRow: RecoveryWhyReason
        let energyScore = liveVM.recovery.readinessScore ?? (overallScore.score > 0 ? overallScore.score : nil)
        if let readiness = energyScore {
            let low = readiness < 60
            energyRow = .init(kind: .energy, name: Copy.Home.whyNameEnergy,
                              sub: low ? Copy.Home.whySubEnergyLow : Copy.Home.whySubEnergyGood,
                              value: low ? Copy.Home.whyValueLow : Copy.Home.whyValueReady,
                              status: low ? Copy.Home.whyStatusBelow : Copy.Home.whyStatusGood,
                              tone: low ? .concern : .good)
        } else {
            energyRow = .noData(kind: .energy, name: Copy.Home.whyNameEnergy)
        }

        return [sleepRow, heartRow, energyRow]
    }

    /// Plain-English summary line under the score, keyed to the 3-band model.
    func readinessSummaryLine(score: Int) -> String {
        if score < 60 { return Copy.Home.scoreSummaryLow }
        if score <= 75 { return Copy.Home.scoreSummaryModerate }
        return Copy.Home.scoreSummaryHigh
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
        MorningCheckInManager.save(checkIn)
        subjectiveReadinessAdjustment = checkIn.readinessAdjustment
        AppAnalytics.shared.trackCoreAction(.completedMorningCheckIn, screen: .home)

        // First-ever check-in is the denied branch's value moment; fire once via
        // a one-shot flag so history pruning can never replay it.
        if !UserDefaults.standard.bool(forKey: AppKeys.Prediction.firstCheckInLogged) {
            UserDefaults.standard.set(true, forKey: AppKeys.Prediction.firstCheckInLogged)
            AppAnalytics.shared.trackFirstCheckInDone()
        }
    }

    /// Adjusted readiness score incorporating subjective data (Paper 10)
    /// Falls back to overall score if no readiness is available.
    @MainActor
    var adjustedReadinessScore: Int {
        let base = scores.overallScore.score
        return max(0, min(100, base + subjectiveReadinessAdjustment))
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

    /// Run NL health query (Papers 1 & 2: PHIA). uses full ML pipeline context
    func queryHealthData(_ question: String) async -> HealthDataQueryEngine.QueryResult {
        await makeHealthDataQueryRequest().execute(question: question)
    }

    /// Execute a health data query with thermal-aware priority
    nonisolated func executeHealthQuery(_ question: String) async -> HealthDataQueryEngine.QueryResult {
        let request = await makeHealthDataQueryRequest()
        let priority: TaskPriority = ThermalManager.shared.shouldThrottle ? .background : .utility
        return await Task.detached(priority: priority) {
            await request.execute(question: question)
        }.value
    }

    /// Assess current receptivity for nudge delivery (Paper 5 & 6: JITAI)
    func assessReceptivity(liveVM: LiveViewModel) -> ReceptivityEstimator.ReceptivityAssessment {
        analysisEngine.mlOrchestrator.receptivityEstimator.assess(
            currentHRV: liveVM.recovery.latestHRV,
            recentStressLevel: liveVM.recovery.stressLevel.map { Double($0) / 100.0 },
            lastAppOpenDate: Date()
        )
    }
}
