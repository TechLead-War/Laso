import Foundation

/// Converts raw health time series into standardized daily feature vectors with derived features.
/// Uses Welford's online algorithm for incremental normalization updates.
///
/// Computes per-metric features:
///   raw, roc, vol7, lag1, lag3, lag7, devBaseline (original)
///   acceleration, entropy, periodicityStr, vol14, vol28, lag14, lag28, lag60,
///   weekdayOffset, weekendOffset, missingness (extended)
final class FeatureEngine {
    /// Minimum days of data required before producing feature vectors
    static let minimumDays = 7

    /// Running statistics per metric for incremental z-score normalization
    private var runningStats: [HealthMetric: WelfordState] = [:]

    /// Running weekday/weekend means per metric for offset features (maintained incrementally)
    private var weekdayStats: [HealthMetric: WelfordState] = [:]
    private var weekendStats: [HealthMetric: WelfordState] = [:]
    /// Tracks which dates have been incorporated into weekday/weekend stats (prevents double-counting)
    private var weekdayWeekendProcessedDates: [HealthMetric: Set<Date>] = [:]

    /// Ordered feature keys for deterministic array output
    private(set) var orderedKeys: [FeatureKey] = []

    /// Cached feature vectors from previous builds. Only the most recent `rebuildWindowDays`
    /// are recomputed each call; older days reuse cached vectors.
    private var cachedVectors: [Date: DailyFeatureVector] = [:]
    /// Days within this window are always recomputed (handles late-arriving data).
    private static let rebuildWindowDays = 3

    // MARK: - History Horizon

    /// Newest days that get a feature vector. A first sync can hand back a decade of HealthKit
    /// samples, and building every one of those days costs minutes of CPU, which trips the
    /// pipeline's own thermal guard before any insight is produced. Two years still leaves far
    /// more training rows than any downstream component asks for (the largest need is 14 days).
    private static let maxHistoryDays = 730

    /// Extra older days kept in the day lookup array beyond the build horizon, so the oldest
    /// built day can still read its lag features. The deepest lookup into that array is lag60.
    private static let maxLookbackDays = 60

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
    /// Observations in the trailing window used for periodicity. Long enough to cover three
    /// cycles at the longest lag (28 days) without reaching deep into the past.
    private static let periodicityWindowSamples = 90
    /// Observations up to and including the day being built before periodicity is reported.
    private static let periodicityMinSamples = 14

    // MARK: - Weekday / Weekend Offsets

    /// Weekday observations required before the weekday offset is reported.
    private static let minWeekdaySamples = 3
    /// Weekend observations required before the weekend offset is reported.
    private static let minWeekendSamples = 2

    // MARK: - Hoisted Per-Day Constants

    /// Every feature type except missingness. Hoisted because the per-day loop would otherwise
    /// rebuild `FeatureType.allCases` for every metric on every day.
    private static let nonMissingnessTypes = FeatureType.allCases.filter { $0 != .missingness }

    /// Lag features and the day offset each one reads.
    private static let lagConfigs: [(days: Int, type: FeatureType)] = [
        (1, .lag1), (3, .lag3), (7, .lag7),
        (14, .lag14), (28, .lag28), (60, .lag60),
    ]

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
        let calendar = Date.cal
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

        // Update running statistics incrementally. only recompute if no prior state exists
        for (metric, dateMap) in metricByDate {
            if runningStats[metric] == nil || runningStats[metric]!.count == 0 {
                // First time: build from scratch
                var state = WelfordState()
                for value in dateMap.values {
                    state.update(value: value)
                }
                runningStats[metric] = state
            }
            // Otherwise keep existing Welford state. incremental updates happen via updateIncremental()
        }

