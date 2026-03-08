import Foundation

/// Converts raw health time series into standardized daily feature vectors with derived features.
/// Uses Welford's online algorithm for incremental normalization updates.
///
/// Computes per-metric features:
///   raw, roc, vol7, lag1, lag3, lag7, devBaseline (original)
///   acceleration, entropy, periodicityStr, vol14, vol28, lag14, lag28, lag60,
///   weekdayOffset, weekendOffset, missingness (extended)
///
/// Also computes cross-metric interaction features for key health metric pairs.
final class FeatureEngine {
    /// Minimum days of data required before producing feature vectors
    static let minimumDays = 7

    /// Running statistics per metric for incremental z-score normalization
    private var runningStats: [HealthMetric: WelfordState] = [:]

    /// Running weekday/weekend means per metric for offset features
    private var weekdayStats: [HealthMetric: WelfordState] = [:]
    private var weekendStats: [HealthMetric: WelfordState] = [:]

    /// Ordered feature keys for deterministic array output
    private(set) var orderedKeys: [FeatureKey] = []

    /// Interaction features computed during the last `buildFeatureVectors` call, keyed by date.
    private(set) var interactionsByDate: [Date: [InteractionFeature: Double]] = [:]

    /// The set of interaction pairs computed during the last build.
    private(set) var interactionPairs: [InteractionFeature] = []

    // MARK: - Key Interaction Metric Pairs

    /// Curated cross-metric pairs that capture physiologically meaningful interactions.
    private static let keyInteractionPairs: [(HealthMetric, HealthMetric)] = [
        (.heartRateVariability, .sleepDuration),
        (.heartRateVariability, .restingHeartRate),
        (.restingHeartRate, .exerciseMinutes),
        (.sleepDuration, .steps),
        (.sleepDeep, .heartRateVariability),
        (.activeCalories, .sleepDuration),
        (.exerciseMinutes, .restingHeartRate),
        (.steps, .restingHeartRate),
        (.vo2Max, .exerciseMinutes),
        (.sleepDuration, .exerciseMinutes),
    ]

    // MARK: - Shannon Entropy Constants

    /// Adaptive bin count: uses Sturges' rule k = ceil(1 + log2(n)) with floor of 5
    /// for small samples, rather than a fixed 5 bins regardless of data volume
    private static func adaptiveBinCount(sampleSize: Int) -> Int {
        let sturges = Int(ceil(1.0 + log2(Double(max(sampleSize, 2)))))
        return max(5, min(sturges, 15))
    }
    /// Range of z-scores mapped into bins: [-3, 3].
    private static let entropyZMin = -3.0
    private static let entropyZMax = 3.0

    // MARK: - Periodicity Lags

    /// Lags (in days) at which autocorrelation is evaluated for periodicity strength.
    private static let periodicityLags = [7, 14, 28]

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
    ///
    /// After this call, `interactionsByDate` contains cross-metric interaction features keyed
    /// by date, and `interactionPairs` lists the interaction keys in deterministic order.
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

        // Build weekday/weekend running means per metric (rebuild from scratch each time for correctness)
        weekdayStats = [:]
        weekendStats = [:]
        for (metric, dateMap) in metricByDate {
            var wdState = WelfordState()
            var weState = WelfordState()
            for (date, value) in dateMap {
                let dow = calendar.component(.weekday, from: date) // 1=Sun, 7=Sat
                if dow == 1 || dow == 7 {
                    weState.update(value: value)
                } else {
                    wdState.update(value: value)
                }
            }
            weekdayStats[metric] = wdState
            weekendStats[metric] = weState
        }

        // Build ordered keys for deterministic array output
        let sortedMetrics = metricsWithData.sorted { $0.rawValue < $1.rawValue }
        orderedKeys = sortedMetrics.flatMap { metric in
            FeatureType.allCases.map { FeatureKey(metric: metric, type: $0) }
        }

        // Pre-compute z-score time series per metric for autocorrelation / entropy.
        // Keyed by metric, values sorted oldest-first by date.
        var zSeriesByMetric: [HealthMetric: [(date: Date, z: Double)]] = [:]
        for metric in sortedMetrics {
            guard let dateMap = metricByDate[metric],
                  let stats = runningStats[metric],
                  stats.count >= Self.minimumDays else { continue }
            var pairs: [(Date, Double)] = []
            for (date, value) in dateMap {
                pairs.append((date, stats.zScore(for: value)))
            }
            pairs.sort { $0.0 < $1.0 }
            zSeriesByMetric[metric] = pairs
        }

