import Foundation
import os

final class MLResultAggregator {

    private let logger = Logger(subsystem: "com.healthpulse.ml", category: "MLResultAggregator")

    struct AggregatedResults {
        var mlAnomalies: [TimeSeriesForecaster.ForecastAnomaly] = []
        var adaptiveAnomalies: [AdaptiveAnomalyDetector.AdaptiveAnomaly] = []
        var discoveredPatterns: [DiscoveredPattern] = []
        var mlCorrelations: [MLCorrelation] = []
        var currentHealthState: HealthState?
        var tomorrowRiskPrediction: MLPrediction?
        var policyDecision: PolicyDecision?
    }

    func collectResults(
        timeSeries: [HealthMetric: MetricTimeSeries],
        vectors: [DailyFeatureVector],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        ruleBasedAnomalies: [AnomalyDetector.AnomalyResult],
        scoreHistory: [(date: Date, score: Int)],
        focusCategories: Set<HealthCategory>,
        components: MLPipelineRunner.Components,
        calibrationManager: MLCalibrationManager,
        evaluationSummaries: [String: ComponentEvaluation],
        dataSufficiency: UncertaintyEstimator.DataSufficiency?,
        smoothedStates: [SmoothedHealthState],
        timingRecommendations: [CircadianAnalyzer.TimingRecommendation]
    ) -> AggregatedResults {
        var results = AggregatedResults()

        // Forecast anomalies
        if components.forecaster.isReady {
            results.mlAnomalies = components.forecaster.detectAnomalies(timeSeries: timeSeries)
        }

        // Adaptive anomalies (score recent days, with persistence gating)
        if components.anomalyDetector.isReady {
            results.adaptiveAnomalies = components.anomalyDetector.scoreRecent(vectors: vectors, days: 7)
        }

        // Patterns
        if components.patternMiner.isReady {
            results.discoveredPatterns = components.patternMiner.patterns
        }

        // Correlations (with FDR correction applied)
        if components.correlationDiscovery.isReady {
            results.mlCorrelations = components.correlationDiscovery.correlations
        }

        // Health state (HMM-smoothed if available)
        if components.stateClassifier.isReady {
            results.currentHealthState = components.stateClassifier.currentState
        }

        // Tomorrow prediction. blend with population prior via PersonalizationBlender
        if components.predictiveScorer.isReady, let todayVector = vectors.last {
            let personalPrediction = components.predictiveScorer.predict(todayVector: todayVector)
            results.tomorrowRiskPrediction = personalPrediction

            if let prediction = personalPrediction {
                let calibrated = calibrationManager.calibratePrediction(
                    prediction: prediction,
                    todayVector: todayVector,
                    vectors: vectors,
                    evaluationSummaries: evaluationSummaries,
                    conformalCalibrator: components.conformalCalibrator,
                    mlEvaluator: components.mlEvaluator
                )
                results.tomorrowRiskPrediction = calibrated
            }
        } else if !vectors.isEmpty {
            let availableData = buildAvailableDataForColdStart(timeSeries: timeSeries)
            let coldStart = PersonalizationBlender.coldStartPrediction(availableData: availableData)
            if coldStart.confidence > 0.05 {
                results.tomorrowRiskPrediction = MLPrediction(
                    target: "bad day tomorrow",
                    probability: coldStart.riskScore,
                    confidence: coldStart.confidence,
                    topFactors: []
                )
            }
        }

        // Apply confidence gate to tomorrow prediction
        if let prediction = results.tomorrowRiskPrediction, let sufficiency = dataSufficiency {
            let gate = UncertaintyEstimator.gate(
                modelConfidence: prediction.confidence,
                dataSufficiency: sufficiency
            )
            if !gate.shouldShow {
                logger.debug("Prediction gated: \(gate.reason ?? "low confidence")")
                results.tomorrowRiskPrediction = nil
            }
        }

        // --- Decision Policy Engine ---
        results.policyDecision = buildPolicyDecision(
            components: components,
            mlCorrelations: results.mlCorrelations,
            currentHealthState: results.currentHealthState,
            tomorrowRiskPrediction: results.tomorrowRiskPrediction,
            trends: trends,
            baselines: baselines,
            ruleBasedAnomalies: ruleBasedAnomalies,
            timeSeries: timeSeries,
            vectors: vectors,
            focusCategories: focusCategories,
            timingRecommendations: timingRecommendations
        )

        return results
    }

