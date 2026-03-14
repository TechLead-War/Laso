package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.exp

/**
 * Computes a composite health score (0-100) from daily samples, baselines, and trends.
 *
 * Scoring pipeline:
 * 1. Per-metric score (0-100): how close the latest value is to the metric's optimal range,
 *    with a bonus/penalty for recent trend direction.
 * 2. Per-category score: weighted average of metric scores within the category.
 * 3. Overall score: weighted average of category scores using [CATEGORY_WEIGHTS].
 */
class HealthScorer {

    /**
     * Produce a [HealthScore] from the current analysis state.
     *
     * Metrics with no samples or no baseline are omitted; categories with zero contributing
     * metrics receive a neutral score of [NEUTRAL_SCORE].
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthScore {
        // --- Per-metric scores ---
        val metricScores = mutableMapOf<HealthMetric, Double>()

        for ((metric, samples) in timeSeries) {
            val baseline = baselines[metric] ?: continue
            val sorted = samples.sortedBy { it.date }
            if (sorted.isEmpty()) continue

            val latestValue = sorted.last().value
            val baseScore = scoreMetricValue(metric, latestValue, baseline)

            // Trend adjustment: reward favourable trends, penalise adverse ones.
            val trend = trends[metric]
            val trendBonus = if (trend != null) trendAdjustment(metric, trend) else 0.0

            metricScores[metric] = (baseScore + trendBonus).coerceIn(0.0, 100.0)
        }

        // --- Per-category scores ---
        val categoryScores = mutableMapOf<HealthCategory, Int>()
        for (category in HealthCategory.entries) {
            val categoryMetrics = metricScores.filterKeys { it.category == category }
            if (categoryMetrics.isEmpty()) {
                categoryScores[category] = NEUTRAL_SCORE
            } else {
                categoryScores[category] = categoryMetrics.values.average().toInt().coerceIn(0, 100)
            }
        }

        // --- Overall score ---
        var weightedSum = 0.0
        var totalWeight = 0.0
        for ((category, catScore) in categoryScores) {
            val weight = CATEGORY_WEIGHTS[category] ?: DEFAULT_CATEGORY_WEIGHT
            weightedSum += catScore * weight
            totalWeight += weight
        }
        val overall = if (totalWeight > 0.0) {
            (weightedSum / totalWeight).toInt().coerceIn(0, 100)
        } else {
            NEUTRAL_SCORE
        }

        // Contributions: normalise metric scores into [0, 1] range for downstream consumers.
        val contributions = metricScores.mapValues { (_, score) -> score / 100.0 }

        return HealthScore(
            overall = overall,
            categoryScores = categoryScores,
            contributions = contributions,
        )
    }

    // ----- internal helpers -----

    /**
     * Score a single metric value (0-100) based on its deviation from baseline.
     *
     * Uses a Gaussian-like decay: score drops as the value moves away from the baseline mean.
     * For metrics where [HealthMetric.higherIsBetter] is true, values above the mean are
     * rewarded; for metrics where lower is better, values below the mean are rewarded.
     */
    private fun scoreMetricValue(
        metric: HealthMetric,
        value: Double,
        baseline: MetricBaseline,
    ): Double {
        if (baseline.standardDeviation <= 0.0) return NEUTRAL_SCORE.toDouble()

        val zScore = (value - baseline.mean) / baseline.standardDeviation

        // Directional z-score: positive = good, negative = bad.
        val directionalZ = if (metric.higherIsBetter) zScore else -zScore

        // Gaussian-like mapping centered on 0 with bonus for favorable direction.
        // directionalZ = 0 -> 70 (baseline), +2 -> ~90, -2 -> ~40.
        val raw = BASELINE_SCORE + DIRECTION_SCALE * directionalZ * exp(-abs(directionalZ) * DECAY_RATE)

        return raw.coerceIn(0.0, 100.0)
    }

    /**
     * Bonus (or penalty) points from trend direction.
     */
    private fun trendAdjustment(metric: HealthMetric, trend: MetricTrend): Double {
        val favorableDirection = when {
            metric.higherIsBetter && trend.direction == TrendDirection.RISING -> true
            metric.higherIsBetter && trend.direction == TrendDirection.FALLING -> false
            !metric.higherIsBetter && trend.direction == TrendDirection.FALLING -> true
            !metric.higherIsBetter && trend.direction == TrendDirection.RISING -> false
            else -> return 0.0 // STABLE or INSUFFICIENT_DATA
        }

        val magnitude = trend.confidence.coerceIn(0.0, 1.0) * MAX_TREND_BONUS
        return if (favorableDirection) magnitude else -magnitude
    }

    companion object {
        /** Category weights for the overall score. Must sum to ~1.0. */
        val CATEGORY_WEIGHTS: Map<HealthCategory, Double> = mapOf(
            HealthCategory.HEART to 0.25,
            HealthCategory.SLEEP to 0.25,
            HealthCategory.ACTIVITY to 0.20,
            HealthCategory.BODY to 0.10,
            HealthCategory.RESPIRATORY to 0.10,
            HealthCategory.MINDFULNESS to 0.05,
            HealthCategory.MOBILITY to 0.05,
        )

        /** Fallback weight for categories not in the weight map (e.g. NUTRITION, HEARING). */
        const val DEFAULT_CATEGORY_WEIGHT = 0.02

        /** Score assigned when no data is available. */
        const val NEUTRAL_SCORE = 50

        // Scoring curve parameters
        private const val BASELINE_SCORE = 70.0
        private const val DIRECTION_SCALE = 15.0
        private const val DECAY_RATE = 0.3
        private const val MAX_TREND_BONUS = 5.0
    }
}
