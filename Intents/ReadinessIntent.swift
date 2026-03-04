import AppIntents
import SwiftUI

/// "What's my readiness?" — Returns readiness/recovery status.
struct ReadinessIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Readiness"
    static var description = IntentDescription(
        "Returns your current readiness and recovery status based on heart rate variability and resting heart rate.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let readiness = await IntentDataProvider.fetchReadiness() else {
            return .result(
                dialog: "I couldn't calculate your readiness. Make sure your Apple Watch has recorded recent HRV and resting heart rate data."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "No readiness data available")
            }
        }

        let readinessLabel = readinessDescription(readiness.readinessScore)
        let dialog = IntentDialog(
            "Your readiness is \(readiness.readinessScore)% — \(readinessLabel). Stress level is \(readiness.stressLabel.lowercased())."
        )

        return .result(dialog: dialog) {
            IntentSnippetViews.ReadinessSnippet(
                readinessScore: readiness.readinessScore,
                stressLevel: readiness.stressLevel,
                stressLabel: readiness.stressLabel
            )
        }
    }

    private func readinessDescription(_ score: Int) -> String {
        switch score {
        case 80...100: return "you're in great shape for intense activity"
        case 60..<80: return "you're ready for moderate activity"
        case 40..<60: return "consider taking it easy today"
        default: return "prioritize rest and recovery"
        }
    }
}