    func synthesizeCompoundInsights(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        currentAdaptiveAnomalies: [AdaptiveAnomalyDetector.AdaptiveAnomaly],
        currentMLCorrelations: [MLCorrelation],
        currentDiscoveredPatterns: [DiscoveredPattern],
        currentTomorrowRiskPrediction: MLPrediction?,
        smoothedStates: [SmoothedHealthState],
        scoreHistory: [(date: Date, score: Int)],
        components: MLPipelineRunner.Components
    ) -> [CompoundInsightEngine.CompoundInsight] {
        let anomalyTuples: [(date: Date, metric: HealthMetric, severity: String)] = currentAdaptiveAnomalies.compactMap { anomaly -> (date: Date, metric: HealthMetric, severity: String)? in
            guard let topFeature = anomaly.anomalousFeatures.first else { return nil }
            return (date: anomaly.date, metric: topFeature.key.metric, severity: "\(anomaly.severity)")
        }
        components.compoundInsightEngine.synthesize(
            timeSeries: timeSeries,
            baselines: baselines,
            correlations: currentMLCorrelations,
            patterns: currentDiscoveredPatterns,
            currentState: components.stateClassifier.isReady ? components.stateClassifier.currentState : nil,
            stateHistory: smoothedStates,
            prediction: currentTomorrowRiskPrediction,
            scoreHistory: scoreHistory,
            anomalies: anomalyTuples
        )
        return components.compoundInsightEngine.insights
    }

    // MARK: - Insight Generation

