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

        /// Caption on the average line drawn across the weekly chart.
        static func yourAverage(_ value: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_your_average", default: "Your average %d"), value)
        }
        static var scaleLow: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_low", default: "Low") }
        static var scaleHigh: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_high", default: "High") }
        static var scaleAndDirection: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_scale_and_direction", default: "out of 100  ·  Lower is better") }
        /// Suffix beside a stress value. The caller passes the live ceiling from
        /// `StressScale.maxScore`, because a hardcoded copy string kept reading
        /// "/ 3" long after the scale moved to 0 to 100, so every tooltip and
        /// weekly box showed a value out of the wrong maximum.
        static func scaleSuffix(max: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_scale_suffix_max", default: "/ %d"), max)
        }

        // MARK: - Drivers

        /// Driver tile value. The fraction is a departure from the person's
        /// own baseline, so it reads as a gap, never as an absolute reading.
        static func driverOffUsual(_ pct: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_stress_monitor_driver_off_usual", default: "%d%% off usual"), pct)
        }
        static var hrvDeviation: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_hrv_deviation", default: "Heart Rate Variability") }
        static var hrElevation: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_hr_elevation", default: "Heart Rate") }

        // MARK: - History

        static var sevenDayStress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_seven_day_stress", default: "7-Day Stress") }

        // MARK: - Tips

        static var reduceStress: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_reduce_stress", default: "Reduce Stress") }
        static var startBreathingExercise: String { RemoteConfigManager.shared.copyString("copy_stress_monitor_stress_monitor_start_breathing_exercise", default: "Start Breathing Exercise") }

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
