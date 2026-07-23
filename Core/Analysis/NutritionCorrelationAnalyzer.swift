import Foundation

/// Time-aware correlation engine for nutrition → health outcome pairs.
/// Tests ~16 curated physiologically plausible pairs (not blind N² search).
struct NutritionCorrelationAnalyzer {

    // MARK: - Types

    struct NutritionCorrelation: Identifiable {
        let id = UUID()
        let nutritionMetric: HealthMetric
        let outcomeMetric: HealthMetric
        let correlation: Double          // Pearson r
        let timingEffect: TimingEffect?  // For timing-sensitive pairs
        let thresholdValue: Double?      // Threshold where impact becomes pronounced
        let actionableInsight: String
        let sampleCount: Int
    }

    struct TimingEffect {
        let cutoffHour: Int              // e.g., 14 for 2pm
        let beforeCutoffCorrelation: Double
        let afterCutoffCorrelation: Double
        let isTimingSensitive: Bool
    }

    // MARK: - Curated Pairs

    private struct CuratedPair {
        let nutrition: HealthMetric
        let outcome: HealthMetric
        let dayOffset: Int                // 0 = same day, 1 = next day
        let timingSensitive: Bool
        let cutoffHour: Int?              // For timing-sensitive pairs
    }

    private static let curatedPairs: [CuratedPair] = [
        // Caffeine → sleep (timing-sensitive, cutoff 2pm)
        CuratedPair(nutrition: .caffeineIntake, outcome: .sleepDuration, dayOffset: 0, timingSensitive: true, cutoffHour: 14),
        CuratedPair(nutrition: .caffeineIntake, outcome: .sleepDeep, dayOffset: 0, timingSensitive: true, cutoffHour: 14),
        CuratedPair(nutrition: .caffeineIntake, outcome: .sleepREM, dayOffset: 0, timingSensitive: true, cutoffHour: 14),
        CuratedPair(nutrition: .caffeineIntake, outcome: .restingHeartRate, dayOffset: 0, timingSensitive: false, cutoffHour: nil),
        CuratedPair(nutrition: .caffeineIntake, outcome: .heartRateVariability, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Hydration → outcomes
        CuratedPair(nutrition: .waterIntake, outcome: .heartRateVariability, dayOffset: 1, timingSensitive: false, cutoffHour: nil),
        CuratedPair(nutrition: .waterIntake, outcome: .restingHeartRate, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Protein → recovery
        CuratedPair(nutrition: .proteinIntake, outcome: .heartRateVariability, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Sugar → sleep (timing-sensitive, cutoff 6pm)
        CuratedPair(nutrition: .sugarIntake, outcome: .sleepDeep, dayOffset: 0, timingSensitive: true, cutoffHour: 18),
        CuratedPair(nutrition: .sugarIntake, outcome: .heartRateVariability, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Sodium → BP
        CuratedPair(nutrition: .sodiumIntake, outcome: .bloodPressureSystolic, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Fiber → glucose stability
        CuratedPair(nutrition: .fiberIntake, outcome: .bloodGlucose, dayOffset: 0, timingSensitive: false, cutoffHour: nil),

        // Total calories → activity
        CuratedPair(nutrition: .totalCaloriesIntake, outcome: .activeCalories, dayOffset: 1, timingSensitive: false, cutoffHour: nil),

        // Fat → sleep
        CuratedPair(nutrition: .fatIntake, outcome: .sleepDeep, dayOffset: 0, timingSensitive: false, cutoffHour: nil),

        // Carbs → activity
        CuratedPair(nutrition: .carbohydrateIntake, outcome: .exerciseMinutes, dayOffset: 1, timingSensitive: false, cutoffHour: nil),
    ]

    // MARK: - Analysis

    /// Analyze curated nutrition-outcome pairs using available time series data.
    static func analyze(timeSeries: [HealthMetric: MetricTimeSeries]) -> [NutritionCorrelation] {
        var results: [NutritionCorrelation] = []
        let calendar = Date.cal

        for pair in curatedPairs {
            guard let nutritionSeries = timeSeries[pair.nutrition],
                  let outcomeSeries = timeSeries[pair.outcome],
                  nutritionSeries.samples.count >= 14,
                  outcomeSeries.samples.count >= 14 else { continue }

            // Build date-indexed lookup
            let nutritionByDate = buildDateLookup(samples: nutritionSeries.sortedSamples)
            let outcomeByDate = buildDateLookup(samples: outcomeSeries.sortedSamples)

            // Collect paired observations (with day offset)
            var nutritionValues: [Double] = []
            var outcomeValues: [Double] = []

            for (date, nutritionValue) in nutritionByDate {
                let outcomeDate: Date
                if pair.dayOffset > 0 {
                    outcomeDate = calendar.date(byAdding: .day, value: pair.dayOffset, to: date) ?? date
                } else {
                    outcomeDate = date
                }

                if let outcomeValue = outcomeByDate[outcomeDate] {
                    nutritionValues.append(nutritionValue)
                    outcomeValues.append(outcomeValue)
                }
            }

            // Require >= 30 paired observations before claiming a nutrition–outcome
            // link. Below this, Pearson correlation is too noisy to ship as an
            // "X affects Y" insight to the user.
            guard nutritionValues.count >= 30 else { continue }

            // Compute Pearson correlation
            let r = pearsonCorrelation(x: nutritionValues, y: outcomeValues)
            guard abs(r) >= 0.15 else { continue }  // Skip weak correlations

            // Threshold detection: find where impact becomes pronounced
            let threshold = detectThreshold(nutritionValues: nutritionValues, outcomeValues: outcomeValues)

            // Generate actionable insight
            let insight = generateInsightText(
                pair: pair,
                correlation: r,
                threshold: threshold,
                sampleCount: nutritionValues.count
            )

            results.append(NutritionCorrelation(
                nutritionMetric: pair.nutrition,
                outcomeMetric: pair.outcome,
                correlation: r,
                timingEffect: nil,  // Simplified: full timing analysis needs sub-daily data
                thresholdValue: threshold?.value,
                actionableInsight: insight,
                sampleCount: nutritionValues.count
            ))
        }

        return results.sorted { abs($0.correlation) > abs($1.correlation) }
    }

    /// Generate insights from discovered correlations
    static func generateInsights(from correlations: [NutritionCorrelation]) -> [Insight] {
        correlations.prefix(5).map { corr in
            Insight(
                metric: corr.nutritionMetric,
                title: Copy.Analysis.NutritionCorrelation.affects(nutrition: corr.nutritionMetric.displayName, outcome: corr.outcomeMetric.displayName),
                summary: corr.actionableInsight,
                recommendation: Copy.Analysis.NutritionCorrelation.monitorToOptimize(nutrition: corr.nutritionMetric.displayName, outcome: corr.outcomeMetric.displayName),
                severity: abs(corr.correlation) > 0.4 ? .warning : .info,
                trend: .stable,
                currentValue: corr.correlation,
                baselineValue: 0,
                deviationPercent: abs(corr.correlation) * 100,
                category: .nutritionCorrelation,
                relatedMetrics: [corr.outcomeMetric],
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(corr.sampleCount) / 60.0),
                    dataPointCount: corr.sampleCount
                )
            )
        }
    }

    // MARK: - Helpers

    private static func buildDateLookup(samples: [MetricSample]) -> [Date: Double] {
        let calendar = Date.cal
        var lookup: [Date: Double] = [:]
        for sample in samples {
            lookup[calendar.startOfDay(for: sample.date)] = sample.value
        }
        return lookup
    }

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

    /// Find the threshold level where impact becomes pronounced using quartile analysis
    private static func detectThreshold(
        nutritionValues: [Double],
        outcomeValues: [Double]
    ) -> (value: Double, impactPercent: Double)? {
        let sorted = zip(nutritionValues, outcomeValues).sorted { $0.0 < $1.0 }
        let n = sorted.count
        guard n >= 20 else { return nil }

        // Split into quartiles
        let q3Start = n * 3 / 4
        let bottomHalfOutcome = sorted.prefix(n / 2).map(\.1)
        let topQuartileOutcome = sorted.suffix(from: q3Start).map(\.1)

        guard !bottomHalfOutcome.isEmpty, !topQuartileOutcome.isEmpty else { return nil }

        let bottomAvg = bottomHalfOutcome.reduce(0, +) / Double(bottomHalfOutcome.count)
        let topAvg = topQuartileOutcome.reduce(0, +) / Double(topQuartileOutcome.count)

        guard bottomAvg != 0 else { return nil }
        let impact = ((topAvg - bottomAvg) / abs(bottomAvg)) * 100

        guard abs(impact) >= 5 else { return nil }

        // Threshold is the value at the start of Q3
        let thresholdValue = sorted[q3Start].0

        return (value: thresholdValue, impactPercent: impact)
    }

    private static func generateInsightText(
        pair: CuratedPair,
        correlation: Double,
        threshold: (value: Double, impactPercent: Double)?,
        sampleCount: Int
    ) -> String {
        let direction = correlation > 0 ? "increases" : "decreases"
        let strength = abs(correlation) > 0.5 ? "strongly" : abs(correlation) > 0.3 ? "moderately" : "slightly"

        var text = "Your \(pair.nutrition.displayName) \(strength) \(direction) \(pair.outcome.displayName)"
        if pair.dayOffset > 0 {
            text += " the next day"
        }
        text += " (r=\(String(format: "%.2f", correlation)), n=\(sampleCount))."

        if let threshold {
            let formatted = pair.nutrition.formatValue(threshold.value)
            text += " Impact becomes more pronounced above \(formatted) \(pair.nutrition.unit) (\(String(format: "%.0f", abs(threshold.impactPercent)))% change)."
        }

        return text
    }
}

// MARK: - InsightAnalyzer Conformance

extension NutritionCorrelationAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "nutritionCorrelation" }
    static var insightCategory: InsightCategory { .nutritionCorrelation }

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        let correlations = analyze(timeSeries: context.timeSeries)
        return generateInsights(from: correlations)
    }
}
