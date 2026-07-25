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
        /// Target bedtime for tonight, from `SleepNeedCalculator.currentNeed?.recommendedBedtime`.
        /// `nil` when we lack data to predict one. Never fake this.
        let recommendedBedtime: Date?
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
            preferences.windDownEnabled ||
            preferences.weeklySummaryEnabled ||
            preferences.criticalAlertsEnabled ||
            preferences.warningAlertsEnabled ||
            preferences.heartRateSpikeAlertsEnabled ||
            preferences.trendReversalAlertsEnabled ||
            preferences.improvementAlertsEnabled ||
            preferences.watchNotWornReminderEnabled
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

        // weekly_score_change is a once-per-week signal, but `perform` runs on every
        // dashboard refresh. Gate the emit on the calendar week-of-year so it fires at
        // most once per week instead of on every refresh. Uses the same week-of-year
        // granularity that `recordWeeklyScore` uses to roll the previous-week score.
        let defaults = UserDefaults.standard
        let now = Date()
        let weekKey = "\(Date.cal.component(.yearForWeekOfYear, from: now))-\(Date.cal.component(.weekOfYear, from: now))"
        if defaults.string(forKey: AppKeys.Data.weeklyScoreEventWeekKey) != weekKey {
            defaults.set(weekKey, forKey: AppKeys.Data.weeklyScoreEventWeekKey)
            analytics.trackWeeklyScoreChange(
                newScore: payload.currentScore,
                delta: scoreChange
            )
        }

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

            // Persist a lightweight last-known snapshot used by the re-engagement push
            // when the user lapses (3+ days inactive). Safe to write non-sensitive
            // Int values to plain UserDefaults.
            let hrvSnapshot = Self.hrvSnapshot(
                timeSeries: payload.timeSeries,
                trends: payload.currentTrends
            )
            let defaults = UserDefaults.standard
            defaults.set(payload.currentScore, forKey: AppKeys.Notifications.lastRecoveryScore)
            if let hrvSnapshot {
                defaults.set(hrvSnapshot.valueMs, forKey: AppKeys.Notifications.lastHRVValue)
                defaults.set(hrvSnapshot.trend.rawValue, forKey: AppKeys.Notifications.lastHRVTrend)
            }

            // Evening wind-down (~60 min before predicted bedtime). Skips if no bedtime.
            WindDownScheduler.schedule(
                recommendedBedtime: payload.recommendedBedtime,
                lastHRV: hrvSnapshot?.valueMs,
                hrvIsLow: hrvSnapshot?.isLow ?? false,
                preferences: preferences
            )

            // Wind-Down Live Activity: windowed countdown from (bedtime - 60 min)
            // through a short grace period past bedtime. Idempotent per refresh.
            WindDownLiveActivityManager.shared.syncWithDashboard(
                recommendedBedtime: payload.recommendedBedtime,
                hrvMs: hrvSnapshot?.valueMs,
                hrvIsLow: hrvSnapshot?.isLow ?? false
            )

            let topTrends: [(metric: String, direction: String, change: Double)] = payload.currentTrends
                .sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
                .prefix(5)
                .map { (metric: $0.key.displayName, direction: TrendDirection.arrowSymbol(forChange: $0.value.weekOverWeekChange), change: $0.value.weekOverWeekChange) }

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

    // MARK: - HRV Snapshot

    /// Small helper struct for capturing the last HRV reading and its trend direction.
    /// Consumed by `WindDownScheduler` (to personalise the hint) and by the lapsed-user
    /// re-engagement push (for the data-grounded body).
    private struct HRVSnapshot {
        let valueMs: Int
        let trend: TrendDirection
        /// `true` if the last HRV is notably below the recent 30-day average.
        let isLow: Bool
    }

    /// Derive the most recent HRV reading + trend direction from the refresh payload.
    /// Returns `nil` when HRV data or trend info is not available.
    private static func hrvSnapshot(
        timeSeries: [HealthMetric: MetricTimeSeries],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> HRVSnapshot? {
        guard let series = timeSeries[.heartRateVariability],
              let latest = series.samples.last,
              latest.value.isFinite,
              latest.value > 0 else {
            return nil
        }

        let direction = trends[.heartRateVariability]?.direction ?? .stable
        let valueMs = Int(latest.value.rounded())

        // "Low" heuristic: last value is 10%+ below the 30-day average, if available.
        let isLow: Bool
        if let baseline = trends[.heartRateVariability]?.movingAverage30d, baseline > 0 {
            isLow = (latest.value / baseline) <= 0.9
        } else {
            isLow = false
        }

        return HRVSnapshot(valueMs: valueMs, trend: direction, isLow: isLow)
    }
}
