import Foundation

/// Monitors body stress patterns by watching for sustained multi-day deviations across
/// key physiological metrics simultaneously.
///
/// The core insight: single-metric deviations are noisy. When resting heart rate, HRV,
/// sleep, activity, and respiratory rate all shift unfavorably at the same time for
/// multiple consecutive days, the probability of increased body stress is significantly higher.
struct IllnessEarlyWarning {

    // MARK: - Public Types

    /// A signal from a single metric indicating an unfavorable deviation from baseline
    struct MetricSignal {
        let metric: HealthMetric
        let currentValue: Double
        let baselineValue: Double
        let deviationSigma: Double      // how many stddevs from baseline
        let direction: String           // "elevated" or "depressed"
    }

    /// A body stress warning combining signals from multiple metrics
    struct Warning: Identifiable {
        let id = UUID()
        let severity: Severity
        let confidence: Int             // 0-100
        let activeSignals: [MetricSignal]
        let daysElevated: Int           // consecutive days with multi-metric signals
        let narrative: String           // human-readable explanation
    }

    // MARK: - Signal Configuration

    /// Defines how each monitored metric should be interpreted for body stress detection.
    /// `unfavorableDirection` is the direction that indicates stress:
    ///   - `.above` means values above baseline are concerning (e.g., resting HR going up)
    ///   - `.below` means values below baseline are concerning (e.g., HRV dropping)
    private enum UnfavorableDirection {
        case above
        case below
    }

    private struct SignalConfig {
        let metric: HealthMetric
        let unfavorableDirection: UnfavorableDirection
        let isSleepDuration: Bool       // special handling: only counts if other signals present
    }

    private static let signalMetrics: [SignalConfig] = [
        SignalConfig(metric: .restingHeartRate, unfavorableDirection: .above, isSleepDuration: false),
        SignalConfig(metric: .heartRateVariability, unfavorableDirection: .below, isSleepDuration: false),
        SignalConfig(metric: .sleepDuration, unfavorableDirection: .below, isSleepDuration: true),
        SignalConfig(metric: .steps, unfavorableDirection: .below, isSleepDuration: false),
        SignalConfig(metric: .respiratoryRate, unfavorableDirection: .above, isSleepDuration: false),
    ]

    /// Minimum standard deviations from baseline to count as a signal
    private static let signalThresholdSigma: Double = 1.0

    /// Minimum days of historical data required to establish a reliable baseline
    private static let minimumDataDays: Int = 14

    /// How many recent days to check for body stress signals
    private static let recentWindowDays: Int = 3

    /// How many days to skip (these may already be part of the stress pattern)
    private static let baselineGapDays: Int = 3

    /// Days before the gap to use for baseline computation (days 4-17 ago)
    private static let baselineWindowDays: Int = 14

    /// Active calories multiplier above baseline that suggests exercise recovery, not body stress
    private static let exerciseRecoveryMultiplier: Double = 1.5

    /// Minimum number of metrics that must signal simultaneously before any warning is surfaced.
    private static let minSignalingMetrics: Int = 2
    /// Minimum number of consecutive multi-metric days before a warning is surfaced.
    private static let minDaysElevatedForWarning: Int = 2
    /// Signal count at/above which severity escalates beyond `.info`.
    private static let highSignalCount: Int = 3
    /// Days elevated at/above which a high-signal warning escalates to `.critical`.
    private static let criticalDaysElevated: Int = 3
    /// Floor on baseline standard deviation below which z-scores are treated as undefined.
    private static let baselineSDFloor: Double = 0.001
    /// Confidence points awarded when exactly two metrics are signaling.
    private static let confidenceTwoMetricPoints: Double = 20
    /// Confidence points awarded when exactly three metrics are signaling.
    private static let confidenceThreeMetricPoints: Double = 30
    /// Confidence points awarded when exactly four metrics are signaling.
    private static let confidenceFourMetricPoints: Double = 40
    /// Per-metric coefficient applied beyond four signaling metrics, capped at the metric ceiling.
    private static let confidencePerMetricBeyondFour: Double = 9
    /// Maximum confidence points awarded from the metric-count component.
    private static let confidenceMetricCeiling: Double = 45
    /// Confidence points awarded when the streak is exactly two days.
    private static let confidenceTwoDayPoints: Double = 15
    /// Confidence points awarded when the streak is exactly three days.
    private static let confidenceThreeDayPoints: Double = 25
    /// Per-day coefficient applied beyond a 3-day streak, capped at the day ceiling.
    private static let confidencePerDayBeyondThree: Double = 10
    /// Maximum confidence points awarded from the days-elevated component.
    private static let confidenceDaysCeiling: Double = 30
    /// Confidence points awarded per sigma above the signal threshold.
    private static let confidencePerSigmaAboveThreshold: Double = 12.5
    /// Maximum confidence points awarded from the deviation-magnitude component.
    private static let confidenceMagnitudeCeiling: Double = 25

