import AppIntents

/// Provides suggested shortcuts that appear in the Shortcuts app and Spotlight.
struct HealthPulseShortcutsProvider: AppShortcutsProvider {

    /// All app shortcuts exposed to Siri and the Shortcuts app.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HealthScoreIntent(),
            phrases: [
                "What's my health score in \(.applicationName)",
                "Check my health score with \(.applicationName)",
                "How's my health in \(.applicationName)",
                "Show my health score in \(.applicationName)",
                "What's my score in \(.applicationName)"
            ],
            shortTitle: "Health Score",
            systemImageName: "heart.text.clipboard"
        )

        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Track water intake with \(.applicationName)",
                "I drank water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: SleepSummaryIntent(),
            phrases: [
                "How did I sleep in \(.applicationName)",
                "How was my sleep in \(.applicationName)",
                "Sleep summary from \(.applicationName)",
                "Check my sleep with \(.applicationName)",
                "Last night's sleep in \(.applicationName)"
            ],
            shortTitle: "Sleep Summary",
            systemImageName: "bed.double.fill"
        )

        AppShortcut(
            intent: ReadinessIntent(),
            phrases: [
                "What's my readiness in \(.applicationName)",
                "Check my readiness with \(.applicationName)",
                "Am I ready to work out in \(.applicationName)",
                "How's my recovery in \(.applicationName)",
                "Check recovery in \(.applicationName)"
            ],
            shortTitle: "Readiness",
            systemImageName: "bolt.heart.fill"
        )

        AppShortcut(
            intent: ShowTrendsIntent(),
            phrases: [
                "Show my health trends in \(.applicationName)",
                "Open trends in \(.applicationName)",
                "Show my analysis in \(.applicationName)",
                "Health trends in \(.applicationName)"
            ],
            shortTitle: "Health Trends",
            systemImageName: "chart.line.uptrend.xyaxis"
        )

        AppShortcut(
            intent: LogWorkoutIntent(),
            phrases: [
                "Log a workout in \(.applicationName)",
                "Log a \(\.$workoutType) workout in \(.applicationName)",
                "Track workout with \(.applicationName)",
                "I worked out in \(.applicationName)"
            ],
            shortTitle: "Log Workout",
            systemImageName: "figure.run"
        )
    }
}
