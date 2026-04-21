import SwiftUI

/// Generates personalized health discoveries for the Day 0 first-launch experience.
/// Stateless struct following the existing analyzer pattern.
struct DiscoveryEngine {

    static let minimumDaysRequired = 30
    static let minimumDiscoveriesRequired = 3
    static let maxDiscoveries = 5

    /// Generate up to 5 high-quality discoveries from the user's health data.
    static func generateDiscoveries(
        timeSeries: [HealthMetric: MetricTimeSeries],
        correlations: [HealthCorrelation],
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext]
    ) -> [Discovery] {
        // Require minimum data depth
        var maxDays = 0
        for series in timeSeries.values where series.daysOfData > maxDays {
            maxDays = series.daysOfData
        }
        guard maxDays >= minimumDaysRequired else { return [] }

        var all: [Discovery] = []

        all.append(contentsOf: conditionalImpactDiscoveries(timeSeries: timeSeries))
        all.append(contentsOf: thresholdEffectDiscoveries(timeSeries: timeSeries, existing: all))
        all.append(contentsOf: dayOfWeekDiscoveries(timeSeries: timeSeries))
        all.append(contentsOf: longTermTrendDiscoveries(historicalContext: historicalContext))
        all.append(contentsOf: personalExtremeDiscoveries(historicalContext: historicalContext))
        all.append(contentsOf: compoundPatternDiscoveries(timeSeries: timeSeries))

        all.sort { $0.impactScore > $1.impactScore }
        return Array(all.prefix(maxDiscoveries))
    }

    // MARK: - A. Conditional Impact

    private struct ConditionalPair {
        let cause: HealthMetric
        let effect: HealthMetric
        let threshold: Double
        let thresholdLabel: String
        let dayOffset: Int
        let minEffect: Double // minimum meaningful difference in real units
    }

    private static let conditionalPairs: [ConditionalPair] = [
        // Sleep → next day outcomes
        ConditionalPair(cause: .sleepDuration, effect: .restingHeartRate, threshold: 7, thresholdLabel: "you sleep 7+ hours", dayOffset: 1, minEffect: 2),
        ConditionalPair(cause: .sleepDuration, effect: .heartRateVariability, threshold: 7, thresholdLabel: "you sleep 7+ hours", dayOffset: 1, minEffect: 3),
        ConditionalPair(cause: .sleepDuration, effect: .steps, threshold: 7, thresholdLabel: "you sleep 7+ hours", dayOffset: 1, minEffect: 500),
        ConditionalPair(cause: .sleepDuration, effect: .activeCalories, threshold: 7, thresholdLabel: "you sleep 7+ hours", dayOffset: 1, minEffect: 50),
        ConditionalPair(cause: .sleepDuration, effect: .restingHeartRate, threshold: 8, thresholdLabel: "you sleep 8+ hours", dayOffset: 1, minEffect: 2),
        ConditionalPair(cause: .sleepDuration, effect: .heartRateVariability, threshold: 8, thresholdLabel: "you sleep 8+ hours", dayOffset: 1, minEffect: 3),

        // Exercise → same day and next day
        ConditionalPair(cause: .exerciseMinutes, effect: .heartRateVariability, threshold: 30, thresholdLabel: "you exercise 30+ minutes", dayOffset: 0, minEffect: 3),
        ConditionalPair(cause: .exerciseMinutes, effect: .restingHeartRate, threshold: 30, thresholdLabel: "you exercise 30+ minutes", dayOffset: 1, minEffect: 2),
        ConditionalPair(cause: .exerciseMinutes, effect: .sleepDuration, threshold: 30, thresholdLabel: "you exercise 30+ minutes", dayOffset: 0, minEffect: 0.3),
        ConditionalPair(cause: .exerciseMinutes, effect: .heartRateVariability, threshold: 30, thresholdLabel: "you exercise 30+ minutes", dayOffset: 1, minEffect: 3),

        // Steps → same day
        ConditionalPair(cause: .steps, effect: .sleepDuration, threshold: 10000, thresholdLabel: "you walk 10K+ steps", dayOffset: 0, minEffect: 0.3),
        ConditionalPair(cause: .steps, effect: .restingHeartRate, threshold: 10000, thresholdLabel: "you walk 10K+ steps", dayOffset: 0, minEffect: 2),

        // Mindfulness → same day
        ConditionalPair(cause: .mindfulMinutes, effect: .heartRateVariability, threshold: 10, thresholdLabel: "you meditate 10+ minutes", dayOffset: 0, minEffect: 3),
        ConditionalPair(cause: .mindfulMinutes, effect: .restingHeartRate, threshold: 10, thresholdLabel: "you meditate 10+ minutes", dayOffset: 0, minEffect: 2),

        // Deep sleep → next day
        ConditionalPair(cause: .sleepDeep, effect: .heartRateVariability, threshold: 1, thresholdLabel: "you get 1+ hour of deep sleep", dayOffset: 1, minEffect: 3),
        ConditionalPair(cause: .sleepDeep, effect: .restingHeartRate, threshold: 1, thresholdLabel: "you get 1+ hour of deep sleep", dayOffset: 1, minEffect: 2),

        // Steps → next day
        ConditionalPair(cause: .steps, effect: .heartRateVariability, threshold: 10000, thresholdLabel: "you walk 10K+ steps", dayOffset: 1, minEffect: 3),

        // Exercise → active calories same day
        ConditionalPair(cause: .exerciseMinutes, effect: .activeCalories, threshold: 30, thresholdLabel: "you exercise 30+ minutes", dayOffset: 0, minEffect: 100),

        // Sleep → exercise next day
        ConditionalPair(cause: .sleepDuration, effect: .exerciseMinutes, threshold: 7, thresholdLabel: "you sleep 7+ hours", dayOffset: 1, minEffect: 5),
        ConditionalPair(cause: .sleepDuration, effect: .exerciseMinutes, threshold: 8, thresholdLabel: "you sleep 8+ hours", dayOffset: 1, minEffect: 5),
    ]

    private static func conditionalImpactDiscoveries(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Discovery] {
        var discoveries: [Discovery] = []

        for pair in conditionalPairs {
            guard let causeSeries = timeSeries[pair.cause],
                  let effectSeries = timeSeries[pair.effect] else { continue }

            let aligned: [TimeSeriesAligner.AlignedPair]
            if pair.dayOffset == 0 {
                aligned = TimeSeriesAligner.alignByDate(causeSeries, effectSeries)
            } else {
                aligned = TimeSeriesAligner.alignWithOffset(causeSeries, effectSeries, dayOffset: pair.dayOffset)
            }

            var aboveSum = 0.0
            var belowSum = 0.0
            var aboveCount = 0
            var belowCount = 0
            for pairData in aligned {
                if pairData.valueA >= pair.threshold {
                    aboveSum += pairData.valueB
                    aboveCount += 1
                } else {
                    belowSum += pairData.valueB
                    belowCount += 1
                }
            }

            guard aboveCount >= 10, belowCount >= 10 else { continue }

            let aboveMean = aboveSum / Double(aboveCount)
            let belowMean = belowSum / Double(belowCount)
            let diff = aboveMean - belowMean
            let absDiff = abs(diff)

            guard absDiff >= pair.minEffect else { continue }

            let percentDiff = belowMean != 0 ? abs(diff / belowMean) * 100 : 0
            let totalPairs = aboveCount + belowCount
            let impactScore = min(percentDiff * log2(Double(totalPairs)), 100)

            let effectUnit = pair.effect.unit
            let formattedDiff = pair.effect.formatValue(absDiff)
            let direction = directionWord(for: pair.effect, diff: diff)

            let headline = "Your \(pair.effect.displayName.lowercased()) \(direction) \(formattedDiff)\(effectUnit) when \(pair.thresholdLabel)"
            let detail = detailText(effect: pair.effect, aboveMean: aboveMean, belowMean: belowMean, diff: diff)
            let months = max(1, totalPairs / 30)
            let evidence = "Based on \(totalPairs) days over \(months) month\(months == 1 ? "" : "s")"

            discoveries.append(Discovery(
                headline: headline,
                detail: detail,
                evidence: evidence,
                metrics: [pair.cause, pair.effect],
                type: .conditionalImpact,
                impactScore: impactScore,
                icon: pair.effect.systemImageName,
                accentColor: pair.effect.category.color
            ))
        }

        return discoveries
    }

    // MARK: - B. Threshold Effects

    private struct ThresholdLadder {
        let metric: HealthMetric
        let thresholds: [Double]
        let effect: HealthMetric
        let dayOffset: Int
        let minEffect: Double
    }

    private static let thresholdLadders: [ThresholdLadder] = [
        ThresholdLadder(metric: .sleepDuration, thresholds: [6, 7, 8, 9], effect: .restingHeartRate, dayOffset: 1, minEffect: 2),
        ThresholdLadder(metric: .sleepDuration, thresholds: [6, 7, 8, 9], effect: .heartRateVariability, dayOffset: 1, minEffect: 3),
        ThresholdLadder(metric: .exerciseMinutes, thresholds: [15, 30, 45], effect: .heartRateVariability, dayOffset: 0, minEffect: 3),
        ThresholdLadder(metric: .exerciseMinutes, thresholds: [15, 30, 45], effect: .restingHeartRate, dayOffset: 1, minEffect: 2),
        ThresholdLadder(metric: .steps, thresholds: [5000, 8000, 10000, 12000], effect: .sleepDuration, dayOffset: 0, minEffect: 0.3),
        ThresholdLadder(metric: .steps, thresholds: [5000, 8000, 10000, 12000], effect: .restingHeartRate, dayOffset: 0, minEffect: 2),
    ]

    private static func thresholdEffectDiscoveries(
        timeSeries: [HealthMetric: MetricTimeSeries],
        existing: [Discovery]
    ) -> [Discovery] {
        // Build a set of (cause, effect) pairs already found in conditional impact
        let existingPairs = Set(existing.compactMap { d -> String? in
            guard d.metrics.count >= 2 else { return nil }
            return "\(d.metrics[0].rawValue)-\(d.metrics[1].rawValue)"
        })

        var discoveries: [Discovery] = []

        for ladder in thresholdLadders {
            guard let causeSeries = timeSeries[ladder.metric],
                  let effectSeries = timeSeries[ladder.effect] else { continue }

            // Skip if conditional impact already found this pair with a higher score
            let pairKey = "\(ladder.metric.rawValue)-\(ladder.effect.rawValue)"
            if existingPairs.contains(pairKey) { continue }

            let aligned: [TimeSeriesAligner.AlignedPair]
            if ladder.dayOffset == 0 {
                aligned = TimeSeriesAligner.alignByDate(causeSeries, effectSeries)
            } else {
                aligned = TimeSeriesAligner.alignWithOffset(causeSeries, effectSeries, dayOffset: ladder.dayOffset)
            }

            guard aligned.count >= 20 else { continue }
            let alignedEffectMean = aligned.mean(of: \.valueB)

            // Find the threshold boundary with the biggest jump
            var bestBoundary: (threshold: Double, diff: Double, aboveCount: Int, belowCount: Int)?

            for i in 0..<(ladder.thresholds.count - 1) {
                let lower = ladder.thresholds[i]
                let upper = ladder.thresholds[i + 1]

                var belowSum = 0.0
                var aboveSum = 0.0
                var belowCount = 0
                var aboveCount = 0

                for pairData in aligned {
                    if pairData.valueA >= upper {
                        aboveSum += pairData.valueB
                        aboveCount += 1
                    } else if pairData.valueA >= lower {
                        belowSum += pairData.valueB
                        belowCount += 1
                    }
                }

                guard belowCount >= 8, aboveCount >= 8 else { continue }

                let belowMean = belowSum / Double(belowCount)
                let aboveMean = aboveSum / Double(aboveCount)
                let diff = abs(aboveMean - belowMean)

                if diff >= ladder.minEffect {
                    if bestBoundary == nil || diff > abs(bestBoundary!.diff) {
                        bestBoundary = (upper, aboveMean - belowMean, aboveCount, belowCount)
                    }
                }
            }

            guard let best = bestBoundary else { continue }

            let totalDays = best.aboveCount + best.belowCount
            let percentDiff = abs(best.diff) / max(1, abs(alignedEffectMean)) * 100
            let impactScore = min(percentDiff * log2(Double(totalDays)) * 0.8, 100) // Slightly lower priority than conditional

            let causeFormatted = ladder.metric.formatValue(best.threshold)
            let diffFormatted = ladder.effect.formatValue(abs(best.diff))
            let direction = directionWord(for: ladder.effect, diff: best.diff)

            let headline = "The magic number is \(causeFormatted) \(ladder.metric.unit). Your \(ladder.effect.displayName.lowercased()) \(direction) \(diffFormatted)\(ladder.effect.unit) past that point"
            let months = max(1, totalDays / 30)
            let evidence = "Based on \(totalDays) days over \(months) month\(months == 1 ? "" : "s")"

            discoveries.append(Discovery(
                headline: headline,
                detail: "Below \(causeFormatted) \(ladder.metric.unit), your \(ladder.effect.displayName.lowercased()) stays flat. Above it, there's a clear jump.",
                evidence: evidence,
                metrics: [ladder.metric, ladder.effect],
                type: .thresholdEffect,
                impactScore: impactScore,
                icon: "arrow.up.right.circle.fill",
                accentColor: ladder.effect.category.color
            ))
        }

        return discoveries
    }

    // MARK: - C. Day-of-Week Patterns

    private static let dayOfWeekMetrics: [HealthMetric] = [
        .steps, .activeCalories, .exerciseMinutes, .sleepDuration, .restingHeartRate, .heartRateVariability
    ]

    private static func dayOfWeekDiscoveries(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Discovery] {
        var discoveries: [Discovery] = []
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        for metric in dayOfWeekMetrics {
            guard let series = timeSeries[metric] else { continue }

            let grouped = TimeSeriesAligner.groupByDayOfWeek(series)

            // Require at least 4 samples per day
            let validDays = grouped.filter { $0.value.count >= 4 }
            guard validDays.count == 7 else { continue }

            let dayAverages = validDays.mapValues { $0.mean }
            guard let bestDay = dayAverages.max(by: { $0.value < $1.value }),
                  let worstDay = dayAverages.min(by: { $0.value < $1.value }) else { continue }

            let diff = bestDay.value - worstDay.value
            let percentDiff = worstDay.value != 0 ? abs(diff / worstDay.value) * 100 : 0

            guard percentDiff > 15 else { continue }

            let totalSamples = grouped.values.reduce(0) { partial, values in
                partial + values.count
            }
            let impactScore = min(percentDiff * 0.6, 100)

            let formattedDiff = metric.formatValue(abs(diff))
            let bestDayName = dayNames[bestDay.key]
            let worstDayName = dayNames[worstDay.key]

            let isHigherBetter = metric.higherIsBetter
            let topDayName = isHigherBetter ? bestDayName : worstDayName
            let botDayName = isHigherBetter ? worstDayName : bestDayName
            let label = isHigherBetter ? "most" : "best"

            let headline = "\(topDayName) is your \(label) \(metric.displayName.lowercased()) day. \(formattedDiff) \(metric.unit) \(isHigherBetter ? "more" : "lower") than \(botDayName)"
            let months = max(1, totalSamples / 30)
            let evidence = "Based on \(totalSamples) data points over \(months) month\(months == 1 ? "" : "s")"

            discoveries.append(Discovery(
                headline: headline,
                detail: "Your weekly pattern is consistent. \(topDayName)s tend to be your strongest day for \(metric.displayName.lowercased()).",
                evidence: evidence,
                metrics: [metric],
                type: .dayOfWeekPattern,
                impactScore: impactScore,
                icon: "calendar",
                accentColor: metric.category.color
            ))
        }

        return discoveries
    }

    // MARK: - D. Hidden Long-Term Trends

    private static func longTermTrendDiscoveries(
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext]
    ) -> [Discovery] {
        var discoveries: [Discovery] = []

        for (metric, context) in historicalContext {
            guard context.totalDataPoints >= 90 else { continue }
            guard let changePercent = context.longTermChangePercent,
                  abs(changePercent) >= 8 else { continue }

            let improving = metric.higherIsBetter ? changePercent > 0 : changePercent < 0
            let direction = improving ? "improved" : "shifted"
            let periodLabel = "past year"

            // Compute absolute change if we have slope
            var absoluteDetail = ""
            if let slope = context.longTermSlope {
                let totalDays = Double(context.totalDataPoints)
                let absChange = abs(slope * totalDays)
                let formatted = metric.formatValue(absChange)
                absoluteDetail = ". That is \(formatted) \(metric.unit) total"
            }

            let headline = "Your \(metric.displayName.lowercased()) has quietly \(direction) \(String(format: "%.0f", abs(changePercent)))% over the \(periodLabel)"
            let impactScore = min(abs(changePercent) * 1.2, 100)
            let evidence = "Based on \(context.totalDataPoints) data points over \(periodLabel)"

            discoveries.append(Discovery(
                headline: headline,
                detail: "This is a gradual shift you might not notice day to day\(absoluteDetail).",
                evidence: evidence,
                metrics: [metric],
                type: .longTermTrend,
                impactScore: impactScore,
                icon: "chart.line.uptrend.xyaxis",
                accentColor: metric.category.color
            ))
        }

        return discoveries
    }

    // MARK: - E. Personal Extremes

    private static func personalExtremeDiscoveries(
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext]
    ) -> [Discovery] {
        var discoveries: [Discovery] = []

        for (metric, context) in historicalContext {
            guard context.totalDataPoints >= 90 else { continue }
            let percentile = context.allTimePercentile

            guard percentile <= 5 || percentile >= 95 else { continue }

            let isHigh = percentile >= 95
            let isGood = isHigh == metric.higherIsBetter
            let bracket = isHigh ? "top 5%" : "bottom 5%"

            let headline = "Your \(metric.displayName.lowercased()) this month is in your \(bracket) of all time"
            let impactScore = min(abs(percentile - 50) * 1.5, 100)
            let periodLabel = "the past year"
            let evidence = "Based on \(context.totalDataPoints) data points across \(periodLabel)"

            discoveries.append(Discovery(
                headline: headline,
                detail: isGood
                    ? "This is an exceptional period for your \(metric.displayName.lowercased()). Keep doing what you're doing."
                    : "Your \(metric.displayName.lowercased()) is at an unusual level. Worth paying attention to.",
                evidence: evidence,
                metrics: [metric],
                type: .personalExtreme,
                impactScore: impactScore,
                icon: isGood ? "trophy.fill" : "exclamationmark.triangle.fill",
                accentColor: metric.category.color
            ))
        }

        return discoveries
    }

    // MARK: - F. Compound Patterns

    private struct CompoundCondition {
        let conditionA: (metric: HealthMetric, threshold: Double, label: String)
        let conditionB: (metric: HealthMetric, threshold: Double, label: String)
        let outcome: HealthMetric
        let minEffect: Double
    }

    private static let compoundConditions: [CompoundCondition] = [
        CompoundCondition(
            conditionA: (.exerciseMinutes, 30, "exercise 30+ min"),
            conditionB: (.sleepDuration, 7, "sleep 7+ hours"),
            outcome: .heartRateVariability, minEffect: 3
        ),
        CompoundCondition(
            conditionA: (.exerciseMinutes, 30, "exercise 30+ min"),
            conditionB: (.sleepDuration, 7, "sleep 7+ hours"),
            outcome: .restingHeartRate, minEffect: 2
        ),
        CompoundCondition(
            conditionA: (.steps, 10000, "walk 10K+ steps"),
            conditionB: (.sleepDuration, 7, "sleep 7+ hours"),
            outcome: .heartRateVariability, minEffect: 3
        ),
        CompoundCondition(
            conditionA: (.mindfulMinutes, 10, "meditate 10+ min"),
            conditionB: (.sleepDuration, 7, "sleep 7+ hours"),
            outcome: .restingHeartRate, minEffect: 2
        ),
        CompoundCondition(
            conditionA: (.exerciseMinutes, 30, "exercise 30+ min"),
            conditionB: (.sleepDeep, 1, "get 1+ hour deep sleep"),
            outcome: .heartRateVariability, minEffect: 3
        ),
        CompoundCondition(
            conditionA: (.steps, 8000, "walk 8K+ steps"),
            conditionB: (.exerciseMinutes, 30, "exercise 30+ min"),
            outcome: .sleepDuration, minEffect: 0.3
        ),
    ]

    private static func compoundPatternDiscoveries(timeSeries: [HealthMetric: MetricTimeSeries]) -> [Discovery] {
        var discoveries: [Discovery] = []

        for compound in compoundConditions {
            guard let seriesA = timeSeries[compound.conditionA.metric],
                  let seriesB = timeSeries[compound.conditionB.metric],
                  let outcomeSeries = timeSeries[compound.outcome] else { continue }

            let mapA = TimeSeriesAligner.dailyValueMap(seriesA)
            let mapB = TimeSeriesAligner.dailyValueMap(seriesB)
            let mapOut = TimeSeriesAligner.dailyValueMap(outcomeSeries)

            var bothSum = 0.0
            var neitherSum = 0.0
            var bothCount = 0
            var neitherCount = 0

            for (date, outcomeVal) in mapOut {
                guard let valA = mapA[date], let valB = mapB[date] else { continue }
                let aMet = valA >= compound.conditionA.threshold
                let bMet = valB >= compound.conditionB.threshold

                if aMet && bMet {
                    bothSum += outcomeVal
                    bothCount += 1
                } else if !aMet && !bMet {
                    neitherSum += outcomeVal
                    neitherCount += 1
                }
            }

            guard bothCount >= 10, neitherCount >= 10 else { continue }

            let bothMean = bothSum / Double(bothCount)
            let neitherMean = neitherSum / Double(neitherCount)
            let diff = bothMean - neitherMean
            let absDiff = abs(diff)

            guard absDiff >= compound.minEffect else { continue }

            let percentDiff = neitherMean != 0 ? abs(diff / neitherMean) * 100 : 0
            let totalDays = bothCount + neitherCount
            let impactScore = min(percentDiff * log2(Double(totalDays)) * 0.9, 100)

            let formattedPercent = String(format: "%.0f", percentDiff)
            let direction = directionWord(for: compound.outcome, diff: diff)

            let headline = "When you \(compound.conditionA.label) AND \(compound.conditionB.label), your \(compound.outcome.displayName.lowercased()) is \(formattedPercent)% \(direction)"
            let months = max(1, totalDays / 30)
            let evidence = "Based on \(totalDays) days over \(months) month\(months == 1 ? "" : "s")"

            discoveries.append(Discovery(
                headline: headline,
                detail: "The combination matters more than either habit alone. On days you do both, \(compound.outcome.displayName.lowercased()) averages \(compound.outcome.formatValue(bothMean)) \(compound.outcome.unit) vs \(compound.outcome.formatValue(neitherMean)) \(compound.outcome.unit).",
                evidence: evidence,
                metrics: [compound.conditionA.metric, compound.conditionB.metric, compound.outcome],
                type: .compoundPattern,
                impactScore: impactScore,
                icon: "arrow.triangle.merge",
                accentColor: compound.outcome.category.color
            ))
        }

        return discoveries
    }

    // MARK: - Helpers

    private static func directionWord(for metric: HealthMetric, diff: Double) -> String {
        let isIncrease = diff > 0
        // For metrics where lower is better (e.g. RHR), an increase is "higher" and a decrease is a "drop"
        if metric.higherIsBetter {
            return isIncrease ? "higher" : "lower"
        } else {
            return isIncrease ? "higher" : "drops"
        }
    }

    private static func detailText(effect: HealthMetric, aboveMean: Double, belowMean: Double, diff: Double) -> String {
        let aboveFormatted = effect.formatValue(aboveMean)
        let belowFormatted = effect.formatValue(belowMean)
        return "Average \(effect.displayName.lowercased()): \(aboveFormatted) \(effect.unit) (with) vs \(belowFormatted) \(effect.unit) (without)."
    }
}
