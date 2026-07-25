import Foundation

/// Discovers cross-metric correlations and generates insights about how health behaviors connect
struct CorrelationAnalyzer {

    /// A pre-defined metric pair to test for correlation
    private struct MetricPair {
        let metricA: HealthMetric
        let metricB: HealthMetric
        let dayOffset: Int          // 0 = same day, 1 = A day N -> B day N+1
    }

    // MARK: - Comprehensive Pair Registry (~35 physiologically-plausible pairs)

    private static let pairs: [MetricPair] = [
        // Sleep -> Recovery (next-day offsets)
        MetricPair(metricA: .sleepDuration, metricB: .restingHeartRate, dayOffset: 1),
        MetricPair(metricA: .sleepDuration, metricB: .heartRateVariability, dayOffset: 1),
        MetricPair(metricA: .sleepDeep, metricB: .heartRateVariability, dayOffset: 1),
        MetricPair(metricA: .sleepREM, metricB: .heartRateVariability, dayOffset: 1),
        MetricPair(metricA: .sleepDuration, metricB: .bloodOxygen, dayOffset: 1),

        // Exercise -> Recovery
        MetricPair(metricA: .exerciseMinutes, metricB: .heartRateVariability, dayOffset: 1),
        MetricPair(metricA: .activeCalories, metricB: .restingHeartRate, dayOffset: 1),
        MetricPair(metricA: .activeCalories, metricB: .sleepDeep, dayOffset: 0),
        MetricPair(metricA: .exerciseMinutes, metricB: .sleepDuration, dayOffset: 0),
        MetricPair(metricA: .steps, metricB: .sleepDuration, dayOffset: 0),
        MetricPair(metricA: .vo2Max, metricB: .restingHeartRate, dayOffset: 0),

        // Activity -> Body
        MetricPair(metricA: .steps, metricB: .activeCalories, dayOffset: 0),
        MetricPair(metricA: .standHours, metricB: .activeCalories, dayOffset: 0),
        MetricPair(metricA: .exerciseMinutes, metricB: .bodyFatPercentage, dayOffset: 0),
        MetricPair(metricA: .steps, metricB: .weight, dayOffset: 0),

        // Heart -> Stress / Mindfulness
        MetricPair(metricA: .mindfulMinutes, metricB: .heartRateVariability, dayOffset: 0),
        MetricPair(metricA: .mindfulMinutes, metricB: .restingHeartRate, dayOffset: 0),
        MetricPair(metricA: .respiratoryRate, metricB: .heartRateVariability, dayOffset: 0),

        // Sleep -> Activity (next-day)
        MetricPair(metricA: .sleepDuration, metricB: .steps, dayOffset: 1),
        MetricPair(metricA: .sleepDuration, metricB: .exerciseMinutes, dayOffset: 1),
        MetricPair(metricA: .sleepDeep, metricB: .activeCalories, dayOffset: 1),

        // Body -> Activity
        MetricPair(metricA: .weight, metricB: .restingHeartRate, dayOffset: 0),
        MetricPair(metricA: .bmi, metricB: .bloodPressureSystolic, dayOffset: 0),
        MetricPair(metricA: .bodyFatPercentage, metricB: .vo2Max, dayOffset: 0),

        // Respiratory -> Sleep
        MetricPair(metricA: .respiratoryRate, metricB: .sleepDeep, dayOffset: 0),
        MetricPair(metricA: .bloodOxygen, metricB: .sleepDeep, dayOffset: 0),

        // Additional cross-domain pairs
        MetricPair(metricA: .sleepDuration, metricB: .restingHeartRate, dayOffset: 0),
        MetricPair(metricA: .sleepDeep, metricB: .restingHeartRate, dayOffset: 1),
        MetricPair(metricA: .exerciseMinutes, metricB: .sleepDeep, dayOffset: 0),
        MetricPair(metricA: .steps, metricB: .heartRateVariability, dayOffset: 0),
        MetricPair(metricA: .activeCalories, metricB: .heartRateVariability, dayOffset: 1),
        MetricPair(metricA: .sleepREM, metricB: .restingHeartRate, dayOffset: 1),
        MetricPair(metricA: .vo2Max, metricB: .heartRateVariability, dayOffset: 0),
        MetricPair(metricA: .exerciseMinutes, metricB: .restingHeartRate, dayOffset: 1),
    ]

