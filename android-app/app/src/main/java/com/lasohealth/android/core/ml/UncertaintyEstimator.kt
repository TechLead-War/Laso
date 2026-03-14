package com.lasohealth.android.core.ml

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Uncertainty estimation and confidence gating for ML predictions.
 *
 * Prevents overconfident predictions from reaching users by combining:
 * - Conformal prediction intervals (finite-sample coverage guarantee)
 * - Ensemble disagreement analysis
 * - Data sufficiency assessment
 * - Three-tier confidence gating (confident / suggestive / gated)
 *
 * Ported from iOS `UncertaintyEstimator.swift`.
 */
object UncertaintyEstimator {

    // ---------------------------------------------------------------------------
    // Conformal Prediction Intervals
    // ---------------------------------------------------------------------------

    data class PredictionInterval(
        val lower: Double,
        val upper: Double,
        val coverage: Double,
        val width: Double,
    )

    /**
     * Compute a conformal prediction interval using split conformal prediction.
     *
     * Given calibration residuals (|actual - predicted|) from a held-out set,
     * the interval is formed at the quantile level ceil((n+1) * coverage) / n.
     */
    fun conformalInterval(
        calibrationResiduals: List<Double>,
        pointPrediction: Double,
        coverageLevel: Double = 0.90,
    ): PredictionInterval {
        val coverage = coverageLevel.coerceIn(0.5, 0.99)

        if (calibrationResiduals.isEmpty()) {
            return PredictionInterval(pointPrediction, pointPrediction, coverage, 0.0)
        }

        val sorted = calibrationResiduals.map { abs(it) }.sorted()
        val n = sorted.size
        val quantileIndex = min(ceil((n + 1).toDouble() * coverage).toInt() - 1, n - 1).coerceAtLeast(0)
        val radius = sorted[quantileIndex]

        return PredictionInterval(
            lower = pointPrediction - radius,
            upper = pointPrediction + radius,
            coverage = coverage,
            width = 2.0 * radius,
        )
    }

    // ---------------------------------------------------------------------------
    // Ensemble Disagreement
    // ---------------------------------------------------------------------------

    data class EnsembleUncertainty(
        val meanPrediction: Double,
        val stdDeviation: Double,
        val coefficientOfVariation: Double,
        val isHighUncertainty: Boolean,
    )

    /**
     * Measure ensemble disagreement across multiple predictions from model variants.
     */
    fun ensembleDisagreement(
        predictions: List<Double>,
        cvThreshold: Double = 0.3,
    ): EnsembleUncertainty? {
        if (predictions.size < 2) return null

        val mean = predictions.average()
        val variance = predictions.sumOf { (it - mean) * (it - mean) } / predictions.size
        val stdDev = sqrt(variance)

        val cv = if (abs(mean) > 1e-9) stdDev / abs(mean)
        else if (stdDev > 1e-9) 1.0 else 0.0

        return EnsembleUncertainty(
            meanPrediction = mean,
            stdDeviation = stdDev,
            coefficientOfVariation = cv,
            isHighUncertainty = cv > cvThreshold,
        )
    }

    // ---------------------------------------------------------------------------
    // Data Sufficiency
    // ---------------------------------------------------------------------------

    data class DataSufficiency(
        val overallScore: Double,
        val totalDays: Int,
        val metricCoverage: Double,
        val recencyScore: Double,
        val minimumMetDays: Int,
        val recommendation: String,
    )

    /** Component minimum day requirements. */
    private val componentMinimums: Map<String, Int> = mapOf(
        "FeatureEngine" to FeatureEngine.MINIMUM_DAYS,
        "TimeSeriesForecaster" to TimeSeriesForecaster.MINIMUM_DAYS,
        "PredictiveScorer" to PredictiveScorer.MINIMUM_DAYS,
        "CorrelationDiscovery" to CorrelationDiscovery.MINIMUM_DAYS,
        "PatternMiner" to PatternMiner.MINIMUM_DAYS,
        "HealthStateClassifier" to HealthStateClassifier.MINIMUM_DAYS,
        "AdaptiveAnomalyDetector" to AdaptiveAnomalyDetector.MINIMUM_DAYS,
    )

