import Foundation

/// Discovers correlations between user-logged journal behaviors and next-day health outcomes.
/// Pairs journal entries with health metrics (HRV, resting HR, sleep quality) using Pearson correlation
/// and generates personalized, data-backed insight strings.
struct JournalCorrelationAnalyzer {

    // MARK: - Types

    /// A discovered correlation between a journal behavior and a health outcome
    struct JournalCorrelation: Identifiable {
        let id = UUID()
        let category: JournalCategory
        let healthMetric: HealthMetric
        let correlation: Double          // Pearson r
        let insight: String              // Human-readable insight
        let sampleCount: Int
        let avgOutcomeHigh: Double       // Avg outcome when behavior is above median
        let avgOutcomeLow: Double        // Avg outcome when behavior is below median
        let effectPercent: Double         // Percent difference between high/low groups

        var strengthLabel: String {
            let absR = abs(correlation)
            if absR >= 0.6 { return Copy.Journal.correlationStrong }
            if absR >= 0.4 { return Copy.Journal.correlationModerate }
            return Copy.Journal.correlationMild
        }

        var confidenceLevel: ConfidenceLevel {
            let absR = abs(correlation)
            if sampleCount >= 30 && absR >= 0.4 { return .high }
            if sampleCount >= 20 && absR >= 0.3 { return .medium }
            return .emerging
        }
    }

    enum ConfidenceLevel: String {
        case high = "High Confidence"
        case medium = "Confidence Growing"
        case emerging = "Emerging Pattern"

        var icon: String {
            switch self {
            case .high: return "checkmark.seal.fill"
            case .medium: return "chart.line.uptrend.xyaxis"
            case .emerging: return "sparkles"
            }
        }
    }

    // MARK: - Curated Outcome Pairs

    /// Physiologically plausible journal→health pairs to test
    private struct OutcomePair {
        let category: JournalCategory
        let metric: HealthMetric
        let dayOffset: Int             // 0 = same day, 1 = next day
        let positiveIsGood: Bool       // Whether higher behavior value → better outcome
    }

    private static let outcomePairs: [OutcomePair] = [
        // Caffeine → sleep/recovery (next day for sleep, same day for HR)
        OutcomePair(category: .caffeine, metric: .sleepDuration, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .caffeine, metric: .sleepDeep, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .caffeine, metric: .heartRateVariability, dayOffset: 1, positiveIsGood: false),
        OutcomePair(category: .caffeine, metric: .restingHeartRate, dayOffset: 1, positiveIsGood: false),

        // Alcohol → sleep/recovery
        OutcomePair(category: .alcohol, metric: .sleepDeep, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .alcohol, metric: .sleepREM, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .alcohol, metric: .heartRateVariability, dayOffset: 1, positiveIsGood: false),
        OutcomePair(category: .alcohol, metric: .restingHeartRate, dayOffset: 1, positiveIsGood: false),

        // Stress → recovery
        OutcomePair(category: .stress, metric: .heartRateVariability, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .stress, metric: .restingHeartRate, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .stress, metric: .sleepDuration, dayOffset: 0, positiveIsGood: false),

        // Meditation → recovery
        OutcomePair(category: .meditation, metric: .heartRateVariability, dayOffset: 0, positiveIsGood: true),
        OutcomePair(category: .meditation, metric: .restingHeartRate, dayOffset: 0, positiveIsGood: true),
        OutcomePair(category: .meditation, metric: .sleepDeep, dayOffset: 0, positiveIsGood: true),

        // Screen time → sleep
        OutcomePair(category: .screenTime, metric: .sleepDuration, dayOffset: 0, positiveIsGood: false),
        OutcomePair(category: .screenTime, metric: .sleepDeep, dayOffset: 0, positiveIsGood: false),

        // Meal timing → sleep
        OutcomePair(category: .mealTiming, metric: .sleepDeep, dayOffset: 0, positiveIsGood: true),
        OutcomePair(category: .mealTiming, metric: .sleepDuration, dayOffset: 0, positiveIsGood: true),

        // Water → recovery
        OutcomePair(category: .water, metric: .heartRateVariability, dayOffset: 1, positiveIsGood: true),
        OutcomePair(category: .water, metric: .restingHeartRate, dayOffset: 1, positiveIsGood: true),

        // Mood → activity/recovery
        OutcomePair(category: .mood, metric: .heartRateVariability, dayOffset: 0, positiveIsGood: true),
        OutcomePair(category: .mood, metric: .sleepDuration, dayOffset: 0, positiveIsGood: true),

        // Supplements → recovery
        OutcomePair(category: .supplements, metric: .heartRateVariability, dayOffset: 1, positiveIsGood: true),
    ]

