package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.ln
import kotlin.math.roundToInt

// ── Result Type ─────────────────────────────────────────────────────────────

/**
 * Daily strain score on a 0-21 logarithmic scale (inspired by WHOOP).
 *
 * @property score strain score 0.0 - 21.0.
 * @property level human-readable level: "Light", "Moderate", "High", "All Out".
 * @property targetMin lower bound of today's recommended strain target.
 * @property targetMax upper bound of today's recommended strain target.
 * @property balance "Under-recovery", "Optimal", or "Overreaching".
 */
data class StrainScore(
    val score: Double,
    val level: String,
    val targetMin: Double,
    val targetMax: Double,
    val balance: String,
)

// ── Scorer ───────────────────────────────────────────────────────────────────

/**
 * Computes a daily strain score on a 0-21 logarithmic scale.
 *
 * Strain accumulates from four sources:
 * - **Active calories**: base energy expenditure above resting.
 * - **Exercise minutes**: duration of structured exercise.
 * - **Heart rate zones**: weighted by zone intensity (exponential).
 * - **Step count**: base movement contribution.
 *
 * Heart rate zones contribute with exponentially increasing weights:
 * - Zone 1 (50-60% max HR): 1x
 * - Zone 2 (60-70%): 2x
 * - Zone 3 (70-80%): 4x
 * - Zone 4 (80-90%): 8x
 * - Zone 5 (90-100%): 16x
 *
 * The raw load is mapped to 0-21 using a natural log scaling function,
 * matching the non-linear physiological stress curve.
 */
class StrainScorer {

    /**
     * Compute today's strain score.
     *
     * @param timeSeries daily samples for relevant metrics.
     * @param readinessScore optional readiness score (0-100) to adjust the target range.
     *   Higher readiness allows higher strain targets.
     * @return [StrainScore] with score, level, target range, and balance assessment.
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        readinessScore: Int = DEFAULT_READINESS,
    ): StrainScore {
        val rawLoad = computeRawLoad(timeSeries)
        val strainScore = rawLoadToStrain(rawLoad)

        val level = classifyLevel(strainScore)
        val (targetMin, targetMax) = computeTargetRange(readinessScore)
        val balance = assessBalance(strainScore, targetMin, targetMax)

        return StrainScore(
            score = (strainScore * 10).roundToInt() / 10.0, // round to 1 decimal
            level = level,
            targetMin = targetMin,
            targetMax = targetMax,
            balance = balance,
        )
    }

    // ── Raw Load Computation ────────────────────────────────────────────────

    /**
     * Accumulate a raw load value from all contributing metrics.
     *
     * Each metric contributes a normalised amount that, once summed, represents
     * the total physiological demand of the day.
     */
    private fun computeRawLoad(timeSeries: Map<HealthMetric, List<DailySample>>): Double {
        var load = 0.0

        // Active calories contribution (baseline ~300 kcal/day for moderate person).
        todayValue(timeSeries[HealthMetric.ACTIVE_CALORIES])?.let { cals ->
            load += cals / CALORIES_NORMALISER
        }

        // Exercise minutes contribution.
        todayValue(timeSeries[HealthMetric.EXERCISE_MINUTES])?.let { mins ->
            load += mins / EXERCISE_MINUTES_NORMALISER
        }

        // Steps contribution (secondary).
        todayValue(timeSeries[HealthMetric.STEPS])?.let { steps ->
            load += steps / STEPS_NORMALISER
        }

        // Heart rate zone contribution (from workout data if available).
        // Use exercise minutes as a proxy for zone distribution if HR zones
        // are not explicitly tracked. Workout count amplifies.
        val workoutCount = todayValue(timeSeries[HealthMetric.WORKOUT_COUNT]) ?: 0.0
        val exerciseMins = todayValue(timeSeries[HealthMetric.EXERCISE_MINUTES]) ?: 0.0

        if (exerciseMins > 0 && workoutCount > 0) {
            // Estimate zone distribution from exercise intensity.
            // Without explicit zone data, allocate minutes across zones.
            val zoneLoad = estimateZoneLoad(exerciseMins, workoutCount)
            load += zoneLoad
        }

        return load
    }

