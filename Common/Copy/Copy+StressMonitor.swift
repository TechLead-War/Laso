import Foundation

extension Copy {
    enum StressMonitor {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_title", default: "Stress Monitor") }

        // MARK: - Level Display Names

        static var levelHigh: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_level_high", default: "High") }
        static var levelElevated: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_level_elevated", default: "Raised") }
        static var levelMild: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_level_mild", default: "Mild") }
        static var levelCalm: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_level_calm", default: "Calm") }

        // MARK: - Empty State

        static var buildingBaselineTitle: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_building_baseline_title", default: "Building your stress baseline") }
        static var needHRVData: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_need_hrv_data", default: "We need about 14 days of overnight HRV data to learn your normal range. Wear your Apple Watch to bed and your stress signal will appear here.") }

        // MARK: - Hero

        static var heroExplainer: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_hero_explainer", default: "How much pressure your body is under right now") }
        static var contextLow: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_context_low", default: "Your body feels relaxed. Good time to focus on work or training.") }
        static var contextMild: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_context_mild", default: "Some tension is building. A few slow breaths can help reset it.") }
        static var contextModerate: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_context_moderate", default: "Your body is showing real strain. Slow down before adding more load.") }
        static var contextHigh: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_context_high", default: "Stress is high. Step back, breathe, and rest well tonight.") }
        static var contextDefault: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_context_default", default: "Tracking your stress signals throughout the day.") }

        // MARK: - Scale

        static var scaleLow: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_low", default: "Low") }
        static var scaleHigh: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_high", default: "High") }
        static var scaleAndDirection: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_and_direction", default: "out of 3  ·  Lower is better") }
        static var scaleSuffix: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_suffix", default: "/ 3") }

        // MARK: - Drivers

        static var whatsDrivingStress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_whats_driving_stress", default: "What Is Driving Your Stress") }
        static var hrvDeviation: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_hrv_deviation", default: "Heart Rate Variability") }
        static var hrElevation: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_hr_elevation", default: "Heart Rate") }

        // MARK: - History

        static var sevenDayStress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_seven_day_stress", default: "7-Day Stress") }

        // MARK: - Tips

        static var reduceStress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_reduce_stress", default: "Reduce Stress") }
        static var startBreathingExercise: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_start_breathing_exercise", default: "Start Breathing Exercise") }
        static var primaryTip: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_primary_tip", default: "Try This First") }
        static var moreTips: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_more_tips", default: "More Ideas") }
        static var moreTipsHint: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_more_tips_hint", default: "Other ways to help your body settle.") }

        // MARK: - Week Delta

        static func weekDeltaImproved(_ thisWeek: String, _ lastWeek: String, _ percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_week_delta_improved", default: "Your stress eased %d%% this week. You are at %@, down from %@ last week."), percent, thisWeek, lastWeek)
        }
        static func weekDeltaIncreased(_ thisWeek: String, _ lastWeek: String, _ percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_week_delta_increased", default: "Your stress rose %d%% this week. You are at %@, up from %@ last week."), percent, thisWeek, lastWeek)
        }
        static func weekDeltaSteady(_ thisWeek: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_week_delta_steady", default: "Your stress is steady at %@ this week, close to last week."), thisWeek)
        }
        static var weekSummaryTitle: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_week_summary_title", default: "This Week") }

        // MARK: - Tips

        static let tipsHigh = [
            "Your body is asking for rest. Lighter activity may help you more right now.",
            "Box breathing can help: inhale 4s, hold 4s, exhale 4s, hold 4s.",
            "A quieter, screen-free space may help your body settle.",
            "Many people find that 8+ hours of sleep tonight helps them feel more resilient tomorrow."
        ]
        static let tipsModerate = [
            "Try a short walk or gentle stretching.",
            "Limiting caffeine and stimulants for the next few hours may help.",
            "Try progressive muscle relaxation.",
            "Shorten your to-do list and focus on essentials."
        ]
        static let tipsMild = [
            "Try a 5-minute breathing exercise.",
            "Step outside for fresh air if possible.",
            "A short walk can help your body reset."
        ]
        static let tipsLow = [
            "Your body is calm. Great time for challenging work.",
            "Maintain this state with regular sleep and hydration.",
            "This is a great time for creative or deep-focus work."
        ]
        static let tipsDefault = [
            "Monitor your stress throughout the day.",
            "Regular breaks can help manage stress levels."
        ]

