import Foundation

// MARK: - Actionable Metrics

/// Metrics that a user can reasonably influence through behavior changes
enum ActionableMetric {
    /// The ~16 user-controllable metrics for simulation
    static let all: Set<HealthMetric> = [
        .sleepDuration, .sleepDeep, .sleepREM,
        .steps, .activeCalories, .exerciseMinutes, .standHours,
        .heartRateVariability, .restingHeartRate,
        .mindfulMinutes, .timeInDaylight,
        .waterIntake,
        .weight, .bodyFatPercentage,
        .vo2Max,
        .walkingSpeed
    ]

    /// Whether a metric can be simulated
    static func isActionable(_ metric: HealthMetric) -> Bool {
        all.contains(metric)
    }

}
