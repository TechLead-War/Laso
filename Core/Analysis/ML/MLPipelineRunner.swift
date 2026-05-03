import Foundation
import os

final class MLPipelineRunner {

    private let logger = Logger(subsystem: "com.healthpulse.ml", category: "MLPipelineRunner")

    struct PipelineInput {
        let timeSeries: [HealthMetric: MetricTimeSeries]
        let baselines: [HealthMetric: UserBaseline]
        let trends: [HealthMetric: TrendAnalyzer.TrendResult]
        let ruleBasedAnomalies: [AnomalyDetector.AnomalyResult]
        let scoreHistory: [(date: Date, score: Int)]
        let anomalyCounts: [Date: Int]
        let focusCategories: Set<HealthCategory>
    }

    struct PipelineOutput {
        var componentsRunCount: Int = 0
        var vectors: [DailyFeatureVector] = []
        var smoothedStates: [SmoothedHealthState] = []
        var multiHorizonForecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast] = [:]
        var multivariateResults: [MultivariateRegressionResult] = []
        var healthSignalReport: PredictiveHealthSignals.HealthSignalReport?
        var dataSufficiency: UncertaintyEstimator.DataSufficiency?
        var componentReadiness: [UncertaintyEstimator.ComponentReadiness] = []
        var personalizationStatus: PersonalizationBlender.PersonalizationStatus?
        var interactionEffects: [InteractionEffectEngine.InteractionEffect] = []
        var doseResponseCurves: [InteractionEffectEngine.DoseResponseCurve] = []
        var temporalSequences: [TemporalSequenceMiner.TemporalSequence] = []
        var precursorPatterns: [TemporalSequenceMiner.PrecursorPattern] = []
        var compoundingEffects: [TemporalSequenceMiner.CompoundingEffect] = []
        var changePoints: [ChangePointDetector.ChangePoint] = []
        var regimeComparisons: [ChangePointDetector.RegimeComparison] = []
        var optimalProfile: PersonalOptimizer.OptimalProfile?
        var idealDay: PersonalOptimizer.IdealDay?
        var scoreSensitivities: [PersonalOptimizer.SensitivityResult] = []
        var driftAlerts: [DriftReport] = []
        var evaluationSummaries: [String: ComponentEvaluation] = [:]
        var stoppedEarly: Bool = false
    }

    struct Components {
        let featureEngine: FeatureEngine
        let forecaster: TimeSeriesForecaster
        let anomalyDetector: AdaptiveAnomalyDetector
        let patternMiner: PatternMiner
        let correlationDiscovery: CorrelationDiscovery
        let stateClassifier: HealthStateClassifier
        let predictiveScorer: PredictiveScorer
        let interactionEngine: InteractionEffectEngine
        let temporalMiner: TemporalSequenceMiner
        let changePointDetector: ChangePointDetector
        let personalOptimizer: PersonalOptimizer
        let compoundInsightEngine: CompoundInsightEngine
        let mlEvaluator: MLEvaluator
        let conformalCalibrator: ConformalCalibrator
        let decisionPolicyEngine: DecisionPolicyEngine
    }

    func run(
        input: PipelineInput,
        components: Components,
        needsFullRetrain: Bool,
        cachedVectorsSetter: @escaping @Sendable ([DailyFeatureVector]) -> Void
    ) async -> PipelineOutput? {
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical || thermalState == .serious {
            logger.warning("Skipping ML analysis: device thermal state is \(thermalState == .critical ? "critical" : "serious")")
            return nil
        }

        // Explicitly run heavy ML computation at background priority to target E-cores,
        // reducing thermal impact even when caller is at higher QoS (e.g., calibration path).
        return await Task.detached(priority: .background) { [self] in
        var output = PipelineOutput()

        // Step 0: Build feature vectors (required by most components)
        let vectors = components.featureEngine.buildFeatureVectors(
            timeSeries: input.timeSeries,
            baselines: input.baselines
        )
        cachedVectorsSetter(vectors)
        output.vectors = vectors
        let orderedKeys = components.featureEngine.orderedKeys

        guard !vectors.isEmpty else { return output }

        let totalDays = vectors.count

        // Assess data sufficiency and component readiness upfront
        let requiredMetrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration,
            .steps, .activeCalories, .exerciseMinutes
        ]
        output.dataSufficiency = UncertaintyEstimator.assessDataSufficiency(
            timeSeries: input.timeSeries,
            requiredMetrics: requiredMetrics
        )
        output.componentReadiness = UncertaintyEstimator.checkComponentReadiness(totalDays: totalDays)

        // Personalization status
        output.personalizationStatus = PersonalizationBlender.personalizationStatus(
            userDataDays: totalDays,
            metricsTracked: input.timeSeries.count
        )

        if await shouldStopForThermal(after: "FeatureEngine") { output.stoppedEarly = true; return output }

        let thermal = ThermalManager.shared

        // --- 1. TimeSeriesForecaster (7+ days) ---
        if totalDays >= TimeSeriesForecaster.minimumDays {
            if components.forecaster.needsRetrain || !components.forecaster.isReady {
                logger.debug("Running TimeSeriesForecaster")
                components.forecaster.fit(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "TimeSeriesForecaster") { output.stoppedEarly = true; return output }

        // --- 2. PredictiveScorer (14+ days) ---
        if totalDays >= PredictiveScorer.minimumDays {
            if !components.predictiveScorer.isReady || needsFullRetrain {
                logger.debug("Running PredictiveScorer")
                components.predictiveScorer.train(
                    vectors: vectors,
                    orderedKeys: orderedKeys,
                    scoreHistory: input.scoreHistory,
                    anomalyCounts: input.anomalyCounts
                )
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "PredictiveScorer") { output.stoppedEarly = true; return output }

        // --- 3. CorrelationDiscovery (7+ days, tier 1) ---
        if thermal.shouldRunComponent(tier: 1), totalDays >= CorrelationDiscovery.minimumDays {
            if components.correlationDiscovery.needsRetrain || !components.correlationDiscovery.isReady {
                logger.debug("Running CorrelationDiscovery")
                components.correlationDiscovery.discover(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "CorrelationDiscovery") { output.stoppedEarly = true; return output }

        // --- 4. HealthStateClassifier (14+ days, tier 1) ---
        if thermal.shouldRunComponent(tier: 1), totalDays >= HealthStateClassifier.minimumDays {
            if components.stateClassifier.needsRetrain || !components.stateClassifier.isReady {
                logger.debug("Running HealthStateClassifier")
                components.stateClassifier.train(vectors: vectors, orderedKeys: orderedKeys)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "HealthStateClassifier") { output.stoppedEarly = true; return output }

        // --- 5. PatternMiner (14+ days, tier 1) ---
        if thermal.shouldRunComponent(tier: 1), totalDays >= PatternMiner.minimumDays {
            if !components.patternMiner.isReady || needsFullRetrain {
                logger.debug("Running PatternMiner")
                components.patternMiner.mine(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "PatternMiner") { output.stoppedEarly = true; return output }

        // --- 6. AdaptiveAnomalyDetector (14+ days, tier 1) ---
        if thermal.shouldRunComponent(tier: 1), totalDays >= AdaptiveAnomalyDetector.minimumDays {
            if components.anomalyDetector.needsRetrain || !components.anomalyDetector.isReady {
                logger.debug("Running AdaptiveAnomalyDetector")
                components.anomalyDetector.train(vectors: vectors, orderedKeys: orderedKeys, baselines: input.baselines)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "AdaptiveAnomalyDetector") { output.stoppedEarly = true; return output }

        // --- 6a. HMM Smoothed States (after classifier trains) ---
        if components.stateClassifier.isReady {
            let dates = vectors.map(\.date)
            output.smoothedStates = components.stateClassifier.smoothedStateHistory(vectors: vectors, dates: dates)
        }

        // --- 6b. Multi-horizon forecasting (after forecaster trains) ---
        if components.forecaster.isReady {
            let forecasterVersion = ModelVersion(
                componentName: "TimeSeriesForecaster",
                modelVersion: 2, featureSchemaVersion: 1, calibrationVersion: 1,
                trainedAt: Date(), dataPointsUsed: totalDays
            )
            var forecastIdx = 0
            for (metric, _) in input.timeSeries {
                forecastIdx += 1
                if forecastIdx % 10 == 0 { await Task.yield() }
                if let forecast = components.forecaster.forecast(metric: metric, horizons: [1, 3, 7]) {
                    output.multiHorizonForecasts[metric] = forecast

                    if let oneDay = forecast.horizons.first(where: { $0.horizon == 1 }) {
                        _ = components.mlEvaluator.recordPrediction(
                            componentName: "TimeSeriesForecaster",
                            modelVersion: forecasterVersion,
                            horizon: .nextDay,
                            targetMetric: metric.rawValue,
                            predictedValue: oneDay.value,
                            confidence: 0.7,
                            intervalLower: oneDay.ciLower,
                            intervalUpper: oneDay.ciUpper
                        )
                    }
                }
            }
        }

        // --- 6c. Multivariate Granger skipped — multivariateResults stored on MLOrchestrator
        // but never read by any ViewModel, View, or downstream system. Removing this
        // eliminates O(N³) OLS regression per target metric of wasted CPU.

        if await shouldStopForThermal(after: "PipelineStep6") { output.stoppedEarly = true; return output }

        // --- 7. Predictive Health Signals (3+ days for fatigue, more for others) ---
        logger.debug("Running PredictiveHealthSignals")
        output.healthSignalReport = PredictiveHealthSignals.analyze(
            timeSeries: input.timeSeries,
            baselines: input.baselines,
            trends: input.trends,
            healthState: components.stateClassifier.isReady ? components.stateClassifier.currentState : nil,
            prediction: (components.predictiveScorer.isReady && vectors.last != nil) ? components.predictiveScorer.predict(todayVector: vectors[vectors.count - 1]) : nil
        )

        if await shouldStopForThermal(after: "PredictiveHealthSignals") { output.stoppedEarly = true; return output }

        // --- 8. Evaluation: auto-resolve expired prediction events ---
        logger.debug("Resolving evaluation events")
        let scoreMap: [(date: Date, score: Double)] = input.scoreHistory.map { (date: $0.date, score: Double($0.score)) }
        components.mlEvaluator.resolveExpiredEvents(timeSeries: input.timeSeries, scores: scoreMap)

        // Drift detection skipped — driftAlerts stored on MLOrchestrator but never read
        // by any ViewModel, View, or notification system. Welch's t-test runs for nothing.

        for component in ["PredictiveScorer", "TimeSeriesForecaster", "HealthStateClassifier"] {
            if let eval = components.mlEvaluator.evaluateComponent(name: component, horizon: .nextDay) {
                output.evaluationSummaries[component] = eval
            }
        }

        // --- Tier 2 (Exploratory): Skipped under thermal pressure (.fair skips these) ---

        // --- 9. InteractionEffectEngine (14+ days, tier 2) ---
        if thermal.shouldRunComponent(tier: 2), totalDays >= InteractionEffectEngine.minimumDays {
            logger.debug("Running InteractionEffectEngine")
            output.interactionEffects = components.interactionEngine.discover(timeSeries: input.timeSeries, baselines: input.baselines)
            output.doseResponseCurves = components.interactionEngine.doseResponseCurves
        }

        if await shouldStopForThermal(after: "InteractionEffectEngine") { output.stoppedEarly = true; return output }

        // --- 10. TemporalSequenceMiner (14+ days, tier 2) ---
        if thermal.shouldRunComponent(tier: 2), totalDays >= TemporalSequenceMiner.minimumDays {
            logger.debug("Running TemporalSequenceMiner")
            components.temporalMiner.mine(
                timeSeries: input.timeSeries,
                baselines: input.baselines,
                stateHistory: output.smoothedStates
            )
            output.temporalSequences = components.temporalMiner.sequences
            output.precursorPatterns = components.temporalMiner.precursorPatterns
            output.compoundingEffects = components.temporalMiner.compoundingEffects
        }

        if await shouldStopForThermal(after: "TemporalSequenceMiner") { output.stoppedEarly = true; return output }

        // --- 11. ChangePointDetector (14+ days, tier 2) ---
        if thermal.shouldRunComponent(tier: 2), totalDays >= ChangePointDetector.minimumDays {
            logger.debug("Running ChangePointDetector")
            components.changePointDetector.detect(timeSeries: input.timeSeries, baselines: input.baselines)
            output.changePoints = components.changePointDetector.changePoints
            output.regimeComparisons = components.changePointDetector.regimeComparisons
        }

        if await shouldStopForThermal(after: "ChangePointDetector") { output.stoppedEarly = true; return output }

        // --- 12. PersonalOptimizer (7+ days, tier 2) ---
        if thermal.shouldRunComponent(tier: 2), totalDays >= PersonalOptimizer.minimumDays && !input.scoreHistory.isEmpty {
            logger.debug("Running PersonalOptimizer")
            components.personalOptimizer.analyze(
                timeSeries: input.timeSeries,
                baselines: input.baselines,
                scoreHistory: input.scoreHistory,
                vectors: vectors
            )
            output.optimalProfile = components.personalOptimizer.optimalProfile
            output.idealDay = components.personalOptimizer.idealDay
            output.scoreSensitivities = components.personalOptimizer.sensitivities
        }

        if await shouldStopForThermal(after: "PersonalOptimizer") { output.stoppedEarly = true; return output }

        return output
        }.value
    }

    func shouldStopForThermal(after component: String) async -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        if state == .critical || state == .serious {
            logger.warning("Stopping ML pipeline after \(component): thermal state \(state == .critical ? "critical" : "serious"), returning partial results")
            return true
        }
        if state == .fair {
            // Yield to let system cool slightly between components
            try? await Task.sleep(for: .milliseconds(100))
        }
        await Task.yield()
        return false
    }

    func trainIncremental(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        todayScore: Int,
        todayAnomalyCount: Int,
        components: Components,
        cachedVectors: [DailyFeatureVector]
    ) {
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                components.featureEngine.updateIncremental(metric: metric, newValue: latest.value)
            }
        }

        let calendar = Date.cal
        let weekday = calendar.component(.weekday, from: Date())
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                components.forecaster.update(metric: metric, newValue: latest.value, dayOfWeek: weekday)
            }
        }

        if let todayVector = cachedVectors.last {
            let wasBadDay = components.predictiveScorer.determineBadDay(
                todayScore: todayScore,
                tomorrowScore: nil,
                anomalyCount: todayAnomalyCount
            )
            components.predictiveScorer.trainIncremental(
                todayVector: todayVector,
                wasBadDay: wasBadDay
            )
        }
    }

    static func runMultivariateGranger(
        timeSeries: [HealthMetric: MetricTimeSeries],
        correlations: [MLCorrelation]
    ) -> [MultivariateRegressionResult] {
        var results: [MultivariateRegressionResult] = []
        let significantCorrelations = correlations.filter { $0.grangerCausal && $0.grangerPValue < 0.1 }

        var candidatesByTarget: [HealthMetric: [HealthMetric]] = [:]
        for corr in significantCorrelations {
            candidatesByTarget[corr.metricB, default: []].append(corr.metricA)
        }

        var seriesValues: [HealthMetric: [Double]] = [:]
        for (metric, series) in timeSeries {
            seriesValues[metric] = series.sortedSamples.map(\.value)
        }

        for (target, predictors) in candidatesByTarget where predictors.count >= 3 {
            if let result = GrangerCausalityEngine.multivariateGrangerTest(
                target: target,
                predictors: Array(Set(predictors).prefix(8)),
                timeSeries: seriesValues,
                maxLag: 3
            ) {
                results.append(result)
            }
        }

        return results
    }
}
