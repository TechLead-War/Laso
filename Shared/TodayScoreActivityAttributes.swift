import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

enum TodayScoreTint: String, Codable, Hashable, Sendable {
    case excellent
    case good
    case fair
    case poor

    static func from(score: Int) -> TodayScoreTint {
        if score >= 85 {
            return .excellent
        } else if score >= 70 {
            return .good
        } else if score >= 50 {
            return .fair
        } else {
            return .poor
        }
    }

    var label: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Needs work"
        }
    }

    var symbolName: String {
        switch self {
        case .excellent:
            return "flame.fill"
        case .good:
            return "bolt.fill"
        case .fair:
            return "leaf.fill"
        case .poor:
            return "moon.zzz.fill"
        }
    }
}

/// Time of day window that drives what the Live Activity foregrounds.
/// Morning surfaces readiness, day surfaces strain, evening surfaces wind-down prep, night goes quiet.
enum CoachMode: String, Codable, Hashable, Sendable {
    case morning
    case day
    case evening
    case night

    static var current: CoachMode {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:   return .morning
        case 10..<18:  return .day
        case 18..<22:  return .evening
        default:       return .night
        }
    }

    var headline: String {
        switch self {
        case .morning: return "Readiness"
        case .day:     return "Strain"
        case .evening: return "Tonight"
        case .night:   return "Resting"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .day:     return "bolt.fill"
        case .evening: return "moon.stars.fill"
        case .night:   return "zzz"
        }
    }

    /// Label above the mode's secondary readout in the expanded trailing stack.
    var secondaryLabel: String {
        switch self {
        case .morning: return "HRV"
        case .day:     return "Steps"
        case .evening: return "Score"
        case .night:   return "Score"
        }
    }
}

/// Discriminator for which App Intent the expanded / lock screen action button should fire.
/// `noop` means no button is rendered for this mode.
enum CoachActionKind: String, Codable, Hashable, Sendable {
    case setIntention
    case breathe
    case windDown
    case noop

    var label: String {
        switch self {
        case .setIntention: return "Set intention"
        case .breathe:      return "Breathe 2 min"
        case .windDown:     return "Wind down"
        case .noop:         return ""
        }
    }

    var symbolName: String {
        switch self {
        case .setIntention: return "sparkles"
        case .breathe:      return "wind"
        case .windDown:     return "moon.fill"
        case .noop:         return ""
        }
    }

    /// VoiceOver description of the action button, or `nil` when no button shows.
    var accessibilityLabel: String? {
        switch self {
        case .setIntention: return "Set today's intention"
        case .breathe:      return "Start a two minute breath"
        case .windDown:     return "Start wind down"
        case .noop:         return nil
        }
    }
}

/// Guardian takeover: when a signal crosses a line the island stops being a
/// coach and becomes an alert. The decision (thresholds, baselines, user
/// toggles) is made app-side in `TodayScoreLiveActivityManager`; the widget
/// only renders the payload it is handed, so no clinical logic lives in the
/// widget target.
enum GuardianAlertKind: String, Codable, Hashable, Sendable {
    /// Resting heart rate above the user's 7 day average by the remote spike
    /// multiplier. `value` is the current bpm, `baseline` the 7 day average.
    case restingHRElevated
    /// Sleep debt at or past the actionable threshold, surfaced only in the
    /// evening act when the user can still do something about it tonight.
    /// `value` is the debt in minutes.
    case sleepDebt

    var symbolName: String {
        switch self {
        case .restingHRElevated: return "heart.fill"
        case .sleepDebt:         return "moon.zzz.fill"
        }
    }

    var title: String {
        switch self {
        case .restingHRElevated: return TodayScoreCopy.alertRestingHRTitle
        case .sleepDebt:         return TodayScoreCopy.alertSleepDebtTitle
        }
    }
}

struct GuardianAlert: Codable, Hashable, Sendable {
    var kind: GuardianAlertKind
    /// bpm for `restingHRElevated`, minutes of debt for `sleepDebt`.
    var value: Int
    /// 7 day average bpm; only set for `restingHRElevated`.
    var baseline: Int?
}

/// User-facing copy for the Today's Score Live Activity that is not already a
/// member of `CoachMode` / `CoachActionKind` / `TodayScoreTint`.
///
/// The LasoWidgets extension does NOT compile `Common/Copy`, so widget-rendered
/// strings live here as Swift literals rather than Remote Config lookups. These
/// MUST stay byte-identical to the app-side `copy_live_la_today_*` defaults.
enum TodayScoreCopy {
    /// Unit under the centre score number — the ring + number both read 0–100.
    static let scoreUnit = "Score"
    static let msUnit = "ms"
    static let bpmUnit = "bpm"

    /// `%1$d` is the overall score, `%2$@` is the mode headline. Ring VoiceOver.
    static let ringAccessibilityTemplate = "%2$@. Laso score %1$d out of 100"

    /// `%@` is a short relative duration ("21h"). Appended to the eyebrow when the
    /// score data is older than the staleness window so the user knows the ring is
    /// no longer live. Inline literal because the widget target does not link Firebase.
    static let staleAgeTemplate = "Updated %@ ago"

    // Guardian alert takeover strings. Inline literals for the same reason as
    // above: the widget target has no Firebase, so Remote Config cannot reach here.
    static let alertRestingHRTitle = "Heart rate is elevated"
    static let alertSleepDebtTitle = "Sleep debt"
    /// `%d` is the 7 day average bpm shown under an elevated resting HR value.
    static let alertBaselineTemplate = "Usual for you is about %d bpm"
    static let bpmAtRest = "bpm at rest"
    static let sleepDebtCaption = "of sleep owed"
    /// Trailing label in the evening act once the recommended bedtime has passed.
    static let pastBedtime = "In bed"
    /// VoiceOver label on the live bedtime countdown timers.
    static let bedtimeCountdownAccessibility = "Time until bedtime"
    /// `%@` is the bedtime as a local clock time. VoiceOver label on the static
    /// bedtime clock shown while more than an hour remains.
    static let bedtimeAccessibilityTemplate = "Bedtime %@"
}

#if canImport(ActivityKit)
struct TodayScoreActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var overallScore: Int
        var scoreTint: TodayScoreTint
        var weakestPillar: String
        var weakestPillarScore: Int?
        var steps: Int
        var stepsGoal: Int
        var hrvMs: Int?
        var restingHR: Int?
        var lastUpdated: Date

        /// Time-of-day coaching mode. Drives widget content selection.
        var mode: CoachMode
        /// Hero integer surfaced by the current mode (readiness %, strain %, tonight score, etc).
        var heroValue: Int
        /// Single-line insight. generated server-side from ML context when available.
        var insight: String
        /// Which App Intent button the expanded region should render (or `.noop`).
        var actionKind: CoachActionKind
        /// Tonight's recommended bedtime from `SleepNeedCalculator`. Drives the
        /// evening act's live countdown; nil falls back to showing the score.
        var targetBedtime: Date?
        /// Guardian takeover payload. Non-nil switches every island surface
        /// from coach rendering to alert rendering.
        var alert: GuardianAlert?

        var stepsProgress: Double {
            guard stepsGoal > 0 else { return 0 }
            return min(1.0, Double(steps) / Double(stepsGoal))
        }
    }
}
#endif