    // MARK: - Minimum Data Points

    /// Minimum number of paired data points required to compute a correlation.
    /// Shared with the onboarding verdict engine so both surfaces judge the
    /// same claim against the same evidence bar.
    static let minimumDataPoints = InsightConfig.Correlation.minPairedDays

    // MARK: - Analysis

    /// Analyze all curated journal-health pairs and return significant correlations.
    /// - Parameters:
    ///   - journalStore: Store for querying journal entries
    ///   - timeSeries: Health metric time series from HealthDataStore
    ///   - lookbackDays: How many days of data to consider (default 90)
    static func analyze(
        journalStore: JournalStore,
        timeSeries: [HealthMetric: MetricTimeSeries],
        lookbackDays: Int = 90
    ) -> [JournalCorrelation] {
        let calendar = Date.cal
        var results: [JournalCorrelation] = []

        for pair in outcomePairs {
            guard let healthSeries = timeSeries[pair.metric] else { continue }

            // Build date-indexed lookups
            let journalByDate = journalStore.dateIndexedValues(for: pair.category, days: lookbackDays)
            guard journalByDate.count >= minimumDataPoints else { continue }

            let healthByDate = buildDateLookup(samples: healthSeries.sortedSamples, calendar: calendar)

            // Collect paired observations with day offset
            var journalValues: [Double] = []
            var healthValues: [Double] = []

            for (date, journalValue) in journalByDate {
                let outcomeDate: Date
                if pair.dayOffset > 0 {
                    outcomeDate = calendar.date(byAdding: .day, value: pair.dayOffset, to: date) ?? date
                } else {
                    outcomeDate = date
                }

                if let healthValue = healthByDate[outcomeDate] {
                    journalValues.append(journalValue)
                    healthValues.append(healthValue)
                }
            }

            guard journalValues.count >= minimumDataPoints else { continue }

            // Compute Pearson correlation. The old 0.15 gate sat below the
            // noise floor at n=14, so random data cleared it; confirmR is the
            // significance threshold (critical r at df=12, p<0.05).
            let r = pearsonCorrelation(x: journalValues, y: healthValues)
            guard abs(r) >= InsightConfig.Correlation.confirmR else { continue }

            // Compute conditional effect: above-median vs below-median behavior
            let effect = computeMedianSplitEffect(
                journalValues: journalValues,
                healthValues: healthValues,
                metric: pair.metric
            )
            guard abs(effect.percentDiff) >= InsightConfig.Correlation.medianSplitFloorPercent else { continue }

            // Generate personalized insight string
            let insight = generateInsight(
                pair: pair,
                r: r,
                effect: effect,
                sampleCount: journalValues.count,
                journalValues: journalValues
            )

            results.append(JournalCorrelation(
                category: pair.category,
                healthMetric: pair.metric,
                correlation: r,
                insight: insight,
                sampleCount: journalValues.count,
                avgOutcomeHigh: effect.avgHigh,
                avgOutcomeLow: effect.avgLow,
                effectPercent: effect.percentDiff
            ))
        }

        // Sort by absolute correlation strength, deduplicate by keeping strongest per category
        let sorted = results.sorted { abs($0.correlation) > abs($1.correlation) }
        return deduplicateByCategory(sorted)
    }

    // MARK: - Pearson Correlation

    private static func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        let n = Double(x.count)
        guard n > 2 else { return 0 }

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = x.reduce(0) { $0 + $1 * $1 }
        let sumY2 = y.reduce(0) { $0 + $1 * $1 }

        let numerator = n * sumXY - sumX * sumY
        let denominator = ((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY)).squareRoot()

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    // MARK: - Conditional Effect

    private struct MedianSplitEffect {
        let avgHigh: Double
        let avgLow: Double
        let percentDiff: Double
    }

