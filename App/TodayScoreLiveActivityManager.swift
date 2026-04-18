import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Lifecycle manager for the "Today's Score" Live Activity.
/// Mirrors `BreathworkLiveActivityManager` — singleton, analytics-hooked,
/// error-safe around `Activity.request`. Local push updates only (pushType: nil).
@MainActor
final class TodayScoreLiveActivityManager {
    static let shared = TodayScoreLiveActivityManager()

    /// 30 minutes of staleness — after which iOS shows the Live Activity as outdated
    /// until the next `updateOrStart` call refreshes it.
    private static let stalenessInterval: TimeInterval = 60 * 30

    private var activity: Activity<TodayScoreActivityAttributes>?

    private init() {
        // Reattach to any activity that survived an app restart so we update
        // the existing one instead of spawning a duplicate.
        activity = Activity<TodayScoreActivityAttributes>.activities.first
    }

    /// Start a new activity if none is running, otherwise update the existing one.
    /// The manager derives `scoreTint` from `overallScore` and `stepsProgress`
    /// is a computed property on `ContentState`, so callers only pass raw fields.
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

        let contentState = TodayScoreActivityAttributes.ContentState(
            overallScore: overallScore,
            scoreTint: TodayScoreTint.from(score: overallScore),
            weakestPillar: weakestPillar,
            weakestPillarScore: weakestPillarScore,
            steps: steps,
            stepsGoal: stepsGoal,
            hrvMs: hrvMs,
            restingHR: restingHR,
            lastUpdated: Date()
        )

        let staleDate = Date().addingTimeInterval(Self.stalenessInterval)
        let content = ActivityContent(state: contentState, staleDate: staleDate)

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
