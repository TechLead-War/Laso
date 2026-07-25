import Foundation

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
                // Compound signal — already reported by InflammationRiskAnalyzer; this adds the temperature-specific detail.
                let deviationText = String(format: "%.1f", deviation)
                let plusDeviationText = String(format: "+%.1f", deviation)
                let baselineText = String(format: "%.1f", baselineMean)
                insights.append(InsightFactory.make(
                    metric: .appleSleepingWristTemperature,
                    title: Copy.Analysis.Research.TemperatureCompound.bodyTempElevatedTitle(nights: consecutiveElevated),
                    summary: Copy.Analysis.Research.TemperatureCompound.compoundSummary(deviation: deviationText, nights: consecutiveElevated),
                    recommendation: Copy.Analysis.Research.TemperatureCompound.compoundRecommendation(deviation: plusDeviationText, baseline: baselineText),
                    severity: deviation >= significantElevationThreshold ? .warning : .info,
                    trend: .declining,
                    currentValue: recentMean,
                    baselineValue: baselineMean,
                    deviationPercent: (deviation / max(abs(baselineMean), 0.1)) * 100,
                    category: .watchSignal,
                    directive: .rest,
                    relatedMetrics: [.appleSleepingWristTemperature, .heartRateVariability, .restingHeartRate],
                    context: InsightContext(
                        confidenceLevel: 0.80,
                        dataPointCount: samples.count
                    )
                ))
            } else {
                // Temperature-only elevation
                let deviationText = String(format: "%.1f", deviation)
                let recentText = String(format: "%.1f", recentMean)
                let baselineText = String(format: "%.1f", baselineMean)
                let sdText = String(format: "%.2f", baselineSD)
                insights.append(InsightFactory.make(
                    metric: .appleSleepingWristTemperature,
                    title: Copy.Analysis.Research.TemperatureCompound.nighttimeAboveBaselineTitle,
                    summary: Copy.Analysis.Research.TemperatureCompound.tempOnlySummary(deviation: deviationText, nights: consecutiveElevated),
                    recommendation: Copy.Analysis.Research.TemperatureCompound.tempOnlyRecommendation(recent: recentText, baseline: baselineText, sd: sdText),
                    severity: .info,
                    trend: .declining,
                    currentValue: recentMean,
                    baselineValue: baselineMean,
                    deviationPercent: (deviation / max(abs(baselineMean), 0.1)) * 100,
                    category: .watchSignal,
                    directive: .informational,
                    relatedMetrics: [.appleSleepingWristTemperature, .heartRateVariability]
                ))
            }
        }

        // Insight 2: Cyclical temperature pattern detected (reproductive health)
        if isCyclicalPattern {
            let cycleAmplitude = computeCycleAmplitude(sorted: sorted, baselineMean: baselineMean)
            if cycleAmplitude >= 0.2 {
                let amplitudeText = String(format: "%.1f", cycleAmplitude)
                let baselineText = String(format: "%.1f", baselineMean)
                insights.append(InsightFactory.observation(
                    metric: .appleSleepingWristTemperature,
                    title: Copy.Analysis.Research.TemperatureCompound.cyclePatternTitle,
                    summary: Copy.Analysis.Research.TemperatureCompound.cyclePatternSummary(amplitude: amplitudeText),
                    recommendation: Copy.Analysis.Research.TemperatureCompound.cyclePatternRecommendation(amplitude: amplitudeText, baseline: baselineText),
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
            let sdText = String(format: "%.2f", baselineSD)
            let cvText = String(format: "%.1f", cv * 100)
            insights.append(InsightFactory.observation(
                metric: .appleSleepingWristTemperature,
                title: Copy.Analysis.Research.TemperatureCompound.highVariabilityTitle,
                summary: Copy.Analysis.Research.TemperatureCompound.highVariabilitySummary(sd: sdText),
                recommendation: Copy.Analysis.Research.TemperatureCompound.highVariabilityRecommendation(cvPercent: cvText),
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
        guard sorted.count >= 28, let firstSample = sorted.first, let lastSample = sorted.last else { return false }

        // Simple: count sign changes relative to baseline over the data
        var signChanges = 0
        var lastAboveBaseline = firstSample.value > baselineMean

        for sample in sorted.dropFirst() {
            let aboveBaseline = sample.value > baselineMean
            if aboveBaseline != lastAboveBaseline {
                signChanges += 1
                lastAboveBaseline = aboveBaseline
            }
        }

        let daysSpanned = Date.cal.dateComponents(
            [.day], from: firstSample.date, to: lastSample.date
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

extension TemperatureCompoundAnalyzer: InsightAnalyzer {}
