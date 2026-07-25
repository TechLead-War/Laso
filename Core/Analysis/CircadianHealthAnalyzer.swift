import Foundation

// MARK: - Circadian Health Analyzer

/// Computes 6 circadian biomarkers from activity and sleep data:
/// activity amplitude, inter-daily stability, intra-daily variability,
/// sleep regularity index, social jet lag, and a composite circadian
/// alignment score. Thresholds are heuristic and unvalidated; treat
/// outputs as informational signals, not clinical measurements.
struct CircadianHealthAnalyzer: InsightAnalyzer {

    // MARK: - Biomarker Results

    struct CircadianBiomarkers {
        /// M10-L5 activity amplitude (higher = healthier rhythm)
        let activityAmplitude: Double
        /// Inter-daily stability: 0-1 (1 = perfectly consistent across days)
        let interDailyStability: Double
        /// Intra-daily variability: typically 0-2+ (lower = less fragmented)
        let intraDailyVariability: Double
        /// Sleep regularity index: 0-100 (100 = perfectly regular)
        let sleepRegularityIndex: Double
        /// Social jet lag in hours (difference between weekday/weekend sleep midpoints)
        let socialJetLag: Double
        /// Composite circadian alignment score: 0-100
        let circadianAlignmentScore: Int
        /// Days of data used
        let daysAnalyzed: Int

        var isDisrupted: Bool { circadianAlignmentScore < 50 }
    }

    // MARK: - Configuration

    private static let minimumDays = 7

    // MARK: - InsightAnalyzer Conformance

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        guard let biomarkers = computeBiomarkers(from: context) else { return [] }

        var insights: [Insight] = []

        // Primary circadian score insight
        let scoreLevel: String
        let severity: Severity
        if biomarkers.circadianAlignmentScore >= 80 {
            scoreLevel = Copy.Analysis.Circadian.levelExcellent
            severity = .info
        } else if biomarkers.circadianAlignmentScore >= 65 {
            scoreLevel = Copy.Analysis.Circadian.levelGood
            severity = .info
        } else if biomarkers.circadianAlignmentScore >= 50 {
            scoreLevel = Copy.Analysis.Circadian.levelModerate
            severity = .warning
        } else {
            scoreLevel = Copy.Analysis.Circadian.levelDisrupted
            severity = .warning
        }

        insights.append(InsightFactory.make(
            metric: .sleepDuration,
            title: Copy.Analysis.Circadian.alignmentTitle(level: scoreLevel),
            summary: circadianDetailText(biomarkers),
            recommendation: biomarkers.isDisrupted
                ? Copy.Analysis.Circadian.alignmentRecDisrupted
                : Copy.Analysis.Circadian.alignmentRecAligned,
            severity: severity,
            trend: biomarkers.circadianAlignmentScore >= 65 ? .stable : .declining,
            baselineValue: 70,
            deviationPercent: Double(biomarkers.circadianAlignmentScore - 70) / 70.0 * 100,
            category: .circadian,
            directive: biomarkers.isDisrupted ? .sleepBetter : .maintain
        ))

