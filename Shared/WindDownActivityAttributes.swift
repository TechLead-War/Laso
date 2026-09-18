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

    /// VoiceOver description of the current stage glyph + progress arc.
    var accessibilityLabel: String {
        switch self {
        case .approaching: return "Wind down stage, dimming the lights"
        case .softening:   return "Wind down stage, softening the pace"
        case .imminent:    return "Wind down stage, time to put the phone down"
        case .now:         return "Wind down stage, ready for bed"
        case .passed:      return "Wind down stage, sleep well"
        }
    }
}

/// User-facing copy for the Wind-Down Live Activity.
///
/// The LasoWidgets extension does NOT compile `Common/Copy`, so widget-rendered
/// strings live here as Swift literals rather than Remote Config lookups. These
/// MUST stay byte-identical to the app-side `copy_live_la_winddown_*` defaults.
enum WindDownCopy {
    static let header = "Wind down"
    static let toBed = "To bed"
    static let breatheButton = "Breathe 2 min"
    /// `%d` is the HRV value in ms.
    static let hrvHintTemplate = "HRV %d ms, an earlier night helps"

    static let compactCountdownAccessibilityLabel = "Time until bedtime"
    static let breatheButtonAccessibilityLabel = "Start a two minute wind down breath"
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
}
#endif
