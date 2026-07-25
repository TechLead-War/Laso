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

                guard wakeUpTimesByNight.count >= minimumSessions else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract hour+minute from each wake-up time and find the median
                let wakeMinutes: [Int] = wakeUpTimesByNight.values.map { date in
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    return (components.hour ?? 7) * 60 + (components.minute ?? 0)
                }.sorted()

                let medianMinutes = wakeMinutes[wakeMinutes.count / 2]
                let hour = medianMinutes / 60
                let minute = medianMinutes % 60

                continuation.resume(returning: (hour: hour, minute: minute))
            }

            healthStore.execute(query)
        }
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
    static func detectAndPersist(healthStore: HKHealthStore) async -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard

        if let detected = await detect(healthStore: healthStore) {
            let safe = clamped(hour: detected.hour, minute: detected.minute, origin: "detected")
            defaults.set(safe.hour, forKey: AppKeys.Engagement.detectedWakeHour)
            defaults.set(safe.minute, forKey: AppKeys.Engagement.detectedWakeMinute)
            defaults.set("detected", forKey: AppKeys.Engagement.wakeTimeSource)
            return safe
        }

        // Fallback
        defaults.set(fallbackHour, forKey: AppKeys.Engagement.detectedWakeHour)
        defaults.set(fallbackMinute, forKey: AppKeys.Engagement.detectedWakeMinute)
        defaults.set("fallback", forKey: AppKeys.Engagement.wakeTimeSource)
        return (hour: fallbackHour, minute: fallbackMinute)
    }

    /// Read the persisted wake-up time (or fallback if not yet detected).
    /// Clamped on read too, so a value written by an older build cannot
    /// schedule a night-time push.
    static var persistedWakeTime: (hour: Int, minute: Int) {
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
}