    /**
     * Assess how sufficient the user's data is for ML analysis.
     */
    fun assessDataSufficiency(
        totalDays: Int,
        metricsPresent: Int,
        requiredMetrics: Int,
        daysSinceLastSync: Int = 0,
    ): DataSufficiency {
        val metricCoverage = if (requiredMetrics > 0) {
            metricsPresent.toDouble() / requiredMetrics
        } else 0.0

        val recencyScore = max(0.0, exp(-0.23 * daysSinceLastSync.toDouble()))

        val maxMinimum = componentMinimums.values.maxOrNull() ?: 60
        val minimumMetDays = max(0, totalDays - maxMinimum)

        val volumeScore = min(totalDays.toDouble() / maxMinimum, 1.0)
        val overallScore = (0.4 * volumeScore + 0.3 * metricCoverage + 0.3 * recencyScore)
            .coerceIn(0.0, 1.0)

        val recommendation = generateSufficiencyRecommendation(
            totalDays, metricCoverage, recencyScore,
        )

        return DataSufficiency(
            overallScore = overallScore,
            totalDays = totalDays,
            metricCoverage = metricCoverage,
            recencyScore = recencyScore,
            minimumMetDays = minimumMetDays,
            recommendation = recommendation,
        )
    }

    private fun generateSufficiencyRecommendation(
        totalDays: Int,
        metricCoverage: Double,
        recencyScore: Double,
    ): String {
        if (recencyScore < 0.3) {
            return "Your data is stale. Open the app to sync the latest health data."
        }
        if (metricCoverage < 0.5) {
            return "Enable more health metrics in Health Connect for richer analysis."
        }
        for ((name, minimum) in componentMinimums.entries.sortedBy { it.value }) {
            if (totalDays < minimum) {
                val remaining = minimum - totalDays
                return "Keep tracking for $remaining more day${if (remaining == 1) "" else "s"} to unlock $name predictions."
            }
        }
        if (metricCoverage < 1.0) {
            return "Great data depth. Enable additional metrics for even better insights."
        }
        return "Excellent data coverage across all ML components."
    }

    // ---------------------------------------------------------------------------
    // Confidence Gate
    // ---------------------------------------------------------------------------

    enum class ConfidenceTier(val displayName: String) {
        CONFIDENT("confident"),
        SUGGESTIVE("suggestive"),
        GATED("gated"),
    }

    data class ConfidenceGate(
        val shouldShow: Boolean,
        val confidenceScore: Double,
        val reason: String?,
        val tier: ConfidenceTier,
    )

    /**
     * Determine whether a prediction/insight should be shown to the user.
     *
     * Requires both sufficient data AND model confidence above the minimum threshold.
     */
    fun gate(
        modelConfidence: Double,
        dataSufficiency: DataSufficiency,
        evaluationAccuracy: Double? = null,
        evaluationCalibrationError: Double? = null,
        minimumConfidence: Double = 0.4,
    ): ConfidenceGate {
        // Gate 1: Data sufficiency.
        if (dataSufficiency.overallScore < 0.3) {
            return ConfidenceGate(
                shouldShow = false,
                confidenceScore = 0.0,
                reason = "Insufficient data: ${dataSufficiency.recommendation}",
                tier = ConfidenceTier.GATED,
            )
        }

        // Compute effective confidence.
        var effectiveConfidence = modelConfidence

        if (evaluationAccuracy != null) {
            val accuracyMultiplier = evaluationAccuracy.pow(0.3)
            effectiveConfidence *= accuracyMultiplier
        }
        if (evaluationCalibrationError != null) {
            val calibrationPenalty = max(0.0, 1.0 - evaluationCalibrationError * 2.5)
            effectiveConfidence *= calibrationPenalty
        }

        effectiveConfidence = effectiveConfidence.coerceIn(0.0, 1.0)

        val tier = when {
            effectiveConfidence >= minimumConfidence -> ConfidenceTier.CONFIDENT
            effectiveConfidence >= 0.2 -> ConfidenceTier.SUGGESTIVE
            else -> ConfidenceTier.GATED
        }

        if (tier == ConfidenceTier.GATED) {
            return ConfidenceGate(
                shouldShow = false,
                confidenceScore = effectiveConfidence,
                reason = "Model confidence too low (${(effectiveConfidence * 100).toInt()}%). Need at least 20%.",
                tier = ConfidenceTier.GATED,
            )
        }

        return ConfidenceGate(
            shouldShow = true,
            confidenceScore = effectiveConfidence,
            reason = if (tier == ConfidenceTier.SUGGESTIVE) "Suggestive — based on limited data." else null,
            tier = tier,
        )
    }

