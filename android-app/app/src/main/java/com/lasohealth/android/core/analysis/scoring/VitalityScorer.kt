package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// ── Result Types ────────────────────────────────────────────────────────────

data class VitalityScore(
    val vitalityAge: Int,
    val delta: Int,
    val score: Int,
    val contributions: List<MetricContribution>,
    val improvements: List<VitalityImprovement>,
    val paceOfAging: Double = 1.0,
    val personalizationProgress: Double = 0.0,
)

data class MetricContribution(
    val metric: HealthMetric,
    val metricName: String,
    val metricAge: Int,
    val weight: Double,
    val currentValue: Double,
    val unit: String,
    val populationMedian: Double,
    val delta: Int,
)

data class VitalityImprovement(
    val metricName: String,
    val impactYears: Int,
    val description: String,
    val metric: HealthMetric,
)

// ── Population Norms ────────────────────────────────────────────────────────

/**
 * Age-adjusted population norms sourced from ACSM, AHA, WHO, and meta-analyses.
 * Each table maps age -> expected median value for that age group.
 */
private object VitalityNorms {

    data class AgeNorm(val age: Int, val value: Double)

    /** VO2 Max norms (mL/kg/min) — combined sex average. Source: ACSM 11th ed. */
    val vo2Max = listOf(
        AgeNorm(20, 46.0), AgeNorm(25, 45.0), AgeNorm(30, 43.0), AgeNorm(35, 41.0),
        AgeNorm(40, 39.0), AgeNorm(45, 37.0), AgeNorm(50, 35.0), AgeNorm(55, 33.0),
        AgeNorm(60, 31.0), AgeNorm(65, 29.0), AgeNorm(70, 27.0), AgeNorm(75, 25.0),
        AgeNorm(80, 23.0),
    )

    /** Resting heart rate norms (bpm) — lower is better. Source: AHA, Framingham. */
    val restingHeartRate = listOf(
        AgeNorm(20, 63.0), AgeNorm(25, 64.0), AgeNorm(30, 65.0), AgeNorm(35, 66.0),
        AgeNorm(40, 67.0), AgeNorm(45, 68.0), AgeNorm(50, 69.0), AgeNorm(55, 70.0),
        AgeNorm(60, 71.0), AgeNorm(65, 72.0), AgeNorm(70, 73.0), AgeNorm(75, 74.0),
        AgeNorm(80, 76.0),
    )

    /** HRV (SDNN, ms) — higher is better. Source: Nunan et al. 2010. */
    val hrv = listOf(
        AgeNorm(20, 62.0), AgeNorm(25, 58.0), AgeNorm(30, 54.0), AgeNorm(35, 50.0),
        AgeNorm(40, 46.0), AgeNorm(45, 42.0), AgeNorm(50, 38.0), AgeNorm(55, 34.0),
        AgeNorm(60, 30.0), AgeNorm(65, 27.0), AgeNorm(70, 24.0), AgeNorm(75, 22.0),
        AgeNorm(80, 20.0),
    )

    /** Sleep efficiency (%) — higher is better. Source: Ohayon et al. 2004. */
    val sleepEfficiency = listOf(
        AgeNorm(20, 92.0), AgeNorm(25, 91.0), AgeNorm(30, 90.0), AgeNorm(35, 89.0),
        AgeNorm(40, 88.0), AgeNorm(45, 87.0), AgeNorm(50, 86.0), AgeNorm(55, 85.0),
        AgeNorm(60, 83.0), AgeNorm(65, 81.0), AgeNorm(70, 79.0), AgeNorm(75, 77.0),
        AgeNorm(80, 75.0),
    )

    /** Deep sleep % of total — higher is better. Source: AASM staging data. */
    val deepSleepPercent = listOf(
        AgeNorm(20, 22.0), AgeNorm(25, 20.0), AgeNorm(30, 18.0), AgeNorm(35, 17.0),
        AgeNorm(40, 16.0), AgeNorm(45, 15.0), AgeNorm(50, 14.0), AgeNorm(55, 13.0),
        AgeNorm(60, 12.0), AgeNorm(65, 11.0), AgeNorm(70, 10.0), AgeNorm(75, 9.0),
        AgeNorm(80, 8.0),
    )

