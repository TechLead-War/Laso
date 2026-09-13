import Foundation

extension Copy {
    enum StressMonitor {

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
