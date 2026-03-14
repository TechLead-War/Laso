import Foundation

/// A single timestamped health metric value
struct MetricSample: Identifiable, Codable {
    let id: UUID
    let date: Date
    let value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }

    private static var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Normalized UTC day bucket for stable day-level deduplication.
    static func utcDayBucket(for date: Date) -> Date {
        utcCalendar.startOfDay(for: date)
    }

    /// Merge two sample arrays by UTC day, preferring incoming samples on conflicts.
    static func mergedByUTCDay(existing: [MetricSample], incoming: [MetricSample]) -> [MetricSample] {
        guard !incoming.isEmpty else { return existing }

        var samplesByDay: [Date: MetricSample] = [:]
        samplesByDay.reserveCapacity(existing.count + incoming.count)

        for sample in existing {
            samplesByDay[utcDayBucket(for: sample.date)] = sample
        }
        for sample in incoming {
            samplesByDay[utcDayBucket(for: sample.date)] = sample
        }

        return samplesByDay.values.sorted { $0.date < $1.date }
    }
}
