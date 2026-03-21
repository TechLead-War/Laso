import Foundation

// MARK: - Composite Feature Types

/// Types of composite (higher-order) features derived by combining multiple raw metrics or
/// applying windowed aggregations. These extend the feature namespace beyond the per-metric
/// `FeatureType` cases produced by `FeatureEngine`.
enum CompositeFeatureType: String, Hashable, Codable, CaseIterable {

    /// HRV / Resting Heart Rate. autonomic nervous system balance.
    /// Higher values indicate parasympathetic dominance (recovery state).
    case autonomicBalance

    /// Sleep Duration * Deep Sleep Percentage. overall sleep effectiveness.
    /// Captures both quantity and quality in a single score.
    case sleepQuality

    /// Active Calories / Steps. metabolic cost per step.
    /// Higher values indicate more intense movement patterns.
    case exerciseIntensity

    /// (HRV_z + SleepDuration_z - RestingHR_z) / 3. composite recovery signal.
    /// Combines cardiac, sleep, and autonomic indicators into one readiness metric.
    case recoveryIndex

    /// 7-day EWA of active calories / 28-day EWA. acute-to-chronic workload ratio.
    /// Values above 1.5 indicate elevated injury risk; below 0.8 indicates detraining.
    case acuteChronicWorkloadRatio

    /// Consecutive days with HRV below personal baseline. monotone fatigue accumulation.
    /// Rising counts signal sustained autonomic stress without recovery.
    case monotoneFatigueSignal

    /// Standard deviation of sleep midpoint over past 7 days. circadian consistency.
    /// Lower values indicate more regular sleep timing.
    case sleepConsistency

    /// |weekday sleep midpoint - weekend sleep midpoint| in hours. social jet lag.
    /// Measures circadian disruption from inconsistent weekday/weekend schedules.
    case socialJetLag

    /// 7-day mean workout load / 7-day StdDev. training load monotony.
    /// High monotony (>2.0) with high load predicts overtraining and illness risk.
    case trainingLoadMonotony

    /// Consecutive days meeting sleep target (>= 7 hours).
    case sleepStreak

    /// Consecutive days meeting step target (>= 8000 steps).
    case stepStreak

    /// Consecutive days meeting exercise target (>= 30 minutes).
    case exerciseStreak
}

// MARK: - Composite Feature Key

/// Identifies a composite feature independently from per-metric `FeatureKey`.
/// Uses `CompositeFeatureType` instead of `HealthMetric + FeatureType`.
struct CompositeFeatureKey: Hashable, Codable {
    let type: CompositeFeatureType

    /// Sentinel value for missing composite features, matching `FeatureKey.missingSentinel`.
    static let missingSentinel: Double = -999.0
}

// MARK: - Enriched Daily Feature Vector

/// A `DailyFeatureVector` augmented with composite features.
/// Consumers can read both the original per-metric features and the composite features.
struct EnrichedDailyFeatureVector {
    let base: DailyFeatureVector
    var compositeFeatures: [CompositeFeatureKey: Double]

    var date: Date { base.date }

    /// Access original per-metric features.
    var features: [FeatureKey: Double] { base.features }
    /// Access original context.
    var context: ContextFeatures { base.context }

    /// Retrieve a composite feature value, returning nil if absent or sentinel.
    func compositeValue(for type: CompositeFeatureType) -> Double? {
        let key = CompositeFeatureKey(type: type)
        guard let value = compositeFeatures[key],
              value != CompositeFeatureKey.missingSentinel else {
            return nil
        }
        return value
    }

    /// All composite values as a sorted array (deterministic order for ML algorithms).
    func compositeArray() -> [Double] {
        CompositeFeatureType.allCases.map { type in
            compositeFeatures[CompositeFeatureKey(type: type)] ?? CompositeFeatureKey.missingSentinel
        }
    }

    /// Combined array: base features (ordered) + composite features (ordered).
    func toFullArray(orderedBaseKeys: [FeatureKey]) -> [Double] {
        base.toArray(orderedKeys: orderedBaseKeys) + compositeArray()
    }
}

// MARK: - Composite Feature Engine

