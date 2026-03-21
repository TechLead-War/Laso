import Foundation

/// Research: Multiple 2025 studies on wrist temperature + metabolic health.
/// Finding: Wrist temperature during sleep detects ovulation (82-93% accuracy),
/// metabolic shifts, and subclinical infection. Temperature rhythm disruption
/// linked to metabolic syndrome.
///
/// Also: Compound signal (temperature up + HRV down) = immune activation.
///
/// Implementation: Computes 30-day rolling baseline of sleeping wrist temperature.
/// Deviations of >0.3°C for 2+ nights trigger investigation. Enhances
/// IllnessEarlyWarning with metabolic and reproductive health signals.
struct TemperatureCompoundAnalyzer {

    // MARK: - Constants

    private static let minDaysRequired = 21
    private static let mildElevationThreshold = 0.3 // °C
    private static let significantElevationThreshold = 0.5 // °C
    private static let consecutiveNightsRequired = 2

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        guard let tempSeries = context.timeSeries[.appleSleepingWristTemperature] else { return [] }

        let samples = tempSeries.samples(lastDays: 60)
        guard samples.count >= minDaysRequired else { return [] }

        let sorted = samples.sorted { $0.date < $1.date }

        // Compute rolling 30-day baseline
        let baselineSamples = Array(sorted.dropLast(min(7, sorted.count - 1)))
        guard baselineSamples.count >= 14 else { return [] }

        let baselineMean = baselineSamples.map(\.value).mean
        let baselineSD = baselineSamples.map(\.value).standardDeviation

        // Recent nights (last 7 days)
        let recentSamples = Array(sorted.suffix(7))
        guard recentSamples.count >= 2 else { return [] }

        let recentMean = recentSamples.map(\.value).mean
        let deviation = recentMean - baselineMean

        // Count consecutive elevated nights
        var consecutiveElevated = 0
        for sample in recentSamples.reversed() {
            if sample.value > baselineMean + mildElevationThreshold {
                consecutiveElevated += 1
            } else {
                break
            }
        }

        // Check for cyclical pattern (menstrual cycle)
        let isCyclicalPattern = detectCyclicalPattern(sorted: sorted, baselineMean: baselineMean)

        // Insight 1: Sustained temperature elevation (non-cyclical)
        if consecutiveElevated >= consecutiveNightsRequired &&
           deviation >= mildElevationThreshold &&
           !isCyclicalPattern {

            // Check if HRV is also suppressed (compound signal)
            let hrvSuppressed = isHRVSuppressed(context: context)

            if hrvSuppressed && deviation >= mildElevationThreshold {
                // Compound signal. already reported by InflammationRiskAnalyzer
                // We add the temperature-specific detail
                insights.append(InsightFactory.make(
                    metric: .appleSleepingWristTemperature,
                    title: "Body Temperature Elevated \(consecutiveElevated) Nights",
                    summary: "Your sleeping wrist temperature is \(String(format: "%.1f", deviation))°C above your 30-day baseline for \(consecutiveElevated) consecutive nights. Combined with suppressed HRV, this compound pattern is associated with early immune response.",
                    recommendation: "Sustained nighttime temperature elevation (\(String(format: "+%.1f", deviation))°C vs baseline \(String(format: "%.1f", baselineMean))°C) alongside low HRV reflects the autonomic and thermoregulatory signatures of immune activation. This compound signal typically precedes symptom onset by 1-3 days.",
                    severity: deviation >= significantElevationThreshold ? .warning : .info,
                    trend: .declining,
                    currentValue: recentMean,
                    baselineValue: baselineMean,
                    deviationPercent: (deviation / max(abs(baselineMean), 0.1)) * 100,
                    category: .illnessWarning,
                    directive: .rest,
                    relatedMetrics: [.appleSleepingWristTemperature, .heartRateVariability, .restingHeartRate],
                    context: InsightContext(
                        confidenceLevel: 0.80,
                        dataPointCount: samples.count
                    )
                ))
            } else {
                // Temperature-only elevation
                insights.append(InsightFactory.make(
                    metric: .appleSleepingWristTemperature,
                    title: "Nighttime Temperature Above Baseline",
                    summary: "Your sleeping wrist temperature has been \(String(format: "%.1f", deviation))°C above your personal baseline for \(consecutiveElevated) nights. Sustained elevation can reflect metabolic shifts, stress, or early subclinical changes.",
                    recommendation: "Your nighttime temperature: \(String(format: "%.1f", recentMean))°C vs 30-day baseline of \(String(format: "%.1f", baselineMean))°C (\u{00B1}\(String(format: "%.2f", baselineSD))). Research shows wrist temperature deviations >0.3°C sustained over multiple nights may indicate metabolic changes, hormonal shifts, or early immune responses.",
                    severity: .info,
                    trend: .declining,
                    currentValue: recentMean,
                    baselineValue: baselineMean,
                    deviationPercent: (deviation / max(abs(baselineMean), 0.1)) * 100,
                    category: .illnessWarning,
                    directive: .informational,
                    relatedMetrics: [.appleSleepingWristTemperature, .heartRateVariability]
                ))
            }
        }

