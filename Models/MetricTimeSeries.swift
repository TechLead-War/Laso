import Foundation

/// A time series of samples for a specific metric, with computed statistical properties
struct MetricTimeSeries: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    /// All samples, stored in chronological order (sorted once at initialization).
    let samples: [MetricSample]

    init(metric: HealthMetric, samples: [MetricSample]) {
        self.metric = metric
        self.samples = samples.sorted { $0.date < $1.date }
    }

    /// Samples in chronological order — O(1), already sorted at init.
    var sortedSamples: [MetricSample] { samples }

    var values: [Double] {
        samples.map(\.value)
    }

    var latestValue: Double? {
        samples.last?.value
    }

    var mean: Double {
        guard !samples.isEmpty else { return 0 }
        var total = 0.0
        for sample in samples {
            total += sample.value
        }
        return total / Double(samples.count)
    }

    var standardDeviation: Double {
        guard samples.count > 1 else { return 0 }
        let avg = mean
        var sumOfSquares = 0.0
        for sample in samples {
            let delta = sample.value - avg
            sumOfSquares += delta * delta
        }
        return (sumOfSquares / Double(samples.count)).squareRoot()
    }

    var min: Double? {
        guard let first = samples.first else { return nil }
        var minimum = first.value
        for sample in samples.dropFirst() where sample.value < minimum {
            minimum = sample.value
        }
        return minimum
    }

    var max: Double? {
        guard let first = samples.first else { return nil }
        var maximum = first.value
        for sample in samples.dropFirst() where sample.value > maximum {
            maximum = sample.value
        }
        return maximum
    }

    var range: Double {
        guard let first = samples.first else { return 0 }
        var minimum = first.value
        var maximum = first.value

        for sample in samples.dropFirst() {
            if sample.value < minimum { minimum = sample.value }
            if sample.value > maximum { maximum = sample.value }
        }

        return maximum - minimum
    }

    /// Samples within the last N days
    func samples(lastDays days: Int) -> [MetricSample] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        guard !samples.isEmpty else { return [] }

        var low = 0
        var high = samples.count
        while low < high {
            let mid = (low + high) / 2
            if samples[mid].date < cutoff {
                low = mid + 1
            } else {
                high = mid
            }
        }

        guard low < samples.count else { return [] }
        return Array(samples[low...])
    }

    /// Mean value over the last N days
    func mean(lastDays days: Int) -> Double {
        samples(lastDays: days).mean(of: \.value)
    }

    // MARK: - Historical Data Access

    /// Samples from a specific calendar month across all years (for seasonal analysis)
    func samples(forMonth month: Int) -> [MetricSample] {
        let calendar = Calendar.current
        return samples.filter { calendar.component(.month, from: $0.date) == month }
    }

    /// Samples from the same calendar month in a specific year
    func samples(forMonth month: Int, year: Int) -> [MetricSample] {
        let calendar = Calendar.current
        return samples.filter {
            return calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
        }
    }

    /// Samples from a date range (inclusive)
    func samples(from start: Date, to end: Date) -> [MetricSample] {
        samples.filter { $0.date >= start && $0.date <= end }
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
        let years = Calendar.current.dateComponents([.year], from: first.date, to: last.date).year ?? 0
        return Swift.max(1, years + 1)
    }

    /// Number of distinct calendar days with actual data points
    var daysOfData: Int {
        guard !samples.isEmpty else { return 0 }
        let calendar = Calendar.current
        var uniqueDays = Set<Date>()
        uniqueDays.reserveCapacity(samples.count)
        for sample in samples {
            uniqueDays.insert(calendar.startOfDay(for: sample.date))
        }
        return uniqueDays.count
    }

    /// Total number of data points
    var totalDataPoints: Int { samples.count }
}
