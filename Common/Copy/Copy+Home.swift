import Foundation
import SwiftUI

extension Copy {
    enum Home {

        // MARK: - Last Refresh Footer

        static func updatedAgo(_ date: Date) -> Text {
            // Pulls the "Updated %@ ago" template from RC; %@ is replaced with
            // the SwiftUI relative-date Text so the date stays auto-styled.
            let template = RemoteConfigManager.shared.copyString("copy_home_updated_ago_template", default: "Updated %@ ago")
            // Split the template into two halves around %@ so the relative Text
            // preserves SwiftUI's automatic styling (we cannot use String(format:) here).
            let parts = template.components(separatedBy: "%@")
            let prefix = parts.first ?? "Updated "
            let suffix = parts.count > 1 ? parts[1] : " ago"
            return Text(prefix) + Text(date, style: .relative) + Text(suffix)
        }
        /// Plain-string variant for `accessibilityLabel(_:)`, which rejects styled `Text`.
        static func lastUpdatedAgo(_ date: Date) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_last_updated_ago", default: "Last updated %@"),
                   Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))
        }
        static var pullToRefresh: Text {
            Text(RemoteConfigManager.shared.copyString("copy_home_pull_to_refresh", default: "Pull to refresh"))
        }
        static var notSyncedYetAccessibility: String { RemoteConfigManager.shared.copyString("copy_home_not_synced_yet_accessibility", default: "Health data not synced yet. Pull down to refresh.") }

        private static let relativeFormatter: RelativeDateTimeFormatter = {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return f
        }()

        // MARK: - Loading

        static var analyzingHealthData: String { RemoteConfigManager.shared.copyString("copy_home_analyzing_health_data", default: "Analyzing your health data...") }

        // Next Up card: the daily action leads the home screen.
        static var nextUpHeader: String { RemoteConfigManager.shared.copyString("copy_home_next_up_header", default: "NEXT UP · TODAY") }
        static var nextUpMarkDone: String { RemoteConfigManager.shared.copyString("copy_home_next_up_mark_done", default: "Mark done") }
        /// Short confirm label shown on the button after it is marked done.
        static var nextUpMarkedDone: String { RemoteConfigManager.shared.copyString("copy_home_next_up_marked_done", default: "Done") }
        /// Remind button on the action card. %@ is the reminder clock time, e.g. "9:30 PM".
        static func nextUpRemind(_ time: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_next_up_remind", default: "Remind %@"), time) }
        /// Same button once today's reminder time has gone by, so the reminder lands tomorrow. %@ is the clock time.
        static func nextUpRemindTomorrow(_ time: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_next_up_remind_tomorrow", default: "Remind tomorrow %@"), time) }
        static var nextUpReminderSet: String { RemoteConfigManager.shared.copyString("copy_home_next_up_reminder_set", default: "Reminder set") }

        // MARK: - Data coverage
        //
        // What Apple Health has actually given us, per signal. A score built on
        // a missing signal has to say which one is missing on the same screen,
        // otherwise silent zeros read as a broken app rather than a switch that
        // was never turned on.

        static var coverageTitle: String { RemoteConfigManager.shared.copyString("copy_home_coverage_title", default: "WHAT WE ARE READING") }
        /// %1$d days with data out of %2$d checked.
        static func coverageDays(_ days: Int, _ window: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_coverage_days", default: "%1$d of %2$d days"), days, window)
        }
        static var coverageNone: String { RemoteConfigManager.shared.copyString("copy_home_coverage_none", default: "Nothing yet") }
        /// HealthKit never tells an app which read permissions were refused, so
        /// this line offers both real causes instead of guessing one.
        static func coverageMissingHint(_ names: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_coverage_missing_hint", default: "%@ has sent nothing. Either it is switched off for Laso in the Health app, or your watch has not recorded it."), names)
        }
        static var coverageOpenSettings: String { RemoteConfigManager.shared.copyString("copy_home_coverage_open_settings", default: "Check Health settings") }

        // MARK: - Life context chips
        //
        // What the watch cannot see. An active chip is a hard constraint on the
        // day's advice, not a label.

        static var contextInjured: String { RemoteConfigManager.shared.copyString("copy_home_context_injured", default: "Injured") }
        static var contextUnwell: String { RemoteConfigManager.shared.copyString("copy_home_context_unwell", default: "Unwell") }
        static var contextTravelling: String { RemoteConfigManager.shared.copyString("copy_home_context_travelling", default: "Travelling") }
        static var contextPoorSleepWeek: String { RemoteConfigManager.shared.copyString("copy_home_context_poor_sleep_week", default: "Sleeping badly") }
        /// %2$@ is the day the user switched it on, e.g. "20 Jul". We show the
        /// start, never an end: how long an injury lasts is not ours to predict.
        static func contextSince(_ name: String, _ date: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_context_since", default: "%1$@ since %2$@"), name, date)
        }
        static var contextAddHint: String { RemoteConfigManager.shared.copyString("copy_home_context_add_hint", default: "Tell us what is going on") }
        /// The periodic check in, so a context can never sit on silently.
        static func contextStillOn(_ name: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_context_still_on", default: "Still %@?"), name)
        }
        static var contextStillYes: String { RemoteConfigManager.shared.copyString("copy_home_context_still_yes", default: "Yes") }
        static var contextStillNo: String { RemoteConfigManager.shared.copyString("copy_home_context_still_no", default: "No, all better") }

        // The action shown while a rest context is on. It overrides everything
        // the body signals would otherwise suggest.
        static var contextRestTitle: String { RemoteConfigManager.shared.copyString("copy_home_context_rest_title", default: "Keep today easy") }
        static func contextRestSubtitle(_ name: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_context_rest_subtitle", default: "You told us you are %@, so we are not asking for load today. Gentle movement is fine, hard effort is not."), name)
        }
        static func contextRestRationale(_ name: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_context_rest_rationale", default: "While %@ is on, recovery matters more than any training gain, so the day's action ignores your readiness score."), name)
        }

        // Activation banner: first week calibration progress line.
        static var activationFullyCalibrated: String { RemoteConfigManager.shared.copyString("copy_home_activation_fully_calibrated", default: "Fully calibrated") }
        /// %@ is the next milestone name, e.g. "Trend Detected".
        static func activationMilestoneSoon(_ milestone: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_soon", default: "Almost there. %@ unlocking soon"), milestone) }
        /// %1$d is today's day number, %2$@ the next milestone name.
        static func activationMilestoneTomorrow(day: Int, milestone: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_tomorrow", default: "Day %1$d of 7. %2$@ in 1 day"), day, milestone) }
        /// %1$d is today's day number, %2$@ the next milestone name, %3$d the days until it unlocks.
        static func activationMilestoneInDays(day: Int, milestone: String, days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_in_days", default: "Day %1$d of 7. %2$@ in %3$d days"), day, milestone, days) }

        // Score card (redesigned): one word state + a plain summary + the Why list.
        static var scoreReadyLabel: String { RemoteConfigManager.shared.copyString("copy_home_score_ready_label", default: "Ready") }
        // Split into a bold heading line and a lighter sub line under the orb.
        static var scoreSummaryLowHead: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_low_head", default: "Lower than usual today.") }
        static var scoreSummaryLowSub: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_low_sub", default: "Worth an easy day.") }
        static var scoreSummaryModerateHead: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_moderate_head", default: "About usual today.") }
        static var scoreSummaryModerateSub: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_moderate_sub", default: "A steady day suits you.") }
        static var scoreSummaryHighHead: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_high_head", default: "Higher than usual today.") }
        static var scoreSummaryHighSub: String { RemoteConfigManager.shared.copyString("copy_home_score_summary_high_sub", default: "Good to push a little.") }
        /// The band a thin reading sits in, e.g. "Likely 61 to 77".
        static func scoreRange(_ low: Int, _ high: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_score_range", default: "Likely %1$d to %2$d"), low, high)
        }
        static var scoreWhyLabel: String { RemoteConfigManager.shared.copyString("copy_home_score_why_label", default: "Why") }
        // One word per recovery band, for places that show a score without its ring.
        static var stateNameGood: String { RemoteConfigManager.shared.copyString("copy_home_state_name_good", default: "Ready") }
        static var stateNameSteady: String { RemoteConfigManager.shared.copyString("copy_home_state_name_steady", default: "Steady") }
        static var stateNameLow: String { RemoteConfigManager.shared.copyString("copy_home_state_name_low", default: "Low") }
        // Plain-word reasons and their status values.
        static var whySleepShort: String { RemoteConfigManager.shared.copyString("copy_home_why_sleep_short", default: "Sleep was short") }
        static var whySleepGood: String { RemoteConfigManager.shared.copyString("copy_home_why_sleep_good", default: "Sleep was solid") }
        static var whyHeartCalm: String { RemoteConfigManager.shared.copyString("copy_home_why_heart_calm", default: "Heart is calm") }
        static var whyHeartWorking: String { RemoteConfigManager.shared.copyString("copy_home_why_heart_working", default: "Heart is working hard") }
        /// Comparative readings. "Good" told a person nothing they could act on,
        /// so every row that has a baseline now shows the gap to their own usual.
        static func whyValueBelowUsual(_ amount: String, _ unit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_why_value_below_usual", default: "%1$@ %2$@ below usual"), amount, unit)
        }
        static func whyValueAboveUsual(_ amount: String, _ unit: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_why_value_above_usual", default: "%1$@ %2$@ above usual"), amount, unit)
        }
        static var whyValueAtUsual: String { RemoteConfigManager.shared.copyString("copy_home_why_value_at_usual", default: "At your usual") }
        /// "1 hrs below usual" read as broken English. Only spelled-out units
        /// agree with the number; symbols like ms and bpm never change.
        static var unitHourSingular: String { RemoteConfigManager.shared.copyString("copy_home_unit_hour_singular", default: "hr") }
        static var whyEnergyLow: String { RemoteConfigManager.shared.copyString("copy_home_why_energy_low", default: "Energy is low") }
        static var whyEnergyGood: String { RemoteConfigManager.shared.copyString("copy_home_why_energy_good", default: "Energy is good") }
        static var whyEnergyLowValue: String { RemoteConfigManager.shared.copyString("copy_home_why_energy_low_value", default: "Below usual") }
        static var whyEnergyGoodValue: String { RemoteConfigManager.shared.copyString("copy_home_why_energy_good_value", default: "Good") }

        // Plain signal names, used only for the "No reading yet" placeholder row.
        static var whyNameSleep: String { RemoteConfigManager.shared.copyString("copy_home_why_name_sleep", default: "Sleep") }
        static var whyNameHeart: String { RemoteConfigManager.shared.copyString("copy_home_why_name_heart", default: "Heart") }
        static var whyNameEnergy: String { RemoteConfigManager.shared.copyString("copy_home_why_name_energy", default: "Energy") }
        /// Abbreviated because the full name leaves no room for the reading
        /// beside it. The metric screen it opens spells it out in full.
        static var whyNameRestingHR: String { RemoteConfigManager.shared.copyString("copy_home_why_name_resting_hr", default: "Resting HR") }
        static var whyNameStress: String { RemoteConfigManager.shared.copyString("copy_home_why_name_stress", default: "Stress") }
        /// Kept short: it shares a narrow row with signal names as long as
        /// "Resting heart rate", and the name must never be the part that clips.
        static var whyNoData: String { RemoteConfigManager.shared.copyString("copy_home_why_no_data", default: "None yet") }
        // Extra dynamic signals that can surface in the Why list.
        static var whyRhrUp: String { RemoteConfigManager.shared.copyString("copy_home_why_rhr_up", default: "Resting heart rate is up") }
        static var whyRhrCalm: String { RemoteConfigManager.shared.copyString("copy_home_why_rhr_calm", default: "Heart rate is calm at rest") }
        static var whyStressHigh: String { RemoteConfigManager.shared.copyString("copy_home_why_stress_high", default: "Stress is high") }
        static var whyStressLow: String { RemoteConfigManager.shared.copyString("copy_home_why_stress_low", default: "Stress is low") }

        // Chip under the ring comparing today's score with yesterday's.
        static func scoreChangeUp(_ points: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_score_change_up", default: "%d up from yesterday"), points) }
        static func scoreChangeDown(_ points: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_score_change_down", default: "%d down from yesterday"), points) }
        static var scoreChangeSame: String { RemoteConfigManager.shared.copyString("copy_home_score_change_same", default: "Same as yesterday") }

        /// How many of the score's signals actually had a reading today.
        static func scoreConfidence(_ withData: Int, _ total: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_score_confidence", default: "Based on %d of %d signals"), withData, total) }
        /// Named under the Why list whenever a signal has no reading, so a
        /// partial score says out loud what it is missing and what fixes it.
        static func scoreMissingSignals(_ names: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_score_missing_signals", default: "%@ not recorded yet. Wear your watch tonight and tomorrow is a full read."), names)
        }
        static var scoreListJoiner: String { RemoteConfigManager.shared.copyString("copy_home_score_list_joiner", default: ", ") }
        static var scoreListFinalJoiner: String { RemoteConfigManager.shared.copyString("copy_home_score_list_final_joiner", default: " and ") }

        // Yesterday's result: the loop-closer shown the morning after an action
        // is marked done, reporting how the readiness score moved.
        static var dailyResultHeader: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_header", default: "YESTERDAY'S RESULT") }
        static func dailyResultUp(delta: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_daily_result_up", default: "Your recovery is +%d higher this morning."), delta) }
        static var dailyResultSteady: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_steady", default: "Your recovery held steady. Small steps add up.") }
        static func dailyResultDown(delta: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_daily_result_down", default: "Your recovery dipped %d. Rest is part of the plan too."), delta) }
        static var dailyResultDismiss: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_dismiss", default: "Got it") }

        // Streak milestone: the one time offer to share a streak the user has
        // just crossed. Shown once per milestone, never again.
        static var streakMilestoneHeader: String { RemoteConfigManager.shared.copyString("copy_home_streak_milestone_header", default: "STREAK MILESTONE") }
        static func streakMilestoneTitle(days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_streak_milestone_title", default: "%d days in a row"), days) }
        static var streakMilestoneBody: String { RemoteConfigManager.shared.copyString("copy_home_streak_milestone_body", default: "You hit activity, sleep and recovery on every one of those days.") }
        static var streakMilestoneShare: String { RemoteConfigManager.shared.copyString("copy_home_streak_milestone_share", default: "Share this") }
        static var streakMilestoneDismiss: String { RemoteConfigManager.shared.copyString("copy_home_streak_milestone_dismiss", default: "No thanks") }

        // MARK: - Connection Status (Home empty state)

        enum ConnectionStatus {
            // Titles
            static func titleReceiving(_ deviceName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_connection_status_title_receiving", default: "%@ is sending data"), deviceName) }
            static var titleStale: String { RemoteConfigManager.shared.copyString("copy_home_connection_status_title_stale", default: "Your watch has not synced recently") }
        }

        // MARK: - Error

        static var unableToLoadData: String { RemoteConfigManager.shared.copyString("copy_home_unable_to_load_data", default: "Unable to Load Data") }
        static var tryAgain: String { RemoteConfigManager.shared.copyString("copy_home_try_again", default: "Try Again") }

        // MARK: - First Launch Sync

        static var syncingHealthData: String { RemoteConfigManager.shared.copyString("copy_home_syncing_health_data", default: "Syncing your past year of health data") }
        static func analyzingDataPoints(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_analyzing_data_points", default: "Analyzing %d data points"), count) }
        static var analyzingYourData: String { RemoteConfigManager.shared.copyString("copy_home_analyzing_your_data", default: "Analyzing your data") }
        static var discoveringPatterns: String { RemoteConfigManager.shared.copyString("copy_home_discovering_patterns", default: "Discovering patterns") }
        static var ready: String { RemoteConfigManager.shared.copyString("copy_home_ready", default: "Ready") }
        static var thisOnlyHappensOnce: String { RemoteConfigManager.shared.copyString("copy_home_this_only_happens_once", default: "This only happens once") }

        // MARK: - Primary Action

        static var todaysAction: String { RemoteConfigManager.shared.copyString("copy_home_todays_action", default: "Today's Action") }
        static var bodyIntelligence: String { RemoteConfigManager.shared.copyString("copy_home_body_intelligence", default: "Body Intelligence") }

        // MARK: - Watch This

        static var earlyWarning: String { RemoteConfigManager.shared.copyString("copy_home_early_warning", default: "Worth Noticing") }
        static var severityHigh: String { RemoteConfigManager.shared.copyString("copy_home_severity_high", default: "High") }
        static var severityModerate: String { RemoteConfigManager.shared.copyString("copy_home_severity_moderate", default: "Moderate") }
        static var severityLow: String { RemoteConfigManager.shared.copyString("copy_home_severity_low", default: "Low") }

        // MARK: - Section & Card Labels

        static var whyThisToday: String { RemoteConfigManager.shared.copyString("copy_home_why_this_today", default: "Why this, today") }
        static var nextWeekTarget: String { RemoteConfigManager.shared.copyString("copy_home_next_week_target", default: "Next week target") }
        static var wearAppleWatchForRecovery: String { RemoteConfigManager.shared.copyString("copy_home_wear_apple_watch_for_recovery", default: "Wear your Apple Watch to see your live energy") }

        // MARK: - Score Guide

        enum ScoreGuide {
            static var healthScore: String { RemoteConfigManager.shared.copyString("copy_home_score_guide_health_score", default: "Health Score") }
            static var title: String { RemoteConfigManager.shared.copyString("copy_home_score_guide_title", default: "This is your Health Score") }
            static var description: String { RemoteConfigManager.shared.copyString("copy_home_score_guide_description", default: "A single number from 0 to 100 that shows how your body is doing right now, based on your own data.") }

            // Personalized "What does it mean?" based on score level
            static var whatDoesItMean: String { RemoteConfigManager.shared.copyString("copy_home_score_guide_what_does_it_mean", default: "What does it mean?") }

            static func whatDoesItMeanBody(score: Int, weakestCategory: String?) -> String {
                let levelExplanation: String
                switch HealthScoreBand.from(score: score) {
                case .excellent:
                    levelExplanation = RemoteConfigManager.shared.copyString("copy_home_score_what_means_excellent", default: "Your numbers are steady or getting better compared to your usual. Everything looks well balanced.")
                case .good:
                    levelExplanation = RemoteConfigManager.shared.copyString("copy_home_score_what_means_good", default: "Most of your numbers are on track, but a few areas have shifted a bit from your usual.")
                case .fair:
                    levelExplanation = RemoteConfigManager.shared.copyString("copy_home_score_what_means_fair", default: "Several numbers have shifted from your usual. This is worth paying attention to.")
                case .needsAttention, .critical:
                    levelExplanation = RemoteConfigManager.shared.copyString("copy_home_score_what_means_needs", default: "Several numbers are off from your usual. Check your insights for areas to focus on.")
                }
                let categoryHint: String
                if let weakest = weakestCategory {
                    categoryHint = String(format: RemoteConfigManager.shared.copyString("copy_home_score_what_means_category_hint", default: " %@ is the area pulling your score down the most right now."), weakest)
                } else {
                    categoryHint = ""
                }
                let suffix = RemoteConfigManager.shared.copyString("copy_home_score_what_means_suffix", default: " This is for information only. Think of it as a daily check in with your body.")
                return levelExplanation + categoryHint + suffix
            }

            static var scoreLevels: String { RemoteConfigManager.shared.copyString("copy_home_score_levels", default: "Score levels") }

            // Score level ranges. Bands match `HealthScoreBand` (single source
            // of truth) so the guide and the live UI never disagree.
            static var excellentRange: String { RemoteConfigManager.shared.copyString("copy_home_excellent_range", default: "85 to 100") }
            static var excellentLabel: String { RemoteConfigManager.shared.copyString("copy_home_excellent_label", default: "Excellent") }
            static var excellentDescription: String { RemoteConfigManager.shared.copyString("copy_home_excellent_description", default: "Everything looks great. Keep doing what you are doing.") }
            static var goodRange: String { RemoteConfigManager.shared.copyString("copy_home_good_range", default: "70 to 84") }
            static var goodLabel: String { RemoteConfigManager.shared.copyString("copy_home_good_label", default: "Good") }
            static var goodDescription: String { RemoteConfigManager.shared.copyString("copy_home_good_description", default: "Most things are on track with small areas to watch.") }
            static var fairRange: String { RemoteConfigManager.shared.copyString("copy_home_fair_range", default: "55 to 69") }
            static var fairLabel: String { RemoteConfigManager.shared.copyString("copy_home_fair_label", default: "Fair") }
            static var fairDescription: String { RemoteConfigManager.shared.copyString("copy_home_fair_description", default: "A few numbers have shifted. Worth paying attention to.") }
            static var needsAttentionRange: String { RemoteConfigManager.shared.copyString("copy_home_needs_attention_range", default: "Below 55") }
            static var needsAttentionLabel: String { RemoteConfigManager.shared.copyString("copy_home_needs_attention_label", default: "Room to Grow") }
            static var needsAttentionDescription: String { RemoteConfigManager.shared.copyString("copy_home_needs_attention_description", default: "Several things are off from your usual. Check your insights.") }

            // Categories
            static var howItsCalculated: String { RemoteConfigManager.shared.copyString("copy_home_how_its_calculated", default: "How it\u{2019}s calculated") }
            static var howItsCalculatedBody: String { RemoteConfigManager.shared.copyString("copy_home_how_its_calculated_body", default: "Your Health Score blends four areas. Areas with more data and more change count for more. Each number is compared to your usual, and shifts and trends move the score up or down.") }
            static var heartCardioName: String { RemoteConfigManager.shared.copyString("copy_home_heart_cardio_name", default: "Heart & Cardio") }
            static var heartCardioDetail: String { RemoteConfigManager.shared.copyString("copy_home_heart_cardio_detail", default: "Resting heart rate, heart calm signal, and cardio fitness") }
            static var sleepName: String { RemoteConfigManager.shared.copyString("copy_home_sleep_name", default: "Sleep") }
            static var sleepDetail: String { RemoteConfigManager.shared.copyString("copy_home_sleep_detail", default: "Duration, consistency, and sleep stages") }
            static var activityName: String { RemoteConfigManager.shared.copyString("copy_home_activity_name", default: "Activity") }
            static var activityDetail: String { RemoteConfigManager.shared.copyString("copy_home_activity_detail", default: "Steps, workouts, and energy burned") }
            static var bodyVitalsName: String { RemoteConfigManager.shared.copyString("copy_home_body_vitals_name", default: "Body & Vitals") }
            static var bodyVitalsDetail: String { RemoteConfigManager.shared.copyString("copy_home_body_vitals_detail", default: "Weight, body fat, blood oxygen, and more") }

            // Refresh timing
            static var whenItUpdatesTitle: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_title", default: "When does it update?") }
            static var whenItUpdatesBody: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_body", default: "Your Health Score refreshes each time you open the app or pull to refresh. It uses the latest data from Apple Health, so changes in your numbers show up within minutes. Trends and shifts in your usual take about 1 to 3 days to show up in the score.") }

            // Baseline callout
            static var baselineCallout: String { RemoteConfigManager.shared.copyString("copy_home_baseline_callout", default: "This score compares you to yourself, not other people. As we learn your patterns, it gets more accurate.") }

            static var gotIt: String { RemoteConfigManager.shared.copyString("copy_home_got_it", default: "Got It") }
        }

        // MARK: - Action Proof

        enum ActionProof {
            /// Detail view section title
            static var whatHappenedBefore: String { RemoteConfigManager.shared.copyString("copy_home_what_happened_before", default: "What happened before") }

            /// Detail: summary of positive outcomes
            static func pastOutcomeSummary(improved: Int, total: Int, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_past_outcome_summary", default: "Out of %d similar tips, %d led to a real improvement in your %@"), total, improved, metric)
            }

            /// Detail: timeframe context
            static func trackingWindow(days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_tracking_window", default: "Based on your data from the last %d days"), days)
            }
        }

        // MARK: - Greeting

        enum Greeting {
            static var goodMorning: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_morning", default: "Morning") }
            static var goodAfternoon: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_afternoon", default: "Afternoon") }
            static var goodEvening: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_evening", default: "Evening") }
            static var goodNight: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_night", default: "Night") }
        }

        // MARK: - Morning Check-In

        enum MorningCheckIn {
            static var greeting: String { RemoteConfigManager.shared.copyString("copy_home_morning_check_in_greeting", default: "Good Morning") }
            static var subtitle: String { RemoteConfigManager.shared.copyString("copy_home_morning_check_in_subtitle", default: "How are you feeling today?") }
            static var done: String { RemoteConfigManager.shared.copyString("copy_home_morning_check_in_done", default: "Done") }
        }

        // MARK: - Ask Your Data

        enum AskYourData {
            static var title: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_title", default: "Ask Your Data") }
            static var placeholder: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_placeholder", default: "Ask anything about your health...") }
            static var tryAsking: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_try_asking", default: "Try asking") }
            static var related: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_related", default: "Related questions") }

            // Concierge-style home card
            static var caption: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_caption", default: "CONCIERGE") }
            static var conciergePrompts: [String] { RemoteConfigManager.shared.copyArray("copy_home_ask_your_data_concierge_prompts", default: ["Ask me how to spend today well.", "How is my heart calm signal trending?", "What is affecting my sleep this week?", "Am I getting enough deep sleep?", "How does exercise shift my recovery?", "What changed in my body last week?", "How consistent is my sleep schedule?"]) }

            static func confidence(_ percent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_ask_your_data_confidence", default: "%d%% confidence"), percent)
            }

            static var suggestedQuestions: [String] { RemoteConfigManager.shared.copyArray("copy_home_suggested_questions", default: ["How is my sleep this week?", "What affects my heart calm signal the most?", "Am I getting enough deep sleep?", "How does exercise affect my recovery?", "What is my resting heart rate trend?", "How consistent is my sleep schedule?"]) }
        }

        // MARK: - Recovery Info

        enum RecoveryInfo {
            static var title: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_title", default: "How Readiness Works") }
            // Ranges here must match `DS.optimalFloor` and `DS.fairFloor`. This
            // sheet used to print 80/50 while the ring graded at 67/45, so a 55
            // was amber on screen and "decent recovery" one tap away.
            static var description: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_description", default: "Each morning your Readiness is locked in from last night's sleep and your overnight heart rate data. As you move and burn energy through the day, the number drops. Take off the Apple Watch and the drop pauses, but your morning Readiness still stays on the screen.") }

            // Score levels
            static var scoreLevels: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_score_levels", default: "Score levels") }
            static var fullyRecoveredRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_range", default: "67 to 100") }
            static var fullyRecoveredLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_label", default: "Ready") }
            static var fullyRecoveredDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_description", default: "Your body is well rested. Great day for a hard workout.") }
            static var moderateRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_range", default: "45 to 66") }
            static var moderateLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_label", default: "Steady") }
            static var moderateDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_description", default: "About your usual. Moderate effort is best today.") }
            static var lowRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_range", default: "Below 45") }
            static var lowLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_label", default: "Low") }
            static var lowDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_description", default: "Your body needs rest. Focus on easy movement and sleep.") }

            // How it's calculated
            static var howItsCalculated: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_how_its_calculated", default: "How it\u{2019}s calculated") }
            static var howItsCalculatedBody: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_how_its_calculated_body", default: "Readiness blends a few signals measured while you sleep. Each signal is compared to your usual. The further off it is, the more it moves the score.") }
            static var hrvName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_name", default: "Heart Calm Signal") }
            static var hrvWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_weight", default: "40% weight") }
            static var hrvDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_detail", default: "A higher heart calm signal means better recovery and lower stress. Compared to your usual.") }
            static var restingHRName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_name", default: "Resting Heart Rate") }
            static var restingHRWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_weight", default: "35% weight") }
            static var restingHRDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_detail", default: "A lower resting heart rate means your heart is recovering well. Compared to your usual.") }
            static var sleepDurationName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_duration_name", default: "Sleep Duration") }
            static var sleepDurationWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_duration_weight", default: "15% weight") }
            static var sleepDurationDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_duration_detail", default: "7.5 hours is best. Too little or too much lowers the score.") }
            static var sleepQualityName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_quality_name", default: "Sleep Quality") }
            static var sleepQualityWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_quality_weight", default: "6% weight") }
            static var sleepQualityDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_sleep_quality_detail", default: "Deep and REM sleep stages help your recovery quality.") }
            static var workoutRecoveryName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_workout_recovery_name", default: "Recent Workout") }
            static var workoutRecoveryWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_workout_recovery_weight", default: "4% weight") }
            static var workoutRecoveryDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_workout_recovery_detail", default: "Hard workouts lower recovery for a short time. The effect fades over 18 to 36 hours.") }

            // Device requirement
            static func wearRequirement(deviceName: String?) -> String {
                if let deviceName {
                    return String(format: RemoteConfigManager.shared.copyString("copy_home_wear_requirement_named", default: "Wear your %@ overnight so it can measure your heart calm signal and resting heart rate while you sleep."), deviceName)
                }
                return RemoteConfigManager.shared.copyString("copy_home_wear_requirement_default", default: "Wear your Apple Watch overnight so it can measure your heart calm signal and resting heart rate while you sleep.")
            }

            // Refresh timing
            static var whenItUpdatesTitle: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_title", default: "When does it update?") }
            static var whenItUpdatesBody: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_body", default: "Your Recovery is set once each morning from last night's signals and stays as the day's anchor. The number on Home then drains live as you burn energy. If you take the watch off, the morning Recovery stays put. If you do not have a morning reading yet and the watch is off, the score is hidden until your next overnight wear.") }
        }

        // MARK: - Cards

        enum Cards {
            // Daily narrative

            // Personal health forecast
            static var yourForecast: String { RemoteConfigManager.shared.copyString("copy_home_cards_your_forecast", default: "YOUR FORECAST") }
            static var nextSevenDays: String { RemoteConfigManager.shared.copyString("copy_home_cards_next_seven_days", default: "Next 7 days") }

            // Today briefing
            static var generatedByLasoIntelligence: String { RemoteConfigManager.shared.copyString("copy_home_cards_generated_by_laso_intelligence", default: "Generated by Laso intelligence") }
        }

        // MARK: - Smart Action Recommendations

        enum SmartAction {
            // MARK: - Policy engine action titles
            //
            // The card headline must be the thing to do, so it can be read as an
            // instruction and marked done. The old headline came from the
            // recovery state bucket, which described a different metric than the
            // sentence underneath it.

            static var doSleepEarlier: String { RemoteConfigManager.shared.copyString("copy_home_do_sleep_earlier", default: "Go to bed 30 minutes earlier tonight") }
            static var doSleepLater: String { RemoteConfigManager.shared.copyString("copy_home_do_sleep_later", default: "Shift bedtime a little later tonight") }
            static var doExtendSleep: String { RemoteConfigManager.shared.copyString("copy_home_do_extend_sleep", default: "Give yourself an extra 30 minutes in bed") }
            static var doReduceScreenTime: String { RemoteConfigManager.shared.copyString("copy_home_do_reduce_screen_time", default: "Put screens away an hour before bed") }
            static var doReduceEvening: String { RemoteConfigManager.shared.copyString("copy_home_do_reduce_evening", default: "Keep tonight calm and low key") }
            static var doActiveRecovery: String { RemoteConfigManager.shared.copyString("copy_home_do_active_recovery", default: "Take an easy 20 minute walk or stretch") }
            static var doIntensifyExercise: String { RemoteConfigManager.shared.copyString("copy_home_do_intensify_exercise", default: "Push a little harder in today's workout") }
            static var doReduceExercise: String { RemoteConfigManager.shared.copyString("copy_home_do_reduce_exercise", default: "Dial today's workout back a notch") }
            static var doShiftCaffeineTiming: String { RemoteConfigManager.shared.copyString("copy_home_do_shift_caffeine_timing", default: "Have your last coffee before 2 PM") }
            static var doReduceCaffeine: String { RemoteConfigManager.shared.copyString("copy_home_do_reduce_caffeine", default: "Drop one coffee today") }
            static var doBreathingSession: String { RemoteConfigManager.shared.copyString("copy_home_do_breathing_session", default: "Take 5 minutes of slow breathing") }
            static var doMeditation: String { RemoteConfigManager.shared.copyString("copy_home_do_meditation", default: "Sit quietly for 10 minutes") }
            static var doAdjustMealTiming: String { RemoteConfigManager.shared.copyString("copy_home_do_adjust_meal_timing", default: "Finish dinner at least 3 hours before bed") }
            static var doHydration: String { RemoteConfigManager.shared.copyString("copy_home_do_hydration", default: "Drink two more glasses of water today") }
            static var doIncreaseSteps: String { RemoteConfigManager.shared.copyString("copy_home_do_increase_steps", default: "Add a 10 minute walk today") }
            static var doReduceSteps: String { RemoteConfigManager.shared.copyString("copy_home_do_reduce_steps", default: "Stay off your feet more than usual today") }
            static var doNap: String { RemoteConfigManager.shared.copyString("copy_home_do_nap", default: "Take a 20 minute nap this afternoon") }

            // Default fallback
            static var defaultTitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_title", default: "Get moving for 15 minutes") }
            static var defaultSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_subtitle", default: "A short walk boosts mood, energy, and sleep quality tonight") }
            static var defaultRationale: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_rationale", default: "No specific signals today. A walk is the simplest, highest payoff activity for overall health.") }

            // Live data: high stress
            static var highStressTitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_title", default: "Your stress is higher than usual right now") }
            static var highStressSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_subtitle", default: "Slow breathing (in for 4, hold 4, out 4, hold 4) for 5 min can bring it down. Your body is asking for a reset.") }
            static func highStressRationale(_ stress: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_rationale", default: "Your live stress reading is %d%%, which is above your comfortable range."), stress)
            }

            // Live data: low sleep
            static var lowSleepTitle: String { RemoteConfigManager.shared.copyString("copy_home_low_sleep_title", default: "Go easy today") }
            static func lowSleepSubtitle(_ formattedSleep: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_low_sleep_subtitle", default: "Only %@ of sleep. Skip intense workouts. Your body needs to save energy."), formattedSleep)
            }
            static var lowSleepRationale: String { RemoteConfigManager.shared.copyString("copy_home_low_sleep_rationale", default: "You got much less sleep than your body needs. Hard effort today would add to the shortfall.") }

            // Live data: low readiness
            static var lowReadinessTitle: String { RemoteConfigManager.shared.copyString("copy_home_low_readiness_title", default: "Recovery day. Your body needs it") }
            static func lowReadinessSubtitle(_ readiness: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_low_readiness_subtitle", default: "Your body is %d%% ready. Stretching or yoga only"), readiness)
            }
            static var lowReadinessRationale: String { RemoteConfigManager.shared.copyString("copy_home_low_readiness_rationale", default: "A few signals (heart calm signal, resting heart rate, sleep) suggest your body has not fully recovered from recent strain.") }

            // Activity progress: goal reached
            static var exerciseGoalTitle: String { RemoteConfigManager.shared.copyString("copy_home_exercise_goal_title", default: "Exercise goal reached!") }
            static func exerciseGoalSubtitle(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_exercise_goal_subtitle", default: "%d min today. Stay active and drink water"), minutes)
            }
            static var exerciseGoalRationale: String { RemoteConfigManager.shared.copyString("copy_home_exercise_goal_rationale", default: "You have already hit your daily exercise goal.") }

            // Activity progress: minutes to go (good readiness)
            static func minutesToGoTitle(_ remaining: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_minutes_to_go_title", default: "You have %d min to go"), remaining)
            }
            static var minutesToGoSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_minutes_to_go_subtitle", default: "Recovery is strong. A run or workout would be great") }
            static var minutesToGoRationale: String { RemoteConfigManager.shared.copyString("copy_home_minutes_to_go_rationale", default: "Your body is well recovered and ready for effort. Closing the exercise gap today would build momentum.") }

            // Late hour wind-down
            static var windDownTitle: String { RemoteConfigManager.shared.copyString("copy_home_wind_down_title", default: "Wind down for sleep") }
            static var windDownSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_wind_down_subtitle", default: "Dim screens and skip caffeine for better rest tonight") }
            static var windDownRationale: String { RemoteConfigManager.shared.copyString("copy_home_wind_down_rationale", default: "It is late evening. Less blue light and caffeine now directly improves your sleep quality tonight.") }

            // Focus: deep sleep
            static var deepSleepTitle: String { RemoteConfigManager.shared.copyString("copy_home_deep_sleep_title", default: "Boost your deep sleep") }
            static func deepSleepSubtitle(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_deep_sleep_subtitle", default: "Only %d min of deep sleep. Try cutting caffeine after 2 PM"), minutes)
            }
            static var deepSleepRationale: String { RemoteConfigManager.shared.copyString("copy_home_deep_sleep_rationale", default: "Deep sleep is when your body repairs muscle, locks in memory, and balances hormones. You are getting less than 45 minutes.") }

            // Focus: bedtime
            static var earlyBedTitle: String { RemoteConfigManager.shared.copyString("copy_home_early_bed_title", default: "Get to bed 30 min earlier") }
            static func earlyBedSubtitle(_ formattedSleep: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_early_bed_subtitle", default: "%@ last night. Aim for 7+ hours"), formattedSleep)
            }
            static var earlyBedRationale: String { RemoteConfigManager.shared.copyString("copy_home_early_bed_rationale", default: "Sleep is your top focus area and you are falling short. Even 30 more minutes makes a real difference.") }

            // Focus: fitness gap
            static func fitnessGapTitle(_ remaining: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_fitness_gap_title", default: "You're %d min from your goal"), remaining)
            }
            static var fitnessGapSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_fitness_gap_subtitle", default: "A brisk walk or quick workout would close the gap") }
            static func fitnessGapRationale(_ remaining: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_fitness_gap_rationale", default: "Fitness is your focus area and you have %d minutes left to hit today's goal."), remaining)
            }

            // Focus: resting HR up
            static var restingHRUpTitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_title", default: "Your resting heart rate is trending up") }
            static var restingHRUpSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_subtitle", default: "Try 10 min of meditation or deep breathing to bring it down") }
            static func restingHRUpRationale(currentRHR: Int, baselineRHR: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_resting_hr_up_rationale", default: "Your resting heart rate is %d beats per minute, above your usual of %d. This could mean your body has not fully recovered, or stress is higher."), currentRHR, baselineRHR)
            }

            // Focus: recovery
            static var focusRecoveryTitle: String { RemoteConfigManager.shared.copyString("copy_home_focus_recovery_title", default: "Focus on recovery today") }
            static func focusRecoverySubtitle(_ readiness: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_focus_recovery_subtitle", default: "Your body is %d%% ready. Light stretching and water will help"), readiness)
            }
            static var focusRecoveryRationale: String { RemoteConfigManager.shared.copyString("copy_home_focus_recovery_rationale", default: "Recovery is your focus area, and today's signals suggest your body has not fully bounced back yet.") }

            // Insight-driven titles
            static func insightEaseOff(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_ease_off", default: "Ease off. %@ needs attention"), metric) }
            static func insightPushHarder(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_push_harder", default: "Push harder. %@ is ready"), metric) }
            static var insightSleepBetter: String { RemoteConfigManager.shared.copyString("copy_home_insight_sleep_better", default: "Improve your sleep tonight") }
            static func insightWorthChecking(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_worth_checking", default: "%@. Worth checking"), metric) }
            static func insightKeepItUp(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_keep_it_up", default: "Keep it up. %@ is solid"), metric) }
        }

        // MARK: - Today's Action Detail

        enum TodaysActionDetail {
            static var doToday: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_do_today", default: "Do Today") }
            static var whatsOffToday: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_whats_off_today", default: "What's off today") }
            static var whatsLeadingToWhat: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_whats_leading_to_what", default: "What's leading to what") }
            static var yourCoachsNotes: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_your_coachs_notes", default: "Your coach's notes") }
            static var todaysWorkout: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_todays_workout", default: "Today's Workout") }
            static var baseline: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_baseline", default: "usual") }
        }

        // MARK: - Weekly Review Section Headers

        enum WeeklyReviewSections {
            static var navigationTitle: String { RemoteConfigManager.shared.copyString("copy_home_weekly_review_sections_navigation_title", default: "Weekly Review") }
        }

        // MARK: - HealthKit Reprompt

        enum HealthKitReprompt {
            static var title: String { RemoteConfigManager.shared.copyString("copy_home_health_kit_reprompt_title", default: "Laso needs access to your health data") }
            static var body: String { RemoteConfigManager.shared.copyString("copy_home_health_kit_reprompt_body", default: "It looks like health data sharing is turned off. Open Settings and turn on the categories you want Laso to track, like heart rate, sleep, and activity.") }
            static var action: String { RemoteConfigManager.shared.copyString("copy_home_health_kit_reprompt_action", default: "Open Settings") }
            static var dismiss: String { RemoteConfigManager.shared.copyString("copy_home_health_kit_reprompt_dismiss", default: "Not Now") }
        }

        // MARK: - Soft Lock (blurred cards until unlock)

        static var softLockBadge: String { RemoteConfigManager.shared.copyString("copy_home_softlock_badge", default: "Unlock to read") }
        static var softLockCTA: String { RemoteConfigManager.shared.copyString("copy_home_softlock_cta", default: "Unlock my report") }
        static func softLockPatterns(_ n: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_softlock_patterns", default: "Patterns found in your data: %d"), n) }

        // MARK: - Lifted view literals
        static var opensTheFullInsightHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_the_full_insight_hint", default: "Opens the full insight") }
        static var opensDetailedMetricViewHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_detailed_metric_view_hint", default: "Opens detailed metric view") }
        static var openScoreGuideButton: String { RemoteConfigManager.shared.copyString("copy_home_open_score_guide_button", default: "Open Score Guide") }
        static var openJournalEntryButton: String { RemoteConfigManager.shared.copyString("copy_home_open_journal_entry_button", default: "Open Journal") }
        static var retryLoadingHealthDataHint: String { RemoteConfigManager.shared.copyString("copy_home_retry_loading_health_data_hint", default: "Retry loading health data") }
        static var opensScoreBreakdownHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_score_breakdown_hint", default: "Opens score breakdown") }
        static var dismissMorningCheckInLabel: String { RemoteConfigManager.shared.copyString("copy_home_dismiss_morning_check_in_label", default: "Dismiss morning check-in") }
        static var closesTheCheckInCardWithoutHint: String { RemoteConfigManager.shared.copyString("copy_home_closes_the_check_in_card_without_hint", default: "Closes the check-in card without submitting") }
        static var submitMorningCheckInLabel: String { RemoteConfigManager.shared.copyString("copy_home_submit_morning_check_in_label", default: "Submit morning check-in") }
        static var savesYourSleepEnergyAndSorenessHint: String { RemoteConfigManager.shared.copyString("copy_home_saves_your_sleep_energy_and_soreness_hint", default: "Saves your sleep, energy, and soreness ratings") }
        static var x: String { RemoteConfigManager.shared.copyString("copy_home_x", default: "·") }
        static var opensYourWeeklyReviewHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_your_weekly_review_hint", default: "Opens your weekly review") }
        static var dismissMilestoneCelebrationLabel: String { RemoteConfigManager.shared.copyString("copy_home_dismiss_milestone_celebration_label", default: "Dismiss milestone celebration") }
        static var hidesTheMilestoneUnlockCardHint: String { RemoteConfigManager.shared.copyString("copy_home_hides_the_milestone_unlock_card_hint", default: "Hides the milestone unlock card") }
        static var opensAskYourDataHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_ask_your_data_hint", default: "Opens Ask Your Data") }
        static var clearSearchLabel: String { RemoteConfigManager.shared.copyString("copy_home_clear_search_label", default: "Clear search") }
        static var removesTheCurrentQuestionAndResultHint: String { RemoteConfigManager.shared.copyString("copy_home_removes_the_current_question_and_result_hint", default: "Removes the current question and result") }
        static var thisAnswerWasHelpfulLabel: String { RemoteConfigManager.shared.copyString("copy_home_this_answer_was_helpful_label", default: "This answer was helpful") }
        static var sendsPositiveFeedbackOnThisAnswerHint: String { RemoteConfigManager.shared.copyString("copy_home_sends_positive_feedback_on_this_answer_hint", default: "Sends positive feedback on this answer") }
        static var thisAnswerWasNotHelpfulLabel: String { RemoteConfigManager.shared.copyString("copy_home_this_answer_was_not_helpful_label", default: "This answer was not helpful") }
        static var sendsNegativeFeedbackOnThisAnswerHint: String { RemoteConfigManager.shared.copyString("copy_home_sends_negative_feedback_on_this_answer_hint", default: "Sends negative feedback on this answer") }
        static var pullsTheLatestHealthDataFromHint: String { RemoteConfigManager.shared.copyString("copy_home_pulls_the_latest_health_data_from_hint", default: "Pulls the latest health data from connected sources") }

        // MARK: - Lifted interpolated view literals
        static func xLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_label", default: "%@: %@"), p0, p1) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_text", default: "%d%%"), p0) }
        static func baselineWithUnitText(_ p0: String, _ p1: String, _ p2: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_baseline_with_unit_text", default: "%@ %@ %@"), p0, p1, p2) }
        static func forecastLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_forecast_label", default: "%@ forecast"), p0) }
        static func confidencePercentValue(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_confidence_percent_value", default: "%@, confidence %d percent"), p0, p1) }
        static func confText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_conf_text", default: "%d%% conf"), p0) }
        static func xText2(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_text2", default: "%@ %@"), p0, p1) }
        static func viewDetailsHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_view_details_hint", default: "View %@ details"), p0) }
        static func ratingOf5Label(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_rating_of5_label", default: "%@ rating %d of 5"), p0, p1) }
        static func selectsOutOf5Hint(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_selects_out_of5_hint", default: "Selects %d out of 5"), p0) }
        static func weeklyReviewScoreWinsLabel(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_weekly_review_score_wins_label", default: "Weekly Review. Score %d. %d wins."), p0, p1) }
        static func dayText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text", default: "%@/day"), p0) }
        static func dayText2(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text2", default: "%@/day"), p0) }
        static func dayText3(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text3", default: "%@/day"), p0) }
        static func insightLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_label", default: "%@ insight: %@"), p0, p1) }
        static func ofMetricsText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_of_metrics_text", default: "%d of %d metrics"), p0, p1) }
        static func confidenceText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_confidence_text", default: "%@ confidence"), p0) }
    }
}
