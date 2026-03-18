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
}

enum BreathworkLiveStatus: String, Codable, Hashable {
    case active
    case paused
    case completed
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