    // MARK: - Public API

    /// Analyze all metric pairs with automatic lag discovery (tests lags 0-3 for each pair)
    /// and return significant correlations as HealthCorrelation objects
    static func analyzeAll(timeSeries: [HealthMetric: MetricTimeSeries]) -> [HealthCorrelation] {
        var results: [HealthCorrelation] = []

        for pair in pairs {
            guard let seriesA = timeSeries[pair.metricA],
                  let seriesB = timeSeries[pair.metricB] else { continue }

            // Test the predefined lag AND nearby lags to find the strongest correlation
            let lagsToTest = Set([pair.dayOffset, 0, 1])

            var bestResult: (r: Double, t: Double, lag: Int, aligned: [TimeSeriesAligner.AlignedPair])?

            for lag in lagsToTest {
                let aligned: [TimeSeriesAligner.AlignedPair]
                if lag == 0 {
                    aligned = TimeSeriesAligner.alignByDate(seriesA, seriesB)
                } else {
                    aligned = TimeSeriesAligner.alignWithOffset(seriesA, seriesB, dayOffset: lag)
                }

                guard aligned.count >= 14 else { continue }

                guard let r = pearsonCorrelation(aligned),
                      abs(r) >= 0.2 else { continue }

                let n = Double(aligned.count)
                let rSquared = r * r
                guard rSquared < 1.0 else { continue }
                let t = abs(r) * sqrt((n - 2) / (1 - rSquared))
                guard t >= 2.0 else { continue }

                if bestResult.map({ abs(r) > abs($0.r) }) ?? true {
                    bestResult = (r: r, t: t, lag: lag, aligned: aligned)
                }
            }

            guard let best = bestResult else { continue }

            // Effect size: require >= 8% difference between above/below baseline groups
            let effectResult = computeConditionalEffect(
                aligned: best.aligned,
                metricA: pair.metricA,
                metricB: pair.metricB
            )
            guard effectResult.percentDiff >= 8.0 else { continue }

            let strengthLabel = Self.strengthLabel(for: abs(best.r))

            // Build personalized labels using the user's actual data
            let baseline = best.aligned.mean(of: \.valueA)
            let personalCauseLabel = Self.personalizedCauseLabel(
                metric: pair.metricA,
                baseline: baseline
            )
            let personalEffectLabel = Self.personalizedEffectLabel(
                metric: pair.metricB,
                avgAbove: effectResult.avgBAbove,
                avgBelow: effectResult.avgBBelow,
                percentDiff: effectResult.percentDiff,
                dayOffset: best.lag
            )
            let personalSummary = Self.personalizedSummary(
                metricA: pair.metricA,
                metricB: pair.metricB,
                baseline: baseline,
                avgBAbove: effectResult.avgBAbove,
                avgBBelow: effectResult.avgBBelow,
                percentDiff: effectResult.percentDiff,
                dayOffset: best.lag,
                sampleCount: best.aligned.count,
                r: best.r
            )

            results.append(HealthCorrelation(
                metricA: pair.metricA,
                metricB: pair.metricB,
                correlation: best.r,
                sampleCount: best.aligned.count,
                strengthLabel: strengthLabel,
                causeLabel: personalCauseLabel,
                effectLabel: personalEffectLabel,
                effectSummary: personalSummary,
                effectPercentDiff: effectResult.percentDiff,
                isPositive: best.r > 0,
                dayOffset: best.lag,
                avgBAbove: effectResult.avgBAbove,
                avgBBelow: effectResult.avgBBelow
            ))
        }

        return results.sorted { abs($0.correlation) > abs($1.correlation) }
    }

    /// Generate top correlation insights with natural language text
    static func generateInsights(from correlations: [HealthCorrelation]) -> [Insight] {
        // Prioritize non-obvious correlations: cross-day > cross-category > same-category
        let ranked = correlations.sorted { a, b in
            let aScore = insightPriority(a)
            let bScore = insightPriority(b)
            return aScore > bScore
        }

        return Array(ranked.prefix(3)).map { result in
            let severity: Severity = abs(result.correlation) >= 0.5 ? .warning : .info

            return Insight(
                metric: result.metricA,
                title: insightTitle(result),
                summary: result.effectSummary,
                recommendation: insightRecommendation(result),
                severity: severity,
                trend: .stable,
                currentValue: result.correlation,
                baselineValue: 0,
                deviationPercent: abs(result.correlation) * 100,
                category: .correlation,
                relatedMetrics: [result.metricA, result.metricB]
            )
        }
    }

