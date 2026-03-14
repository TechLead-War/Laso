import AppIntents
import SwiftUI

/// "How did I sleep last night?" — Returns last night's sleep summary.
struct SleepSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Sleep Summary"
    static var description = IntentDescription(
        "Returns a summary of your sleep from last night, including duration and quality.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let sleep = await IntentDataProvider.fetchLastNightSleep() else {
            return .result(
                dialog: "I couldn't find sleep data for last night. Make sure your sleep data synced to Apple Health."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "No sleep data for last night")
            }
        }

        let totalFormatted = formatHoursMinutes(sleep.totalHours)
        let deepFormatted = formatHoursMinutes(sleep.deepHours)
        let remFormatted = formatHoursMinutes(sleep.remHours)

        var dialogText = "You slept \(totalFormatted) last night — that's \(sleep.qualityLabel.lowercased()) quality."
        if sleep.deepHours > 0 || sleep.remHours > 0 {
            dialogText += " You got \(deepFormatted) of deep sleep and \(remFormatted) of REM sleep."
        }

        return .result(dialog: IntentDialog(stringLiteral: dialogText)) {
            IntentSnippetViews.SleepSnippet(
                totalHours: sleep.totalHours,
                deepHours: sleep.deepHours,
                remHours: sleep.remHours,
                qualityLabel: sleep.qualityLabel
            )
        }
    }

    private func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 {
            return "\(m) minutes"
        } else if m == 0 {
            return "\(h) hour\(h == 1 ? "" : "s")"
        } else {
            return "\(h)h \(m)m"
        }
    }
}
