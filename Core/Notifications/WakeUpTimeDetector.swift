import Foundation
import HealthKit

/// Detects the user's typical wake-up time from HealthKit sleep data.
/// Falls back to 7:00 AM if insufficient data.
enum WakeUpTimeDetector {

    /// Default wake-up time when no sleep data is available.
    static let fallbackHour = 7
    static let fallbackMinute = 0

    /// Sane band for any wake time a scheduler is allowed to fire at. A value
    /// outside it is a detector bug, not a sleep pattern, and firing there means
    /// a push in the middle of the night.
    static let earliestWakeHour = 5
    static let latestWakeHour = 11

    /// Minimum sleep sessions needed to make a reliable estimate.
    private static let minimumSessions = 3

    /// Number of days to look back for sleep data.
    private static let lookbackDays = 14

    /// HealthKit stores one sample per sleep stage, and a short wake-up in the
    /// night leaves a gap between them. Stages closer than this are the same
    /// session.
    private static let sessionGapTolerance: TimeInterval = 60 * 60

    /// Anything shorter than this is a nap, and a nap must never decide the
    /// wake time.
    private static let minimumSessionDuration: TimeInterval = 3 * 60 * 60

    /// A night that starts before midnight and ends after it is one night, so
    /// sessions are bucketed by their end shifted back 12 hours. Without this,
    /// tonight's pre-midnight sleep and this morning's wake land in the same
    /// calendar day and the late-night value wins.
    private static let nightBucketShift: TimeInterval = -12 * 60 * 60

    /// Detect the user's typical wake-up time from recent sleep sessions.
    /// Returns `(hour, minute)` or `nil` if insufficient data.
    static func detect(healthStore: HKHealthStore) async -> (hour: Int, minute: Int)? {
        let sleepType = HKCategoryType(.sleepAnalysis)

        let calendar = Date.cal
        guard let startDate = calendar.date(byAdding: .day, value: -lookbackDays, to: Date()) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                guard error == nil,
                      let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // One wake time per night: the end of that night's last long
                // session.
                var wakeUpTimesByNight: [Date: Date] = [:]
                for session in sleepSessions(from: samples)
                where session.end.timeIntervalSince(session.start) >= minimumSessionDuration {
                    let night = calendar.startOfDay(for: session.end.addingTimeInterval(nightBucketShift))
                    if let existing = wakeUpTimesByNight[night], existing >= session.end { continue }
                    wakeUpTimesByNight[night] = session.end
                }

                continuation.resume(returning: medianWakeTime(from: Array(wakeUpTimesByNight.values)))
            }