    /// Score how "non-obvious" and valuable a correlation is.
    /// Cross-day effects > cross-category > high effect size > same-category obvious ones.
    private static func insightPriority(_ c: HealthCorrelation) -> Double {
        var score = abs(c.correlation) * 10   // base: correlation strength
        score += c.effectPercentDiff * 0.3    // bigger effect = more interesting
        if c.dayOffset > 0 { score += 15 }    // lagged = non-obvious
        if c.metricA.category != c.metricB.category { score += 10 } // cross-category = surprising
        // Penalize obvious pairs
        let obviousPairs: Set<String> = ["steps-activeCalories", "activeCalories-steps", "standHours-activeCalories"]
        let pairKey = "\(c.metricA.rawValue)-\(c.metricB.rawValue)"
        if obviousPairs.contains(pairKey) { score -= 20 }
        return score
    }

    /// Natural language insight title. reads like a discovery, not a formula.
    private static func insightTitle(_ c: HealthCorrelation) -> String {
        let diffPct = Int(c.effectPercentDiff)
        let bFormatted = c.metricB.formatValue(c.avgBAbove)

        if c.dayOffset > 0 {
            // Lagged correlations. the most valuable ones
            return "Your \(c.metricB.displayName.lowercased()) is \(diffPct)% \(c.isPositive ? "higher" : "lower") the day after more \(c.metricA.displayName.lowercased())"
        }

        // Same-day correlations
        return "Days with more \(c.metricA.displayName.lowercased()) show \(diffPct)% \(c.isPositive ? "higher" : "lower") \(c.metricB.displayName.lowercased()) (\(bFormatted)\(c.metricB.unit))"
    }

    /// Conversational recommendation. what this means for the user.
    private static func insightRecommendation(_ c: HealthCorrelation) -> String {
        let aName = c.metricA.displayName.lowercased()
        let bName = c.metricB.displayName.lowercased()
        let formattedAbove = c.metricB.formatValue(c.avgBAbove)
        let formattedBelow = c.metricB.formatValue(c.avgBBelow)
        let diffPct = Int(c.effectPercentDiff)

        if c.dayOffset > 0 {
            return "In your data, higher \(aName) days are followed by \(bName) of \(formattedAbove)\(c.metricB.unit) vs \(formattedBelow)\(c.metricB.unit). A \(diffPct)% difference that shows up the next day. This pattern held across \(c.sampleCount) days."
        }

        return "On your above-average \(aName) days, \(bName) reaches \(formattedAbove)\(c.metricB.unit) instead of \(formattedBelow)\(c.metricB.unit). That \(diffPct)% gap is consistent across \(c.sampleCount) days of your data."
    }

    // MARK: - Private

    /// Strength label based on |r|
    private static func strengthLabel(for absR: Double) -> String {
        if absR >= 0.6 { return Copy.Analysis.Correlation.strong }
        if absR >= 0.4 { return Copy.Analysis.Correlation.moderate }
        return Copy.Analysis.Correlation.mild
    }

    /// Pearson correlation on aligned pairs without intermediate arrays.
    private static func pearsonCorrelation(_ aligned: [TimeSeriesAligner.AlignedPair]) -> Double? {
        let count = aligned.count
        guard count >= 5 else { return nil }

        var sumA = 0.0
        var sumB = 0.0
        for pair in aligned {
            sumA += pair.valueA
            sumB += pair.valueB
        }
        let meanA = sumA / Double(count)
        let meanB = sumB / Double(count)

        var numerator = 0.0
        var denomA = 0.0
        var denomB = 0.0
        for pair in aligned {
            let deltaA = pair.valueA - meanA
            let deltaB = pair.valueB - meanB
            numerator += deltaA * deltaB
            denomA += deltaA * deltaA
            denomB += deltaB * deltaB
        }

        guard denomA > 0, denomB > 0 else { return nil }
        return numerator / (denomA.squareRoot() * denomB.squareRoot())
    }

    // MARK: - Personalized Natural Language

