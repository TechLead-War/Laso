import Foundation

#if canImport(ActivityKit)
import ActivityKit

@MainActor
final class BreathworkLiveActivityManager {
    static let shared = BreathworkLiveActivityManager()

    private var activity: Activity<BreathworkActivityAttributes>?
    private var lastContentState: BreathworkActivityAttributes.ContentState?

    private init() {
        activity = Activity<BreathworkActivityAttributes>.activities.first
    }

    func start(
        `protocol`: BreathingProtocol,
        phase: BreathPhase,
        sessionTimeRemaining: Double
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "breathwork",
                state: "unavailable",
                metadata: [
                    "protocol_type": `protocol`.subtitle
                ]
            )
            return
        }

        let contentState = makeContentState(
            protocol: `protocol`,
            phase: phase,
            sessionTimeRemaining: sessionTimeRemaining,
            status: .active
        )
        lastContentState = contentState

        if let activity {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        do {
            activity = try Activity.request(
                attributes: BreathworkActivityAttributes(title: "Breathwork"),
                content: ActivityContent(state: contentState, staleDate: nil),
                pushType: nil
            )
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "breathwork",
                state: "started",
                metadata: [
                    "protocol_type": `protocol`.subtitle,
                    "phase": phase.rawValue,
                    "remaining_sec": max(Int(ceil(sessionTimeRemaining)), 0)
                ]
            )
        } catch {
            activity = nil
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "breathwork",
                state: "start_failed",
                metadata: [
                    "protocol_type": `protocol`.subtitle
                ]
            )
        }
    }

    func update(
        `protocol`: BreathingProtocol,
        phase: BreathPhase,
        sessionTimeRemaining: Double,
        isPaused: Bool
    ) {
        guard let activity else { return }

        let contentState = makeContentState(
            protocol: `protocol`,
            phase: phase,
            sessionTimeRemaining: sessionTimeRemaining,
            status: isPaused ? .paused : .active
        )
        lastContentState = contentState

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
        AppAnalytics.shared.trackLiveActivityStateChanged(
            kind: "breathwork",
            state: isPaused ? "paused" : "updated",
            metadata: [
                "protocol_type": `protocol`.subtitle,
                "phase": phase.rawValue,
                "remaining_sec": max(Int(ceil(sessionTimeRemaining)), 0),
                "is_paused": isPaused ? 1 : 0
            ]
        )
    }

    func end(after delay: TimeInterval) {
        guard let activity else { return }

        let finalState = BreathworkActivityAttributes.ContentState(
            status: .completed,
            protocolType: lastContentState?.protocolType ?? .cyclicSighing,
            currentPhase: .exhale,
            remainingSeconds: 0,
            sessionStartDate: Date(),
            sessionEndDate: Date()
        )

        let policy: ActivityUIDismissalPolicy = delay > 0
            ? .after(Date().addingTimeInterval(delay))
            : .immediate

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: policy
            )
        }

        AppAnalytics.shared.trackLiveActivityStateChanged(
            kind: "breathwork",
            state: "ended",
            metadata: [
                "protocol_type": finalState.protocolType.rawValue,
                "dismiss_after_sec": Int(delay),
                "final_status": finalState.status.rawValue
            ]
        )

        self.activity = nil
        self.lastContentState = nil
    }

    private func makeContentState(
        protocol: BreathingProtocol,
        phase: BreathPhase,
        sessionTimeRemaining: Double,
        status: BreathworkLiveStatus
    ) -> BreathworkActivityAttributes.ContentState {
        let protocolType = BreathworkLiveProtocol(protocol: `protocol`)
        let remainingSeconds = max(Int(ceil(sessionTimeRemaining)), 0)
        let sessionStartDate = Date().addingTimeInterval(-(protocolType.totalDuration - TimeInterval(remainingSeconds)))
        let sessionEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))

        return BreathworkActivityAttributes.ContentState(
            status: status,
            protocolType: protocolType,
            currentPhase: BreathworkLivePhase(phase: phase),
            remainingSeconds: remainingSeconds,
            sessionStartDate: sessionStartDate,
            sessionEndDate: sessionEndDate
        )
    }
}

#else

@MainActor
final class BreathworkLiveActivityManager {
    static let shared = BreathworkLiveActivityManager()

    private init() {}

    func start(protocol: BreathingProtocol, phase: BreathPhase, sessionTimeRemaining: Double) {}
    func update(protocol: BreathingProtocol, phase: BreathPhase, sessionTimeRemaining: Double, isPaused: Bool) {}
    func end(after delay: TimeInterval) {}
}

#endif

private extension BreathworkLiveProtocol {
    init(protocol: BreathingProtocol) {
        switch `protocol` {
        case .cyclicSighing:
            self = .cyclicSighing
        case .boxBreathing:
            self = .boxBreathing
        }
    }
}

private extension BreathworkLivePhase {
    init(phase: BreathPhase) {
        switch phase {
        case .inhale:
            self = .inhale
        case .inhaleTop:
            self = .inhaleTop
        case .holdAfterInhale:
            self = .holdAfterInhale
        case .exhale:
            self = .exhale
        case .holdAfterExhale:
            self = .holdAfterExhale
        }
    }
}
