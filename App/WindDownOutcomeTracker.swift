import Foundation

/// Correlates Wind-Down Live Activity exposure with actual sleep onset from HealthKit.
///
/// Flow:
///  1. `recordShown(bedtime:)` is called when the Wind-Down activity starts for the evening,
///     persisting the target bedtime to UserDefaults.
///  2. `evaluatePendingOutcome(healthKitManager:)` runs on each dashboard refresh. Once the
///     stored bedtime is at least `minHoursSinceBedtime` old, we query HealthKit for the first
///     "asleep*" sample inside a window around that bedtime and emit
///     `live_activity_sleep_outcome` with the delta between target and actual sleep onset.
///  3. The pending record is cleared after emission so we emit at most once per wind-down session.
///
/// Never fakes data — if no asleep sample is found in the window, the event still fires but
/// with `sleep_detected=0` and no onset/delta fields. That distinguishes "user did not wear
/// watch" from "user fell asleep late" in PostHog.
@MainActor
enum WindDownOutcomeTracker {
    private static let pendingBedtimeKey = "windDown.outcome.pendingBedtime"
    private static let pendingShownAtKey = "windDown.outcome.pendingShownAt"

    /// Hours to wait after the target bedtime before we consider the outcome evaluable.
    private static let minHoursSinceBedtime: Double = 6
    /// Maximum age (hours) before we give up on a pending outcome record.
    private static let maxPendingAgeHours: Double = 36
    /// How far before the bedtime we scan for sleep onset.
    private static let onsetWindowLookbackHours: Double = 2
    /// How far after the bedtime we scan for sleep onset.
    private static let onsetWindowLookaheadHours: Double = 6

    static func recordShown(bedtime: Date) {
        let defaults = UserDefaults.standard
        defaults.set(bedtime.timeIntervalSince1970, forKey: pendingBedtimeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: pendingShownAtKey)
    }

    /// Idempotent. Call on each dashboard refresh. No-op if no pending record, too fresh,
    /// or already expired beyond `maxPendingAgeHours`.
    static func evaluatePendingOutcome(healthKitManager: HealthKitManager) async {
        let defaults = UserDefaults.standard
        let bedtimeEpoch = defaults.double(forKey: pendingBedtimeKey)
        let shownEpoch = defaults.double(forKey: pendingShownAtKey)
        guard bedtimeEpoch > 0, shownEpoch > 0 else { return }

        let bedtime = Date(timeIntervalSince1970: bedtimeEpoch)
        let now = Date()
        let hoursSinceBedtime = now.timeIntervalSince(bedtime) / 3600

        // Too fresh — user is (probably) still asleep. Wait for tomorrow's refresh.
        guard hoursSinceBedtime >= minHoursSinceBedtime else { return }

        // Too old — expired. Clear and move on to avoid stale emissions.
        guard hoursSinceBedtime <= maxPendingAgeHours else {
            clear()
            return
        }

        let windowStart = bedtime.addingTimeInterval(-onsetWindowLookbackHours * 3600)
        let windowEnd = bedtime.addingTimeInterval(onsetWindowLookaheadHours * 3600)
        let onset = await healthKitManager.fetchFirstSleepOnset(
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        let deltaMinutes: Int? = onset.map { onsetDate in
            Int((onsetDate.timeIntervalSince(bedtime) / 60).rounded())
        }

        AppAnalytics.shared.trackLiveActivitySleepOutcome(
            kind: "wind_down",
            bedtimeEpoch: Int(bedtime.timeIntervalSince1970),
            sleepOnsetEpoch: onset.map { Int($0.timeIntervalSince1970) },
            deltaMinutes: deltaMinutes,
            sleepDetected: onset != nil
        )

        clear()
    }

    private static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: pendingBedtimeKey)
        defaults.removeObject(forKey: pendingShownAtKey)
    }
}
