import Foundation
import HealthKit

/// Detects the user's typical wake-up time from HealthKit sleep data.
/// Falls back to 7:00 AM if insufficient data.
enum WakeUpTimeDetector {

    /// Default wake-up time when no sleep data is available.
    static let fallbackHour = 7
    static let fallbackMinute = 0

    /// Minimum sleep sessions needed to make a reliable estimate.
    private static let minimumSessions = 3

    /// Number of days to look back for sleep data.
    private static let lookbackDays = 14

    /// Cached "yyyy-MM-dd" formatter. avoids reallocating
    /// inside the per-sample loop below.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                guard error == nil,
                      let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Group samples into sleep sessions by date.
                // For each calendar day, find the latest wake-up time (end of last sleep stage).
                var wakeUpTimesByDay: [String: Date] = [:]
                let formatter = dayKeyFormatter

                for sample in samples {
                    // Only consider actual sleep stages (not inBed/awake)
                    let value = sample.value
                    let isSleepStage = value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                        || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue

                    guard isSleepStage else { continue }

                    let dayKey = formatter.string(from: sample.endDate)
                    if let existing = wakeUpTimesByDay[dayKey] {
                        if sample.endDate > existing {
                            wakeUpTimesByDay[dayKey] = sample.endDate
                        }
                    } else {
                        wakeUpTimesByDay[dayKey] = sample.endDate
                    }
                }

                guard wakeUpTimesByDay.count >= minimumSessions else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract hour+minute from each wake-up time and find the median
                let wakeMinutes: [Int] = wakeUpTimesByDay.values.map { date in
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

    /// Detect and persist wake-up time. Returns the resolved (hour, minute).
    static func detectAndPersist(healthStore: HKHealthStore) async -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard

        if let detected = await detect(healthStore: healthStore) {
            defaults.set(detected.hour, forKey: AppKeys.Engagement.detectedWakeHour)
            defaults.set(detected.minute, forKey: AppKeys.Engagement.detectedWakeMinute)
            defaults.set("detected", forKey: AppKeys.Engagement.wakeTimeSource)
            return detected
        }

        // Fallback
        defaults.set(fallbackHour, forKey: AppKeys.Engagement.detectedWakeHour)
        defaults.set(fallbackMinute, forKey: AppKeys.Engagement.detectedWakeMinute)
        defaults.set("fallback", forKey: AppKeys.Engagement.wakeTimeSource)
        return (hour: fallbackHour, minute: fallbackMinute)
    }

    /// Read the persisted wake-up time (or fallback if not yet detected).
    static var persistedWakeTime: (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        let hour = defaults.integer(forKey: AppKeys.Engagement.detectedWakeHour)
        let minute = defaults.integer(forKey: AppKeys.Engagement.detectedWakeMinute)
        if hour == 0 && defaults.string(forKey: AppKeys.Engagement.wakeTimeSource) == nil {
            return (hour: fallbackHour, minute: fallbackMinute)
        }
        return (hour: hour, minute: minute)
    }
}
