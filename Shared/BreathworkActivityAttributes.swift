import ActivityKit
import Foundation

enum BreathworkLiveProtocol: String, Codable, Hashable {
    case cyclicSighing
    case boxBreathing

    var title: String {
        switch self {
        case .cyclicSighing:
            return "Relax"
        case .boxBreathing:
            return "Focus"
        }
    }

    var subtitle: String {
        switch self {
        case .cyclicSighing:
            return "Cyclic Sighing"
        case .boxBreathing:
            return "Box Breathing"
        }
    }

    var symbolName: String {
        switch self {
        case .cyclicSighing:
            return "leaf.fill"
        case .boxBreathing:
            return "square.dashed"
        }
    }

    var totalDuration: TimeInterval {
        switch self {
        case .cyclicSighing:
            return 5 * 60
        case .boxBreathing:
            return 4 * 60
        }
    }

    var phaseDurations: [(phase: BreathworkLivePhase, duration: TimeInterval)] {
        switch self {
        case .cyclicSighing:
            return [
                (.inhale, 2),
                (.inhaleTop, 1),
                (.exhale, 6)
            ]
        case .boxBreathing:
            return [
                (.inhale, 4),
                (.holdAfterInhale, 4),
                (.exhale, 4),
                (.holdAfterExhale, 4)
            ]
        }
    }

    func phase(atElapsed elapsed: TimeInterval) -> BreathworkLivePhase {
        let phases = phaseDurations
        let cycleDuration = phases.reduce(0) { $0 + $1.duration }
        guard cycleDuration > 0 else { return .inhale }

        var remaining = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        for item in phases {
            if remaining < item.duration {
                return item.phase
            }
            remaining -= item.duration
        }
        return phases.last?.phase ?? .inhale
    }
}

enum BreathworkLivePhase: String, Codable, Hashable {
    case inhale
    case inhaleTop
    case holdAfterInhale
    case exhale
    case holdAfterExhale

    var label: String {
        switch self {
        case .inhale, .inhaleTop:
            return "Breathe In"
        case .holdAfterInhale, .holdAfterExhale:
            return "Hold"
        case .exhale:
            return "Breathe Out"
        }
    }

    var symbolName: String {
        switch self {
        case .inhale, .inhaleTop:
            return "arrow.up.circle.fill"
        case .holdAfterInhale, .holdAfterExhale:
            return "pause.circle.fill"
        case .exhale:
            return "arrow.down.circle.fill"
        }
    }

    /// Target scale of the breathing orb for this phase. Inhale grows the orb,
    /// exhale shrinks it, holds keep the boundary size — so the orb tracks the
    /// lungs and gives a glanceable pace cue. Honoured only when Reduce Motion
    /// is off; otherwise the orb stays at a fixed size.
    var orbScale: CGFloat {
        switch self {
        case .inhale:           return 1.0
        case .inhaleTop:        return 1.15
        case .holdAfterInhale:  return 1.15
        case .exhale:           return 0.7
        case .holdAfterExhale:  return 0.7
        }
    }

    /// VoiceOver description of the current breathing phase.
    var accessibilityLabel: String {
        switch self {
        case .inhale, .inhaleTop:
            return "Breathe in"
        case .holdAfterInhale, .holdAfterExhale:
            return "Hold"
        case .exhale:
            return "Breathe out"
        }
    }
}

enum BreathworkLiveStatus: String, Codable, Hashable {
    case active
    case paused
    case completed
}

/// User-facing copy for the Breathwork Live Activity.
///
/// The LasoWidgets extension does NOT compile `Common/Copy`, so widget-rendered
/// strings live here as Swift literals rather than Remote Config lookups. These
/// MUST stay byte-identical to the app-side `copy_live_la_breathwork_*` defaults.
enum BreathworkCopy {
    static let statusPaused = "Session paused"
    static let statusComplete = "Session complete"
    static let paused = "Paused"
    static let remaining = "Remaining"
    static let done = "Done"
    /// Glyph shown in the compact trailing slot while paused.
    static let pausedCompact = "II"
    /// Glyph shown in the compact trailing slot once complete.
    static let completeCompact = "OK"

    static let timerAccessibilityLabel = "Time remaining"
    static let breathingOrbAccessibilityLabel = "Breathing pace"
}

struct BreathworkActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: BreathworkLiveStatus
        var protocolType: BreathworkLiveProtocol
        var currentPhase: BreathworkLivePhase
        var remainingSeconds: Int
        var sessionStartDate: Date
        var sessionEndDate: Date

        var activePhase: BreathworkLivePhase {
            guard status == .active else { return currentPhase }
            return protocolType.phase(atElapsed: max(0, Date().timeIntervalSince(sessionStartDate)))
        }
    }

    var title: String
}
