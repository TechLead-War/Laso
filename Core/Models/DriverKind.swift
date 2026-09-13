import Foundation

/// One thing pulling on today's readiness. The brief ranks these, the driver
/// detail screen explains one, and a three-week focus is started from one.
///
/// `anomaly` carries its metric so any off-usual signal can be a driver
/// without a case per metric.
enum DriverKind: Hashable, Codable {
    case restDays
    case sleepBalance
    case heartRateBounceBack
    case strainHigh
    case stressHigh
    case anomaly(HealthMetric)

    private static let anomalyPrefix = "anomaly."

    /// Stable string form. Routes, UI test identifiers and analytics carry it,
    /// so a rename here breaks deep links already in the wild.
    var id: String {
        switch self {
        case .restDays:            return "restDays"
        case .sleepBalance:        return "sleepBalance"
        case .heartRateBounceBack: return "heartRateBounceBack"
        case .strainHigh:          return "strainHigh"
        case .stressHigh:          return "stressHigh"
        case .anomaly(let metric): return Self.anomalyPrefix + metric.rawValue
        }
    }

    static func fromIdentifier(_ raw: String) -> DriverKind? {
        switch raw {
        case "restDays":            return .restDays
        case "sleepBalance":        return .sleepBalance
        case "heartRateBounceBack": return .heartRateBounceBack
        case "strainHigh":          return .strainHigh
        case "stressHigh":          return .stressHigh
        default:
            guard raw.hasPrefix(anomalyPrefix),
                  let metric = HealthMetric(rawValue: String(raw.dropFirst(anomalyPrefix.count))) else {
                return nil
            }
            return .anomaly(metric)
        }
    }

    /// The signal the driver is read from; the detail screen charts this one.
    var metric: HealthMetric {
        switch self {
        case .restDays:            return .workoutDuration
        case .sleepBalance:        return .sleepDuration
        case .heartRateBounceBack: return .heartRateRecovery
        case .strainHigh:          return .activeCalories
        case .stressHigh:          return .heartRateVariability
        case .anomaly(let metric): return metric
        }
    }

    /// The numbers a focus on this driver tracks, primary first. An anomaly has
    /// none: one off-usual reading is not a three-week programme.
    var focusKPIs: [FocusStore.KPIKind] {
        switch self {
        case .restDays:            return [.restDaysPerWeek, .sleepBalanceHours, .vo2Max]
        case .sleepBalance:        return [.sleepBalanceHours, .deepSleepMinutes, .hrvMs]
        case .heartRateBounceBack: return [.hrrPercentOffUsual, .restingHR, .vo2Max]
        case .strainHigh:          return [.restDaysPerWeek, .restingHR, .hrvMs]
        case .stressHigh:          return [.stressScore, .hrvMs, .restingHR]
        case .anomaly:             return []
        }
    }
}
