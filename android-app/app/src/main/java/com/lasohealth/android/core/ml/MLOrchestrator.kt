package com.lasohealth.android.core.ml

import android.util.Log
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Orchestrates all on-device ML components: feature extraction, forecasting,
 * correlation discovery, anomaly detection, pattern mining, health state
 * classification, predictive scoring, health signals, and decision policy.
 *
 * Call [runPipeline] from a coroutine scope (e.g. a ViewModel) after fresh
 * health data has been synced. The orchestrator runs each component in
 * sequence on [Dispatchers.Default] and publishes results as plain properties
 * that the UI layer can observe.
 *
 * When fewer than 7 days of data are available, population-based defaults are
 * returned (cold-start).
 *
 * Ported from iOS `MLOrchestrator.swift`.
 */
class MLOrchestrator {

    companion object {
        private const val TAG = "MLOrchestrator"
    }

    // -- ML Components (Core) ---------------------------------------------------

    val featureEngine = FeatureEngine()
    val forecaster = TimeSeriesForecaster()
    val correlationDiscovery = CorrelationDiscovery()
    val anomalyDetector = AdaptiveAnomalyDetector()
    val patternMiner = PatternMiner()
    val stateClassifier = HealthStateClassifier()
    val predictiveScorer = PredictiveScorer()

    // -- ML Components (Intelligence Layer) -------------------------------------

    val predictiveHealthSignals = PredictiveHealthSignals()
    val decisionPolicyEngine = DecisionPolicyEngine()
    val conformalCalibrator = ConformalCalibrator()

    // -- Observable state -------------------------------------------------------

    /** Whether the pipeline has been run at least once. */
    var hasRunOnce: Boolean = false
        private set

    /** Whether the pipeline is currently executing. */
    var isRunning: Boolean = false
        private set

    /** Personalization stage based on data maturity. */
    var personalizationStage: PersonalizationStage = PersonalizationStage.POPULATION
        private set

    /** Personalization status for the UI. */
    var personalizationStatus: PersonalizationBlender.PersonalizationStatus? = null
        private set

    /** Data sufficiency assessment. */
    var dataSufficiency: UncertaintyEstimator.DataSufficiency? = null
        private set

    /** Component readiness. */
    var componentReadiness: List<UncertaintyEstimator.ComponentReadiness> = emptyList()
        private set

    /** True when any component has enough data to produce results. */
    val isReady: Boolean
        get() = featureEngine.isReady || forecaster.isReady || correlationDiscovery.isReady

    // -- Results ----------------------------------------------------------------

    /** Multi-horizon forecasts keyed by metric. */
    var predictions: Map<HealthMetric, MultiHorizonForecast> = emptyMap()
        private set

    /** Discovered metric correlations (FDR-corrected). */
    var correlations: List<MLCorrelation> = emptyList()
        private set

    /** Feature vectors from the last pipeline run (oldest first). */
    var featureVectors: List<DailyFeatureVector> = emptyList()
        private set

    /** Discovered periodic patterns. */
    var patterns: List<DiscoveredPattern> = emptyList()
        private set

    /** All identified health states. */
    var healthStates: List<HealthState> = emptyList()
        private set

    /** Current health state. */
    var currentHealthState: HealthState? = null
        private set

    /** HMM-smoothed state history. */
    var smoothedStates: List<SmoothedHealthState> = emptyList()
        private set

    /** Adaptive anomaly results. */
    var adaptiveAnomalies: List<AdaptiveAnomalyDetector.AdaptiveAnomaly> = emptyList()
        private set

    /** Tomorrow risk prediction. */
    var tomorrowRiskPrediction: MLPrediction? = null
        private set

    /** Predictive health signal report. */
    var healthSignalReport: PredictiveHealthSignals.HealthSignalReport? = null
        private set

    /** Today's action recommendation. */
    var policyDecision: PolicyDecision? = null
        private set

