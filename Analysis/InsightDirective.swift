import Foundation

/// The behavioral direction an insight pushes the user toward.
///
/// Each insight carries a directive indicating what action it recommends.
/// The `InsightCoordinator` uses directives to detect conflicting advice
/// (e.g., "rest" vs "exercise more") and resolve them so the user receives
/// a coherent, non-contradictory set of insights.
enum InsightDirective: String, Codable, Hashable, CaseIterable {

    // MARK: - Activity Axis

    /// Reduce physical activity, take recovery day(s)
    case rest
    /// Increase overall activity level (steps, movement, consistency)
    case increaseActivity

    // MARK: - Intensity Axis

    /// Lower workout intensity (but not necessarily total activity)
    case reduceIntensity
    /// Push harder in workouts, increase volume or effort
    case pushHarder

    // MARK: - Sleep Axis

    /// Extend sleep duration
    case sleepMore
    /// Improve sleep quality (timing, environment, consistency)
    case sleepBetter

    // MARK: - Medical Axis

    /// Consult a healthcare provider
    case seekMedical

    // MARK: - Neutral

    /// Continue current behavior — things are going well
    case maintain
    /// Observational insight with no specific behavioral direction
    case informational

    // MARK: - Conflict Detection

    /// Directives that directly contradict this one.
    /// Two insights with mutually conflicting directives cannot coexist
    /// when at least one carries warning+ severity.
    var conflicts: Set<InsightDirective> {
        switch self {
        case .rest:              return [.increaseActivity, .pushHarder]
        case .increaseActivity:  return [.rest, .reduceIntensity]
        case .reduceIntensity:   return [.pushHarder, .increaseActivity]
        case .pushHarder:        return [.rest, .reduceIntensity]
        case .sleepMore:         return []
        case .sleepBetter:       return []
        case .seekMedical:       return []  // never suppressed
        case .maintain:          return []
        case .informational:     return []
        }
    }

    // MARK: - Resolution Priority

    /// Priority for conflict resolution — higher value wins.
    /// Safety-oriented directives (medical, rest) outrank performance pushes.
    var resolutionPriority: Int {
        switch self {
        case .seekMedical:       return 100
        case .rest:              return 80
        case .reduceIntensity:   return 70
        case .sleepMore:         return 60
        case .sleepBetter:       return 50
        case .increaseActivity:  return 40
        case .pushHarder:        return 30
        case .maintain:          return 20
        case .informational:     return 10
        }
    }
}