            healthStore.execute(query)
        }
    }

    /// The user's typical wake time across a set of nights, or nil below
    /// `minimumSessions` nights — a median of two mornings is not a schedule.
    ///
    /// Shared so onboarding and the background detector agree on one answer.
    /// Onboarding cannot reuse `detect` directly: it already runs its own sleep
    /// query, and a second full 14-day fetch during the flow is wasted work.
    static func medianWakeTime(from wakeTimes: [Date]) -> (hour: Int, minute: Int)? {
        guard wakeTimes.count >= minimumSessions else { return nil }
        let minutes = wakeTimes.map { date -> Int in
            let components = Date.cal.dateComponents([.hour, .minute], from: date)
            return (components.hour ?? fallbackHour) * 60 + (components.minute ?? 0)
        }.sorted()
        // Upper median on an even count, matching the original behaviour.
        let median = minutes[minutes.count / 2]
        return (hour: median / 60, minute: median % 60)
    }

    /// Merge consecutive sleep-stage samples into whole sessions, so a night is
    /// one span instead of dozens of stage rows.
    private static func sleepSessions(from samples: [HKCategorySample]) -> [(start: Date, end: Date)] {
        let asleep = samples
            .filter { isSleepStage($0.value) }
            .sorted { $0.startDate < $1.startDate }

        var sessions: [(start: Date, end: Date)] = []
        for sample in asleep {
            if var last = sessions.last,
               sample.startDate <= last.end.addingTimeInterval(sessionGapTolerance) {
                last.end = max(last.end, sample.endDate)
                sessions[sessions.count - 1] = last
            } else {
                sessions.append((start: sample.startDate, end: sample.endDate))
            }
        }
        return sessions
    }

    /// True for real sleep stages only, so inBed and awake rows never count.
    private static func isSleepStage(_ value: Int) -> Bool {
        value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    }

    /// Force a wake time into the sane band. Every scheduler reads the stored
    /// wake time through this, so a detector bug can never put a push in the
    /// middle of the night again. An out-of-band value is reported, not
    /// swallowed.
    static func clamped(hour: Int, minute: Int, origin: String) -> (hour: Int, minute: Int) {
        let safeHour = min(max(hour, earliestWakeHour), latestWakeHour)
        let safeMinute = (0..<60).contains(minute) ? minute : 0
        guard safeHour != hour || safeMinute != minute else {
            return (hour: hour, minute: minute)
        }

        // A clamped hour makes the original minute meaningless.
        let result = (hour: safeHour, minute: safeHour == hour ? safeMinute : 0)
        AnalyticsBackend.provider.captureError(
            "wake time outside sane band",
            context: "wake_time_clamp",
            metadata: [
                "origin": origin,
                "raw_hour": hour,
                "raw_minute": minute,
                "clamped_hour": result.hour,
                "clamped_minute": result.minute
            ]
        )
        return result
    }

    /// Detect and persist wake-up time. Returns the resolved (hour, minute).
    /// How long a detected wake time is trusted before re-querying HealthKit.
    /// A sleep schedule does not move meaningfully inside a week, and the query
    /// underneath is an unbounded 14-day sleep-stage fetch.
    private static let detectionTTL: TimeInterval = 7 * 24 * 3600

    static func detectAndPersist(healthStore: HKHealthStore) async -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard

        // A user-set anchor short-circuits before the query AND before the
        // writes. Detecting here would overwrite the persisted keys with the
        // detected time, silently reverting the anchor for every scheduler that
        // reads them through `persistedWakeTime`.
        if let anchor = userAnchor { return anchor }

        // Gated at the choke point so both callers inherit it. Without this the
        // detector re-ran its 14-day HealthKit query on every refresh.
        if let last = defaults.object(forKey: AppKeys.Engagement.lastWakeDetection) as? Date,
           Date().timeIntervalSince(last) < detectionTTL,
           defaults.string(forKey: AppKeys.Engagement.wakeTimeSource) != nil {
            return persistedWakeTime
        }

        if let detected = await detect(healthStore: healthStore) {
            let safe = clamped(hour: detected.hour, minute: detected.minute, origin: "detected")
            defaults.set(safe.hour, forKey: AppKeys.Engagement.detectedWakeHour)
            defaults.set(safe.minute, forKey: AppKeys.Engagement.detectedWakeMinute)
            defaults.set("detected", forKey: AppKeys.Engagement.wakeTimeSource)
            defaults.set(Date(), forKey: AppKeys.Engagement.lastWakeDetection)
            return safe
        }

        // A nil detection means "no sleep data OR the query failed" — the two are
        // indistinguishable here. Keep a wake time we once detected rather than
        // letting one HealthKit hiccup move the user's morning notifications to
        // the 7 a.m. guess. The stamp still advances so the query stays throttled.
        if defaults.string(forKey: AppKeys.Engagement.wakeTimeSource) == "detected" {
            defaults.set(Date(), forKey: AppKeys.Engagement.lastWakeDetection)
            return persistedWakeTime
        }

        // Fallback. The stamp is written here too: a user with no sleep data
        // would otherwise re-run the full query on every single refresh.
        defaults.set(fallbackHour, forKey: AppKeys.Engagement.detectedWakeHour)
        defaults.set(fallbackMinute, forKey: AppKeys.Engagement.detectedWakeMinute)
        defaults.set("fallback", forKey: AppKeys.Engagement.wakeTimeSource)
        defaults.set(Date(), forKey: AppKeys.Engagement.lastWakeDetection)
        return (hour: fallbackHour, minute: fallbackMinute)
    }

    /// The wake time the user chose for themselves, or nil if they never did.
    ///
    /// Clamped to the same 5–11 band as detection, and for the same reason:
    /// `NotificationManager.summaryMayBreakQuietHours` grants the daily summary
    /// its quiet-hours exemption only inside that band, so an anchor outside it
    /// would produce a repeating trigger that is dropped, not deferred — a
    /// morning reminder that silently never arrives.
    static var userAnchor: (hour: Int, minute: Int)? {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: AppKeys.Engagement.userWakeAnchorHour) != nil else {
                return nil
            }
            return (
                hour: defaults.integer(forKey: AppKeys.Engagement.userWakeAnchorHour),
                minute: defaults.integer(forKey: AppKeys.Engagement.userWakeAnchorMinute)
            )
        }
        set {
            let defaults = UserDefaults.standard
            guard let newValue else {
                defaults.removeObject(forKey: AppKeys.Engagement.userWakeAnchorHour)
                defaults.removeObject(forKey: AppKeys.Engagement.userWakeAnchorMinute)
                return
            }
            let safe = clamped(hour: newValue.hour, minute: newValue.minute, origin: "anchor")
            defaults.set(safe.hour, forKey: AppKeys.Engagement.userWakeAnchorHour)
            defaults.set(safe.minute, forKey: AppKeys.Engagement.userWakeAnchorMinute)
        }
    }

    /// Read the persisted wake-up time (or fallback if not yet detected).
    /// Clamped on read too, so a value written by an older build cannot
    /// schedule a night-time push.
    static var persistedWakeTime: (hour: Int, minute: Int) {
        // The anchor is a promise: once the user picks a wake time, nothing
        // detected moves it.
        if let anchor = userAnchor { return anchor }

        let defaults = UserDefaults.standard
        // No source key means detection never ran, so the stored zeros are not
        // a real time.
        guard defaults.string(forKey: AppKeys.Engagement.wakeTimeSource) != nil else {
            return (hour: fallbackHour, minute: fallbackMinute)
        }
        return clamped(
            hour: defaults.integer(forKey: AppKeys.Engagement.detectedWakeHour),
            minute: defaults.integer(forKey: AppKeys.Engagement.detectedWakeMinute),
            origin: "persisted"
        )
    }

    /// The anchor as a `Date` on the given day, for the bedtime pipeline.
    /// `SleepNeedCalculator` takes a `targetWakeTime: Date?`, and without this
    /// the wind-down push keeps computing bedtime off a separate wake estimate —
    /// so "we move your bedtime, not your mornings" would not be true.
    static func anchorDate(on day: Date = Date()) -> Date? {
        guard let anchor = userAnchor else { return nil }
        var comps = Date.cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = anchor.hour
        comps.minute = anchor.minute
        comps.calendar = Date.cal
        return Date.cal.date(from: comps)
    }
}
