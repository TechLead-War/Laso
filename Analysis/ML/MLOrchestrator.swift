import Foundation
import Observation
import os

/// Manages all ML component lifecycle, sequential execution, incremental training, and periodic retraining.
@Observable
final class MLOrchestrator {

    private let logger = Logger(subsystem: "com.healthpulse.ml", category: "MLOrchestrator")

    // MARK: - ML Components (Core)

    let featureEngine = FeatureEngine()
    let forecaster = TimeSeriesForecaster()
    let anomalyDetector = AdaptiveAnomalyDetector()
    let patternMiner = PatternMiner()
    let correlationDiscovery = CorrelationDiscovery()
    let stateClassifier = HealthStateClassifier()
    let predictiveScorer = PredictiveScorer()
    let adherenceTracker = AdherenceTracker()
    let circadianAnalyzer = CircadianAnalyzer()

    // MARK: - ML Components (New)

    let decisionPolicyEngine = DecisionPolicyEngine()
    let mlEvaluator = MLEvaluator()
    let conformalCalibrator = ConformalCalibrator()

    // MARK: - ML Components (Intelligence Layer)

    let interactionEngine = InteractionEffectEngine()
    let temporalMiner = TemporalSequenceMiner()
    let changePointDetector = ChangePointDetector()
    let personalOptimizer = PersonalOptimizer()
    let compoundInsightEngine = CompoundInsightEngine()

    // MARK: - State

    /// Whether ML analysis has been run at least once
    var hasRunOnce = false
    /// Whether ML is currently running
    var isRunning = false
    /// Last full retrain date
    var lastFullRetrain: Date?

    // MARK: - Results (for AnalysisEngine to consume)

    /// ML-powered anomalies (from forecaster + isolation forest)
    var mlAnomalies: [TimeSeriesForecaster.ForecastAnomaly] = []
    /// Adaptive anomaly results
    var adaptiveAnomalies: [AdaptiveAnomalyDetector.AdaptiveAnomaly] = []
    /// Discovered patterns
    var discoveredPatterns: [DiscoveredPattern] = []
    /// ML-discovered correlations
    var mlCorrelations: [MLCorrelation] = []
    /// Current health state
    var currentHealthState: HealthState?
    /// Tomorrow risk prediction
    var tomorrowRiskPrediction: MLPrediction?

    // MARK: - New ML Results

