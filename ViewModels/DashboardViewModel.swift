import Foundation
import Observation

/// ViewModel for the main dashboard showing overall score, top insights, and category cards
@Observable
final class DashboardViewModel {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let store: HealthDataStore
    private let persistence = PersistenceManager()

    var isLoading = false
    var errorMessage: String?

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

    /// User's selected health focuses — used to filter insights and sort content
    var focusCategories: Set<HealthCategory> {
        let focuses = persistence.loadHealthFocuses()
        return HealthFocus.categories(for: focuses)
    }

    /// Insights filtered to user's focus areas + any critical/warning severity
    var focusedInsights: [Insight] {
        let categories = focusCategories
        return analysisEngine.insights.filter { insight in
            insight.severity >= .warning || categories.contains(insight.metric.category)
        }
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

    /// Initial load: authorize, fetch, analyze
    func load() async {
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

        await refresh()

        // Day 0 discovery generation — after refresh so all data is available
        if isFirstLaunchSync {
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

    /// Refresh data from HealthKit, sync to on-device store, and re-run analysis
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Capture previous trends before re-analysis
        let prevTrends = previousTrends

        // Load stored data + incrementally sync new data from HealthKit
        if isFirstLaunchSync { syncPhase = .importing }
        await healthKitManager.loadAndSync(store: store)
        if isFirstLaunchSync { syncPhase = .analyzing }
        analysisEngine.runFullAnalysis(timeSeries: healthKitManager.timeSeries)

        // Persist today's analysis snapshot for historical score tracking
        store.saveAnalysisSnapshot(
            overallScore: overallScore.score,
            categoryScores: analysisEngine.categoryScores,
            baselines: analysisEngine.baselines
        )

        // CloudKit backup (fire-and-forget, throttled to once per 6 hours)
        Task.detached(priority: .utility) { [store] in
            let persistence = PersistenceManager()
            await CloudBackupManager.shared.backupIfNeeded(store: store, persistence: persistence)
        }

        // Step 8: Score trajectory insights (uses stored score history + category breakdown)
        let scoreHistory = store.loadScoreHistory(days: 60)
        let trajectoryInsights = ScoreTrajectoryAnalyzer.generateInsights(
            scoreHistory: scoreHistory,
            categoryScores: analysisEngine.categoryScores
        )
        analysisEngine.insights.append(contentsOf: trajectoryInsights)

        // Step 9: Baseline drift insights (uses stored baseline history + correlations for co-drift)
        var baselineHistory: [HealthMetric: [(date: Date, baseline: UserBaseline)]] = [:]
        for metric in analysisEngine.baselines.keys {
            let history = store.loadBaselineHistory(for: metric)
            if history.count >= 30 {
                baselineHistory[metric] = history
            }
        }
        if !baselineHistory.isEmpty {
            let driftInsights = BaselineDriftDetector.generateInsights(
                currentBaselines: analysisEngine.baselines,
                baselineHistory: baselineHistory,
                correlations: analysisEngine.correlations
            )
            analysisEngine.insights.append(contentsOf: driftInsights)
        }

        // Re-sort after adding trajectory and drift insights
        analysisEngine.insights.sort { $0.priorityScore > $1.priorityScore }

        // Track analysis output
        AppAnalytics.shared.trackAnalysisCompleted(
            score: overallScore.score,
            insightsCount: analysisEngine.insights.count,
            anomaliesCount: analysisEngine.anomalies.count,
            risksCount: analysisEngine.healthRisks.count,
            correlationsCount: analysisEngine.correlations.count,
            illnessWarningsCount: analysisEngine.illnessWarnings.count,
            metricsAnalyzed: healthKitManager.timeSeries.count
        )

        // Store current trends for next refresh comparison
        previousTrends = analysisEngine.trends.mapValues { $0.direction }

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
        let scoreChange = previousScore.map { overallScore.score - $0 } ?? 0
        persistence.recordWeeklyScore(overallScore.score)

        // Track weekly score change for outcome metrics
        AppAnalytics.shared.trackWeeklyScoreChange(
            newScore: overallScore.score,
            previousScore: previousScore,
            delta: scoreChange
        )

        // Daily summary with richer data
        let anomalyCount = analysisEngine.anomalies.filter { $0.severity >= .warning }.count
        let categoryBreakdown = categoryScores.compactMap { score -> String? in
            guard let cat = score.category else { return nil }
            return "\(cat.shortName): \(score.score)"
        }.joined(separator: " | ")

        DailySummaryScheduler.schedule(
            score: overallScore.score,
            anomalyCount: anomalyCount,
            topInsights: Array(topInsights.prefix(3)),
            categoryBreakdown: categoryBreakdown,
            preferences: prefs
        )

        // Weekly summary with full details
        let periodSummary7d = periodSummary(for: .sevenDays)
        let topTrends: [(metric: String, direction: String, change: Double)] = analysisEngine.trends
            .sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
            .prefix(5)
            .map { (metric: $0.key.displayName, direction: $0.value.direction.symbol, change: $0.value.weekOverWeekChange) }

        WeeklySummaryScheduler.schedule(
            score: overallScore.score,
            scoreChange: scoreChange,
            improvedCount: periodSummary7d.improvedCount,
            declinedCount: periodSummary7d.declinedCount,
            topTrends: topTrends,
            preferences: prefs
        )

        if notificationsAuthorized {
            // Full alert evaluation with spike detection and trend reversals
            AlertEvaluator.evaluate(
                anomalies: analysisEngine.anomalies,
                trends: analysisEngine.trends,
                timeSeries: healthKitManager.timeSeries,
                previousTrends: prevTrends,
                preferences: prefs
            )
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

    /// Score delta from stored history (comparing to 7 days ago)
    var scoreChangeFromLastWeek: Int? {
        let history = store.loadScoreHistory(days: 14)
        guard history.count >= 2 else { return nil }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let oldEntries = history.filter { $0.date <= weekAgo }
        guard let oldScore = oldEntries.last?.score else { return nil }
        let delta = overallScore.score - oldScore
        return delta == 0 ? nil : delta
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
            case yearOverYear
            case allTimeExtreme
            case seasonal
            case longTermTrajectory
        }

        var icon: String {
            switch type {
            case .yearOverYear: return "calendar.badge.clock"
            case .allTimeExtreme: return "trophy.fill"
            case .seasonal: return "leaf.fill"
            case .longTermTrajectory: return "chart.line.uptrend.xyaxis"
            }
        }

        var typeLabel: String {
            switch type {
            case .yearOverYear: return "Year-over-Year"
            case .allTimeExtreme: return "All-Time"
            case .seasonal: return "Seasonal"
            case .longTermTrajectory: return "Long-Term"
            }
        }
    }

    var historicalHighlights: [HistoricalHighlight] {
        let ctx = analysisEngine.historicalContext
        var highlights: [HistoricalHighlight] = []
        let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        let focuses = focusCategories

        for (metric, context) in ctx {
            if let yoy = context.yearOverYearChange, abs(yoy) > 5 {
                let improving = metric.higherIsBetter ? yoy > 0 : yoy < 0
                let rec = improving
                    ? "Keep doing what's working — your consistency is paying off."
                    : RulesConfiguration.recommendation(for: metric, severity: .warning, trend: .declining)
                highlights.append(HistoricalHighlight(
                    metric: metric,
                    type: .yearOverYear,
                    title: "\(String(format: "%.0f", abs(yoy)))% \(improving ? "better" : "worse") than last \(monthName)",
                    recommendation: rec,
                    isPositive: improving,
                    significance: abs(yoy)
                ))
            }

            if context.isAllTimeExtreme, context.totalDataPoints >= 180 {
                let isHigh = context.allTimePercentile >= 95
                let good = isHigh == metric.higherIsBetter
                let rec = good
                    ? "You're at a personal best. Lock in the habits that got you here."
                    : RulesConfiguration.recommendation(for: metric, severity: .warning, trend: .declining)
                highlights.append(HistoricalHighlight(
                    metric: metric,
                    type: .allTimeExtreme,
                    title: "Near \(context.yearsOfData)-year \(isHigh ? "high" : "low")",
                    recommendation: rec,
                    isPositive: good,
                    significance: 90
                ))
            }

            if let seasonalDev = context.seasonalDeviation, abs(seasonalDev) > 10, context.yearsOfData >= 2 {
                let improving = metric.higherIsBetter ? seasonalDev > 0 : seasonalDev < 0
                let rec = improving
                    ? "You're beating your seasonal average — strong work."
                    : "You usually do better this time of year. \(RulesConfiguration.recommendation(for: metric, severity: .info, trend: .declining))"
                highlights.append(HistoricalHighlight(
                    metric: metric,
                    type: .seasonal,
                    title: "\(String(format: "%.0f", abs(seasonalDev)))% \(seasonalDev > 0 ? "above" : "below") \(monthName) norm",
                    recommendation: rec,
                    isPositive: improving,
                    significance: abs(seasonalDev)
                ))
            }

            if let change = context.longTermChangePercent, abs(change) > 10, context.yearsOfData >= 1 {
                let improving = metric.higherIsBetter ? change > 0 : change < 0
                let periodLabel = context.yearsOfData >= 2 ? "\(context.yearsOfData) years" : "1 year"
                let rec = improving
                    ? "Sustained improvement — your consistency is the key. Don't change what's working."
                    : "Gradual decline over \(periodLabel). Small daily adjustments compound. \(RulesConfiguration.recommendation(for: metric, severity: .info, trend: .declining))"
                highlights.append(HistoricalHighlight(
                    metric: metric,
                    type: .longTermTrajectory,
                    title: "\(improving ? "Up" : "Down") \(String(format: "%.0f", abs(change)))% over \(periodLabel)",
                    recommendation: rec,
                    isPositive: improving,
                    significance: abs(change)
                ))
            }
        }

        // Sort: focus-relevant metrics first, then by significance
        highlights.sort { a, b in
            let aFocus = !focuses.isEmpty && focuses.contains(a.metric.category)
            let bFocus = !focuses.isEmpty && focuses.contains(b.metric.category)
            if aFocus != bFocus { return aFocus }
            return a.significance > b.significance
        }
        return Array(highlights.prefix(5))
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
        let stress = liveVM.stressLevel
        let readiness = liveVM.readinessScore
        let sleepHours = liveVM.lastNightSleepDuration / 3600
        let exerciseMin = liveVM.todayExerciseMinutes
        let exerciseGoal = liveVM.exerciseGoal
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
        if liveVM.hasSleepData && sleepHours < 5.5 {
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

        let sleepHours = liveVM.lastNightSleepDuration / 3600
        let exerciseMin = liveVM.todayExerciseMinutes
        let exerciseGoal = liveVM.exerciseGoal

        if focuses.contains(.sleep) && liveVM.hasSleepData {
            let deepSleepMin = liveVM.lastNightDeepSleep / 60
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
            if let rhr = liveVM.latestRestingHeartRate, let baseline = analysisEngine.baselines[.restingHeartRate]?.mean, rhr > baseline * 1.05 {
                return SmartAction(
                    icon: "heart.fill",
                    title: "Your resting HR is trending up",
                    subtitle: "Try 10 min of meditation or deep breathing to bring it down"
                )
            }
        }

        if focuses.contains(.recovery) {
            if let r = liveVM.readinessScore, r < 60 {
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
