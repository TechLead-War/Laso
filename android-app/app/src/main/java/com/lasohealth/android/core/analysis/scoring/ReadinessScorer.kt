package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Computes a daily readiness score (0-100) indicating how prepared the body is
 * for physical exertion or cognitive demand.
 *
 * Readiness is derived from four pillars:
 * - **Sleep quality** (40%): duration relative to optimal, consistency.
 * - **HRV vs baseline** (25%): higher HRV relative to baseline = better readiness.
 * - **Resting HR vs baseline** (20%): lower resting HR relative to baseline = better readiness.
 * - **Previous-day activity load** (15%): excessive prior strain lowers readiness.
 */
class ReadinessScorer {

    /**
     * Compute today's readiness score.
     *
     * @param timeSeries recent daily samples for all available metrics.
     * @param baselines pre-computed baselines for comparison.
     * @return readiness score 0-100, or 50 if insufficient data.
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Int {
        var weightedSum = 0.0
        var totalWeight = 0.0

        // ── Sleep Quality (40%) ─────────────────────────────────────────────
        val sleepScore = computeSleepScore(timeSeries)
        if (sleepScore != null) {
            weightedSum += sleepScore * WEIGHT_SLEEP
            totalWeight += WEIGHT_SLEEP
        }

        // ── HRV vs Baseline (25%) ──────────────────────────────────────────
        val hrvScore = computeHrvScore(timeSeries, baselines)
        if (hrvScore != null) {
            weightedSum += hrvScore * WEIGHT_HRV
            totalWeight += WEIGHT_HRV
        }

        // ── Resting HR vs Baseline (20%) ────────────────────────────────────
        val rhrScore = computeRhrScore(timeSeries, baselines)
        if (rhrScore != null) {
            weightedSum += rhrScore * WEIGHT_RHR
            totalWeight += WEIGHT_RHR
        }

        // ── Previous-Day Activity Load (15%) ────────────────────────────────
        val loadScore = computeActivityLoadScore(timeSeries, baselines)
        if (loadScore != null) {
            weightedSum += loadScore * WEIGHT_LOAD
            totalWeight += WEIGHT_LOAD
        }

        if (totalWeight <= 0.0) return DEFAULT_READINESS

        return (weightedSum / totalWeight).roundToInt().coerceIn(0, 100)
    }

    // ── Sub-Score Calculations ──────────────────────────────────────────────

    /**
     * Sleep quality sub-score (0-100).
     *
     * Duration factor: 7-8 hours is optimal (score 100). Below 5h or above 10h
     * scores poorly. Consistency factor: low variance across recent nights is better.
     */
    private fun computeSleepScore(timeSeries: Map<HealthMetric, List<DailySample>>): Double? {
        val sleepSamples = recentSamples(timeSeries[HealthMetric.SLEEP_DURATION], days = 7)
            ?: return null

        val lastNight = sleepSamples.maxByOrNull { it.date }?.value ?: return null

        // Duration factor: bell curve centred at 7.5h.
        val durationScore = durationFactor(lastNight)

        // Consistency factor: standard deviation of last 7 nights.
        val values = sleepSamples.map { it.value }
        val mean = values.average()
        val stdDev = kotlin.math.sqrt(values.sumOf { (it - mean) * (it - mean) } / values.size)
        // Low variance (< 0.5h) = 100, high variance (> 2h) = 40.
        val consistencyScore = (100.0 - (stdDev - 0.5).coerceAtLeast(0.0) * 40.0).coerceIn(40.0, 100.0)

        // Blend: 70% duration, 30% consistency.
        return durationScore * 0.7 + consistencyScore * 0.3
    }

    /**
     * HRV sub-score (0-100). Higher HRV relative to baseline = better readiness.
     */
    private fun computeHrvScore(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Double? {
        val baseline = baselines[HealthMetric.HEART_RATE_VARIABILITY] ?: return null
        val recent = mostRecentValue(timeSeries[HealthMetric.HEART_RATE_VARIABILITY]) ?: return null

        if (baseline.mean <= 0 || baseline.standardDeviation <= 0) return null

        // z-score: how many SDs above/below baseline.
        val z = (recent - baseline.mean) / baseline.standardDeviation

        // Map z-score to 0-100:
        // z = +2  → 100 (well above baseline)
        // z =  0  → 70  (at baseline)
        // z = -2  → 30  (well below baseline)
        return (70.0 + z * 15.0).coerceIn(0.0, 100.0)
    }

    /**
     * Resting HR sub-score (0-100). Lower RHR relative to baseline = better readiness.
     */
    private fun computeRhrScore(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Double? {
        val baseline = baselines[HealthMetric.RESTING_HEART_RATE] ?: return null
        val recent = mostRecentValue(timeSeries[HealthMetric.RESTING_HEART_RATE]) ?: return null

        if (baseline.mean <= 0 || baseline.standardDeviation <= 0) return null

        // Inverted z-score: lower than baseline is good.
        val z = (baseline.mean - recent) / baseline.standardDeviation

        // z = +2  → 100 (much lower than baseline, great)
        // z =  0  → 70  (at baseline)
        // z = -2  → 30  (elevated, poor readiness)
        return (70.0 + z * 15.0).coerceIn(0.0, 100.0)
    }

    /**
     * Activity load sub-score (0-100). Excessive yesterday = lower readiness today.
     */
    private fun computeActivityLoadScore(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Double? {
        val baseline = baselines[HealthMetric.ACTIVE_CALORIES] ?: return null
        val samples = timeSeries[HealthMetric.ACTIVE_CALORIES]
        val yesterday = samples
            ?.sortedByDescending { it.date }
            ?.drop(1) // skip today
            ?.firstOrNull()?.value
            ?: return null

        if (baseline.mean <= 0) return null

        val ratio = yesterday / baseline.mean

        // ratio 0.5 → 90 (light day, well recovered)
        // ratio 1.0 → 70 (normal)
        // ratio 2.0 → 30 (very heavy day)
        return (90.0 - (ratio - 0.5).coerceAtLeast(0.0) * 40.0).coerceIn(0.0, 100.0)
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Get the most recent value for a metric. */
    private fun mostRecentValue(samples: List<DailySample>?): Double? {
        return samples?.maxByOrNull { it.date }?.value
    }

    /** Filter to samples within the last [days]. Requires at least 3. */
    private fun recentSamples(samples: List<DailySample>?, days: Int): List<DailySample>? {
        if (samples.isNullOrEmpty()) return null
        val sorted = samples.sortedByDescending { it.date }
        val cutoff = sorted.first().date - days * MILLIS_PER_DAY
        val recent = sorted.filter { it.date >= cutoff }
        return if (recent.size >= MIN_SAMPLES) recent else null
    }

    /** Duration factor: bell curve around 7.5h optimal. */
    private fun durationFactor(hours: Double): Double {
        val optimal = 7.5
        val deviation = abs(hours - optimal)
        return when {
            deviation < 0.5 -> 100.0
            deviation < 1.0 -> 90.0
            deviation < 1.5 -> 75.0
            deviation < 2.0 -> 60.0
            deviation < 2.5 -> 45.0
            else -> 30.0
        }
    }

    companion object {
        private const val MILLIS_PER_DAY = 86_400_000L
        private const val MIN_SAMPLES = 3
        private const val DEFAULT_READINESS = 50

        private const val WEIGHT_SLEEP = 0.40
        private const val WEIGHT_HRV = 0.25
        private const val WEIGHT_RHR = 0.20
        private const val WEIGHT_LOAD = 0.15
    }
}
