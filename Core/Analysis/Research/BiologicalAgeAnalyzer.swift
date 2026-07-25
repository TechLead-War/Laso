import Foundation

/// Heuristic — unvalidated. Computes a composite "biological age" estimate
/// from activity rhythm amplitude (cosinor analysis), a VO2max percentile,
/// RHR trajectory, and mobility metrics. The bracket cutoffs are heuristic
/// and not clinically validated; treat outputs as informational signals.
struct BiologicalAgeAnalyzer {

    // MARK: - VO2max Age/Sex Norms (heuristic — unvalidated)
    // Each tuple: (ageBracketMidpoint, maleAvg, femaleAvg)

    private static let vo2maxNorms: [(age: Double, male: Double, female: Double)] = [
        (19, 39.7, 31.1),
        (25, 38.5, 30.5),
        (35, 36.0, 28.8),
        (45, 34.0, 27.0),
        (55, 31.5, 25.5),
        (65, 29.0, 24.0),
        (75, 27.0, 23.0),
        (85, 25.9, 22.2),
    ]

    // MARK: - Analysis

    static func generateInsights(context: AnalysisContext) -> [Insight] {
        var insights: [Insight] = []

        // Collect available components
        var ageEstimates: [(component: String, estimatedAge: Double, weight: Double)] = []

        // 1. VO2max-based fitness age (strongest single predictor)
        if let vo2Insight = computeVO2maxAge(context: context) {
            ageEstimates.append(vo2Insight)
        }

        // 2. RHR-based cardiovascular age
        if let rhrInsight = computeRHRAge(context: context) {
            ageEstimates.append(rhrInsight)
        }

        // 3. Activity rhythm amplitude (CosinorAge proxy)
        if let rhythmInsight = computeActivityRhythmAge(context: context) {
            ageEstimates.append(rhythmInsight)
        }

        // 4. Mobility-based functional age
        if let mobilityInsight = computeMobilityAge(context: context) {
            ageEstimates.append(mobilityInsight)
        }

        // 5. HRV-based autonomic age
        if let hrvInsight = computeHRVAge(context: context) {
            ageEstimates.append(hrvInsight)
        }

        guard ageEstimates.count >= 2 else { return [] }

        // Weighted average biological age
        let totalWeight = ageEstimates.map(\.weight).reduce(0, +)
        let weightedAge = ageEstimates.map { $0.estimatedAge * $0.weight }.reduce(0, +) / max(totalWeight, 1)

        // We don't know the user's chronological age directly, but we can express
        // the result as a relative fitness equivalent and compare components.
        let componentBreakdown = ageEstimates
            .sorted { $0.estimatedAge < $1.estimatedAge }
            .map { Copy.Analysis.Research.BiologicalAge.componentBreakdownEntry(component: $0.component, years: String(format: "%.0f", $0.estimatedAge)) }
            .joined(separator: ", ")

        let youngestComponent = ageEstimates.min(by: { $0.estimatedAge < $1.estimatedAge })!
        let oldestComponent = ageEstimates.max(by: { $0.estimatedAge < $1.estimatedAge })!
        let ageSpread = oldestComponent.estimatedAge - youngestComponent.estimatedAge
        let weightedAgeText = String(format: "%.0f", weightedAge)

        // Primary insight: Biological age estimate
        insights.append(InsightFactory.observation(
            metric: .vo2Max,
            title: Copy.Analysis.Research.BiologicalAge.fitnessAgeTitle(years: weightedAgeText),
            summary: Copy.Analysis.Research.BiologicalAge.fitnessAgeSummary(componentCount: ageEstimates.count, years: weightedAgeText, strongest: youngestComponent.component, oldest: oldestComponent.component),
            recommendation: Copy.Analysis.Research.BiologicalAge.fitnessAgeRecommendation(breakdown: componentBreakdown),
            currentValue: weightedAge,
            baselineValue: weightedAge,
            deviationPercent: 0,
            category: .clinicalTrajectory,
            relatedMetrics: [.vo2Max, .restingHeartRate, .heartRateVariability, .walkingSpeed],
            context: InsightContext(
                confidenceLevel: min(Double(ageEstimates.count) / 5.0, 1.0),
                dataPointCount: ageEstimates.count
            )
        ))

        // Insight: Large spread between components → imbalance
        if ageSpread > 15 {
            let spreadText = String(format: "%.0f", ageSpread)
            let youngestText = String(format: "%.0f", youngestComponent.estimatedAge)
            let oldestText = String(format: "%.0f", oldestComponent.estimatedAge)
            insights.append(InsightFactory.make(
                metric: .vo2Max,
                title: Copy.Analysis.Research.BiologicalAge.imbalanceTitle,
                summary: Copy.Analysis.Research.BiologicalAge.imbalanceSummary(spread: spreadText, youngestComponent: youngestComponent.component, youngestAge: youngestText, oldestComponent: oldestComponent.component, oldestAge: oldestText),
                recommendation: Copy.Analysis.Research.BiologicalAge.imbalanceRecommendation(oldestComponent: oldestComponent.component),
                severity: .info,
                trend: .stable,
                currentValue: ageSpread,
                baselineValue: 10,
                deviationPercent: ((ageSpread - 10) / 10) * 100,
                category: .clinicalTrajectory,
                directive: .informational,
                relatedMetrics: [.vo2Max, .restingHeartRate, .walkingSpeed]
            ))
        }

        return insights
    }

