import Foundation

/// Shared constants used across multiple modules.
/// Module-specific constants that are only used within a single file should stay local.
enum AppConstants {

    // MARK: - Notification Identifiers

    enum NotificationID {
        static let dailySummary = "healthpulse.dailySummary"
        static let eveningSummary = "healthpulse.eveningSummary"
        static let weeklySummary = "healthpulse.weeklySummary"
        static let windDown = "healthpulse.windDown"
        static let reengagement = "healthpulse.reengagement.3day"
        static let watchNotWornScheduled = "healthpulse.watch.notWorn.scheduled"
        static let watchLowBattery = "healthpulse.watch.lowBattery"

        // Onboarding abandonment (Journey 1): three reminders after the user
        // drops out mid-onboarding, cancelled the moment onboarding completes.
        static let abandonment2h = "healthpulse.abandonment.2h"
        static let abandonment24h = "healthpulse.abandonment.24h"
        static let abandonment72h = "healthpulse.abandonment.72h"

        // Trial lifecycle (Journey 2/3).
        static let trialGettingStarted = "healthpulse.trial.gettingStarted"
        static let trialInsightNudge = "healthpulse.trial.insightNudge"
        static let trialRenewalReminder = "healthpulse.trial.renewalReminder"
        static let trialWinback = "healthpulse.trial.winback"

        // Answer-ready (Journey 4): the cliffhanger payoff push.
        static let answerReady = "healthpulse.answerReady"

        // Denied-branch re-permission (Journey 5): one push after 3 check-ins.
        static let repermission = "healthpulse.repermission"

        // Non-trial activation welcome (subscription lifecycle): one push to a
        // user who activates a paid plan WITHOUT a free trial.
        static let nonTrialWelcome = "healthpulse.subscription.nonTrialWelcome"

        // Cancelled-but-still-active save: one push when auto-renew is turned
        // off while the paid period is still running, before it lapses.
        static let cancelledSave = "healthpulse.subscription.cancelledSave"

        // Prefix-based identifiers (appended with metric/level info)
        static let alertPrefix = "healthpulse.alert."
        static let spikePrefix = "healthpulse.spike."
        static let triagePrefix = "healthpulse.triage."
        static let reversalPrefix = "healthpulse.reversal."
        static let celebrationPrefix = "healthpulse.celebration."
        static let engagementPrefix = "healthpulse.engagement."
        static let intelligencePrefix = "healthpulse.intelligence."

        /// Every onboarding-abandonment identifier, for one-shot cancellation
        /// when onboarding completes.
        static let abandonmentAll = [abandonment2h, abandonment24h, abandonment72h]

        /// Every trial-lifecycle identifier, cancelled on purchase.
        static let trialAll = [trialGettingStarted, trialInsightNudge, trialRenewalReminder, trialWinback]
    }

    // MARK: - Notification Categories

    /// UNNotificationCategory identifiers. Registered in AppDelegate (D3) with
    /// the `.customDismissAction` option so a swipe-dismiss fires `didReceive`
    /// and is tracked as a dismissal. Set as `content.categoryIdentifier` on
    /// outgoing notifications. Non-UI identifier, no Copy key.
    enum NotificationCategory {
        static let standard = "healthpulse.category.standard"
    }

    // MARK: - Notification Names (NotificationCenter)

    enum NotificationName {
        static let navigateToExplore = Notification.Name("healthPulseNavigateToExplore")
    }

    // MARK: - Timing Intervals

    enum Timing {
        /// Minimum interval between automatic backups (6 hours)
        static let backupThrottle: TimeInterval = 6 * 60 * 60

        /// Reengagement notification delay (3 days)
        static let reengagementDelay: TimeInterval = 3 * 24 * 60 * 60

        /// Onboarding-abandonment reminder offsets, measured from the moment the
        /// user dropped out (Journey 1). Spaced so the three reminders never land
        /// inside one frequency-cap day.
        static let abandonment2h: TimeInterval = 2 * 60 * 60
        static let abandonment24h: TimeInterval = 24 * 60 * 60
        static let abandonment72h: TimeInterval = 72 * 60 * 60