    // -- Pipeline ---------------------------------------------------------------

    /**
     * Run the full ML pipeline sequentially.
     *
     * Pipeline stages:
     * 1. Feature extraction
     * 2. Time-series forecasting (train + forecast)
     * 3. Correlation discovery
     * 4. Anomaly detection (Isolation Forest)
     * 5. Pattern mining (autocorrelation + Goertzel)
     * 6. Health state classification (GMM + HMM)
     * 7. Predictive scoring (GBT)
     * 8. Predictive health signals (6 detectors)
     * 9. Decision policy engine (expected utility)
     * 10. Uncertainty estimation + personalization status
     *
     * All computation runs on [Dispatchers.Default].
     */
    suspend fun runPipeline(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        scoreHistory: List<Pair<Long, Int>> = emptyList(),
        anomalyCounts: Map<Long, Int> = emptyMap(),
    ) = withContext(Dispatchers.Default) {
        if (isRunning) return@withContext
        isRunning = true
        val startTime = System.currentTimeMillis()

        try {
            val dayCount = computeDayCount(timeSeries)
            personalizationStage = PersonalizationStage.from(dayCount)

            Log.d(TAG, "Pipeline start: $dayCount days of data, stage=$personalizationStage")

            // Update uncertainty/readiness regardless of data maturity.
            dataSufficiency = UncertaintyEstimator.assessDataSufficiency(
                totalDays = dayCount,
                metricsPresent = timeSeries.size,
                requiredMetrics = 10,
            )
            componentReadiness = UncertaintyEstimator.checkComponentReadiness(dayCount)
            personalizationStatus = PersonalizationBlender.personalizationStatus(
                userDataDays = dayCount,
                metricsTracked = timeSeries.size,
            )

            // Cold-start: population-based defaults.
            if (dayCount < FeatureEngine.MINIMUM_DAYS) {
                applyColdStartDefaults(timeSeries)
                return@withContext
            }

            // Step 1: Feature extraction.
            val allSamples = timeSeries.values.flatten()
            val vectors = featureEngine.extract(allSamples, baselines)
            featureVectors = vectors
            Log.d(TAG, "Features: ${vectors.size} vectors, ${featureEngine.orderedKeys.size} keys")

            // Step 2: Forecasting.
            forecaster.train(timeSeries)
            val forecasts = mutableMapOf<HealthMetric, MultiHorizonForecast>()
            for (metric in timeSeries.keys) {
                forecaster.forecast(metric, horizons = listOf(1, 3, 7))?.let { forecasts[metric] = it }
            }
            predictions = forecasts
            Log.d(TAG, "Forecasts: ${forecasts.size} metrics")

            // Step 3: Correlation discovery.
            if (dayCount >= CorrelationDiscovery.MINIMUM_DAYS) {
                correlationDiscovery.discover(timeSeries)
                correlations = correlationDiscovery.correlations
                Log.d(TAG, "Correlations: ${correlations.size} discovered, ${correlationDiscovery.fdrSignificant().size} FDR-significant")
            }

            // Step 4: Anomaly detection.
            if (dayCount >= AdaptiveAnomalyDetector.MINIMUM_DAYS && vectors.isNotEmpty()) {
                anomalyDetector.train(vectors, featureEngine.orderedKeys, baselines)
                adaptiveAnomalies = anomalyDetector.scoreRecent(vectors)
                val surfaced = adaptiveAnomalies.count { it.shouldSurface }
                Log.d(TAG, "Anomalies: ${adaptiveAnomalies.size} scored, $surfaced surfaced")
            }

            // Step 5: Pattern mining.
            if (dayCount >= PatternMiner.MINIMUM_DAYS) {
                patternMiner.mine(timeSeries)
                patterns = patternMiner.patterns
                Log.d(TAG, "Patterns: ${patterns.size} discovered")
            }

            // Step 6: Health state classification.
            if (dayCount >= HealthStateClassifier.MINIMUM_DAYS && vectors.isNotEmpty()) {
                stateClassifier.classify(vectors, featureEngine.orderedKeys)
                healthStates = stateClassifier.states
                currentHealthState = stateClassifier.currentState
                smoothedStates = stateClassifier.smoothedStates(vectors)
                Log.d(TAG, "States: ${healthStates.size} identified, current=${currentHealthState?.label}")
            }

            // Step 7: Predictive scoring (GBT).
            if (dayCount >= PredictiveScorer.MINIMUM_DAYS && vectors.isNotEmpty() && scoreHistory.isNotEmpty()) {
                predictiveScorer.train(vectors, featureEngine.orderedKeys, scoreHistory, anomalyCounts)
                if (predictiveScorer.isReady) {
                    tomorrowRiskPrediction = predictiveScorer.predict(vectors.last())
                    Log.d(TAG, "Risk prediction: ${tomorrowRiskPrediction?.predictedValue}")
                }
            }

            // Step 8: Predictive health signals.
            if (dayCount >= PredictiveHealthSignals.MINIMUM_DAYS) {
                healthSignalReport = predictiveHealthSignals.analyze(timeSeries, baselines)
                Log.d(TAG, "Health signals: ${healthSignalReport?.signals?.size ?: 0} signals, " +
                    "risk=${healthSignalReport?.overallRisk}")
            }

            // Step 9: Decision policy engine.
            policyDecision = decisionPolicyEngine.decide(
                forecasts = forecasts,
                baselines = baselines,
                anomalies = adaptiveAnomalies,
                healthSignals = healthSignalReport,
                patterns = patterns,
                correlations = correlationDiscovery.fdrSignificant(),
                currentState = currentHealthState,
                dayCount = dayCount,
            )
            Log.d(TAG, "Policy: ${policyDecision?.action}")

        } catch (e: Exception) {
            Log.e(TAG, "Pipeline failed", e)
        } finally {
            isRunning = false
            hasRunOnce = true
            val elapsed = System.currentTimeMillis() - startTime
            Log.d(TAG, "Pipeline complete in ${elapsed}ms")
        }
    }

