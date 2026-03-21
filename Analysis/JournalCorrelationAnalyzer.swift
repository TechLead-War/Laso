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
            if absR >= 0.6 { return "Strong" }
            if absR >= 0.4 { return "Moderate" }
            return "Mild"
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

    /// Minimum number of paired data points required to compute a correlation
    static let minimumDataPoints = 14

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
        let calendar = Calendar.current
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

            // Compute Pearson correlation
            let r = pearsonCorrelation(x: journalValues, y: healthValues)
            guard abs(r) >= 0.15 else { continue }

            // Compute conditional effect: above-median vs below-median behavior
            let effect = computeMedianSplitEffect(
                journalValues: journalValues,
                healthValues: healthValues,
                metric: pair.metric
            )
            guard abs(effect.percentDiff) >= 5.0 else { continue }

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

        // Generate category-specific personalized insights
        switch pair.category {
        case .caffeine:
            let cups = String(format: "%.0f", median)
            if pair.metric == .sleepDeep || pair.metric == .sleepDuration {
                return "When you have \(cups)+ cups of coffee, your \(metricName) drops \(absDiff)%. Based on \(sampleCount) days of your data."
            }
            return "Days with \(cups)+ cups of caffeine show \(absDiff)% \(direction) \(metricName) the next day."

        case .alcohol:
            let drinks = String(format: "%.0f", median)
            if pair.metric == .sleepDeep || pair.metric == .sleepREM {
                return "Nights with \(drinks)+ drinks reduce your \(metricName) by \(absDiff)%. Your body needs alcohol-free evenings for quality sleep."
            }
            return "\(drinks)+ drinks impact your next-day \(metricName) by \(absDiff)%."

        case .stress:
            let level = String(format: "%.0f", median)
            return "When your stress is \(level)+ out of 10, your \(metricName) is \(absDiff)% \(direction). Stress management directly impacts your recovery."

        case .meditation:
            let mins = String(format: "%.0f", median)
            return "\(mins)+ minutes of meditation boosts your \(metricName) by \(absDiff)%. Consistency matters more than duration."

        case .screenTime:
            let hrs = String(format: "%.1f", median)
            return "Days with \(hrs)+ hrs of screen time show \(absDiff)% \(direction) \(metricName). Consider a screen curfew before bed."

        case .mealTiming:
            let hrs = String(format: "%.1f", median)
            return "Eating \(hrs)+ hrs before bed improves your \(metricName) by \(absDiff)%. Earlier dinners support better sleep."

        case .water:
            let glasses = String(format: "%.0f", median)
            return "Drinking \(glasses)+ glasses of water leads to \(absDiff)% \(direction) \(metricName) the next day."

        case .mood:
            let rating = String(format: "%.0f", median)
            return "On days when your mood is \(rating)+, your \(metricName) averages \(absDiff)% \(direction)."

        case .supplements:
            return "Days with supplements show \(absDiff)% \(direction) next-day \(metricName). Based on \(sampleCount) observations."
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