        // Build a quick lookup: metric -> date -> index in zSeries (for autocorrelation window slicing)
        var zDateIndex: [HealthMetric: [Date: Int]] = [:]
        for (metric, series) in zSeriesByMetric {
            var idx: [Date: Int] = [:]
            for (i, pair) in series.enumerated() {
                idx[pair.date] = i
            }
            zDateIndex[metric] = idx
        }

        // Build vectors for each day
        var vectors: [DailyFeatureVector] = []
        var interactionsAccumulator: [Date: [InteractionFeature: Double]] = [:]

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let day = calendar.startOfDay(for: date)
            let dow = calendar.component(.weekday, from: day) // 1=Sun, 7=Sat
            let isWeekendDay = (dow == 1 || dow == 7)

            var features: [FeatureKey: Double] = [:]
            var hasAnyData = false

            for metric in sortedMetrics {
                guard let dateMap = metricByDate[metric],
                      let stats = runningStats[metric],
                      stats.count >= Self.minimumDays else { continue }

                let rawValue = dateMap[day]

                // -- Missingness feature (always computable) --
                if rawValue == nil {
                    features[FeatureKey(metric: metric, type: .missingness)] = 1.0
                    // Mark all other features as missing for this metric on this day
                    for ft in FeatureType.allCases where ft != .missingness {
                        features[FeatureKey(metric: metric, type: ft)] = FeatureKey.missingSentinel
                    }
                    continue
                }

                let value = rawValue!
                hasAnyData = true
                let zScore = stats.zScore(for: value)

                features[FeatureKey(metric: metric, type: .missingness)] = 0.0

                // --- Raw z-score ---
                features[FeatureKey(metric: metric, type: .raw)] = zScore

                // --- Rate of change (day-over-day) ---
                let prevRoc: Double
                if let prevDate = calendar.date(byAdding: .day, value: -1, to: day),
                   let prevValue = dateMap[prevDate] {
                    let prevZ = stats.zScore(for: prevValue)
                    prevRoc = zScore - prevZ
                } else {
                    prevRoc = 0
                }
                features[FeatureKey(metric: metric, type: .roc)] = prevRoc

                // --- Acceleration (2nd derivative) --- requires 3+ days
                if stats.count >= 3,
                   let prev1Date = calendar.date(byAdding: .day, value: -1, to: day),
                   let prev2Date = calendar.date(byAdding: .day, value: -2, to: day),
                   let prev1Value = dateMap[prev1Date],
                   let prev2Value = dateMap[prev2Date] {
                    let prev1Z = stats.zScore(for: prev1Value)
                    let prev2Z = stats.zScore(for: prev2Value)
                    let roc1 = zScore - prev1Z
                    let roc0 = prev1Z - prev2Z
                    features[FeatureKey(metric: metric, type: .acceleration)] = roc1 - roc0
                } else {
                    features[FeatureKey(metric: metric, type: .acceleration)] = FeatureKey.missingSentinel
                }

                // --- Rolling volatility helpers ---
                // Collect z-score windows for various lookback periods
                let vol7Values = collectRecentZScores(
                    dateMap: dateMap, stats: stats, day: day, windowDays: 7, calendar: calendar
                )
                let vol14Values = collectRecentZScores(
                    dateMap: dateMap, stats: stats, day: day, windowDays: 14, calendar: calendar
                )
                let vol28Values = collectRecentZScores(
                    dateMap: dateMap, stats: stats, day: day, windowDays: 28, calendar: calendar
                )

                // --- 7-day rolling volatility ---
                if vol7Values.count >= 3 {
                    let (_, vol) = AccelerateML.welfordVariance(vol7Values)
                    features[FeatureKey(metric: metric, type: .vol7)] = vol.squareRoot()
                } else {
                    features[FeatureKey(metric: metric, type: .vol7)] = 0
                }

                // --- 14-day rolling volatility --- needs 14+ days in running stats
                if stats.count >= 14, vol14Values.count >= 5 {
                    let (_, vol) = AccelerateML.welfordVariance(vol14Values)
                    features[FeatureKey(metric: metric, type: .vol14)] = vol.squareRoot()
                } else {
                    features[FeatureKey(metric: metric, type: .vol14)] = FeatureKey.missingSentinel
                }

                // --- 28-day rolling volatility --- needs 28+ days in running stats
                if stats.count >= 28, vol28Values.count >= 10 {
                    let (_, vol) = AccelerateML.welfordVariance(vol28Values)
                    features[FeatureKey(metric: metric, type: .vol28)] = vol.squareRoot()
                } else {
                    features[FeatureKey(metric: metric, type: .vol28)] = FeatureKey.missingSentinel
                }

                // --- Lag features ---
                let lagConfigs: [(Int, FeatureType)] = [
                    (1, .lag1), (3, .lag3), (7, .lag7),
                    (14, .lag14), (28, .lag28), (60, .lag60),
                ]
                for (lagDays, lagType) in lagConfigs {
                    if let lagDate = calendar.date(byAdding: .day, value: -lagDays, to: day),
                       let lagValue = dateMap[lagDate] {
                        features[FeatureKey(metric: metric, type: lagType)] = stats.zScore(for: lagValue)
                    } else {
                        features[FeatureKey(metric: metric, type: lagType)] = FeatureKey.missingSentinel
                    }
                }

                // --- Deviation from baseline ---
                if let baseline = baselines[metric], baseline.standardDeviation > 0 {
                    features[FeatureKey(metric: metric, type: .devBaseline)] =
                        (value - baseline.mean) / baseline.standardDeviation
                } else {
                    features[FeatureKey(metric: metric, type: .devBaseline)] = zScore
                }

                // --- Shannon entropy of last 7 z-score values (binned into 5 bins) ---
                if stats.count >= 7, vol7Values.count >= 7 {
                    features[FeatureKey(metric: metric, type: .entropy)] =
                        Self.shannonEntropy(zScores: vol7Values)
                } else {
                    features[FeatureKey(metric: metric, type: .entropy)] = FeatureKey.missingSentinel
                }

                // --- Periodicity strength (autocorrelation at dominant period) ---
                if stats.count >= 14, let zSeries = zSeriesByMetric[metric] {
                    let zValues = zSeries.map(\.z)
                    if zValues.count >= 14 {
                        // Use AccelerateML.autocorrelation at lags [7, 14, 28], return max |r|
                        var maxAbsR = 0.0
                        for lag in Self.periodicityLags {
                            guard lag < zValues.count else { continue }
                            let r = AccelerateML.autocorrelation(zValues, lag: lag)
                            let absR = abs(r)
                            if absR > maxAbsR { maxAbsR = absR }
                        }
                        features[FeatureKey(metric: metric, type: .periodicityStr)] = maxAbsR
                    } else {
                        features[FeatureKey(metric: metric, type: .periodicityStr)] = FeatureKey.missingSentinel
                    }
                } else {
                    features[FeatureKey(metric: metric, type: .periodicityStr)] = FeatureKey.missingSentinel
                }

                // --- Weekday offset: deviation of weekday mean from overall mean ---
                if let wdStats = weekdayStats[metric], wdStats.count >= 3,
                   stats.stdDev > 0 {
                    features[FeatureKey(metric: metric, type: .weekdayOffset)] =
                        (wdStats.mean - stats.mean) / stats.stdDev
                } else {
                    features[FeatureKey(metric: metric, type: .weekdayOffset)] = FeatureKey.missingSentinel
                }

                // --- Weekend offset: deviation of weekend mean from overall mean ---
                if let weStats = weekendStats[metric], weStats.count >= 2,
                   stats.stdDev > 0 {
                    features[FeatureKey(metric: metric, type: .weekendOffset)] =
                        (weStats.mean - stats.mean) / stats.stdDev
                } else {
                    features[FeatureKey(metric: metric, type: .weekendOffset)] = FeatureKey.missingSentinel
                }
            }

