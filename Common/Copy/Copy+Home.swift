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
        static var nextUpDone: String { RemoteConfigManager.shared.copyString("copy_home_next_up_done", default: "Done. We check the result in tomorrow morning's score.") }

        // Yesterday's result: the loop-closer shown the morning after an action
        // is marked done, reporting how the readiness score moved.
        static var dailyResultHeader: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_header", default: "YESTERDAY'S RESULT") }
        static func dailyResultUp(delta: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_daily_result_up", default: "Your recovery is +%d higher this morning."), delta) }
        static var dailyResultSteady: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_steady", default: "Your recovery held steady. Consistency is what compounds.") }
        static func dailyResultDown(delta: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_daily_result_down", default: "Your recovery dipped %d. Rest is part of the plan too."), delta) }
        static var dailyResultDismiss: String { RemoteConfigManager.shared.copyString("copy_home_daily_result_dismiss", default: "Got it") }

        // MARK: - Empty State

        static var connectHealthData: String { RemoteConfigManager.shared.copyString("copy_home_connect_health_data", default: "Connect Your Health Data") }
        static var connectHealthDescription: String { RemoteConfigManager.shared.copyString("copy_home_connect_health_description", default: "Laso reads from Apple Health. Most other wearables need their apps to share data with Apple Health.") }
        static var worksWith: String { RemoteConfigManager.shared.copyString("copy_home_works_with", default: "Works with") }
        static var syncsAutomatically: String { RemoteConfigManager.shared.copyString("copy_home_syncs_automatically", default: "Syncs automatically") }
        static func viaApp(_ name: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_via_app", default: "Via %@ app"), name) }
        static var howToConnect: String { RemoteConfigManager.shared.copyString("copy_home_how_to_connect", default: "How to connect") }
        static var connectStep1: String { RemoteConfigManager.shared.copyString("copy_home_connect_step1", default: "Open the Settings app on your iPhone") }
        static var connectStep2: String { RemoteConfigManager.shared.copyString("copy_home_connect_step2", default: "Tap Health \u{2192} Data Access & Devices") }
        static var connectStep3: String { RemoteConfigManager.shared.copyString("copy_home_connect_step3", default: "Enable your wearable's companion app") }
        static var connectStep4: String { RemoteConfigManager.shared.copyString("copy_home_connect_step4", default: "Come back here. Data appears automatically.") }
        static var manageDevices: String { RemoteConfigManager.shared.copyString("copy_home_manage_devices", default: "Manage Devices") }
        static var refresh: String { RemoteConfigManager.shared.copyString("copy_home_refresh", default: "Refresh") }

        // MARK: - Connection Status (Home empty state)

        enum ConnectionStatus {
            // Titles
            static var titleWaiting: String { RemoteConfigManager.shared.copyString("copy_home_connection_status_title_waiting", default: "Waiting for your first watch data") }
            static func titleReceiving(_ deviceName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_connection_status_title_receiving", default: "%@ is sending data"), deviceName) }
            static var titleStale: String { RemoteConfigManager.shared.copyString("copy_home_connection_status_title_stale", default: "Your watch has not synced recently") }

            // Descriptions
            static var descriptionWaiting: String { RemoteConfigManager.shared.copyString("copy_home_connection_status_description_waiting", default: "Apple Health is connected. No wearable has shared data yet. If you use a watch, open its app and turn on Apple Health sharing.") }
            static func descriptionReceiving(deviceName: String, sourceName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_connection_status_description_receiving", default: "%@ is syncing through %@. Your dashboard will update as new data comes in."), deviceName, sourceName)
            }
            static func descriptionStale(deviceName: String, lastSync: String, sourceName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_connection_status_description_stale", default: "%@ last shared data %@. Open %@ and run a sync so Laso can catch up."), deviceName, lastSync, sourceName)
            }

            // Badge labels
            static var badgeWaiting: String { RemoteConfigManager.shared.copyString("copy_home_badge_waiting", default: "Waiting") }
            static var badgeConnected: String { RemoteConfigManager.shared.copyString("copy_home_badge_connected", default: "Connected") }
            static var badgeStale: String { RemoteConfigManager.shared.copyString("copy_home_badge_stale", default: "Stale") }
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

        // MARK: - Health Risks

        static var healthRisks: String { RemoteConfigManager.shared.copyString("copy_home_health_risks", default: "Areas to Watch") }

        // MARK: - Trends

        static var trends: String { RemoteConfigManager.shared.copyString("copy_home_trends", default: "Trends") }

        // MARK: - Journal

        static var howWasToday: String { RemoteConfigManager.shared.copyString("copy_home_how_was_today", default: "How was today?") }
        static var journalSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_journal_subtitle", default: "A quick check-in helps track patterns over time") }

        // MARK: - Section & Card Labels

        static var focusAreasTitle: String { RemoteConfigManager.shared.copyString("copy_home_focus_areas_title", default: "Your Focus Areas") }
        static var fromYourData: String { RemoteConfigManager.shared.copyString("copy_home_from_your_data", default: "From Your Data") }
        static var whyThisToday: String { RemoteConfigManager.shared.copyString("copy_home_why_this_today", default: "Why this, today") }
        static var nextWeekTarget: String { RemoteConfigManager.shared.copyString("copy_home_next_week_target", default: "Next week target") }
        static var askYourData: String { RemoteConfigManager.shared.copyString("copy_home_ask_your_data", default: "Ask your data") }
        static var seeSleepTips: String { RemoteConfigManager.shared.copyString("copy_home_see_sleep_tips", default: "See sleep tips \u{2192}") }
        static var wearAppleWatchForRecovery: String { RemoteConfigManager.shared.copyString("copy_home_wear_apple_watch_for_recovery", default: "Wear your Apple Watch to see your live energy") }
        static var tapToUnderstandScore: String { RemoteConfigManager.shared.copyString("copy_home_tap_to_understand_score", default: "Tap to understand your score") }

        // MARK: - Recovery Labels

        static var fullyRecovered: String { RemoteConfigManager.shared.copyString("copy_home_fully_recovered", default: "Fully Recovered") }
        static var wellRecovered: String { RemoteConfigManager.shared.copyString("copy_home_well_recovered", default: "Well Recovered") }
        static var moderate: String { RemoteConfigManager.shared.copyString("copy_home_moderate", default: "Moderate") }
        static var fatigued: String { RemoteConfigManager.shared.copyString("copy_home_fatigued", default: "Fatigued") }
        static var strained: String { RemoteConfigManager.shared.copyString("copy_home_strained", default: "Strained") }

        // MARK: - Recovery State (DashboardViewModel)

        static var moderateRecovery: String { RemoteConfigManager.shared.copyString("copy_home_moderate_recovery", default: "Moderate Recovery") }
        static var lowRecovery: String { RemoteConfigManager.shared.copyString("copy_home_low_recovery", default: "Low Recovery") }

        // Day type labels
        static var greenDayPushHard: String { RemoteConfigManager.shared.copyString("copy_home_green_day_push_hard", default: "Green Day. Push Hard.") }
        static var yellowDayMaintain: String { RemoteConfigManager.shared.copyString("copy_home_yellow_day_maintain", default: "Yellow Day. Maintain.") }
        static var redDayRecover: String { RemoteConfigManager.shared.copyString("copy_home_red_day_recover", default: "Red Day. Recover.") }

        // Simple strain guidance
        static var greenStrainGuidance: String { RemoteConfigManager.shared.copyString("copy_home_green_strain_guidance", default: "High effort training is a great pick. Your body is ready for a challenge.") }
        static var yellowStrainGuidance: String { RemoteConfigManager.shared.copyString("copy_home_yellow_strain_guidance", default: "Moderate activity is best. Focus on form over intensity.") }
        static var redStrainGuidance: String { RemoteConfigManager.shared.copyString("copy_home_red_strain_guidance", default: "Focus on rest and gentle movement. Your body needs recovery time.") }

        // Contextual strain guidance (recovery state × activity trend)
        static var greenImproving: String { RemoteConfigManager.shared.copyString("copy_home_green_improving", default: "Recovery is high and activity is already trending up. Push hard, but avoid a big jump in strain.") }
        static var greenDeclining: String { RemoteConfigManager.shared.copyString("copy_home_green_declining", default: "Recovery is high while recent activity has trended down. Add a hard session to rebuild strain.") }
        static var greenStable: String { RemoteConfigManager.shared.copyString("copy_home_green_stable", default: "Recovery is high. Push hard today with a challenging workout.") }
        static var greenNone: String { RemoteConfigManager.shared.copyString("copy_home_green_none", default: "Recovery is high. Push hard today.") }
        static var yellowImproving: String { RemoteConfigManager.shared.copyString("copy_home_yellow_improving", default: "Recovery is moderate and activity is trending up. Keep strain steady and intensity in check.") }
        static var yellowDeclining: String { RemoteConfigManager.shared.copyString("copy_home_yellow_declining", default: "Recovery is moderate with activity easing off. Stick with a steady, moderate session.") }
        static var yellowStable: String { RemoteConfigManager.shared.copyString("copy_home_yellow_stable", default: "Recovery is moderate. Keep your usual training load today.") }
        static var yellowNone: String { RemoteConfigManager.shared.copyString("copy_home_yellow_none", default: "Recovery is moderate. Aim for a moderate strain today.") }
        static var redImproving: String { RemoteConfigManager.shared.copyString("copy_home_red_improving", default: "Recovery is low after rising activity. Take a recovery day with light movement only.") }
        static var redDeclining: String { RemoteConfigManager.shared.copyString("copy_home_red_declining", default: "Recovery is low. Keep strain very low and focus on sleep, water, and easy movement.") }
        static var redStable: String { RemoteConfigManager.shared.copyString("copy_home_red_stable", default: "Recovery is low. Recover today with easy walking or stretching only.") }
        static var redNone: String { RemoteConfigManager.shared.copyString("copy_home_red_none", default: "Recovery is low. Focus on recovery and avoid hard training.") }

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
            static var howItsCalculatedBody: String { RemoteConfigManager.shared.copyString("copy_home_how_its_calculated_body", default: "Your Health Score is a weighted average across four areas. Areas with more data and more change carry more weight. Each number is scored against your usual, and changes and trends move the score up or down.") }
            static var heartCardioName: String { RemoteConfigManager.shared.copyString("copy_home_heart_cardio_name", default: "Heart & Cardio") }
            static var heartCardioDetail: String { RemoteConfigManager.shared.copyString("copy_home_heart_cardio_detail", default: "Resting heart rate, HRV, and cardio fitness") }
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
            /// Card proof line shown on the home card below the subtitle
            static func followedAdviceImproved(count: Int, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_followed_advice_improved", default: "The last %d times you followed this advice, your %@ got better"), count, metric)
            }

            /// Proof line for recovery staying green after pushing hard
            static func recoveryStayedGreen(goodCount: Int, totalCount: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_recovery_stayed_green", default: "When you were in this state before and pushed hard, recovery stayed green %d out of %d times"), goodCount, totalCount)
            }

            /// General proof line referencing personal history timeframe
            static func basedOnHistory(days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_based_on_history", default: "Based on your personal history over %d days"), days)
            }

            /// Short proof line for the home card when we have a win rate
            static func thingsWentWell(count: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_things_went_well", default: "The last %d times you were in this state and followed this advice, things went well"), count)
            }

            /// Detail view section title
            static var whatHappenedBefore: String { RemoteConfigManager.shared.copyString("copy_home_what_happened_before", default: "What happened before") }

            /// Detail: no history yet
            static var notEnoughHistory: String { RemoteConfigManager.shared.copyString("copy_home_not_enough_history", default: "We are still learning your patterns. After a few more days of data, this section will show how past tips worked out for you.") }

            /// Detail: summary of positive outcomes
            static func pastOutcomeSummary(improved: Int, total: Int, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_past_outcome_summary", default: "Out of %d similar tips, %d led to a real improvement in your %@"), total, improved, metric)
            }

            /// Detail: timeframe context
            static func trackingWindow(days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_action_proof_tracking_window", default: "Based on your data from the last %d days"), days)
            }
        }

        // MARK: - Recovery Hero Why Lines

        enum RecoveryHero {
            static func whyLineGreen(topFactor: String, secondFactor: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_recovery_hero_why_line_green", default: "%@ and %@"), topFactor, secondFactor)
            }
            static func whyLineYellow(topFactor: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_recovery_hero_why_line_yellow", default: "%@, keeping recovery moderate"), topFactor)
            }
            static func whyLineRed(topFactor: String, secondFactor: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_recovery_hero_why_line_red", default: "%@ and %@"), topFactor, secondFactor)
            }

            // Factor descriptions (positive)
            static var hrvBounced: String { RemoteConfigManager.shared.copyString("copy_home_hrv_bounced", default: "HRV bounced back") }
            static var hrvHigh: String { RemoteConfigManager.shared.copyString("copy_home_hrv_high", default: "HRV is above your usual") }
            static var rhrLow: String { RemoteConfigManager.shared.copyString("copy_home_rhr_low", default: "resting heart rate is low") }
            static var rhrDropped: String { RemoteConfigManager.shared.copyString("copy_home_rhr_dropped", default: "resting heart rate dropped back down") }
            static var sleepSolid: String { RemoteConfigManager.shared.copyString("copy_home_sleep_solid", default: "solid night of sleep") }
            static var sleepGreat: String { RemoteConfigManager.shared.copyString("copy_home_sleep_great", default: "sleep was long and restorative") }
            static var sleepGood: String { RemoteConfigManager.shared.copyString("copy_home_sleep_good", default: "decent sleep duration") }

            // Factor descriptions (negative)
            static var hrvLow: String { RemoteConfigManager.shared.copyString("copy_home_hrv_low", default: "HRV has not recovered yet") }
            static var hrvBelow: String { RemoteConfigManager.shared.copyString("copy_home_hrv_below", default: "HRV is below your usual") }
            static var rhrElevated: String { RemoteConfigManager.shared.copyString("copy_home_rhr_elevated", default: "resting heart rate is higher than usual") }
            static var rhrHigh: String { RemoteConfigManager.shared.copyString("copy_home_rhr_high", default: "resting heart rate is still high") }
            static var sleepShort: String { RemoteConfigManager.shared.copyString("copy_home_sleep_short", default: "sleep was short") }
            static var sleepPoor: String { RemoteConfigManager.shared.copyString("copy_home_sleep_poor", default: "sleep quality was low") }
            static var recentHardWorkout: String { RemoteConfigManager.shared.copyString("copy_home_recent_hard_workout", default: "still recovering from a hard workout") }
        }

        // MARK: - Greeting

        enum Greeting {
            static var goodMorning: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_morning", default: "Good Morning") }
            static var goodAfternoon: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_afternoon", default: "Good Afternoon") }
            static var goodEvening: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_evening", default: "Good Evening") }
            static var goodNight: String { RemoteConfigManager.shared.copyString("copy_home_greeting_good_night", default: "Good Night") }

            static func streakBadge(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_greeting_streak_badge", default: "%d days"), days) }
            static func streakMilestone(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_greeting_streak_milestone", default: "%d day streak!"), days) }

            // Morning
            static var morningGreen: String { RemoteConfigManager.shared.copyString("copy_home_greeting_morning_green", default: "Your body is recovered and ready. Great day to push hard.") }
            static var morningYellow: String { RemoteConfigManager.shared.copyString("copy_home_greeting_morning_yellow", default: "Recovery is moderate. Steady effort today, nothing extreme.") }
            static var morningRed: String { RemoteConfigManager.shared.copyString("copy_home_greeting_morning_red", default: "Your body needs rest. Take it easy and try to get a good night's sleep tonight.") }

            // Afternoon
            static var afternoonGreen: String { RemoteConfigManager.shared.copyString("copy_home_greeting_afternoon_green", default: "Still looking strong. Good time for a workout if you have not done one yet.") }
            static var afternoonYellow: String { RemoteConfigManager.shared.copyString("copy_home_greeting_afternoon_yellow", default: "Holding steady. Keep the pace moderate this afternoon.") }
            static var afternoonRed: String { RemoteConfigManager.shared.copyString("copy_home_greeting_afternoon_red", default: "Recovery is still low. Light movement and water are your best bet.") }

            // Evening
            static var eveningGreen: String { RemoteConfigManager.shared.copyString("copy_home_greeting_evening_green", default: "Solid day. Wind down and protect your sleep tonight.") }
            static var eveningYellow: String { RemoteConfigManager.shared.copyString("copy_home_greeting_evening_yellow", default: "Decent day overall. An early bedtime would help recovery.") }
            static var eveningRed: String { RemoteConfigManager.shared.copyString("copy_home_greeting_evening_red", default: "Tough day for your body. Get to bed early tonight.") }

            // Night
            static var nightGreen: String { RemoteConfigManager.shared.copyString("copy_home_greeting_night_green", default: "Good day. Rest well tonight and you will wake up strong.") }
            static var nightYellow: String { RemoteConfigManager.shared.copyString("copy_home_greeting_night_yellow", default: "Your body could use a solid night. Try to get to sleep soon.") }
            static var nightRed: String { RemoteConfigManager.shared.copyString("copy_home_greeting_night_red", default: "Your body is running low. Sleep is the most important thing right now.") }
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
            static var conciergePrompts: [String] { RemoteConfigManager.shared.copyArray("copy_home_ask_your_data_concierge_prompts", default: ["Ask me how to spend today well.", "How is my HRV trending?", "What is affecting my sleep this week?", "Am I getting enough deep sleep?", "How does exercise shift my recovery?", "What changed in my body last week?", "How consistent is my sleep schedule?"]) }

            static func confidence(_ percent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_ask_your_data_confidence", default: "%d%% confidence"), percent)
            }

            static var suggestedQuestions: [String] { RemoteConfigManager.shared.copyArray("copy_home_suggested_questions", default: ["How is my sleep this week?", "What affects my HRV the most?", "Am I getting enough deep sleep?", "How does exercise affect my recovery?", "What is my resting heart rate trend?", "How consistent is my sleep schedule?"]) }
        }

        // MARK: - Recovery Info

        enum RecoveryInfo {
            static var title: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_title", default: "How Your Score Works") }
            static var description: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_description", default: "Each morning your Recovery is locked in from last night's sleep and your overnight heart rate data. As you move and burn energy through the day, the number drops to show your live Energy. Take off the Apple Watch and the live drain pauses, but your morning Recovery still stays on the screen.") }

            // Score levels
            static var scoreLevels: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_score_levels", default: "Score levels") }
            static var fullyRecoveredRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_range", default: "80 to 100") }
            static var fullyRecoveredLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_label", default: "Fully Recovered") }
            static var fullyRecoveredDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_fully_recovered_description", default: "Your body is well rested. Great day for a hard workout.") }
            static var moderateRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_range", default: "50 to 79") }
            static var moderateLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_label", default: "Moderate") }
            static var moderateDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_moderate_description", default: "Decent recovery. Moderate effort is best today.") }
            static var lowRange: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_range", default: "Below 50") }
            static var lowLabel: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_label", default: "Low Recovery") }
            static var lowDescription: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_low_description", default: "Your body needs rest. Focus on easy movement and sleep.") }

            // How it's calculated
            static var howItsCalculated: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_how_its_calculated", default: "How it\u{2019}s calculated") }
            static var howItsCalculatedBody: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_how_its_calculated_body", default: "Recovery is a weighted score from signals measured while you sleep. Each signal is compared to your usual. The further off it is, the more it affects the score.") }
            static var hrvName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_name", default: "Heart Rate Variability") }
            static var hrvWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_weight", default: "40% weight") }
            static var hrvDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_hrv_detail", default: "Higher HRV means better recovery and lower stress. Compared to your usual.") }
            static var restingHRName: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_name", default: "Resting Heart Rate") }
            static var restingHRWeight: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_weight", default: "35% weight") }
            static var restingHRDetail: String { RemoteConfigManager.shared.copyString("copy_home_recovery_info_resting_hr_detail", default: "Lower resting HR means your heart is recovering well. Compared to your usual.") }
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
                    return String(format: RemoteConfigManager.shared.copyString("copy_home_wear_requirement_named", default: "Wear your %@ overnight so it can measure HRV and resting heart rate while you sleep."), deviceName)
                }
                return RemoteConfigManager.shared.copyString("copy_home_wear_requirement_default", default: "Wear your Apple Watch overnight so it can measure HRV and resting heart rate while you sleep.")
            }

            // Refresh timing
            static var whenItUpdatesTitle: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_title", default: "When does it update?") }
            static var whenItUpdatesBody: String { RemoteConfigManager.shared.copyString("copy_home_when_it_updates_body", default: "Your Recovery is set once each morning from last night's signals and stays as the day's anchor. The number on Home then drains live as you burn energy. If you take the watch off, the morning Recovery stays put. If you do not have a morning reading yet and the watch is off, the score is hidden until your next overnight wear.") }
        }

        // MARK: - Recovery Trend (7-day HRV caption)

        enum RecoveryTrend {
            static var improving: String { RemoteConfigManager.shared.copyString("copy_home_recovery_trend_improving", default: "HRV trending up this week") }
            static var stable: String { RemoteConfigManager.shared.copyString("copy_home_recovery_trend_stable", default: "HRV steady this week") }
            static var declining: String { RemoteConfigManager.shared.copyString("copy_home_recovery_trend_declining", default: "HRV trending down this week") }
        }

        // MARK: - Cycle Phase Card

        enum CyclePhase {
            static func dayOfCycle(day: Int, total: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_cycle_phase_day_of_cycle", default: "Day %d of %d"), day, total) }
        }

        // MARK: - Strain Card

        enum StrainCard {
            static func zoneLabel(_ zone: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_strain_card_zone_label", default: "Z%d"), zone) }
        }

        // MARK: - Cards

        enum Cards {
            // Daily narrative
            static var forYouToday: String { RemoteConfigManager.shared.copyString("copy_home_cards_for_you_today", default: "FOR YOU TODAY") }
            static var readingTodaysSignals: String { RemoteConfigManager.shared.copyString("copy_home_cards_reading_todays_signals", default: "Reading today's signals…") }

            // Personal health forecast
            static var yourForecast: String { RemoteConfigManager.shared.copyString("copy_home_cards_your_forecast", default: "YOUR FORECAST") }
            static var nextSevenDays: String { RemoteConfigManager.shared.copyString("copy_home_cards_next_seven_days", default: "Next 7 days") }

            // Sleep coach card
            static var tonightsGoal: String { RemoteConfigManager.shared.copyString("copy_home_cards_tonights_goal", default: "Tonight's Goal") }
            static func bedBy(_ time: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_cards_bed_by", default: "Bed by %@"), time) }

            // Strain card
            static var todaysStrain: String { RemoteConfigManager.shared.copyString("copy_home_cards_todays_strain", default: "Today's Strain") }

            // Sleep card
            static var lastNightsSleep: String { RemoteConfigManager.shared.copyString("copy_home_cards_last_nights_sleep", default: "Last Night's Sleep") }

            // Stress card
            static var stressLevel: String { RemoteConfigManager.shared.copyString("copy_home_cards_stress_level", default: "Stress Level") }

            // Recovery hero
            static var rightNow: String { RemoteConfigManager.shared.copyString("copy_home_cards_right_now", default: "Right now") }
            static var vsLastWeek: String { RemoteConfigManager.shared.copyString("copy_home_cards_vs_last_week", default: "vs last week") }

            // Today briefing
            static var generatedByLasoIntelligence: String { RemoteConfigManager.shared.copyString("copy_home_cards_generated_by_laso_intelligence", default: "Generated by Laso intelligence") }

            // Correlations section
            static var seeAll: String { RemoteConfigManager.shared.copyString("copy_home_cards_see_all", default: "See all") }
        }

        // MARK: - Smart Action Recommendations

        enum SmartAction {
            // Default fallback
            static var defaultTitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_title", default: "Get moving for 15 minutes") }
            static var defaultSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_subtitle", default: "A short walk boosts mood, energy, and sleep quality tonight") }
            static var defaultRationale: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_default_rationale", default: "No specific signals today. A walk is the simplest, highest payoff activity for overall health.") }

            // Live data: high stress
            static var highStressTitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_title", default: "Your stress is higher than usual right now") }
            static var highStressSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_smart_action_high_stress_subtitle", default: "Box breathing (4-4-4-4) for 5 min can bring it down. Your body is asking for a reset.") }
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
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_low_readiness_subtitle", default: "Readiness is %d%%. Stretching or yoga only"), readiness)
            }
            static var lowReadinessRationale: String { RemoteConfigManager.shared.copyString("copy_home_low_readiness_rationale", default: "A few signals (HRV, resting HR, sleep) suggest your body has not recovered from recent strain.") }

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
            static var deepSleepRationale: String { RemoteConfigManager.shared.copyString("copy_home_deep_sleep_rationale", default: "Deep sleep is when your body repairs muscle, locks in memory, and balances hormones. You are getting less than the 45-minute mark.") }

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
            static var restingHRUpTitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_title", default: "Your resting HR is trending up") }
            static var restingHRUpSubtitle: String { RemoteConfigManager.shared.copyString("copy_home_resting_hr_up_subtitle", default: "Try 10 min of meditation or deep breathing to bring it down") }
            static func restingHRUpRationale(currentRHR: Int, baselineRHR: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_resting_hr_up_rationale", default: "Your resting heart rate is %d bpm, above your usual of %d bpm. This could hint at incomplete recovery or higher stress."), currentRHR, baselineRHR)
            }

            // Focus: recovery
            static var focusRecoveryTitle: String { RemoteConfigManager.shared.copyString("copy_home_focus_recovery_title", default: "Focus on recovery today") }
            static func focusRecoverySubtitle(_ readiness: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_home_smart_action_focus_recovery_subtitle", default: "Readiness is %d%%. Light stretching and water will help"), readiness)
            }
            static var focusRecoveryRationale: String { RemoteConfigManager.shared.copyString("copy_home_focus_recovery_rationale", default: "Recovery is your focus area and your readiness score suggests your body has not fully bounced back yet.") }

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
            static var baseline: String { RemoteConfigManager.shared.copyString("copy_home_todays_action_detail_baseline", default: "baseline") }
        }

        // MARK: - Weekly Review Section Headers

        enum WeeklyReviewSections {
            static var navigationTitle: String { RemoteConfigManager.shared.copyString("copy_home_weekly_review_sections_navigation_title", default: "Weekly Review") }
            static var progressiveCoach: String { RemoteConfigManager.shared.copyString("copy_home_weekly_review_sections_progressive_coach", default: "Progressive Coach") }
            static var nextWeek: String { RemoteConfigManager.shared.copyString("copy_home_weekly_review_sections_next_week", default: "Next Week") }
            static var keyDiscovery: String { RemoteConfigManager.shared.copyString("copy_home_weekly_review_sections_key_discovery", default: "Key Discovery") }
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
        static var bodyInsightBriefingLabel: String { RemoteConfigManager.shared.copyString("copy_home_body_insight_briefing_label", default: "Body insight briefing") }
        static var opensTheFullInsightsScreenHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_the_full_insights_screen_hint", default: "Opens the full insights screen") }
        static var opensTheFullInsightHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_the_full_insight_hint", default: "Opens the full insight") }
        static var seeAllCorrelationsLabel: String { RemoteConfigManager.shared.copyString("copy_home_see_all_correlations_label", default: "See all correlations") }
        static var opensTheFullHealthIntelligenceViewHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_the_full_health_intelligence_view_hint", default: "Opens the full health intelligence view") }
        static var viewMetricDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_metric_details_hint", default: "View metric details") }
        static var viewBrainHealthDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_brain_health_details_hint", default: "View brain health details") }
        static var opensDetailedMetricViewHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_detailed_metric_view_hint", default: "Opens detailed metric view") }
        static var viewSleepCoachDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_sleep_coach_details_hint", default: "View sleep coach details") }
        static var opensGuidanceForTodaySRecommendedHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_guidance_for_today_s_recommended_hint", default: "Opens guidance for today's recommended action") }
        static var openScoreGuideButton: String { RemoteConfigManager.shared.copyString("copy_home_open_score_guide_button", default: "Open Score Guide") }
        static var retryLoadingHealthDataHint: String { RemoteConfigManager.shared.copyString("copy_home_retry_loading_health_data_hint", default: "Retry loading health data") }
        static var viewCycleTrackingDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_cycle_tracking_details_hint", default: "View cycle tracking details") }
        static var viewStrainDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_strain_details_hint", default: "View strain details") }
        static var viewRiskDetailsAndRecommendationsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_risk_details_and_recommendations_hint", default: "View risk details and recommendations") }
        static var opensScoreBreakdownHint: String { RemoteConfigManager.shared.copyString("copy_home_opens_score_breakdown_hint", default: "Opens score breakdown") }
        static var viewStressMonitorDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_stress_monitor_details_hint", default: "View stress monitor details") }
        static func strainCardLabel(value: String, level: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_strain_card_label", default: "Today's strain %@, %@"), value, level)
        }
        static func stressCardLabel(score: String, level: String, trend: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_home_stress_card_label", default: "Stress level %@, %@, trending %@"), score, level, trend)
        }
        static var timePeriodSelectorLabel: String { RemoteConfigManager.shared.copyString("copy_home_time_period_selector_label", default: "Time period selector") }
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
        static var viewSleepDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_sleep_details_hint", default: "View sleep details") }
        static var viewVitalityAgeDetailsHint: String { RemoteConfigManager.shared.copyString("copy_home_view_vitality_age_details_hint", default: "View vitality age details") }
        static var pullsTheLatestHealthDataFromHint: String { RemoteConfigManager.shared.copyString("copy_home_pulls_the_latest_health_data_from_hint", default: "Pulls the latest health data from connected sources") }

        // MARK: - Lifted interpolated view literals
        static func xLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_label", default: "%@: %@"), p0, p1) }
        static func leadsToLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_leads_to_label", default: "%@ leads to %@"), p0, p1) }
        static func correlationValue(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_correlation_value", default: "%@ correlation"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_text", default: "%d"), p0) }
        static func sleepStageDurationText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_sleep_stage_duration_text", default: "%@ %@"), p0, p1) }
        static func baselineWithUnitText(_ p0: String, _ p1: String, _ p2: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_baseline_with_unit_text", default: "%@ %@ %@"), p0, p1, p2) }
        static func brainHealthScoreOutOfLabel(_ p0: Int, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_brain_health_score_out_of_label", default: "Brain Health score %d out of 100, %@"), p0, p1) }
        static func forecastLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_forecast_label", default: "%@ forecast"), p0) }
        static func confidencePercentValue(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_confidence_percent_value", default: "%@, confidence %d percent"), p0, p1) }
        static func confText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_conf_text", default: "%d%% conf"), p0) }
        static func debtText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_debt_text", default: "%@ debt"), p0) }
        static func todaySActionLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_today_s_action_label", default: "Today's action: %@"), p0) }
        static func dayOfDaysUntilNextLabel(_ p0: String, _ p1: Int, _ p2: Int, _ p3: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_of_days_until_next_label", default: "%@, day %d of %d, %d days until next period"), p0, p1, p2, p3) }
        static func worthNoticingText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_worth_noticing_text", default: "%d worth noticing"), p0) }
        static func riskLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_risk_label", default: "%@, %@ risk"), p0, p1) }
        static func metricsLabel(_ p0: Int, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_metrics_label", default: "%d metrics %@"), p0, p1) }
        static func filterToShowMetricsHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_filter_to_show_metrics_hint", default: "Filter to show %@ metrics"), p0) }
        static func xText2(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_x_text2", default: "%@ %@"), p0, p1) }
        static func viewDetailsHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_view_details_hint", default: "View %@ details"), p0) }
        static func ratingOf5Label(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_rating_of5_label", default: "%@ rating %d of 5"), p0, p1) }
        static func selectsOutOf5Hint(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_selects_out_of5_hint", default: "Selects %d out of 5"), p0) }
        static func weeklyReviewScoreWinsLabel(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_weekly_review_score_wins_label", default: "Weekly Review. Score %d. %d wins."), p0, p1) }
        static func dayText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text", default: "%@/day"), p0) }
        static func dayText2(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text2", default: "%@/day"), p0) }
        static func dayText3(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_day_text3", default: "%@/day"), p0) }
        static func insightLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_insight_label", default: "%@ insight: %@"), p0, p1) }
        static func lastNightSSleepLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_last_night_s_sleep_label", default: "Last night's sleep %@, %@"), p0, p1) }
        static func vsAvgText(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_vs_avg_text", default: "%@%d%% vs avg"), p0, p1) }
        static func ofMetricsText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_of_metrics_text", default: "%d of %d metrics"), p0, p1) }
        static func confidenceText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_home_confidence_text", default: "%@ confidence"), p0) }
    }
}
