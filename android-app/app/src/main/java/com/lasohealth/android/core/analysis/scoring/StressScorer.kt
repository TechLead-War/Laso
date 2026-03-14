package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.roundToInt

// ── Result Type ─────────────────────────────────────────────────────────────

/**
 * Stress level assessment derived from autonomic nervous system indicators.
 *
 * @property score stress score 0-100 (higher = more stress).
 * @property level human-readable label: "Low", "Moderate", "High", "Very High".
 * @property hrvDeviation how far HRV is from baseline (negative = below baseline = stressed).
 * @property hrElevation how far resting HR is above baseline (positive = elevated = stressed).
 */
data class StressScore(
    val score: Double,
    val level: String,
    val hrvDeviation: Double,
    val hrElevation: Double,
)

// ── Scorer ───────────────────────────────────────────────────────────────────

/**
 * Computes a physiological stress score (0-100) from autonomic nervous system markers.
 *
 * Primary signal: **HRV deviation from baseline** — the sympathetic/parasympathetic
 * balance is the gold standard for physiological stress measurement.
 *
 * Secondary signals:
 * - **Resting HR elevation** above baseline — sympathetic activation raises HR.
 * - **Sleep disruption** — poor sleep both reflects and amplifies stress.
 *
 * Weighting:
 * - HRV deviation: 50%
 * - Resting HR elevation: 30%
 * - Sleep disruption: 20%
 *
 * Level labels:
 * - 0-30:  "Low"
 * - 31-60: "Moderate"
 * - 61-80: "High"
 * - 81-100: "Very High"
 */
class StressScorer {

    /**
     * Compute the current stress score.
     *
     * @param timeSeries daily samples for HRV, resting HR, and sleep metrics.
     * @param baselines pre-computed baselines for comparison.
     * @return [StressScore] or a neutral score if insufficient data.
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): StressScore {
        var weightedSum = 0.0
        var totalWeight = 0.0
        var hrvDev = 0.0
        var hrElev = 0.0

        // ── HRV Deviation (50%) ─────────────────────────────────────────────
        val hrvStress = computeHrvStress(timeSeries, baselines)
        if (hrvStress != null) {
            weightedSum += hrvStress.stressContribution * WEIGHT_HRV
            totalWeight += WEIGHT_HRV
            hrvDev = hrvStress.deviation
        }

        // ── Resting HR Elevation (30%) ──────────────────────────────────────
        val rhrStress = computeRhrStress(timeSeries, baselines)
        if (rhrStress != null) {
            weightedSum += rhrStress.stressContribution * WEIGHT_RHR
            totalWeight += WEIGHT_RHR
            hrElev = rhrStress.elevation
        }

        // ── Sleep Disruption (20%) ──────────────────────────────────────────
        val sleepStress = computeSleepStress(timeSeries)
        if (sleepStress != null) {
            weightedSum += sleepStress * WEIGHT_SLEEP
            totalWeight += WEIGHT_SLEEP
        }

        val score = if (totalWeight > 0) {
            (weightedSum / totalWeight).coerceIn(0.0, 100.0)
        } else {
            DEFAULT_STRESS.toDouble()
        }

        return StressScore(
            score = (score * 10).roundToInt() / 10.0,
            level = classifyLevel(score),
            hrvDeviation = (hrvDev * 100).roundToInt() / 100.0,
            hrElevation = (hrElev * 100).roundToInt() / 100.0,
        )
    }

    // ── Sub-Score Calculations ──────────────────────────────────────────────

    private data class HrvStressResult(val stressContribution: Double, val deviation: Double)
    private data class RhrStressResult(val stressContribution: Double, val elevation: Double)

    /**
     * HRV stress: lower HRV vs baseline indicates higher sympathetic activation.
     *
     * z-score < 0 → stressed; z-score > 0 → relaxed.
     * Maps to 0-100 stress contribution.
     */
    private fun computeHrvStress(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): HrvStressResult? {
        val baseline = baselines[HealthMetric.HEART_RATE_VARIABILITY] ?: return null
        val recent = mostRecentValue(timeSeries[HealthMetric.HEART_RATE_VARIABILITY]) ?: return null

        if (baseline.mean <= 0 || baseline.standardDeviation <= 0) return null

        val z = (recent - baseline.mean) / baseline.standardDeviation
        // z = -2 → stress = 90
        // z =  0 → stress = 30
        // z = +2 → stress = 5
        val stress = (30.0 - z * 30.0).coerceIn(0.0, 100.0)

        return HrvStressResult(
            stressContribution = stress,
            deviation = z,
        )
    }

    /**
     * RHR stress: elevated resting HR vs baseline indicates sympathetic activation.
     *
     * z-score > 0 (elevated) → stressed; z-score < 0 (lower) → relaxed.
     */
    private fun computeRhrStress(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): RhrStressResult? {
        val baseline = baselines[HealthMetric.RESTING_HEART_RATE] ?: return null
        val recent = mostRecentValue(timeSeries[HealthMetric.RESTING_HEART_RATE]) ?: return null

        if (baseline.mean <= 0 || baseline.standardDeviation <= 0) return null

        val z = (recent - baseline.mean) / baseline.standardDeviation
        // z = +2 → stress = 90 (much higher than baseline)
        // z =  0 → stress = 30 (at baseline)
        // z = -2 → stress = 5  (lower than baseline)
        val stress = (30.0 + z * 30.0).coerceIn(0.0, 100.0)

        return RhrStressResult(
            stressContribution = stress,
            elevation = z,
        )
    }

    /**
     * Sleep disruption stress: poor sleep quality amplifies stress.
     *
     * Short duration or excessive awake time indicates disrupted sleep.
     */
    private fun computeSleepStress(timeSeries: Map<HealthMetric, List<DailySample>>): Double? {
        val sleepDuration = mostRecentValue(timeSeries[HealthMetric.SLEEP_DURATION]) ?: return null

        // Duration-based stress.
        val durationStress = when {
            sleepDuration >= 7.0 -> 10.0  // good sleep, low stress
            sleepDuration >= 6.0 -> 30.0
            sleepDuration >= 5.0 -> 55.0
            sleepDuration >= 4.0 -> 75.0
            else -> 90.0                   // very poor, high stress
        }

        // If awake time data is available, factor it in.
        val awakeDuration = mostRecentValue(timeSeries[HealthMetric.SLEEP_AWAKE])
        val awakeStress = if (awakeDuration != null && sleepDuration > 0) {
            val awakeRatio = awakeDuration / (sleepDuration + awakeDuration)
            // > 20% awake → high stress; < 5% → low.
            (awakeRatio * 300.0).coerceIn(0.0, 100.0)
        } else {
            null
        }

        return if (awakeStress != null) {
            durationStress * 0.6 + awakeStress * 0.4
        } else {
            durationStress
        }
    }

    // ── Classification ──────────────────────────────────────────────────────

    private fun classifyLevel(score: Double): String = when {
        score <= 30.0 -> "Low"
        score <= 60.0 -> "Moderate"
        score <= 80.0 -> "High"
        else -> "Very High"
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun mostRecentValue(samples: List<DailySample>?): Double? {
        return samples?.maxByOrNull { it.date }?.value
    }

    companion object {
        private const val DEFAULT_STRESS = 30

        private const val WEIGHT_HRV = 0.50
        private const val WEIGHT_RHR = 0.30
        private const val WEIGHT_SLEEP = 0.20
    }
}
