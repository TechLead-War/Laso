package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

// ── Result Type ─────────────────────────────────────────────────────────────

/**
 * Brain health composite score with sub-dimension breakdown.
 *
 * @property score overall brain health score (0-100).
 * @property grade letter grade: A (90+), B (75-89), C (60-74), D (45-59), F (<45).
 * @property cognitiveReadiness readiness for cognitive tasks (0-100).
 * @property memoryRecovery quality of sleep-dependent memory consolidation (0-100).
 * @property stressCognitionLoad inverse stress impact on cognition (0-100).
 * @property neurovascularFitness brain blood flow & oxygenation (0-100).
 * @property circadianAlignment regularity of sleep-wake cycle (0-100).
 * @property factors top contributing factors with impact labels.
 */
data class BrainHealthScore(
    val score: Int,
    val grade: String,
    val cognitiveReadiness: Int,
    val memoryRecovery: Int,
    val stressCognitionLoad: Int,
    val neurovascularFitness: Int,
    val circadianAlignment: Int,
    val factors: List<BrainFactor>,
)

data class BrainFactor(
    val label: String,
    val impact: String,
    val isPositive: Boolean,
)

// ── Scorer ───────────────────────────────────────────────────────────────────

/**
 * Computes a composite brain health score from physiological data.
 *
 * The brain health model is built on five dimensions, each informed by
 * neuroscience research linking peripheral biomarkers to cognitive function:
 *
 * | Dimension              | Weight | Primary Metrics                      |
 * |------------------------|--------|--------------------------------------|
 * | Sleep quality          |  30%   | Duration, deep sleep, consistency    |
 * | Stress (inverse)       |  20%   | Passed in as stressScore             |
 * | HRV                    |  20%   | HRV vs baseline                     |
 * | Exercise               |  15%   | Active cals, exercise minutes        |
 * | Blood oxygen           |  15%   | SpO2                                |
 *
 * Sub-scores are mapped to five neurocognitive dimensions:
 * - **Cognitive Readiness**: HRV + sleep quality.
 * - **Memory Recovery**: deep sleep + total sleep duration.
 * - **Stress-Cognition Load**: inverse of stress score.
 * - **Neurovascular Fitness**: blood oxygen + exercise.
 * - **Circadian Alignment**: sleep consistency.
 */
class BrainHealthScorer {

    /**
     * Compute the brain health score.
     *
     * @param timeSeries daily samples for all available metrics.
     * @param baselines pre-computed baselines for comparison.
     * @param stressScore current stress score (0-100); higher = more stress.
     * @return [BrainHealthScore] with overall score, grade, and sub-dimensions.
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        stressScore: Double,
    ): BrainHealthScore {
        // ── Compute pillar scores ───────────────────────────────────────────
        val sleepQuality = computeSleepQuality(timeSeries)
        val hrvScore = computeHrvScore(timeSeries, baselines)
        val exerciseScore = computeExerciseScore(timeSeries)
        val oxygenScore = computeOxygenScore(timeSeries)
        val stressInverse = (100.0 - stressScore).coerceIn(0.0, 100.0)

        // ── Weighted composite ──────────────────────────────────────────────
        var weightedSum = 0.0
        var totalWeight = 0.0

        fun addPillar(score: Double?, weight: Double) {
            if (score != null) {
                weightedSum += score * weight
                totalWeight += weight
            }
        }

        addPillar(sleepQuality, WEIGHT_SLEEP)
        addPillar(stressInverse, WEIGHT_STRESS)
        addPillar(hrvScore, WEIGHT_HRV)
        addPillar(exerciseScore, WEIGHT_EXERCISE)
        addPillar(oxygenScore, WEIGHT_OXYGEN)

        val overall = if (totalWeight > 0) {
            (weightedSum / totalWeight).roundToInt().coerceIn(0, 100)
        } else {
            50
        }

        // ── Sub-dimensions ──────────────────────────────────────────────────
        val cognitiveReadiness = combineScores(hrvScore ?: 50.0, sleepQuality ?: 50.0, 0.5, 0.5)
        val memoryRecovery = computeMemoryRecovery(timeSeries, sleepQuality ?: 50.0)
        val stressCognitionLoad = stressInverse.roundToInt().coerceIn(0, 100)
        val neurovascularFitness = combineScores(oxygenScore ?: 50.0, exerciseScore ?: 50.0, 0.5, 0.5)
        val circadianAlignment = computeCircadianAlignment(timeSeries)

        // ── Top factors ─────────────────────────────────────────────────────
        val factors = buildFactors(sleepQuality, hrvScore, exerciseScore, oxygenScore, stressInverse)

        return BrainHealthScore(
            score = overall,
            grade = toGrade(overall),
            cognitiveReadiness = cognitiveReadiness,
            memoryRecovery = memoryRecovery,
            stressCognitionLoad = stressCognitionLoad,
            neurovascularFitness = neurovascularFitness,
            circadianAlignment = circadianAlignment,
            factors = factors,
        )
    }

    // ── Pillar Calculations ─────────────────────────────────────────────────

    /**
     * Sleep quality score for brain health (0-100).
     * Deep sleep is especially important for memory consolidation and glymphatic clearance.
     */
    private fun computeSleepQuality(timeSeries: Map<HealthMetric, List<DailySample>>): Double? {
        val sleepDuration = recentAverage(timeSeries[HealthMetric.SLEEP_DURATION], days = 7)
            ?: return null

        // Duration factor: 7-9h optimal for brain health.
        val durationScore = when {
            sleepDuration in 7.0..9.0 -> 90.0 + (sleepDuration - 7.0) * 5.0
            sleepDuration in 6.0..7.0 -> 60.0 + (sleepDuration - 6.0) * 30.0
            sleepDuration > 9.0 -> 90.0 - (sleepDuration - 9.0) * 15.0
            sleepDuration in 5.0..6.0 -> 40.0 + (sleepDuration - 5.0) * 20.0
            else -> 25.0
        }.coerceIn(0.0, 100.0)

        // Deep sleep factor (if available).
        val deepSleep = recentAverage(timeSeries[HealthMetric.SLEEP_DEEP], days = 7)
        val deepScore = if (deepSleep != null && sleepDuration > 0) {
            val deepPercent = (deepSleep / sleepDuration) * 100.0
            when {
                deepPercent >= 20 -> 95.0
                deepPercent >= 15 -> 80.0
                deepPercent >= 10 -> 60.0
                deepPercent >= 5 -> 40.0
                else -> 20.0
            }
        } else {
            null
        }

        return if (deepScore != null) {
            durationScore * 0.5 + deepScore * 0.5
        } else {
            durationScore
        }
    }