    // MARK: - Component Age Estimators

    private static func computeVO2maxAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let vo2Series = context.timeSeries[.vo2Max] else { return nil }
        let recent = vo2Series.samples(lastDays: 90)
        guard recent.count >= 3 else { return nil }

        let currentVO2 = recent.tailMean(5)
        guard currentVO2 > 10 else { return nil }

        // Find the age where this VO2max is average (interpolate between norms)
        // Use male norms as default; we don't have sex info in context
        // The resulting age is approximate either way
        let norms = vo2maxNorms.map { ($0.age, ($0.male + $0.female) / 2.0) }

        var estimatedAge = norms.last!.0

        for i in 0..<(norms.count - 1) {
            let (age1, vo2_1) = norms[i]
            let (age2, vo2_2) = norms[i + 1]

            if currentVO2 >= vo2_2 && currentVO2 <= vo2_1 {
                // Interpolate
                let fraction = (vo2_1 - currentVO2) / max(vo2_1 - vo2_2, 0.1)
                estimatedAge = age1 + fraction * (age2 - age1)
                break
            } else if currentVO2 > vo2_1 && i == 0 {
                // Better than youngest bracket
                let excess = (currentVO2 - vo2_1) / max(vo2_1 - vo2_2, 0.1)
                estimatedAge = max(15, age1 - excess * (age2 - age1))
                break
            }
        }