    /** Walking speed (km/h) — higher is better. Source: Bohannon & Andrews 2011. */
    val walkingSpeed = listOf(
        AgeNorm(20, 5.4), AgeNorm(25, 5.3), AgeNorm(30, 5.2), AgeNorm(35, 5.1),
        AgeNorm(40, 5.0), AgeNorm(45, 4.9), AgeNorm(50, 4.8), AgeNorm(55, 4.7),
        AgeNorm(60, 4.5), AgeNorm(65, 4.3), AgeNorm(70, 4.1), AgeNorm(75, 3.9),
        AgeNorm(80, 3.6),
    )

    /** Steps per day — higher is better. Source: Tudor-Locke et al. 2011, NHANES. */
    val steps = listOf(
        AgeNorm(20, 10000.0), AgeNorm(25, 9800.0), AgeNorm(30, 9500.0), AgeNorm(35, 9000.0),
        AgeNorm(40, 8500.0), AgeNorm(45, 8000.0), AgeNorm(50, 7500.0), AgeNorm(55, 7000.0),
        AgeNorm(60, 6500.0), AgeNorm(65, 6000.0), AgeNorm(70, 5500.0), AgeNorm(75, 5000.0),
        AgeNorm(80, 4500.0),
    )

    /** Exercise minutes per day — higher is better. Source: WHO PA Guidelines. */
    val exerciseMinutes = listOf(
        AgeNorm(20, 45.0), AgeNorm(25, 42.0), AgeNorm(30, 40.0), AgeNorm(35, 38.0),
        AgeNorm(40, 35.0), AgeNorm(45, 33.0), AgeNorm(50, 30.0), AgeNorm(55, 28.0),
        AgeNorm(60, 25.0), AgeNorm(65, 22.0), AgeNorm(70, 20.0), AgeNorm(75, 18.0),
        AgeNorm(80, 15.0),
    )

    /** Body fat % — lower is better. Source: Jackson & Pollock, ACE norms. */
    val bodyFatPercent = listOf(
        AgeNorm(20, 18.0), AgeNorm(25, 19.0), AgeNorm(30, 20.0), AgeNorm(35, 21.0),
        AgeNorm(40, 22.0), AgeNorm(45, 23.0), AgeNorm(50, 24.0), AgeNorm(55, 25.0),
        AgeNorm(60, 26.0), AgeNorm(65, 27.0), AgeNorm(70, 28.0), AgeNorm(75, 29.0),
        AgeNorm(80, 30.0),
    )

    /** Optimal BMI value — deviation adds age. */
    const val BMI_OPTIMAL = 22.5

    /**
     * Given a measured value and a norm table, find the "metric age" — the age at
     * which this value would be the population median.
     *
     * Uses linear interpolation between reference points, clamped to 18..95.
     *
     * @param higherIsBetter if true, higher values correspond to younger ages
     *   (table values decrease with age). If false, lower values correspond to
     *   younger ages (table values increase with age).
     */
    fun metricAge(value: Double, table: List<AgeNorm>, higherIsBetter: Boolean): Int {
        if (table.size < 2) return 50

        // For "higher is better" metrics the table values decrease with age;
        // reversing makes values ascend so the interpolation logic works uniformly.
        val sorted = if (higherIsBetter) table.reversed() else table

        if (value <= sorted.first().value) return sorted.first().age
        if (value >= sorted.last().value) return sorted.last().age

        for (i in 0 until sorted.size - 1) {
            val lower = sorted[i]
            val upper = sorted[i + 1]
            if (value in lower.value..upper.value) {
                val valueDelta = upper.value - lower.value
                val fraction = if (abs(valueDelta) < 0.001) 0.5
                else (value - lower.value) / valueDelta
                val interpolated = lower.age.toDouble() + fraction * (upper.age - lower.age)
                return interpolated.roundToInt().coerceIn(18, 95)
            }
        }
        return 50 // fallback
    }

