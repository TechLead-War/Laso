import Foundation

final class DashboardHousekeepingService {
    struct Payload {
        let currentScore: Int
        let currentAnomalies: [AnomalyDetector.AnomalyResult]
        let currentTrends: [HealthMetric: TrendAnalyzer.TrendResult]
        let previousTrends: [HealthMetric: TrendDirection]
        let currentCategoryScores: [HealthScore]
        let metricsCount: Int
        let timeSeries: [HealthMetric: MetricTimeSeries]
        let insights: [Insight]
        let healthRisksCount: Int
        let correlationsCount: Int
        let illnessWarningsCount: Int
        let strainLabel: String
        let scoreChangeFromYesterday: Int?
        let periodSummary: DashboardViewModel.PeriodSummary
    }

    private let persistenceManager: PersistenceManager
    private let cloudBackupManager: any CloudBackupService
    private let notificationManager: any NotificationAuthorizationService
    private let analytics: any AnalyticsTrackingService
    private let sessionTracker: any SessionTrackingService

    init(
        persistenceManager: PersistenceManager,
        cloudBackupManager: any CloudBackupService = CloudBackupManager.shared,
        notificationManager: any NotificationAuthorizationService = NotificationManager.shared,
        analytics: any AnalyticsTrackingService = AppAnalytics.shared,
        sessionTracker: any SessionTrackingService = SessionTracker.shared
    ) {
        self.persistenceManager = persistenceManager
        self.cloudBackupManager = cloudBackupManager
        self.notificationManager = notificationManager
        self.analytics = analytics
        self.sessionTracker = sessionTracker
    }

    func perform(store: HealthDataStore, payload: Payload) async {
        await cloudBackupManager.backupIfNeeded(store: store, persistence: persistenceManager)

        // HealthDataStore is @MainActor — batch SwiftData operations on main actor
        await MainActor.run {
            RecommendationEvaluator.evaluatePending(store: store, timeSeries: payload.timeSeries)
            store.pruneOldRecommendations()
            store.pruneOldNotificationEvents()
        }

        analytics.trackAnalysisCompleted(
            score: payload.currentScore,
            insightsCount: payload.insights.count,
            anomaliesCount: payload.currentAnomalies.count,
            risksCount: payload.healthRisksCount,
            correlationsCount: payload.correlationsCount,
            illnessWarningsCount: payload.illnessWarningsCount,
            metricsAnalyzed: payload.metricsCount
        )

        let preferences = persistenceManager.loadPreferences()
        let notificationsEnabled =
            preferences.dailySummaryEnabled ||
            preferences.eveningSummaryEnabled ||
            preferences.weeklySummaryEnabled ||
            preferences.criticalAlertsEnabled ||
            preferences.warningAlertsEnabled ||
            preferences.heartRateSpikeAlertsEnabled ||
            preferences.trendReversalAlertsEnabled ||
            preferences.improvementAlertsEnabled ||
            preferences.watchNotWornReminderEnabled ||
            preferences.lowBatteryReminderEnabled
        let notificationsAuthorized = notificationsEnabled
            ? await notificationManager.requestAuthorizationIfNeeded()
            : false

        let previousScore = persistenceManager.loadPreviousWeekScore()
        let scoreChange = previousScore.map { payload.currentScore - $0 } ?? 0
        persistenceManager.recordWeeklyScore(payload.currentScore)

        analytics.trackWeeklyScoreChange(
            newScore: payload.currentScore,
            previousScore: previousScore,
            delta: scoreChange
        )

        // Track whether this refresh delivered new value to the user
        analytics.trackValueDelivered(
            newInsightsCount: payload.insights.count,
            scoreChanged: scoreChange != 0,
            newAnomalies: payload.currentAnomalies.filter { $0.severity >= .warning }.count,
            newCorrelations: payload.correlationsCount
        )

        let anomalyCount = payload.currentAnomalies.filter { $0.severity >= .warning }.count
        let categoryBreakdown = payload.currentCategoryScores.compactMap { score -> String? in
            guard let category = score.category else { return nil }
            return "\(category.shortName): \(score.score)"
        }.joined(separator: " | ")

        let topAnomaly: (metricName: String, changePercent: Double)? = payload.currentAnomalies
            .filter { $0.severity >= .warning }
            .max(by: { $0.severity < $1.severity })
            .map { (metricName: $0.metric.displayName, changePercent: $0.deviationPercent) }

        // Notification scheduling accesses @MainActor HealthDataStore internally
        // (via NotificationManager.store), so run all scheduling on main actor.
        let streakDays = sessionTracker.streakDays
        await MainActor.run {
            var optimizedPreferences = preferences
            let notificationEvents = store.loadNotificationEvents(days: 30)
            if notificationEvents.count >= 14 {
                optimizedPreferences.dailySummaryTime.hour = NotificationOptimizer.optimalHour(events: notificationEvents)
            }

            DailySummaryScheduler.schedule(
                score: payload.currentScore,
                anomalyCount: anomalyCount,
                topInsights: Array(payload.insights.prefix(3)),
                categoryBreakdown: categoryBreakdown,
                preferences: optimizedPreferences,
                topAnomaly: topAnomaly,
                scoreChangeFromYesterday: payload.scoreChangeFromYesterday,
                streakDays: streakDays
            )

            DailySummaryScheduler.scheduleEvening(
                score: payload.currentScore,
                strainLevel: payload.strainLabel,
                preferences: preferences
            )

            let topTrends: [(metric: String, direction: String, change: Double)] = payload.currentTrends
                .sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
                .prefix(5)
                .map { (metric: $0.key.displayName, direction: $0.value.direction.symbol, change: $0.value.weekOverWeekChange) }

            WeeklySummaryScheduler.schedule(
                score: payload.currentScore,
                scoreChange: scoreChange,
                improvedCount: payload.periodSummary.improvedCount,
                declinedCount: payload.periodSummary.declinedCount,
                topTrends: topTrends,
                preferences: preferences
            )

            if notificationsAuthorized {
                AlertEvaluator.evaluate(
                    anomalies: payload.currentAnomalies,
                    trends: payload.currentTrends,
                    timeSeries: payload.timeSeries,
                    previousTrends: payload.previousTrends,
                    preferences: preferences
                )
            }
        }
    }
}
