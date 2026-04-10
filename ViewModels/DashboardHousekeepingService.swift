import Foundation

@MainActor
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
        let improvingDays: Int
        let periodSummary: DashboardViewModel.PeriodSummary
        let intelligenceBriefing: [IntelligenceCard]
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
        analytics: any AnalyticsTrackingService,
        sessionTracker: any SessionTrackingService
    ) {
        self.persistenceManager = persistenceManager
        self.cloudBackupManager = cloudBackupManager
        self.notificationManager = notificationManager
        self.analytics = analytics
        self.sessionTracker = sessionTracker
    }

    func perform(store: HealthDataStore, payload: Payload) async {
        await backupAndPruneData(store: store, payload: payload)

        trackAnalyticsForRefresh(payload: payload)

        let preferences = persistenceManager.loadPreferences()
        let notificationsAuthorized = await resolveNotificationAuthorization(preferences: preferences)

        let scoreChange = recordAndTrackWeeklyScore(payload: payload)

        trackValueDelivered(payload: payload, scoreChange: scoreChange)

        await scheduleNotifications(
            payload: payload,
            preferences: preferences,
            notificationsAuthorized: notificationsAuthorized,
            scoreChange: scoreChange
        )
    }

    // MARK: - Housekeeping Steps

    private func backupAndPruneData(store: HealthDataStore, payload: Payload) async {
        await cloudBackupManager.backupIfNeeded(store: store, persistence: persistenceManager)

        // HealthDataStore is @MainActor. batch SwiftData operations on main actor
        await MainActor.run {
            RecommendationEvaluator.evaluatePending(store: store, timeSeries: payload.timeSeries)
            store.pruneOldRecommendations()
            store.pruneOldNotificationEvents()
        }
    }

    private func trackAnalyticsForRefresh(payload: Payload) {
        analytics.trackAnalysisCompleted(
            score: payload.currentScore,
            insightsCount: payload.insights.count,
            anomaliesCount: payload.currentAnomalies.count,
            risksCount: payload.healthRisksCount,
            correlationsCount: payload.correlationsCount,
            illnessWarningsCount: payload.illnessWarningsCount,
            metricsAnalyzed: payload.metricsCount
        )
    }

    private func resolveNotificationAuthorization(preferences: NotificationPreferences) async -> Bool {
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
        // Check current authorization status without prompting. Permission is
        // requested during onboarding so we should not show a random dialog here.
        return notificationsEnabled
            ? await notificationManager.isCurrentlyAuthorized()
            : false
    }

    private func recordAndTrackWeeklyScore(payload: Payload) -> Int {
        let previousScore = persistenceManager.loadPreviousWeekScore()
        let scoreChange = previousScore.map { payload.currentScore - $0 } ?? 0
        persistenceManager.recordWeeklyScore(payload.currentScore)

        analytics.trackWeeklyScoreChange(
            newScore: payload.currentScore,
            previousScore: previousScore,
            delta: scoreChange
        )

        // Prompt for App Store review after meaningful score improvement
        if scoreChange >= 3 {
            AppStoreReviewManager.shared.requestReviewIfEligible(trigger: "score_improved")
        }

        return scoreChange
    }

    private func trackValueDelivered(payload: Payload, scoreChange: Int) {
        analytics.trackValueDelivered(
            newInsightsCount: payload.insights.count,
            scoreChanged: scoreChange != 0,
            newAnomalies: payload.currentAnomalies.filter { $0.severity >= .warning }.count,
            newCorrelations: payload.correlationsCount
        )
    }

    private func scheduleNotifications(
        payload: Payload,
        preferences: NotificationPreferences,
        notificationsAuthorized: Bool,
        scoreChange: Int
    ) async {
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
            DailySummaryScheduler.schedule(
                score: payload.currentScore,
                anomalyCount: anomalyCount,
                topInsights: Array(payload.insights.prefix(3)),
                categoryBreakdown: categoryBreakdown,
                preferences: preferences,
                topAnomaly: topAnomaly,
                scoreChangeFromYesterday: payload.scoreChangeFromYesterday,
                streakDays: streakDays,
                improvingDays: payload.improvingDays
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

                IntelligenceAlertEvaluator.evaluate(
                    cards: payload.intelligenceBriefing,
                    preferences: preferences
                )
            }
        }
    }
}
