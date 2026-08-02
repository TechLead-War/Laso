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
        /// One-off reminder the user sets from the Next Up action card.
        static let actionReminder = "healthpulse.actionReminder"
        /// Opt-in Daily Mirror reminder; one id per scheduled day (prefix + 0...6).
        static let mirrorReminderPrefix = "healthpulse.mirror.reminder."
        static let reengagement = "healthpulse.reengagement.3day"
        static let watchNotWornScheduled = "healthpulse.watch.notWorn.scheduled"

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
        // 26h, not 24h: at 24h the second reminder is only 22h after the first,
        // so an evening drop-out whose 2h reminder is pushed out of quiet hours
        // collides with it on the same fire day and loses the same-day priority
        // contest. 26h puts both at the same wall-clock hour, one day apart.
        static let abandonment24h: TimeInterval = 26 * 60 * 60
        static let abandonment72h: TimeInterval = 72 * 60 * 60

        /// Delay after a no-trial paid activation before the welcome push.
        static let nonTrialWelcomeDelay: TimeInterval = 2 * 60 * 60

        /// Lead time before expiry for the cancelled-subscriber save push.
        static let cancelledSaveLeadTime: TimeInterval = 24 * 60 * 60

        /// Fallback delay when the save push is armed with under a day left.
        static let cancelledSaveMinDelay: TimeInterval = 60 * 60
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

    // MARK: - Schema & Migration

    enum Schema {
        static let versionKey = "healthdata.schema.version"
    }
}