        /// Delay after a no-trial paid activation before the welcome push.
        static let nonTrialWelcomeDelay: TimeInterval = 2 * 60 * 60

        /// Lead time before expiry for the cancelled-subscriber save push.
        static let cancelledSaveLeadTime: TimeInterval = 24 * 60 * 60

        /// Fallback delay when the save push is armed with under a day left.
        static let cancelledSaveMinDelay: TimeInterval = 60 * 60

        /// ML model retrain interval (30 days)
        static let mlRetrainInterval: TimeInterval = 30 * 24 * 60 * 60

        /// Analysis engine heavy computation TTL (1 hour)
        static let heavyAnalysisTTL: TimeInterval = 3600

        /// DashboardViewModel minimum analysis interval (5 min)
        static let analysisMinInterval: TimeInterval = 300

        /// DashboardViewModel sync retry interval (10 min)
        static let syncRetryMinInterval: TimeInterval = 600

        /// Connectivity recovery minimum interval (15 min)
        static let connectivityRecoveryMinInterval: TimeInterval = 900

        /// Preferences cache duration (5 min)
        static let preferencesCacheDuration: TimeInterval = 300
    }

    // MARK: - Notification Fatigue Suppression

    enum NotificationFatigue {
        /// Window within which an app open is considered a "response" to a
        /// fired notification. Opens beyond this window count as a dismiss.
        static let openResponseWindow: TimeInterval = 2 * 60 * 60

        /// Consecutive dismiss-without-open events on non-critical
        /// notifications that trigger a suppression window.
        static let dismissStreakThreshold: Int = 3

        /// How long to suppress non-critical notifications after the
        /// dismiss streak threshold is reached.
        static let suppressionDuration: TimeInterval = 48 * 60 * 60
    }

    // MARK: - Background Tasks

    enum BackgroundTask {
        static let readinessRefresh = "com.lasohealth.fit.background-refresh"
        static let earliestBeginInterval: TimeInterval = 30 * 60
        static let completionDelay: TimeInterval = 5
    }

    // MARK: - Data Requirements (Minimum days for ML/Analysis)

    enum DataRequirements {
        static let featureEngine = 7
        static let circadianAnalyzer = 14
        static let illnessEarlyWarning = 14
        static let adherenceTracker = 15
        static let timeSeriesForecaster = 21
        static let predictiveScorer = 30
        static let correlationDiscovery = 30
        static let discoveryEngine = 30
        static let crossMetricHistory = 30
        static let healthStateClassifier = 60
        static let adaptiveAnomalyDetector = 60
        static let patternMiner = 60
    }

    // MARK: - Anomaly Detection Thresholds

    enum AnomalyThresholds {
        static let warningZScore = 1.5
        static let criticalZScore = 2.5

        // Adaptive anomaly detector
        static let globalScoreThreshold = 0.65
        static let contextualZScoreThreshold = 2.0
    }

    // MARK: - Score Impact Deductions

    enum ScoreImpact {
        static let anomalyWarning = -20
        static let anomalyCritical = -40
        static let decliningTrend = -10
        static let strongDecliningTrend = -20
        static let outsideNormalRange = -15
        static let improvingTrendBonus = 5
    }

    // MARK: - Subscription

    enum Subscription {
        static let billingGraceDays = 30
        static let fallbackTrialDays = 7
    }

    // MARK: - Schema & Migration

    enum Schema {
        static let versionKey = "healthdata.schema.version"
    }

    // MARK: - Export

    enum Export {
        static let reportFilePrefix = "Laso_Report_"
    }

    // MARK: - Weekly Review

    enum WeeklyReview {
        static let minimumDailyStepTarget = 4000
        static let maximumDailyStepTarget = 15000
        static let weeklyStepIncrement = 500
    }
}