/// Computes advanced composite features from basic daily feature vectors produced by `FeatureEngine`.
///
/// This engine is **stateless**. every method is a pure function that takes input data and returns
/// enriched vectors. It is designed to run after `FeatureEngine.buildFeatureVectors(...)` and before
/// downstream ML components (forecaster, anomaly detector, classifier, etc.).
///
/// Composite features fall into three categories:
/// 1. **Ratio features**. combine two metrics on the same day (autonomic balance, exercise intensity).
/// 2. **Windowed aggregations**. compute rolling statistics across multiple days (ACWR, monotony, consistency).
/// 3. **Streak/count features**. track consecutive days meeting a threshold (fatigue signal, behavioral streaks).
enum CompositeFeatureEngine {

    // MARK: - Minimum Data Requirements

    /// Minimum days of data required for each composite feature type.
    static func minimumDays(for type: CompositeFeatureType) -> Int {
        switch type {
        case .autonomicBalance:          return 1
        case .sleepQuality:              return 1
        case .exerciseIntensity:         return 1
        case .recoveryIndex:             return 1
        case .acuteChronicWorkloadRatio: return 28
        case .monotoneFatigueSignal:     return 7
        case .sleepConsistency:          return 7
        case .socialJetLag:              return 14  // Need weekday + weekend samples
        case .trainingLoadMonotony:      return 7
        case .sleepStreak:               return 7
        case .stepStreak:                return 7
        case .exerciseStreak:            return 7
        }
    }

    // MARK: - Public Entry Point

    /// Enrich an array of daily feature vectors with all applicable composite features.
    ///
    /// - Parameters:
    ///   - vectors: Basic feature vectors from `FeatureEngine`, sorted by date (oldest first).
    ///   - timeSeries: Raw metric time series for accessing absolute values.
    ///   - baselines: Personal baselines per metric for threshold comparisons.
    /// - Returns: Enriched vectors in the same date order, with composite features populated
    ///   wherever sufficient data exists.
    static func enrich(
        vectors: [DailyFeatureVector],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [EnrichedDailyFeatureVector] {
        guard !vectors.isEmpty else { return [] }

        let calendar = Calendar.current

        // Pre-build date-indexed raw value lookups from time series
        let dateLookups = buildDateLookups(from: timeSeries, calendar: calendar)

        // Pre-compute windowed aggregations that span multiple days
        let acwrByDate = computeACWR(dateLookups: dateLookups, calendar: calendar)
        let fatigueByDate = computeMonotoneFatigue(
            dateLookups: dateLookups, baselines: baselines, calendar: calendar
        )
        let sleepConsistencyByDate = computeSleepConsistency(
            dateLookups: dateLookups, calendar: calendar
        )
        let socialJetLagByDate = computeSocialJetLag(
            dateLookups: dateLookups, calendar: calendar
        )
        let monotonyByDate = computeTrainingLoadMonotony(
            dateLookups: dateLookups, calendar: calendar
        )
        // Use personal baselines for streak thresholds instead of hardcoded population values.
        // Falls back to population defaults only when no baseline exists.
        let sleepThreshold = baselines[.sleepDuration].map { max($0.mean - 0.5 * $0.standardDeviation, 5.0) } ?? 7.0
        let stepThreshold = baselines[.steps].map { max($0.mean - 0.5 * $0.standardDeviation, 3000) } ?? 8000.0
        let exerciseThreshold = baselines[.exerciseMinutes].map { max($0.mean - 0.5 * $0.standardDeviation, 10) } ?? 30.0

        let sleepStreakByDate = computeStreak(
            dateLookups: dateLookups, metric: .sleepDuration,
            threshold: sleepThreshold, calendar: calendar
        )
        let stepStreakByDate = computeStreak(
            dateLookups: dateLookups, metric: .steps,
            threshold: stepThreshold, calendar: calendar
        )
        let exerciseStreakByDate = computeStreak(
            dateLookups: dateLookups, metric: .exerciseMinutes,
            threshold: exerciseThreshold, calendar: calendar
        )

        // Enrich each vector
        return vectors.map { vector in
            let day = calendar.startOfDay(for: vector.date)
            var composites: [CompositeFeatureKey: Double] = [:]

            // 1. Autonomic Balance Index
            composites[CompositeFeatureKey(type: .autonomicBalance)] =
                computeAutonomicBalance(day: day, dateLookups: dateLookups)

            // 2. Sleep Quality Score
            composites[CompositeFeatureKey(type: .sleepQuality)] =
                computeSleepQuality(day: day, dateLookups: dateLookups)

            // 3. Exercise Intensity
            composites[CompositeFeatureKey(type: .exerciseIntensity)] =
                computeExerciseIntensity(day: day, dateLookups: dateLookups)

            // 4. Recovery Index
            composites[CompositeFeatureKey(type: .recoveryIndex)] =
                computeRecoveryIndex(vector: vector)

            // 5. ACWR
            composites[CompositeFeatureKey(type: .acuteChronicWorkloadRatio)] =
                acwrByDate[day] ?? CompositeFeatureKey.missingSentinel

            // 6. Monotone Fatigue Signal
            composites[CompositeFeatureKey(type: .monotoneFatigueSignal)] =
                fatigueByDate[day] ?? CompositeFeatureKey.missingSentinel

            // 7. Sleep Consistency
            composites[CompositeFeatureKey(type: .sleepConsistency)] =
                sleepConsistencyByDate[day] ?? CompositeFeatureKey.missingSentinel

            // 8. Social Jet Lag
            composites[CompositeFeatureKey(type: .socialJetLag)] =
                socialJetLagByDate[day] ?? CompositeFeatureKey.missingSentinel

            // 9. Training Load Monotony
            composites[CompositeFeatureKey(type: .trainingLoadMonotony)] =
                monotonyByDate[day] ?? CompositeFeatureKey.missingSentinel

            // 10. Behavioral Streaks
            composites[CompositeFeatureKey(type: .sleepStreak)] =
                sleepStreakByDate[day] ?? CompositeFeatureKey.missingSentinel
            composites[CompositeFeatureKey(type: .stepStreak)] =
                stepStreakByDate[day] ?? CompositeFeatureKey.missingSentinel
            composites[CompositeFeatureKey(type: .exerciseStreak)] =
                exerciseStreakByDate[day] ?? CompositeFeatureKey.missingSentinel

            return EnrichedDailyFeatureVector(base: vector, compositeFeatures: composites)
        }
    }

    // MARK: - Date-Indexed Lookups

    /// Build a per-metric dictionary mapping calendar days to raw values.
    private static func buildDateLookups(
        from timeSeries: [HealthMetric: MetricTimeSeries],
        calendar: Calendar
    ) -> [HealthMetric: [Date: Double]] {
        var lookups: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            var dateMap: [Date: Double] = [:]
            dateMap.reserveCapacity(series.sortedSamples.count)
            for sample in series.sortedSamples {
                let day = calendar.startOfDay(for: sample.date)
                dateMap[day] = sample.value
            }
            lookups[metric] = dateMap
        }
        return lookups
    }

