import Foundation

/// A time series of samples for a specific metric, with computed statistical properties
struct MetricTimeSeries: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    /// All samples, stored in chronological order (sorted once at initialization).
    let samples: [MetricSample]
    private let distinctDayCount: Int

    // Cached statistics — computed once at init, O(1) access thereafter.
    private let _mean: Double
    private let _standardDeviation: Double
    private let _min: Double?
    private let _max: Double?

    /// Pass 11 AF: cached calendar — `init`'s distinct-day pass and the
    /// `samples(lastDays:)` / `samples(forMonth:)` accessors all hit it.
    /// MetricTimeSeries is constructed once per metric per refresh, then
    /// queried multiple times during analysis.
    private static let cal: Calendar = Calendar.current

    init(metric: HealthMetric, samples: [MetricSample]) {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        self.metric = metric
        self.samples = sortedSamples

        let calendar = Self.cal
        var distinctDayCount = 0
        var previousDay: Date?

        // Single pass: compute distinct days, sum, min, max simultaneously
        var total = 0.0
        var minimum: Double?
        var maximum: Double?
        for sample in sortedSamples {
            let currentDay = calendar.startOfDay(for: sample.date)
            if currentDay != previousDay {
                distinctDayCount += 1
                previousDay = currentDay
            }
            total += sample.value
            if let curMin = minimum {
                if sample.value < curMin { minimum = sample.value }
            } else {
                minimum = sample.value
            }
            if let curMax = maximum {
                if sample.value > curMax { maximum = sample.value }
            } else {
                maximum = sample.value
            }
        }
        self.distinctDayCount = distinctDayCount
        self._min = minimum
        self._max = maximum

        // Compute mean
        let n = sortedSamples.count
        let mean = n > 0 ? total / Double(n) : 0
        self._mean = mean

        // Compute standard deviation (second pass, unavoidable without online algo)
        if n > 1 {
            var sumOfSquares = 0.0
            for sample in sortedSamples {
                let delta = sample.value - mean
                sumOfSquares += delta * delta
            }
            self._standardDeviation = (sumOfSquares / Double(n)).squareRoot()
        } else {
            self._standardDeviation = 0
        }
    }

    /// Samples in chronological order. O(1), already sorted at init.
    var sortedSamples: [MetricSample] { samples }

    var values: [Double] {
        samples.map(\.value)
    }

    var latestValue: Double? {
        samples.last?.value
    }

    var mean: Double { _mean }

    var standardDeviation: Double { _standardDeviation }

    var min: Double? { _min }

    var max: Double? { _max }

    var range: Double {
        guard let lo = _min, let hi = _max else { return 0 }
        return hi - lo
    }

    /// Samples within the last N days
    func samples(lastDays days: Int) -> [MetricSample] {
        let cutoff = Self.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        guard !samples.isEmpty else { return [] }

        let startIndex = firstIndex(onOrAfter: cutoff)
        guard startIndex < samples.count else { return [] }
        return Array(samples[startIndex...])
    }

    /// Mean value over the last N days
    func mean(lastDays days: Int) -> Double {
        samples(lastDays: days).mean(of: \.value)
    }

    // MARK: - Historical Data Access

    /// Samples from a specific calendar month across all years (for seasonal analysis)
    func samples(forMonth month: Int) -> [MetricSample] {
        let calendar = Self.cal
        return samples.filter { calendar.component(.month, from: $0.date) == month }
    }

    /// Samples from the same calendar month in a specific year
    func samples(forMonth month: Int, year: Int) -> [MetricSample] {
        let calendar = Self.cal
        return samples.filter {
            return calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
        }
    }

    /// Samples from a date range (inclusive)
    func samples(from start: Date, to end: Date) -> [MetricSample] {
        guard start <= end, !samples.isEmpty else { return [] }
        let startIndex = firstIndex(onOrAfter: start)
        let endIndex = firstIndex(after: end)
        guard startIndex < endIndex else { return [] }
        return Array(samples[startIndex..<endIndex])
    }

    /// Samples from a date range using an exclusive upper bound.
    func samples(from start: Date, until endExclusive: Date) -> [MetricSample] {
        guard start < endExclusive, !samples.isEmpty else { return [] }
        let startIndex = firstIndex(onOrAfter: start)
        let endIndex = firstIndex(onOrAfter: endExclusive)
        guard startIndex < endIndex else { return [] }
        return Array(samples[startIndex..<endIndex])
    }

    /// Percentile rank of a value in all-time data (0-100)
    func percentile(of value: Double) -> Double {
        guard !samples.isEmpty else { return 50 }
        var belowCount = 0
        for sample in samples where sample.value < value {
            belowCount += 1
        }
        return (Double(belowCount) / Double(samples.count)) * 100.0
    }

    /// Number of years of data available
    var yearsOfData: Int {
        guard let first = samples.first, let last = samples.last else { return 0 }
        let years = Self.cal.dateComponents([.year], from: first.date, to: last.date).year ?? 0
        return Swift.max(1, years + 1)
    }

    /// Number of distinct calendar days with actual data points
    var daysOfData: Int {
        distinctDayCount
    }

    /// Total number of data points
    var totalDataPoints: Int { samples.count }

    private func firstIndex(onOrAfter date: Date) -> Int {
        var low = 0
        var high = samples.count
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func firstIndex(after date: Date) -> Int {
        var low = 0
        var high = samples.count
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].date <= date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
