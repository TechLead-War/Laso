import Foundation
import HealthKit
import Observation

/// Loads real Apple Health data for onboarding screens 10–13. Replaces
/// previously hardcoded values ("1y 8mo", "5h 42m", "71 BPM", "Sunday HRV
/// dip") with actual queries. Where data is missing, screens render an
/// honest empty state rather than a fabricated one.
@MainActor
@Observable
final class OnboardingHealthSnapshot {
    private let store = HKHealthStore()

    private(set) var isLoaded = false

    // Screen 10 (Scan) — earliest sample age per metric, in seconds.
    // nil means no samples ever recorded for that metric.
    private(set) var heartRateAge: TimeInterval?
    private(set) var sleepAge: TimeInterval?
    private(set) var workoutsAge: TimeInterval?
    private(set) var hrvAge: TimeInterval?
    private(set) var hasRecoverySignal: Bool = false

    // Screen 11 (Heart)
    private(set) var restingHR: Int?
    private(set) var restingHRMonthsCovered: Int?

    // Screen 12 (Sleep)
    private(set) var sleepAvgHours: Int?
    private(set) var sleepAvgMins: Int?
    private(set) var sleepLast7Nights: [Double] = []
    private(set) var sleepMonthsCovered: Int?

    // Screen 13 (HRV) — weekday-pattern analysis (Mon..Sun, index 0..6).
    // hrvWeekdayMeans[i] is nil if no samples landed on weekday i.
    private(set) var hrvWorstWeekday: Int?  // 1=Sun..7=Sat (Calendar convention)
    private(set) var hrvWeeklyAvgMs: Double?
    private(set) var hrvWeeksCovered: Int?
    private(set) var hrvWeekdayMeans: [Double?] = Array(repeating: nil, count: 7)

    func load() async {
        async let hrAge = earliestSampleAge(for: HKQuantityType(.heartRate))
        async let slpAge = earliestSampleAge(for: HKCategoryType(.sleepAnalysis))
        async let wktAge = earliestSampleAge(for: HKWorkoutType.workoutType())
        async let hrvAgeVal = earliestSampleAge(for: HKQuantityType(.heartRateVariabilitySDNN))
        async let rhrData = recentRestingHR()
        async let sleepData = recent7NightSleep()
        async let hrvData = hrvWeekdayPattern()

        let h = await hrAge
        let s = await slpAge
        let w = await wktAge
        let hr = await hrvAgeVal
        let rhr = await rhrData
        let sleep = await sleepData
        let hrv = await hrvData

        heartRateAge = h
        sleepAge = s
        workoutsAge = w
        hrvAge = hr
        hasRecoverySignal = (h != nil) && (hr != nil) && (s != nil)

        restingHR = rhr.average
        restingHRMonthsCovered = rhr.months

        sleepAvgHours = sleep.hours
        sleepAvgMins = sleep.mins
        sleepLast7Nights = sleep.last7
        sleepMonthsCovered = sleep.months

        hrvWorstWeekday = hrv.worstWeekday
        hrvWeeklyAvgMs = hrv.weeklyAvgMs
        hrvWeeksCovered = hrv.weeksOfData
        hrvWeekdayMeans = hrv.weekdayMeans

        isLoaded = true
    }

    // MARK: - Earliest sample

    /// Last 365 days. Bounds page-10 ages so a metric with multi-year history
    /// (e.g. heart rate) does not visually clash with metrics that have only a
    /// few months of data (e.g. resting HR, HRV) on the same scan screen.
    private static let scanWindowDays: Int = 365

    private func earliestSampleAge(for type: HKSampleType) async -> TimeInterval? {
        let endDate = Date()
        guard let startDate = Date.cal.date(byAdding: .day, value: -Self.scanWindowDays, to: endDate) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                if let first = samples?.first {
                    continuation.resume(returning: Date().timeIntervalSince(first.startDate))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            store.execute(q)
        }
    }

    // MARK: - Resting heart rate (last 365 days, matches scanWindowDays)

