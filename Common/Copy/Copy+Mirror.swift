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
        static var explainerPoint3: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_point3", default: "One trade off. Delete Laso and the archive goes too, unless you turn on saving to Photos in settings.") }
        static var explainerStart: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_start", default: "Allow camera and start") }
        static var explainerLater: String { RemoteConfigManager.shared.copyString("copy_mirror_explainer_later", default: "Maybe later") }

        // MARK: - Capture and confirm

        // Data overlays baked into the photo.
        static var filterStamp: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_stamp", default: "Today stamp") }
        static var filterPulse: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_pulse", default: "Heartbeat") }
        static var filterStreak: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_streak", default: "Streak") }
        static var filterRing: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_ring", default: "Score ring") }
        static var filterBigScore: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_big_score", default: "Big score") }
        /// Sits under the large numeral on the big score overlay.
        static var filterBigScoreUnit: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_big_score_unit", default: "RECOVERY") }
        static var filterGlow: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_glow", default: "Glow") }
        static var filterJourney: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_journey", default: "Journey") }
        /// `%d` is the capture streak shown large on the journey overlay.
        static func filterJourneyDay(_ day: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_filter_journey_day", default: "Day %d"), day)
        }
        static var filterBanner: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_banner", default: "Diary strip") }
        static var filterDateOnly: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_date_only", default: "Date only") }
        static var filterClean: String { RemoteConfigManager.shared.copyString("copy_mirror_filter_clean", default: "Clean") }

        static var confirmSave: String { RemoteConfigManager.shared.copyString("copy_mirror_confirm_save", default: "Save photo") }
        static var confirmRetake: String { RemoteConfigManager.shared.copyString("copy_mirror_confirm_retake", default: "Retake") }
        static var saveFailed: String { RemoteConfigManager.shared.copyString("copy_mirror_save_failed", default: "Could not save your photo. Please try again.") }
        static var photosSaveFailed: String { RemoteConfigManager.shared.copyString("copy_mirror_photos_save_failed", default: "Your photo is saved in Laso, but the copy to your Photos app did not go through.") }
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
        static var settingsGallery: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_gallery", default: "See all photos") }
        static var settingsPhotosToggle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_photos_toggle", default: "Also save to Photos") }
        static var settingsPhotosFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_photos_footer", default: "Off by default. Turn it on and every new capture is also copied to your Photos app, so your archive survives deleting Laso. Laso can add photos there but never read them.") }
        static var settingsExportAll: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_export_all", default: "Save every photo to Photos now") }
        /// `%d` is how many photos were copied into the Photos app.
        static func settingsExportDone(_ count: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_settings_export_done", default: "%d photos saved to your Photos app."), count)
        }
        static var settingsPhotosDenied: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_photos_denied", default: "Laso cannot add to your Photos app. Allow it in iOS Settings first.") }
        static var galleryTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_gallery_title", default: "Your photos") }
        static var galleryDelete: String { RemoteConfigManager.shared.copyString("copy_mirror_gallery_delete", default: "Delete photo") }
        static var galleryDeleteConfirm: String { RemoteConfigManager.shared.copyString("copy_mirror_gallery_delete_confirm", default: "Delete this photo?") }
        static var settingsDeleteAll: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_all", default: "Delete entire archive") }
        static var settingsDeleteConfirmTitle: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_confirm_title", default: "Delete all Daily Mirror photos?") }
        static var settingsDeleteAction: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_delete_action", default: "Delete all") }
        static var settingsFooter: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_footer", default: "Deleting is immediate and permanent. Copies you already saved to your Photos app stay there.") }
        static var settingsEmpty: String { RemoteConfigManager.shared.copyString("copy_mirror_settings_empty", default: "No photos yet. Capture your first one from the evening check-in.") }

        // MARK: - Templates: names and groups

        static func templateName(_ template: MirrorTemplate) -> String {
            switch template {
            case .fieldNotes:   return RemoteConfigManager.shared.copyString("copy_mirror_tpl_field_notes", default: "Field Notes")
            case .number:       return RemoteConfigManager.shared.copyString("copy_mirror_tpl_number", default: "The Number")
            case .oneWord:      return RemoteConfigManager.shared.copyString("copy_mirror_tpl_one_word", default: "One Word")
            case .clean:        return RemoteConfigManager.shared.copyString("copy_mirror_tpl_clean", default: "Clean")
            case .behindYou:    return RemoteConfigManager.shared.copyString("copy_mirror_tpl_behind_you", default: "Behind You")
            case .horizon:      return RemoteConfigManager.shared.copyString("copy_mirror_tpl_horizon", default: "Horizon")
            case .night:        return RemoteConfigManager.shared.copyString("copy_mirror_tpl_night", default: "The Night")
            case .bodyAge:      return RemoteConfigManager.shared.copyString("copy_mirror_tpl_body_age", default: "Body Age")
            case .slip:         return RemoteConfigManager.shared.copyString("copy_mirror_tpl_slip", default: "The Slip")
            case .chin:         return RemoteConfigManager.shared.copyString("copy_mirror_tpl_chin", default: "Instant Film")
            case .newsprint:    return RemoteConfigManager.shared.copyString("copy_mirror_tpl_newsprint", default: "Newsprint")
            case .nineties:     return RemoteConfigManager.shared.copyString("copy_mirror_tpl_nineties", default: "Nineteen Ninety Eight")
            case .thisWeek:     return RemoteConfigManager.shared.copyString("copy_mirror_tpl_this_week", default: "This Week")
            case .thenAndNow:   return RemoteConfigManager.shared.copyString("copy_mirror_tpl_then_and_now", default: "Then and Now")
            case .contactSheet: return RemoteConfigManager.shared.copyString("copy_mirror_tpl_contact_sheet", default: "Contact Sheet")
            case .sentence:     return RemoteConfigManager.shared.copyString("copy_mirror_tpl_sentence", default: "The Sentence")
            case .claim:        return RemoteConfigManager.shared.copyString("copy_mirror_tpl_claim", default: "The Claim")
            case .landmark:     return RemoteConfigManager.shared.copyString("copy_mirror_tpl_landmark", default: "Landmark")
            }
        }

        static func templateGroup(_ group: MirrorTemplate.Group) -> String {
            switch group {
            case .everyday: return RemoteConfigManager.shared.copyString("copy_mirror_group_everyday", default: "Every day")
            case .data:     return RemoteConfigManager.shared.copyString("copy_mirror_group_data", default: "Your numbers")
            case .object:   return RemoteConfigManager.shared.copyString("copy_mirror_group_object", default: "Printed")
            case .archive:  return RemoteConfigManager.shared.copyString("copy_mirror_group_archive", default: "Your history")
            case .voice:    return RemoteConfigManager.shared.copyString("copy_mirror_group_voice", default: "In words")
            }
        }

        // MARK: - Picker

        static var pickerSuggested: String { RemoteConfigManager.shared.copyString("copy_mirror_picker_suggested", default: "Suggested for today") }
        static var pickerAllLooks: String { RemoteConfigManager.shared.copyString("copy_mirror_picker_all", default: "All looks") }
        static var pickerSetDefault: String { RemoteConfigManager.shared.copyString("copy_mirror_picker_set_default", default: "Use this every day") }
        static var pickerDefaultSet: String { RemoteConfigManager.shared.copyString("copy_mirror_picker_default_set", default: "This is your everyday look") }
        /// `%d` is the landmark day being marked.
        static func suggestLandmark(_ day: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_suggest_landmark", default: "Day %d. Worth marking properly."), day)
        }
        static var suggestQuiet: String { RemoteConfigManager.shared.copyString("copy_mirror_suggest_quiet", default: "A quieter one today, with no numbers on it.") }
        static var suggestWeek: String { RemoteConfigManager.shared.copyString("copy_mirror_suggest_week", default: "You have the full week. Here it is.") }
        static var suggestLighting: String { RemoteConfigManager.shared.copyString("copy_mirror_suggest_lighting", default: "Bright behind you, so the numbers move onto paper.") }

        // MARK: - Template content

        static var labelReady: String { RemoteConfigManager.shared.copyString("copy_mirror_label_ready", default: "READY") }
        static var labelSleep: String { RemoteConfigManager.shared.copyString("copy_mirror_label_sleep", default: "SLEEP") }
        static var labelHrv: String { RemoteConfigManager.shared.copyString("copy_mirror_label_hrv", default: "HRV") }
        static var labelResting: String { RemoteConfigManager.shared.copyString("copy_mirror_label_resting", default: "RESTING") }
        static var labelStrain: String { RemoteConfigManager.shared.copyString("copy_mirror_label_strain", default: "STRAIN") }
        static var labelDeep: String { RemoteConfigManager.shared.copyString("copy_mirror_label_deep", default: "DEEP") }
        static var labelLastNight: String { RemoteConfigManager.shared.copyString("copy_mirror_label_last_night", default: "LAST NIGHT") }
        static var labelAsleep: String { RemoteConfigManager.shared.copyString("copy_mirror_label_asleep", default: "ASLEEP") }
        static var labelThisWeek: String { RemoteConfigManager.shared.copyString("copy_mirror_label_this_week", default: "THIS WEEK") }
        static var labelThen: String { RemoteConfigManager.shared.copyString("copy_mirror_label_then", default: "THEN") }
        static var labelNow: String { RemoteConfigManager.shared.copyString("copy_mirror_label_now", default: "NOW") }
        static var labelYourAge: String { RemoteConfigManager.shared.copyString("copy_mirror_label_your_age", default: "YOUR AGE") }
        static var labelYourBody: String { RemoteConfigManager.shared.copyString("copy_mirror_label_your_body", default: "YOUR BODY") }
        static var labelThirtyDays: String { RemoteConfigManager.shared.copyString("copy_mirror_label_thirty_days", default: "30 DAYS") }
        static var labelPrivate: String { RemoteConfigManager.shared.copyString("copy_mirror_label_private", default: "ONLY YOU SEE THIS") }
        static var labelKeptHere: String { RemoteConfigManager.shared.copyString("copy_mirror_label_kept_here", default: "KEPT ON THIS PHONE") }
        static var masthead: String { RemoteConfigManager.shared.copyString("copy_mirror_masthead", default: "The Daily Mirror") }
        /// `%d` is the capture day, used as an issue number on the masthead.
        static func issueNumber(_ day: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_issue_number", default: "NO. %d"), day)
        }
        /// `%d` is the capture day.
        static func dayNumber(_ day: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_day_number", default: "DAY %d"), day)
        }
        /// `%d` is the average score across the window drawn.
        static func averageScore(_ score: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_average_score", default: "AVG %d"), score)
        }
        /// `%1$d` captured days, `%2$d` days in the window.
        static func daysOfSeven(_ captured: Int, _ total: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_days_of_seven", default: "%1$d OF %2$d DAYS"), captured, total)
        }
        /// `%d` is the number of days between the two photos.
        static func daysApart(_ days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_days_apart", default: "%d days apart"), days)
        }
        /// `%1$@` is what the user did, `%2$d` is how far recovery moved.
        static func actionProof(_ action: String, _ delta: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_action_proof", default: "%1$@. Recovery moved %2$d points overnight."), action, delta)
        }
        /// `%d` is the confidence percentage behind this morning's score.
        static func confidenceSure(_ percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_confidence_sure", default: "%d PERCENT SURE"), percent)
        }
        /// `%d` is the run length being marked.
        static func landmarkTitle(_ days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_landmark_title", default: "%d DAYS"), days)
        }
        /// `%1$@` is the first capture date, `%2$d` is the total captures.
        static func landmarkLine(_ started: String, _ total: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_landmark_line", default: "You started on %1$@ and you have kept %2$d of them."), started, total)
        }
        /// `%d` is the number of years between the two ages.
        static func yearsYounger(_ years: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_years_younger", default: "%d YEARS YOUNGER"), years)
        }
        static func yearsOlder(_ years: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_mirror_years_older", default: "%d YEARS OLDER"), years)
        }
        static var sameAsYourAge: String { RemoteConfigManager.shared.copyString("copy_mirror_same_age", default: "THE SAME AS YOUR AGE") }

        /// The claim template's archetypes. Each is a description of a real
        /// pattern in the last thirty days, never flattery the data cannot
        /// support.
        static var claimSteady: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_steady", default: "STEADY STATE") }
        static var claimSteadyLine: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_steady_line", default: "Thirty days, and your recovery has not moved more than six points either way.") }
        static var claimClimbing: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_climbing", default: "ON THE WAY UP") }
        static var claimClimbingLine: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_climbing_line", default: "Your last ten days are running higher than the twenty before them.") }
        static var claimRebuilding: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_rebuilding", default: "REBUILDING") }
        static var claimRebuildingLine: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_rebuilding_line", default: "A harder stretch than usual, and you kept showing up through it.") }
        static var claimSwinging: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_swinging", default: "UP AND DOWN") }
        static var claimSwingingLine: String { RemoteConfigManager.shared.copyString("copy_mirror_claim_swinging_line", default: "Big swings this month. Your good days are very good.") }

        /// One Word. Read in order, first match wins. None of these states a
        /// health claim and none of them makes a hard day sound like a failure.
        static var wordRest: String { RemoteConfigManager.shared.copyString("copy_mirror_word_rest", default: "Rest") }
        static var wordRestLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_rest_line", default: "Hard days count too.") }
        static var wordTired: String { RemoteConfigManager.shared.copyString("copy_mirror_word_tired", default: "Tired") }
        static var wordTiredLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_tired_line", default: "You came anyway.") }
        static var wordHeavy: String { RemoteConfigManager.shared.copyString("copy_mirror_word_heavy", default: "Heavy") }
        static var wordHeavyLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_heavy_line", default: "Carrying a bit today.") }
        static var wordSlow: String { RemoteConfigManager.shared.copyString("copy_mirror_word_slow", default: "Slow") }
        static var wordSlowLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_slow_line", default: "Take it gently.") }
        static var wordSteady: String { RemoteConfigManager.shared.copyString("copy_mirror_word_steady", default: "Steady") }
        static var wordSteadyLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_steady_line", default: "Nothing to prove today.") }
        static var wordReady: String { RemoteConfigManager.shared.copyString("copy_mirror_word_ready", default: "Ready") }
        static var wordReadyLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_ready_line", default: "Good day to use.") }
        static var wordStrong: String { RemoteConfigManager.shared.copyString("copy_mirror_word_strong", default: "Strong") }
        static var wordStrongLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_strong_line", default: "Remember this one.") }
        static var wordToday: String { RemoteConfigManager.shared.copyString("copy_mirror_word_today", default: "Today") }
        static var wordTodayLine: String { RemoteConfigManager.shared.copyString("copy_mirror_word_today_line", default: "Just here.") }
    }
}
