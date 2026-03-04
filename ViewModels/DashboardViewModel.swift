import Foundation
import Observation
import os

/// ViewModel for the main dashboard showing overall score, top insights, and category cards
@Observable
final class DashboardViewModel {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let store: HealthDataStore
    private let persistence = PersistenceManager()

    var isLoading = false
    var hasCompletedInitialLoad = false
    var errorMessage: String?
    private var isSyncRetryInProgress = false
    private var lastSyncRetryAttempt: Date?

    /// Tracks last full analysis to avoid redundant re-runs when no new data arrives
    private var lastAnalysisDate: Date?
    private static let analysisMinInterval: TimeInterval = 300  // 5 minutes
    private static let syncRetryMinInterval: TimeInterval = 600  // 10 minutes
    private static let connectivityRecoveryMinInterval: TimeInterval = 900  // 15 minutes
    private var lastConnectivityRecoverySync: Date?

    // MARK: - Cached Properties (updated on refresh, not on every view render)
    private(set) var cachedScoreChangeFromLastWeek: Int?
    private(set) var cachedScoreChangeFromYesterday: Int?
    private(set) var cachedTrendsSummary: TrendsSummary?
    private(set) var cachedHistoricalHighlights: [HistoricalHighlight] = []
    private(set) var cachedTopCorrelations: [HealthCorrelation] = []
    private(set) var cachedFocusCategories: Set<HealthCategory> = []
    private(set) var cachedFocusedInsights: [Insight] = []
    private(set) var cachedCoachGoals: [CoachGoal] = []

    // MARK: - Discovery (Day 0)
    var discoveries: [Discovery] = []
    var showDiscovery = false
    var syncPhase: SyncPhase = .idle

    enum SyncPhase {
        case idle, importing, analyzing, discovering, complete
    }

    var isFirstLaunchSync: Bool {
        !UserDefaults.standard.bool(forKey: AppKeys.App.hasSeenDiscovery)
    }

    /// Selected time period — shared across all Home screen sections
    var selectedPeriod: TimePeriod = .sevenDays

    /// Previous trend directions — used for trend reversal detection
    private var previousTrends: [HealthMetric: TrendDirection] = [:]

    var overallScore: HealthScore {
        analysisEngine.overallScore
    }

    var categoryScores: [HealthScore] {
        analysisEngine.categoryScores
    }

    /// User's selected health focuses — cached to avoid Keychain+AES-GCM decrypt per access
    var focusCategories: Set<HealthCategory> {
        cachedFocusCategories
    }

    /// Insights filtered to user's focus areas + any critical/warning severity — cached
    var focusedInsights: [Insight] {
        cachedFocusedInsights
    }

    /// The single most important insight for today's briefing headline
    var headlineInsight: Insight? {
        focusedInsights.first
    }

    var topInsights: [Insight] {
        Array(focusedInsights.prefix(3))
    }

    var allInsights: [Insight] {
        focusedInsights
    }

    /// All significant correlations discovered across metrics
    var correlations: [HealthCorrelation] {
        analysisEngine.correlations
    }

    /// Top correlations for the home screen section, sorted by focus relevance
    var topCorrelations: [HealthCorrelation] {
        cachedTopCorrelations
    }

    /// Health risks sorted by level (highest risk first)
    var healthRisks: [HealthRisk] {
        analysisEngine.healthRisks
    }

    /// Top risks that need attention (moderate or higher)
    var topHealthRisks: [HealthRisk] {
        analysisEngine.healthRisks.filter { $0.riskGrade != .low }
    }

    /// Top 3 actionable insights for the compact card display, filtered by selected period
    var topActionableInsights: [Insight] {
        topActionableInsights(for: selectedPeriod)
    }

