import Foundation

extension Copy {
    enum HealthStateTimeline {

        // MARK: - Navigation

        static let navigationTitle = "Health States"

        // MARK: - Sections

        static let distributionHeader = "Distribution"
        static let commonTransitionsHeader = "Common Transitions"
        static let stateGuideHeader = "State Guide"

        // MARK: - Empty State

        static let emptyTitle = "Health states are still loading"
        static let emptyBody = "We need a few days of data to learn your patterns. Open the app over the next week and your health states will start showing up here."

        // MARK: - Classifier State Labels

        static let stateRecovery = "Recovery"
        static let statePeakPerformance = "Peak Performance"
        static let stateStressed = "Stressed"
        static let stateUnderSlept = "Under-Slept"
        static let stateActive = "Active"
        static let stateFatigued = "Fatigued"
        static let stateResting = "Resting"
        static let stateBalanced = "Balanced"
        static let stateRecovering = "Recovering"
        static let stateStrained = "Strained"
        static let stateLowEnergy = "Low Energy"
        static let stateRestful = "Restful"

        static func transitionNotObserved(from: String, to: String) -> String {
            "Transition from \(from) to \(to) not observed."
        }
    }
}
