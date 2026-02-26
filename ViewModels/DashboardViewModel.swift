import Foundation
import Observation

/// ViewModel for the main dashboard showing overall score, top insights, and category cards
@Observable
final class DashboardViewModel {
    let healthKitManager: HealthKitManager
    let analysisEngine: AnalysisEngine
    let store: HealthDataStore

    var isLoading = false
    var errorMessage: String?

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

    /// User's selected health focuses — used to filter insights
    private var focusCategories: Set<HealthCategory> {
        let focuses = PersistenceManager().loadHealthFocuses()
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

    /// Top correlations for the home screen section
    var topCorrelations: [HealthCorrelation] {
        Array(analysisEngine.correlations.prefix(5))
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
    }

    /// Refresh data from HealthKit, sync to on-device store, and re-run analysis
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Capture previous trends before re-analysis
        let prevTrends = previousTrends

        // Load stored data + incrementally sync new data from HealthKit
        await healthKitManager.loadAndSync(store: store)
        analysisEngine.runFullAnalysis(timeSeries: healthKitManager.timeSeries)

        // Persist today's analysis snapshot for historical score tracking
        store.saveAnalysisSnapshot(
            overallScore: overallScore.score,
            categoryScores: analysisEngine.categoryScores,
            baselines: analysisEngine.baselines
        )

        // Store current trends for next refresh comparison
        previousTrends = analysisEngine.trends.mapValues { $0.direction }

        // Schedule notifications
        let persistence = PersistenceManager()
        let prefs = persistence.loadPreferences()

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

        let previousScore = persistence.loadPreviousWeekScore()
        let scoreChange = previousScore.map { overallScore.score - $0 } ?? 0
        persistence.recordWeeklyScore(overallScore.score)

        WeeklySummaryScheduler.schedule(
            score: overallScore.score,
            scoreChange: scoreChange,
            improvedCount: periodSummary7d.improvedCount,
            declinedCount: periodSummary7d.declinedCount,
            topTrends: topTrends,
            preferences: prefs
        )

        // Full alert evaluation with spike detection and trend reversals
        AlertEvaluator.evaluate(
            anomalies: analysisEngine.anomalies,
            trends: analysisEngine.trends,
            timeSeries: healthKitManager.timeSeries,
            previousTrends: prevTrends,
            preferences: prefs
        )
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

    /// Context-aware daily action based on recovery, stress, sleep, exercise, time of day
    func smartDailyAction(liveVM: LiveViewModel) -> SmartAction {
        let hour = Calendar.current.component(.hour, from: Date())
        let stress = liveVM.stressLevel
        let readiness = liveVM.readinessScore
        let sleepHours = liveVM.lastNightSleepDuration / 3600
        let exerciseMin = liveVM.todayExerciseMinutes
        let exerciseGoal = liveVM.exerciseGoal

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

        // Priority 4: Exercise goal already met
        if exerciseMin >= exerciseGoal {
            return SmartAction(
                icon: "checkmark.seal.fill",
                title: "Exercise goal reached!",
                subtitle: "\(Int(exerciseMin)) min today — stay active and hydrate"
            )
        }

        // Priority 5: Good recovery + exercise remaining
        if let r = readiness, r >= 60 {
            let remaining = Int(exerciseGoal - exerciseMin)
            return SmartAction(
                icon: "bolt.heart.fill",
                title: "You have \(remaining) min to go",
                subtitle: "Recovery is strong — a run or workout would be great"
            )
        }

        // Priority 6: Evening wind-down
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