    /// Period-aware insights: only include metrics that have data in the selected period, filtered by focus areas
    func topActionableInsights(for period: TimePeriod) -> [Insight] {
        let days = period.days
        let categories = focusCategories
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
        keyMetricSnapshots(for: selectedPeriod)
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
            case .allTime: return 365
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
        let categories = focusCategories
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

    init(healthKitManager: HealthKitManager, analysisEngine: AnalysisEngine, store: HealthDataStore) {
        self.healthKitManager = healthKitManager
        self.analysisEngine = analysisEngine
        self.store = store
    }

    /// Use results produced by onboarding calibration without re-running heavy first-load work.
    /// Assumes shared `healthKitManager` + `analysisEngine` were already populated.
    func hydrateFromCalibration() {
        isLoading = false
        errorMessage = nil
        hasCompletedInitialLoad = true
        updateCachedProperties()
        lastAnalysisDate = Date()
    }

    /// Initial load: authorize, fetch, analyze.
    /// `skipDiscovery` is used by onboarding calibration to avoid extra first-day computation.
    func load(
        skipDiscovery: Bool = false,
        awaitDeferredAnalysis: Bool = false,
        forceHeavyDeferred: Bool = false,
        runHousekeeping: Bool = true
    ) async {
        isLoading = true
        defer { isLoading = false }

        guard healthKitManager.isHealthKitAvailable else {
            errorMessage = "HealthKit is not available on this device. Please run on a real iPhone paired with Apple Watch."
            return
        }

        await healthKitManager.requestAuthorization()

        guard healthKitManager.isAuthorized else {
            errorMessage = healthKitManager.error ?? "HealthKit authorization required"
            return
        }

        await refresh(
            awaitDeferredAnalysis: awaitDeferredAnalysis,
            forceHeavyDeferred: forceHeavyDeferred,
            runHousekeeping: runHousekeeping
        )
        hasCompletedInitialLoad = true

        // Day 0 discovery generation — after refresh so all data is available.
        // Skipped when onboarding already provides a dedicated calibration flow.
        if isFirstLaunchSync && !skipDiscovery {
            syncPhase = .discovering
            let results = DiscoveryEngine.generateDiscoveries(
                timeSeries: healthKitManager.timeSeries,
                correlations: analysisEngine.correlations,
                historicalContext: analysisEngine.historicalContext
            )
            if results.count >= DiscoveryEngine.minimumDiscoveriesRequired {
                discoveries = results
                showDiscovery = true
            } else {
                // Do not keep users in perpetual "first launch sync" when data is still sparse.
                UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenDiscovery)
            }
            syncPhase = .complete
        }
    }

