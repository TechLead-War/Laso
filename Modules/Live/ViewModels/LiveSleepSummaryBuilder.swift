import Foundation
import HealthKit

struct LiveSleepSummary: Equatable {
    var totalDuration: TimeInterval = 0
    var deepSleep: TimeInterval = 0
    var remSleep: TimeInterval = 0
    var coreSleep: TimeInterval = 0
    var awakeTime: TimeInterval = 0
}

struct LiveSleepSummaryBuilder {
    let eveningHour: Int
    let noonHour: Int

    init(eveningHour: Int = 18, noonHour: Int = 12) {
        self.eveningHour = eveningHour
        self.noonHour = noonHour
    }

    func queryWindow(containing now: Date, calendar: Calendar = .current) -> DateInterval? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let windowStart = calendar.date(
                bySettingHour: eveningHour,
                minute: 0,
                second: 0,
                of: yesterday
              ),
              let windowEnd = calendar.date(
                bySettingHour: noonHour,
                minute: 0,
                second: 0,
                of: startOfToday
              ) else {
            return nil
        }

        return DateInterval(start: windowStart, end: windowEnd)
    }

    func summarize(samples: [HKCategorySample]) -> LiveSleepSummary {
        var summary = LiveSleepSummary()

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

            switch value {
            case .asleepDeep:
                summary.deepSleep += duration
                summary.totalDuration += duration
            case .asleepREM:
                summary.remSleep += duration
                summary.totalDuration += duration
            case .asleepCore:
                summary.coreSleep += duration
                summary.totalDuration += duration
            case .awake:
                summary.awakeTime += duration
            case .asleepUnspecified:
                summary.totalDuration += duration
            case .inBed:
                // Time in bed is not time asleep — exclude from the total so it
                // matches the canonical Core sleep sum (asleep* stages only) and
                // does not inflate last night's sleep or the readiness score.
                break
            @unknown default:
                break
            }
        }

        return summary
    }
}