    func generateInsights(
        discoveredPatterns: [DiscoveredPattern],
        currentHealthState: HealthState?,
        tomorrowRiskPrediction: MLPrediction?,
        healthSignalReport: PredictiveHealthSignals.HealthSignalReport?,
        interactionEffects: [InteractionEffectEngine.InteractionEffect],
        precursorPatterns: [TemporalSequenceMiner.PrecursorPattern],
        temporalSequences: [TemporalSequenceMiner.TemporalSequence],
        changePoints: [ChangePointDetector.ChangePoint],
        optimalProfile: PersonalOptimizer.OptimalProfile?,
        idealDay: PersonalOptimizer.IdealDay?,
        mlCorrelations: [MLCorrelation],
        compoundInsightEngine: CompoundInsightEngine,
        circadianAnalyzer: CircadianAnalyzer,
        cachedVectorCount: Int
    ) -> [Insight] {
        var insights: [Insight] = []

        // Pattern insights
        for pattern in discoveredPatterns.prefix(3) {
            insights.append(Insight(
                metric: pattern.metric,
                title: Copy.Insights.discoveredPattern(pattern.patternType.rawValue),
                summary: pattern.description,
                recommendation: recommendationForPattern(pattern),
                severity: .info,
                trend: .stable,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: 0,
                category: .mlPattern,
                context: InsightContext(
                    confidenceLevel: pattern.strength,
                    dataPointCount: cachedVectorCount
                )
            ))
        }

        // Health state insight
        if let state = currentHealthState {
            let severity: Severity = state.label == "Stressed" ? .warning : .info
            let trend: TrendDirection = state.label == "Recovery" ? .improving :
                                        state.label == "Stressed" ? .declining : .stable

            insights.append(Insight(
                metric: .heartRateVariability,
                title: Copy.Insights.currentState(state.label),
                summary: "You've been in a \"\(state.label)\" state for \(state.daysInState) day\(state.daysInState == 1 ? "" : "s"). " +
                         describeStateCharacteristics(state),
                recommendation: recommendationForState(state),
                severity: severity,
                trend: trend,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: 0,
                category: .mlState,
                context: InsightContext(
                    confidenceLevel: 0.7,
                    dataPointCount: cachedVectorCount
                )
            ))
        }

        // Tomorrow prediction insight
        if let prediction = tomorrowRiskPrediction, prediction.confidence >= 0.15 {
            let severity: Severity = prediction.probability > 0.6 ? .warning : .info
            let topRisk = prediction.topFactors.first { $0.isRiskFactor }
            let topProtective = prediction.topFactors.first { !$0.isRiskFactor }

            var summary = "Tomorrow risk: \(prediction.riskLevel) (\(Int(prediction.probability * 100))% probability)."
            if let risk = topRisk {
                summary += " Top risk factor: \(risk.metric.displayName) (\(risk.featureType.rawValue))."
            }
            if let protective = topProtective {
                summary += " Protective: \(protective.metric.displayName)."
            }

            insights.append(Insight(
                metric: topRisk?.metric ?? .heartRateVariability,
                title: Copy.Insights.tomorrowOutlook(prediction.riskLevel),
                summary: summary,
                recommendation: recommendationForPrediction(prediction),
                severity: severity,
                trend: prediction.probability > 0.5 ? .declining : .improving,
                currentValue: prediction.probability,
                baselineValue: 0.3,
                deviationPercent: (prediction.probability - 0.3) / 0.3 * 100,
                category: .mlPrediction,
                context: InsightContext(
                    confidenceLevel: prediction.confidence,
                    dataPointCount: cachedVectorCount
                )
            ))
        }

        // Predictive health signal insights
        if let report = healthSignalReport {
            insights.append(contentsOf: PredictiveHealthSignals.generateInsights(from: report))
        }

        // Circadian insights
        if circadianAnalyzer.isReady {
            insights.append(contentsOf: circadianAnalyzer.generateInsights())
        }

        // Compound insights (crown jewel. cross-component synthesis)
        if compoundInsightEngine.isReady {
            insights.append(contentsOf: compoundInsightEngine.toInsights())
        }

        // Interaction effect insights (dose-response, sweet spots, conditional effects)
        for effect in interactionEffects.prefix(3) {
            insights.append(Insight(
                metric: effect.cause,
                title: "\(effect.cause.displayName) → \(effect.effect.displayName) \(effect.effectType.rawValue.replacingOccurrences(of: "conditionalPositive", with: "Conditional Effect").replacingOccurrences(of: "conditionalNegative", with: "Conditional Effect").replacingOccurrences(of: "doseResponse", with: "Dose-Response").replacingOccurrences(of: "invertedU", with: "Sweet Spot").replacingOccurrences(of: "uShape", with: "U-Shape").replacingOccurrences(of: "moderation", with: "Moderation").replacingOccurrences(of: "saturation", with: "Saturation").replacingOccurrences(of: "threshold", with: "Threshold"))",
                summary: effect.description,
                recommendation: effect.condition ?? "Monitor this interaction to optimize your \(effect.effect.displayName.lowercased()).",
                severity: effect.strength > 0.5 ? .warning : .info,
                trend: .stable,
                currentValue: effect.strength,
                baselineValue: 0,
                deviationPercent: effect.strength * 100,
                category: .causalChain,
                relatedMetrics: [effect.effect],
                context: InsightContext(
                    confidenceLevel: effect.confidence,
                    dataPointCount: effect.sampleCount
                )
            ))
        }

        // Temporal sequence insights (precursor warnings, compounding effects)
        for precursor in precursorPatterns where precursor.isCurrentlyTriggered {
            insights.append(Insight(
                metric: precursor.warningSignals.first?.metric ?? .heartRateVariability,
                title: Copy.Insights.activeWarning(precursor.predictedEvent),
                summary: precursor.description,
                recommendation: "This pattern has been \(Int(precursor.historicalAccuracy * 100))% accurate in your history. Take preventive action now.",
                severity: precursor.historicalAccuracy > 0.7 ? .critical : .warning,
                trend: .declining,
                currentValue: precursor.historicalAccuracy,
                baselineValue: 0.5,
                deviationPercent: (precursor.historicalAccuracy - 0.5) * 200,
                category: .mlPrediction,
                context: InsightContext(
                    confidenceLevel: precursor.historicalAccuracy,
                    dataPointCount: precursor.occurrenceCount
                )
            ))
        }

        for seq in temporalSequences.prefix(2) where seq.isCurrentlyActive {
            insights.append(Insight(
                metric: seq.steps.first?.metric ?? .heartRateVariability,
                title: Copy.Insights.sequenceInProgress,
                summary: seq.description + (seq.predictedOutcome.map { " Predicted: \($0)" } ?? ""),
                recommendation: "Based on \(seq.totalOccurrences) past occurrences, this sequence typically leads to the predicted outcome.",
                severity: .warning,
                trend: .declining,
                currentValue: seq.avgConsequenceMagnitude,
                baselineValue: 0,
                deviationPercent: seq.avgConsequenceMagnitude * 100,
                category: .causalChain,
                context: InsightContext(
                    confidenceLevel: seq.confidence,
                    dataPointCount: seq.totalOccurrences
                )
            ))
        }

        // Changepoint insights (regime shifts)
        for cp in changePoints.prefix(3) where cp.daysSinceChange <= 30 {
            let verb = cp.direction == .increase ? "increased" : "decreased"
            insights.append(Insight(
                metric: cp.metric,
                title: "\(cp.metric.displayName) Baseline Shift",
                summary: cp.description,
                recommendation: cp.coOccurringChanges.isEmpty
                    ? "Your \(cp.metric.displayName.lowercased()) \(verb) \(cp.daysSinceChange) days ago. Monitor whether this new level holds."
                    : "This shift coincided with changes in \(cp.coOccurringChanges.map { $0.metric.displayName }.joined(separator: ", ")).",
                severity: cp.magnitude > 1.0 ? .warning : .info,
                trend: cp.direction == .increase ? .improving : .declining,
                currentValue: cp.afterMean,
                baselineValue: cp.beforeMean,
                deviationPercent: cp.beforeMean != 0 ? (cp.afterMean - cp.beforeMean) / cp.beforeMean * 100 : 0,
                category: .baselineDrift,
                context: InsightContext(
                    confidenceLevel: cp.confidence,
                    dataPointCount: cp.daysSinceChange
                )
            ))
        }

        // Personal optimization insights
        if let profile = optimalProfile, profile.matchPercentage < 0.7 {
            let unmet = profile.conditions.filter { !$0.isCurrentlyMet }.prefix(3)
            let gaps = unmet.map { $0.description }.joined(separator: ". ")
            insights.append(Insight(
                metric: unmet.first?.metric ?? .heartRateVariability,
                title: Copy.Insights.optimizationGap(Int((1.0 - profile.matchPercentage) * 100)),
                summary: "You're matching \(Int(profile.matchPercentage * 100))% of your optimal profile (avg score \(Int(profile.avgScoreWhenOptimal)) vs \(Int(profile.avgScoreWhenNot)) when not). \(gaps)",
                recommendation: unmet.first?.description ?? "Focus on the top gaps to reach your optimal state.",
                severity: profile.matchPercentage < 0.4 ? .warning : .info,
                trend: .stable,
                currentValue: profile.matchPercentage,
                baselineValue: 1.0,
                deviationPercent: (1.0 - profile.matchPercentage) * 100,
                category: .correlation,
                context: InsightContext(
                    confidenceLevel: 0.8,
                    dataPointCount: cachedVectorCount
                )
            ))
        }

        if let ideal = idealDay {
            insights.append(Insight(
                metric: ideal.targets.first?.metric ?? .heartRateVariability,
                title: Copy.Insights.yourIdealDayBlueprint,
                summary: ideal.description,
                recommendation: ideal.targets.prefix(3).map { $0.description }.joined(separator: " "),
                severity: .info,
                trend: .stable,
                currentValue: ideal.predictedScore,
                baselineValue: 0,
                deviationPercent: 0,
                category: .correlation,
                context: InsightContext(
                    confidenceLevel: ideal.confidence,
                    dataPointCount: cachedVectorCount
                )
            ))
        }

        // ML correlation insights (novel discoveries not in the hardcoded 35)
        for corr in mlCorrelations.prefix(3) where corr.grangerCausal {
            let effectLabel: String
            if corr.grangerEffectSize > 0.35 { effectLabel = "strong" }
            else if corr.grangerEffectSize > 0.15 { effectLabel = "moderate" }
            else { effectLabel = "measurable" }

            let lagNote = corr.grangerOptimalLag > 0
                ? " with a \(corr.grangerOptimalLag)-day lag" : ""
            let direction = corr.pearsonR > 0 ? "positively" : "inversely"

            insights.append(Insight(
                metric: corr.metricA,
                title: "\(corr.metricA.displayName) Drives \(corr.metricB.displayName)",
                summary: "Your \(corr.metricA.displayName.lowercased()) \(direction) influences your \(corr.metricB.displayName.lowercased())\(lagNote)"
                    + " (\(effectLabel) effect, r=\(String(format: "%.2f", corr.pearsonR)), \(corr.sampleCount) days of data,"
                    + " \(Int(corr.stability * 100))% stability).",
                recommendation: corr.grangerOptimalLag > 0
                    ? "Changes in \(corr.metricA.displayName.lowercased()) predict \(corr.metricB.displayName.lowercased()) changes \(corr.grangerOptimalLag) day\(corr.grangerOptimalLag == 1 ? "" : "s") later. Use this to plan ahead."
                    : "Improving your \(corr.metricA.displayName.lowercased()) should lead to better \(corr.metricB.displayName.lowercased()) outcomes.",
                severity: .info,
                trend: .stable,
                currentValue: corr.pearsonR,
                baselineValue: 0,
                deviationPercent: abs(corr.pearsonR) * 100,
                category: .correlation,
                relatedMetrics: [corr.metricB],
                context: InsightContext(
                    confidenceLevel: corr.stability,
                    dataPointCount: corr.sampleCount
                )
            ))
        }

        return insights
    }