    private func recentRestingHR() async -> (average: Int?, months: Int?) {
        let calendar = Date.cal
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -Self.scanWindowDays, to: endDate) else {
            return (nil, nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKQuantityType(.restingHeartRate),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let qs = samples as? [HKQuantitySample], !qs.isEmpty else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let values = qs.map { $0.quantity.doubleValue(for: unit) }
                let avg = values.reduce(0, +) / Double(values.count)
                let earliest = qs.map { $0.startDate }.min() ?? endDate
                let months = max(1, calendar.dateComponents([.month], from: earliest, to: endDate).month ?? 1)
                continuation.resume(returning: (Int(avg.rounded()), months))
            }
            store.execute(q)
        }
    }

    // MARK: - Sleep (last 30 days, group by night)

    private func recent7NightSleep() async -> (hours: Int?, mins: Int?, last7: [Double], months: Int?) {
        let calendar = Date.cal
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else {
            return (nil, nil, [], nil)
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let cats = samples as? [HKCategorySample], !cats.isEmpty else {
                    continuation.resume(returning: (nil, nil, [], nil))
                    return
                }

                var perNight: [Date: TimeInterval] = [:]
                for sample in cats {
                    let asleep =
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    guard asleep else { continue }
                    let nightAnchor = calendar.startOfDay(for: sample.startDate.addingTimeInterval(-6 * 3600))
                    perNight[nightAnchor, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
                }

                let sorted = perNight.sorted(by: { $0.key < $1.key })
                guard !sorted.isEmpty else {
                    continuation.resume(returning: (nil, nil, [], nil))
                    return
                }
                let last7 = sorted.suffix(7).map { $0.value / 3600.0 }
                let avgSeconds = sorted.map { $0.value }.reduce(0, +) / Double(sorted.count)
                let hours = Int(avgSeconds / 3600)
                let mins = Int(avgSeconds.truncatingRemainder(dividingBy: 3600) / 60)
                let earliest = sorted.first?.key ?? endDate
                let months = max(1, calendar.dateComponents([.month], from: earliest, to: endDate).month ?? 1)

                continuation.resume(returning: (hours, mins, last7, months))
            }
            store.execute(q)
        }
    }

    // MARK: - HRV weekday pattern (last 12 weeks)

    private func hrvWeekdayPattern() async -> (
        worstWeekday: Int?,
        weeklyAvgMs: Double?,
        weeksOfData: Int?,
        weekdayMeans: [Double?]
    ) {
        let calendar = Date.cal
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -84, to: endDate) else {
            return (nil, nil, nil, Array(repeating: nil, count: 7))
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: HKQuantityType(.heartRateVariabilitySDNN),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let qs = samples as? [HKQuantitySample], qs.count >= 14 else {
                    continuation.resume(returning: (nil, nil, nil, Array(repeating: nil, count: 7)))
                    return
                }
                let unit = HKUnit.secondUnit(with: .milli)

                // Group raw samples by Calendar weekday (1=Sun..7=Sat).
                var byWeekday: [Int: [Double]] = [:]
                for sample in qs {
                    let weekday = calendar.component(.weekday, from: sample.startDate)
                    byWeekday[weekday, default: []].append(sample.quantity.doubleValue(for: unit))
                }
                let weekdayMeansDict = byWeekday.compactMapValues { values -> Double? in
                    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
                }
                guard weekdayMeansDict.count >= 5 else {
                    continuation.resume(returning: (nil, nil, nil, Array(repeating: nil, count: 7)))
                    return
                }

                let overallAvg = qs.map { $0.quantity.doubleValue(for: unit) }
                    .reduce(0, +) / Double(qs.count)

                // Worst weekday must be at least 5% below the overall average to
                // count as a real pattern. With 12+ weeks of data, 5% is a
                // realistic threshold; tighter risks false negatives, looser
                // surfaces noise.
                let worst: Int?
                if let candidate = weekdayMeansDict.min(by: { $0.value < $1.value }),
                   candidate.value < overallAvg * 0.95 {
                    worst = candidate.key
                } else {
                    worst = nil
                }

                // Map dictionary (weekday 1..7 = Sun..Sat) into Mon..Sun array
                // indexed 0..6 to match the chart's M T W T F S S labels.
                var weekdayMeans: [Double?] = Array(repeating: nil, count: 7)
                for (weekday, mean) in weekdayMeansDict {
                    let idx = weekday == 1 ? 6 : (weekday - 2)
                    if (0...6).contains(idx) { weekdayMeans[idx] = mean }
                }

                let distinctWeeks = Set(qs.map { sample -> Date in
                    let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: sample.startDate)
                    return calendar.date(from: comps) ?? sample.startDate
                }).count

                continuation.resume(returning: (worst, overallAvg, distinctWeeks, weekdayMeans))
            }
            store.execute(q)
        }
    }
}

// MARK: - Formatting helpers

enum OnbHealthFormat {
    /// Formats an age in seconds as "Xy Ymo" / "Xy" / "Ymo" / "Xd".
    /// Returns nil if input is nil so callers can render an honest empty state.
    static func duration(from seconds: TimeInterval?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let days = Int(seconds / 86400)
        if days >= 365 {
            let years = days / 365
            let months = (days % 365) / 30
            if months > 0 { return "\(years)y \(months)mo" }
            return "\(years)y"
        }
        if days >= 30 {
            return "\(days / 30)mo"
        }
        if days >= 1 {
            return "\(days)d"
        }
        return "today"
    }

    /// Returns the short weekday name for a Calendar weekday number (1 = Sun).
    static func weekdayName(_ weekday: Int?) -> String? {
        guard let weekday, (1...7).contains(weekday) else { return nil }
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[weekday - 1]
    }
}
