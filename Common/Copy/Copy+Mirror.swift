import Foundation

extension Copy {
    /// Daily Mirror: the daily selfie ritual. Capture lives in the evening
    /// journal check-in, photos stay on device only.
    enum Mirror {

        // MARK: - Journal entry card

        static var journalCardCTA: String { RemoteConfigManager.shared.copyString("copy_mirror_journal_cta", default: "Capture today's you") }
        static var journalCardDone: String { RemoteConfigManager.shared.copyString("copy_mirror_journal_done", default: "Captured today") }
        /// `%d` is the current capture streak in days.
        static func streakDays(_ days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_streak_days", default: "%d day streak"), days)
        }

        // MARK: - First run explainer

        static var explainerTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_title", default: "Your face stays on your phone") }
        static var explainerBody: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_body", default: "Daily Mirror photos are stored only on this device, protected by your phone's passcode encryption.") }
        static var explainerPoint1: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_point1", default: "Never uploaded. No cloud, no server, no backup we can see.") }
        static var explainerPoint2: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_point2", default: "Not in your camera roll. Photos live inside Laso only.") }
        static var explainerPoint3: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_point3", default: "One trade off. If you lose this phone, the archive goes with it.") }
        static var explainerStart: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_start", default: "Allow camera and start") }
        static var explainerLater: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_later", default: "Maybe later") }

        // MARK: - Capture and confirm

        static var filterStamp: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_stamp", default: "Today stamp") }
        static var filterTint: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_tint", default: "Score tint") }
        static var filterStreak: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_streak", default: "Streak") }
        static var filterClean: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_clean", default: "Clean") }
        static var confirmSave: String { RemoteConfigManager.shared.copyString("copy_mirror_confirm_save", default: "Save photo") }
        static var confirmRetake: String { RemoteConfigManager.shared.copyString("copy_mirror_confirm_retake", default: "Retake") }
        static var saveFailed: String { RemoteConfigManager.shared.copyString("copy_mirror_save_failed", default: "Could not save your photo. Please try again.") }
        /// `%d` is the readiness score baked onto the photo stamp.
        static func recoveryScore(_ score: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_recovery_score", default: "Recovery %d"), score)
        }

        // MARK: - Replay

        static var replayTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_replay_title", default: "Your last 7 days") }
        static var replayDone: String { RemoteConfigManager.shared.copyString("copy_mirror_replay_done", default: "Done") }

        // MARK: - Weekly review strip

        static var weeklyStripTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_weekly_strip_title", default: "Your week in faces") }
        /// `%1$d` days captured, `%2$d` days in the week.
        static func weeklyStripCount(_ captured: Int, _ total: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_weekly_strip_count", default: "%1$d of %2$d days"), captured, total)
        }

        // MARK: - Share

        static var shareChip: String { RemoteConfigManager.shared.copyString("copy_mirror_share_chip", default: "Progress") }
        /// `%d` is the number of days between the two photos.
        static func shareDaysApart(_ days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_share_days_apart", default: "%d days apart"), days)
        }
        /// `%d` is the score gain between the two photos.
        static func sharePointsUp(_ points: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_share_points_up", default: "+%d recovery"), points)
        }

        // MARK: - Mirror Moment (daily capture prompt)

        static var momentEyebrow: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_eyebrow", default: "Daily Mirror") }
        /// `%d` is the current capture streak in days.
        static func momentEyebrowDay(_ day: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_moment_eyebrow_day", default: "Daily Mirror. Day %d"), day)
        }
        /// Rotating daily titles. Repeating yesterday's line measurably wears
        /// out (Duolingo KDD 2020), so the manager cycles through all five.
        /// All are state framed, never appearance framed.
        static var momentTitles: [String] {
            [
                RemoteConfigManager.shared.copyString("copy_mirror_moment_title_1", default: "Ten seconds keeps it going."),
                RemoteConfigManager.shared.copyString("copy_mirror_moment_title_2", default: "Put today on the record."),
                RemoteConfigManager.shared.copyString("copy_mirror_moment_title_3", default: "Capture how you showed up today."),
                RemoteConfigManager.shared.copyString("copy_mirror_moment_title_4", default: "Future you will want this day."),
                RemoteConfigManager.shared.copyString("copy_mirror_moment_title_5", default: "One capture. That is the whole job.")
            ]
        }
        static var momentTeaseLocked: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_tease_locked", default: "Yesterday's you unlocks after today's capture.") }
        /// `%d` is how many captures remain until the 7 day replay.
        static func momentTeaseProgress(_ remaining: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_moment_tease_progress", default: "%d more and your week plays back."), remaining)
        }
        /// `%d` is captures this month, shown after a streak break instead of a
        /// zero. Highlighting a broken streak reduces persistence (JCR 2023).
        static func momentMetricMonth(_ count: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_moment_metric_month", default: "%d captures this month. Start a new run today."), count)
        }
        static var momentCaptureCTA: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_capture_cta", default: "Capture today's you") }
        static var momentNotToday: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_not_today", default: "Not today") }

        // First run: a one tap commitment, not a feature tour. An if-then plan
        // carries d = 0.65 on goal attainment (Gollwitzer and Sheeran 2006).
        static var momentCommitTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_commit_title", default: "When I open Laso in the morning, I capture my mirror.") }
        static var momentCommitLine: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_commit_line", default: "Ten seconds a day. On day 7 your week plays back.") }
        static var momentCommitCTA: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_commit_cta", default: "I'm in for 7 days") }
        static var momentCommitLater: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_commit_later", default: "Maybe later") }
        static var momentPrivacyLine: String { RemoteConfigManager.shared.copyString("copy_mirror_moment_privacy_line", default: "Photos never leave this phone.") }

        // MARK: - Settings: prompt and reminder

        static var settingsPromptToggle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_prompt_toggle", default: "Morning capture prompt") }
        static var settingsPromptFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_prompt_footer", default: "One quiet invite on your first open of the day. Turning it off is always respected.") }
        static var settingsReminderToggle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_reminder_toggle", default: "Reminder notification") }
        static var settingsReminderStart: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_reminder_start", default: "Earliest") }
        static var settingsReminderEnd: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_reminder_end", default: "Latest") }
        static var settingsReminderFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_reminder_footer", default: "Off by default. Fires once a day at a different time inside your window.") }
        static var settingsReminderDenied: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_reminder_denied", default: "Notifications are turned off for Laso. Allow them in iOS Settings first.") }

        // MARK: - Settings

        static var settingsTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_title", default: "Daily Mirror") }
        static var settingsPhotos: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_photos", default: "Memories captured") }
        static var settingsSince: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_since", default: "Your story started") }
        static var settingsSpace: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_space", default: "Space your memories take") }
        static var settingsStreak: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_streak", default: "Longest streak") }
        static var settingsDeleteAll: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_all", default: "Delete entire archive") }
        static var settingsDeleteConfirmTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_confirm_title", default: "Delete all Daily Mirror photos?") }
        static var settingsDeleteAction: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_action", default: "Delete all") }
        static var settingsFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_footer", default: "Deleting is immediate and permanent. Photos are never backed up anywhere.") }
        static var settingsEmpty: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_empty", default: "No photos yet. Capture your first one from the evening check-in.") }
    }
}
