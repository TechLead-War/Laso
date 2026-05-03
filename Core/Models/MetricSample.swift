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

    /// Normalized UTC day bucket for stable day-level deduplication.
    /// Math-based division is ~100x faster than Calendar.startOfDay(for:) in Swift.
    static func utcDayBucket(for date: Date) -> Int64 {
        return Int64(floor(date.timeIntervalSince1970 / 86400.0))
    }

    static func mergedByUTCDay(existing: [MetricSample], incoming: [MetricSample]) -> [MetricSample] {
        guard !incoming.isEmpty else { return existing }

        var samplesByDay: [Int64: MetricSample] = [:]
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

// MARK: - MetricSample Array Convenience

extension Array where Element == MetricSample {
    /// Arithmetic mean of sample values. Returns 0 for an empty array.
    var valueMean: Double {
        guard !isEmpty else { return 0 }
        return map(\.value).reduce(0, +) / Double(count)
    }

    /// Mean of the last `n` sample values without materializing an intermediate array.
    /// Returns 0 if the array is empty or `n` is non-positive.
    func tailMean(_ n: Int) -> Double {
        guard n > 0, !isEmpty else { return 0 }
        return suffix(n).mean(of: \.value)
    }
}
