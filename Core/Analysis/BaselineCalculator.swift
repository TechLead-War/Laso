import Foundation

/// Computes personal baselines from historical data with outlier filtering and smoothing
struct BaselineCalculator {

    /// Compute baseline from a time series (uses 30-90 days of data)
    static func compute(series: MetricTimeSeries) -> UserBaseline? {
        // Use 30-90 days of data
        let samples = series.samples(lastDays: 90)
        let values = samples.map(\.value)

        guard values.count >= 7 else { return nil } // Need at least a week of data

        // Step 1: Filter outliers (beyond 2 standard deviations)
        let filtered = values.filterOutliers(maxDeviations: 2.0)
        guard !filtered.isEmpty else { return nil }

        // Step 2: Apply exponential smoothing (alpha = 0.3)
        let smoothed = filtered.exponentialSmoothing(alpha: 0.3)

        // Step 3: Compute statistics from smoothed data
        let mean = smoothed.mean
        let stdDev = smoothed.standardDeviation
        let median = smoothed.median

        return UserBaseline(
            metric: series.metric,
            mean: mean,
            standardDeviation: stdDev,
            median: median,
            sampleCount: filtered.count
        )
    }

    /// Check if baseline needs recalculation (every 7 days)
    static func needsRecalculation(baseline: UserBaseline) -> Bool {
        let daysSinceUpdate = baseline.lastUpdated.daysBetween(Date())
        return daysSinceUpdate >= 7
    }

    /// Update existing baselines with new data, recalculating where needed
    static func updateBaselines(
        existing: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [HealthMetric: UserBaseline] {
        var updated = existing

        for (metric, series) in timeSeries {
            if let existingBaseline = existing[metric] {
                if needsRecalculation(baseline: existingBaseline) {
                    if let newBaseline = compute(series: series) {
                        updated[metric] = newBaseline
                    }
                }
            } else {
                // No existing baseline, compute fresh
                if let newBaseline = compute(series: series) {
                    updated[metric] = newBaseline
                }
            }
        }

        return updated
    }
}
