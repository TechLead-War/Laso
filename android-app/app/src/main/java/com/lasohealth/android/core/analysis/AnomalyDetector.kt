package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs

/**
 * Detects anomalous daily samples by comparing each value against its metric's [MetricBaseline].
 *
 * Classification thresholds (absolute z-score):
 * - >= [SEVERE_THRESHOLD]   (3.0) -> [AnomalySeverity.SEVERE]
 * - >= [MODERATE_THRESHOLD] (2.5) -> [AnomalySeverity.MODERATE]
 * - >= [MILD_THRESHOLD]     (2.0) -> [AnomalySeverity.MILD]
 * - below 2.0               -> not flagged
 */
class AnomalyDetector {

    /**
     * Detect anomalies in [samples] for a single metric given its [baseline].
     *
     * Only samples whose absolute z-score meets or exceeds [MILD_THRESHOLD] are returned.
     * If the baseline has zero standard deviation (no variance), no anomalies are reported.
     */
    fun detect(
        samples: List<DailySample>,
        baseline: MetricBaseline,
    ): List<MetricAnomaly> {
        if (baseline.standardDeviation <= 0.0) return emptyList()

        return samples.mapNotNull { sample ->
            val z = (sample.value - baseline.mean) / baseline.standardDeviation
            val absZ = abs(z)
            val severity = classifySeverity(absZ) ?: return@mapNotNull null

            MetricAnomaly(
                metric = sample.metric,
                value = sample.value,
                expected = baseline.mean,
                zScore = z,
                severity = severity,
                timestamp = sample.date,
            )
        }
    }

    /**
     * Detect anomalies across all metrics in [timeSeries] using the matching entries in [baselines].
     *
     * Metrics without a baseline are silently skipped.
     */
    fun detectAll(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): List<MetricAnomaly> =
        timeSeries.flatMap { (metric, samples) ->
            val baseline = baselines[metric] ?: return@flatMap emptyList()
            detect(samples, baseline)
        }

    companion object {
        const val MILD_THRESHOLD = 2.0
        const val MODERATE_THRESHOLD = 2.5
        const val SEVERE_THRESHOLD = 3.0

        /**
         * Map an absolute z-score to an [AnomalySeverity], or `null` if below the mild threshold.
         */
        fun classifySeverity(absZScore: Double): AnomalySeverity? = when {
            absZScore >= SEVERE_THRESHOLD -> AnomalySeverity.SEVERE
            absZScore >= MODERATE_THRESHOLD -> AnomalySeverity.MODERATE
            absZScore >= MILD_THRESHOLD -> AnomalySeverity.MILD
            else -> null
        }
    }
}