    /// Enriched feature vectors with composite features
    var enrichedVectors: [EnrichedDailyFeatureVector] = []
    /// Predictive health signal report (fatigue, burnout, overtraining, insomnia, immune, inactivity)
    var healthSignalReport: PredictiveHealthSignals.HealthSignalReport?
    /// Single highest-impact daily action (legacy, kept for backward compat)
    var dailyAction: DailyAction?
    /// Policy-based recommendation decision (replaces dailyAction as primary)
    var policyDecision: PolicyDecision?
    /// Personalization status for the user
    var personalizationStatus: PersonalizationBlender.PersonalizationStatus?
    /// Data sufficiency assessment
    var dataSufficiency: UncertaintyEstimator.DataSufficiency?
    /// Component readiness
    var componentReadiness: [UncertaintyEstimator.ComponentReadiness] = []
    /// HMM-smoothed state history
    var smoothedStates: [SmoothedHealthState] = []
    /// Multi-horizon forecasts (1d, 3d, 7d) per metric
    var multiHorizonForecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast] = [:]
    /// Multivariate regression results (omitted-variable-reduced causality)
    var multivariateResults: [MultivariateRegressionResult] = []
    /// Latest evaluation summary per component
    var evaluationSummaries: [String: ComponentEvaluation] = [:]
    /// Model drift alerts
    var driftAlerts: [DriftReport] = []
    /// Interaction effects (dose-response, conditional, moderation)
    var interactionEffects: [InteractionEffectEngine.InteractionEffect] = []
    /// Dose-response curves
    var doseResponseCurves: [InteractionEffectEngine.DoseResponseCurve] = []
    /// Temporal sequences (multi-step causal chains)
    var temporalSequences: [TemporalSequenceMiner.TemporalSequence] = []
    /// Precursor warning patterns
    var precursorPatterns: [TemporalSequenceMiner.PrecursorPattern] = []
    /// Compounding effects
    var compoundingEffects: [TemporalSequenceMiner.CompoundingEffect] = []
    /// Detected changepoints (regime shifts)
    var changePoints: [ChangePointDetector.ChangePoint] = []
    /// Regime comparisons per metric
    var regimeComparisons: [ChangePointDetector.RegimeComparison] = []
    /// Personal optimal profile
    var optimalProfile: PersonalOptimizer.OptimalProfile?
    /// Ideal day targets
    var idealDay: PersonalOptimizer.IdealDay?
    /// Score sensitivities per metric
    var scoreSensitivities: [PersonalOptimizer.SensitivityResult] = []
    /// Compound insights (cross-component synthesis)
    var compoundInsights: [CompoundInsightEngine.CompoundInsight] = []

    // MARK: - Cached Feature Vectors

    private let vectorLock = NSLock()
    private var _cachedVectors: [DailyFeatureVector] = []
    private var cachedVectors: [DailyFeatureVector] {
        get { vectorLock.withLock { _cachedVectors } }
        set { vectorLock.withLock { _cachedVectors = newValue } }
    }

    /// Latest feature vector (for simulation engine)
    var latestVector: DailyFeatureVector? { cachedVectors.last }

    /// Full state history from classifier (for Health State Timeline)
    var stateHistory: [(date: Date, label: String)] {
        stateClassifier.isReady ? stateClassifier.stateHistory : []
    }

    /// Transition matrix from classifier (for Health State Timeline)
    var stateTransitionMatrix: [String: [String: Double]] {
        stateClassifier.isReady ? stateClassifier.transitionMatrix : [:]
    }

    /// All identified health states from classifier
    var healthStates: [HealthState] {
        stateClassifier.isReady ? stateClassifier.states : []
    }

    /// Circadian profile (chronotype, peak times)
    var circadianProfile: CircadianAnalyzer.CircadianProfile? { circadianAnalyzer.profile }

    /// Timing recommendations from circadian analysis
    var timingRecommendations: [CircadianAnalyzer.TimingRecommendation] { circadianAnalyzer.recommendations }

    /// Whether circadian analysis should run
    var needsCircadianAnalysis: Bool { circadianAnalyzer.needsAnalysis }

    // MARK: - Run ML Analysis

    /// Run all ML components that are ready. Called from AnalysisEngine after rule-based analysis.
    /// Components run sequentially (one at a time) to avoid CPU spikes, ordered by priority.
    /// Thermal state is checked before starting and between each component.
    func runMLAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        ruleBasedAnomalies: [AnomalyDetector.AnomalyResult],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int]
    ) async {
        // Bail out entirely if device is critically overheated
        if ProcessInfo.processInfo.thermalState == .critical {
            logger.warning("Skipping ML analysis: device thermal state is critical")
            return
        }

        isRunning = true
        defer {
            isRunning = false
            hasRunOnce = true
        }

        // Step 0: Build feature vectors (required by most components)
        let vectors = featureEngine.buildFeatureVectors(
            timeSeries: timeSeries,
            baselines: baselines
        )
        cachedVectors = vectors
        let orderedKeys = featureEngine.orderedKeys

        guard !vectors.isEmpty else { return }

        let totalDays = vectors.count

        // Assess data sufficiency and component readiness upfront
        let requiredMetrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration,
            .steps, .activeCalories, .exerciseMinutes
        ]
        dataSufficiency = UncertaintyEstimator.assessDataSufficiency(
            timeSeries: timeSeries,
            requiredMetrics: requiredMetrics
        )
        componentReadiness = UncertaintyEstimator.checkComponentReadiness(totalDays: totalDays)

        // Personalization status
        personalizationStatus = PersonalizationBlender.personalizationStatus(
            userDataDays: totalDays,
            metricsTracked: timeSeries.count
        )

        // Step 0a: Enrich feature vectors with composite features
        logger.debug("Building composite features")
        enrichedVectors = CompositeFeatureEngine.enrich(
            vectors: vectors,
            timeSeries: timeSeries,
            baselines: baselines
        )

        if shouldStopForThermal(after: "CompositeFeatureEngine") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 1. TimeSeriesForecaster (21+ days) ---
        if totalDays >= TimeSeriesForecaster.minimumDays {
            if forecaster.needsRetrain || !forecaster.isReady {
                logger.debug("Running TimeSeriesForecaster")
                forecaster.fit(timeSeries: timeSeries)
            }
        }

        if shouldStopForThermal(after: "TimeSeriesForecaster") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 2. PredictiveScorer (30+ days) ---
        if totalDays >= PredictiveScorer.minimumDays {
            logger.debug("Running PredictiveScorer")
            predictiveScorer.train(
                vectors: vectors,
                orderedKeys: orderedKeys,
                scoreHistory: scoreHistory,
                anomalyCounts: anomalyCounts
            )
        }

        if shouldStopForThermal(after: "PredictiveScorer") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 3. CorrelationDiscovery (30+ days) ---
        if totalDays >= CorrelationDiscovery.minimumDays {
            if correlationDiscovery.needsRetrain || !correlationDiscovery.isReady {
                logger.debug("Running CorrelationDiscovery")
                correlationDiscovery.discover(timeSeries: timeSeries)
            }
        }

        if shouldStopForThermal(after: "CorrelationDiscovery") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 4. HealthStateClassifier (60+ days) ---
        if totalDays >= HealthStateClassifier.minimumDays {
            if stateClassifier.needsRetrain || !stateClassifier.isReady {
                logger.debug("Running HealthStateClassifier")
                stateClassifier.train(vectors: vectors, orderedKeys: orderedKeys)
            }
        }

        if shouldStopForThermal(after: "HealthStateClassifier") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 5. PatternMiner (60+ days) ---
        if totalDays >= PatternMiner.minimumDays {
            logger.debug("Running PatternMiner")
            patternMiner.mine(timeSeries: timeSeries)
        }

        if shouldStopForThermal(after: "PatternMiner") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 6. AdaptiveAnomalyDetector (60+ days) ---
        if totalDays >= AdaptiveAnomalyDetector.minimumDays {
            if anomalyDetector.needsRetrain || !anomalyDetector.isReady {
                logger.debug("Running AdaptiveAnomalyDetector")
                anomalyDetector.train(vectors: vectors, orderedKeys: orderedKeys, baselines: baselines)
            }
        }

        if shouldStopForThermal(after: "AdaptiveAnomalyDetector") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 6a. HMM Smoothed States (after classifier trains) ---
        if stateClassifier.isReady {
            let dates = vectors.map(\.date)
            smoothedStates = stateClassifier.smoothedStateHistory(vectors: vectors, dates: dates)
        }

        // --- 6b. Multi-horizon forecasting (after forecaster trains) ---
        if forecaster.isReady {
            let forecasterVersion = ModelVersion(
                componentName: "TimeSeriesForecaster",
                modelVersion: 2, featureSchemaVersion: 1, calibrationVersion: 1,
                trainedAt: Date(), dataPointsUsed: totalDays
            )
            for (metric, _) in timeSeries {
                if let forecast = forecaster.forecast(metric: metric, horizons: [1, 3, 7]) {
                    multiHorizonForecasts[metric] = forecast

                    // Record evaluation events for each forecast horizon
                    if let oneDay = forecast.horizons.first(where: { $0.horizon == 1 }) {
                        _ = mlEvaluator.recordPrediction(
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
        if totalDays >= 45 && correlationDiscovery.isReady {
            logger.debug("Running multivariate Granger")
            multivariateResults = runMultivariateGranger(timeSeries: timeSeries)
        }

        if shouldStopForThermal(after: "MultivariateGranger") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 7. Predictive Health Signals (7+ days for fatigue, more for others) ---
        logger.debug("Running PredictiveHealthSignals")
        healthSignalReport = PredictiveHealthSignals.analyze(
            timeSeries: timeSeries,
            baselines: baselines,
            trends: trends,
            healthState: stateClassifier.isReady ? stateClassifier.currentState : nil,
            prediction: predictiveScorer.isReady ? predictiveScorer.predict(todayVector: vectors.last!) : nil
        )

        if shouldStopForThermal(after: "PredictiveHealthSignals") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 8. Evaluation: auto-resolve expired prediction events ---
        logger.debug("Resolving evaluation events")
        let scoreMap: [(date: Date, score: Double)] = scoreHistory.map { (date: $0.date, score: Double($0.score)) }
        mlEvaluator.resolveExpiredEvents(timeSeries: timeSeries, scores: scoreMap)

        // Run drift detection on key components
        driftAlerts = []
        for component in ["PredictiveScorer", "TimeSeriesForecaster"] {
            if let drift = mlEvaluator.detectModelDrift(componentName: component),
               drift.isDrifting {
                driftAlerts.append(drift)
                logger.warning("Model drift detected in \(component): \(drift.recommendation)")
            }
        }

        // Update evaluation summaries
        for component in ["PredictiveScorer", "TimeSeriesForecaster", "HealthStateClassifier"] {
            if let eval = mlEvaluator.evaluateComponent(name: component, horizon: .nextDay) {
                evaluationSummaries[component] = eval
            }
        }

        // --- 9. InteractionEffectEngine (45+ days) ---
        if totalDays >= InteractionEffectEngine.minimumDays {
            logger.debug("Running InteractionEffectEngine")
            interactionEffects = interactionEngine.discover(timeSeries: timeSeries, baselines: baselines)
            doseResponseCurves = interactionEngine.doseResponseCurves
        }

        if shouldStopForThermal(after: "InteractionEffectEngine") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 10. TemporalSequenceMiner (30+ days) ---
        if totalDays >= TemporalSequenceMiner.minimumDays {
            logger.debug("Running TemporalSequenceMiner")
            temporalMiner.mine(
                timeSeries: timeSeries,
                baselines: baselines,
                stateHistory: smoothedStates
            )
            temporalSequences = temporalMiner.sequences
            precursorPatterns = temporalMiner.precursorPatterns
            compoundingEffects = temporalMiner.compoundingEffects
        }

        if shouldStopForThermal(after: "TemporalSequenceMiner") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 11. ChangePointDetector (30+ days) ---
        if totalDays >= ChangePointDetector.minimumDays {
            logger.debug("Running ChangePointDetector")
            changePointDetector.detect(timeSeries: timeSeries, baselines: baselines)
            changePoints = changePointDetector.changePoints
            regimeComparisons = changePointDetector.regimeComparisons
        }

        if shouldStopForThermal(after: "ChangePointDetector") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 12. PersonalOptimizer (21+ days, needs score history) ---
        if totalDays >= PersonalOptimizer.minimumDays && !scoreHistory.isEmpty {
            logger.debug("Running PersonalOptimizer")
            personalOptimizer.analyze(
                timeSeries: timeSeries,
                baselines: baselines,
                scoreHistory: scoreHistory,
                vectors: vectors
            )
            optimalProfile = personalOptimizer.optimalProfile
            idealDay = personalOptimizer.idealDay
            scoreSensitivities = personalOptimizer.sensitivities
        }

        if shouldStopForThermal(after: "PersonalOptimizer") {
            collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
            return
        }

        // --- 13. CompoundInsightEngine (synthesizes all component outputs) ---
        logger.debug("Running CompoundInsightEngine")
        let anomalyTuples: [(date: Date, metric: HealthMetric, severity: String)] = adaptiveAnomalies.compactMap { anomaly -> (date: Date, metric: HealthMetric, severity: String)? in
            guard let topFeature = anomaly.anomalousFeatures.first else { return nil }
            return (date: anomaly.date, metric: topFeature.key.metric, severity: "\(anomaly.severity)")
        }
        compoundInsightEngine.synthesize(
            timeSeries: timeSeries,
            baselines: baselines,
            correlations: mlCorrelations,
            patterns: discoveredPatterns,
            currentState: stateClassifier.isReady ? stateClassifier.currentState : nil,
            stateHistory: smoothedStates,
            prediction: tomorrowRiskPrediction,
            scoreHistory: scoreHistory,
            anomalies: anomalyTuples
        )
        compoundInsights = compoundInsightEngine.insights

        // Collect all results and compute policy decision
        collectResults(timeSeries: timeSeries, vectors: vectors, baselines: baselines, trends: trends, ruleBasedAnomalies: ruleBasedAnomalies, scoreHistory: scoreHistory)
    }

    /// Check thermal state and yield between components. Returns true if ML should stop.
    private func shouldStopForThermal(after component: String) -> Bool {
        if ProcessInfo.processInfo.thermalState == .critical {
            logger.warning("Stopping ML analysis after \(component): thermal state critical")
            return true
        }
        return false
    }

    // MARK: - Incremental Training

    /// Lightweight daily update without full retrain
    func trainIncremental(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        todayScore: Int,
        todayAnomalyCount: Int
    ) {
        // Update feature engine
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                featureEngine.updateIncremental(metric: metric, newValue: latest.value)
            }
        }

        // Update forecaster with latest values
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                forecaster.update(metric: metric, newValue: latest.value, dayOfWeek: weekday)
            }
        }

        // Update predictive scorer
        if let todayVector = cachedVectors.last {
            let wasBadDay = predictiveScorer.determineBadDay(
                todayScore: todayScore,
                tomorrowScore: nil,
                anomalyCount: todayAnomalyCount
            )
            predictiveScorer.trainIncremental(
                todayVector: todayVector,
                wasBadDay: wasBadDay
            )
        }
    }

    // MARK: - Full Retrain

    /// Full retrain of all components (expensive, every 30 days)
    var needsFullRetrain: Bool {
        guard let lastRetrain = lastFullRetrain else { return hasRunOnce }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    func markFullRetrainComplete() {
        lastFullRetrain = Date()
    }

    // MARK: - Circadian Analysis (separate pipeline, runs weekly)

    /// Run circadian analysis using hourly data. Called separately from the main ML pipeline.
    func runCircadianAnalysis(hourlyData: [HealthMetric: [[Double]]]) {
        guard !hourlyData.isEmpty else { return }
        circadianAnalyzer.analyze(hourlyData: hourlyData)
    }

    // MARK: - Result Collection

    private func collectResults(
        timeSeries: [HealthMetric: MetricTimeSeries],
        vectors: [DailyFeatureVector],
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        ruleBasedAnomalies: [AnomalyDetector.AnomalyResult],
        scoreHistory: [(date: Date, score: Int)]
    ) {
        // Forecast anomalies
        if forecaster.isReady {
            mlAnomalies = forecaster.detectAnomalies(timeSeries: timeSeries)
        }

        // Adaptive anomalies (score recent days, with persistence gating)
        if anomalyDetector.isReady {
            adaptiveAnomalies = anomalyDetector.scoreRecent(vectors: vectors, days: 7)
        }

        // Patterns
        if patternMiner.isReady {
            discoveredPatterns = patternMiner.patterns
        }

        // Correlations (with FDR correction applied)
        if correlationDiscovery.isReady {
            mlCorrelations = correlationDiscovery.correlations
        }

        // Health state (HMM-smoothed if available)
        if stateClassifier.isReady {
            currentHealthState = stateClassifier.currentState
        }

        // Tomorrow prediction — blend with population prior via PersonalizationBlender
        if predictiveScorer.isReady, let todayVector = vectors.last {
            let personalPrediction = predictiveScorer.predict(todayVector: todayVector)
            tomorrowRiskPrediction = personalPrediction

            // Blend with population base model if we have limited data
            if let prediction = personalPrediction {
                let populationPrediction = PersonalizationBlender.populationPrediction(
                    from: todayVector
                )
                let (blendedProb, _) = PersonalizationBlender.blendPrediction(
                    personalPrediction: prediction.probability,
                    populationPrediction: populationPrediction,
                    userDataDays: vectors.count
                )

                // PredictiveScorer now internally applies Platt calibration during predict(),
                // so blendedProb is already calibrated. Only apply temperature scaling if
                // evaluation data shows persistent miscalibration (ECE > 0.10).
                var calibratedProb = blendedProb
                if let eval = evaluationSummaries["PredictiveScorer"],
                   let ece = eval.ece, ece > 0.10,
                   eval.sampleCount >= 20 {
                    // Fit temperature from recent evaluation data
                    let logit = log(max(blendedProb, 1e-10) / max(1 - blendedProb, 1e-10))
                    let tempT = conformalCalibrator.temperatureScale(
                        logits: [logit], labels: [blendedProb > 0.5 ? 1.0 : 0.0]
                    )
                    calibratedProb = conformalCalibrator.calibrateWithTemperature(logit: logit, T: tempT)
                }

                tomorrowRiskPrediction = MLPrediction(
                    target: prediction.target,
                    probability: calibratedProb,
                    confidence: prediction.confidence,
                    topFactors: prediction.topFactors,
                    generatedAt: Date()
                )

                // Record evaluation event for this prediction
                let version = ModelVersion(
                    componentName: "PredictiveScorer",
                    modelVersion: 2,
                    featureSchemaVersion: 2,
                    calibrationVersion: 1,
                    trainedAt: Date(),
                    dataPointsUsed: vectors.count
                )
                _ = mlEvaluator.recordPrediction(
                    componentName: "PredictiveScorer",
                    modelVersion: version,
                    horizon: .nextDay,
                    targetMetric: "overallScore",
                    predictedValue: calibratedProb,
                    probability: calibratedProb,
                    confidence: prediction.confidence
                )
            }
        } else if !vectors.isEmpty {
            // Cold start: use population-based prediction even without trained model
            let availableData = buildAvailableDataForColdStart(timeSeries: timeSeries)
            let coldStart = PersonalizationBlender.coldStartPrediction(availableData: availableData)
            if coldStart.confidence > 0.05 {
                tomorrowRiskPrediction = MLPrediction(
                    target: "bad day tomorrow",
                    probability: coldStart.riskScore,
                    confidence: coldStart.confidence,
                    topFactors: [],
                    generatedAt: Date()
                )
            }
        }

        // Apply confidence gate to tomorrow prediction — keep suggestive predictions
        if let prediction = tomorrowRiskPrediction, let sufficiency = dataSufficiency {
            let gate = UncertaintyEstimator.gate(
                modelConfidence: prediction.confidence,
                dataSufficiency: sufficiency,
                evaluationMetrics: nil
            )
            if !gate.shouldShow {
                logger.debug("Prediction gated: \(gate.reason ?? "low confidence")")
                tomorrowRiskPrediction = nil
            }
        }

        // --- Decision Policy Engine (replaces DailyActionEngine as primary) ---
        let causalCorrelations = mlCorrelations.filter { $0.grangerCausal }
        let candidates = decisionPolicyEngine.generateCandidates(
            currentState: currentHealthState,
            tomorrowRisk: tomorrowRiskPrediction,
            causalDiscoveries: causalCorrelations,
            trends: trends,
            baselines: baselines,
            anomalies: ruleBasedAnomalies,
            circadianRecommendations: timingRecommendations,
            timeSeries: timeSeries
        )

        if !candidates.isEmpty {
            // Run counterfactual on top candidates if scorer is ready
            var enrichedCandidates = candidates
            if predictiveScorer.isReady, let todayVector = vectors.last {
                enrichedCandidates = candidates.map { candidate in
                    let delta = decisionPolicyEngine.estimateCounterfactual(
                        action: candidate,
                        currentVector: todayVector,
                        scorer: predictiveScorer
                    )
                    // If counterfactual shows meaningful delta, boost uplift
                    if let delta = delta, abs(delta) > 0.01 {
                        var boosted = candidate
                        // Counterfactual-informed candidates are handled by the policy scoring
                        return boosted
                    }
                    return candidate
                }
            }

            if let decision = decisionPolicyEngine.decide(candidates: enrichedCandidates) {
                // Attach natural language with full timeSeries context
                let primaryLang = decisionPolicyEngine.generateLanguage(
                    for: decision.primaryAction.candidate,
                    baselines: baselines, trends: trends, timeSeries: timeSeries
                )
                let primaryWithLang = PolicyDecision.RankedIntervention(
                    candidate: decision.primaryAction.candidate,
                    expectedUtility: decision.primaryAction.expectedUtility,
                    noveltyFactor: decision.primaryAction.noveltyFactor,
                    title: primaryLang.title, description: primaryLang.description,
                    whyItMatters: primaryLang.whyMatters, expectedBenefit: primaryLang.expectedBenefit
                )

                var secondaryWithLang: PolicyDecision.RankedIntervention?
                if let sec = decision.secondaryAction {
                    let secLang = decisionPolicyEngine.generateLanguage(
                        for: sec.candidate,
                        baselines: baselines, trends: trends, timeSeries: timeSeries
                    )
                    secondaryWithLang = PolicyDecision.RankedIntervention(
                        candidate: sec.candidate,
                        expectedUtility: sec.expectedUtility, noveltyFactor: sec.noveltyFactor,
                        title: secLang.title, description: secLang.description,
                        whyItMatters: secLang.whyMatters, expectedBenefit: secLang.expectedBenefit
                    )
                }

                let allWithLang = decision.allCandidates.map { ranked in
                    let lang = decisionPolicyEngine.generateLanguage(
                        for: ranked.candidate,
                        baselines: baselines, trends: trends, timeSeries: timeSeries
                    )
                    return PolicyDecision.RankedIntervention(
                        candidate: ranked.candidate,
                        expectedUtility: ranked.expectedUtility, noveltyFactor: ranked.noveltyFactor,
                        title: lang.title, description: lang.description,
                        whyItMatters: lang.whyMatters, expectedBenefit: lang.expectedBenefit
                    )
                }

                policyDecision = PolicyDecision(
                    primaryAction: primaryWithLang,
                    secondaryAction: secondaryWithLang,
                    allCandidates: allWithLang,
                    rationale: decision.rationale,
                    decisionConfidence: decision.decisionConfidence,
                    decidedAt: decision.decidedAt
                )
            }
        }

        // Legacy daily action (kept for backward compat during transition)
        dailyAction = DailyActionEngine.computeDailyAction(
            prediction: tomorrowRiskPrediction,
            circadianProfile: circadianProfile,
            timingRecommendations: timingRecommendations,
            causalCorrelations: causalCorrelations,
            currentState: currentHealthState,
            anomalies: ruleBasedAnomalies,
            trends: trends,
            baselines: baselines,
            timeSeries: timeSeries,
            adherenceMultiplier: { [weak self] category in
                self?.adherenceTracker.effectivenessMultiplier(for: category) ?? 1.0
            }
        )
    }

    /// Run multivariate Granger on metrics with 3+ significant pairwise correlations
    private func runMultivariateGranger(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [MultivariateRegressionResult] {
        var results: [MultivariateRegressionResult] = []
        let significantCorrelations = mlCorrelations.filter { $0.grangerCausal && $0.grangerPValue < 0.1 }

        // Group by target metric
        var candidatesByTarget: [HealthMetric: [HealthMetric]] = [:]
        for corr in significantCorrelations {
            candidatesByTarget[corr.metricB, default: []].append(corr.metricA)
        }

        // Convert MetricTimeSeries to [Double] for Granger engine
        var seriesValues: [HealthMetric: [Double]] = [:]
        for (metric, series) in timeSeries {
            seriesValues[metric] = series.sortedSamples.map(\.value)
        }

        // Run multivariate only when 3+ predictors exist
        for (target, predictors) in candidatesByTarget where predictors.count >= 3 {
            if let result = GrangerCausalityEngine.multivariateGrangerTest(
                target: target,
                predictors: Array(Set(predictors).prefix(8)), // cap at 8
                timeSeries: seriesValues,
                maxLag: 3
            ) {
                results.append(result)
            }
        }

        return results
    }

    /// Build metric data arrays for cold-start prediction
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

    // MARK: - Insight Generation

    /// Convert ML results into Insight objects for the insights pipeline
    func generateInsights() -> [Insight] {
        var insights: [Insight] = []

        // Pattern insights
        for pattern in discoveredPatterns.prefix(3) {
            insights.append(Insight(
                metric: pattern.metric,
                title: "Discovered \(pattern.patternType.rawValue) Pattern",
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
                    dataPointCount: cachedVectors.count
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
                title: "Current State: \(state.label)",
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
                    dataPointCount: cachedVectors.count
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
                title: "Tomorrow Outlook: \(prediction.riskLevel) Risk",
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
                    dataPointCount: cachedVectors.count
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

        // Compound insights (crown jewel — cross-component synthesis)
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
                title: "Active Warning: \(precursor.predictedEvent)",
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
                title: "Sequence In Progress",
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
                title: "Optimization: \(Int((1.0 - profile.matchPercentage) * 100))% Gap to Your Best",
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
                    dataPointCount: cachedVectors.count
                )
            ))
        }

        if let ideal = idealDay {
            insights.append(Insight(
                metric: ideal.targets.first?.metric ?? .heartRateVariability,
                title: "Your Ideal Day Blueprint",
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
                    dataPointCount: cachedVectors.count
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

    // MARK: - Recommendation Helpers

    private func recommendationForPattern(_ pattern: DiscoveredPattern) -> String {
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
            return "Your \(pattern.metric.displayName) follows a ~\(Int(pattern.periodDays))-day cycle (strength: \(Int(pattern.strength * 100))%). Track what changes around the cycle peak and trough — this may relate to hormonal or lifestyle rhythms."
        case .seasonal:
            return "Your \(pattern.metric.displayName) shows seasonal variation (strength: \(Int(pattern.strength * 100))%). Adjust your targets based on the time of year rather than holding to a fixed standard."
        case .custom:
            return "Your \(pattern.metric.displayName) has a unique \(Int(pattern.periodDays))-day cycle (strength: \(Int(pattern.strength * 100))%). Observe what activities or habits align with this rhythm."
        }
    }

    private func describeStateCharacteristics(_ state: HealthState) -> String {
        let notable = state.characteristics.filter { $0.level != .normal }
        guard !notable.isEmpty else { return "All metrics within normal range." }

        let descriptions = notable.prefix(3).map { char in
            let severity = abs(char.zScore) > 2 ? "significantly " : abs(char.zScore) > 1 ? "" : "slightly "
            return "\(severity)\(char.level.rawValue) \(char.metric.displayName) (\(String(format: "%.1f", abs(char.zScore)))σ)"
        }
        return "Characterized by: " + descriptions.joined(separator: ", ") + "."
    }

    private func recommendationForState(_ state: HealthState) -> String {
        let daysNote = state.daysInState > 1 ? " (day \(state.daysInState) in this state)" : ""
        let characteristics = state.characteristics.filter { $0.level != .normal }
        let charNote: String
        if let top = characteristics.first {
            charNote = " Key signal: \(top.level.rawValue) \(top.metric.displayName.lowercased())"
                + " (\(String(format: "%.1f", abs(top.zScore)))σ from normal)."
        } else {
            charNote = ""
        }

        // Build transition context
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

    private func recommendationForPrediction(_ prediction: MLPrediction) -> String {
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
                rec += " Your \(protective.metric.displayName.lowercased()) is helping — keep it up."
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