    /// Split journal values at the median and compare average health outcomes
    private static func computeMedianSplitEffect(
        journalValues: [Double],
        healthValues: [Double],
        metric: HealthMetric
    ) -> MedianSplitEffect {
        let sorted = journalValues.sorted()
        let median = sorted[sorted.count / 2]

        var highSum = 0.0, lowSum = 0.0
        var highCount = 0, lowCount = 0

        for (i, journalVal) in journalValues.enumerated() {
            if journalVal >= median {
                highSum += healthValues[i]
                highCount += 1
            } else {
                lowSum += healthValues[i]
                lowCount += 1
            }
        }

        guard highCount > 0, lowCount > 0 else {
            return MedianSplitEffect(avgHigh: 0, avgLow: 0, percentDiff: 0)
        }

        let avgHigh = highSum / Double(highCount)
        let avgLow = lowSum / Double(lowCount)

        guard avgLow != 0 else {
            return MedianSplitEffect(avgHigh: avgHigh, avgLow: 0, percentDiff: 0)
        }

        let percentDiff = ((avgHigh - avgLow) / abs(avgLow)) * 100

        return MedianSplitEffect(
            avgHigh: avgHigh,
            avgLow: avgLow,
            percentDiff: percentDiff
        )
    }

    // MARK: - Insight Generation

    private static func generateInsight(
        pair: OutcomePair,
        r: Double,
        effect: MedianSplitEffect,
        sampleCount: Int,
        journalValues: [Double]
    ) -> String {
        _ = pair.category.displayName.lowercased()
        let metricName = pair.metric.displayName.lowercased()
        let absDiff = String(format: "%.0f", abs(effect.percentDiff))
        let direction = effect.percentDiff > 0 ? "higher" : "lower"
        let sorted = journalValues.sorted()
        let median = sorted[sorted.count / 2]

        switch pair.category {
        case .caffeine:
            let cups = String(format: "%.0f", median)
            if pair.metric == .sleepDeep || pair.metric == .sleepDuration {
                return Copy.Journal.Correlation.caffeineSleep(cups: cups, metric: metricName, percent: absDiff, days: sampleCount)
            }
            return Copy.Journal.Correlation.caffeineGeneric(cups: cups, percent: absDiff, direction: direction, metric: metricName)

        case .alcohol:
            let drinks = String(format: "%.0f", median)
            if pair.metric == .sleepDeep || pair.metric == .sleepREM {
                return Copy.Journal.Correlation.alcoholSleep(drinks: drinks, metric: metricName, percent: absDiff)
            }
            return Copy.Journal.Correlation.alcoholGeneric(drinks: drinks, metric: metricName, percent: absDiff)

        case .stress:
            return Copy.Journal.Correlation.stressImpact(level: String(format: "%.0f", median), metric: metricName, percent: absDiff, direction: direction)

        case .meditation:
            return Copy.Journal.Correlation.meditationImpact(mins: String(format: "%.0f", median), metric: metricName, percent: absDiff)

        case .screenTime:
            return Copy.Journal.Correlation.screenTimeImpact(hrs: String(format: "%.1f", median), percent: absDiff, direction: direction, metric: metricName)

        case .mealTiming:
            return Copy.Journal.Correlation.mealTimingImpact(hrs: String(format: "%.1f", median), metric: metricName, percent: absDiff)

        case .water:
            return Copy.Journal.Correlation.waterImpact(glasses: String(format: "%.0f", median), percent: absDiff, direction: direction, metric: metricName)

        case .mood:
            return Copy.Journal.Correlation.moodImpact(rating: String(format: "%.0f", median), metric: metricName, percent: absDiff, direction: direction)

        case .supplements:
            return Copy.Journal.Correlation.supplementsImpact(percent: absDiff, direction: direction, metric: metricName, observations: sampleCount)
        }
    }

    // MARK: - Helpers

    private static func buildDateLookup(samples: [MetricSample], calendar: Calendar) -> [Date: Double] {
        var lookup: [Date: Double] = [:]
        for sample in samples {
            lookup[calendar.startOfDay(for: sample.date)] = sample.value
        }
        return lookup
    }

    /// Keep only the strongest correlation per journal category to avoid redundancy
    private static func deduplicateByCategory(_ correlations: [JournalCorrelation]) -> [JournalCorrelation] {
        var seen: Set<String> = []
        var result: [JournalCorrelation] = []

        for corr in correlations {
            let key = corr.category.rawValue
            if !seen.contains(key) {
                seen.insert(key)
                result.append(corr)
            }
        }

        return result
    }
}