        // Social jet lag warning
        if biomarkers.socialJetLag > 1.5 {
            let hours = String(format: "%.1f", biomarkers.socialJetLag)
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Circadian.socialJetLagTitle(hours: hours),
                summary: Copy.Analysis.Circadian.socialJetLagSummary(hours: hours),
                recommendation: Copy.Analysis.Circadian.socialJetLagRec,
                severity: biomarkers.socialJetLag > 2.5 ? .critical : .warning,
                trend: .declining,
                baselineValue: 0.5,
                deviationPercent: (biomarkers.socialJetLag - 0.5) / 0.5 * 100,
                category: .circadian,
                directive: .sleepBetter
            ))
        }

        // Sleep regularity insight
        if biomarkers.sleepRegularityIndex < 60 {
            insights.append(InsightFactory.make(
                metric: .sleepDuration,
                title: Copy.Analysis.Circadian.irregularPatternTitle,
                summary: Copy.Analysis.Circadian.irregularPatternSummary(sri: Int(biomarkers.sleepRegularityIndex)),
                recommendation: Copy.Analysis.Circadian.irregularPatternRec,
                severity: .warning,
                trend: .declining,
                baselineValue: 75,
                deviationPercent: (biomarkers.sleepRegularityIndex - 75) / 75.0 * 100,
                category: .circadian,
                directive: .sleepBetter
            ))
        }

        // High fragmentation insight
        if biomarkers.intraDailyVariability > 1.2 {
            insights.append(InsightFactory.make(
                metric: .steps,
                title: Copy.Analysis.Circadian.fragmentedRhythmTitle,
                summary: Copy.Analysis.Circadian.fragmentedRhythmSummary(iv: String(format: "%.2f", biomarkers.intraDailyVariability)),
                recommendation: Copy.Analysis.Circadian.fragmentedRhythmRec,
                severity: .warning,
                trend: .stable,
                baselineValue: 0.8,
                deviationPercent: (biomarkers.intraDailyVariability - 0.8) / 0.8 * 100,
                category: .circadian,
                directive: .increaseActivity
            ))
        }

        // Strong rhythm positive insight
        if biomarkers.interDailyStability > 0.7 && biomarkers.activityAmplitude > 0.6 {
            insights.append(InsightFactory.make(
                metric: .steps,
                title: Copy.Analysis.Circadian.strongRhythmTitle,
                summary: Copy.Analysis.Circadian.strongRhythmSummary(stabilityPct: Int(biomarkers.interDailyStability * 100)),
                recommendation: Copy.Analysis.Circadian.strongRhythmRec,
                severity: .info,
                trend: .improving,
                baselineValue: 0.5,
                deviationPercent: (biomarkers.interDailyStability - 0.5) / 0.5 * 100,
                category: .circadian,
                directive: .maintain
            ))
        }

        return insights
    }

    // MARK: - Core Computation

    static func computeBiomarkers(from context: AnalysisContext) -> CircadianBiomarkers? {
        let calendar = Date.cal

        // Need at least 7 days of step/activity data
        guard let stepsSeries = context.timeSeries[.steps],
              stepsSeries.samples.count >= minimumDays else {
            return nil
        }

        let sleepSeries = context.timeSeries[.sleepDuration]
        let samples = stepsSeries.samples.sorted { $0.date < $1.date }
        let daysAnalyzed = samples.count

        let dailyValues = samples.map(\.value)

        // 1. Activity Amplitude (M10/L5 ratio, normalized)
        let sorted = dailyValues.sorted()
        let l5Count = max(1, sorted.count / 3)  // lowest third
        let m10Count = max(1, (sorted.count * 2) / 3)  // highest two-thirds
        let l5Mean = sorted.prefix(l5Count).reduce(0.0, +) / Double(l5Count)
        let m10Mean = sorted.suffix(m10Count).reduce(0.0, +) / Double(m10Count)

        // Single pass over dailyValues: compute overall mean, total squared sum,
        // consecutive diff squared sum, and weekday buckets simultaneously.
        let n = Double(dailyValues.count)
        let overallMean = dailyValues.reduce(0.0, +) / n
        var totalSquaredSum = 0.0
        var consecutiveDiffSquaredSum = 0.0
        var weekdayBuckets: [Int: (sum: Double, count: Int)] = [:]
        for i in 0..<dailyValues.count {
            let val = dailyValues[i]
            let dev = val - overallMean
            totalSquaredSum += dev * dev

            if i > 0 {
                let diff = val - dailyValues[i - 1]
                consecutiveDiffSquaredSum += diff * diff
            }

            let weekday = calendar.component(.weekday, from: samples[i].date)
            let existing = weekdayBuckets[weekday, default: (sum: 0, count: 0)]
            weekdayBuckets[weekday] = (sum: existing.sum + val, count: existing.count + 1)
        }

        let relativeAmplitude = overallMean > 0 ? (m10Mean - l5Mean) / (m10Mean + l5Mean) : 0

        // 2. Inter-daily Stability (IS)
        // IS = (N * Σ(x̄_h - x̄)²) / (p * Σ(x_i - x̄)²)
        // Simplified for daily data: variance of day-of-week means / total variance
        let weekdayMeans = weekdayBuckets.mapValues { $0.sum / Double($0.count) }
        let weekdayVariance = weekdayMeans.values.map { ($0 - overallMean) * ($0 - overallMean) }.reduce(0, +) / max(1, Double(weekdayMeans.count))
        let totalVariance = totalSquaredSum / max(1, n)
        let is_value = totalVariance > 0 ? min(1.0, weekdayVariance / totalVariance * Double(weekdayMeans.count)) : 0

        // 3. Intra-daily Variability (IV)
        // IV = (N * Σ(x_i - x_{i-1})²) / ((N-1) * Σ(x_i - x̄)²)
        let iv_value = totalSquaredSum > 0 ? (n * consecutiveDiffSquaredSum) / ((n - 1) * totalSquaredSum) : 0

        // 4 & 5. Sleep Regularity Index (SRI) and Social Jet Lag
        // Computed in a single pass over sleep samples
        let (sri, socialJetLag) = computeSleepMetrics(sleepSeries: sleepSeries, calendar: calendar)

        // 6. Component Scores (each normalized to 0-100)
        let amplitudeScore = min(100, max(0, relativeAmplitude * 200))  // RA of 0.5 = 100
        let stabilityScore = min(100, max(0, is_value * 100))
        let fragmentationScore = min(100, max(0, (2.0 - iv_value) * 50))  // IV of 0 = 100
        let regularityScore = sri
        let jetLagScore = min(100, max(0, (3.0 - socialJetLag) / 3.0 * 100))  // 0h = 100, 3h = 0

        // Weighted composite: regularity and jet lag are strongest predictors
        let composite = Int(
            amplitudeScore * 0.15 +
            stabilityScore * 0.20 +
            fragmentationScore * 0.15 +
            regularityScore * 0.30 +
            jetLagScore * 0.20
        )

        return CircadianBiomarkers(
            activityAmplitude: relativeAmplitude,
            interDailyStability: is_value,
            intraDailyVariability: iv_value,
            sleepRegularityIndex: sri,
            socialJetLag: socialJetLag,
            circadianAlignmentScore: min(100, max(0, composite)),
            daysAnalyzed: daysAnalyzed
        )
    }

    // MARK: - Helpers

    /// Computes sleep regularity index and social jet lag in a single pass over sleep samples.
    private static func computeSleepMetrics(sleepSeries: MetricTimeSeries?, calendar: Calendar) -> (sri: Double, socialJetLag: Double) {
        guard let series = sleepSeries, series.samples.count >= 14 else {
            // Neutral defaults that DON'T trigger downstream warnings (the
            // "Irregular sleep pattern detected" insight fires when SRI < 60).
            // Returning 75 keeps the score above that threshold so users with
            // insufficient sleep history don't see a fabricated warning.
            return (sri: 75, socialJetLag: 0)
        }

        // Single pass: accumulate stats for SRI (mean + variance) and social jet lag (weekday/weekend split)
        var sum = 0.0
        var sqSum = 0.0
        var weekdaySum = 0.0
        var weekdayCount = 0
        var weekendSum = 0.0
        var weekendCount = 0

        for sample in series.samples {
            let value = sample.value
            sum += value
            sqSum += value * value

            let weekday = calendar.component(.weekday, from: sample.date)
            if weekday == 1 || weekday == 7 {
                weekendSum += value
                weekendCount += 1
            } else {
                weekdaySum += value
                weekdayCount += 1
            }
        }

        let n = Double(series.samples.count)
        let mean = sum / n

        // SRI: coefficient of variation approach
        // CV of 0 = 100 (perfect regularity), CV of 0.3+ = 0 (highly irregular)
        let sri: Double
        if mean > 0 {
            let variance = sqSum / n - mean * mean
            let cv = sqrt(max(0, variance)) / mean
            sri = min(100, max(0, (0.3 - cv) / 0.3 * 100))
        } else {
            sri = 50
        }

        // Social jet lag: difference in weekday vs weekend sleep duration as proxy for midpoint shift
        let socialJetLag: Double
        if weekdayCount > 0, weekendCount > 0 {
            let weekdayMean = weekdaySum / Double(weekdayCount)
            let weekendMean = weekendSum / Double(weekendCount)
            socialJetLag = abs(weekendMean - weekdayMean) / 3600.0
        } else {
            socialJetLag = 0
        }

        return (sri: sri, socialJetLag: socialJetLag)
    }

    private static func circadianDetailText(_ biomarkers: CircadianBiomarkers) -> String {
        var parts: [String] = []
        parts.append("Circadian score: \(biomarkers.circadianAlignmentScore)/100 (\(biomarkers.daysAnalyzed)-day analysis).")

        if biomarkers.sleepRegularityIndex >= 75 {
            parts.append("Sleep timing is consistent.")
        } else {
            parts.append("Sleep timing varies. aim for a fixed schedule.")
        }

        if biomarkers.socialJetLag > 1.0 {
            parts.append("Weekend shift of \(String(format: "%.1f", biomarkers.socialJetLag))h detected.")
        }

        if biomarkers.interDailyStability > 0.6 {
            parts.append("Daily activity pattern is stable.")
        }

        return parts.joined(separator: " ")
    }
}
