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

    /// Read once from the app-wide calendar. `Date.cal` is a snapshot of
    /// `Calendar.current` taken at launch, so every bucket stays stable for the whole
    /// run even if the device changes time zone mid session.
    private static let zone = Date.cal.timeZone

    private static let secondsPerDay: Double = 86400

    /// Local calendar day index, used as the day-level dedupe key.
    /// It has to be the local day: sleep samples are dated at local wake time, so a UTC
    /// bucket merges two different nights anywhere the UTC boundary is not local midnight,
    /// which is India, most of Europe and Japan.
    /// Adding the zone offset first turns the value into a wall clock reading, so dividing
    /// by one day lands on exactly the boundary `Calendar.startOfDay` would, daylight
    /// saving included, without paying for date component decomposition on every sample.
    static func localDayBucket(for date: Date) -> Int64 {
        let wallClockSeconds = date.timeIntervalSince1970 + Double(zone.secondsFromGMT(for: date))
        return Int64(floor(wallClockSeconds / secondsPerDay))
    }

    static func mergedByLocalDay(existing: [MetricSample], incoming: [MetricSample]) -> [MetricSample] {
        guard !incoming.isEmpty else { return existing }

        var samplesByDay: [Int64: MetricSample] = [:]
        samplesByDay.reserveCapacity(existing.count + incoming.count)

        for sample in existing {
            samplesByDay[localDayBucket(for: sample.date)] = sample
        }
        for sample in incoming {
            samplesByDay[localDayBucket(for: sample.date)] = sample
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