        return (Copy.Analysis.Research.BiologicalAge.cardioFitnessComponent, estimatedAge, BiologicalAgeConfig.cardioFitnessWeight)
    }

    private static func computeRHRAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let rhrSeries = context.timeSeries[.restingHeartRate] else { return nil }
        let recent = rhrSeries.samples(lastDays: 30)
        guard recent.count >= 10 else { return nil }

        let currentRHR = recent.tailMean(7)

        let rhrAge: Double
        if currentRHR <= BiologicalAgeConfig.rhrYoungFitCeiling {
            rhrAge = BiologicalAgeConfig.rhrYoungFitAge
        } else if currentRHR <= BiologicalAgeConfig.rhrAverageCeiling {
            rhrAge = BiologicalAgeConfig.rhrYoungFitAge
                + (currentRHR - BiologicalAgeConfig.rhrYoungFitCeiling)
                * BiologicalAgeConfig.rhrSlopeYoungToAverage
        } else if currentRHR <= BiologicalAgeConfig.rhrElevatedCeiling {
            rhrAge = BiologicalAgeConfig.rhrAverageAge
                + (currentRHR - BiologicalAgeConfig.rhrAverageCeiling)
                * BiologicalAgeConfig.rhrSlopeAverageToElevated
        } else {
            rhrAge = BiologicalAgeConfig.rhrElevatedAge
                + (currentRHR - BiologicalAgeConfig.rhrElevatedCeiling)
                * BiologicalAgeConfig.rhrSlopeElevated
        }

        return (Copy.Analysis.Research.BiologicalAge.restingHeartRateComponent, min(rhrAge, BiologicalAgeConfig.maxComputedAge), BiologicalAgeConfig.restingHeartRateWeight)
    }

    private static func computeActivityRhythmAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let stepsSeries = context.timeSeries[.steps] else { return nil }
        let samples = stepsSeries.samples(lastDays: 60)
        guard samples.count >= 30 else { return nil }

        // CosinorAge proxy: activity rhythm amplitude
        // High amplitude (large difference between active and rest periods) = younger
        // Low amplitude (flat activity pattern) = older biological age
        let values = samples.map(\.value)
        let mean = values.mean
        guard mean > 0 else { return nil }

        let stdDev = values.standardDeviation
        let relativeAmplitude = stdDev / mean // Coefficient of variation as amplitude proxy

        // Also compute day-to-day regularity (lower is better)
        var dayDiffs: [Double] = []
        let sorted = samples.sorted { $0.date < $1.date }
        for i in 1..<sorted.count {
            dayDiffs.append(abs(sorted[i].value - sorted[i-1].value))
        }
        let avgDayDiff = dayDiffs.isEmpty ? stdDev : dayDiffs.mean
        let regularity = 1.0 - min(avgDayDiff / max(mean, 1), 1.0)

        let rhythmScore = relativeAmplitude * BiologicalAgeConfig.rhythmAmplitudeWeight
            + regularity * BiologicalAgeConfig.rhythmRegularityWeight

        let rhythmAge: Double
        if rhythmScore >= BiologicalAgeConfig.rhythmYoungThreshold {
            rhythmAge = BiologicalAgeConfig.rhythmYoungAge
        } else if rhythmScore >= BiologicalAgeConfig.rhythmMidThreshold {
            rhythmAge = BiologicalAgeConfig.rhythmYoungAge
                + (BiologicalAgeConfig.rhythmYoungThreshold - rhythmScore)
                / BiologicalAgeConfig.rhythmMidBracketSpan
                * BiologicalAgeConfig.rhythmMidBracketAgeSpan
        } else {
            rhythmAge = BiologicalAgeConfig.rhythmMidAge
                + (BiologicalAgeConfig.rhythmMidThreshold - rhythmScore)
                / BiologicalAgeConfig.rhythmOlderBracketSpan
                * BiologicalAgeConfig.rhythmOlderBracketAgeSpan
        }

        return (Copy.Analysis.Research.BiologicalAge.activityRhythmComponent, min(max(rhythmAge, BiologicalAgeConfig.minComputedAge), BiologicalAgeConfig.maxComputedAge), BiologicalAgeConfig.activityRhythmWeight)
    }

    private static func computeMobilityAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        var mobilityScores: [Double] = []

        if let speedSeries = context.timeSeries[.walkingSpeed] {
            let recent = speedSeries.samples(lastDays: 30)
            if recent.count >= 5 {
                let speed = recent.tailMean(10)
                let speedAge: Double
                if speed >= BiologicalAgeConfig.walkingSpeedYoungAnchor {
                    speedAge = BiologicalAgeConfig.walkingSpeedYoungAge
                } else if speed >= BiologicalAgeConfig.walkingSpeedMidAnchor {
                    speedAge = BiologicalAgeConfig.walkingSpeedYoungAge
                        + (BiologicalAgeConfig.walkingSpeedYoungAnchor - speed)
                        / BiologicalAgeConfig.walkingSpeedMidBracketSpan
                        * BiologicalAgeConfig.walkingSpeedMidBracketAgeSpan
                } else if speed >= BiologicalAgeConfig.walkingSpeedSlowAnchor {
                    speedAge = BiologicalAgeConfig.walkingSpeedMidAge
                        + (BiologicalAgeConfig.walkingSpeedMidAnchor - speed)
                        / BiologicalAgeConfig.walkingSpeedSlowBracketSpan
                        * BiologicalAgeConfig.walkingSpeedSlowBracketAgeSpan
                } else {
                    speedAge = BiologicalAgeConfig.walkingSpeedSlowAge
                        + (BiologicalAgeConfig.walkingSpeedSlowAnchor - speed)
                        / BiologicalAgeConfig.walkingSpeedVerySlowBracketSpan
                        * BiologicalAgeConfig.walkingSpeedVerySlowBracketAgeSpan
                }
                mobilityScores.append(min(speedAge, BiologicalAgeConfig.walkingSpeedAgeCap))
            }
        }

        if let dspSeries = context.timeSeries[.walkingDoubleSupportPercentage] {
            let recent = dspSeries.samples(lastDays: 30)
            if recent.count >= 5 {
                let dsp = recent.tailMean(10)
                let dspAge = max(
                    BiologicalAgeConfig.doubleSupportFloorAge,
                    min(
                        BiologicalAgeConfig.doubleSupportCapAge,
                        BiologicalAgeConfig.doubleSupportYoungAge
                            + (dsp - BiologicalAgeConfig.doubleSupportYoungAnchor)
                            * BiologicalAgeConfig.doubleSupportSlope
                    )
                )
                mobilityScores.append(dspAge)
            }
        }

        guard !mobilityScores.isEmpty else { return nil }
        return (Copy.Analysis.Research.BiologicalAge.mobilityComponent, mobilityScores.mean, BiologicalAgeConfig.mobilityWeight)
    }

    private static func computeHRVAge(context: AnalysisContext) -> (component: String, estimatedAge: Double, weight: Double)? {
        guard let hrvSeries = context.timeSeries[.heartRateVariability] else { return nil }
        let recent = hrvSeries.samples(lastDays: 30)
        guard recent.count >= 10 else { return nil }

        let currentHRV = recent.tailMean(7)

        let hrvAge: Double
        if currentHRV >= BiologicalAgeConfig.hrvYoungAnchor {
            hrvAge = BiologicalAgeConfig.hrvYoungAge
        } else if currentHRV >= BiologicalAgeConfig.hrvAdultAnchor {
            hrvAge = BiologicalAgeConfig.hrvYoungAge
                + (BiologicalAgeConfig.hrvYoungAnchor - currentHRV)
                / BiologicalAgeConfig.hrvAdultBracketSpan
                * BiologicalAgeConfig.hrvAdultBracketAgeSpan
        } else if currentHRV >= BiologicalAgeConfig.hrvMidlifeAnchor {
            hrvAge = BiologicalAgeConfig.hrvAdultAge
                + (BiologicalAgeConfig.hrvAdultAnchor - currentHRV)
                / BiologicalAgeConfig.hrvMidlifeBracketSpan
                * BiologicalAgeConfig.hrvMidlifeBracketAgeSpan
        } else if currentHRV >= BiologicalAgeConfig.hrvOlderAnchor {
            hrvAge = BiologicalAgeConfig.hrvMidlifeAge
                + (BiologicalAgeConfig.hrvMidlifeAnchor - currentHRV)
                / BiologicalAgeConfig.hrvOlderBracketSpan
                * BiologicalAgeConfig.hrvOlderBracketAgeSpan
        } else {
            hrvAge = BiologicalAgeConfig.hrvOlderAge
                + (BiologicalAgeConfig.hrvOlderAnchor - currentHRV)
                / BiologicalAgeConfig.hrvVeryLowBracketSpan
                * BiologicalAgeConfig.hrvVeryLowBracketAgeSpan
        }

        return (Copy.Analysis.Research.BiologicalAge.autonomicComponent, min(hrvAge, BiologicalAgeConfig.maxComputedAge), BiologicalAgeConfig.hrvWeight)
    }
}

// MARK: - InsightAnalyzer Conformance

extension BiologicalAgeAnalyzer: InsightAnalyzer {}