        // MARK: - Accessibility

        static var startBreathingA11y: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_start_breathing_a11y", default: "Start breathing exercise") }

        // MARK: - Stress Level Display Names (Scorer)

        static var stressLevelLow: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_level_low", default: "Low Stress") }
        static var stressLevelMild: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_level_mild", default: "Mild Stress") }
        static var stressLevelModerate: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_level_moderate", default: "Moderate Stress") }
        static var stressLevelHigh: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_level_high", default: "High Stress") }

        // MARK: - Stress Trend Display Names (Scorer)

        static var trendDecreasing: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_trend_decreasing", default: "Decreasing") }
        static var trendStable: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_trend_stable", default: "Stable") }
        static var trendIncreasing: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_trend_increasing", default: "Increasing") }

        // MARK: - Stress Descriptions (Scorer)

        static var descriptionNoData: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_description_no_data", default: "Not enough data to assess stress yet. Keep heart rate and HRV data syncing to establish your personal baseline.") }

        static func descriptionLow(score: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_low", default: "Your stress level is low (%@/3.0). Your HRV and heart rate are within your normal range. Keep up your current routine. Your body is recovering well."), score)
        }
        static func descriptionMildPrefix(score: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_mild_prefix", default: "Your stress level is mildly elevated (%@/3.0). "), score)
        }
        static func descriptionModeratePrefix(score: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_moderate_prefix", default: "Your stress level is moderate (%@/3.0). "), score)
        }
        static func descriptionHighPrefix(score: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_high_prefix", default: "Your stress level is high (%@/3.0). "), score)
        }
        static func descriptionHRVMention(percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_hrv_mention", default: "Your HRV is %d%% below your baseline. "), percent)
        }
        static func descriptionHRMention(percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_hr_mention", default: "Your heart rate is %d%% above your resting average. "), percent)
        }
        static var descriptionMildSuffix: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_description_mild_suffix", default: "Consider lighter exercise today and prioritize sleep tonight.") }
        static var descriptionModerateSuffix: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_description_moderate_suffix", default: "Focus on recovery: deep breathing, gentle movement, and adequate hydration.") }
        static var descriptionHighSuffix: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_description_high_suffix", default: "Prioritize rest and recovery. Avoid intense exercise, reduce caffeine, and consider mindfulness or breathing exercises.") }
        static func descriptionHighHRVAndHRTyped(hrvPercent: Int, hrPercent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_description_high_hrv_and_hr_typed", default: "Your HRV is %d%% below baseline and heart rate is %d%% elevated. "), hrvPercent, hrPercent)
        }

        // MARK: - Lifted view literals
        static var breathworkNavTitle: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_nav_title", default: "Breathwork") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_stressmonitor_x_text", default: "%@ / %@"), p0, p1) }
        static func ofText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_stressmonitor_of_text", default: "%@ of %@"), p0, p1) }
    }

    enum Breathwork {

        // MARK: - Protocol Descriptions

        static var cyclicSighingDescription: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_cyclic_sighing_description", default: "Double inhale, long exhale. A simple way to calm down fast.") }
        static var boxBreathingDescription: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_box_breathing_description", default: "Equal timed breathing to help you focus and stay steady.") }

        // MARK: - Session

        static var sessionInProgress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_session_in_progress", default: "Your breathing session is still in progress.") }
        static var chooseYourPractice: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_choose_your_practice", default: "Choose Your Practice") }
        static var selectTechnique: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_select_technique", default: "Pick a breathing technique to begin") }
        static var beginSession: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_begin_session", default: "Begin Session") }
        static var sessionComplete: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_session_complete", default: "Session Complete") }
        static var howDoYouFeel: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_how_do_you_feel", default: "How do you feel?") }

        // MARK: - Stop Confirmation

        static var endSessionTitle: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_end_session_title", default: "End Session?") }
        static var endSessionConfirm: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_end_session_confirm", default: "End") }
        static var continueSession: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_continue_session", default: "Continue") }
        static var done: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_breathwork_done", default: "Done") }
    }
}