    /**
     * Interpolate the population median value for a given chronological age.
     */
    fun interpolateMedian(age: Int, table: List<AgeNorm>): Double {
        if (table.size < 2) return 0.0
        if (age <= table.first().age) return table.first().value
        if (age >= table.last().age) return table.last().value

        for (i in 0 until table.size - 1) {
            if (age in table[i].age..table[i + 1].age) {
                val fraction = (age - table[i].age).toDouble() / (table[i + 1].age - table[i].age)
                return table[i].value + fraction * (table[i + 1].value - table[i].value)
            }
        }
        return table[table.size / 2].value
    }
}

// ── Scorer ───────────────────────────────────────────────────────────────────

/**
 * Computes a "Vitality Age" representing how old the user's body is performing,
 * based on key health metrics compared against age-adjusted population norms.
 *
 * Each metric is mapped to a "component age" via population norm tables, then
 * combined with metric-specific weights into a single biological age estimate.
 *
 * Delta = chronological age - vitality age (positive means younger than actual).
 */
class VitalityScorer {

    /** Metric contribution weights — sum to 1.0. */
    private enum class MetricKey(val weight: Double) {
        RESTING_HR(0.20),
        HRV(0.15),
        SLEEP_DURATION(0.15),
        VO2_MAX(0.12),
        BLOOD_OXYGEN(0.10),
        STEPS(0.08),
        ACTIVE_CALORIES(0.08),
        RESPIRATORY_RATE(0.06),
        BODY_MASS(0.06),
    }

