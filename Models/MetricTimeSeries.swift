import Foundation

/// A time series of samples for a specific metric, with computed statistical properties
struct MetricTimeSeries: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    let samples: [MetricSample]

    var sortedSamples: [MetricSample] {
        samples.sorted { $0.date < $1.date }
    }

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
}
