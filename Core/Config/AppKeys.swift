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
        static let disclaimerAcknowledged      = "healthpulse.disclaimerAcknowledged"
        static let paywallDeclined             = "healthpulse.paywallDeclined"
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

        // Rest-day streak credits (Gentler Streak / Duolingo pattern).
        // One credit forgives a single missed day; refilled monthly.
        static let restCreditsRemaining  = "laso.session.rest_credits_remaining"
        static let lastRestCreditGrantDate = "laso.session.last_rest_credit_grant_date"

        // Activation → paywall trigger (hard paywall after aha moment, shown once).
        static let ahaPaywallShown       = "laso.session.aha_paywall_shown"

        // Open-session snapshot persisted on background so the session's
        // session_ended can fire on the next launch even if iOS kills the app.
        static let openSession           = "laso.session.open_session"
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
        static let weeklyScoreEventWeekKey = "healthpulse.weeklyScoreEventWeekKey"
        static let healthFocuses     = "healthpulse.healthFocuses"
        static let progressiveCoachState = "healthpulse.progressiveCoachState"
        static let primaryDevice         = "healthpulse.primaryDevice"
        static let cachedDailyAction     = "healthpulse.cachedDailyAction"
        static let dailyActionDoneDay    = "healthpulse.dailyActionDoneDay"
        static let cachedDeviceSources   = "Laso.DeviceSource.cachedDevices"
        static let deviceSourceScanDate  = "Laso.DeviceSource.lastScanDate"
    }

    // MARK: - Intent Cache (lightweight, non-sensitive. used by Siri shortcuts)

    enum Intent {
        static let score   = "healthpulse.intent.score"
        static let grade   = "healthpulse.intent.grade"
        static let summary = "healthpulse.intent.summary"
    }

    // MARK: - Feedback

    enum Feedback {
        static let entries       = "laso.feedback.entries"
        static let lastNPSDate   = "laso.feedback.last_nps_date"
        static let lastNPSScore  = "laso.feedback.last_nps_score"
    }

    // MARK: - Watch Monitor

    enum Watch {
        static let lastWatchDataTime        = "healthpulse.watchMonitor.lastWatchDataTime"
        static let lowBatteryAlertShown     = "healthpulse.watchMonitor.lowBatteryAlertShown"
        static let lastObserverProcessing   = "healthpulse.watchMonitor.lastObserverProcessing"
        static let lastScheduleRefresh      = "healthpulse.watchMonitor.lastScheduleRefresh"
    }

    // MARK: - UI Dismissals

    enum Dismissals {
        static let siriTip = "laso.dismissed.siri_tip"
    }

    // MARK: - Billing Grace

    enum Billing {
        static let graceStartDate = "laso.billing.grace_start_date"
        static let lastSubscribedDate = "laso.billing.last_subscribed_date"
        /// Set once the trial-expired win-back push has been armed, so it is
        /// scheduled a single time per expiry rather than on every status refresh.
        static let winbackArmed = "laso.billing.winback_armed"

        /// Set once the cancelled-but-active save push has been armed, so it
        /// fires a single time per cancellation rather than on every status
        /// refresh. Cleared when auto-renew is turned back on.
        static let cancelledSaveArmed = "laso.billing.cancelled_save_armed"
    }

    // MARK: - Readiness

    enum Readiness {
        static let cachedScore     = "laso.readiness.cached_score"
        static let cachedTimestamp = "laso.readiness.cached_timestamp"

        // Per-day morning lock. Score and confidence are stamped once each
        // morning when last-night sleep + overnight HRV/RHR vs the 60-day
        // baseline land, then re-used by every refresh that day so the live
        // energy drain has a stable anchor.
        static let morningLockScorePrefix      = "laso.readiness.morning_lock_score."
        static let morningLockDatePrefix       = "laso.readiness.morning_lock_date."
        static let morningLockConfidencePrefix = "laso.readiness.morning_lock_confidence."
    }

    // MARK: - Referral

    enum Referral {
        static let code         = "laso.referral.code"
        static let redeemedCode = "laso.referral.redeemed_code"
        static let freeUntil    = "laso.referral.free_until"
        /// Auth UID the cached referral fields belong to. On mismatch (account
        /// deleted, credential switch) the cache is cleared before use.
        static let ownerUid     = "laso.referral.owner_uid"
    }

    // MARK: - Backup

    enum Backup {
        static let lastBackupDate = "healthpulse.backup.lastBackupDate"
        static let backupEnabled  = "healthpulse.backup.enabled"
    }

    // MARK: - HealthKit Reprompt

    enum HealthKit {
        /// Timestamp when empty data was first detected despite authorization
        static let emptyDataDetectedDate  = "healthpulse.healthkit.emptyDataDetectedDate"
        /// Timestamp when the HealthKit re-prompt banner was last shown
        static let repromptLastShownDate   = "healthpulse.healthkit.repromptLastShown"
    }

    // MARK: - Notifications

    enum Notifications {
        /// Dynamic prefix. append the alert identifier to form the full key,
        /// e.g. `AppKeys.Notifications.alertCooldownPrefix + identifier`.
        static let alertCooldownPrefix = "healthpulse.alertCooldown."
        static let notificationLog     = "healthpulse.notificationLog"
        /// Timestamp when the user first denied notification permission
        static let permissionDeniedDate    = "healthpulse.notifications.deniedDate"
        /// Timestamp when the re-prompt banner was last shown
        static let repromptLastShownDate   = "healthpulse.notifications.repromptLastShown"
        /// Last psychological category used for daily summary (avoids repeats)
        static let lastDailyHookCategory   = "healthpulse.notifications.lastHookCategory"

        // MARK: Fatigue suppression layer

        /// Timestamp of the most recently fired NON-critical notification
        /// (used to approximate "dismissed without open" when an open does
        /// not arrive within the open-window).
        static let lastNonCriticalFiredAt   = "healthpulse.notifications.lastNonCriticalFiredAt"
        /// Identifier of the most recently fired non-critical notification
        /// (used to avoid double-counting the same fire in the dismiss streak).
        static let lastNonCriticalFiredId   = "healthpulse.notifications.lastNonCriticalFiredId"
        /// Timestamp of the user's last app open (reset signal for the streak).
        static let lastAppOpenedAt          = "healthpulse.notifications.lastAppOpenedAt"
        /// Consecutive dismiss-without-open count on non-critical notifications.
        static let dismissWithoutOpenStreak = "healthpulse.notifications.dismissStreak"
        /// Absolute date until which all non-critical notifications are suppressed.
        static let fatigueSuppressionUntil  = "healthpulse.notifications.fatigueSuppressionUntil"
        /// Best (priority, identifier) scheduled today for same-day priority resolution.
        /// Stored as `"<yyyy-MM-dd>|<priority>|<identifier>"`.
        static let sameDayBestCandidate     = "healthpulse.notifications.sameDayBest"

        // MARK: Wind-down rotation
        /// Index of the last wind-down title variant (to rotate across nights)
        static let windDownVariantIndex    = "healthpulse.notifications.windDownVariantIndex"

        // MARK: Re-engagement snapshot (plain-text, non-sensitive)
        /// Last known HRV value in ms (Int, rounded)
        static let lastHRVValue            = "healthpulse.notifications.lastHRV"
        /// Last known HRV trend direction (raw value of TrendDirection)
        static let lastHRVTrend            = "healthpulse.notifications.lastHRVTrend"
        /// Last known recovery score used by re-engagement push
        static let lastRecoveryScore       = "healthpulse.notifications.lastRecoveryScore"
    }

    // MARK: - Engagement Sequence

    enum Engagement {
        static let lastScheduledDay  = "laso.engagement.last_scheduled_day"
        static let sequenceCompleted = "laso.engagement.sequence_completed"
        static let detectedWakeHour  = "laso.engagement.detected_wake_hour"
        static let detectedWakeMinute = "laso.engagement.detected_wake_minute"
        static let wakeTimeSource    = "laso.engagement.wake_time_source"

        // Activation gates (Headspace pattern: 0 to 1 activation moment, not calendar).
        // Day 2 gate: user has opened the app and seen their first real Recovery score.
        static let firstRecoveryScoreSeen  = "laso.engagement.first_recovery_score_seen"
        // Day 5 gate: user has seen a second Recovery score (baseline in progress).
        static let secondRecoveryScoreSeen = "laso.engagement.second_recovery_score_seen"
        // Sequence paused when user goes dark for 48+ hours. Re engagement track takes over.
        static let sequencePaused          = "laso.engagement.sequence_paused"
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

    // MARK: - Onboarding Prediction (cliffhanger payoff + re-permission hook)

    enum Prediction {
        /// JSON-encoded PreRegisteredPrediction captured during onboarding.
        static let registered = "laso.prediction.registered"
        /// JSON-encoded onboarding answers persistOnboardingProfile used to
        /// discard (symptoms / activity / wearable), kept so the "we will
        /// watch for them" promise is true.
        static let capturedAnswers = "laso.prediction.captured_answers"
        /// Set once the answer-ready (cliffhanger payoff) push has fired so it
        /// never repeats.
        static let answerReadyFired = "laso.prediction.answer_ready_fired"
        /// Set once the denied-branch re-permission push has fired.
        static let repermissionFired = "laso.prediction.repermission_fired"
        /// Set once the first ever morning check-in completes, so the
        /// first_checkin_done value-moment event fires exactly once.
        static let firstCheckInLogged = "laso.prediction.first_checkin_logged"
        /// Set once the re-permission conversion event has fired, so a user who
        /// grants Health access after the re-permission push is counted once.
        static let repermissionConverted = "laso.prediction.repermission_converted"
    }

    // MARK: - Circadian Health

    enum Circadian {
        static let lastScore      = "laso.circadian.last_score"
        static let lastComputeDate = "laso.circadian.last_compute_date"
    }
}
