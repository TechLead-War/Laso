import Foundation

/// A time series of samples for a specific metric, with computed statistical properties
struct MetricTimeSeries: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    /// All samples, stored in chronological order (sorted once at initialization).
    let samples: [MetricSample]
    private let distinctDayCount: Int

    // Removed pre-computed stats variables to save CPU and memory on init.

    init(metric: HealthMetric, samples: [MetricSample]) {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        
        // Filter out absurd physiological outliers to prevent data corruption
        let validSamples = sortedSamples.filter { sample in
            switch metric {
            case .heartRate, .restingHeartRate:
                return sample.value > 25 && sample.value < 250
            case .heartRateVariability:
                return sample.value > 5 && sample.value < 250
            case .bloodOxygen:
                return sample.value >= 0.5 && sample.value <= 1.0
            case .respiratoryRate:
                return sample.value > 5 && sample.value < 50
            case .bodyTemperature:
                return sample.value > 30 && sample.value < 45 // Celsius
            case .sleepDuration:
                return sample.value >= 0 && sample.value <= 24 // hours
            case .vo2Max:
                return sample.value > 15 && sample.value < 90
            default:
                return true
            }
        }
        
        // A dropped sample is a day the user silently loses. The commonest cause now is
        // two sources writing the same night, which lands above the sleep ceiling once a
        // whole night counts on one day, so it is reported rather than swallowed.
        let droppedCount = sortedSamples.count - validSamples.count
        if droppedCount > 0 {
            AnalyticsBackend.provider.captureError(
                "sample outside the plausible range for this metric was dropped",
                context: "metric_time_series_outlier_dropped",
                metadata: [
                    "metric": metric.rawValue,
                    "dropped": droppedCount
                ]
            )
        }

        self.metric = metric
        self.samples = validSamples

        // `localDayBucket` lands on exactly the boundary `Calendar.startOfDay`
        // would, daylight saving included, but in float math rather than a full
        // date-component decomposition. It is already the persistence dedupe key,
        // and at ~26k samples on a cold load this loop was the single largest
        // main-actor cost in the store.
        var distinctDayCount = 0
        var previousDay = Int64.min

        for sample in validSamples {
            let currentDay = MetricSample.localDayBucket(for: sample.date)
            if currentDay != previousDay {
                distinctDayCount += 1
                previousDay = currentDay
            }
        }
        self.distinctDayCount = distinctDayCount
    }

    /// Trusted init for slices of an already-built series: the samples are known
    /// sorted and outlier-filtered, so re-running that work would be pure waste.
    /// Deliberately private — a public caller could bypass the outlier invariant.
    private init(metric: HealthMetric, validatedSamples: [MetricSample], distinctDayCount: Int) {
        self.metric = metric
        self.samples = validatedSamples
        self.distinctDayCount = distinctDayCount
    }

    /// Samples in chronological order. O(1), already sorted at init.
    var sortedSamples: [MetricSample] { samples }

    var values: [Double] {
        samples.map(\.value)
    }

    var latestValue: Double? {
        samples.last?.value
    }

    var mean: Double { 
        let n = samples.count
        guard n > 0 else { return 0 }
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(n)
    }

    var standardDeviation: Double { 
        let n = samples.count
        guard n > 1 else { return 0 }
        let currentMean = mean
        let sumOfSquares = samples.reduce(0.0) { sum, sample in
            let delta = sample.value - currentMean
            return sum + (delta * delta)
        }
        return (sumOfSquares / Double(n)).squareRoot()
    }

    /// Check if the latest data is older than the given number of days.
    func isStale(thresholdDays: Int = 2) -> Bool {
        guard let lastDate = samples.last?.date else { return true }
        let cutoff = Date.cal.date(byAdding: .day, value: -thresholdDays, to: Date()) ?? Date()
        return lastDate < cutoff
    }

    /// Samples within the last N days
    func samples(lastDays days: Int) -> [MetricSample] {
        let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
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
        let calendar = Date.cal
        return samples.filter { calendar.component(.month, from: $0.date) == month }
    }

    /// Samples from the same calendar month in a specific year
    func samples(forMonth month: Int, year: Int) -> [MetricSample] {
        let calendar = Date.cal
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

    /// Returns a copy containing only samples on or before the end of the
    /// given calendar day. Used by the historical-score backfill to replay
    /// the scorer deterministically as it would have seen the data on dayN.
    func sliced(throughDay day: Date) -> MetricTimeSeries {
        let cal = Date.cal
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day)) else {
            return self
        }
        let endIndex = samples.firstIndex(onOrAfter: dayEnd)
        if endIndex >= samples.count { return self }

        // A prefix of a sorted, filtered array is still sorted and filtered, so
        // this takes the trusted init. The backfill replays this once per day per
        // metric, where the full init's re-sort and re-filter dominated.
        let prefix = Array(samples[..<endIndex])
        var dayCount = 0
        var previousDay = Int64.min
        for sample in prefix {
            let currentDay = MetricSample.localDayBucket(for: sample.date)
            if currentDay != previousDay {
                dayCount += 1
                previousDay = currentDay
            }
        }
        return MetricTimeSeries(metric: metric, validatedSamples: prefix, distinctDayCount: dayCount)
    }

    /// Number of years of data available
    var yearsOfData: Int {
        guard let first = samples.first, let last = samples.last else { return 0 }
        let years = Date.cal.dateComponents([.year], from: first.date, to: last.date).year ?? 0
        return Swift.max(1, years + 1)
    }

    /// Number of distinct calendar days with actual data points
    var daysOfData: Int {
        distinctDayCount
    }

    /// Total number of data points
    var totalDataPoints: Int { samples.count }

    private func firstIndex(onOrAfter date: Date) -> Int {
        samples.firstIndex(onOrAfter: date)
    }

    private func firstIndex(after date: Date) -> Int {
        samples.firstIndex(after: date)
    }
}