    /// Retrieve a raw value for a metric on a specific day, or nil if unavailable.
    private static func rawValue(
        metric: HealthMetric,
        day: Date,
        dateLookups: [HealthMetric: [Date: Double]]
    ) -> Double? {
        dateLookups[metric]?[day]
    }

    // MARK: - 1. Autonomic Balance Index

    /// HRV / Resting Heart Rate.
    ///
    /// Measures the ratio of parasympathetic activity (HRV) to overall cardiac demand
    /// (resting HR). A higher ratio indicates better autonomic balance and recovery.
    /// Typical values range from 0.3 to 1.5 depending on fitness and age.
    private static func computeAutonomicBalance(
        day: Date,
        dateLookups: [HealthMetric: [Date: Double]]
    ) -> Double {
        guard let hrv = rawValue(metric: .heartRateVariability, day: day, dateLookups: dateLookups),
              let rhr = rawValue(metric: .restingHeartRate, day: day, dateLookups: dateLookups),
              rhr > 0 else {
            return CompositeFeatureKey.missingSentinel
        }
        return hrv / rhr
    }

    // MARK: - 2. Sleep Quality Score

    /// Sleep Duration (hours) * Deep Sleep Percentage.
    ///
    /// Combines total sleep time with the proportion spent in deep (slow-wave) sleep.
    /// Deep sleep percentage is derived as deepSleep / totalSleep. The product captures
    /// both quantity and restorative quality. a short but deep sleep may score similarly
    /// to a long but shallow one. Higher is better.
    private static func computeSleepQuality(
        day: Date,
        dateLookups: [HealthMetric: [Date: Double]]
    ) -> Double {
        guard let duration = rawValue(metric: .sleepDuration, day: day, dateLookups: dateLookups),
              let deep = rawValue(metric: .sleepDeep, day: day, dateLookups: dateLookups),
              duration > 0 else {
            return CompositeFeatureKey.missingSentinel
        }
        let deepPercentage = deep / duration  // Both in hours
        return duration * deepPercentage
    }

