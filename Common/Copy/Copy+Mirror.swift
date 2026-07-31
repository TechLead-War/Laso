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

        // MARK: - Settings

        static var settingsTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_title", default: "Daily Mirror") }
        static var settingsPhotos: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_photos", default: "Photos stored") }
        static var settingsSpace: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_space", default: "Space used") }
        static var settingsStreak: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_streak", default: "Longest streak") }
        static var settingsDeleteAll: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_all", default: "Delete entire archive") }
        static var settingsDeleteConfirmTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_confirm_title", default: "Delete all Daily Mirror photos?") }
        static var settingsDeleteAction: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_action", default: "Delete all") }
        static var settingsFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_footer", default: "Deleting is immediate and permanent. Photos are never backed up anywhere.") }
        static var settingsEmpty: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_empty", default: "No photos yet. Capture your first one from the evening check-in.") }
    }
}