        // Build weekday/weekend running means per metric incrementally.
        // Only process dates not yet incorporated to avoid O(N) full rebuild each run.
        for (metric, dateMap) in metricByDate {
            if weekdayStats[metric] == nil { weekdayStats[metric] = WelfordState() }
            if weekendStats[metric] == nil { weekendStats[metric] = WelfordState() }
            var processed = weekdayWeekendProcessedDates[metric] ?? []
            for (date, value) in dateMap {
                guard !processed.contains(date) else { continue }
                processed.insert(date)
                let dow = calendar.component(.weekday, from: date) // 1=Sun, 7=Sat
                if dow == 1 || dow == 7 {
                    weekendStats[metric]?.update(value: value)
                } else {
                    weekdayStats[metric]?.update(value: value)
                }
            }
            weekdayWeekendProcessedDates[metric] = processed
        }

        // Build ordered keys for deterministic array output
        let sortedMetrics = metricsWithData.sorted { $0.rawValue < $1.rawValue }
        orderedKeys = sortedMetrics.flatMap { metric in
            FeatureType.allCases.map { FeatureKey(metric: metric, type: $0) }
        }

        // Pre-compute the z-score series per metric (oldest first) plus a date -> index lookup,
        // so each day can take a trailing autocorrelation window that ends on that day.
        var zValuesByMetric: [HealthMetric: [Double]] = [:]
        var zDateIndex: [HealthMetric: [Date: Int]] = [:]
        for metric in sortedMetrics {
            guard let dateMap = metricByDate[metric],
                  let stats = runningStats[metric],
                  stats.count >= Self.minimumDays else { continue }
            let sortedDates = dateMap.keys.sorted()
            var values: [Double] = []
            values.reserveCapacity(sortedDates.count)
            var index: [Date: Int] = [:]
            index.reserveCapacity(sortedDates.count)
            for (i, date) in sortedDates.enumerated() {
                values.append(stats.zScore(for: dateMap[date]!))
                index[date] = i
            }
            zValuesByMetric[metric] = values
            zDateIndex[metric] = index
        }

        // Weekday and weekend offsets depend only on the running stats, never on the day being
        // built, so they are computed once per metric instead of once per metric per day.
        var weekdayOffsetByMetric: [HealthMetric: Double] = [:]
        var weekendOffsetByMetric: [HealthMetric: Double] = [:]
        for metric in sortedMetrics {
            guard let stats = runningStats[metric], stats.stdDev > 0 else { continue }
            if let wdStats = weekdayStats[metric], wdStats.count >= Self.minWeekdaySamples {
                weekdayOffsetByMetric[metric] = (wdStats.mean - stats.mean) / stats.stdDev
            }
            if let weStats = weekendStats[metric], weStats.count >= Self.minWeekendSamples {
                weekendOffsetByMetric[metric] = (weStats.mean - stats.mean) / stats.stdDev
            }
        }

        // Pre-build the date array ONCE to keep Calendar.date(byAdding:) out of the inner loops.
        // allDays[0] = today, allDays[1] = yesterday, and so on. It runs one lookback window past
        // the build horizon so the oldest built day can still read its lag features.
        let lookupDays = min(totalDays, Self.maxHistoryDays + Self.maxLookbackDays)
        var allDays: [Date] = []
        allDays.reserveCapacity(lookupDays)
        for offset in 0..<lookupDays {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            allDays.append(calendar.startOfDay(for: d))
        }

        // Build vectors for each day inside the horizon (newest first)
        var vectors: [DailyFeatureVector] = []
        let buildDays = min(allDays.count, Self.maxHistoryDays)