    // MARK: - 3. Exercise Intensity

    /// Active Calories / Steps. energy expenditure per step.
    ///
    /// A proxy for movement intensity: walking produces low values (~0.03-0.05 kcal/step)
    /// while running or stair climbing yields higher values. Zero steps returns sentinel
    /// to avoid division by zero.
    private static func computeExerciseIntensity(
        day: Date,
        dateLookups: [HealthMetric: [Date: Double]]
    ) -> Double {
        guard let calories = rawValue(metric: .activeCalories, day: day, dateLookups: dateLookups),
              let steps = rawValue(metric: .steps, day: day, dateLookups: dateLookups),
              steps > 0 else {
            return CompositeFeatureKey.missingSentinel
        }
        return calories / steps
    }

    // MARK: - 4. Recovery Index

    /// (HRV_zScore + SleepDuration_zScore - RestingHR_zScore) / 3.0.
    ///
    /// Multi-metric recovery signal using z-scored values from the base feature vector.
    /// HRV and sleep duration are positive contributors (higher = more recovered), while
    /// resting HR is inverted (lower = more recovered). The average produces a balanced
    /// composite centered near zero, where positive values indicate above-average recovery.
    private static func computeRecoveryIndex(vector: DailyFeatureVector) -> Double {
        let hrvZ = vector.features[FeatureKey(metric: .heartRateVariability, type: .raw)]
        let sleepZ = vector.features[FeatureKey(metric: .sleepDuration, type: .raw)]
        let rhrZ = vector.features[FeatureKey(metric: .restingHeartRate, type: .raw)]

        // Require all three z-scores and verify none are sentinel
        guard let h = hrvZ, h != FeatureKey.missingSentinel,
              let s = sleepZ, s != FeatureKey.missingSentinel,
              let r = rhrZ, r != FeatureKey.missingSentinel else {
            return CompositeFeatureKey.missingSentinel
        }
        return (h + s - r) / 3.0
    }

    // MARK: - 5. Acute-to-Chronic Workload Ratio (ACWR)

    /// 7-day exponentially weighted average of active calories / 28-day EWA.
    ///
    /// The ACWR is a standard sports science metric for monitoring injury risk.
    /// - Values 0.8–1.3: safe training zone ("sweet spot").
    /// - Values > 1.5: spike in acute load. elevated soft-tissue injury risk.
    /// - Values < 0.8: undertraining / detraining zone.
    ///
    /// Uses exponentially weighted averages rather than simple moving averages for
    /// smoother transitions and greater sensitivity to recent load changes.
    ///
    /// Requires at least 28 days of active calorie data.
    private static func computeACWR(
        dateLookups: [HealthMetric: [Date: Double]],
        calendar: Calendar
    ) -> [Date: Double] {
        guard let calorieDateMap = dateLookups[.activeCalories] else { return [:] }

        let sortedDays = calorieDateMap.keys.sorted()
        guard sortedDays.count >= 28 else { return [:] }

        // Exponential decay factors
        // 7-day EWA: alpha = 2/(7+1) = 0.25
        // 28-day EWA: alpha = 2/(28+1) ≈ 0.069
        let alphaAcute = 2.0 / 8.0
        let alphaChronic = 2.0 / 29.0

        var acuteEWA = calorieDateMap[sortedDays[0]] ?? 0
        var chronicEWA = acuteEWA
        var result: [Date: Double] = [:]

        for (index, day) in sortedDays.enumerated() {
            let value = calorieDateMap[day] ?? 0
            acuteEWA = alphaAcute * value + (1.0 - alphaAcute) * acuteEWA
            chronicEWA = alphaChronic * value + (1.0 - alphaChronic) * chronicEWA

            // Only emit values once we have 28 days of warm-up
            if index >= 27 && chronicEWA > 0 {
                result[day] = acuteEWA / chronicEWA
            }
        }

        return result
    }

    // MARK: - 6. Monotone Fatigue Signal