    /** HRV vs baseline: higher parasympathetic tone supports cognitive function. */
    private fun computeHrvScore(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Double? {
        val baseline = baselines[HealthMetric.HEART_RATE_VARIABILITY] ?: return null
        val recent = recentAverage(timeSeries[HealthMetric.HEART_RATE_VARIABILITY], days = 7)
            ?: return null

        if (baseline.mean <= 0 || baseline.standardDeviation <= 0) return null

        val z = (recent - baseline.mean) / baseline.standardDeviation
        // z = +2 → 95, z = 0 → 65, z = -2 → 25
        return (65.0 + z * 15.0).coerceIn(0.0, 100.0)
    }

    /** Exercise: regular physical activity supports BDNF and cerebral blood flow. */
    private fun computeExerciseScore(timeSeries: Map<HealthMetric, List<DailySample>>): Double? {
        val exerciseMins = recentAverage(timeSeries[HealthMetric.EXERCISE_MINUTES], days = 7)
        val activeCals = recentAverage(timeSeries[HealthMetric.ACTIVE_CALORIES], days = 7)

        if (exerciseMins == null && activeCals == null) return null

        // Exercise minutes score: 30+ min/day optimal.
        val minsScore = if (exerciseMins != null) {
            when {
                exerciseMins >= 30 -> 90.0 + (exerciseMins - 30).coerceAtMost(30.0) / 3.0
                exerciseMins >= 20 -> 70.0 + (exerciseMins - 20) * 2.0
                exerciseMins >= 10 -> 50.0 + (exerciseMins - 10) * 2.0
                else -> 30.0 + exerciseMins * 2.0
            }.coerceIn(0.0, 100.0)
        } else {
            null
        }

        // Active calories score: 300+ kcal/day is good.
        val calsScore = if (activeCals != null) {
            when {
                activeCals >= 400 -> 95.0
                activeCals >= 300 -> 80.0
                activeCals >= 200 -> 65.0
                activeCals >= 100 -> 45.0
                else -> 25.0
            }
        } else {
            null
        }

        return when {
            minsScore != null && calsScore != null -> minsScore * 0.6 + calsScore * 0.4
            minsScore != null -> minsScore
            else -> calsScore
        }
    }

    /** Blood oxygen: cerebral oxygenation is critical for cognitive function. */
    private fun computeOxygenScore(timeSeries: Map<HealthMetric, List<DailySample>>): Double? {
        val spo2 = recentAverage(timeSeries[HealthMetric.BLOOD_OXYGEN], days = 7) ?: return null

        return when {
            spo2 >= 98.0 -> 95.0
            spo2 >= 96.0 -> 80.0
            spo2 >= 95.0 -> 65.0
            spo2 >= 93.0 -> 40.0
            else -> 20.0
        }
    }

    // ── Sub-Dimension Calculations ──────────────────────────────────────────

    /** Memory recovery: deep sleep is the primary driver. */
    private fun computeMemoryRecovery(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        sleepQuality: Double,
    ): Int {
        val deepSleep = recentAverage(timeSeries[HealthMetric.SLEEP_DEEP], days = 7)
        val sleepDuration = recentAverage(timeSeries[HealthMetric.SLEEP_DURATION], days = 7)

        if (deepSleep == null || sleepDuration == null || sleepDuration <= 0) {
            return sleepQuality.roundToInt().coerceIn(0, 100)
        }

        val deepPercent = (deepSleep / sleepDuration) * 100.0
        val deepScore = when {
            deepPercent >= 20 -> 95.0
            deepPercent >= 15 -> 80.0
            deepPercent >= 10 -> 60.0
            else -> 35.0
        }

        return combineScores(deepScore, sleepQuality, 0.6, 0.4)
    }

    /** Circadian alignment: consistency of sleep timing. */
    private fun computeCircadianAlignment(timeSeries: Map<HealthMetric, List<DailySample>>): Int {
        val samples = timeSeries[HealthMetric.SLEEP_DURATION] ?: return 50
        val sorted = samples.sortedByDescending { it.date }
        val cutoff = (sorted.firstOrNull()?.date ?: return 50) - 7 * MILLIS_PER_DAY
        val recent = sorted.filter { it.date >= cutoff }

        if (recent.size < 3) return 50

        val values = recent.map { it.value }
        val mean = values.average()
        val stdDev = sqrt(values.sumOf { (it - mean) * (it - mean) } / values.size)

        // Low variance (< 0.5h) = excellent alignment.
        return when {
            stdDev < 0.3 -> 95
            stdDev < 0.5 -> 85
            stdDev < 1.0 -> 70
            stdDev < 1.5 -> 50
            else -> 30
        }
    }

    // ── Factor Analysis ─────────────────────────────────────────────────────

    /** Build the top contributing factors list for the UI. */
    private fun buildFactors(
        sleepQuality: Double?,
        hrvScore: Double?,
        exerciseScore: Double?,
        oxygenScore: Double?,
        stressInverse: Double,
    ): List<BrainFactor> {
        data class PillarEntry(val label: String, val score: Double)

        val pillars = listOfNotNull(
            sleepQuality?.let { PillarEntry("Sleep Quality", it) },
            hrvScore?.let { PillarEntry("HRV", it) },
            exerciseScore?.let { PillarEntry("Exercise", it) },
            oxygenScore?.let { PillarEntry("Blood Oxygen", it) },
            PillarEntry("Stress Management", stressInverse),
        )

        return pillars
            .sortedByDescending { abs(it.score - 50.0) } // most impactful first
            .take(4)
            .map { pillar ->
                val isPositive = pillar.score >= 60.0
                val impact = when {
                    pillar.score >= 85 -> "Strong positive"
                    pillar.score >= 70 -> "Positive"
                    pillar.score >= 50 -> "Neutral"
                    pillar.score >= 35 -> "Negative"
                    else -> "Strong negative"
                }
                BrainFactor(
                    label = pillar.label,
                    impact = impact,
                    isPositive = isPositive,
                )
            }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Recent average requiring at least 3 data points. */
    private fun recentAverage(samples: List<DailySample>?, days: Int): Double? {
        if (samples.isNullOrEmpty()) return null
        val sorted = samples.sortedByDescending { it.date }
        val cutoff = sorted.first().date - days * MILLIS_PER_DAY
        val recent = sorted.filter { it.date >= cutoff }
        if (recent.size < MIN_SAMPLES) return null
        return recent.map { it.value }.average()
    }

    /** Combine two scores with given weights, returning an integer 0-100. */
    private fun combineScores(a: Double, b: Double, wA: Double, wB: Double): Int {
        return ((a * wA + b * wB) / (wA + wB)).roundToInt().coerceIn(0, 100)
    }

    /** Map overall score to a letter grade. */
    private fun toGrade(score: Int): String = when {
        score >= 90 -> "A"
        score >= 75 -> "B"
        score >= 60 -> "C"
        score >= 45 -> "D"
        else -> "F"
    }

    companion object {
        private const val MILLIS_PER_DAY = 86_400_000L
        private const val MIN_SAMPLES = 3

        private const val WEIGHT_SLEEP = 0.30
        private const val WEIGHT_STRESS = 0.20
        private const val WEIGHT_HRV = 0.20
        private const val WEIGHT_EXERCISE = 0.15
        private const val WEIGHT_OXYGEN = 0.15
    }
}
