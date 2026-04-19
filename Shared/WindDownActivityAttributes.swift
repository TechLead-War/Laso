import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Stages the wind-down activity moves through as bedtime approaches.
/// Derived inside the widget from `targetBedtime` vs. now, so it evolves
/// without requiring a push update each minute.
enum WindDownStage: String, Codable, Hashable, Sendable {
    case approaching    // > 45 min to bedtime
    case softening      // 30 - 45 min
    case imminent       // 10 - 30 min
    case now            // 0 - 10 min
    case passed         // past bedtime, in grace window

    static func stage(minutesToBedtime m: Int) -> WindDownStage {
        if m > 45 { return .approaching }
        if m > 30 { return .softening }
        if m > 10 { return .imminent }
        if m >= 0 { return .now }
        return .passed
    }

    var phrase: String {
        switch self {
        case .approaching: return "Dim the lights"
        case .softening:   return "Soften the pace"
        case .imminent:    return "Put the phone down"
        case .now:         return "Ready for bed"
        case .passed:      return "Sleep well"
        }
    }

    var symbolName: String {
        switch self {
        case .approaching, .softening: return "moon.stars.fill"
        case .imminent, .now:          return "moon.fill"
        case .passed:                  return "zzz"
        }
    }
}

#if canImport(ActivityKit)
struct WindDownActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The user's real, data-derived target bedtime. Locked when the activity starts.
        var targetBedtime: Date
        /// When the wind-down window opened for this session.
        var windDownStartedAt: Date
        /// Last known HRV value in ms (optional hint).
        var hrvMs: Int?
        /// Whether recent HRV is meaningfully below baseline — surfaces a gentler nudge.
        var hrvIsLow: Bool
    }

    /// Static attribute — fixed for the life of the activity.
    var userName: String?
}
#endif