    /**
     * Estimate heart rate zone load from exercise minutes and workout count.
     *
     * Without explicit zone tracking, we use heuristics:
     * - Short, intense workouts → more time in zones 3-5.
     * - Long, moderate sessions → more time in zones 1-2.
     */
    private fun estimateZoneLoad(exerciseMinutes: Double, workoutCount: Double): Double {
        val avgDuration = if (workoutCount > 0) exerciseMinutes / workoutCount else exerciseMinutes
        val intensityFactor = when {
            avgDuration < 20 -> 0.7 // short = likely intense
            avgDuration < 45 -> 0.5 // moderate
            else -> 0.3             // long = likely steady-state
        }

        // Distribute minutes across zones based on intensity factor.
        val z1Mins = exerciseMinutes * (1.0 - intensityFactor) * 0.5
        val z2Mins = exerciseMinutes * (1.0 - intensityFactor) * 0.5
        val z3Mins = exerciseMinutes * intensityFactor * 0.5
        val z4Mins = exerciseMinutes * intensityFactor * 0.3
        val z5Mins = exerciseMinutes * intensityFactor * 0.2

        return (z1Mins * ZONE_1_MULTIPLIER +
                z2Mins * ZONE_2_MULTIPLIER +
                z3Mins * ZONE_3_MULTIPLIER +
                z4Mins * ZONE_4_MULTIPLIER +
                z5Mins * ZONE_5_MULTIPLIER) / ZONE_NORMALISER
    }

    // ── Scaling & Classification ────────────────────────────────────────────

    /**
     * Map raw load to 0-21 strain using natural log scaling.
     *
     * The formula: strain = (21 / ln(maxLoad + 1)) * ln(rawLoad + 1)
     * ensures the scale is logarithmic — small loads accumulate quickly,
     * while reaching 18+ requires extreme effort.
     */
    private fun rawLoadToStrain(rawLoad: Double): Double {
        if (rawLoad <= 0) return 0.0
        val maxExpectedLoad = 12.0 // normalised load for an "all out" day
        val scale = MAX_STRAIN / ln(maxExpectedLoad + 1.0)
        return (scale * ln(rawLoad + 1.0)).coerceIn(0.0, MAX_STRAIN)
    }

    /** Classify strain level from score. */
    private fun classifyLevel(strain: Double): String = when {
        strain < 5.0 -> "Light"
        strain < 10.0 -> "Moderate"
        strain < 14.0 -> "High"
        strain < 18.0 -> "Strenuous"
        else -> "All Out"
    }

    /**
     * Compute target strain range based on readiness.
     *
     * High readiness (80+) → target 10-14 (can push hard).
     * Medium readiness (50-79) → target 7-11 (moderate day).
     * Low readiness (<50) → target 3-7 (recovery day).
     */
    private fun computeTargetRange(readiness: Int): Pair<Double, Double> = when {
        readiness >= 80 -> 10.0 to 14.0
        readiness >= 60 -> 7.0 to 11.0
        readiness >= 40 -> 4.0 to 8.0
        else -> 2.0 to 5.0
    }

    /** Assess balance between strain and target. */
    private fun assessBalance(strain: Double, targetMin: Double, targetMax: Double): String = when {
        strain < targetMin * 0.7 -> "Under-recovery"
        strain > targetMax * 1.3 -> "Overreaching"
        strain in targetMin..targetMax -> "Optimal"
        strain < targetMin -> "Below Target"
        else -> "Above Target"
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Get today's (most recent) value for a metric. */
    private fun todayValue(samples: List<DailySample>?): Double? {
        return samples?.maxByOrNull { it.date }?.value
    }

    companion object {
        private const val MAX_STRAIN = 21.0
        private const val DEFAULT_READINESS = 50

        // Normalisation constants to bring each metric's contribution
        // into a comparable range (~0-3 each for a typical day).
        private const val CALORIES_NORMALISER = 200.0  // 200 kcal → 1 unit
        private const val EXERCISE_MINUTES_NORMALISER = 30.0 // 30 min → 1 unit
        private const val STEPS_NORMALISER = 5000.0    // 5000 steps → 1 unit

        // Heart rate zone multipliers (exponential weighting).
        private const val ZONE_1_MULTIPLIER = 1.0
        private const val ZONE_2_MULTIPLIER = 2.0
        private const val ZONE_3_MULTIPLIER = 4.0
        private const val ZONE_4_MULTIPLIER = 8.0
        private const val ZONE_5_MULTIPLIER = 16.0
        private const val ZONE_NORMALISER = 200.0 // scale zone-minutes back to load units
    }
}
