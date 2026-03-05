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

            // ML pipeline — runs after rule-based analysis completes
            await runMLPhase(timeSeries: ts)

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

    // MARK: - ML Pipeline

    /// Runs the on-device ML analysis pipeline after rule-based analysis completes.
    /// Uses score history from SwiftData and anomaly counts derived from stored snapshots.
    private func runMLPhase(timeSeries: [HealthMetric: MetricTimeSeries]) async {
        let scoreHistory = store.loadScoreHistory(days: 365)

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

        await analysisEngine.runMLAnalysis(
            timeSeries: timeSeries,
            scoreHistory: scoreHistory,
            anomalyCounts: anomalyCounts
        )
        await MainActor.run { updateCachedProperties() }
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
        let defaults = UserDefaults.standard
        defaults.set(score, forKey: AppKeys.Intent.score)
        defaults.set(overallScore.grade, forKey: AppKeys.Intent.grade)
        defaults.set(summaryText, forKey: AppKeys.Intent.summary)

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

    /// Dedicated intelligence layer for coach recommendations.
    /// Fuses insights, trends, risks, correlations, and causal chains into high-signal daily goals.
    private struct CoachRecommendationEngine {
        struct Recommendation {
            let metric: HealthMetric
            let action: String
            let reason: String
            let priority: Double
        }

        private struct Candidate {
            let metric: HealthMetric
            var action: String
            var reasons: [String]
            var score: Double
            var evidenceSources: Set<String>
            var category: HealthCategory { metric.category }

            mutating func merge(action newAction: String, reason: String, score newScore: Double, source: String) {
                let sanitizedReason = sanitize(reason)
                if !sanitizedReason.isEmpty, !reasons.contains(sanitizedReason) {
                    reasons.append(sanitizedReason)
                }
                if newScore > score || isGenericAction(action) {
                    action = newAction
                }
                score = max(score, newScore) + min(newScore * 0.15, 16)
                evidenceSources.insert(source)
                if reasons.count > 3 {
                    reasons = Array(reasons.prefix(3))
                }
            }
        }

        static func generateRecommendations(
            insights: [Insight],
            trends: [HealthMetric: TrendAnalyzer.TrendResult],
            baselines: [HealthMetric: UserBaseline],
            timeSeries: [HealthMetric: MetricTimeSeries],
            correlations: [HealthCorrelation],
            causalChains: [CausalChain],
            healthRisks: [HealthRisk],
            focusCategories: Set<HealthCategory>,
            maxCount: Int = 3
        ) -> [Recommendation] {
            var candidateByMetric: [HealthMetric: Candidate] = [:]
            var chainByEffect: [HealthMetric: CausalChain] = [:]
            for chain in causalChains {
                if let existing = chainByEffect[chain.affectedMetric],
                   existing.confidence >= chain.confidence {
                    continue
                }
                chainByEffect[chain.affectedMetric] = chain
            }

            // 1) Insight-driven candidates: strongest first, includes causal and illness insights.
            let actionableInsights = InsightGenerator.filterToActionable(insights, maxCount: 24)
            for insight in actionableInsights {
                let leverMetric = preferredLeverMetric(for: insight, chainByEffect: chainByEffect) ?? insight.metric
                guard isActionableMetric(leverMetric) else { continue }

                let trend = trends[leverMetric]
                let baseline = baselines[leverMetric]
                let recent = recentValue(for: leverMetric, in: timeSeries)

                let action = buildAction(
                    metric: leverMetric,
                    trend: trend,
                    baseline: baseline,
                    recentValue: recent,
                    recommendationHint: insight.recommendation
                )
                let reason = buildInsightReason(insight: insight, leverMetric: leverMetric)
                let score = scoreInsight(
                    insight: insight,
                    leverMetric: leverMetric,
                    focusCategories: focusCategories
                )
                upsert(
                    metric: leverMetric,
                    action: action,
                    reason: reason,
                    score: score,
                    source: "insight",
                    into: &candidateByMetric
                )
            }

            // 2) Correlation levers: prioritize non-obvious cause->effect opportunities.
            for corr in correlations.prefix(20) {
                guard isActionableMetric(corr.metricA),
                      abs(corr.correlation) >= 0.3,
                      corr.effectPercentDiff >= 10,
                      corr.sampleCount >= 14 else { continue }

                let trendB = trends[corr.metricB]
                let targetDeclining = trendB?.direction == .declining
                guard targetDeclining || abs(corr.correlation) >= 0.45 else { continue }

                let action = buildAction(
                    metric: corr.metricA,
                    trend: trends[corr.metricA],
                    baseline: baselines[corr.metricA],
                    recentValue: recentValue(for: corr.metricA, in: timeSeries),
                    recommendationHint: nil,
                    targetMetric: corr.metricB,
                    expectedEffectPercent: corr.effectPercentDiff
                )

                let lagText = corr.dayOffset == 0 ? "same-day" : "next-day"
                let reason = "\(corr.sampleCount)-day \(lagText) pattern: higher \(corr.metricA.displayName.lowercased()) links to \(String(format: "%.0f", corr.effectPercentDiff))% better \(corr.metricB.displayName.lowercased())."
                let score = scoreCorrelation(
                    correlation: corr,
                    targetTrend: trendB,
                    focusCategories: focusCategories
                )
                upsert(
                    metric: corr.metricA,
                    action: action,
                    reason: reason,
                    score: score,
                    source: "correlation",
                    into: &candidateByMetric
                )
            }

            // 3) Risk factors: pull high-impact factors even if they have no direct insight yet.
            for risk in healthRisks where risk.riskGrade != .low {
                for factor in risk.measuredFactors.sorted(by: { $0.contribution > $1.contribution }).prefix(4) {
                    let metric = factor.metric
                    guard isActionableMetric(metric) else { continue }

                    let action = buildAction(
                        metric: metric,
                        trend: trends[metric],
                        baseline: baselines[metric],
                        recentValue: recentValue(for: metric, in: timeSeries),
                        recommendationHint: nil
                    )
                    let reason = "\(risk.riskType.displayName) is \(risk.riskGrade.displayName.lowercased()); \(metric.displayName) is \(factor.status.displayName.lowercased())."
                    let score = scoreRisk(
                        risk: risk,
                        factor: factor,
                        focusCategories: focusCategories
                    )
                    upsert(
                        metric: metric,
                        action: action,
                        reason: reason,
                        score: score,
                        source: "risk",
                        into: &candidateByMetric
                    )
                }
            }

            // 4) Trend fallback: ensure coach still has concrete targets when other evidence is sparse.
            for (metric, trend) in trends {
                guard isActionableMetric(metric),
                      trend.direction == .declining,
                      abs(trend.weekOverWeekChange) >= 4 else { continue }

                let action = buildAction(
                    metric: metric,
                    trend: trend,
                    baseline: baselines[metric],
                    recentValue: recentValue(for: metric, in: timeSeries),
                    recommendationHint: nil
                )
                let reason = "\(metric.displayName) moved \(String(format: "%.0f", trend.weekOverWeekChange))% week-over-week."
                let score = scoreTrend(trend: trend, metric: metric, focusCategories: focusCategories)
                upsert(
                    metric: metric,
                    action: action,
                    reason: reason,
                    score: score,
                    source: "trend",
                    into: &candidateByMetric
                )
            }

            let ranked = candidateByMetric.values
                .map { candidate in
                    var updated = candidate
                    updated.score += Double(updated.evidenceSources.count) * 8
                    if updated.reasons.isEmpty {
                        updated.reasons = ["\(updated.metric.displayName) is currently off your baseline."]
                    }
                    return updated
                }
                .sorted { $0.score > $1.score }

            // Keep diversity: avoid flooding the coach section with one category only.
            var selected: [Candidate] = []
            var usedCategories: Set<HealthCategory> = []
            for candidate in ranked {
                if usedCategories.contains(candidate.category) && selected.count < maxCount - 1 {
                    continue
                }
                selected.append(candidate)
                usedCategories.insert(candidate.category)
                if selected.count >= maxCount { break }
            }

            // Backfill if diversity filter removed too many.
            if selected.count < maxCount {
                for candidate in ranked where !selected.contains(where: { $0.metric == candidate.metric }) {
                    selected.append(candidate)
                    if selected.count >= maxCount { break }
                }
            }

            return selected.prefix(maxCount).map { candidate in
                Recommendation(
                    metric: candidate.metric,
                    action: sanitize(candidate.action, maxLength: 140),
                    reason: sanitize(candidate.reasons.joined(separator: " "), maxLength: 150),
                    priority: candidate.score
                )
            }
        }

        private static func upsert(
            metric: HealthMetric,
            action: String,
            reason: String,
            score: Double,
            source: String,
            into map: inout [HealthMetric: Candidate]
        ) {
            guard !action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if var existing = map[metric] {
                existing.merge(action: action, reason: reason, score: score, source: source)
                map[metric] = existing
            } else {
                map[metric] = Candidate(
                    metric: metric,
                    action: sanitize(action),
                    reasons: [sanitize(reason)],
                    score: score,
                    evidenceSources: [source]
                )
            }
        }

        private static func preferredLeverMetric(
            for insight: Insight,
            chainByEffect: [HealthMetric: CausalChain]
        ) -> HealthMetric? {
            if let root = insight.context?.rootCauseMetric, isActionableMetric(root) {
                return root
            }

            if insight.category == .causalChain,
               let chain = chainByEffect[insight.metric],
               let cause = chain.links.first?.causeMetric,
               isActionableMetric(cause) {
                return cause
            }

            if let related = insight.relatedMetrics.first(where: { isActionableMetric($0) }) {
                return related
            }
            return nil
        }

        private static func scoreInsight(
            insight: Insight,
            leverMetric: HealthMetric,
            focusCategories: Set<HealthCategory>
        ) -> Double {
            let severityWeight: Double = switch insight.severity {
            case .critical: 130
            case .warning: 85
            case .info: 30
            }
            let actionability = Double(InsightGenerator.actionabilityScore(insight))
            let deviation = min(abs(insight.deviationPercent), 50) * 1.4
            let trendBoost: Double = insight.trend == .declining ? 28 : 8
            let focusBoost: Double = focusCategories.contains(leverMetric.category) ? 30 : 0
            let categoryBoost: Double = switch insight.category {
            case .causalChain: 36
            case .illnessWarning: 34
            case .crossMetricAnomaly: 28
            case .correlation: 24
            case .cognitiveEnergy: 20
            default: 12
            }
            let confidenceBoost = (insight.context?.confidenceLevel ?? 0) * 25
            let rootCauseBoost: Double = insight.context?.rootCauseMetric == nil ? 0 : 18

            var total = severityWeight
            total += actionability
            total += deviation
            total += trendBoost
            total += focusBoost
            total += categoryBoost
            total += confidenceBoost
            total += rootCauseBoost
            return total
        }

        private static func scoreCorrelation(
            correlation: HealthCorrelation,
            targetTrend: TrendAnalyzer.TrendResult?,
            focusCategories: Set<HealthCategory>
        ) -> Double {
            var score = abs(correlation.correlation) * 130
            score += min(correlation.effectPercentDiff, 40) * 2.2
            score += min(Double(correlation.sampleCount), 50)
            if targetTrend?.direction == .declining { score += 30 }
            if focusCategories.contains(correlation.metricA.category) { score += 24 }
            if correlation.dayOffset > 0 { score += 8 }
            return score
        }

        private static func scoreRisk(
            risk: HealthRisk,
            factor: RiskFactor,
            focusCategories: Set<HealthCategory>
        ) -> Double {
            let statusBoost: Double = switch factor.status {
            case .critical: 35
            case .concerning: 24
            case .borderline: 12
            case .optimal, .unmeasured: 0
            }
            let focusBoost: Double = focusCategories.contains(factor.metric.category) ? 20 : 0
            let base = Double(risk.level) * 1.8
            return base + Double(factor.contribution) + statusBoost + focusBoost
        }

        private static func scoreTrend(
            trend: TrendAnalyzer.TrendResult,
            metric: HealthMetric,
            focusCategories: Set<HealthCategory>
        ) -> Double {
            let wow = abs(trend.weekOverWeekChange)
            let inflectionBoost: Double = switch trend.inflection {
            case .accelerating: 20
            case .reversing: 12
            case .decelerating: 8
            case .steady: 0
            }
            let focusBoost: Double = focusCategories.contains(metric.category) ? 18 : 0
            return wow * 6 + inflectionBoost + focusBoost + 30
        }

        private static func buildInsightReason(insight: Insight, leverMetric: HealthMetric) -> String {
            var parts: [String] = []
            let absDeviation = abs(insight.deviationPercent)
            if absDeviation >= 5 {
                parts.append("\(insight.metric.displayName) is off baseline by \(String(format: "%.0f", absDeviation))%.")
            }
            if leverMetric != insight.metric {
                parts.append("Best lever from your data: \(leverMetric.displayName.lowercased()).")
            }
            if !insight.relatedMetrics.isEmpty {
                let topRelated = insight.relatedMetrics.prefix(2).map { $0.displayName.lowercased() }.joined(separator: " + ")
                parts.append("Connected metrics: \(topRelated).")
            }
            if let confidence = insight.context?.confidenceLevel, confidence > 0 {
                parts.append("Confidence \(String(format: "%.0f", confidence * 100))%.")
            }
            if parts.isEmpty {
                parts.append(insight.summary)
            }
            return parts.joined(separator: " ")
        }

        private static func buildAction(
            metric: HealthMetric,
            trend: TrendAnalyzer.TrendResult?,
            baseline: UserBaseline?,
            recentValue: Double?,
            recommendationHint: String?,
            targetMetric: HealthMetric? = nil,
            expectedEffectPercent: Double? = nil
        ) -> String {
            if let hint = recommendationHint {
                let cleanedHint = cleanHintAction(hint)
                if !cleanedHint.isEmpty && !isGenericAction(cleanedHint) {
                    return sanitize(cleanedHint, maxLength: 140)
                }
            }

            let fallbackTrend = trend?.direction ?? .declining
            let attachEffect: (String) -> String = { base in
                guard let targetMetric, let expectedEffectPercent, expectedEffectPercent >= 10 else {
                    return sanitize(base, maxLength: 140)
                }
                let annotated = "\(base) Potential upside: ~\(String(format: "%.0f", expectedEffectPercent))% better \(targetMetric.displayName.lowercased())."
                return sanitize(annotated, maxLength: 140)
            }

            switch metric {
            case .steps, .distanceWalkingRunning:
                let baselineSteps = Int((baseline?.mean ?? 8_000).rounded())
                let recentSteps = Int((recentValue ?? Double(baselineSteps)).rounded())
                let gap = max(800, baselineSteps - recentSteps)
                return attachEffect("Add a 20-minute walk and close at least \(formatLargeInt(gap)) steps today.")

            case .activeCalories, .exerciseMinutes, .workoutDuration, .workoutCount, .appleMoveTime:
                let target = max(20, Int((baseline?.mean ?? 30).rounded()))
                return attachEffect("Schedule \(target) minutes of moderate movement today, split into two short sessions if needed.")

            case .sleepDuration:
                let baselineHours = baseline?.mean ?? 7.5
                let recent = recentValue ?? baselineHours
                let boundedDiff = max(-2.0, min(2.0, baselineHours - recent))
                if boundedDiff > 0.25 {
                    let extraMinutes = max(30, Int((boundedDiff * 60).rounded()))
                    return attachEffect("Move bedtime earlier and add about \(extraMinutes) minutes of sleep tonight.")
                }
                return attachEffect("Hold a consistent bedtime tonight and protect your current sleep rhythm.")

            case .sleepDeep:
                return attachEffect("Protect deep sleep tonight: no alcohol, no caffeine after 2 pm, and keep the room cool.")

            case .sleepREM:
                return attachEffect("Stabilize REM tonight with a fixed wake time and a 60-minute screen-free wind-down.")

            case .sleepCore, .sleepAwake:
                return attachEffect("Keep bedtime and wake time consistent tonight to reduce sleep fragmentation.")

            case .mindfulMinutes:
                let target = max(10, Int((baseline?.mean ?? 12).rounded()))
                return attachEffect("Run a focused breathing block for \(target) minutes before your highest-stress period.")

            case .timeInDaylight:
                return attachEffect("Get 20 minutes of outdoor light before noon to improve recovery and sleep timing.")

            case .waterIntake:
                let targetMl = Int((baseline?.mean ?? 2_500).rounded())
                return attachEffect("Front-load hydration: drink 500 mL now and target \(formatLargeInt(targetMl)) mL total today.")

            case .proteinIntake:
                let targetG = max(70, Int((baseline?.mean ?? 95).rounded()))
                return attachEffect("Hit \(targetG)g protein today by anchoring each meal with a clear protein source.")

            case .fiberIntake:
                let targetG = max(25, Int((baseline?.mean ?? 28).rounded()))
                return attachEffect("Push fiber to \(targetG)g today by adding vegetables and a whole-grain serving.")

            case .restingHeartRate:
                return attachEffect("Use a low-load recovery day, hydration, and an early bedtime to bring resting HR down.")

            case .heartRateVariability:
                return attachEffect("Prioritize parasympathetic recovery: 10 minutes of slow breathing and an easier training day.")

            case .heartRateRecovery:
                return attachEffect("Add a controlled cooldown after workouts and one easy cardio session to improve HR recovery.")

            case .vo2Max:
                return attachEffect("Add one 20-30 minute zone-2 cardio block today to defend VO2 max.")

            case .bloodOxygen, .respiratoryRate:
                return attachEffect("Favor nasal breathing during light activity and avoid late intense sessions tonight.")

            case .weight, .bodyFatPercentage, .waistCircumference, .bloodGlucose:
                return attachEffect("Anchor meals around protein and fiber, then add a 10-15 minute post-meal walk.")

            default:
                let deviation = baseline.flatMap { base -> Double? in
                    guard let recentValue else { return nil }
                    return base.deviationPercent(for: recentValue)
                }
                let fallback = RulesConfiguration.recommendation(
                    for: metric,
                    severity: .warning,
                    trend: fallbackTrend,
                    currentValue: recentValue,
                    deviationPercent: deviation
                )
                return sanitize(cleanHintAction(fallback), maxLength: 140)
            }
        }

        private static func cleanHintAction(_ text: String) -> String {
            let sentences = text
                .split(separator: ".", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let filtered = sentences.filter { sentence in
                let lower = sentence.lowercased()
                return !lower.contains("triage level")
            }
            return sanitize((filtered.first ?? "").appending(filtered.isEmpty ? "" : "."))
        }

        private static func recentValue(for metric: HealthMetric, in seriesMap: [HealthMetric: MetricTimeSeries]) -> Double? {
            guard let series = seriesMap[metric] else { return nil }
            if let latest = series.latestValue { return latest }
            let last3 = series.samples(lastDays: 3).map(\.value)
            return last3.isEmpty ? nil : last3.mean
        }

        private static func isActionableMetric(_ metric: HealthMetric) -> Bool {
            switch metric {
            case .steps, .activeCalories, .exerciseMinutes, .standHours, .distanceWalkingRunning,
                 .flightsClimbed, .distanceCycling, .distanceSwimming, .appleMoveTime,
                 .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
                 .mindfulMinutes, .timeInDaylight,
                 .waterIntake, .proteinIntake, .fiberIntake, .sugarIntake, .sodiumIntake,
                 .caffeineIntake, .totalCaloriesIntake, .carbohydrateIntake, .fatIntake,
                 .restingHeartRate, .heartRateVariability, .heartRateRecovery,
                 .vo2Max, .bloodOxygen, .respiratoryRate,
                 .weight, .bodyFatPercentage, .waistCircumference, .bloodGlucose,
                 .walkingSpeed, .walkingStepLength, .walkingAsymmetry,
                 .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed,
                 .sixMinuteWalkTestDistance, .workoutDuration, .workoutCount:
                return true
            default:
                return false
            }
        }

        private static func sanitize(_ text: String, maxLength: Int = 220) -> String {
            let compact = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard compact.count > maxLength else { return compact }

            let truncated = compact.prefix(maxLength)
            if let split = truncated.lastIndex(of: " ") {
                return String(truncated[..<split]) + "..."
            }
            return String(truncated) + "..."
        }

        private static func isGenericAction(_ text: String) -> Bool {
            let lower = text.lowercased()
            let genericPhrases = [
                "keep it up",
                "stay on track",
                "monitor",
                "watch this",
                "good trend",
                "looks stable",
                "within normal range"
            ]
            return genericPhrases.contains { lower.contains($0) }
        }

        private static func formatLargeInt(_ value: Int) -> String {
            if value >= 10_000 {
                return String(format: "%.1fk", Double(value) / 1000)
            }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }

    private func computeCoachGoals() -> [CoachGoal] {
        let enriched = CoachRecommendationEngine.generateRecommendations(
            insights: analysisEngine.insights,
            trends: analysisEngine.trends,
            baselines: analysisEngine.baselines,
            timeSeries: healthKitManager.timeSeries,
            correlations: analysisEngine.correlations,
            causalChains: analysisEngine.causalChains,
            healthRisks: analysisEngine.healthRisks,
            focusCategories: cachedFocusCategories,
            maxCount: 3
        )

        if !enriched.isEmpty {
            return enriched.map { rec in
                CoachGoal(
                    metric: rec.metric,
                    action: rec.action,
                    reason: rec.reason,
                    priority: rec.priority
                )
            }
        }

        // Fallback to legacy approach if the intelligence layer has too little evidence.
        return computeCoachGoalsLegacy()
    }

    private func computeCoachGoalsLegacy() -> [CoachGoal] {
        let focuses = cachedFocusCategories
        var goals: [CoachGoal] = []
        var usedCategories: Set<HealthCategory> = []

        // 1. Declining actionable metrics → personalized nudge with real numbers
        for (metric, trend) in analysisEngine.trends {
            guard trend.weekOverWeekChange < -3 else { continue }
            let category = metric.category
            guard !usedCategories.contains(category) else { continue }
            guard let goal = buildPersonalizedGoal(metric: metric, trend: trend) else { continue }
            goals.append(goal)
            usedCategories.insert(category)
        }

        // 2. Risk focus areas → data-backed action per risk
        for risk in analysisEngine.healthRisks where risk.riskGrade != .low {
            for factor in risk.measuredFactors {
                let metric = factor.metric
                guard !usedCategories.contains(metric.category) else { continue }
                let trend = analysisEngine.trends[metric]
                guard let goal = buildPersonalizedGoal(
                    metric: metric,
                    trend: trend,
                    reasonOverride: "\(risk.riskType.displayName) risk — \(risk.riskGrade.displayName.lowercased())"
                ) else { continue }
                goals.append(CoachGoal(
                    metric: goal.metric,
                    action: goal.action,
                    reason: "\(risk.riskType.displayName) risk — \(risk.riskGrade.displayName.lowercased())",
                    priority: Double(risk.level)
                ))
                usedCategories.insert(metric.category)
            }
        }

        // 3. Correlation-derived — surface a non-obvious connection with data
        for corr in analysisEngine.correlations.prefix(10) {
            let metric = corr.metricA
            guard !usedCategories.contains(metric.category),
                  let trend = analysisEngine.trends[metric],
                  trend.direction != .improving else { continue }
            guard let goal = buildPersonalizedGoal(
                metric: metric,
                trend: trend,
                reasonOverride: corr.effectSummary
            ) else { continue }
            goals.append(CoachGoal(
                metric: goal.metric,
                action: goal.action,
                reason: corr.effectSummary,
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

    /// Builds a personalized, data-driven action for a metric.
    /// Returns nil for metrics that aren't directly actionable by the user.
    private func buildPersonalizedGoal(
        metric: HealthMetric,
        trend: TrendAnalyzer.TrendResult?,
        reasonOverride: String? = nil
    ) -> CoachGoal? {
        let baseline = analysisEngine.baselines[metric]
        let series = healthKitManager.timeSeries[metric]
        let recentValue = series?.samples(lastDays: 1).last?.value
        let weekAvg = series?.samples(lastDays: 7).map(\.value).mean
        let baselineMean = baseline?.mean

        let action: String
        let reason: String
        let priority: Double = abs(trend?.weekOverWeekChange ?? 0)

        switch metric {
        // MARK: Activity — user can directly move more
        case .steps, .distanceWalkingRunning:
            if let recent = recentValue, let base = baselineMean {
                let gap = Int(base - recent)
                if gap > 0 {
                    action = "You need about \(formatLargeInt(gap)) more steps to hit your usual \(formatLargeInt(Int(base)))"
                } else {
                    action = "You're on track — keep moving to stay above \(formatLargeInt(Int(base))) steps"
                }
            } else if let base = baselineMean {
                action = "Aim for \(formatLargeInt(Int(base))) steps — try a walk after lunch"
            } else {
                action = "Get a walk in today"
            }

        case .activeCalories:
            if let avg = weekAvg, let base = baselineMean, base > 0 {
                let pct = Int(((base - avg) / base) * 100)
                if pct > 0 {
                    action = "You're burning \(pct)% fewer calories than usual — add a brisk walk"
                } else {
                    action = "Calorie burn is on track at \(Int(avg)) kcal — keep the momentum"
                }
            } else {
                action = "Get some active movement in today"
            }

        case .exerciseMinutes, .workoutDuration:
            if let base = baselineMean {
                action = "Fit in \(Int(base)) min of exercise — even a short session counts"
            } else {
                action = "Get a workout in today"
            }

        case .workoutCount:
            if let avg = weekAvg, avg < 0.5 {
                action = "You haven't worked out in a few days — today's a good day"
            } else {
                action = "Keep your workout streak going today"
            }

        case .flightsClimbed:
            if let base = baselineMean {
                action = "Climb \(Int(base)) flights today — take the stairs when you can"
            } else {
                action = "Take the stairs instead of the elevator today"
            }

        case .standHours:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.8 {
                action = "You're averaging \(String(format: "%.0f", avg)) stand hours vs your usual \(String(format: "%.0f", base)) — set hourly reminders"
            } else {
                action = "Stand up and move every hour today"
            }

        // MARK: Sleep — user can control bedtime habits
        case .sleepDuration:
            if let recent = recentValue, let base = baselineMean {
                let diff = base - recent
                if diff > 0.5 {
                    let hrs = String(format: "%.1f", recent)
                    let target = String(format: "%.1f", base)
                    action = "Last night was \(hrs) hrs — get to bed earlier to reach your \(target) hr average"
                } else {
                    action = "Sleep was solid — keep the same bedtime tonight"
                }
            } else if let base = baselineMean {
                action = "Target \(String(format: "%.1f", base)) hrs tonight — start winding down early"
            } else {
                action = "Prioritize a full night's sleep tonight"
            }

        case .sleepDeep:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.85 {
                action = "Deep sleep is down to \(String(format: "%.1f", avg)) hrs — skip caffeine after 2pm and dim lights early"
            } else {
                action = "Protect your deep sleep — keep the room cool and dark"
            }

        case .sleepREM:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.85 {
                action = "REM sleep dropped to \(String(format: "%.1f", avg)) hrs — avoid alcohol tonight and keep a steady wake time"
            } else {
                action = "REM is healthy — stick with your current routine"
            }

        case .sleepCore:
            action = "Keep a consistent bedtime tonight — your body clock depends on it"

        // MARK: Mindfulness — user can practice
        case .mindfulMinutes:
            if let base = baselineMean, base > 0 {
                action = "You usually do \(Int(base)) min — try a breathing session before lunch"
            } else {
                action = "Try a 5-minute breathing exercise today"
            }

        case .timeInDaylight:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.7 {
                action = "Only \(Int(avg)) min of daylight this week vs your usual \(Int(base)) — get outside for 15 min"
            } else {
                action = "Keep getting daylight — it helps sleep and mood"
            }

        // MARK: Nutrition — user can eat/drink
        case .waterIntake:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.8 {
                action = "You're at \(Int(avg)) mL/day vs your usual \(Int(base)) mL — drink a glass now"
            } else {
                action = "Stay on top of hydration today"
            }

        case .proteinIntake:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.85 {
                action = "Protein is \(Int(avg))g vs your usual \(Int(base))g — add eggs, chicken, or a shake"
            } else {
                action = "Protein intake is solid — keep it up"
            }

        case .fiberIntake:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.85 {
                action = "Fiber is low at \(Int(avg))g — add vegetables or whole grains to your next meal"
            } else {
                action = "Fiber intake is on track"
            }

        // MARK: Cardio — user can do cardio work
        case .vo2Max:
            if let trend = trend, trend.direction == .declining {
                action = "VO2 max is trending down — do 20+ min of sustained cardio today"
            } else {
                action = "Maintain your cardio fitness with a run or brisk walk"
            }

        case .distanceCycling:
            if let base = baselineMean, base > 0 {
                action = "You usually ride \(String(format: "%.1f", base)) km — try to get a ride in today"
            } else {
                action = "Go for a bike ride today"
            }

        case .distanceSwimming:
            action = "Fit in a swim session today"

        case .appleMoveTime:
            if let avg = weekAvg, let base = baselineMean, avg < base * 0.8 {
                action = "Move time is \(Int(avg)) min vs \(Int(base)) min — take a walk break"
            } else {
                action = "Keep moving throughout the day"
            }

        default:
            return nil
        }

        if let reasonOverride {
            reason = reasonOverride
        } else if let trend, abs(trend.weekOverWeekChange) > 3 {
            let direction = trend.weekOverWeekChange < 0 ? "down" : "up"
            let pct = String(format: "%.0f", abs(trend.weekOverWeekChange))
            if let avg = weekAvg {
                reason = "\(metric.displayName) \(direction) \(pct)% — averaging \(metric.formatValue(avg)) \(metric.unit)"
            } else {
                reason = "\(metric.displayName) \(direction) \(pct)% this week"
            }
        } else if let avg = weekAvg, let base = baselineMean, base > 0 {
            let pct = Int(((avg - base) / base) * 100)
            if abs(pct) > 3 {
                reason = "\(metric.displayName) is \(pct > 0 ? "+" : "")\(pct)% vs your baseline"
            } else {
                reason = "\(metric.displayName) is right at your baseline"
            }
        } else {
            reason = ""
        }

        return CoachGoal(metric: metric, action: action, reason: reason, priority: priority)
    }

    private func formatLargeInt(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1fk", Double(value) / 1000)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