            guard hasAnyData else { continue }

            let context = ContextFeatures.from(date: day)
            vectors.append(DailyFeatureVector(date: day, features: features, context: context))

            // --- Interaction features for this day ---
            let dayInteractions = computeInteractions(
                features: features,
                metricsAvailable: Set(sortedMetrics),
                isWeekend: isWeekendDay
            )
            if !dayInteractions.isEmpty {
                interactionsAccumulator[day] = dayInteractions
            }
        }

        // Finalize interaction outputs
        interactionsByDate = interactionsAccumulator
        interactionPairs = buildOrderedInteractionKeys(metricsAvailable: Set(sortedMetrics))

        return vectors.sorted { $0.date < $1.date }
    }

    // MARK: - Incremental Updates

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

    // MARK: - Interaction Feature Retrieval

    /// Retrieve interaction features for a specific date.
    /// Returns an empty dictionary if no interactions were computed for that date.
    func interactions(for date: Date) -> [InteractionFeature: Double] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return interactionsByDate[day] ?? [:]
    }

    /// Get all interaction values for a date as a sorted array matching `interactionPairs` order.
    func interactionArray(for date: Date) -> [Double] {
        let dict = interactions(for: date)
        return interactionPairs.map { dict[$0] ?? FeatureKey.missingSentinel }
    }

    // MARK: - Private Helpers

    /// Collect z-scored values within a lookback window ending on `day`.
    private func collectRecentZScores(
        dateMap: [Date: Double],
        stats: WelfordState,
        day: Date,
        windowDays: Int,
        calendar: Calendar
    ) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(windowDays)
        for d in 0..<windowDays {
            if let pastDate = calendar.date(byAdding: .day, value: -d, to: day),
               let v = dateMap[pastDate] {
                values.append(stats.zScore(for: v))
            }
        }
        return values
    }

    /// Compute Shannon entropy from z-score values binned adaptively over [-3, 3].
    /// Bin count follows Sturges' rule: k = ceil(1 + log2(n)), clamped to [5, 15].
    /// Formula: -Sum(p_i * log(p_i)) for non-zero bins.
    /// Returns entropy in nats, normalized by max entropy = ln(binCount) to [0, 1].
    private static func shannonEntropy(zScores: [Double]) -> Double {
        let binCount = adaptiveBinCount(sampleSize: zScores.count)
        let zMin = entropyZMin
        let zMax = entropyZMax
        let binWidth = (zMax - zMin) / Double(binCount)

        var bins = [Int](repeating: 0, count: binCount)
        let n = zScores.count
        guard n > 0 else { return 0 }

        for z in zScores {
            // Clamp to [zMin, zMax)
            let clamped = Swift.min(Swift.max(z, zMin), zMax - 1e-9)
            let binIndex = Int((clamped - zMin) / binWidth)
            let safeBin = Swift.min(Swift.max(binIndex, 0), binCount - 1)
            bins[safeBin] += 1
        }

        var entropy = 0.0
        let nDouble = Double(n)
        for count in bins {
            guard count > 0 else { continue }
            let p = Double(count) / nDouble
            entropy -= p * log(p)
        }
        // Normalize by max entropy (uniform distribution) so output is scale-invariant [0, 1]
        let maxEntropy = log(Double(binCount))
        return maxEntropy > 0 ? entropy / maxEntropy : 0
    }

    /// Compute interaction features for a single day given the per-metric feature dictionary.
    private func computeInteractions(
        features: [FeatureKey: Double],
        metricsAvailable: Set<HealthMetric>,
        isWeekend: Bool
    ) -> [InteractionFeature: Double] {
        var result: [InteractionFeature: Double] = [:]

        for (metricA, metricB) in Self.keyInteractionPairs {
            guard metricsAvailable.contains(metricA),
                  metricsAvailable.contains(metricB) else { continue }

            let keyA = FeatureKey(metric: metricA, type: .raw)
            let keyB = FeatureKey(metric: metricB, type: .raw)

            guard let zA = features[keyA], zA != FeatureKey.missingSentinel,
                  let zB = features[keyB], zB != FeatureKey.missingSentinel else { continue }

            // Product interaction: A * B (captures joint effect)
            let productKey = InteractionFeature(
                metricA: metricA, metricB: metricB, interactionType: .product
            )
            result[productKey] = zA * zB

            // Ratio interaction: A / B (relative measure, guard division by near-zero)
            let ratioKey = InteractionFeature(
                metricA: metricA, metricB: metricB, interactionType: .ratio
            )
            if abs(zB) > 0.01 {
                result[ratioKey] = zA / zB
            } else {
                result[ratioKey] = FeatureKey.missingSentinel
            }

            // Conditional high: A when B > 1 sigma
            let condHighKey = InteractionFeature(
                metricA: metricA, metricB: metricB, interactionType: .conditionalHigh
            )
            result[condHighKey] = zB > 1.0 ? zA : FeatureKey.missingSentinel

            // Conditional low: A when B < -1 sigma
            let condLowKey = InteractionFeature(
                metricA: metricA, metricB: metricB, interactionType: .conditionalLow
            )
            result[condLowKey] = zB < -1.0 ? zA : FeatureKey.missingSentinel
        }

        return result
    }

    /// Build a deterministic ordered list of all interaction feature keys based on available metrics.
    private func buildOrderedInteractionKeys(metricsAvailable: Set<HealthMetric>) -> [InteractionFeature] {
        var keys: [InteractionFeature] = []
        let interactionTypes: [InteractionFeature.InteractionType] = [
            .product, .ratio, .conditionalHigh, .conditionalLow,
        ]
        for (metricA, metricB) in Self.keyInteractionPairs {
            guard metricsAvailable.contains(metricA),
                  metricsAvailable.contains(metricB) else { continue }
            for iType in interactionTypes {
                keys.append(InteractionFeature(
                    metricA: metricA, metricB: metricB, interactionType: iType
                ))
            }
        }
        return keys
    }
}
