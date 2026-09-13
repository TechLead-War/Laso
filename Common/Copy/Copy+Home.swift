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
        /// Short confirm label shown on the button after it is marked done.
        static var nextUpMarkedDone: String { RemoteConfigManager.shared.copyString("copy_home_next_up_marked_done", default: "Done") }
        /// The merged life-context entry on the action card. Idle state.
        static var nextUpContextPrompt: String { RemoteConfigManager.shared.copyString("copy_home_next_up_context_prompt", default: "Something going on today? Tell me") }
        /// Active state. %@ is the context display name, e.g. "Unwell".
        static func nextUpContextAdjusted(_ name: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_next_up_context_adjusted", default: "Adjusted for: %@ · change"), name)
        }
        /// The collapsed state after done. The card gives the slot back.
        static var nextUpDoneLogged: String { RemoteConfigManager.shared.copyString("copy_home_next_up_done_logged", default: "Logged. It joins your record.") }

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

        // MARK: - Sleep bank
        //
        // The only number on Home that accumulates. Everything else resets each
        // morning, so without this nothing can say "this has been building all
        // week". Silent until there is a balance worth naming.

        /// The daily action when the balance is the biggest thing about the day.
        static var sleepBankActionTitle: String { RemoteConfigManager.shared.copyString("copy_home_sleep_bank_action_title", default: "Get to bed early tonight") }
        static func sleepBankActionSubtitle(_ amount: String, _ nights: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_sleep_bank_action_subtitle", default: "You are %1$@ down on sleep. %2$d early nights clear it."), amount, nights)
        }
        /// Once clearing the balance would take longer than a week, quoting the
        /// count reads as a punishment rather than a plan.
        static func sleepBankActionSubtitleLong(_ amount: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_sleep_bank_action_subtitle_long", default: "You are %@ down on sleep, and it grew again this week. Tonight is the place to start."), amount)
        }

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

        // Activation banner: first week calibration progress line.
        static var activationFullyCalibrated: String { RemoteConfigManager.shared.copyString("copy_home_activation_fully_calibrated", default: "Fully calibrated") }
        /// %@ is the next milestone name, e.g. "Trend Detected".
        static func activationMilestoneSoon(_ milestone: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_soon", default: "Almost there. %@ unlocking soon"), milestone) }
        /// %1$d is today's day number, %2$@ the next milestone name.
        static func activationMilestoneTomorrow(day: Int, milestone: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_tomorrow", default: "Day %1$d of 7. %2$@ in 1 day"), day, milestone) }
        /// %1$d is today's day number, %2$@ the next milestone name, %3$d the days until it unlocks.
        static func activationMilestoneInDays(day: Int, milestone: String, days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_activation_milestone_in_days", default: "Day %1$d of 7. %2$@ in %3$d days"), day, milestone, days) }

        // Score card (redesigned): one word state + a plain summary + the Why list.
        /// The band a thin reading sits in, e.g. "Likely 61 to 77".
        static func scoreRange(_ low: Int, _ high: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_score_range", default: "Likely %1$d to %2$d"), low, high)
        }
        // Plain-word reasons and their status values.
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
        static var dailyResultDismiss: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_dismiss", default: "Got it") }

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

        // MARK: - Watch This

        static var earlyWarning: String { RemoteConfigManager.shared.copyString("copy_home_early_warning", default: "Worth Noticing") }
        static var severityHigh: String { RemoteConfigManager.shared.copyString("copy_home_severity_high", default: "High") }
        static var severityModerate: String { RemoteConfigManager.shared.copyString("copy_home_severity_moderate", default: "Moderate") }
        static var severityLow: String { RemoteConfigManager.shared.copyString("copy_home_severity_low", default: "Low") }

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
            // Every prompt has to resolve to a real intent in
            // HealthDataQueryEngine. "Ask me how to spend today well" and "What
            // changed in my body last week" matched no metric and no pattern, so
            // tapping them returned an unrelated answer.
            static var conciergePrompts: [String] { RemoteConfigManager.shared.copyArray("copy_home_ask_your_data_concierge_prompts", default: ["Tell me how to make today a great day.", "How is my heart calm signal trending?", "What is affecting my sleep this week?", "Am I getting enough deep sleep?", "Does my exercise affect my recovery?", "What looks unusual in my data right now?", "How consistent is my sleep schedule?"]) }

            static func confidence(_ percent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_ask_your_data_confidence", default: "%d%% confidence"), percent)
            }

            static var suggestedQuestions: [String] { RemoteConfigManager.shared.copyArray("copy_home_suggested_questions", default: ["How is my sleep trending this week?", "What affects my heart calm signal the most?", "Am I getting enough deep sleep?", "How does exercise affect my recovery?", "What is my resting heart rate trend?", "How consistent is my sleep schedule?"]) }

            /// Answer when the user asks about a score the app has not computed.
            static var noScoreYet: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data_no_score_yet", default: "I do not have enough of your data to work out a health score yet. Keep your health data syncing and I will explain the score as soon as there is one.") }
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

            // Live data: high stress
            static var highStressTitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_title", default: "Your stress is higher than usual right now") }
            static var highStressSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_subtitle", default: "Slow breathing (in for 4, hold 4, out 4, hold 4) for 5 min can bring it down. Your body is asking for a reset.") }

            // Live data: low sleep
            static var lowSleepTitle: String { RemoteConfigManager.shared.copyString("copy_home_low_sleep_title", default: "Go easy today") }
            static func lowSleepSubtitle(_ formattedSleep: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_low_sleep_subtitle", default: "Only %@ of sleep. Skip intense workouts. Your body needs to save energy."), formattedSleep)
            }

            // Live data: low readiness
            static var lowReadinessTitle: String { RemoteConfigManager.shared.copyString("copy_home_low_readiness_title", default: "Recovery day. Your body needs it") }
            static func lowReadinessSubtitle(_ readiness: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_low_readiness_subtitle", default: "Your body is %d%% ready. Stretching or yoga only"), readiness)
            }

            // Activity progress: goal reached
            static var exerciseGoalTitle: String { RemoteConfigManager.shared.copyString("copy_home_exercise_goal_title", default: "Exercise goal reached!") }
            static func exerciseGoalSubtitle(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_exercise_goal_subtitle", default: "%d min today. Stay active and drink water"), minutes)
            }

            // Activity progress: minutes to go (good readiness)
            static func minutesToGoTitle(_ remaining: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_minutes_to_go_title", default: "You have %d min to go"), remaining)
            }
            static var minutesToGoSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_minutes_to_go_subtitle", default: "Recovery is strong. A run or workout would be great") }

            // Late hour wind-down
            static var windDownTitle: String { RemoteConfigManager.shared.copyString("copy_home_wind_down_title", default: "Wind down for sleep") }
            static var windDownSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_wind_down_subtitle", default: "Dim screens and skip caffeine for better rest tonight") }

            // Focus: deep sleep
            static var deepSleepTitle: String { RemoteConfigManager.shared.copyString("copy_home_deep_sleep_title", default: "Boost your deep sleep") }
            static func deepSleepSubtitle(_ minutes: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_deep_sleep_subtitle", default: "Only %d min of deep sleep. Try cutting caffeine after 2 PM"), minutes)
            }

            // Focus: bedtime
            static var earlyBedTitle: String { RemoteConfigManager.shared.copyString("copy_home_early_bed_title", default: "Get to bed 30 min earlier") }
            static func earlyBedSubtitle(_ formattedSleep: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_early_bed_subtitle", default: "%@ last night. Aim for 7+ hours"), formattedSleep)
            }

            // Focus: fitness gap
            static func fitnessGapTitle(_ remaining: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_fitness_gap_title", default: "You're %d min from your goal"), remaining)
            }
            static var fitnessGapSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_fitness_gap_subtitle", default: "A brisk walk or quick workout would close the gap") }

            // Focus: resting HR up
            static var restingHRUpTitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_title", default: "Your resting heart rate is trending up") }
            static var restingHRUpSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_subtitle", default: "Try 10 min of meditation or deep breathing to bring it down") }

            // Focus: recovery
            static var focusRecoveryTitle: String { RemoteConfigManager.shared.copyString("copy_home_focus_recovery_title", default: "Focus on recovery today") }
            static func focusRecoverySubtitle(_ readiness: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_focus_recovery_subtitle", default: "Your body is %d%% ready. Light stretching and water will help"), readiness)
            }

            // Insight-driven titles
            static func insightEaseOff(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_ease_off", default: "Ease off. %@ needs attention"), metric) }
            static func insightPushHarder(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_push_harder", default: "Push harder. %@ is ready"), metric) }
            static var insightSleepBetter: String { RemoteConfigManager.shared.copyString("copy_home_insight_sleep_better", default: "Improve your sleep tonight") }
            static func insightWorthChecking(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_worth_checking", default: "%@. Worth checking"), metric) }
            static func insightKeepItUp(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_keep_it_up", default: "Keep it up. %@ is solid"), metric) }
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
        static var openJournalEntryButton: String { RemoteConfigManager.shared.copyString("copy_home_open_journal_entry_button", default: "Open Journal") }
        static var openMirrorMomentButton: String { RemoteConfigManager.shared.copyString("copy_home_open_mirror_moment_button", default: "Open Mirror Moment") }
        static var retryLoadingHealthDataHint: String { RemoteConfigManager.shared.copyString("copy_home_retry_loading_health_data_hint", default: "Retry loading health data") }
        static var dismissMorningCheckInLabel: String { RemoteConfigManager.shared.copyString("copy_home_dismiss_morning_check_in_label", default: "Dismiss morning check-in") }
        static var closesTheCheckInCardWithoutHint: String { RemoteConfigManager.shared.copyString("copy_home_closes_the_check_in_card_without_hint", default: "Closes the check-in card without submitting") }
        static var submitMorningCheckInLabel: String { RemoteConfigManager.shared.copyString("copy_home_submit_morning_check_in_label", default: "Submit morning check-in") }
        static var savesYourSleepEnergyAndSorenessHint: String { RemoteConfigManager.shared.copyString("copy_home_saves_your_sleep_energy_and_soreness_hint", default: "Saves your sleep, energy, and soreness ratings") }
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
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_text", default: "%d%%"), p0) }
        static func ratingOf5Label(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_rating_of5_label", default: "%@ rating %d of 5"), p0, p1) }
        static func selectsOutOf5Hint(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_selects_out_of5_hint", default: "Selects %d out of 5"), p0) }
        static func ofMetricsText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_of_metrics_text", default: "%d of %d metrics"), p0, p1) }
    }
}