    /// Consecutive days with HRV below personal baseline mean.
    ///
    /// Sustained periods of suppressed HRV indicate accumulated autonomic fatigue.
    /// Unlike single-day anomalies, the monotone count captures the *duration* of
    /// sub-baseline performance. a critical factor in overtraining syndrome detection.
    /// The count resets to zero whenever HRV returns to or above the baseline.
    ///
    /// Requires at least 7 days of HRV data and a computed HRV baseline.
    private static func computeMonotoneFatigue(
        dateLookups: [HealthMetric: [Date: Double]],
        baselines: [HealthMetric: UserBaseline],
        calendar: Calendar
    ) -> [Date: Double] {
        guard let hrvDateMap = dateLookups[.heartRateVariability],
              let baseline = baselines[.heartRateVariability] else {
            return [:]
        }

        let sortedDays = hrvDateMap.keys.sorted()
        guard sortedDays.count >= minimumDays(for: .monotoneFatigueSignal) else { return [:] }

        let baselineMean = baseline.mean
        var consecutiveBelow = 0
        var result: [Date: Double] = [:]

        for day in sortedDays {
            guard let hrv = hrvDateMap[day] else {
                // Missing day does not break the streak, but does not extend it either.
                result[day] = Double(consecutiveBelow)
                continue
            }

            if hrv < baselineMean {
                consecutiveBelow += 1
            } else {
                consecutiveBelow = 0
            }
            result[day] = Double(consecutiveBelow)
        }

        return result
    }

    // MARK: - 7. Sleep Consistency

    /// Standard deviation of sleep midpoint over the trailing 7 days (in hours).
    ///
    /// Sleep midpoint is estimated as sleepDuration / 2, measured from the assumption
    /// that HealthKit sleep duration is centered around the actual midpoint. When actual
    /// bedtime/wake data is unavailable, this proxy captures variability in sleep timing.
    /// Lower values indicate more consistent circadian rhythm. A consistency above 1.5 hours
    /// is associated with increased metabolic and cognitive risk.
    ///
    /// Requires at least 7 days of sleep duration data.
    private static func computeSleepConsistency(
        dateLookups: [HealthMetric: [Date: Double]],
        calendar: Calendar
    ) -> [Date: Double] {
        guard let sleepDateMap = dateLookups[.sleepDuration] else { return [:] }

        let sortedDays = sleepDateMap.keys.sorted()
        guard sortedDays.count >= minimumDays(for: .sleepConsistency) else { return [:] }

        var result: [Date: Double] = [:]

        for (index, day) in sortedDays.enumerated() {
            guard index >= 6 else { continue }  // Need 7 days of history

            // Collect sleep durations for the trailing 7 days
            var windowValues: [Double] = []
            windowValues.reserveCapacity(7)

            for offset in 0..<7 {
                guard let lookbackDate = calendar.date(byAdding: .day, value: -offset, to: day),
                      let value = sleepDateMap[lookbackDate] else {
                    continue
                }
                // Use duration / 2 as proxy for sleep midpoint (hours from midnight)
                windowValues.append(value / 2.0)
            }

            guard windowValues.count >= 4 else {
                // Not enough data points in the window
                result[day] = CompositeFeatureKey.missingSentinel
                continue
            }

            // Use Accelerate for vectorized variance computation
            let (_, variance) = AccelerateML.welfordVariance(windowValues)
            result[day] = variance.squareRoot()
        }

        return result
    }

    // MARK: - 8. Social Jet Lag

    /// |weekday sleep midpoint - weekend sleep midpoint| in hours.
    ///
    /// Social jet lag quantifies the circadian misalignment between work days and free days.
    /// It is strongly associated with metabolic syndrome, obesity, and cardiovascular risk.
    /// Values above 2.0 hours indicate clinically significant social jet lag.
    ///
    /// Computed over a rolling 14-day window to capture at least two weekends.
    /// Uses sleep duration / 2 as a proxy for sleep midpoint.
    ///
    /// Requires at least 14 days of sleep data with both weekday and weekend coverage.
    private static func computeSocialJetLag(
        dateLookups: [HealthMetric: [Date: Double]],
        calendar: Calendar
    ) -> [Date: Double] {
        guard let sleepDateMap = dateLookups[.sleepDuration] else { return [:] }

        let sortedDays = sleepDateMap.keys.sorted()
        guard sortedDays.count >= minimumDays(for: .socialJetLag) else { return [:] }

        var result: [Date: Double] = [:]

        for (index, day) in sortedDays.enumerated() {
            guard index >= 13 else { continue }  // Need 14-day window

            var weekdayMidpoints: [Double] = []
            var weekendMidpoints: [Double] = []

            for offset in 0..<14 {
                guard let lookbackDate = calendar.date(byAdding: .day, value: -offset, to: day),
                      let duration = sleepDateMap[lookbackDate] else {
                    continue
                }

                let midpoint = duration / 2.0
                let dayOfWeek = calendar.component(.weekday, from: lookbackDate)
                let isWeekend = (dayOfWeek == 1 || dayOfWeek == 7)  // Sun=1, Sat=7

                if isWeekend {
                    weekendMidpoints.append(midpoint)
                } else {
                    weekdayMidpoints.append(midpoint)
                }
            }

            // Require at least 2 weekday and 2 weekend data points
            guard weekdayMidpoints.count >= 2, weekendMidpoints.count >= 2 else {
                result[day] = CompositeFeatureKey.missingSentinel
                continue
            }

            let weekdayMean = AccelerateML.mean(weekdayMidpoints)
            let weekendMean = AccelerateML.mean(weekendMidpoints)
            result[day] = abs(weekdayMean - weekendMean)
        }

        return result
    }

