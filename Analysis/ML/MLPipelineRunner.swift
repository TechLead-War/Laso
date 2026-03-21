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
        var enrichedVectors: [EnrichedDailyFeatureVector] = []
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
        cachedVectorsSetter: ([DailyFeatureVector]) -> Void
    ) async -> PipelineOutput? {
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical {
            logger.warning("Skipping ML analysis: device thermal state is critical")
            return nil
        }
        if thermalState == .serious {
            logger.info("ML analysis starting under serious thermal state. will throttle between components")
        }

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

        // Step 0a: Enrich feature vectors with composite features
        logger.debug("Building composite features")
        output.enrichedVectors = CompositeFeatureEngine.enrich(
            vectors: vectors,
            timeSeries: input.timeSeries,
            baselines: input.baselines
        )

        if await shouldStopForThermal(after: "CompositeFeatureEngine") { output.stoppedEarly = true; return output }

        // --- 1. TimeSeriesForecaster (21+ days) ---
        if totalDays >= TimeSeriesForecaster.minimumDays {
            if components.forecaster.needsRetrain || !components.forecaster.isReady {
                logger.debug("Running TimeSeriesForecaster")
                components.forecaster.fit(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "TimeSeriesForecaster") { output.stoppedEarly = true; return output }

        // --- 2. PredictiveScorer (30+ days) ---
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

        // --- 3. CorrelationDiscovery (30+ days) ---
        if totalDays >= CorrelationDiscovery.minimumDays {
            if components.correlationDiscovery.needsRetrain || !components.correlationDiscovery.isReady {
                logger.debug("Running CorrelationDiscovery")
                components.correlationDiscovery.discover(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "CorrelationDiscovery") { output.stoppedEarly = true; return output }

        // --- 4. HealthStateClassifier (60+ days) ---
        if totalDays >= HealthStateClassifier.minimumDays {
            if components.stateClassifier.needsRetrain || !components.stateClassifier.isReady {
                logger.debug("Running HealthStateClassifier")
                components.stateClassifier.train(vectors: vectors, orderedKeys: orderedKeys)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "HealthStateClassifier") { output.stoppedEarly = true; return output }

        // --- 5. PatternMiner (60+ days) ---
        if totalDays >= PatternMiner.minimumDays {
            if !components.patternMiner.isReady || needsFullRetrain {
                logger.debug("Running PatternMiner")
                components.patternMiner.mine(timeSeries: input.timeSeries)
                output.componentsRunCount += 1
            }
        }

        if await shouldStopForThermal(after: "PatternMiner") { output.stoppedEarly = true; return output }

        // --- 6. AdaptiveAnomalyDetector (60+ days) ---
        if totalDays >= AdaptiveAnomalyDetector.minimumDays {
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

        // --- 6c. Multivariate Granger (after pairwise correlations, 45+ days) ---
        if totalDays >= 45 && components.correlationDiscovery.isReady {
            logger.debug("Running multivariate Granger")
            output.multivariateResults = Self.runMultivariateGranger(
                timeSeries: input.timeSeries,
                correlations: components.correlationDiscovery.correlations
            )
        }

        if await shouldStopForThermal(after: "MultivariateGranger") { output.stoppedEarly = true; return output }

        // --- 7. Predictive Health Signals (7+ days for fatigue, more for others) ---
        logger.debug("Running PredictiveHealthSignals")
        output.healthSignalReport = PredictiveHealthSignals.analyze(
            timeSeries: input.timeSeries,
            baselines: input.baselines,
            trends: input.trends,
            healthState: components.stateClassifier.isReady ? components.stateClassifier.currentState : nil,
            prediction: components.predictiveScorer.isReady ? components.predictiveScorer.predict(todayVector: vectors.last!) : nil
        )

        if await shouldStopForThermal(after: "PredictiveHealthSignals") { output.stoppedEarly = true; return output }

        // --- 8. Evaluation: auto-resolve expired prediction events ---
        logger.debug("Resolving evaluation events")
        let scoreMap: [(date: Date, score: Double)] = input.scoreHistory.map { (date: $0.date, score: Double($0.score)) }
        components.mlEvaluator.resolveExpiredEvents(timeSeries: input.timeSeries, scores: scoreMap)

        output.driftAlerts = []
        for component in ["PredictiveScorer", "TimeSeriesForecaster"] {
            if let drift = components.mlEvaluator.detectModelDrift(componentName: component),
               drift.isDrifting {
                output.driftAlerts.append(drift)
                logger.warning("Model drift detected in \(component): \(drift.recommendation)")
            }
        }

        for component in ["PredictiveScorer", "TimeSeriesForecaster", "HealthStateClassifier"] {
            if let eval = components.mlEvaluator.evaluateComponent(name: component, horizon: .nextDay) {
                output.evaluationSummaries[component] = eval
            }
        }

        // --- 9. InteractionEffectEngine (45+ days) ---
        if totalDays >= InteractionEffectEngine.minimumDays {
            logger.debug("Running InteractionEffectEngine")
            output.interactionEffects = components.interactionEngine.discover(timeSeries: input.timeSeries, baselines: input.baselines)
            output.doseResponseCurves = components.interactionEngine.doseResponseCurves
        }

        if await shouldStopForThermal(after: "InteractionEffectEngine") { output.stoppedEarly = true; return output }

        // --- 10. TemporalSequenceMiner (30+ days) ---
        if totalDays >= TemporalSequenceMiner.minimumDays {
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

        // --- 11. ChangePointDetector (30+ days) ---
        if totalDays >= ChangePointDetector.minimumDays {
            logger.debug("Running ChangePointDetector")
            components.changePointDetector.detect(timeSeries: input.timeSeries, baselines: input.baselines)
            output.changePoints = components.changePointDetector.changePoints
            output.regimeComparisons = components.changePointDetector.regimeComparisons
        }

        if await shouldStopForThermal(after: "ChangePointDetector") { output.stoppedEarly = true; return output }

        // --- 12. PersonalOptimizer (21+ days, needs score history) ---
        if totalDays >= PersonalOptimizer.minimumDays && !input.scoreHistory.isEmpty {
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
    }

    func shouldStopForThermal(after component: String) async -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        if state == .critical {
            logger.warning("Stopping ML analysis after \(component): thermal state critical")
            return true
        }
        if state == .serious {
            logger.info("Thermal cooldown after \(component): state is serious, pausing 2s")
            try? await Task.sleep(for: .seconds(2))
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

        let calendar = Calendar.current
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