    // ---------------------------------------------------------------------------
    // Personalization Blend Weight
    // ---------------------------------------------------------------------------

    /**
     * Compute how much to trust the personalized model vs a base/rule-based model.
     *
     * Uses a sigmoid ramp from 0 days (all base) to rampUpDays (all personalized).
     */
    fun personalizationWeight(
        userDataDays: Int,
        modelAccuracy: Double?,
        rampUpDays: Int = 60,
    ): Double {
        val ramp = rampUpDays.toDouble()
        if (ramp <= 0) return 1.0

        val midpoint = ramp / 2.0
        val steepness = ramp / 6.0
        if (steepness <= 0) return if (userDataDays >= midpoint) 1.0 else 0.0

        val x = (userDataDays.toDouble() - midpoint) / steepness
        var weight = (1.0 / (1.0 + exp(-x))).coerceIn(0.0, 1.0)

        if (modelAccuracy != null) {
            val accuracyFactor = ((modelAccuracy - 0.5) / 0.2).coerceIn(0.0, 1.0)
            weight *= accuracyFactor
        }

        return weight
    }

    // ---------------------------------------------------------------------------
    // Bootstrap Confidence Interval
    // ---------------------------------------------------------------------------

    /**
     * Compute a bootstrap confidence interval for a statistic.
     */
    fun bootstrapInterval(
        values: List<Double>,
        statistic: (List<Double>) -> Double,
        bootstrapCount: Int = 200,
        confidenceLevel: Double = 0.95,
    ): PredictionInterval? {
        if (values.size < 5) return null

        val n = values.size
        val bootstrapStats = (0 until bootstrapCount).map {
            val resample = (0 until n).map { values[(Math.random() * n).toInt().coerceIn(0, n - 1)] }
            statistic(resample)
        }.sorted()

        val alpha = 1.0 - confidenceLevel
        val lowerIndex = max(0, floor(alpha / 2.0 * bootstrapCount).toInt())
        val upperIndex = min(bootstrapCount - 1, ceil((1.0 - alpha / 2.0) * bootstrapCount).toInt() - 1)

        val lower = bootstrapStats[lowerIndex]
        val upper = bootstrapStats[upperIndex]

        return PredictionInterval(lower, upper, confidenceLevel, upper - lower)
    }

    // ---------------------------------------------------------------------------
    // Component Readiness
    // ---------------------------------------------------------------------------

    data class ComponentReadiness(
        val componentName: String,
        val minimumDays: Int,
        val currentDays: Int,
        val isReady: Boolean,
        val readinessPercent: Double,
    )

    /**
     * Check readiness of all ML components given the available data.
     */
    fun checkComponentReadiness(totalDays: Int): List<ComponentReadiness> =
        componentMinimums.entries
            .sortedBy { it.value }
            .map { (name, minimum) ->
                val percent = min(100.0, totalDays.toDouble() / minimum * 100.0)
                ComponentReadiness(
                    componentName = name,
                    minimumDays = minimum,
                    currentDays = totalDays,
                    isReady = totalDays >= minimum,
                    readinessPercent = percent,
                )
            }
}
