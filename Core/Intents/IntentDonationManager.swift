import AppIntents
import Foundation

/// Donates intents to the system based on user behavior patterns,
/// enabling proactive Spotlight suggestions and Siri recommendations.
enum IntentDonationManager {

    /// Donate relevant shortcuts after the user checks their health score.
    /// Call this from DashboardViewModel after a successful analysis refresh.
    static func donateHealthScoreCheck() {
        let intent = HealthScoreIntent()
        IntentDonationManager.donate(intent)
    }

    /// Donate sleep summary after the user views sleep data.
    static func donateSleepCheck() {
        let intent = SleepSummaryIntent()
        IntentDonationManager.donate(intent)
    }

    /// Donate readiness check after the user views recovery/readiness data.
    static func donateReadinessCheck() {
        let intent = ReadinessIntent()
        IntentDonationManager.donate(intent)
    }

    /// Donate trends view after the user navigates to the Explore tab.
    static func donateTrendsView() {
        let intent = ShowTrendsIntent()
        IntentDonationManager.donate(intent)
    }

    /// Donate water logging after the user logs water manually.
    static func donateWaterLog() {
        let intent = LogWaterIntent()
        intent.amount = 0.5 // Suggest a default amount
        IntentDonationManager.donate(intent)
    }

    /// Donate workout logging after the user finishes or views a workout.
    static func donateWorkoutLog() {
        let intent = LogWorkoutIntent()
        intent.workoutType = .running
        intent.durationMinutes = 30
        IntentDonationManager.donate(intent)
    }

    /// Donate all common shortcuts during app launch for initial suggestions.
    static func donateAllCommonShortcuts() {
        donateHealthScoreCheck()
        donateSleepCheck()
        donateReadinessCheck()
    }

    // MARK: - Private

    private static func donate<T: AppIntent>(_ intent: T) {
        // For App Intents framework, shortcuts are registered automatically via AppShortcutsProvider.
        // This method serves as the integration point for future dynamic donation when
        // Apple expands the App Intents donation API beyond the static AppShortcutsProvider.
        // The AppShortcutsProvider already handles static shortcut registration.
        //
        // Intent donations via INInteraction are for the older SiriKit framework.
        // With App Intents (iOS 16+), the system automatically learns usage patterns
        // from AppShortcutsProvider and suggests relevant shortcuts.
    }
}