    /// Dismiss the discovery view and mark as seen
    func dismissDiscovery() {
        showDiscovery = false
        UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenDiscovery)
    }

    /// True when the initial load finished but no health data is available despite authorization.
    /// Used by Home timer and scene-phase recovery to trigger automatic retries.
    var needsSyncRetry: Bool {
        hasCompletedInitialLoad && healthKitManager.timeSeries.isEmpty && healthKitManager.isAuthorized
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
        guard hasCompletedInitialLoad else { return false }
        guard healthKitManager.isAuthorized else { return false }
        guard !isLoading, !isSyncRetryInProgress else { return false }

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
        // Capture previous trends before re-analysis
        let prevTrends = previousTrends

        // Load stored data + incrementally sync new data from HealthKit
        if isFirstLaunchSync { syncPhase = .importing }
        let syncResult = await healthKitManager.loadAndSync(store: store)

        // Skip full analysis if no new data AND we analyzed within the last 5 minutes
        let recentlyAnalyzed = lastAnalysisDate.map { Date().timeIntervalSince($0) < Self.analysisMinInterval } ?? false
        if !syncResult.hasNewData && recentlyAnalyzed && !syncResult.isFirstSync {
            return
        }

        if isFirstLaunchSync { syncPhase = .analyzing }

        let ts = healthKitManager.timeSeries
        async let cycleFlowSamplesTask = healthKitManager.fetchMenstrualFlowSamples(days: 365)

        // Phase 1: Core analysis — scores, trends, baselines (blocks until done, UI needs these)
        await Task.detached(priority: .userInitiated) { [analysisEngine] in
            analysisEngine.runCoreAnalysis(timeSeries: ts)
        }.value

        // Persist today's analysis snapshot for historical score tracking
        store.saveAnalysisSnapshot(
            overallScore: overallScore.score,
            categoryScores: analysisEngine.categoryScores,
            baselines: analysisEngine.baselines
        )

        // Update cached computed properties so views don't recompute on every render
        updateCachedProperties()

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

            updateCachedProperties()

            await Task.detached(priority: .background) { [analysisEngine] in
                analysisEngine.runDeferredHeavy(timeSeries: ts, force: forceHeavyDeferred)
            }.value

            updateCachedProperties()

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
            return
        }

        // Phase 2A: Essential insights — lightweight (~15K ops), runs immediately
        let cycleFlowSamples = await cycleFlowSamplesTask
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            self.analysisEngine.runDeferredEssentials(
                timeSeries: ts,
                cycleFlowSamples: cycleFlowSamples
            )
            await MainActor.run { self.updateCachedProperties() }
        }

        // Phase 2B: Heavy analysis + housekeeping — delayed for thermal relief
        Task.detached(priority: .background) { [weak self, prevTrends] in
            guard let self else { return }
            let analysisEngine = self.analysisEngine
            let logger = Logger(subsystem: "com.healthpulse", category: "Dashboard")

            // Thermal break — let CPU cool after core + essentials
            try? await Task.sleep(for: .seconds(10))

            // Gate on thermal state — skip heavy work entirely if device is overheating
            if ThermalManager.shared.shouldThrottle {
                logger.warning("Skipping deferred heavy analysis — thermal state is elevated")
                return
            }

            // Wait for ML analysis to complete before starting heavy cross-metric work
            // so we don't stack CPU-intensive phases on top of each other
            while analysisEngine.mlOrchestrator.isRunning {
                try? await Task.sleep(for: .milliseconds(500))
            }

            // Heavy cross-metric analysis (correlations, historical, causal chains)
            // Skipped automatically if results are still fresh (1-hour TTL)
            analysisEngine.runDeferredHeavy(timeSeries: ts, force: forceHeavyDeferred)

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
        let scoreHistory = store.loadScoreHistory(days: 60)
        let trajectoryInsights = ScoreTrajectoryAnalyzer.generateInsights(
            scoreHistory: scoreHistory,
            categoryScores: currentCategoryScores
        )
        let baselineHistory = store.loadAllBaselineHistory(forMetrics: Set(currentBaselines.keys))
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
            analysisEngine.insights = AnalysisEngine.deduplicateInsights(analysisEngine.insights)
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

        // CloudKit backup (throttled to once per 6 hours)
        let persistence = PersistenceManager()
        await CloudBackupManager.shared.backupIfNeeded(store: store, persistence: persistence)

        // Evaluate recommendation outcomes and prune old records
        let currentTimeSeries = healthKitManager.timeSeries
        RecommendationEvaluator.evaluatePending(store: store, timeSeries: currentTimeSeries)
        store.pruneOldRecommendations()
        store.pruneOldNotificationEvents()

        // Analytics tracking
        AppAnalytics.shared.trackAnalysisCompleted(
            score: currentScore,
            insightsCount: analysisEngine.insights.count,
            anomaliesCount: currentAnomalies.count,
            risksCount: analysisEngine.healthRisks.count,
            correlationsCount: currentCorrelations.count,
            illnessWarningsCount: analysisEngine.illnessWarnings.count,
            metricsAnalyzed: metricsCount
        )

        // Schedule notifications
        let prefs = persistence.loadPreferences()
        let notificationsEnabled =
            prefs.dailySummaryEnabled ||
            prefs.weeklySummaryEnabled ||
            prefs.criticalAlertsEnabled ||
            prefs.warningAlertsEnabled ||
            prefs.heartRateSpikeAlertsEnabled ||
            prefs.trendReversalAlertsEnabled ||
            prefs.improvementAlertsEnabled ||
            prefs.watchNotWornReminderEnabled ||
            prefs.lowBatteryReminderEnabled
        let notificationsAuthorized = notificationsEnabled
            ? await NotificationManager.shared.requestAuthorizationIfNeeded()
            : false
        let previousScore = persistence.loadPreviousWeekScore()
        let scoreChange = previousScore.map { currentScore - $0 } ?? 0
        persistence.recordWeeklyScore(currentScore)

        AppAnalytics.shared.trackWeeklyScoreChange(
            newScore: currentScore,
            previousScore: previousScore,
            delta: scoreChange
        )

        let anomalyCount = currentAnomalies.filter { $0.severity >= .warning }.count
        let categoryBreakdown = currentCategoryScores.compactMap { score -> String? in
            guard let cat = score.category else { return nil }
            return "\(cat.shortName): \(score.score)"
        }.joined(separator: " | ")

        let topAnomaly: (metricName: String, changePercent: Double)? = currentAnomalies
            .filter { $0.severity >= .warning }
            .max(by: { $0.severity < $1.severity })
            .map { (metricName: $0.metric.displayName, changePercent: $0.deviationPercent) }

        // Optimize daily summary timing based on notification engagement data
        var optimizedPrefs = prefs
        let notifEvents = store.loadNotificationEvents(days: 30)
        if notifEvents.count >= 14 {
            let optimalHour = NotificationOptimizer.optimalHour(events: notifEvents)
            optimizedPrefs.dailySummaryTime.hour = optimalHour
        }

        DailySummaryScheduler.schedule(
            score: currentScore,
            anomalyCount: anomalyCount,
            topInsights: Array(analysisEngine.insights.prefix(3)),
            categoryBreakdown: categoryBreakdown,
            preferences: optimizedPrefs,
            topAnomaly: topAnomaly,
            scoreChangeFromYesterday: cachedScoreChangeFromYesterday,
            streakDays: SessionTracker.shared.streakDays
        )

        let periodSummary7d = await MainActor.run { self.periodSummary(for: .sevenDays) }
        let topTrends: [(metric: String, direction: String, change: Double)] = currentTrends
            .sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
            .prefix(5)
            .map { (metric: $0.key.displayName, direction: $0.value.direction.symbol, change: $0.value.weekOverWeekChange) }

        WeeklySummaryScheduler.schedule(
            score: currentScore,
            scoreChange: scoreChange,
            improvedCount: periodSummary7d.improvedCount,
            declinedCount: periodSummary7d.declinedCount,
            topTrends: topTrends,
            preferences: prefs
        )

        if notificationsAuthorized {
            AlertEvaluator.evaluate(
                anomalies: currentAnomalies,
                trends: currentTrends,
                timeSeries: timeSeries,
                previousTrends: prevTrends,
                preferences: prefs
            )
        }
    }

    // MARK: - Cache Update (called once per refresh, not per render)

    private func updateCachedProperties() {
        // Cache focus categories first (Keychain + AES-GCM decrypt — do once, not per view access)
        let focuses = persistence.loadHealthFocuses()
        cachedFocusCategories = HealthFocus.categories(for: focuses)

        // Cache focused insights (depends on focus categories)
        let categories = cachedFocusCategories
        cachedFocusedInsights = analysisEngine.insights.filter { insight in
            insight.severity >= .warning || categories.contains(insight.metric.category)
        }

        cachedScoreChangeFromLastWeek = computeScoreChangeFromLastWeek()
        cachedScoreChangeFromYesterday = computeScoreChangeFromYesterday()
        cachedTrendsSummary = computeTrendsSummary()
        cachedHistoricalHighlights = computeHistoricalHighlights()
        cachedTopCorrelations = computeTopCorrelations()
        cachedCoachGoals = computeCoachGoals()

        // Save shown recommendations for outcome tracking
        let insightsToSave = cachedFocusedInsights.prefix(10)
        Task { @MainActor [store] in
            for insight in insightsToSave {
                store.saveRecommendation(insight)
            }
        }
    }

    private func computeScoreChangeFromLastWeek() -> Int? {
        let history = store.loadScoreHistory(days: 14)
        guard history.count >= 2 else { return nil }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oldEntries = history.filter { $0.date <= weekAgo }
        guard let oldScore = oldEntries.last?.score else { return nil }
        let delta = overallScore.score - oldScore
        return delta == 0 ? nil : delta
    }

    private func computeScoreChangeFromYesterday() -> Int? {
        let history = store.loadScoreHistory(days: 3)
        guard history.count >= 2 else { return nil }
        let cal = Calendar.current
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let today = cal.startOfDay(for: Date())
        let yesterdayEntries = history.filter { $0.date >= yesterday && $0.date < today }
        guard let yesterdayScore = yesterdayEntries.last?.score else { return nil }
        let delta = overallScore.score - yesterdayScore
        return delta == 0 ? nil : delta
    }

    private func computeTrendsSummary() -> TrendsSummary {
        var improving = 0, stable = 0, declining = 0
        var movers: [MetricMover] = []

        for (metric, trend) in analysisEngine.trends {
            switch trend.direction {
            case .improving: improving += 1
            case .stable: stable += 1
            case .declining: declining += 1
            }
            if abs(trend.weekOverWeekChange) > 3 {
                movers.append(MetricMover(
                    metric: metric,
                    changePercent: trend.weekOverWeekChange,
                    improving: trend.direction == .improving
                ))
            }
        }
        movers.sort { abs($0.changePercent) > abs($1.changePercent) }
        return TrendsSummary(
            improving: improving,
            stable: stable,
            declining: declining,
            topMovers: Array(movers.prefix(5))
        )
    }

    private func computeTopCorrelations() -> [HealthCorrelation] {
        let focuses = focusCategories
        if focuses.isEmpty {
            return Array(analysisEngine.correlations.prefix(5))
        }
        let sorted = analysisEngine.correlations.sorted { a, b in
            let aRelevant = focuses.contains(a.metricA.category) || focuses.contains(a.metricB.category)
            let bRelevant = focuses.contains(b.metricA.category) || focuses.contains(b.metricB.category)
            if aRelevant != bRelevant { return aRelevant }
            return abs(a.correlation) > abs(b.correlation)
        }
        return Array(sorted.prefix(5))
    }

    private func computeHistoricalHighlights() -> [HistoricalHighlight] {
        var highlights: [HistoricalHighlight] = []
        let focuses = focusCategories

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

    // MARK: - Coach Goals Computation

    private func computeCoachGoals() -> [CoachGoal] {
        let focuses = cachedFocusCategories
        var goals: [CoachGoal] = []
        var usedCategories: Set<HealthCategory> = []

        // 1. Declining metrics the user can act on → actionable daily focus
        for (metric, trend) in analysisEngine.trends {
            guard trend.weekOverWeekChange < -3,
                  let action = dailyAction(for: metric) else { continue }
            let category = metric.category
            guard !usedCategories.contains(category) else { continue }

            let drop = String(format: "%.0f", abs(trend.weekOverWeekChange))
            goals.append(CoachGoal(
                metric: metric,
                action: action,
                reason: "\(metric.displayName) down \(drop)% this week",
                priority: abs(trend.weekOverWeekChange)
            ))
            usedCategories.insert(category)
        }

        // 2. Risk focus areas → one actionable item per risk
        for risk in analysisEngine.healthRisks where risk.riskGrade != .low {
            for factor in risk.measuredFactors {
                guard !usedCategories.contains(factor.metric.category),
                      let action = dailyAction(for: factor.metric) else { continue }
                goals.append(CoachGoal(
                    metric: factor.metric,
                    action: action,
                    reason: "\(risk.riskType.displayName) risk is \(risk.riskGrade.displayName.lowercased())",
                    priority: Double(risk.level)
                ))
                usedCategories.insert(factor.metric.category)
            }
        }

        // 3. Correlation-derived — surface something the user might not think of
        for corr in analysisEngine.correlations.prefix(10) {
            let metric = corr.metricA
            guard !usedCategories.contains(metric.category),
                  let action = dailyAction(for: metric),
                  let trend = analysisEngine.trends[metric],
                  trend.direction != .improving else { continue }
            goals.append(CoachGoal(
                metric: metric,
                action: action,
                reason: "\(corr.causeLabel) → \(corr.effectLabel)",
                priority: abs(corr.correlation) * 50
            ))
            usedCategories.insert(metric.category)
        }

        // Sort: focus categories first, then by priority
        goals.sort { a, b in
            let aFocus = !focuses.isEmpty && focuses.contains(a.metric.category)
            let bFocus = !focuses.isEmpty && focuses.contains(b.metric.category)
            if aFocus != bFocus { return aFocus }
            return a.priority > b.priority
        }

        return Array(goals.prefix(3))
    }

    /// Maps a metric to a concrete thing the user can do today.
    /// Returns nil for metrics that aren't directly actionable (HRV, resting HR, blood oxygen, etc.).
    private func dailyAction(for metric: HealthMetric) -> String? {
        switch metric {
        case .steps, .distanceWalkingRunning:
            return "Take a walk after your next meal"
        case .activeCalories:
            return "Fit in 20 minutes of movement today"
        case .exerciseMinutes, .workoutDuration:
            return "Get a workout in today"
        case .workoutCount:
            return "Make time for a workout today"
        case .flightsClimbed:
            return "Take the stairs instead of the elevator"
        case .standHours:
            return "Stand up and stretch every hour"
        case .sleepDuration:
            return "Start winding down 30 minutes earlier tonight"
        case .sleepDeep, .sleepREM:
            return "Avoid screens an hour before bed tonight"
        case .sleepCore:
            return "Keep a consistent bedtime tonight"
        case .mindfulMinutes:
            return "Do a 5-minute breathing exercise today"
        case .timeInDaylight:
            return "Spend 15 minutes outside today"
        case .waterIntake:
            return "Drink a glass of water right now"
        case .distanceCycling:
            return "Go for a bike ride today"
        case .distanceSwimming:
            return "Fit in a swim session today"
        case .vo2Max:
            return "Do some cardio — a brisk walk or jog"
        case .proteinIntake:
            return "Add a protein-rich snack today"
        case .fiberIntake:
            return "Add vegetables or whole grains to your next meal"
        case .appleMoveTime:
            return "Move around for a few minutes this hour"
        default:
            return nil
        }
    }

    // MARK: - Computed Analytics for Views

    /// All anomalous metrics across all categories
    var anomalousMetrics: [AnomalyDetector.AnomalyResult] {
        analysisEngine.anomalies.filter { $0.severity >= .warning }
    }

    /// Number of critical alerts currently active
    var criticalAlertCount: Int {
        analysisEngine.anomalies.filter { $0.severity == .critical }.count
    }

    /// Number of warning alerts currently active
    var warningAlertCount: Int {
        analysisEngine.anomalies.filter { $0.severity == .warning }.count
    }

    // MARK: - Explore Tab Data

    /// Score delta from stored history (comparing to 7 days ago) — cached on refresh
    var scoreChangeFromLastWeek: Int? {
        cachedScoreChangeFromLastWeek
    }

    /// Score delta from stored history (comparing to yesterday) — cached on refresh
    var scoreChangeFromYesterday: Int? {
        cachedScoreChangeFromYesterday
    }

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

    var trendsSummary: TrendsSummary {
        cachedTrendsSummary ?? TrendsSummary(improving: 0, stable: 0, declining: 0, topMovers: [])
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

    var historicalHighlights: [HistoricalHighlight] {
        cachedHistoricalHighlights
    }

    // MARK: - Coach Goals

    struct CoachGoal: Identifiable {
        let id = UUID()
        let metric: HealthMetric
        let action: String
        let reason: String
        let priority: Double
    }

    var coachGoals: [CoachGoal] {
        cachedCoachGoals
    }

    /// Data depth summary — how much data powers the analysis
    var dataDepth: (metricsTracked: Int, totalDataPoints: Int, daysOfData: Int) {
        let series = healthKitManager.timeSeries
        let metrics = series.count
        let points = series.values.reduce(0) { $0 + $1.totalDataPoints }
        let maxDays = series.values.map(\.daysOfData).max() ?? 0
        return (metrics, points, maxDays)
    }

    // MARK: - New Intelligence Features

    /// Active illness early warnings
    var illnessWarnings: [IllnessEarlyWarning.Warning] {
        analysisEngine.illnessWarnings
    }

    /// Whether there's an active illness early warning
    var hasIllnessWarning: Bool {
        !analysisEngine.illnessWarnings.isEmpty
    }

    /// The most severe illness warning (for Today section hero)
    var topIllnessWarning: IllnessEarlyWarning.Warning? {
        analysisEngine.illnessWarnings.first
    }

    /// Cross-metric anomalies detected
    var crossMetricAnomalies: [CrossMetricAnomalyDetector.CrossMetricAnomaly] {
        analysisEngine.crossMetricAnomalies
    }

    /// Causal chains explaining metric changes
    var causalChains: [CausalChain] {
        analysisEngine.causalChains
    }

    /// Top causal chain for the today section
    var topCausalChain: CausalChain? {
        analysisEngine.causalChains.first
    }

    /// Score explanation for transparency
    var scoreExplanation: HealthScorer.ScoreExplanation? {
        analysisEngine.scoreExplanation
    }

    /// High-quality actionable insights only (for Today section)
    var actionableInsights: [Insight] {
        InsightGenerator.filterToActionable(focusedInsights, maxCount: 3)
    }

    /// Trends summary for Today section (moved from Explore)
    var todayTrendsSummary: TrendsSummary {
        trendsSummary
    }

    /// Health risks for Today section (moved from Explore)
    var todayHealthRisks: [HealthRisk] {
        analysisEngine.healthRisks.filter { $0.riskGrade != .low }
    }

    // MARK: - Body Insights

    /// Insights grouped by InsightCategory, filtered by focus areas, excluding empty categories
    var insightsByCategory: [(category: InsightCategory, insights: [Insight])] {
        let focused = focusedInsights
        return InsightCategory.allCases.compactMap { category in
            let matching = focused.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            return (category: category, insights: matching)
        }
    }

    /// High-quality actionable insights grouped by category, pre-filtered via InsightGenerator
    var actionableInsightsByCategory: [(category: InsightCategory, insights: [Insight])] {
        let filtered = InsightGenerator.filterToActionable(analysisEngine.insights, maxCount: 10)
        return InsightCategory.allCases.compactMap { category in
            let matching = filtered.filter { $0.category == category }
            guard !matching.isEmpty else { return nil }
            return (category: category, insights: matching)
        }
    }

    /// Context-aware daily action based on recovery, stress, sleep, exercise, time of day, and user focus areas
    func smartDailyAction(liveVM: LiveViewModel) -> SmartAction {
        let hour = Calendar.current.component(.hour, from: Date())
        let stress = liveVM.recovery.stressLevel
        let readiness = liveVM.recovery.readinessScore
        let sleepHours = liveVM.sleep.lastNightSleepDuration / 3600
        let exerciseMin = liveVM.activity.todayExerciseMinutes
        let exerciseGoal = liveVM.activity.exerciseGoal
        let focuses = persistence.loadHealthFocuses()

        // Priority 1: High stress
        if let s = stress, s >= 60 {
            return SmartAction(
                icon: "wind",
                title: "Take 5 min to breathe",
                subtitle: "Stress is elevated — box breathing (4-4-4-4) can lower it fast"
            )
        }

        // Priority 2: Poor sleep
        if liveVM.sleep.hasSleepData && sleepHours < 5.5 {
            return SmartAction(
                icon: "moon.zzz.fill",
                title: "Go easy today",
                subtitle: "Only \(formatHoursMinutes(sleepHours)) of sleep — skip intense workouts"
            )
        }

        // Priority 3: Low recovery
        if let r = readiness, r < 40 {
            return SmartAction(
                icon: "figure.mind.and.body",
                title: "Prioritize recovery",
                subtitle: "Readiness is \(r)% — stretching or yoga only today"
            )
        }

        // Priority 4: Focus-aware actions based on onboarding priorities
        if let focusAction = focusAwareAction(liveVM: liveVM, focuses: focuses) {
            return focusAction
        }

        // Priority 5: Exercise goal already met
        if exerciseMin >= exerciseGoal {
            return SmartAction(
                icon: "checkmark.seal.fill",
                title: "Exercise goal reached!",
                subtitle: "\(Int(exerciseMin)) min today — stay active and hydrate"
            )
        }

        // Priority 6: Good recovery + exercise remaining
        if let r = readiness, r >= 60 {
            let remaining = Int(exerciseGoal - exerciseMin)
            return SmartAction(
                icon: "bolt.heart.fill",
                title: "You have \(remaining) min to go",
                subtitle: "Recovery is strong — a run or workout would be great"
            )
        }

        // Priority 7: Evening wind-down
        if hour >= 20 {
            return SmartAction(
                icon: "moon.fill",
                title: "Wind down for sleep",
                subtitle: "Dim screens and skip caffeine for better rest"
            )
        }

        // Default: walk
        return SmartAction(
            icon: "figure.walk",
            title: "Take a 15 min walk",
            subtitle: "A short walk boosts mood and energy"
        )
    }

    /// Generate a focus-specific action based on user's onboarding health priorities
    private func focusAwareAction(liveVM: LiveViewModel, focuses: Set<HealthFocus>) -> SmartAction? {
        guard !focuses.isEmpty else { return nil }

        let sleepHours = liveVM.sleep.lastNightSleepDuration / 3600
        let exerciseMin = liveVM.activity.todayExerciseMinutes
        let exerciseGoal = liveVM.activity.exerciseGoal

        if focuses.contains(.sleep) && liveVM.sleep.hasSleepData {
            let deepSleepMin = liveVM.sleep.lastNightDeepSleep / 60
            if deepSleepMin < 45 {
                return SmartAction(
                    icon: "moon.zzz.fill",
                    title: "Boost your deep sleep",
                    subtitle: "Only \(Int(deepSleepMin)) min of deep sleep — try cutting caffeine after 2 PM"
                )
            }
            if sleepHours < 7 {
                return SmartAction(
                    icon: "bed.double.fill",
                    title: "Get to bed 30 min earlier",
                    subtitle: "\(formatHoursMinutes(sleepHours)) last night — aim for 7+ hours"
                )
            }
        }

        if focuses.contains(.fitness) && exerciseMin < exerciseGoal {
            let remaining = Int(exerciseGoal - exerciseMin)
            return SmartAction(
                icon: "figure.run",
                title: "You're \(remaining) min from your goal",
                subtitle: "A brisk walk or quick workout would close the gap"
            )
        }

        if focuses.contains(.heartHealth) {
            if let rhr = liveVM.recovery.latestRestingHeartRate, let baseline = analysisEngine.baselines[.restingHeartRate]?.mean, rhr > baseline * 1.05 {
                return SmartAction(
                    icon: "heart.fill",
                    title: "Your resting HR is trending up",
                    subtitle: "Try 10 min of meditation or deep breathing to bring it down"
                )
            }
        }

        if focuses.contains(.recovery) {
            if let r = liveVM.recovery.readinessScore, r < 60 {
                return SmartAction(
                    icon: "figure.mind.and.body",
                    title: "Focus on recovery today",
                    subtitle: "Readiness is \(r)% — light stretching and hydration will help"
                )
            }
        }

        return nil
    }

    struct SmartAction {
        let icon: String
        let title: String
        let subtitle: String
    }

    func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 { return "\(m)m" }
        return "\(h)h \(String(format: "%02d", m))m"
    }
}
