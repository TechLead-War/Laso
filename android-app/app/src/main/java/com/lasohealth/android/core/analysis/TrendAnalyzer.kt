package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Detects trends in health metric time series using ordinary least-squares (OLS) linear regression.
 *
 * For each metric the analyzer fits `y = a + b*x` where `x` is the day index and `y` is the
 * metric value. The slope `b` determines [TrendDirection], and normalising by baseline standard
 * deviation produces a [RateOfChange] classification.
 *
 * Requires at least [MIN_SAMPLES] data points within the requested [periodDays] window.
 */
class TrendAnalyzer {

    /**
     * Analyse a single metric's samples over the most recent [periodDays].
     *
     * @return a [MetricTrend] or `null` if there are fewer than [MIN_SAMPLES] samples.
     */
    fun analyze(samples: List<DailySample>, periodDays: Int = DEFAULT_PERIOD_DAYS): MetricTrend? {
        if (samples.size < MIN_SAMPLES) return null

        val sorted = samples.sortedBy { it.date }
        val metric = sorted.first().metric

        // Use only the most recent `periodDays` worth of samples.
        val cutoff = sorted.last().date - periodDays * MILLIS_PER_DAY
        val window = sorted.filter { it.date >= cutoff }
        if (window.size < MIN_SAMPLES) return null

        // Day index relative to the first sample in the window.
        val originDate = window.first().date
        val xs = window.map { ((it.date - originDate).toDouble() / MILLIS_PER_DAY) }
        val ys = window.map { it.value }

        val n = xs.size.toDouble()
        val sumX = xs.sum()
        val sumY = ys.sum()
        val sumXY = xs.zip(ys).sumOf { (x, y) -> x * y }
        val sumX2 = xs.sumOf { it * it }

        val denominator = n * sumX2 - sumX * sumX
        if (denominator == 0.0) {
            return MetricTrend(
                metric = metric,
                direction = TrendDirection.INSUFFICIENT_DATA,
                rateOfChange = 0.0,
                confidence = 0.0,
                periodDays = periodDays,
            )
        }

        val slope = (n * sumXY - sumX * sumY) / denominator
        val intercept = (sumY - slope * sumX) / n

        // --- R-squared as a confidence proxy ---
        val yMean = sumY / n
        val ssTot = ys.sumOf { (it - yMean) * (it - yMean) }
        val ssRes = xs.zip(ys).sumOf { (x, y) ->
            val predicted = intercept + slope * x
            (y - predicted) * (y - predicted)
        }
        val rSquared = if (ssTot > 0.0) 1.0 - (ssRes / ssTot) else 0.0

        // --- Standard error of slope for significance test ---
        val slopeSignificant = if (n > 2 && ssTot > 0.0) {
            val sResidual = sqrt(ssRes / (n - 2.0))
            val sXX = sumX2 - (sumX * sumX) / n
            if (sXX > 0.0) {
                val seSlopeVal = sResidual / sqrt(sXX)
                // t-statistic: slope / SE(slope); we treat |t| > 2 as significant.
                abs(slope / seSlopeVal) > SIGNIFICANCE_T_THRESHOLD
            } else {
                false
            }
        } else {
            false
        }

        val direction = when {
            !slopeSignificant -> TrendDirection.STABLE
            slope > 0 -> TrendDirection.RISING
            slope < 0 -> TrendDirection.FALLING
            else -> TrendDirection.STABLE
        }

        return MetricTrend(
            metric = metric,
            direction = direction,
            rateOfChange = slope,
            confidence = rSquared.coerceIn(0.0, 1.0),
            periodDays = periodDays,
        )
    }

    /**
     * Analyse all metrics in the provided [timeSeries].
     *
     * Metrics with insufficient data are silently omitted.
     */
    fun analyzeAll(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        periodDays: Int = DEFAULT_PERIOD_DAYS,
    ): Map<HealthMetric, MetricTrend> =
        timeSeries.mapNotNull { (metric, samples) ->
            analyze(samples, periodDays)?.let { metric to it }
        }.toMap()

    companion object {
        /** Minimum samples required to run regression. */
        const val MIN_SAMPLES = 7
        /** Default look-back period in days. */
        const val DEFAULT_PERIOD_DAYS = 30
        /** Milliseconds in one day. */
        const val MILLIS_PER_DAY = 86_400_000L
        /** |t| threshold for treating the slope as statistically significant. */
        const val SIGNIFICANCE_T_THRESHOLD = 2.0
    }
}
