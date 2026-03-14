package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.sqrt

/**
 * Computes [MetricBaseline]s from raw daily samples.
 *
 * Uses an exponentially weighted moving average (EWMA) with [alpha] = 0.1 to give
 * more weight to recent observations while retaining a smooth long-term baseline.
 * Standard deviation is computed from the most recent [windowDays] samples.
 *
 * Requires at least [MIN_SAMPLES] data points to produce a baseline.
 */
class BaselineCalculator(
    private val alpha: Double = DEFAULT_ALPHA,
    private val windowDays: Int = DEFAULT_WINDOW_DAYS,
) {
    /**
     * Calculate a [MetricBaseline] from a list of daily samples for a single metric.
     *
     * Samples are sorted by date ascending internally. Returns `null` if fewer than
     * [MIN_SAMPLES] samples are provided.
     */
    fun calculate(samples: List<DailySample>): MetricBaseline? {
        if (samples.size < MIN_SAMPLES) return null

        val sorted = samples.sortedBy { it.date }
        val metric = sorted.first().metric

        // --- EWMA mean ---
        var ewma = sorted.first().value
        for (i in 1 until sorted.size) {
            ewma = alpha * sorted[i].value + (1.0 - alpha) * ewma
        }

        // --- Standard deviation from the most recent windowDays ---
        val recentValues = if (sorted.size > windowDays) {
            sorted.takeLast(windowDays).map { it.value }
        } else {
            sorted.map { it.value }
        }

        val recentMean = recentValues.average()
        val variance = recentValues.sumOf { (it - recentMean) * (it - recentMean) } / recentValues.size
        val stdDev = sqrt(variance)

        return MetricBaseline(
            metric = metric,
            mean = ewma,
            standardDeviation = stdDev,
            sampleCount = sorted.size,
            lastUpdated = sorted.last().date,
        )
    }

    /**
     * Calculate baselines for every metric present in [timeSeries].
     *
     * Metrics with fewer than [MIN_SAMPLES] samples are silently omitted from the result.
     */
    fun calculateAll(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ): Map<HealthMetric, MetricBaseline> =
        timeSeries.mapNotNull { (metric, samples) ->
            calculate(samples)?.let { metric to it }
        }.toMap()

    companion object {
        /** Minimum number of daily samples required to compute a baseline. */
        const val MIN_SAMPLES = 7
        /** Default EWMA smoothing factor. */
        const val DEFAULT_ALPHA = 0.1
        /** Default number of recent days used for standard deviation. */
        const val DEFAULT_WINDOW_DAYS = 30
    }
}
