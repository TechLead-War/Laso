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

    /// Slider step increment appropriate for each metric's scale
    static func sliderStep(for metric: HealthMetric) -> Double {
        switch metric {
        case .sleepDuration, .sleepDeep, .sleepREM: return 0.25        // 15-minute increments
        case .steps: return 500
        case .activeCalories: return 50
        case .exerciseMinutes: return 5
        case .standHours: return 1
        case .heartRateVariability: return 2                            // ms
        case .restingHeartRate: return 1                                // bpm
        case .mindfulMinutes: return 5
        case .timeInDaylight: return 10
        case .waterIntake: return 250                                   // mL
        case .weight: return 0.5                                        // kg
        case .bodyFatPercentage: return 0.5                             // %
        case .vo2Max: return 1                                          // mL/kg/min
        case .walkingSpeed: return 0.1                                  // km/h
        default: return 1
        }
    }

    /// Simulation range for a metric: ±2σ clamped to physiological bounds
    static func simulationRange(for metric: HealthMetric, baseline: UserBaseline) -> ClosedRange<Double> {
        let normalRange = RulesConfiguration.normalRange(for: metric)
        let physiologicalLow = min(normalRange.low, normalRange.high)
        let physiologicalHigh = max(normalRange.low, normalRange.high)

        let mean = baseline.mean.isFinite ? baseline.mean : (physiologicalLow + physiologicalHigh) / 2
        let standardDeviation = baseline.standardDeviation.isFinite
            ? max(0, baseline.standardDeviation)
            : 0

        let low = max(physiologicalLow, mean - 2 * standardDeviation)
        let high = min(physiologicalHigh, mean + 2 * standardDeviation)

        // Ensure range has positive width so Slider step doesn't crash
        guard low < high else {
            let clampedMean = min(max(mean, physiologicalLow), physiologicalHigh)
            let halfStep = sliderStep(for: metric)
            return (clampedMean - halfStep)...(clampedMean + halfStep)
        }

        return low...high
    }
}

// MARK: - Effort Level

/// How much effort a behavioral change requires
enum EffortLevel: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    var displayName: String {
        switch self {
        case .low: return "Easy"
        case .medium: return "Moderate"
        case .high: return "Hard"
        }
    }

    static func < (lhs: EffortLevel, rhs: EffortLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
