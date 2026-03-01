import Foundation

/// Single source of truth for all UserDefaults / AppStorage keys.
/// Every persistence access in the app MUST use these constants.
enum AppKeys {

    // MARK: - App State

    enum App {
        static let onboardingCompleted = "healthpulse.onboardingCompleted"
        static let appTheme            = "healthpulse.appTheme"
        static let hasSeenDiscovery    = "healthpulse.hasSeenDiscovery"
        static let hasSeenScoreGuide   = "healthpulse.hasSeenScoreGuide"
        static let hasSeenRecoveryInfo = "healthpulse.hasSeenRecoveryInfo"
        static let pendingCalibrationHydration = "healthpulse.pendingCalibrationHydration"
    }

    // MARK: - Session & Lifecycle

    enum Session {
        static let lastActiveDate    = "laso.session.last_active_date"
        static let streakDays        = "laso.session.streak_days"
        static let longestStreak     = "laso.session.longest_streak"
        static let totalSessions     = "laso.lifecycle.total_sessions"
        static let milestones        = "laso.lifecycle.milestones"
        static let lastSessionDate   = "laso.lifecycle.last_session_date"
        static let firstValueTimeSec = "laso.lifecycle.first_value_time_sec"

        // Retention & Habit
        static let retentionMilestones   = "laso.session.retention_milestones"
        static let streakMilestones      = "laso.session.streak_milestones"
        static let lifetimeCoreActions   = "laso.session.lifetime_core_actions"

        // Churn / Inactivity
        static let lastInactivityAlert   = "laso.session.last_inactivity_alert"
    }

    // MARK: - Install

    enum Lifecycle {
        /// Unified install date key. Previously duplicated as
        /// "laso.install_date" (SubscriptionManager / FeedbackPromptManager)
        /// and "laso.lifecycle.install_date" (SessionTracker).
        /// All call-sites now use this single key.
        static let installDate = "laso.install_date"
    }

    // MARK: - Persistence (Baselines, Preferences, Scores)

    enum Data {
        static let baselines         = "healthpulse.baselines"
        static let preferences       = "healthpulse.preferences"
        static let lastAnalysis      = "healthpulse.lastAnalysis"
        static let previousWeekScore = "healthpulse.previousWeekScore"
        static let currentScore      = "healthpulse.currentScore"
        static let scoreDate         = "healthpulse.scoreDate"
        static let healthFocuses     = "healthpulse.healthFocuses"
    }

    // MARK: - Feedback

    enum Feedback {
        static let lastPromptDate = "laso.feedback.last_prompt_date"
        static let submitted      = "laso.feedback.submitted"
        static let cooldownDays   = "laso.feedback.cooldown_days"
        static let entries        = "laso.feedback.entries"
        static let lastNPSDate    = "laso.feedback.last_nps_date"
        static let lastNPSScore   = "laso.feedback.last_nps_score"
    }

    // MARK: - Watch Monitor

    enum Watch {
        static let lastWatchDataTime        = "healthpulse.watchMonitor.lastWatchDataTime"
        static let lastNotWornNotification  = "healthpulse.watchMonitor.lastNotWornNotification"
        static let lowBatteryAlertShown     = "healthpulse.watchMonitor.lowBatteryAlertShown"
    }

    // MARK: - Billing Grace

    enum Billing {
        static let graceStartDate = "laso.billing.grace_start_date"
        static let lastSubscribedDate = "laso.billing.last_subscribed_date"
    }

    // MARK: - Backup

    enum Backup {
        static let lastBackupDate = "healthpulse.backup.lastBackupDate"
        static let backupEnabled  = "healthpulse.backup.enabled"
    }

    // MARK: - Notifications

    enum Notifications {
        /// Dynamic prefix — append the alert identifier to form the full key,
        /// e.g. `AppKeys.Notifications.alertCooldownPrefix + identifier`.
        static let alertCooldownPrefix = "healthpulse.alertCooldown."
        static let notificationLog     = "healthpulse.notificationLog"
    }
}
