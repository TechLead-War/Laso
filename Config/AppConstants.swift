import Foundation

/// Shared constants used across multiple modules.
/// Module-specific constants that are only used within a single file should stay local.
enum AppConstants {

    // MARK: - Notification Identifiers

    enum NotificationID {
        static let dailySummary = "healthpulse.dailySummary"
        static let eveningSummary = "healthpulse.eveningSummary"
        static let weeklySummary = "healthpulse.weeklySummary"
        static let reengagement = "healthpulse.reengagement.3day"
        static let watchNotWornScheduled = "healthpulse.watch.notWorn.scheduled"
        static let watchNotWorn = "healthpulse.watch.notWorn"
        static let watchLowBattery = "healthpulse.watch.lowBattery"

        // Prefix-based identifiers (appended with metric/level info)
        static let alertPrefix = "healthpulse.alert."
        static let spikePrefix = "healthpulse.spike."
        static let triagePrefix = "healthpulse.triage."
        static let reversalPrefix = "healthpulse.reversal."
        static let celebrationPrefix = "healthpulse.celebration."
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

    // MARK: - Background Tasks

    enum BackgroundTask {
        static let readinessRefresh = "com.lasohealth.background-refresh"
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