        for dayOffset in 0..<buildDays {
            let day = allDays[dayOffset]

            // Reuse cached vector for days outside the rebuild window.
            // Only the most recent days need recomputation (new/late data).
            if dayOffset >= Self.rebuildWindowDays,
               let cached = cachedVectors[day] {
                vectors.append(cached)
                continue
            }

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
                    for ft in Self.nonMissingnessTypes {
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

                // --- Rate of change (day-over-day) --- uses allDays index instead of Calendar
                let prevRoc: Double
                let prev1Idx = dayOffset + 1
                if prev1Idx < allDays.count,
                   let prevValue = dateMap[allDays[prev1Idx]] {
                    let prevZ = stats.zScore(for: prevValue)
                    prevRoc = zScore - prevZ
                } else {
                    prevRoc = 0
                }
                features[FeatureKey(metric: metric, type: .roc)] = prevRoc

                // --- Acceleration (2nd derivative) --- requires 3+ days
                let prev2Idx = dayOffset + 2
                if stats.count >= 3,
                   prev1Idx < allDays.count,
                   prev2Idx < allDays.count,
                   let prev1Value = dateMap[allDays[prev1Idx]],
                   let prev2Value = dateMap[allDays[prev2Idx]] {
                    let prev1Z = stats.zScore(for: prev1Value)
                    let prev2Z = stats.zScore(for: prev2Value)
                    let roc1 = zScore - prev1Z
                    let roc0 = prev1Z - prev2Z
                    features[FeatureKey(metric: metric, type: .acceleration)] = roc1 - roc0
                } else {
                    features[FeatureKey(metric: metric, type: .acceleration)] = FeatureKey.missingSentinel
                }

                // --- Rolling volatility helpers ---
                // Collect z-score windows using pre-built allDays array (no Calendar calls)
                let vol7Values = collectRecentZScoresIndexed(
                    dateMap: dateMap, stats: stats, dayOffset: dayOffset, windowDays: 7, allDays: allDays
                )
                let vol14Values = collectRecentZScoresIndexed(
                    dateMap: dateMap, stats: stats, dayOffset: dayOffset, windowDays: 14, allDays: allDays
                )
                let vol28Values = collectRecentZScoresIndexed(
                    dateMap: dateMap, stats: stats, dayOffset: dayOffset, windowDays: 28, allDays: allDays
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

                // --- Lag features --- uses allDays index instead of Calendar
                for (lagDays, lagType) in Self.lagConfigs {
                    let lagIdx = dayOffset + lagDays
                    if lagIdx < allDays.count,
                       let lagValue = dateMap[allDays[lagIdx]] {
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

                // --- Periodicity strength (max |autocorrelation| over a trailing window) ---
                // The window has to end on the day being built. Running it over the whole series
                // folds later days into a past day's feature, which biases every model that
                // trains on these vectors, and it also made the value identical on every day.
                if let zValues = zValuesByMetric[metric],
                   let endIndex = zDateIndex[metric]?[day],
                   endIndex + 1 >= Self.periodicityMinSamples {
                    let startIndex = max(0, endIndex + 1 - Self.periodicityWindowSamples)
                    let window = Array(zValues[startIndex...endIndex])
                    var maxAbsR = 0.0
                    for lag in Self.periodicityLags where lag < window.count {
                        let absR = abs(AccelerateML.autocorrelation(window, lag: lag))
                        if absR > maxAbsR { maxAbsR = absR }
                    }
                    features[FeatureKey(metric: metric, type: .periodicityStr)] = maxAbsR
                } else {
                    features[FeatureKey(metric: metric, type: .periodicityStr)] = FeatureKey.missingSentinel
                }

                // --- Weekday / weekend offsets (precomputed once per metric above) ---
                features[FeatureKey(metric: metric, type: .weekdayOffset)] =
                    weekdayOffsetByMetric[metric] ?? FeatureKey.missingSentinel
                features[FeatureKey(metric: metric, type: .weekendOffset)] =
                    weekendOffsetByMetric[metric] ?? FeatureKey.missingSentinel
            }

            guard hasAnyData else { continue }

            let context = ContextFeatures.from(date: day)
            vectors.append(DailyFeatureVector(date: day, features: features, context: context))
        }

        // Update cache with freshly computed vectors
        for vector in vectors {
            cachedVectors[vector.date] = vector
        }

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

    // MARK: - Private Helpers

    /// Collect z-scored values using pre-built date array (zero Calendar calls).
    /// `dayOffset` is the index into `allDays` for the current day.
    private func collectRecentZScoresIndexed(
        dateMap: [Date: Double],
        stats: WelfordState,
        dayOffset: Int,
        windowDays: Int,
        allDays: [Date]
    ) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(windowDays)
        for d in 0..<windowDays {
            let idx = dayOffset + d
            guard idx < allDays.count else { break }
            if let v = dateMap[allDays[idx]] {
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

}
