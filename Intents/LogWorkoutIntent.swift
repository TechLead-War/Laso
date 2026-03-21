import AppIntents
import SwiftUI

/// "Log workout". Quick-log a workout type with duration.
struct LogWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Workout"
    static var description = IntentDescription(
        "Quickly log a workout to Apple Health with a type and duration.",
        categoryName: "Health"
    )

    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Workout Type",
        description: "The type of workout you did",
        requestValueDialog: "What type of workout did you do?"
    )
    var workoutType: WorkoutTypeAppEnum

    @Parameter(
        title: "Duration (minutes)",
        description: "How long was the workout in minutes",
        requestValueDialog: "How many minutes was the workout?"
    )
    var durationMinutes: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$durationMinutes) minute \(\.$workoutType) workout")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard durationMinutes > 0 else {
            return .result(
                dialog: "Duration must be greater than zero."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Invalid duration")
            }
        }

        guard durationMinutes <= 480 else {
            return .result(
                dialog: "That's over 8 hours! Please enter a shorter duration."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Duration too long")
            }
        }

        let success = await IntentDataProvider.logWorkout(
            type: workoutType.hkActivityType,
            durationMinutes: durationMinutes
        )

        await MainActor.run {
            AppAnalytics.shared.trackBlockTap(
                title: "Log Workout",
                type: .siriShortcutPerformed,
                screen: .home,
                metadata: [
                    "shortcut": "log_workout",
                    "workout_type": workoutType.rawValue,
                    "duration_minutes": durationMinutes,
                    "success": success
                ]
            )
        }

        if success {
            let workoutName = workoutType.rawValue
            let formattedDuration = formatDuration(durationMinutes)
            let dialog = IntentDialog("Logged a \(formattedDuration) \(workoutName) workout to Apple Health.")

            return .result(dialog: dialog) {
                IntentSnippetViews.WorkoutSnippet(
                    workoutType: workoutType,
                    durationMinutes: durationMinutes
                )
            }
        } else {
            return .result(
                dialog: "Failed to log the workout. Make sure Laso has write access to Apple Health."
            ) {
                IntentSnippetViews.ErrorSnippet(message: "Could not save workout")
            }
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        if minutes < 60 {
            return "\(Int(minutes)) minute"
        } else {
            let h = Int(minutes / 60)
            let m = Int(minutes.truncatingRemainder(dividingBy: 60))
            if m == 0 {
                return "\(h) hour"
            }
            return "\(h)h \(m)m"
        }
    }
}
