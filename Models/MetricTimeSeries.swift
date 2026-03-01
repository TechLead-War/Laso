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
        sortedSamples.map(\.value)
    }

    var latestValue: Double? {
        sortedSamples.last?.value
    }

    var mean: Double {
        values.mean
    }

    var standardDeviation: Double {
        values.standardDeviation
    }

    var min: Double? {
        values.min()
    }

    var max: Double? {
        values.max()
    }

    var range: Double {
        guard let lo = values.min(), let hi = values.max() else { return 0 }
        return hi - lo
    }

    /// Samples within the last N days
    func samples(lastDays days: Int) -> [MetricSample] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sortedSamples.filter { $0.date >= cutoff }
    }

    /// Mean value over the last N days
    func mean(lastDays days: Int) -> Double {
        samples(lastDays: days).map(\.value).mean
    }

    // MARK: - Historical Data Access

    /// Samples from a specific calendar month across all years (for seasonal analysis)
    func samples(forMonth month: Int) -> [MetricSample] {
        sortedSamples.filter { Calendar.current.component(.month, from: $0.date) == month }
    }

    /// Samples from the same calendar month in a specific year
    func samples(forMonth month: Int, year: Int) -> [MetricSample] {
        sortedSamples.filter {
            let c = Calendar.current
            return c.component(.month, from: $0.date) == month && c.component(.year, from: $0.date) == year
        }
    }

    /// Samples from a date range (inclusive)
    func samples(from start: Date, to end: Date) -> [MetricSample] {
        sortedSamples.filter { $0.date >= start && $0.date <= end }
    }

    /// Percentile rank of a value in all-time data (0-100)
    func percentile(of value: Double) -> Double {
        let allValues = values
        guard !allValues.isEmpty else { return 50 }
        let below = allValues.filter { $0 < value }.count
        return (Double(below) / Double(allValues.count)) * 100.0
    }

    /// Number of years of data available
    var yearsOfData: Int {
        guard let earliest = sortedSamples.first?.date else { return 0 }
        return Swift.max(1, Calendar.current.dateComponents([.year], from: earliest, to: Date()).year ?? 0)
    }

    /// Number of distinct calendar days with actual data points
    var daysOfData: Int {
        guard !sortedSamples.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(sortedSamples.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    /// Total number of data points
    var totalDataPoints: Int { samples.count }
}