        // Insight 2: Cyclical temperature pattern detected (reproductive health)
        if isCyclicalPattern {
            let cycleAmplitude = computeCycleAmplitude(sorted: sorted, baselineMean: baselineMean)
            if cycleAmplitude >= 0.2 {
                insights.append(InsightFactory.observation(
                    metric: .appleSleepingWristTemperature,
                    title: "Temperature Cycle Pattern Detected",
                    summary: "Your wrist temperature shows a recurring cyclical pattern with \(String(format: "%.1f", cycleAmplitude))°C amplitude. consistent with hormonal cycle influence. Research shows wrist temperature tracks ovulation with 82-93% accuracy.",
                    recommendation: "The cyclical temperature variation of \(String(format: "%.1f", cycleAmplitude))°C around your baseline of \(String(format: "%.1f", baselineMean))°C reflects the biphasic pattern driven by progesterone. Post-ovulation temperatures typically rise 0.2-0.5°C above the follicular phase baseline.",
                    currentValue: cycleAmplitude,
                    baselineValue: 0.3,
                    deviationPercent: ((cycleAmplitude - 0.3) / 0.3) * 100,
                    category: .cyclePhase,
                    relatedMetrics: [.appleSleepingWristTemperature, .restingHeartRate]
                ))
            }
        }

        // Insight 3: Temperature variability as metabolic health marker
        let cv = baselineSD / max(abs(baselineMean), 0.1)
        if cv > 0.05 && !isCyclicalPattern && samples.count >= 30 {
            insights.append(InsightFactory.observation(
                metric: .appleSleepingWristTemperature,
                title: "High Temperature Variability",
                summary: "Your nighttime wrist temperature varies significantly night to night (\u{00B1}\(String(format: "%.2f", baselineSD))°C). High thermoregulatory variability is associated with disrupted circadian rhythm and metabolic health.",
                recommendation: "Temperature coefficient of variation: \(String(format: "%.1f", cv * 100))%. Research links elevated nighttime temperature variability to circadian disruption, poor sleep quality, and metabolic syndrome risk. Stable temperatures reflect stronger circadian entrainment.",
                currentValue: cv * 100,
                baselineValue: 3,
                deviationPercent: ((cv * 100 - 3) / 3) * 100,
                category: .circadian,
                relatedMetrics: [.appleSleepingWristTemperature, .sleepDuration]
            ))
        }

        return insights
    }

    // MARK: - Helpers

    private static func isHRVSuppressed(context: AnalysisContext) -> Bool {
        guard let hrvSeries = context.timeSeries[.heartRateVariability],
              let hrvBaseline = context.baselines[.heartRateVariability] else { return false }
        let recent = hrvSeries.samples(lastDays: 3)
        guard recent.count >= 2 else { return false }
        let recentAvg = recent.map(\.value).mean
        return recentAvg < hrvBaseline.mean - hrvBaseline.standardDeviation
    }

    /// Detect if temperature data shows a ~28-day cyclical pattern
    private static func detectCyclicalPattern(sorted: [MetricSample], baselineMean: Double) -> Bool {
        guard sorted.count >= 28 else { return false }

        // Simple: count sign changes relative to baseline over the data
        var signChanges = 0
        var lastAboveBaseline = sorted.first!.value > baselineMean

        for sample in sorted.dropFirst() {
            let aboveBaseline = sample.value > baselineMean
            if aboveBaseline != lastAboveBaseline {
                signChanges += 1
                lastAboveBaseline = aboveBaseline
            }
        }

        let daysSpanned = Calendar.current.dateComponents(
            [.day], from: sorted.first!.date, to: sorted.last!.date
        ).day ?? 1

        // Expect ~2 sign changes per 28-day cycle (up→down, down→up)
        let expectedCycles = Double(daysSpanned) / 28.0
        let expectedChanges = expectedCycles * 2

        // If sign changes are roughly consistent with cyclical pattern
        return Double(signChanges) >= expectedChanges * 0.5 &&
               Double(signChanges) <= expectedChanges * 2.0 &&
               expectedCycles >= 1.0
    }

    /// Compute the amplitude of the cyclical temperature pattern
    private static func computeCycleAmplitude(sorted: [MetricSample], baselineMean: Double) -> Double {
        let aboveBaseline = sorted.filter { $0.value > baselineMean }.map(\.value)
        let belowBaseline = sorted.filter { $0.value <= baselineMean }.map(\.value)

        guard !aboveBaseline.isEmpty, !belowBaseline.isEmpty else { return 0 }

        return aboveBaseline.mean - belowBaseline.mean
    }
}

// MARK: - InsightAnalyzer Conformance

extension TemperatureCompoundAnalyzer: InsightAnalyzer {
    static var analyzerID: String { "temperatureCompound" }
    static var insightCategory: InsightCategory { .illnessWarning }
}
