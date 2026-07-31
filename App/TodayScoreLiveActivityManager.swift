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

    /// One push's worth of dashboard signals, kept so the boundary re-push can
    /// re-render the island with honest data (and the original capture time)
    /// when a rendering rule flips without a fresh refresh.
    private struct Inputs {
        let overallScore: Int
        let weakestPillar: String
        let weakestPillarScore: Int?
        let steps: Int
        let stepsGoal: Int
        let hrvMs: Int?
        let restingHR: Int?
        let targetBedtime: Date?
        let sleepDebtHours: Double?
        let rhrLatestRaw: Double?
        let rhrBaseline7dRaw: Double?
        let spikeAlertsEnabled: Bool
        let capturedAt: Date
    }

    private var lastInputs: Inputs?
    private var boundaryRepushTask: Task<Void, Never>?

    /// Start a new activity if none is running, otherwise update the existing one.
    /// The manager derives `scoreTint` from `overallScore`, the coaching context
    /// (mode + hero value + insight + action button) from time of day and the
    /// supplied signals, and `stepsProgress` as a computed property on ContentState.
    ///
    /// `rhrLatestRaw` / `rhrBaseline7dRaw` are the unrounded resting HR and its
    /// 7 day average from the same non-stale series `AlertEvaluator` alerts on;
    /// raw doubles so the Guardian threshold compares exactly what the push
    /// compares. nil (stale or missing) disables the heart takeover.
    /// `spikeAlertsEnabled` mirrors the user's heart rate spike toggle so the
    /// island respects the same switch as the pushes.
    func updateOrStart(
        overallScore: Int,
        weakestPillar: String,
        weakestPillarScore: Int?,
        steps: Int,
        stepsGoal: Int,
        hrvMs: Int?,
        restingHR: Int?,
        targetBedtime: Date? = nil,
        sleepDebtHours: Double? = nil,
        rhrLatestRaw: Double? = nil,
        rhrBaseline7dRaw: Double? = nil,
        spikeAlertsEnabled: Bool = false
    ) {
        apply(
            Inputs(
                overallScore: overallScore,
                weakestPillar: weakestPillar,
                weakestPillarScore: weakestPillarScore,
                steps: steps,
                stepsGoal: stepsGoal,
                hrvMs: hrvMs,
                restingHR: restingHR,
                targetBedtime: targetBedtime,
                sleepDebtHours: sleepDebtHours,
                rhrLatestRaw: rhrLatestRaw,
                rhrBaseline7dRaw: rhrBaseline7dRaw,
                spikeAlertsEnabled: spikeAlertsEnabled,
                capturedAt: Date()
            ),
            trigger: "refresh"
        )
    }

    /// Render `inputs` into a push. `trigger` is "refresh" for a dashboard push
    /// and "boundary" for a scheduled re-render at an act/bedtime flip.
    private func apply(_ inputs: Inputs, trigger: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "unavailable",
                metadata: [
                    "overall_score": inputs.overallScore
                ]
            )
            return
        }

        // Wind-down owns the Dynamic Island during its evening window. An evening
        // dashboard refresh would otherwise respawn the rotating TodayScore on top of
        // a live wind-down (two activities in the notch); stand down and let it hold.
        if !Activity<WindDownActivityAttributes>.activities.isEmpty {
            end()
            return
        }

        let mode = CoachMode.current
        let bedtime = Self.displayBedtime(inputs.targetBedtime)
        let alert = Self.deriveGuardianAlert(
            mode: mode,
            rhrLatestRaw: inputs.rhrLatestRaw,
            rhrBaseline7dRaw: inputs.rhrBaseline7dRaw,
            spikeAlertsEnabled: inputs.spikeAlertsEnabled,
            sleepDebtHours: inputs.sleepDebtHours
        )
        let coach = Self.deriveCoachContext(
            mode: mode,
            overallScore: inputs.overallScore,
            weakestPillar: inputs.weakestPillar,
            steps: inputs.steps,
            stepsGoal: inputs.stepsGoal,
            hrvMs: inputs.hrvMs,
            restingHR: inputs.restingHR,
            targetBedtime: bedtime,
            alert: alert
        )

        let contentState = TodayScoreActivityAttributes.ContentState(
            overallScore: inputs.overallScore,
            scoreTint: TodayScoreTint.from(score: inputs.overallScore),
            weakestPillar: inputs.weakestPillar,
            weakestPillarScore: inputs.weakestPillarScore,
            steps: inputs.steps,
            stepsGoal: inputs.stepsGoal,
            hrvMs: inputs.hrvMs,
            restingHR: inputs.restingHR,
            // The original capture time, not Date(): a boundary re-push re-renders
            // old data and must not make it look freshly measured.
            lastUpdated: inputs.capturedAt,
            mode: mode,
            heroValue: coach.value,
            insight: coach.insight,
            actionKind: coach.action,
            targetBedtime: bedtime,
            alert: alert
        )

        lastInputs = inputs
        let midnight = Self.nextLocalMidnight()
        let content = ActivityContent(state: contentState, staleDate: midnight)
        scheduleMidnightTeardown(at: midnight)
        scheduleBoundaryRepush(bedtime: bedtime, before: midnight)

        if let existing = activity ?? Activity<TodayScoreActivityAttributes>.activities.first {
            activity = existing
            Task {
                await existing.update(content)
            }
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "updated",
                metadata: [
                    "overall_score": inputs.overallScore,
                    "score_tint": contentState.scoreTint.rawValue,
                    "mode": mode.rawValue,
                    "hero_value": coach.value,
                    "action_kind": coach.action.rawValue,
                    "alert_kind": alert?.kind.rawValue ?? "none",
                    "has_bedtime": bedtime != nil,
                    "trigger": trigger,
                    "steps": inputs.steps,
                    "steps_goal": inputs.stepsGoal
                ]
            )
            return
        }

        do {
            activity = try Activity.request(
                attributes: TodayScoreActivityAttributes(),
                content: content,
                pushType: nil
            )
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "started",
                metadata: [
                    "overall_score": inputs.overallScore,
                    "score_tint": contentState.scoreTint.rawValue,
                    "mode": mode.rawValue,
                    "hero_value": coach.value,
                    "action_kind": coach.action.rawValue,
                    "alert_kind": alert?.kind.rawValue ?? "none",
                    "has_bedtime": bedtime != nil,
                    "trigger": trigger,
                    "steps": inputs.steps,
                    "steps_goal": inputs.stepsGoal
                ]
            )
        } catch {
            activity = nil
            AppAnalytics.shared.trackLiveActivityStateChanged(
                kind: "today_score",
                state: "start_failed",
                metadata: [
                    "overall_score": inputs.overallScore,
                    "error": String(describing: error)
                ]
            )
        }
    }

    // MARK: - Bedtime display gate

    /// A bedtime further out than this is not "tonight's target" on any sane
    /// schedule; showing a countdown to it would be noise. Display heuristic
    /// only — the clinical recommendation itself lives in SleepNeedCalculator.
    private static let bedtimeDisplayHorizon: TimeInterval = 8 * 3600

    /// Gate the recommended bedtime before it reaches any surface: it must be
    /// ahead but close enough to be tonight's, and not a bedtime whose wind-down
    /// activity the user swipe-dismissed tonight — resurrecting the same
    /// countdown here would override that explicit choice.
    private static func displayBedtime(_ bedtime: Date?) -> Date? {
        guard let bedtime else { return nil }
        let now = Date()
        guard bedtime > now, bedtime.timeIntervalSince(now) <= bedtimeDisplayHorizon else { return nil }
        guard !WindDownLiveActivityManager.shared.userDismissed(bedtime: bedtime) else { return nil }
        return bedtime
    }

    // MARK: - Boundary re-push

    /// Arm a one-shot re-push at the next moment the island's rendering rules
    /// flip: an act boundary (the hour switches in `CoachMode.current`), one
    /// hour before bedtime (the static bedtime clock becomes the live
    /// countdown), or bedtime itself (the countdown becomes "In bed"). Live
    /// Activity views cannot schedule their own re-render, so without this the
    /// pill would hold yesterday's act or an amber 0:00 all night. Best-effort
    /// while the process lives — same ceiling as the midnight teardown; the
    /// next foreground refresh heals anything missed.
    private func scheduleBoundaryRepush(bedtime: Date?, before midnight: Date) {
        boundaryRepushTask?.cancel()
        let now = Date()

        // Act flip hours must match CoachMode.current's windows.
        var candidates: [Date] = [10, 18, 22].compactMap {
            Date.cal.date(bySettingHour: $0, minute: 0, second: 0, of: now)
        }
        if let bedtime {
            candidates.append(bedtime.addingTimeInterval(-3600))
            candidates.append(bedtime)
        }
        guard let next = candidates.filter({ $0 > now && $0 < midnight }).min() else {
            boundaryRepushTask = nil
            return
        }

        boundaryRepushTask = Task { @MainActor [weak self] in
            let delay = next.timeIntervalSinceNow
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try Task.checkCancellation()
                } catch {
                    return
                }
            }
            guard let self, let inputs = self.lastInputs else { return }
            self.apply(inputs, trigger: "boundary")
        }
    }

    /// End the current activity immediately (e.g. at midnight, or user-toggle off).
    func end() {
        midnightTeardownTask?.cancel()
        midnightTeardownTask = nil
        boundaryRepushTask?.cancel()
        boundaryRepushTask = nil
        lastInputs = nil

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

    /// Guardian takeover decision. Mirrors the notification stack's rules so the
    /// island never contradicts the pushes: the heart takeover compares the same
    /// raw doubles against the same 7 day baseline and remote spike multiplier
    /// as `AlertEvaluator`, respects the same anomaly kill switch, and stands
    /// down for triage-grade readings — those carry a "consider a healthcare
    /// provider" push, and a breathe framing here would downgrade it. The sleep
    /// debt takeover uses `SleepDebtTracker.actionableDebtHours` — and only
    /// during the evening act, when the user can still act on it tonight.
    /// Heart wins when both fire: it is acute, debt keeps for an hour.
    private static func deriveGuardianAlert(
        mode: CoachMode,
        rhrLatestRaw: Double?,
        rhrBaseline7dRaw: Double?,
        spikeAlertsEnabled: Bool,
        sleepDebtHours: Double?
    ) -> GuardianAlert? {
        guard !RemoteConfigManager.shared.killAnomalyAlerts else { return nil }
        if spikeAlertsEnabled,
           let rhr = rhrLatestRaw,
           let baseline = rhrBaseline7dRaw,
           baseline > 0 {
            let triage = SafetyTriageEngine.assess(
                metric: .restingHeartRate,
                currentValue: rhr,
                baselineValue: baseline
            )
            if triage.level == .normal,
               rhr > baseline * RemoteConfigManager.shared.heartRateSpikeMultiplier {
                return GuardianAlert(
                    kind: .restingHRElevated,
                    value: Int(rhr.rounded()),
                    baseline: Int(baseline.rounded())
                )
            }
        }
        if mode == .evening,
           let debtHours = sleepDebtHours,
           debtHours >= SleepDebtTracker.actionableDebtHours {
            return GuardianAlert(kind: .sleepDebt, value: Int(debtHours * 60), baseline: nil)
        }
        return nil
    }

    /// Maps time-of-day + current signals to the hero metric, caption and action
    /// button for the Live Activity. Uses `overallScore` as a fallback proxy when
    /// dedicated signals (readiness, strain) are not yet wired in. A Guardian
    /// alert overrides the act's insight and action so every surface (compact,
    /// expanded, lock screen) tells the alert's story with one voice.
    private static func deriveCoachContext(
        mode: CoachMode,
        overallScore: Int,
        weakestPillar: String,
        steps: Int,
        stepsGoal: Int,
        hrvMs: Int?,
        restingHR: Int?,
        targetBedtime: Date?,
        alert: GuardianAlert?
    ) -> CoachContext {
        // An alert overrides the story (insight + action) but keeps the act's
        // hero value: `heroValue` feeds analytics as a 0-100 quantity and must
        // not silently switch units to bpm or debt minutes mid-day.
        if let alert {
            let base = actValue(
                mode: mode, overallScore: overallScore, steps: steps, stepsGoal: stepsGoal
            )
            switch alert.kind {
            case .restingHRElevated:
                return CoachContext(
                    value: base,
                    insight: Copy.CoachActivity.alertRestingHR(current: alert.value, baseline: alert.baseline ?? 0),
                    action: .breathe
                )
            case .sleepDebt:
                return CoachContext(
                    value: base,
                    insight: Copy.CoachActivity.alertSleepDebt,
                    action: .windDown
                )
            }
        }

        switch mode {
        case .morning:
            let readiness = overallScore
            let message: String
            if let hrv = hrvMs {
                message = Copy.CoachActivity.morningWithHRV(hrvMs: hrv, phrase: readinessPhrase(for: readiness))
            } else {
                message = Copy.CoachActivity.morningNoHRV(phrase: readinessPhrase(for: readiness))
            }
            return CoachContext(
                value: readiness,
                insight: message,
                action: .setIntention
            )

        case .day:
            let strainPct = actValue(
                mode: mode, overallScore: overallScore, steps: steps, stepsGoal: stepsGoal
            )

            let insight: String
            let action: CoachActionKind
            if strainPct < 30 {
                insight = Copy.CoachActivity.dayLight
                action = .noop
            } else if strainPct < 70 {
                insight = Copy.CoachActivity.daySteady
                action = .breathe
            } else {
                insight = Copy.CoachActivity.dayHigh
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
            if let bedtime = targetBedtime, bedtime > Date() {
                insight = Copy.CoachActivity.eveningBedtime(time: bedtime.formatted(.dateTime.hour().minute()))
            } else if !weakestPillar.isEmpty {
                insight = Copy.CoachActivity.eveningWeakest(pillar: weakestPillar)
            } else {
                insight = Copy.CoachActivity.eveningGeneric
            }
            return CoachContext(
                value: tonight,
                insight: insight,
                action: .windDown
            )

        case .night:
            let insight: String
            if let rhr = restingHR {
                insight = Copy.CoachActivity.nightRestingHR(bpm: rhr)
            } else {
                insight = Copy.CoachActivity.nightGeneric
            }
            return CoachContext(
                value: overallScore,
                insight: insight,
                action: .noop
            )
        }
    }

    /// The act's 0-100 hero quantity: strain percent during the day act, the
    /// overall score otherwise.
    private static func actValue(mode: CoachMode, overallScore: Int, steps: Int, stepsGoal: Int) -> Int {
        guard mode == .day else { return overallScore }
        guard stepsGoal > 0 else { return 0 }
        return min(100, Int((Double(steps) / Double(stepsGoal)) * 100))
    }

    private static func readinessPhrase(for score: Int) -> String {
        if score >= 85 { return Copy.CoachActivity.strongRecovery }
        if score >= 70 { return Copy.CoachActivity.solidBase }
        if score >= 50 { return Copy.CoachActivity.moderateRecovery }
        return Copy.CoachActivity.goGentle
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
        restingHR: Int?,
        targetBedtime: Date? = nil,
        sleepDebtHours: Double? = nil,
        rhrLatestRaw: Double? = nil,
        rhrBaseline7dRaw: Double? = nil,
        spikeAlertsEnabled: Bool = false
    ) {}

    func end() {}
}

#endif
