import AppIntents
import SwiftUI

/// "What's my health score?" — Returns the current overall health score with a brief summary.
struct HealthScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Health Score"
    static var description = IntentDescription(
        "Returns your current overall health score with a brief summary.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let result = await IntentDataProvider.fetchCurrentHealthScore() else {
            return .result(
                dialog: "I don't have enough health data yet. Open HealthPulse and let it sync with Apple Health first."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "No health data available")
            }
        }

        let dialog = IntentDialog(
            "Your health score is \(result.score) out of 100 — that's a \(result.grade). \(result.summary)"
        )

        return .result(dialog: dialog) {
            IntentSnippetViews.ScoreSnippet(
                score: result.score,
                grade: result.grade,
                summary: result.summary
            )
        }
    }
}