    // MARK: - 9. Training Load Monotony

    /// 7-day mean of daily workout load / 7-day standard deviation.
    ///
    /// Monotony measures how uniform the training load distribution is across the week.
    /// High monotony (>2.0) combined with high total load is a strong predictor of
    /// overtraining, illness, and burnout. It indicates insufficient variation in daily
    /// training stress.
    ///
    /// Uses active calories as the load metric. Requires at least 7 days.
    private static func computeTrainingLoadMonotony(
        dateLookups: [HealthMetric: [Date: Double]],
        calendar: Calendar
    ) -> [Date: Double] {
        guard let calorieDateMap = dateLookups[.activeCalories] else { return [:] }

        let sortedDays = calorieDateMap.keys.sorted()
        guard sortedDays.count >= minimumDays(for: .trainingLoadMonotony) else { return [:] }

        var result: [Date: Double] = [:]

        for (index, day) in sortedDays.enumerated() {
            guard index >= 6 else { continue }

            var windowValues: [Double] = []
            windowValues.reserveCapacity(7)

            for offset in 0..<7 {
                guard let lookbackDate = calendar.date(byAdding: .day, value: -offset, to: day),
                      let value = calorieDateMap[lookbackDate] else {
                    continue
                }
                windowValues.append(value)
            }

            guard windowValues.count >= 5 else {
                result[day] = CompositeFeatureKey.missingSentinel
                continue
            }

            let (mean, variance) = AccelerateML.welfordVariance(windowValues)
            let stdDev = variance.squareRoot()

            // Avoid division by zero. if stdDev is near zero, load is perfectly uniform
            // which is itself a high-monotony signal. Cap at a practical maximum.
            guard stdDev > 1.0 else {
                result[day] = mean > 0 ? 10.0 : 0.0  // Capped maximum monotony
                continue
            }

            result[day] = mean / stdDev
        }

        return result
    }

    // MARK: - 10. Behavioral Streak Features

    /// Compute consecutive-day streak for a metric exceeding a threshold.
    ///
    /// Streaks capture behavioral consistency. a powerful predictor of long-term health
    /// outcomes. Each streak type tracks how many consecutive days the user has met a
    /// specific target:
    /// - **Sleep streak** (>= 7 hours): adequate sleep duration.
    /// - **Step streak** (>= 8000 steps): sufficient daily movement.
    /// - **Exercise streak** (>= 30 minutes): active exercise habit.
    ///
    /// The streak count resets to zero on any day below the threshold or with missing data.
    ///
    /// Requires at least 7 days of data for the target metric.
    private static func computeStreak(
        dateLookups: [HealthMetric: [Date: Double]],
        metric: HealthMetric,
        threshold: Double,
        calendar: Calendar
    ) -> [Date: Double] {
        guard let dateMap = dateLookups[metric] else { return [:] }

        let sortedDays = dateMap.keys.sorted()
        guard sortedDays.count >= 7 else { return [:] }

        // Build a dense day-by-day sequence to detect true consecutive days
        guard let firstDay = sortedDays.first, let lastDay = sortedDays.last else { return [:] }
        let totalSpan = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0

        var streak = 0
        var result: [Date: Double] = [:]

        for offset in 0...totalSpan {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: day)

            if let value = dateMap[dayStart], value >= threshold {
                streak += 1
            } else {
                streak = 0
            }

            result[dayStart] = Double(streak)
        }

        return result
    }
}
