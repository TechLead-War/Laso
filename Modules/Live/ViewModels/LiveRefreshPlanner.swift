import Foundation

struct LiveRefreshPlanner {
    struct State: Equatable {
        var lastMediumFetch: Date?
        var lastSlowFetch: Date?
    }

    struct Decision: Equatable {
        let shouldFetchFast: Bool
        let shouldFetchMedium: Bool
        let shouldFetchSlow: Bool
    }

    let mediumInterval: TimeInterval
    let slowInterval: TimeInterval

    init(
        mediumInterval: TimeInterval = 300,
        slowInterval: TimeInterval = 600
    ) {
        self.mediumInterval = mediumInterval
        self.slowInterval = slowInterval
    }

    func decisionForTieredRefresh(now: Date, state: State) -> Decision {
        Decision(
            shouldFetchFast: true,
            shouldFetchMedium: isDue(state.lastMediumFetch, now: now, interval: mediumInterval),
            shouldFetchSlow: isDue(state.lastSlowFetch, now: now, interval: slowInterval)
        )
    }

    func decisionForDeferredStreamingRefresh(now: Date, state: State) -> Decision {
        Decision(
            shouldFetchFast: false,
            shouldFetchMedium: isDue(state.lastMediumFetch, now: now, interval: mediumInterval),
            shouldFetchSlow: isDue(state.lastSlowFetch, now: now, interval: slowInterval)
        )
    }

    func markFullRefresh(at now: Date, state: inout State) {
        state.lastMediumFetch = now
        state.lastSlowFetch = now
    }

    func apply(_ decision: Decision, at now: Date, state: inout State) {
        if decision.shouldFetchMedium {
            state.lastMediumFetch = now
        }
        if decision.shouldFetchSlow {
            state.lastSlowFetch = now
        }
    }

    private func isDue(_ lastFetch: Date?, now: Date, interval: TimeInterval) -> Bool {
        guard let lastFetch else { return true }
        return now.timeIntervalSince(lastFetch) >= interval
    }
}
