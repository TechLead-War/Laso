import Foundation

extension Copy {
    enum HealthStateTimeline {

        // MARK: - Navigation

        static var navigationTitle: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_navigation_title", default: "Health States") }

        // MARK: - Sections

        static var distributionHeader: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_distribution_header", default: "Distribution") }
        static var commonTransitionsHeader: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_common_transitions_header", default: "Common Transitions") }
        static var stateGuideHeader: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_guide_header", default: "State Guide") }

        // MARK: - Empty State

        static var emptyTitle: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_empty_title", default: "Health states are still loading") }
        static var emptyBody: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_empty_body", default: "We need a few days of data to learn your patterns. Open the app over the next week and your health states will start showing up here.") }

        // MARK: - Classifier State Labels

        static var stateRecovery: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_recovery", default: "Recovery") }
        static var statePeakPerformance: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_peak_performance", default: "Peak Performance") }
        static var stateStressed: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_stressed", default: "Stressed") }
        static var stateUnderSlept: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_under_slept", default: "Under-Slept") }
        static var stateActive: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_active", default: "Active") }
        static var stateFatigued: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_fatigued", default: "Fatigued") }
        static var stateResting: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_resting", default: "Resting") }
        static var stateBalanced: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_balanced", default: "Balanced") }
        static var stateRecovering: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_recovering", default: "Recovering") }
        static var stateStrained: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_strained", default: "Strained") }
        static var stateLowEnergy: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_low_energy", default: "Low Energy") }
        static var stateRestful: String { RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_state_restful", default: "Restful") }

        static func transitionNotObserved(from: String, to: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_transition_not_observed", default: "Transition from %@ to %@ not observed."), from, to)
        }

        /// `days` arrives preformatted ("%.0f") so the caller's rounding stays unchanged.
        static func transitionPrediction(to state: String, days: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_health_state_health_state_timeline_transition_prediction", default: "You typically move to %@ in ~%@ days"), state, days)
        }
    }

    // MARK: - Lifted view literals
    enum HealthState {
        static var healthStatesNavTitle: String { RemoteConfigManager.shared.copyString("copy_health_state_health_states_nav_title", default: "Health States") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_healthstate_x_text", default: "%d"), p0) }
        static func xText2(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_healthstate_x_text2", default: "%d"), p0) }
        static func xText3(_ p0: String, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_healthstate_x_text3", default: "%@: %d%%"), p0, p1) }
        static func xText4(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_healthstate_x_text4", default: "%d%%"), p0) }
        static func xText5(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_healthstate_x_text5", default: "%@: %@"), p0, p1) }
    }
}
