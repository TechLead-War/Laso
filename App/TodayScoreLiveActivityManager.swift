import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Lifecycle manager for the "Today's Score" Live Activity.
/// Mirrors `BreathworkLiveActivityManager` — singleton, analytics-hooked,
/// error-safe around `Activity.request`. Local push updates only (pushType: nil).
///
/// The manager also derives time-of-day coaching context (mode, hero number, insight,
/// action kind) internally so callers do not need to change their signature when we
/// evolve the Live Activity's content hierarchy.
@MainActor
final class TodayScoreLiveActivityManager {
    static let shared = TodayScoreLiveActivityManager()

    private var activity: Activity<TodayScoreActivityAttributes>?
    /// One-shot task that ends the activity at local midnight so yesterday's score
    /// can never linger on the lock screen into the new day. Cancelled and replaced
    /// on each `updateOrStart`, and on `end()`.
    private var midnightTeardownTask: Task<Void, Never>?

    private init() {
        // Reattach to any activity that survived an app restart so we update
        // the existing one instead of spawning a duplicate.
        activity = Activity<TodayScoreActivityAttributes>.activities.first
    }

    /// Next local midnight (start of tomorrow) in the user's current calendar/zone.
    /// The score is a per-day value, so this is both the staleness boundary and the
    /// hard teardown point.
    private static func nextLocalMidnight(after now: Date = Date()) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(60 * 60 * 24)
    }

    /// Start a new activity if none is running, otherwise update the existing one.
    /// The manager derives `scoreTint` from `overallScore`, the coaching context
    /// (mode + hero value + insight + action button) from time of day and the
    /// supplied signals, and `stepsProgress` as a computed property on ContentState.
    func updateOrStart(
        overallScore: Int,
        weakestPillar: String,
        weakestPillarScore: Int?,
        steps: Int,
        stepsGoal: Int,
        hrvMs: Int?,
        restingHR: Int?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "unavailable",
                metadata: [
                    "overall_score": overallScore
                ]
            )
            return
        }

        let mode = CoachMode.current
        let coach = Self.deriveCoachContext(
            mode: mode,
            overallScore: overallScore,
            weakestPillar: weakestPillar,
            steps: steps,
            stepsGoal: stepsGoal,
            hrvMs: hrvMs,
            restingHR: restingHR
        )

        let contentState = TodayScoreActivityAttributes.ContentState(
            overallScore: overallScore,
            scoreTint: TodayScoreTint.from(score: overallScore),
            weakestPillar: weakestPillar,
            weakestPillarScore: weakestPillarScore,
            steps: steps,
            stepsGoal: stepsGoal,
            hrvMs: hrvMs,
            restingHR: restingHR,
            lastUpdated: Date(),
            mode: mode,
            heroValue: coach.value,
            insight: coach.insight,
            actionKind: coach.action
        )

        let midnight = Self.nextLocalMidnight()
        let content = ActivityContent(state: contentState, staleDate: midnight)
        scheduleMidnightTeardown(at: midnight)

        if let existing = activity ?? Activity<TodayScoreActivityAttributes>.activities.first {
            activity = existing
            Task {
                await existing.update(content)
            }
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "updated",
                metadata: [
                    "overall_score": overallScore,
                    "score_tint": contentState.scoreTint.rawValue,
                    "mode": mode.rawValue,
                    "hero_value": coach.value,
                    "action_kind": coach.action.rawValue,
                    "steps": steps,
                    "steps_goal": stepsGoal
                ]
            )
            return
        }

        do {
            activity = try Activity.request(
                attributes: TodayScoreActivityAttributes(userName: nil),
                content: content,
                pushType: nil
            )
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "started",
                metadata: [
                    "overall_score": overallScore,
                    "score_tint": contentState.scoreTint.rawValue,
                    "mode": mode.rawValue,
                    "hero_value": coach.value,
                    "action_kind": coach.action.rawValue,
                    "steps": steps,
                    "steps_goal": stepsGoal
                ]
            )
        } catch {
            activity = nil
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "start_failed",
                metadata: [
                    "overall_score": overallScore,
                    "error": String(describing: error)
                ]
            )
        }
    }

    /// End the current activity immediately (e.g. at midnight, or user-toggle off).
    func end() {
        midnightTeardownTask?.cancel()
        midnightTeardownTask = nil

        guard let existing = activity ?? Activity<TodayScoreActivityAttributes>.activities.first else {
            return
        }

        Task {
            await existing.end(nil, dismissalPolicy: .immediate)
        }

        AppAnalytics.shared.trackLiveActivityStateChanged(
            kind: "today_score",
            state: "ended",
            metadata: [:]
        )

        self.activity = nil
    }

    /// Arm a one-shot task that ends the activity at local midnight. Replaces any
    /// prior task so the deadline always tracks the latest `updateOrStart`. The
    /// sleep is best-effort while the process is alive; the midnight `staleDate`
    /// is the system-side backstop if the app is suspended before this fires.
    private func scheduleMidnightTeardown(at midnight: Date) {
        midnightTeardownTask?.cancel()
        midnightTeardownTask = Task { @MainActor [weak self] in
            let delay = midnight.timeIntervalSinceNow
            if delay > 0 {
                // Sleep throws CancellationError if a newer updateOrStart cancels
                // this task; checkCancellation guards the post-sleep teardown too.
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try Task.checkCancellation()
                } catch {
                    return
                }
            }
            self?.end()
        }
    }

    // MARK: - Coach Context Derivation

    private struct CoachContext {
        let value: Int
        let insight: String
        let action: CoachActionKind
    }

    /// Maps time-of-day + current signals to the hero metric, caption and action
    /// button for the Live Activity. Uses `overallScore` as a fallback proxy when
    /// dedicated signals (readiness, strain) are not yet wired in.
    private static func deriveCoachContext(
        mode: CoachMode,
        overallScore: Int,
        weakestPillar: String,
        steps: Int,
        stepsGoal: Int,
        hrvMs: Int?,
        restingHR: Int?
    ) -> CoachContext {
        switch mode {
        case .morning:
            let readiness = overallScore
            let message: String
            if let hrv = hrvMs {
                message = "HRV \(hrv) ms. \(readinessPhrase(for: readiness))."
            } else {
                message = "\(readinessPhrase(for: readiness)). Set the tone for today."
            }
            return CoachContext(
                value: readiness,
                insight: message,
                action: .setIntention
            )

        case .day:
            let strainPct: Int
            if stepsGoal > 0 {
                strainPct = min(100, Int((Double(steps) / Double(stepsGoal)) * 100))
            } else {
                strainPct = 0
            }

            let insight: String
            let action: CoachActionKind
            if strainPct < 30 {
                insight = "Light load so far. Small movement helps."
                action = .noop
            } else if strainPct < 70 {
                insight = "Steady strain. One short reset keeps you sharp."
                action = .breathe
            } else {
                insight = "High strain today. A 2 minute reset will help."
                action = .breathe
            }

            return CoachContext(
                value: strainPct,
                insight: insight,
                action: action
            )

        case .evening:
            let tonight = overallScore
            let insight: String
            if !weakestPillar.isEmpty {
                insight = "Weakest today: \(weakestPillar). Wind down supports tomorrow."
            } else {
                insight = "Wind down now to set up a strong tomorrow."
            }
            return CoachContext(
                value: tonight,
                insight: insight,
                action: .windDown
            )

        case .night:
            let insight: String
            if let rhr = restingHR {
                insight = "Resting heart rate \(rhr). Resume at sunrise."
            } else {
                insight = "Sleep in progress. Resume at sunrise."
            }
            return CoachContext(
                value: overallScore,
                insight: insight,
                action: .noop
            )
        }
    }

    private static func readinessPhrase(for score: Int) -> String {
        if score >= 85 { return "Strong recovery" }
        if score >= 70 { return "Solid base" }
        if score >= 50 { return "Moderate recovery" }
        return "Go gentle today"
    }
}

#else

@MainActor
final class TodayScoreLiveActivityManager {
    static let shared = TodayScoreLiveActivityManager()

    private init() {}

    func updateOrStart(
        overallScore: Int,
        weakestPillar: String,
        weakestPillarScore: Int?,
        steps: Int,
        stepsGoal: Int,
        hrvMs: Int?,
        restingHR: Int?
    ) {}

    func end() {}
}

#endif
