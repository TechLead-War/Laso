import Foundation

/// Converts raw health time series into standardized daily feature vectors with derived features.
/// Uses Welford's online algorithm for incremental normalization updates.
final class FeatureEngine {
    /// Minimum days of data required before producing feature vectors
    static let minimumDays = 7

    /// Running statistics per metric for incremental z-score normalization
    private var runningStats: [HealthMetric: WelfordState] = [:]

    /// Ordered feature keys for deterministic array output
    private(set) var orderedKeys: [FeatureKey] = []

    // MARK: - Welford's Online Statistics

    /// Incremental mean/variance tracker
    struct WelfordState: Codable {
        var count: Int = 0
        var mean: Double = 0
        var m2: Double = 0

        var variance: Double {
            count > 1 ? m2 / Double(count) : 0
        }

        var stdDev: Double {
            variance.squareRoot()
        }

        mutating func update(value: Double) {
            count += 1
            let delta = value - mean
            mean += delta / Double(count)
            let delta2 = value - mean
            m2 += delta * delta2
        }

        func zScore(for value: Double) -> Double {
            let sd = stdDev
            guard sd > 0 else { return 0 }
            return (value - mean) / sd
        }
    }

    // MARK: - Feature Extraction

    /// Build daily feature vectors from raw time series data.
    /// Returns vectors sorted by date (oldest first).
    func buildFeatureVectors(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [DailyFeatureVector] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Determine date range from available data
        let allDates = timeSeries.values.flatMap { $0.sortedSamples.map { calendar.startOfDay(for: $0.date) } }
        guard let earliest = allDates.min() else { return [] }

        let totalDays = calendar.dateComponents([.day], from: earliest, to: today).day ?? 0
        guard totalDays >= Self.minimumDays else { return [] }

        // Build date-indexed lookup per metric
        var metricByDate: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            var dateMap: [Date: Double] = [:]
            for sample in series.sortedSamples {
                let day = calendar.startOfDay(for: sample.date)
                dateMap[day] = sample.value
            }
            metricByDate[metric] = dateMap
        }

        let metricsWithData = Array(metricByDate.keys)

        // Update running statistics incrementally — only recompute if no prior state exists
        for (metric, dateMap) in metricByDate {
            if runningStats[metric] == nil || runningStats[metric]!.count == 0 {
                // First time: build from scratch
                var state = WelfordState()
                for value in dateMap.values {
                    state.update(value: value)
                }
                runningStats[metric] = state
            }
            // Otherwise keep existing Welford state — incremental updates happen via updateIncremental()
        }

        // Build ordered keys for deterministic array output
        let sortedMetrics = metricsWithData.sorted { $0.rawValue < $1.rawValue }
        orderedKeys = sortedMetrics.flatMap { metric in
            FeatureType.allCases.map { FeatureKey(metric: metric, type: $0) }
        }

        // Build vectors for each day
        var vectors: [DailyFeatureVector] = []

        for dayOffset in 0...totalDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let day = calendar.startOfDay(for: date)

            var features: [FeatureKey: Double] = [:]
            var hasAnyData = false

            for metric in sortedMetrics {
                guard let dateMap = metricByDate[metric],
                      let stats = runningStats[metric],
                      stats.count >= Self.minimumDays else { continue }

                guard let rawValue = dateMap[day] else {
                    // Mark all features as missing for this metric on this day
                    for ft in FeatureType.allCases {
                        features[FeatureKey(metric: metric, type: ft)] = FeatureKey.missingSentinel
                    }
                    continue
                }

                hasAnyData = true
                let zScore = stats.zScore(for: rawValue)

                // Raw z-score
                features[FeatureKey(metric: metric, type: .raw)] = zScore

                // Rate of change (day-over-day)
                if let prevDate = calendar.date(byAdding: .day, value: -1, to: day),
                   let prevValue = dateMap[prevDate] {
                    let prevZ = stats.zScore(for: prevValue)
                    features[FeatureKey(metric: metric, type: .roc)] = zScore - prevZ
                } else {
                    features[FeatureKey(metric: metric, type: .roc)] = 0
                }

                // 7-day rolling volatility
                var recentValues: [Double] = []
                for d in 0..<7 {
                    if let pastDate = calendar.date(byAdding: .day, value: -d, to: day),
                       let v = dateMap[pastDate] {
                        recentValues.append(stats.zScore(for: v))
                    }
                }
                if recentValues.count >= 3 {
                    let (_, vol) = AccelerateML.welfordVariance(recentValues)
                    features[FeatureKey(metric: metric, type: .vol7)] = vol.squareRoot()
                } else {
                    features[FeatureKey(metric: metric, type: .vol7)] = 0
                }

                // Lag features
                for (lagDays, lagType) in [(1, FeatureType.lag1), (3, FeatureType.lag3), (7, FeatureType.lag7)] {
                    if let lagDate = calendar.date(byAdding: .day, value: -lagDays, to: day),
                       let lagValue = dateMap[lagDate] {
                        features[FeatureKey(metric: metric, type: lagType)] = stats.zScore(for: lagValue)
                    } else {
                        features[FeatureKey(metric: metric, type: lagType)] = FeatureKey.missingSentinel
                    }
                }

                // Deviation from baseline
                if let baseline = baselines[metric], baseline.standardDeviation > 0 {
                    features[FeatureKey(metric: metric, type: .devBaseline)] =
                        (rawValue - baseline.mean) / baseline.standardDeviation
                } else {
                    features[FeatureKey(metric: metric, type: .devBaseline)] = zScore
                }
            }

            guard hasAnyData else { continue }

            let context = ContextFeatures.from(date: day)
            vectors.append(DailyFeatureVector(date: day, features: features, context: context))
        }

        return vectors.sorted { $0.date < $1.date }
    }

    /// Update running statistics incrementally with new data (daily update)
    func updateIncremental(metric: HealthMetric, newValue: Double) {
        if runningStats[metric] == nil {
            runningStats[metric] = WelfordState()
        }
        runningStats[metric]?.update(value: newValue)
    }

    /// Get current running statistics for persistence
    func getRunningStats() -> [HealthMetric: WelfordState] {
        runningStats
    }

    /// Restore running statistics from persisted state
    func restoreRunningStats(_ stats: [HealthMetric: WelfordState]) {
        runningStats = stats
    }

    /// Whether the engine has enough data to produce useful features
    var isReady: Bool {
        runningStats.values.contains { $0.count >= Self.minimumDays }
    }
}
