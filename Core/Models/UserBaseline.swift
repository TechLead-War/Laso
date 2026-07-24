import Foundation

/// Personal baseline for a specific metric, computed from historical data
struct UserBaseline: Codable, Identifiable {
    var id: String { metric.rawValue }

    let metric: HealthMetric
    var mean: Double
    var standardDeviation: Double
    var median: Double
    var sampleCount: Int
    var lastUpdated: Date

    /// Warning threshold: 10% deviation
    var warningLow: Double { mean * 0.9 }
    var warningHigh: Double { mean * 1.1 }

    /// Critical threshold: 20% deviation
    var criticalLow: Double { mean * 0.8 }
    var criticalHigh: Double { mean * 1.2 }

    /// Deviation of a value from the baseline mean, as a percentage.
    ///
    /// Bounded to ±500%: metrics whose usual value sits near zero (walking
    /// asymmetry, double-support %, steadiness) make percent-of-mean explode for a
    /// small real change — an unbounded result once surfaced "24606% off usual" to
    /// a user. Real physiological/behavioural deviations fit well inside this band,
    /// and every downstream use compares against far smaller thresholds.
    func deviationPercent(for value: Double) -> Double {
        guard mean != 0 else { return 0 }
        let pct = ((value - mean) / mean) * 100.0
        return max(-500, min(500, pct))
    }

    init(metric: HealthMetric, mean: Double, standardDeviation: Double, median: Double, sampleCount: Int, lastUpdated: Date = Date()) {
        self.metric = metric
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.median = median
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }
}