    // MARK: - Private Helpers

    private func buildPolicyDecision(
        components: MLPipelineRunner.Components,
        mlCorrelations: [MLCorrelation],
        currentHealthState: HealthState?,
        tomorrowRiskPrediction: MLPrediction?,
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        ruleBasedAnomalies: [AnomalyDetector.AnomalyResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        vectors: [DailyFeatureVector],
        focusCategories: Set<HealthCategory>,
        timingRecommendations: [CircadianAnalyzer.TimingRecommendation]
    ) -> PolicyDecision? {
        let causalCorrelations = mlCorrelations.filter { $0.grangerCausal }
        let candidates = components.decisionPolicyEngine.generateCandidates(
            currentState: currentHealthState,
            tomorrowRisk: tomorrowRiskPrediction,
            causalDiscoveries: causalCorrelations,
            trends: trends,
            baselines: baselines,
            anomalies: ruleBasedAnomalies,
            circadianRecommendations: timingRecommendations,
            timeSeries: timeSeries
        )

        guard !candidates.isEmpty else { return nil }

        var enrichedCandidates = candidates
        if components.predictiveScorer.isReady, let todayVector = vectors.last {
            enrichedCandidates = candidates.map { candidate in
                let delta = components.decisionPolicyEngine.estimateCounterfactual(
                    action: candidate,
                    currentVector: todayVector,
                    scorer: components.predictiveScorer
                )
                if let delta = delta, abs(delta) > 0.01 {
                    let boosted = candidate
                    return boosted
                }
                return candidate
            }
        }

        guard let decision = components.decisionPolicyEngine.decide(candidates: enrichedCandidates, focusCategories: focusCategories) else {
            return nil
        }

        let primaryLang = components.decisionPolicyEngine.generateLanguage(
            for: decision.primaryAction.candidate,
            baselines: baselines, trends: trends, timeSeries: timeSeries
        )
        let primaryWithLang = PolicyDecision.RankedIntervention(
            candidate: decision.primaryAction.candidate,
            expectedUtility: decision.primaryAction.expectedUtility,
            noveltyFactor: decision.primaryAction.noveltyFactor,
            description: primaryLang.description,
            whyItMatters: primaryLang.whyMatters, expectedBenefit: primaryLang.expectedBenefit
        )

        var secondaryWithLang: PolicyDecision.RankedIntervention?
        if let sec = decision.secondaryAction {
            let secLang = components.decisionPolicyEngine.generateLanguage(
                for: sec.candidate,
                baselines: baselines, trends: trends, timeSeries: timeSeries
            )
            secondaryWithLang = PolicyDecision.RankedIntervention(
                candidate: sec.candidate,
                expectedUtility: sec.expectedUtility, noveltyFactor: sec.noveltyFactor,
                description: secLang.description,
                whyItMatters: secLang.whyMatters, expectedBenefit: secLang.expectedBenefit
            )
        }

        let allWithLang = decision.allCandidates.map { ranked in
            let lang = components.decisionPolicyEngine.generateLanguage(
                for: ranked.candidate,
                baselines: baselines, trends: trends, timeSeries: timeSeries
            )
            return PolicyDecision.RankedIntervention(
                candidate: ranked.candidate,
                expectedUtility: ranked.expectedUtility, noveltyFactor: ranked.noveltyFactor,
                description: lang.description,
                whyItMatters: lang.whyMatters, expectedBenefit: lang.expectedBenefit
            )
        }

        let headline = components.decisionPolicyEngine.generatePrescriptiveHeadline(
            primaryCandidate: decision.primaryAction.candidate,
            baselines: baselines,
            timeSeries: timeSeries
        )
        let sleepTime = components.decisionPolicyEngine.computeTargetSleepTime(
            baselines: baselines, timeSeries: timeSeries
        )
        let strainBudget = components.decisionPolicyEngine.computeStrainBudget(
            baselines: baselines, timeSeries: timeSeries
        )

        return PolicyDecision(
            primaryAction: primaryWithLang,
            secondaryAction: secondaryWithLang,
            allCandidates: allWithLang,
            rationale: decision.rationale,
            decisionConfidence: decision.decisionConfidence,
            decidedAt: decision.decidedAt,
            prescriptiveHeadline: headline,
            targetSleepTime: sleepTime,
            strainBudget: strainBudget
        )
    }

    private func buildAvailableDataForColdStart(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [HealthMetric: [Double]] {
        var result: [HealthMetric: [Double]] = [:]
        for (metric, series) in timeSeries {
            let values = series.sortedSamples.map(\.value)
            if !values.isEmpty {
                result[metric] = values
            }
        }
        return result
    }

    // MARK: - Recommendation Helpers

    func recommendationForPattern(_ pattern: DiscoveredPattern) -> String {
        switch pattern.patternType {
        case .weekly:
            if let peak = pattern.peakDayName, let trough = pattern.troughDayName {
                var rec = "Your \(pattern.metric.displayName) peaks on \(peak)s and dips on \(trough)s."
                    + " Schedule demanding activities on \(peak)s and recovery on \(trough)s."
                if let peakVal = pattern.peakMeanValue, let troughVal = pattern.troughMeanValue {
                    let diff = pattern.metric.formatValue(abs(peakVal - troughVal))
                    rec += " The swing is ~\(diff) \(pattern.metric.unit) between best and worst days."
                }
                return rec
            }
            return "Your \(pattern.metric.displayName) follows a weekly rhythm. Plan demanding activities on your peak days and recovery on your low days."
        case .biweekly:
            return "Your \(pattern.metric.displayName) shows a 2-week cycle (strength: \(Int(pattern.strength * 100))%). Consider a deload every 2 weeks to align with your body's natural load-recovery rhythm."
        case .monthly:
            return "Your \(pattern.metric.displayName) follows a ~\(Int(pattern.periodDays))-day cycle (strength: \(Int(pattern.strength * 100))%). Track what changes around the cycle peak and trough. this may relate to hormonal or lifestyle rhythms."
        case .seasonal:
            return "Your \(pattern.metric.displayName) shows seasonal variation (strength: \(Int(pattern.strength * 100))%). Adjust your targets based on the time of year rather than holding to a fixed standard."
        case .custom:
            return "Your \(pattern.metric.displayName) has a unique \(Int(pattern.periodDays))-day cycle (strength: \(Int(pattern.strength * 100))%). Observe what activities or habits align with this rhythm."
        }
    }

    func describeStateCharacteristics(_ state: HealthState) -> String {
        let notable = state.characteristics.filter { $0.level != .normal }
        guard !notable.isEmpty else { return "All metrics within normal range." }

        let descriptions = notable.prefix(3).map { char in
            let severity = abs(char.zScore) > 2 ? "significantly " : abs(char.zScore) > 1 ? "" : "slightly "
            return "\(severity)\(char.level.rawValue) \(char.metric.displayName) (\(String(format: "%.1f", abs(char.zScore)))σ)"
        }
        return "Characterized by: " + descriptions.joined(separator: ", ") + "."
    }

    func recommendationForState(_ state: HealthState) -> String {
        let daysNote = state.daysInState > 1 ? " (day \(state.daysInState) in this state)" : ""
        let characteristics = state.characteristics.filter { $0.level != .normal }
        let charNote: String
        if let top = characteristics.first {
            charNote = " Key signal: \(top.level.rawValue) \(top.metric.displayName.lowercased())"
                + " (\(String(format: "%.1f", abs(top.zScore)))σ from normal)."
        } else {
            charNote = ""
        }

        let transitionNote: String
        if let bestTransition = state.transitionProbabilities
            .filter({ $0.key != state.label })
            .max(by: { $0.value < $1.value }),
           bestTransition.value > 0.15 {
            transitionNote = " Historically, you transition to \"\(bestTransition.key)\" \(Int(bestTransition.value * 100))% of the time from here."
        } else {
            transitionNote = ""
        }

        switch state.label {
        case "Recovery":
            return "You're in recovery\(daysNote). This is a good time for light activity and building habits.\(charNote)\(transitionNote)"
        case "Peak Performance":
            return "You're performing well\(daysNote). Take advantage for challenging workouts or demanding days.\(charNote)\(transitionNote)"
        case "Stressed":
            return "Your body shows signs of stress\(daysNote). Prioritize sleep, reduce intensity.\(charNote)\(transitionNote)"
        case "Under-Slept":
            return "Sleep deficit detected\(daysNote). Aim for an extra 30-60 min tonight and avoid intense exercise.\(charNote)\(transitionNote)"
        case "Active":
            return "High activity level\(daysNote). Ensure adequate recovery between sessions.\(charNote)\(transitionNote)"
        case "Fatigued":
            return "Fatigue signals detected\(daysNote). Consider a rest day or low-intensity active recovery.\(charNote)\(transitionNote)"
        default:
            if !characteristics.isEmpty {
                let topMetrics = characteristics.prefix(2).map { "\($0.level.rawValue) \($0.metric.displayName.lowercased())" }
                return "Current state\(daysNote): \(topMetrics.joined(separator: ", ")).\(transitionNote)"
            }
            return "Monitor how you feel and adjust your activity level based on your energy.\(daysNote)"
        }
    }

    func recommendationForPrediction(_ prediction: MLPrediction) -> String {
        let riskFactors = prediction.topFactors.filter { $0.isRiskFactor }
        let protectiveFactors = prediction.topFactors.filter { !$0.isRiskFactor }

        if prediction.probability > 0.6 {
            let topRisk = riskFactors.prefix(2)
            let factors = topRisk.map { factor -> String in
                switch factor.featureType {
                case .roc: return "\(factor.metric.displayName) (declining)"
                case .vol7: return "\(factor.metric.displayName) (volatile)"
                case .devBaseline: return "\(factor.metric.displayName) (off baseline)"
                default: return factor.metric.displayName
                }
            }.joined(separator: " and ")
            let pct = Int(prediction.probability * 100)
            return "Higher risk predicted (\(pct)%). Top drivers: \(factors.isEmpty ? "multiple factors" : factors). Focus on these today to reduce tomorrow's risk."
        } else if prediction.probability > 0.4 {
            let topRisk = riskFactors.first
            let topProtective = protectiveFactors.first
            var rec = "Moderate risk (\(Int(prediction.probability * 100))%)."
            if let risk = topRisk {
                rec += " Watch your \(risk.metric.displayName.lowercased())."
            }
            if let protective = topProtective {
                rec += " Your \(protective.metric.displayName.lowercased()) is helping. keep it up."
            }
            rec += " Prioritize consistent sleep tonight."
            return rec
        } else {
            let pct = Int(prediction.probability * 100)
            if let protective = protectiveFactors.first {
                return "Low risk (\(pct)%). Your \(protective.metric.displayName.lowercased()) is a key protective factor. You're on track for a good day tomorrow."
            }
            return "Low risk predicted (\(pct)%). You're on track for a good day tomorrow."
        }
    }
}
