import AppIntents
import SwiftUI

/// "Show my health trends" — Opens the app to the Explore/trends view.
struct ShowTrendsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Health Trends"
    static var description = IntentDescription(
        "Opens HealthPulse to the Explore tab showing your health trends and analysis.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post a notification that ContentView can observe to switch to the Explore tab
        await MainActor.run {
            NotificationCenter.default.post(
                name: .healthPulseNavigateToExplore,
                object: nil
            )
        }

        return .result(dialog: "Opening your health trends in HealthPulse.")
    }
}

// MARK: - Navigation Notification

extension Notification.Name {
    static let healthPulseNavigateToExplore = Notification.Name("healthPulseNavigateToExplore")
}