    // MARK: - Public API

    /// Evaluate all signal metrics for body stress patterns.
    ///
    /// - Parameters:
    ///   - timeSeries: Time series data keyed by health metric
    ///   - baselines: Personal baselines keyed by health metric (used for exercise recovery check)
    /// - Returns: Array of warnings, sorted by severity (most severe first). Empty if no warning.
    static func evaluate(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [Warning] {
        let calendar = Date.cal
        let now = Date()

        // If the user had intense workouts during the signal window, skip detection
        // (elevated RHR + depressed HRV after a hard workout is normal recovery, not body stress)
        if isExerciseRecoveryLikely(timeSeries: timeSeries, baselines: baselines, calendar: calendar, now: now) {
            return []
        }

        // Step 1: Compute per-day signals for each metric over the recent window
        let dailySignals = computeDailySignals(timeSeries: timeSeries, calendar: calendar, now: now)

        // Step 2: For each day in the recent window, determine which metrics are signaling
        let consecutiveResult = computeConsecutiveMultiMetricDays(dailySignals: dailySignals)

        guard consecutiveResult.daysElevated >= minDaysElevatedForWarning,
              consecutiveResult.signalingMetrics.count >= minSignalingMetrics else {
            return []
        }

        // Step 3: Build MetricSignal objects for all signaling metrics
        let activeSignals = buildActiveSignals(
            signalingMetrics: consecutiveResult.signalingMetrics,
            timeSeries: timeSeries,
            calendar: calendar,
            now: now
        )

        // Step 4: Apply sleep-duration special rule. only count it if other signals are present
        let nonSleepSignals = activeSignals.filter { $0.metric != .sleepDuration }
        let finalSignals: [MetricSignal]
        if nonSleepSignals.count >= minSignalingMetrics {
            // Other signals present, sleep duration can join
            finalSignals = activeSignals
        } else {
            // Without enough non-sleep signals, drop sleep duration
            finalSignals = nonSleepSignals
        }

        guard finalSignals.count >= minSignalingMetrics else { return [] }

        // Step 5: Determine severity
        let severity = determineSeverity(
            signalCount: finalSignals.count,
            daysElevated: consecutiveResult.daysElevated
        )

        // Step 6: Compute confidence score
        let confidence = computeConfidence(
            signals: finalSignals,
            daysElevated: consecutiveResult.daysElevated
        )

        // Step 7: Generate narrative
        let narrative = generateNarrative(signals: finalSignals, daysElevated: consecutiveResult.daysElevated)

        let warning = Warning(
            severity: severity,
            confidence: confidence,
            activeSignals: finalSignals,
            daysElevated: consecutiveResult.daysElevated,
            narrative: narrative
        )

        return [warning]
    }

    /// Convert warnings into Insight objects for the insight pipeline.
    static func generateInsights(from warnings: [Warning]) -> [Insight] {
        warnings.map { warning in
            let relatedMetrics = warning.activeSignals.map(\.metric)
            let primaryMetric = relatedMetrics.first ?? .restingHeartRate

            let recommendation = generateRecommendation(
                signals: warning.activeSignals,
                daysElevated: warning.daysElevated,
                severity: warning.severity
            )

            return Insight(
                metric: primaryMetric,
                title: insightTitle(for: warning),
                summary: warning.narrative,
                recommendation: recommendation,
                severity: warning.severity,
                trend: .declining,
                currentValue: Double(warning.confidence),
                baselineValue: 0,
                deviationPercent: Double(warning.activeSignals.count * 10),
                category: .watchSignal,
                relatedMetrics: relatedMetrics
            )
        }
    }

    // MARK: - Daily Signal Computation

    /// For each signal metric, compute whether it was deviating unfavorably on each
    /// of the last `recentWindowDays` days.
    /// Returns a dictionary: metric -> [dayIndex: deviation in sigma], where dayIndex 0 = today.
    private static func computeDailySignals(
        timeSeries: [HealthMetric: MetricTimeSeries],
        calendar: Calendar,
        now: Date
    ) -> [HealthMetric: [Int: Double]] {
        var dailySignals: [HealthMetric: [Int: Double]] = [:]

        for config in signalMetrics {
            guard let series = timeSeries[config.metric] else { continue }

            // Compute a personal baseline from days (baselineGapDays + 1) through
            // (baselineGapDays + baselineWindowDays) ago, skipping the recent window
            let baselineStart = calendar.date(byAdding: .day, value: -(baselineGapDays + baselineWindowDays), to: now) ?? now
            let baselineEnd = calendar.date(byAdding: .day, value: -(baselineGapDays + 1), to: now) ?? now

            let baselineSamples = series.samples(from: baselineStart, to: baselineEnd)
            let baselineValues = baselineSamples.map(\.value)

            // Require enough data to form a meaningful baseline
            guard baselineValues.count >= minimumDataDays else { continue }

            let baselineMean = baselineValues.mean
            let baselineSD = baselineValues.standardDeviation

            // If stddev is effectively zero, we can't compute meaningful z-scores
            guard baselineSD > baselineSDFloor else { continue }

            var metricDailySignals: [Int: Double] = [:]

            // Check each day in the recent window (0 = most recent, recentWindowDays-1 = oldest)
            for dayOffset in 0..<recentWindowDays {
                let dayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now

                let daySamples = series.samples(from: dayStart, to: dayEnd)
                guard !daySamples.isEmpty else { continue }

                let dayMean = daySamples.map(\.value).mean
                let deviation = (dayMean - baselineMean) / baselineSD

                // Check if the deviation is in the unfavorable direction and exceeds threshold
                let isUnfavorable: Bool
                switch config.unfavorableDirection {
                case .above:
                    isUnfavorable = deviation >= signalThresholdSigma
                case .below:
                    isUnfavorable = deviation <= -signalThresholdSigma
                }

                if isUnfavorable {
                    metricDailySignals[dayOffset] = abs(deviation)
                }
            }

            if !metricDailySignals.isEmpty {
                dailySignals[config.metric] = metricDailySignals
            }
        }

        return dailySignals
    }

    // MARK: - Consecutive Day Analysis

    private struct ConsecutiveResult {
        let daysElevated: Int
        let signalingMetrics: Set<HealthMetric>
    }

    /// Determine how many consecutive recent days had 2+ metrics signaling simultaneously.
    /// Counts backwards from today. the streak must be unbroken from the most recent day.
    private static func computeConsecutiveMultiMetricDays(
        dailySignals: [HealthMetric: [Int: Double]]
    ) -> ConsecutiveResult {
        var consecutiveDays = 0
        var allSignalingMetrics: Set<HealthMetric> = []

        // Walk backwards from today (dayOffset 0) through the recent window
        for dayOffset in 0..<recentWindowDays {
            var metricsSignalingToday: Set<HealthMetric> = []

            for (metric, days) in dailySignals {
                if days[dayOffset] != nil {
                    metricsSignalingToday.insert(metric)
                }
            }

            if metricsSignalingToday.count >= minSignalingMetrics {
                consecutiveDays += 1
                allSignalingMetrics.formUnion(metricsSignalingToday)
            } else {
                // Streak broken
                break
            }
        }

        return ConsecutiveResult(daysElevated: consecutiveDays, signalingMetrics: allSignalingMetrics)
    }

    // MARK: - Active Signal Construction

    /// Build MetricSignal objects with current and baseline values for all signaling metrics.
    private static func buildActiveSignals(
        signalingMetrics: Set<HealthMetric>,
        timeSeries: [HealthMetric: MetricTimeSeries],
        calendar: Calendar,
        now: Date
    ) -> [MetricSignal] {
        var signals: [MetricSignal] = []

        for config in signalMetrics {
            guard signalingMetrics.contains(config.metric),
                  let series = timeSeries[config.metric] else { continue }

            let baselineStart = calendar.date(byAdding: .day, value: -(baselineGapDays + baselineWindowDays), to: now) ?? now
            let baselineEnd = calendar.date(byAdding: .day, value: -(baselineGapDays + 1), to: now) ?? now

            let baselineValues = series.samples(from: baselineStart, to: baselineEnd).map(\.value)
            guard !baselineValues.isEmpty else { continue }

            let baselineMean = baselineValues.mean
            let baselineSD = baselineValues.standardDeviation
            guard baselineSD > baselineSDFloor else { continue }

            // Current value: average of the recent window
            let recentSamples = series.samples(lastDays: recentWindowDays)
            guard !recentSamples.isEmpty else { continue }
            let currentValue = recentSamples.map(\.value).mean

            let deviation = (currentValue - baselineMean) / baselineSD

            let direction: String
            switch config.unfavorableDirection {
            case .above: direction = "elevated"
            case .below: direction = "depressed"
            }

            signals.append(MetricSignal(
                metric: config.metric,
                currentValue: currentValue,
                baselineValue: baselineMean,
                deviationSigma: abs(deviation),
                direction: direction
            ))
        }

        return signals
    }

    // MARK: - Exercise Recovery Guard

    /// Check if the user had intense workouts during the signal window.
    /// If activeCalories on any of the signal days were > 1.5x their baseline,
    /// it is more likely exercise recovery than body stress.
    private static func isExerciseRecoveryLikely(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        calendar: Calendar,
        now: Date
    ) -> Bool {
        guard let caloriesSeries = timeSeries[.activeCalories],
              let caloriesBaseline = baselines[.activeCalories],
              caloriesBaseline.mean > 0 else {
            return false
        }

        let threshold = caloriesBaseline.mean * exerciseRecoveryMultiplier

        // Check each day in the recent signal window
        for dayOffset in 0..<recentWindowDays {
            let dayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? now

            let daySamples = caloriesSeries.samples(from: dayStart, to: dayEnd)
            guard !daySamples.isEmpty else { continue }

            let dayTotal = daySamples.map(\.value).reduce(0, +)
            if dayTotal > threshold {
                return true
            }
        }

        return false
    }

    // MARK: - Severity Determination

    /// Level is based on how many metrics are signaling and for how many consecutive days.
    ///
    /// - 2 metrics for 2+ days = `.info` (early heads up)
    /// - 3+ metrics for 2 days = `.warning` (clear multi-system deviation)
    /// - 3+ metrics for 3+ days = `.critical` (sustained multi-system strain)
    private static func determineSeverity(signalCount: Int, daysElevated: Int) -> Severity {
        if signalCount >= highSignalCount && daysElevated >= criticalDaysElevated {
            return .critical
        } else if signalCount >= highSignalCount && daysElevated >= minDaysElevatedForWarning {
            return .warning
        } else {
            return .info
        }
    }

    // MARK: - Confidence Scoring

    /// Confidence score (0-100) based on:
    /// - Number of metrics signaling (more metrics = higher confidence)
    /// - Consecutive days (longer streak = higher confidence)
    /// - Magnitude of deviation (bigger deviations = higher confidence)
    private static func computeConfidence(signals: [MetricSignal], daysElevated: Int) -> Int {
        // Component 1: Number of metrics (max 5 signal metrics)
        let metricScore: Double
        switch signals.count {
        case 2: metricScore = confidenceTwoMetricPoints
        case 3: metricScore = confidenceThreeMetricPoints
        case 4: metricScore = confidenceFourMetricPoints
        default: metricScore = min(Double(signals.count) * confidencePerMetricBeyondFour, confidenceMetricCeiling)
        }

        // Component 2: Consecutive days (max 3 in our window)
        let daysScore: Double
        switch daysElevated {
        case 2: daysScore = confidenceTwoDayPoints
        case 3: daysScore = confidenceThreeDayPoints
        default: daysScore = min(Double(daysElevated) * confidencePerDayBeyondThree, confidenceDaysCeiling)
        }

        // Component 3: Average magnitude of deviation (capped contribution)
        let avgSigma = signals.map(\.deviationSigma).mean
        let magnitudeScore = min((avgSigma - signalThresholdSigma) * confidencePerSigmaAboveThreshold, confidenceMagnitudeCeiling)

        let raw = metricScore + daysScore + max(magnitudeScore, 0)
        return min(Int(raw.rounded()), 100)
    }

    // MARK: - Narrative Generation

    /// Build a human-readable narrative describing the multi-metric pattern.
    /// Uses non-diagnostic language. describes physiological strain, not specific conditions.
    private static func generateNarrative(signals: [MetricSignal], daysElevated: Int) -> String {
        let daysLabel = daysElevated == 1 ? "day" : "days"
        var parts: [String] = []

        for signal in signals {
            let metricName = signal.metric.displayName.lowercased()
            let formatted = signal.metric.formatValue(signal.currentValue)
            let baselineFormatted = signal.metric.formatValue(signal.baselineValue)
            let unit = signal.metric.unit

            let deviationDescription: String
            if signal.baselineValue > baselineSDFloor {
                let pctChange = abs((signal.currentValue - signal.baselineValue) / signal.baselineValue) * 100
                deviationDescription = String(format: "%.0f%%", pctChange)
            } else {
                deviationDescription = String(format: "%.1f\u{03C3}", signal.deviationSigma)
            }

            switch signal.direction {
            case "elevated":
                parts.append("\(metricName) has trended \(deviationDescription) above baseline for \(daysElevated) \(daysLabel) (\(formatted) vs \(baselineFormatted) \(unit))")
            case "depressed":
                parts.append("\(metricName) dropped \(deviationDescription) below baseline over \(daysElevated) \(daysLabel) (\(formatted) vs \(baselineFormatted) \(unit))")
            default:
                parts.append("\(metricName) deviated \(deviationDescription) from baseline")
            }
        }

        let signalSummary: String
        if parts.count == 1 {
            signalSummary = "Your " + parts[0] + "."
        } else if parts.count == 2 {
            signalSummary = "Your " + parts[0] + ", while your " + parts[1] + "."
        } else {
            let allButLast = parts.dropLast().map { "your " + $0 }
            let last = "your " + parts.last!
            signalSummary = allButLast.joined(separator: ", ") + ", and " + last + "."
        }

        let patternNote = Copy.Analysis.StrainSignals.multiMetricPattern

        return signalSummary + " " + patternNote
    }

    // MARK: - Insight Text

    /// Generate a concise insight title based on warning severity.
    private static func insightTitle(for warning: Warning) -> String {
        switch warning.severity {
        case .critical:
            return Copy.Analysis.StrainSignals.significantStrain
        case .warning:
            return Copy.Analysis.StrainSignals.multipleMetricStrain
        case .info:
            return Copy.Analysis.StrainSignals.earlyPhysiologicalStrain
        }
    }

    /// Generate data-driven observations about the signals present.
    private static func generateRecommendation(
        signals: [MetricSignal],
        daysElevated: Int,
        severity: Severity
    ) -> String {
        var observations: [String] = []

        // Core observation always present
        observations.append("Your body is showing strain across \(signals.count) metrics over \(daysElevated) consecutive days.")

        // Rest priority. state data, not prescription
        if severity >= .warning {
            observations.append("Your body is showing strain across \(signals.count) metrics simultaneously.")
        } else {
            observations.append(Copy.Analysis.StrainSignals.multipleMetricsShifted)
        }

        // State data observation
        observations.append(Copy.Analysis.StrainSignals.consistentWithPhysiologicalStrain)

        // Sleep-specific observation if HRV or RHR are signaling
        let hasCardiacSignal = signals.contains { $0.metric == .restingHeartRate || $0.metric == .heartRateVariability }
        if hasCardiacSignal {
            observations.append(Copy.Analysis.StrainSignals.cardiacMetricsStrain)
        }

        // Activity-specific observation
        let hasActivityDecline = signals.contains { $0.metric == .steps }
        if hasActivityDecline {
            observations.append(Copy.Analysis.StrainSignals.activityNotReturned)
        }

        // Critical-level: state the severity of the data pattern
        if severity == .critical {
            observations.append("This is a sustained multi-metric deviation. \(signals.count) signals active for \(daysElevated) consecutive days.")
        }

        return observations.joined(separator: " ")
    }
}

// MARK: - InsightAnalyzer Conformance

extension IllnessEarlyWarning: InsightAnalyzer {
    static var analyzerID: String { "illnessEarlyWarning" }
    static var insightCategory: InsightCategory { .watchSignal }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(from: context.illnessWarnings)
    }
}