    // -- Cold-start -------------------------------------------------------------

    private fun applyColdStartDefaults(timeSeries: Map<HealthMetric, List<DailySample>>) {
        predictions = emptyMap()
        correlations = emptyList()
        featureVectors = emptyList()
        patterns = emptyList()
        healthStates = emptyList()
        currentHealthState = null
        smoothedStates = emptyList()
        adaptiveAnomalies = emptyList()
        tomorrowRiskPrediction = null
        healthSignalReport = null

        // Cold-start prediction from population priors.
        val availableData = timeSeries.mapValues { (_, samples) ->
            samples.sortedBy { it.date }.map { it.value }
        }
        val (riskScore, confidence, _) = PersonalizationBlender.coldStartPrediction(availableData)

        policyDecision = if (riskScore > 0.5) {
            PolicyDecision(
                action = "Take it easy today",
                detail = "Based on general health benchmarks, your metrics suggest taking a lighter approach today.",
                confidence = confidence,
                metric = null,
                iconEmoji = "\uD83D\uDCA4",
            )
        } else {
            PolicyDecision(
                action = "Keep tracking",
                detail = "We need a few more days of data to personalise insights for you.",
                confidence = 0.3,
                metric = null,
                iconEmoji = "\uD83D\uDCCA",
            )
        }
    }

    // -- Helpers ----------------------------------------------------------------

    /**
     * Compute the number of distinct calendar days across all metric series.
     */
    private fun computeDayCount(timeSeries: Map<HealthMetric, List<DailySample>>): Int {
        val allDates = timeSeries.values.flatMap { samples -> samples.map { startOfDay(it.date) } }.toSet()
        return allDates.size
    }

    private fun startOfDay(epochMillis: Long): Long {
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = epochMillis
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