    /**
     * Compute the vitality score from health metric time series.
     *
     * @param timeSeries daily samples keyed by [HealthMetric].
     * @param chronologicalAge the user's actual age in years.
     * @return [VitalityScore] with vitality age, delta, per-metric contributions, and improvements.
     */
    fun score(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        chronologicalAge: Int,
    ): VitalityScore {
        val contributions = mutableListOf<MetricContribution>()
        var weightedAgeSum = 0.0
        var totalWeight = 0.0

        // ── Resting Heart Rate ──────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.RESTING_HEART_RATE], days = 14, metric = HealthMetric.RESTING_HEART_RATE)?.let { avg ->
            val age = VitalityNorms.metricAge(avg, VitalityNorms.restingHeartRate, higherIsBetter = false)
            val w = MetricKey.RESTING_HR.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.restingHeartRate)
            contributions += MetricContribution(
                metric = HealthMetric.RESTING_HEART_RATE,
                metricName = "Resting HR",
                metricAge = age, weight = w,
                currentValue = avg, unit = "bpm",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── HRV ─────────────────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.HEART_RATE_VARIABILITY], days = 14, metric = HealthMetric.HEART_RATE_VARIABILITY)?.let { avg ->
            val age = VitalityNorms.metricAge(avg, VitalityNorms.hrv, higherIsBetter = true)
            val w = MetricKey.HRV.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.hrv)
            contributions += MetricContribution(
                metric = HealthMetric.HEART_RATE_VARIABILITY,
                metricName = "HRV",
                metricAge = age, weight = w,
                currentValue = avg, unit = "ms",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Sleep Duration (used as proxy for sleep quality) ────────────────
        recentAverage(timeSeries[HealthMetric.SLEEP_DURATION], days = 14, metric = HealthMetric.SLEEP_DURATION)?.let { avg ->
            // Map sleep duration (hours) to efficiency-style score.
            // 7-8h is optimal (maps to ~90%), <5h or >10h penalised.
            val efficiency = sleepDurationToEfficiency(avg)
            val age = VitalityNorms.metricAge(efficiency, VitalityNorms.sleepEfficiency, higherIsBetter = true)
            val w = MetricKey.SLEEP_DURATION.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.sleepEfficiency)
            contributions += MetricContribution(
                metric = HealthMetric.SLEEP_DURATION,
                metricName = "Sleep",
                metricAge = age, weight = w,
                currentValue = avg, unit = "hrs",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── VO2 Max ─────────────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.VO2_MAX], days = 30, metric = HealthMetric.VO2_MAX)?.let { avg ->
            val age = VitalityNorms.metricAge(avg, VitalityNorms.vo2Max, higherIsBetter = true)
            val w = MetricKey.VO2_MAX.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.vo2Max)
            contributions += MetricContribution(
                metric = HealthMetric.VO2_MAX,
                metricName = "VO2 Max",
                metricAge = age, weight = w,
                currentValue = avg, unit = "mL/kg/min",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Blood Oxygen ────────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.BLOOD_OXYGEN], days = 14, metric = HealthMetric.BLOOD_OXYGEN)?.let { avg ->
            // SpO2 is tightly clustered: 95-100% is normal. Map to age contribution.
            // Below 95% is abnormal at any age; 97-99% is youthful.
            val age = bloodOxygenToAge(avg, chronologicalAge)
            val w = MetricKey.BLOOD_OXYGEN.weight
            contributions += MetricContribution(
                metric = HealthMetric.BLOOD_OXYGEN,
                metricName = "Blood Oxygen",
                metricAge = age, weight = w,
                currentValue = avg, unit = "%",
                populationMedian = 97.0,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Steps ───────────────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.STEPS], days = 14, metric = HealthMetric.STEPS)?.let { avg ->
            val age = VitalityNorms.metricAge(avg, VitalityNorms.steps, higherIsBetter = true)
            val w = MetricKey.STEPS.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.steps)
            contributions += MetricContribution(
                metric = HealthMetric.STEPS,
                metricName = "Daily Steps",
                metricAge = age, weight = w,
                currentValue = avg, unit = "steps",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Active Calories ─────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.ACTIVE_CALORIES], days = 14, metric = HealthMetric.ACTIVE_CALORIES)?.let { avg ->
            // Map active calories to exercise minutes equivalent for norm lookup.
            // Rough conversion: ~10 kcal per minute of moderate activity.
            val equivMinutes = avg / 10.0
            val age = VitalityNorms.metricAge(equivMinutes, VitalityNorms.exerciseMinutes, higherIsBetter = true)
            val w = MetricKey.ACTIVE_CALORIES.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.exerciseMinutes) * 10.0
            contributions += MetricContribution(
                metric = HealthMetric.ACTIVE_CALORIES,
                metricName = "Active Calories",
                metricAge = age, weight = w,
                currentValue = avg, unit = "kcal",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Respiratory Rate ────────────────────────────────────────────────
        recentAverage(timeSeries[HealthMetric.RESPIRATORY_RATE], days = 14, metric = HealthMetric.RESPIRATORY_RATE)?.let { avg ->
            // Normal adult: 12-20 br/min. Optimal (young) is ~14-16.
            val age = respiratoryRateToAge(avg, chronologicalAge)
            val w = MetricKey.RESPIRATORY_RATE.weight
            contributions += MetricContribution(
                metric = HealthMetric.RESPIRATORY_RATE,
                metricName = "Respiratory Rate",
                metricAge = age, weight = w,
                currentValue = avg, unit = "br/min",
                populationMedian = 15.0,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Body Mass (BMI or Body Fat %) ───────────────────────────────────
        val bodyFatAvg = recentAverage(timeSeries[HealthMetric.BODY_FAT_PERCENTAGE], days = 30, metric = HealthMetric.BODY_FAT_PERCENTAGE)
        val bmiAvg = recentAverage(timeSeries[HealthMetric.BMI], days = 30, metric = HealthMetric.BMI)
        if (bodyFatAvg != null) {
            val age = VitalityNorms.metricAge(bodyFatAvg, VitalityNorms.bodyFatPercent, higherIsBetter = false)
            val w = MetricKey.BODY_MASS.weight
            val median = VitalityNorms.interpolateMedian(chronologicalAge, VitalityNorms.bodyFatPercent)
            contributions += MetricContribution(
                metric = HealthMetric.BODY_FAT_PERCENTAGE,
                metricName = "Body Fat",
                metricAge = age, weight = w,
                currentValue = bodyFatAvg, unit = "%",
                populationMedian = median,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        } else if (bmiAvg != null) {
            val deviation = abs(bmiAvg - VitalityNorms.BMI_OPTIMAL)
            val ageOffset = deviation * 1.5
            val age = (chronologicalAge + ageOffset).roundToInt().coerceIn(18, 95)
            val w = MetricKey.BODY_MASS.weight
            contributions += MetricContribution(
                metric = HealthMetric.BMI,
                metricName = "BMI",
                metricAge = age, weight = w,
                currentValue = bmiAvg, unit = "",
                populationMedian = VitalityNorms.BMI_OPTIMAL,
                delta = age - chronologicalAge,
            )
            weightedAgeSum += age * w
            totalWeight += w
        }

        // ── Aggregate ───────────────────────────────────────────────────────

        if (contributions.size < 2 || totalWeight <= 0.0) {
            return VitalityScore(
                vitalityAge = chronologicalAge,
                delta = 0,
                score = 50,
                contributions = contributions.sortedByDescending { it.metricAge },
                improvements = emptyList(),
            )
        }

        val computedAge = (weightedAgeSum / totalWeight).roundToInt().coerceIn(18, 95)

        // Personalization: ramp from chronological to computed over 7..30 days of data.
        val availableDays = estimateAvailableDays(timeSeries)
        val progress = personalizationProgress(availableDays)
        val vitalityAge = blendedAge(chronologicalAge, computedAge, progress)

        val delta = chronologicalAge - vitalityAge // positive = younger
        val score = ageToScore(delta)

        val sorted = contributions.sortedByDescending { it.metricAge }

        // Top improvement opportunities: metrics dragging vitality age older.
        val improvements = sorted
            .filter { it.delta > 0 }
            .take(3)
            .map { contrib ->
                VitalityImprovement(
                    metricName = contrib.metricName,
                    impactYears = contrib.delta,
                    description = improvementDescription(contrib.metric),
                    metric = contrib.metric,
                )
            }

        return VitalityScore(
            vitalityAge = vitalityAge,
            delta = delta,
            score = score,
            contributions = sorted,
            improvements = improvements,
            paceOfAging = 1.0, // requires historical data not available in single call
            personalizationProgress = progress,
        )
    }

    // ── Private Helpers ─────────────────────────────────────────────────────

    /** Recent average requiring at least 3 data points in the last [days]. Also filters by staleness. */
    private fun recentAverage(samples: List<DailySample>?, days: Int, metric: HealthMetric): Double? {
        if (samples.isNullOrEmpty()) return null
        val sorted = samples.sortedByDescending { it.date }
        
        val latestTimestamp = sorted.first().date
        val stalenessMillis = System.currentTimeMillis() - latestTimestamp
        val maxStaleness = if (metric == HealthMetric.BMI || metric == HealthMetric.BODY_FAT_PERCENTAGE) {
            30L * 86_400_000L // 30 days
        } else {
            2L * 86_400_000L // 48 hours
        }
        if (stalenessMillis > maxStaleness) {
            return null
        }
        
        val cutoff = System.currentTimeMillis() - days * MILLIS_PER_DAY
        val recent = sorted.filter { it.date >= cutoff }
        if (recent.size < MIN_SAMPLES_FOR_AVERAGE) return null
        return recent.map { it.value }.average()
    }

    /** Map sleep duration (hours) to a sleep efficiency-like percentage. */
    private fun sleepDurationToEfficiency(hours: Double): Double {
        // Bell curve around 7.5h optimal.
        val optimal = 7.5
        val deviation = abs(hours - optimal)
        return (95.0 - deviation * 5.0).coerceIn(60.0, 98.0)
    }

    /** Map blood oxygen (%) to a component age. */
    private fun bloodOxygenToAge(spo2: Double, chronologicalAge: Int): Int {
        // 97-100% → youthful (chronological - 5 to chronological).
        // 95-97% → neutral. Below 95% → older.
        val offset = when {
            spo2 >= 98.0 -> -3.0
            spo2 >= 97.0 -> -1.0
            spo2 >= 95.0 -> 2.0
            spo2 >= 93.0 -> 8.0
            else -> 15.0
        }
        return (chronologicalAge + offset).roundToInt().coerceIn(18, 95)
    }

    /** Map respiratory rate (br/min) to a component age. */
    private fun respiratoryRateToAge(rate: Double, chronologicalAge: Int): Int {
        // Optimal: 12-16. Deviation adds age.
        val optimal = 14.0
        val deviation = abs(rate - optimal)
        val offset = when {
            deviation < 2.0 -> -2.0
            deviation < 4.0 -> 0.0
            deviation < 6.0 -> 5.0
            else -> 10.0
        }
        return (chronologicalAge + offset).roundToInt().coerceIn(18, 95)
    }

    /** Estimate max available days across usable metrics. */
    private fun estimateAvailableDays(timeSeries: Map<HealthMetric, List<DailySample>>): Int {
        var maxDays = 0
        for ((_, samples) in timeSeries) {
            if (samples.size < MIN_SAMPLES_FOR_AVERAGE) continue
            val sorted = samples.sortedBy { it.date }
            val span = ((sorted.last().date - sorted.first().date) / MILLIS_PER_DAY).toInt()
            maxDays = max(maxDays, span)
        }
        return maxDays
    }

    /** Personalization stays at 0 for the first 7 usable days, then ramps to 1.0 by day 30. */
    private fun personalizationProgress(availableDays: Int): Double {
        if (availableDays <= ZERO_DELTA_DAYS) return 0.0
        if (availableDays >= FULL_PERSONALIZATION_DAYS) return 1.0
        val rampDays = FULL_PERSONALIZATION_DAYS - ZERO_DELTA_DAYS
        val progressed = availableDays - ZERO_DELTA_DAYS
        return (progressed.toDouble() / rampDays).coerceIn(0.0, 1.0)
    }

    /** Blend chronological → computed age based on personalization progress. */
    private fun blendedAge(chronological: Int, computed: Int, progress: Double): Int {
        val rawDelta = (computed - chronological).toDouble()
        val blended = chronological + rawDelta * progress.coerceIn(0.0, 1.0)
        return blended.roundToInt().coerceIn(18, 95)
    }

    /** Convert vitality delta to a 0-100 score. Positive delta = better. */
    private fun ageToScore(delta: Int): Int {
        // -15 years → 100, 0 → 50, +15 years → 0
        return (50 + delta * (50.0 / 15.0)).roundToInt().coerceIn(0, 100)
    }

    /** Actionable suggestion for improving a specific metric. */
    private fun improvementDescription(metric: HealthMetric): String = when (metric) {
        HealthMetric.VO2_MAX ->
            "Improve cardiovascular fitness with regular aerobic exercise — aim for 150+ min/week of moderate-intensity activity."
        HealthMetric.RESTING_HEART_RATE ->
            "Lower resting heart rate through consistent cardio training, stress management, and adequate sleep."
        HealthMetric.HEART_RATE_VARIABILITY ->
            "Boost HRV with quality sleep, mindfulness practices, and balanced training load."
        HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP ->
            "Optimise sleep by maintaining a consistent schedule, limiting screens before bed, and keeping a cool, dark room."
        HealthMetric.STEPS ->
            "Increase daily movement — take walking breaks, use stairs, and aim for 8,000+ steps per day."
        HealthMetric.ACTIVE_CALORIES ->
            "Burn more active calories with varied exercise — mix strength training with cardio sessions."
        HealthMetric.BODY_FAT_PERCENTAGE, HealthMetric.BMI ->
            "Improve body composition through balanced nutrition and a mix of resistance and aerobic training."
        HealthMetric.RESPIRATORY_RATE ->
            "Practice breathing exercises and maintain cardiovascular fitness to optimise respiratory rate."
        HealthMetric.BLOOD_OXYGEN ->
            "Support blood oxygen with regular exercise, good posture, and adequate iron intake."
        else ->
            "Focus on consistent healthy habits across exercise, sleep, and nutrition."
    }

    companion object {
        private const val MILLIS_PER_DAY = 86_400_000L
        private const val MIN_SAMPLES_FOR_AVERAGE = 3
        private const val ZERO_DELTA_DAYS = 7
        private const val FULL_PERSONALIZATION_DAYS = 30
    }
}
