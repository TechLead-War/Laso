import Foundation

/// Single source of truth for all UserDefaults / AppStorage keys.
/// Every persistence access in the app MUST use these constants.
enum AppKeys {

    // MARK: - App State

    enum App {
        static let onboardingCompleted = "healthpulse.onboardingCompleted"
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

        // Stickiness
        static let weeklyActiveDays      = "laso.session.weekly_active_days"
        static let weeklyActiveDaysData  = "laso.session.weekly_active_days_data"
        static let organicSessions       = "laso.session.organic_sessions"
        static let notifSessions         = "laso.session.notif_sessions"
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
        static let progressiveCoachState = "healthpulse.progressiveCoachState"
        static let primaryDevice         = "healthpulse.primaryDevice"
        static let cachedDailyAction     = "healthpulse.cachedDailyAction"
        static let cachedDeviceSources   = "Laso.DeviceSource.cachedDevices"
        static let deviceSourceScanDate  = "Laso.DeviceSource.lastScanDate"
    }

    // MARK: - Intent Cache (lightweight, non-sensitive — used by Siri shortcuts)

    enum Intent {
        static let score   = "healthpulse.intent.score"
        static let grade   = "healthpulse.intent.grade"
        static let summary = "healthpulse.intent.summary"
    }

    // MARK: - Feedback

    enum Feedback {
        static let lastPromptDate    = "laso.feedback.last_prompt_date"
        static let submitted         = "laso.feedback.submitted"
        static let lastSubmittedDate = "laso.feedback.last_submitted_date"
        static let cooldownDays      = "laso.feedback.cooldown_days"
        static let entries           = "laso.feedback.entries"
        static let lastNPSDate       = "laso.feedback.last_nps_date"
        static let lastNPSScore      = "laso.feedback.last_nps_score"
    }

    // MARK: - Watch Monitor

    enum Watch {
        static let lastWatchDataTime        = "healthpulse.watchMonitor.lastWatchDataTime"
        static let lastNotWornNotification  = "healthpulse.watchMonitor.lastNotWornNotification"
        static let lowBatteryAlertShown     = "healthpulse.watchMonitor.lowBatteryAlertShown"
    }

    // MARK: - UI Dismissals

    enum Dismissals {
        static let siriTip = "laso.dismissed.siri_tip"
    }

    // MARK: - Billing Grace

    enum Billing {
        static let graceStartDate = "laso.billing.grace_start_date"
        static let lastSubscribedDate = "laso.billing.last_subscribed_date"
    }

    // MARK: - Readiness

    enum Readiness {
        static let cachedScore     = "laso.readiness.cached_score"
        static let cachedTimestamp = "laso.readiness.cached_timestamp"
    }

    // MARK: - Referral

    enum Referral {
        static let code         = "laso.referral.code"
        static let redeemedCode = "laso.referral.redeemed_code"
        static let freeUntil    = "laso.referral.free_until"
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
        /// Timestamp when the user first denied notification permission
        static let permissionDeniedDate    = "healthpulse.notifications.deniedDate"
        /// Timestamp when the re-prompt banner was last shown
        static let repromptLastShownDate   = "healthpulse.notifications.repromptLastShown"
        /// Last psychological category used for daily summary (avoids repeats)
        static let lastDailyHookCategory   = "healthpulse.notifications.lastHookCategory"
    }

    // MARK: - Engagement Sequence

    enum Engagement {
        static let lastScheduledDay  = "laso.engagement.last_scheduled_day"
        static let sequenceCompleted = "laso.engagement.sequence_completed"
        static let detectedWakeHour  = "laso.engagement.detected_wake_hour"
        static let detectedWakeMinute = "laso.engagement.detected_wake_minute"
        static let wakeTimeSource    = "laso.engagement.wake_time_source"
    }

    // MARK: - User Profile

    enum Profile {
        static let name             = "laso.profile.name"
        static let email            = "laso.profile.email"
        static let gender           = "laso.profile.gender"
        static let dateOfBirth      = "laso.profile.date_of_birth"
        static let profileCompleted = "laso.profile.completed"
        static let deviceId         = "laso.profile.device_id"
    }

    // MARK: - Strain

    enum Strain {
        static let lastStrainDate = "laso.strain.last_date"
        static let todayStrain    = "laso.strain.today"
    }

    // MARK: - Sleep Coach

    enum SleepCoach {
        static let targetWakeTime   = "laso.sleep_coach.target_wake_time"
        static let performanceLevel = "laso.sleep_coach.performance_level"
        static let sleepDebt        = "laso.sleep_coach.debt"
    }

    // MARK: - Stress

    enum Stress {
        static let lastStressUpdate = "laso.stress.last_update"
    }

    // MARK: - Weekly Plan

    enum Plan {
        static let activeGoal    = "laso.plan.active_goal"
        static let planStartDate = "laso.plan.start_date"
        static let planData      = "laso.plan.data"
    }

    // MARK: - Gamification

    enum Gamification {
        static let unlockedAchievements   = "laso.gamification.unlocked"
        static let longestActivityStreak  = "laso.gamification.longest_activity_streak"
        static let longestSleepStreak     = "laso.gamification.longest_sleep_streak"
        static let longestRecoveryStreak  = "laso.gamification.longest_recovery_streak"
        static let longestMasterStreak    = "laso.gamification.longest_master_streak"
    }

    // MARK: - Cycle Tracking

    enum Cycle {
        static let trackingEnabled   = "laso.cycle.tracking_enabled"
        static let lastCycleComputed = "laso.cycle.last_computed"
    }

    // MARK: - Widget (App Group UserDefaults)

    enum Widget {
        static let readiness    = "laso.widget.readiness"
        static let sleep        = "laso.widget.sleep"
        static let action       = "laso.widget.action"
        static let intelligence = "laso.widget.intelligence"
        static let recoveryDebt = "laso.widget.recoveryDebt"
        static let lastUpdate   = "laso.widget.lastUpdate"
    }

    // MARK: - Data Retention

    enum Retention {
        static let lastPruneDate = "laso.retention.last_prune_date"
    }

    // MARK: - Morning Check-In

    enum CheckIn {
        static let history    = "laso.morning_checkin.history"
        static let lastDate   = "laso.morning_checkin.last_date"
    }

    // MARK: - Activation Sequence

    enum Activation {
        static let state = "laso.activation.state"
    }

    // MARK: - Circadian Health

    enum Circadian {
        static let lastScore      = "laso.circadian.last_score"
        static let lastComputeDate = "laso.circadian.last_compute_date"
    }
}
