import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Lifecycle manager for the evening Wind-Down Live Activity.
/// Mirrors `BreathworkLiveActivityManager` — singleton, analytics-hooked, error-safe.
///
/// Window model (Flighty / Uber-style time-bounded activity):
///   - Eligible to START: now ∈ [bedtime - 60min, bedtime + 0min]
///   - Auto-END: now > bedtime + graceMinutes (default 30)
///
/// We track per-night "dismissed" state in a shared UserDefault so a user-ended
/// activity does not get re-created on the next dashboard refresh.
@MainActor
final class WindDownLiveActivityManager {
    static let shared = WindDownLiveActivityManager()

    /// How early we open the window, relative to target bedtime.
    private static let openMinutesBeforeBedtime = 60
    /// How long past bedtime we keep the activity alive before auto-ending.
    private static let graceMinutesAfterBedtime = 30

    private static let dismissedBedtimeKey = "windDownLiveActivity.dismissedBedtime"

    private var activity: Activity<WindDownActivityAttributes>?
    /// Task observing `activity.activityStateUpdates`. Cancelled and replaced whenever
    /// we start or reattach. A `nil` task means nothing is being observed.
    private var stateObservationTask: Task<Void, Never>?
    /// Set when we end the activity programmatically so the state-update observer
    /// does not double-emit a `user_swiped` event for our own teardown.
    private var programmaticEndInFlight: Bool = false

    private init() {
        activity = Activity<WindDownActivityAttributes>.activities.first
        if let activity {
            observeStateUpdates(activity)
        }
    }

    /// Main entry point — call on each dashboard refresh. Idempotent.
    /// Starts the activity if eligible and not yet running; updates it in-place
    /// if already running; auto-ends if past the grace window.
    func syncWithDashboard(
        recommendedBedtime: Date?,
        hrvMs: Int?,
        hrvIsLow: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        guard let bedtime = recommendedBedtime else {
            endIfRunning(reason: "no_bedtime")
            return
        }

        let now = Date()
        let windowStart = bedtime.addingTimeInterval(-Double(Self.openMinutesBeforeBedtime) * 60)
        let windowEnd = bedtime.addingTimeInterval(Double(Self.graceMinutesAfterBedtime) * 60)

        // Outside window entirely — end anything running from an earlier session.
        guard now >= windowStart else {
            // Bedtime moved later than a live activity expects (recompute pushed the
            // window into the future); tear it down so a stale countdown isn't pinned.
            endIfRunning(reason: "before_window")
            return
        }
        guard now <= windowEnd else {
            endIfRunning(reason: "grace_expired")
            return
        }

        // Respect per-bedtime dismissal so user-ended activities stay ended tonight.
        if wasDismissed(for: bedtime) {
            return
        }

        let state = WindDownActivityAttributes.ContentState(
            targetBedtime: bedtime,
            windDownStartedAt: activity?.content.state.windDownStartedAt ?? now,
            hrvMs: hrvMs,
            hrvIsLow: hrvIsLow
        )
        let staleDate = windowEnd
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let existing = activity ?? Activity<WindDownActivityAttributes>.activities.first {
            activity = existing
            Task {
                await existing.update(content)
            }
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "wind_down",
                state: "updated",
                metadata: metadata(for: state)
            )
            return
        }

        do {
            let newActivity = try Activity.request(
                attributes: WindDownActivityAttributes(userName: nil),
                content: content,
                pushType: nil
            )
            activity = newActivity
            observeStateUpdates(newActivity)
            // Hand the notch over: end the rotating daily TodayScore so the
            // wind-down activity owns the Dynamic Island for the evening window.
            TodayScoreLiveActivityManager.shared.end()
            // Persist the shown bedtime so we can correlate with sleep onset
            // tomorrow morning and emit the PMF sleep outcome event.
            WindDownOutcomeTracker.recordShown(bedtime: bedtime)

            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "wind_down",
                state: "started",
                metadata: metadata(for: state)
            )
        } catch {
            activity = nil
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "wind_down",
                state: "start_failed",
                metadata: [
                    "error": String(describing: error)
                ]
            )
        }
    }

    // MARK: - Private helpers

    private func endIfRunning(reason: String) {
        guard let existing = activity ?? Activity<WindDownActivityAttributes>.activities.first else {
            return
        }
        programmaticEndInFlight = true
        Task {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
        AppAnalytics.shared.trackLiveActivityStateChanged(
            kind: "wind_down",
            state: "ended",
            metadata: [
                "reason": reason
            ]
        )
        stateObservationTask?.cancel()
        stateObservationTask = nil
        self.activity = nil
    }

    /// Observe ActivityKit state transitions so we can detect a user swipe-dismiss
    /// (iOS emits `.dismissed`/`.ended` without our explicit end call) and record it
    /// as a distinct funnel outcome vs. the auto-expire path.
    private func observeStateUpdates(_ activity: Activity<WindDownActivityAttributes>) {
        stateObservationTask?.cancel()
        // Each freshly observed activity starts clean: a prior `endIfRunning` leaves
        // the flag set, and without this reset the next night's genuine user swipe
        // would be misread as our own teardown (skipping analytics + dismissal memory).
        programmaticEndInFlight = false
        stateObservationTask = Task { @MainActor [weak self] in
            for await state in activity.activityStateUpdates {
                guard let self else { return }
                if state == .dismissed || state == .ended {
                    if !self.programmaticEndInFlight {
                        AppAnalytics.shared.trackLiveActivityStateChanged(
                            kind: "wind_down",
                            state: "ended",
                            metadata: [
                                "reason": state == .dismissed ? "user_swiped" : "system_ended"
                            ]
                        )
                        // Remember this bedtime as user-dismissed so we don't
                        // re-spawn the activity later tonight on the same schedule.
                        self.markDismissed(for: activity.content.state.targetBedtime)
                    }
                    self.programmaticEndInFlight = false
                    self.activity = nil
                    self.stateObservationTask = nil
                    return
                }
                // .active / .stale and any future states — keep observing.
                continue
            }
        }
    }

    private func metadata(for state: WindDownActivityAttributes.ContentState) -> [String: Any] {
        var meta: [String: Any] = [
            "bedtime_epoch": Int(state.targetBedtime.timeIntervalSince1970),
            "started_epoch": Int(state.windDownStartedAt.timeIntervalSince1970),
            "hrv_is_low": state.hrvIsLow ? 1 : 0
        ]
        if let hrv = state.hrvMs {
            meta["hrv_ms"] = hrv
        }
        return meta
    }

    private func wasDismissed(for bedtime: Date) -> Bool {
        let stored = UserDefaults.standard.double(forKey: Self.dismissedBedtimeKey)
        guard stored > 0 else { return false }
        // Same-bedtime match within ±5 min so clock drift on bedtime recompute
        // doesn't accidentally re-trigger the activity after a user dismissal.
        return abs(stored - bedtime.timeIntervalSince1970) < 5 * 60
    }

    private func markDismissed(for bedtime: Date) {
        UserDefaults.standard.set(bedtime.timeIntervalSince1970, forKey: Self.dismissedBedtimeKey)
    }
}

#else

@MainActor
final class WindDownLiveActivityManager {
    static let shared = WindDownLiveActivityManager()
    private init() {}

    func syncWithDashboard(recommendedBedtime: Date?, hrvMs: Int?, hrvIsLow: Bool) {}
}

#endif
