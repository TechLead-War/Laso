import AppIntents
import SwiftUI

/// "Log X liters of water". Logs water intake to HealthKit with a specified amount.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water Intake"
    static var description = IntentDescription(
        "Logs water intake to your Health app. Specify the amount in liters.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount (liters)",
        description: "How many liters of water to log",
        requestValueDialog: "How many liters of water would you like to log?"
    )
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) liters of water")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard amount > 0 else {
            return .result(
                dialog: "The amount must be greater than zero."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Invalid amount")
            }
        }

        guard amount <= 10 else {
            return .result(
                dialog: "That seems like a lot! Please enter an amount under 10 liters."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Amount too large")
            }
        }

        let success = await IntentDataProvider.logWater(liters: amount)

        await MainActor.run {
            AppAnalytics.shared.trackBlockTap(
                title: "Log Water",
                type: .siriShortcutPerformed,
                screen: .home,
                metadata: [
                    "shortcut": "log_water",
                    "amount_liters": amount,
                    "success": success
                ]
            )
        }

        if success {
            let mlAmount = Int(amount * 1000)
            let dialog = IntentDialog("Logged \(formatAmount(amount)) of water (\(mlAmount) mL) to Apple Health.")

            return .result(dialog: dialog) {
                IntentSnippetViews.WaterSnippet(liters: amount)
            }
        } else {
            return .result(
                dialog: "Failed to log water. Make sure Laso has write access to Apple Health."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Could not save to Apple Health")
            }
        }
    }

    private func formatAmount(_ liters: Double) -> String {
        if liters == 1.0 {
            return "1 liter"
        } else if liters == Double(Int(liters)) {
            return "\(Int(liters)) liters"
        } else {
            return String(format: "%.1f liters", liters)
        }
    }
}
