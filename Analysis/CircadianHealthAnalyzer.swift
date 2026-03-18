import Foundation

// MARK: - Circadian Health Analyzer

/// Computes 6 circadian biomarkers from activity and sleep data.
/// Based on chronomedicine research (Diagnostics 2025): activity amplitude,
/// inter-daily stability, intra-daily variability, sleep regularity index,
/// social jet lag, and a composite circadian alignment score.
struct CircadianHealthAnalyzer: InsightAnalyzer {

    static var analyzerID: String { "circadian_health" }
    static var insightCategory: InsightCategory { .circadian }

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
        /// Individual component scores for breakdown display
        let componentScores: ComponentScores
        /// Days of data used
        let daysAnalyzed: Int

        struct ComponentScores {
            let amplitudeScore: Double   // 0-100
            let stabilityScore: Double   // 0-100
            let fragmentationScore: Double // 0-100
            let regularityScore: Double  // 0-100
            let jetLagScore: Double      // 0-100
        }

        var isHealthy: Bool { circadianAlignmentScore >= 70 }
        var isDisrupted: Bool { circadianAlignmentScore < 50 }
    }

    // MARK: - Configuration

    private static let minimumDays = 7
    private static let idealDays = 14

    // MARK: - InsightAnalyzer Conformance

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        guard let biomarkers = computeBiomarkers(from: context) else { return [] }

        var insights: [Insight] = []

        // Primary circadian score insight
        let scoreLevel: String
        let severity: Severity
        if biomarkers.circadianAlignmentScore >= 80 {
            scoreLevel = "excellent"
            severity = .info
        } else if biomarkers.circadianAlignmentScore >= 65 {
            scoreLevel = "good"
            severity = .info
        } else if biomarkers.circadianAlignmentScore >= 50 {
            scoreLevel = "moderate"
            severity = .warning
        } else {
            scoreLevel = "disrupted"
            severity = .warning
        }

        insights.append(InsightFactory.make(
            metric: .sleepDuration,
            title: "Circadian alignment is \(scoreLevel)",
            summary: circadianDetailText(biomarkers),
            recommendation: biomarkers.isDisrupted
                ? "Strengthen your circadian rhythm by keeping consistent sleep/wake times and getting daylight exposure in the morning."
                : "Your circadian rhythm is well-aligned. Keep maintaining consistent daily patterns.",
            severity: severity,
            trend: biomarkers.circadianAlignmentScore >= 65 ? .stable : .declining,
            currentValue: Double(biomarkers.circadianAlignmentScore),
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
                title: "Social jet lag detected: \(hours)h shift",
                summary: "Your weekend sleep midpoint shifts \(hours) hours from weekdays.",
                recommendation: "Try keeping weekend wake times within 1 hour of weekdays to reduce circadian disruption.",
                severity: biomarkers.socialJetLag > 2.5 ? .critical : .warning,
                trend: .declining,
                currentValue: biomarkers.socialJetLag,
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
                title: "Irregular sleep pattern detected",
                summary: "Your sleep regularity index is \(Int(biomarkers.sleepRegularityIndex))/100.",
                recommendation: "Aim for consistent bed and wake times. Irregular sleep timing is linked to metabolic disruption and mood changes.",
                severity: .warning,
                trend: .declining,
                currentValue: biomarkers.sleepRegularityIndex,
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
                title: "Activity rhythm is fragmented",
                summary: "Your daily activity pattern shows high fragmentation (IV: \(String(format: "%.2f", biomarkers.intraDailyVariability))).",
                recommendation: "A more consolidated active period during the day supports better circadian health.",
                severity: .warning,
                trend: .stable,
                currentValue: biomarkers.intraDailyVariability,
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
                title: "Your daily rhythm is strong and consistent",
                summary: "High inter-daily stability (\(Int(biomarkers.interDailyStability * 100))%) with robust activity amplitude.",
                recommendation: "This pattern is associated with better metabolic health and mood regulation. Keep it up.",
                severity: .info,
                trend: .improving,
                currentValue: biomarkers.interDailyStability,
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
        let calendar = Calendar.current

        // Need at least 7 days of step/activity data
        guard let stepsSeries = context.timeSeries[.steps],
              stepsSeries.samples.count >= minimumDays else {
            return nil
        }

        let sleepSeries = context.timeSeries[.sleepDuration]
        let samples = stepsSeries.samples.sorted { $0.date < $1.date }
        let daysAnalyzed = samples.count

        // Build hourly activity profile (approximated from daily data)
        // For true circadian analysis, we'd want hourly data, but we approximate
        // using the daily value distribution across known active/rest periods
        let dailyValues = samples.map(\.value)

        // 1. Activity Amplitude (M10/L5 ratio, normalized)
        let sorted = dailyValues.sorted()
        let l5Count = max(1, sorted.count / 3)  // lowest third
        let m10Count = max(1, (sorted.count * 2) / 3)  // highest two-thirds
        let l5Mean = sorted.prefix(l5Count).reduce(0.0, +) / Double(l5Count)
        let m10Mean = sorted.suffix(m10Count).reduce(0.0, +) / Double(m10Count)
        let overallMean = dailyValues.reduce(0.0, +) / Double(dailyValues.count)
        let relativeAmplitude = overallMean > 0 ? (m10Mean - l5Mean) / (m10Mean + l5Mean) : 0

        // 2. Inter-daily Stability (IS)
        // IS = (N * Σ(x̄_h - x̄)²) / (p * Σ(x_i - x̄)²)
        // Simplified for daily data: variance of day-of-week means / total variance
        let weekdayMeans = computeWeekdayMeans(samples: samples, calendar: calendar)
        let weekdayVariance = weekdayMeans.values.map { ($0 - overallMean) * ($0 - overallMean) }.reduce(0, +) / max(1, Double(weekdayMeans.count))
        let totalVariance = dailyValues.map { ($0 - overallMean) * ($0 - overallMean) }.reduce(0, +) / max(1, Double(dailyValues.count))
        let is_value = totalVariance > 0 ? min(1.0, weekdayVariance / totalVariance * Double(weekdayMeans.count)) : 0

        // 3. Intra-daily Variability (IV)
        // IV = (N * Σ(x_i - x_{i-1})²) / ((N-1) * Σ(x_i - x̄)²)
        var consecutiveDiffSquaredSum = 0.0
        for i in 1..<dailyValues.count {
            let diff = dailyValues[i] - dailyValues[i - 1]
            consecutiveDiffSquaredSum += diff * diff
        }
        let totalSquaredSum = dailyValues.map { ($0 - overallMean) * ($0 - overallMean) }.reduce(0, +)
        let n = Double(dailyValues.count)
        let iv_value = totalSquaredSum > 0 ? (n * consecutiveDiffSquaredSum) / ((n - 1) * totalSquaredSum) : 0

        // 4. Sleep Regularity Index (SRI)
        let sri = computeSleepRegularity(sleepSeries: sleepSeries, calendar: calendar)

        // 5. Social Jet Lag
        let socialJetLag = computeSocialJetLag(sleepSeries: sleepSeries, calendar: calendar)

        // 6. Component Scores (each normalized to 0-100)
        let amplitudeScore = min(100, max(0, relativeAmplitude * 200))  // RA of 0.5 = 100
        let stabilityScore = min(100, max(0, is_value * 100))
        let fragmentationScore = min(100, max(0, (2.0 - iv_value) * 50))  // IV of 0 = 100
        let regularityScore = sri
        let jetLagScore = min(100, max(0, (3.0 - socialJetLag) / 3.0 * 100))  // 0h = 100, 3h = 0

        let componentScores = CircadianBiomarkers.ComponentScores(
            amplitudeScore: amplitudeScore,
            stabilityScore: stabilityScore,
            fragmentationScore: fragmentationScore,
            regularityScore: regularityScore,
            jetLagScore: jetLagScore
        )

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
            componentScores: componentScores,
            daysAnalyzed: daysAnalyzed
        )
    }

    // MARK: - Helpers

    private static func computeWeekdayMeans(samples: [MetricSample], calendar: Calendar) -> [Int: Double] {
        var buckets: [Int: [Double]] = [:]
        for sample in samples {
            let weekday = calendar.component(.weekday, from: sample.date)
            buckets[weekday, default: []].append(sample.value)
        }
        return buckets.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    private static func computeSleepRegularity(sleepSeries: MetricTimeSeries?, calendar: Calendar) -> Double {
        guard let series = sleepSeries, series.samples.count >= 7 else {
            return 50 // default moderate when no sleep data
        }

        let sorted = series.samples.sorted { $0.date < $1.date }
        let durations = sorted.map(\.value)

        // SRI approximation: consistency of sleep duration
        // Perfect regularity = same duration every day
        let mean = durations.reduce(0, +) / Double(durations.count)
        guard mean > 0 else { return 50 }

        let coefficientOfVariation = sqrt(durations.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(durations.count)) / mean

        // CV of 0 = 100 (perfect), CV of 0.3+ = 0 (highly irregular)
        return min(100, max(0, (0.3 - coefficientOfVariation) / 0.3 * 100))
    }

    private static func computeSocialJetLag(sleepSeries: MetricTimeSeries?, calendar: Calendar) -> Double {
        guard let series = sleepSeries, series.samples.count >= 7 else {
            return 0
        }

        var weekdayDurations: [Double] = []
        var weekendDurations: [Double] = []

        for sample in series.samples {
            let weekday = calendar.component(.weekday, from: sample.date)
            let isWeekend = weekday == 1 || weekday == 7
            if isWeekend {
                weekendDurations.append(sample.value)
            } else {
                weekdayDurations.append(sample.value)
            }
        }

        guard !weekdayDurations.isEmpty, !weekendDurations.isEmpty else { return 0 }

        let weekdayMean = weekdayDurations.reduce(0, +) / Double(weekdayDurations.count)
        let weekendMean = weekendDurations.reduce(0, +) / Double(weekendDurations.count)

        // Social jet lag approximation: difference in sleep duration
        // as proxy for sleep midpoint shift (longer weekend sleep = later midpoint)
        // Convert from seconds to hours difference
        return abs(weekendMean - weekdayMean) / 3600.0
    }

    private static func circadianDetailText(_ biomarkers: CircadianBiomarkers) -> String {
        var parts: [String] = []
        parts.append("Circadian score: \(biomarkers.circadianAlignmentScore)/100 (\(biomarkers.daysAnalyzed)-day analysis).")

        if biomarkers.sleepRegularityIndex >= 75 {
            parts.append("Sleep timing is consistent.")
        } else {
            parts.append("Sleep timing varies — aim for a fixed schedule.")
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