    /// Cause label with the user's actual threshold number.
    /// "More exercise" → "40+ min of exercise"
    private static func personalizedCauseLabel(metric: HealthMetric, baseline: Double) -> String {
        let formatted = metric.formatValue(baseline)
        return "\(formatted)+ \(metric.displayName.lowercased())"
    }

    /// Effect label with the user's actual outcome numbers.
    /// "Higher HRV next day" → "HRV jumps to 45ms"
    private static func personalizedEffectLabel(
        metric: HealthMetric,
        avgAbove: Double,
        avgBelow: Double,
        percentDiff: Double,
        dayOffset: Int
    ) -> String {
        let formatted = metric.formatValue(avgAbove)
        let diffPct = Int(abs(percentDiff))
        let timing = dayOffset > 0 ? " next day" : ""
        // percentDiff arrives as an absolute value, so its sign can't give the
        // direction. Derive it from the averages, which also match the printed
        // value (avgAbove) so the word and the number never contradict.
        return "\(metric.displayName) \(diffPct)% \(avgAbove >= avgBelow ? "higher" : "lower")\(timing) (\(formatted)\(metric.unit))"
    }

    /// Natural language summary that reads like a coach, not a stats report.
    private static func personalizedSummary(
        metricA: HealthMetric,
        metricB: HealthMetric,
        baseline: Double,
        avgBAbove: Double,
        avgBBelow: Double,
        percentDiff: Double,
        dayOffset: Int,
        sampleCount: Int,
        r: Double
    ) -> String {
        let aName = metricA.displayName.lowercased()
        let bName = metricB.displayName.lowercased()
        let threshold = metricA.formatValue(baseline)
        let formattedAbove = metricB.formatValue(avgBAbove)
        let formattedBelow = metricB.formatValue(avgBBelow)
        let diffPct = Int(abs(percentDiff))
        let timing = dayOffset > 0 ? "the next morning" : "that same day"

        // Build a conversational explanation
        var parts: [String] = []

        // Opening. the finding in plain language
        parts.append("On days you hit \(threshold)+ \(aName), your \(bName) averages \(formattedAbove)\(metricB.unit) \(timing). Compared to \(formattedBelow)\(metricB.unit) on lighter days.")

        // The "so what". why this matters
        parts.append("That is a \(diffPct)% difference.")

        // Confidence note. builds trust
        if sampleCount >= 30 {
            parts.append("This is based on \(sampleCount) days of your data. A reliable pattern.")
        } else {
            parts.append("Seen across \(sampleCount) days so far. Still building confidence.")
        }

        return parts.joined(separator: " ")
    }

    struct EffectResult {
        let percentDiff: Double
        let avgBAbove: Double
        let avgBBelow: Double
    }

    /// Partition by above/below baseline of metric A, compute average difference in metric B
    static func computeConditionalEffect(
        aligned: [TimeSeriesAligner.AlignedPair],
        metricA: HealthMetric,
        metricB: HealthMetric
    ) -> EffectResult {
        guard !aligned.isEmpty else {
            return EffectResult(
                percentDiff: 0,
                avgBAbove: 0,
                avgBBelow: 0
            )
        }

        let baseline = aligned.mean(of: \.valueA)

        var aboveSum = 0.0
        var belowSum = 0.0
        var aboveCount = 0
        var belowCount = 0

        for pair in aligned {
            if pair.valueA >= baseline {
                aboveSum += pair.valueB
                aboveCount += 1
            } else {
                belowSum += pair.valueB
                belowCount += 1
            }
        }

        guard aboveCount > 0, belowCount > 0 else {
            return EffectResult(
                percentDiff: 0,
                avgBAbove: 0,
                avgBBelow: 0
            )
        }

        let avgBAbove = aboveSum / Double(aboveCount)
        let avgBBelow = belowSum / Double(belowCount)

        guard avgBBelow != 0 else {
            return EffectResult(
                percentDiff: 0,
                avgBAbove: avgBAbove,
                avgBBelow: 0
            )
        }

        let percentDiff = ((avgBAbove - avgBBelow) / abs(avgBBelow)) * 100
        return EffectResult(percentDiff: abs(percentDiff), avgBAbove: avgBAbove, avgBBelow: avgBBelow)
    }
}

// MARK: - InsightAnalyzer Conformance

extension CorrelationAnalyzer: InsightAnalyzer {
    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generateInsights(from: context.correlations)
    }
}
