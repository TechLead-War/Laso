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
    }
}
