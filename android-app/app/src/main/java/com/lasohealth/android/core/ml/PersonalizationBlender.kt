package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

/**
 * Blends population-level statistical priors with personalized model outputs
 * using confidence-weighted sigmoid ramps. Enables meaningful predictions from
 * day one and smoothly transitions to fully personalized models as user data
 * accumulates.
 *
 * Also contains the population priors (27 metric priors + 15 correlation priors)
 * used for cold-start analysis.
 *
 * Ported from iOS `PersonalizationBlender.swift`.
 */
object PersonalizationBlender {

    // ---------------------------------------------------------------------------
    // Population Priors
    // ---------------------------------------------------------------------------

    data class MetricPrior(
        val metric: HealthMetric,
        val populationMean: Double,
        val populationStdDev: Double,
        val healthyRangeLow: Double,
        val healthyRangeHigh: Double,
        val typicalDailyVariation: Double,
    )

    data class CorrelationPrior(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val expectedCorrelation: Double,
        val expectedDirection: String,
        val confidence: Double,
        val mechanism: String,
    )

    /** Population-level metric priors from AHA, AASM, WHO. */
    val metricPriors: Map<HealthMetric, MetricPrior> = listOf(
        // Heart
        MetricPrior(HealthMetric.HEART_RATE_VARIABILITY, 45.0, 15.0, 20.0, 100.0, 0.15),
        MetricPrior(HealthMetric.RESTING_HEART_RATE, 68.0, 8.0, 50.0, 85.0, 0.05),
        MetricPrior(HealthMetric.HEART_RATE, 75.0, 10.0, 55.0, 100.0, 0.08),
        MetricPrior(HealthMetric.HEART_RATE_RECOVERY, 22.0, 8.0, 12.0, 45.0, 0.15),
        // Sleep
        MetricPrior(HealthMetric.SLEEP_DURATION, 7.0, 1.0, 6.0, 9.0, 0.10),
        MetricPrior(HealthMetric.SLEEP_DEEP, 1.26, 0.35, 0.9, 1.75, 0.20),
        MetricPrior(HealthMetric.SLEEP_REM, 1.58, 0.42, 1.0, 2.25, 0.18),
        MetricPrior(HealthMetric.SLEEP_CORE, 3.5, 0.7, 2.5, 5.0, 0.12),
        MetricPrior(HealthMetric.SLEEP_AWAKE, 0.5, 0.25, 0.0, 1.0, 0.30),
        // Activity
        MetricPrior(HealthMetric.STEPS, 7500.0, 3000.0, 5000.0, 15000.0, 0.25),
        MetricPrior(HealthMetric.ACTIVE_CALORIES, 400.0, 200.0, 200.0, 800.0, 0.30),
        MetricPrior(HealthMetric.EXERCISE_MINUTES, 30.0, 20.0, 20.0, 90.0, 0.35),
        MetricPrior(HealthMetric.STAND_HOURS, 10.0, 3.0, 6.0, 16.0, 0.15),
        MetricPrior(HealthMetric.DISTANCE_WALKING_RUNNING, 5.5, 2.5, 3.0, 12.0, 0.28),
        MetricPrior(HealthMetric.FLIGHTS_CLIMBED, 5.0, 4.0, 2.0, 15.0, 0.35),
        // Body
        MetricPrior(HealthMetric.WEIGHT, 75.0, 15.0, 50.0, 100.0, 0.01),
        MetricPrior(HealthMetric.BLOOD_PRESSURE_SYSTOLIC, 120.0, 12.0, 90.0, 140.0, 0.05),
        MetricPrior(HealthMetric.BLOOD_PRESSURE_DIASTOLIC, 78.0, 8.0, 60.0, 90.0, 0.05),
        MetricPrior(HealthMetric.BODY_TEMPERATURE, 36.6, 0.3, 36.1, 37.2, 0.005),
        MetricPrior(HealthMetric.BLOOD_GLUCOSE, 95.0, 12.0, 70.0, 120.0, 0.10),
        // Respiratory
        MetricPrior(HealthMetric.VO2_MAX, 38.0, 8.0, 25.0, 55.0, 0.03),
        MetricPrior(HealthMetric.BLOOD_OXYGEN, 97.5, 1.2, 95.0, 100.0, 0.01),
        MetricPrior(HealthMetric.RESPIRATORY_RATE, 15.0, 2.5, 12.0, 20.0, 0.06),
        // Mindfulness
        MetricPrior(HealthMetric.MINDFUL_MINUTES, 10.0, 10.0, 5.0, 30.0, 0.40),
        // Mobility
        MetricPrior(HealthMetric.WALKING_SPEED, 4.8, 0.6, 3.5, 6.5, 0.05),
        MetricPrior(HealthMetric.WALKING_STEP_LENGTH, 72.0, 8.0, 55.0, 90.0, 0.04),
        // Nutrition
        MetricPrior(HealthMetric.WATER_INTAKE, 2000.0, 600.0, 1500.0, 3500.0, 0.20),
        MetricPrior(HealthMetric.CAFFEINE_INTAKE, 200.0, 100.0, 0.0, 400.0, 0.25),
    ).associateBy { it.metric }

    /** Known physiological correlation priors. */
    val correlationPriors: List<CorrelationPrior> = listOf(
        CorrelationPrior(HealthMetric.HEART_RATE_VARIABILITY, HealthMetric.SLEEP_DURATION, 0.30, "positive", 0.80, "Better sleep improves autonomic recovery"),
        CorrelationPrior(HealthMetric.HEART_RATE_VARIABILITY, HealthMetric.SLEEP_DEEP, 0.35, "positive", 0.75, "Deep sleep is primary window for parasympathetic restoration"),
        CorrelationPrior(HealthMetric.HEART_RATE_VARIABILITY, HealthMetric.RESTING_HEART_RATE, -0.40, "negative", 0.90, "Higher vagal tone lowers RHR and raises HRV"),
        CorrelationPrior(HealthMetric.RESTING_HEART_RATE, HealthMetric.EXERCISE_MINUTES, -0.25, "negative", 0.70, "Regular exercise strengthens cardiac efficiency"),
        CorrelationPrior(HealthMetric.SLEEP_DURATION, HealthMetric.STEPS, 0.20, "positive", 0.60, "Adequate sleep enables more physical activity"),
        CorrelationPrior(HealthMetric.ACTIVE_CALORIES, HealthMetric.SLEEP_DEEP, 0.20, "positive", 0.50, "Physical activity promotes deeper sleep"),
        CorrelationPrior(HealthMetric.VO2_MAX, HealthMetric.EXERCISE_MINUTES, 0.35, "positive", 0.80, "Consistent exercise drives aerobic capacity improvements"),
        CorrelationPrior(HealthMetric.VO2_MAX, HealthMetric.RESTING_HEART_RATE, -0.30, "negative", 0.75, "Higher fitness correlates with lower RHR"),
        CorrelationPrior(HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES, 0.70, "positive", 0.95, "Walking directly contributes to energy expenditure"),
        CorrelationPrior(HealthMetric.MINDFUL_MINUTES, HealthMetric.HEART_RATE_VARIABILITY, 0.15, "positive", 0.50, "Mindfulness enhances parasympathetic activity"),
        CorrelationPrior(HealthMetric.RESPIRATORY_RATE, HealthMetric.HEART_RATE_VARIABILITY, -0.20, "negative", 0.55, "Slower respiratory rate reflects greater parasympathetic tone"),
    )

    // ---------------------------------------------------------------------------
    // Prediction Blending
    // ---------------------------------------------------------------------------

    /**
     * Blend a personalized prediction with a population prediction using a sigmoid ramp.
     *
     * At ~0 days: ~5% personal, ~95% population.
     * At ~14 days: ~50/50.
     * At ~30 days: ~95% personal.
     *
     * @return (blendedPrediction, personalWeight)
     */
    fun blendPrediction(
        personalPrediction: Double,
        populationPrediction: Double,
        userDataDays: Int,
        personalModelAccuracy: Double? = null,
        rampCenterDays: Int = 14,
        rampScale: Double = 5.0,
    ): Pair<Double, Double> {
        var personalWeight = sigmoidWeight(userDataDays, rampCenterDays, rampScale)

        if (personalModelAccuracy != null && personalModelAccuracy > 0.5) {
            val boost = (personalModelAccuracy - 0.5) * 0.4
            personalWeight = min(1.0, personalWeight + boost * personalWeight)
        }

        val blended = personalWeight * personalPrediction + (1.0 - personalWeight) * populationPrediction
        return clamp01(blended) to personalWeight
    }

    // ---------------------------------------------------------------------------
    // Baseline Blending
    // ---------------------------------------------------------------------------

    /**
     * Blend a personalized baseline with population priors.
     *
     * @return (mean, stdDev, personalWeight)
     */
    fun blendBaseline(
        personalBaseline: MetricBaseline?,
        metric: HealthMetric,
        userDataDays: Int,
    ): Triple<Double, Double, Double> {
        val prior = metricPriors[metric]
            ?: return if (personalBaseline != null) {
                Triple(personalBaseline.mean, personalBaseline.standardDeviation, 1.0)
            } else {
                Triple(0.0, 1.0, 0.0)
            }

        if (userDataDays < 3 || personalBaseline == null) {
            return Triple(prior.populationMean, prior.populationStdDev, 0.0)
        }
        if (userDataDays >= 30) {
            return Triple(personalBaseline.mean, personalBaseline.standardDeviation, 1.0)
        }

        val w = sigmoidWeight(userDataDays, 14, 5.0)
        val blendedMean = w * personalBaseline.mean + (1.0 - w) * prior.populationMean
        val blendedStd = w * personalBaseline.standardDeviation + (1.0 - w) * prior.populationStdDev

        return Triple(blendedMean, blendedStd, w)
    }

    // ---------------------------------------------------------------------------
    // Correlation Blending (Bayesian Shrinkage)
    // ---------------------------------------------------------------------------

    /**
     * Blend a personal correlation with a population prior using Bayesian shrinkage.
     *
     * @return (blendedR, personalWeight)
     */
    fun blendCorrelation(
        personalR: Double,
        personalN: Int,
        populationR: Double,
        populationConfidence: Double,
    ): Pair<Double, Double> {
        val priorWeight = 5.0 + populationConfidence * 45.0
        val n = personalN.toDouble()
        val blendedR = (populationR * priorWeight + personalR * n) / (priorWeight + n)
        val personalWeight = n / (priorWeight + n)
        return blendedR.coerceIn(-1.0, 1.0) to personalWeight
    }

    /** Look up the population correlation prior for a metric pair. */
    fun findCorrelationPrior(metricA: HealthMetric, metricB: HealthMetric): CorrelationPrior? =
        correlationPriors.firstOrNull { prior ->
            (prior.metricA == metricA && prior.metricB == metricB) ||
                (prior.metricA == metricB && prior.metricB == metricA)
        }

    // ---------------------------------------------------------------------------
    // Cold-Start Prediction
    // ---------------------------------------------------------------------------

    /**
     * Generate a population-based risk prediction when personal model is insufficient.
     *
     * @return (riskScore 0-1, confidence 0-1, explanation)
     */
    fun coldStartPrediction(
        availableData: Map<HealthMetric, List<Double>>,
    ): Triple<Double, Double, String> {
        if (availableData.isEmpty()) {
            return Triple(0.5, 0.0, "No health data available yet. Track at least one day for initial insights.")
        }

        var logit = -0.30 // base intercept
        var matchedFeatures = 0
        val riskFactors = mutableListOf<String>()
        val protectiveFactors = mutableListOf<String>()

        // Population-level feature weights for bad-day prediction.
        val weights = mapOf(
            HealthMetric.HEART_RATE_VARIABILITY to -0.50,
            HealthMetric.RESTING_HEART_RATE to 0.30,
            HealthMetric.SLEEP_DURATION to -0.40,
            HealthMetric.SLEEP_DEEP to -0.20,
            HealthMetric.STEPS to -0.10,
            HealthMetric.ACTIVE_CALORIES to -0.10,
            HealthMetric.EXERCISE_MINUTES to -0.15,
            HealthMetric.BLOOD_OXYGEN to -0.10,
        )

        for ((metric, values) in availableData) {
            val latestValue = values.lastOrNull() ?: continue
            val prior = metricPriors[metric] ?: continue

            val zScore = if (prior.populationStdDev > 0) {
                (latestValue - prior.populationMean) / prior.populationStdDev
            } else 0.0

            val weight = weights[metric] ?: continue
            val contribution = weight * zScore
            logit += contribution
            matchedFeatures++

            if (kotlin.math.abs(contribution) > 0.1) {
                if (contribution > 0) riskFactors.add(metric.displayName)
                else protectiveFactors.add(metric.displayName)
            }
        }

        val riskScore = sigmoid(logit)
        val metricCount = availableData.size
        val dayCount = availableData.values.maxOfOrNull { it.size } ?: 0
        val metricCoverage = metricCount.toDouble() / max(weights.size, 1)
        val dayFactor = min(dayCount.toDouble() / 7.0, 1.0)
        val confidence = clamp01(min(metricCoverage, matchedFeatures.toDouble() / max(weights.size, 1)) * 0.6 + dayFactor * 0.4)

        val riskLabel = when {
            riskScore >= 0.7 -> "elevated risk"
            riskScore >= 0.5 -> "moderate risk"
            riskScore >= 0.3 -> "low risk"
            else -> "very low risk"
        }

        val parts = mutableListOf<String>()
        parts.add(
            "Based on $dayCount day${if (dayCount == 1) "" else "s"} of data across " +
                "$metricCount metric${if (metricCount == 1) "" else "s"}, " +
                "population benchmarks suggest $riskLabel for a challenging day.",
        )
        if (riskFactors.isNotEmpty()) parts.add("Risk factors: ${riskFactors.joinToString(", ")}.")
        if (protectiveFactors.isNotEmpty()) parts.add("Protective factors: ${protectiveFactors.joinToString(", ")}.")
        if (confidence < 0.5) parts.add("Confidence is low — more data will improve accuracy.")

        return Triple(riskScore, confidence, parts.joinToString(" "))
    }

    // ---------------------------------------------------------------------------
    // Personalization Status
    // ---------------------------------------------------------------------------

    data class PersonalizationStatus(
        val level: PersonalizationLevel,
        val percentPersonalized: Double,
        val description: String,
        val nextMilestone: String?,
    )

    enum class PersonalizationLevel(val displayName: String) {
        POPULATION("Population Averages"),
        EMERGING("Learning Your Patterns"),
        BLENDED("Increasingly Personal"),
        PERSONALIZED("Highly Personalized"),
        FULLY_PERSONAL("Fully Personalized"),
    }

    /**
     * Compute the personalization status for the current user.
     */
    fun personalizationStatus(
        userDataDays: Int,
        metricsTracked: Int,
        modelAccuracy: Double? = null,
    ): PersonalizationStatus {
        val basePercent = sigmoidWeight(userDataDays, 30, 8.0) * 100.0
        val metricBreadthBonus = min(metricsTracked.toDouble() / 10.0, 1.0) * 10.0
        val accuracyBonus = if (modelAccuracy != null && modelAccuracy > 0.6) {
            (modelAccuracy - 0.6) * 25.0
        } else 0.0

        val percent = min(100.0, basePercent + metricBreadthBonus + accuracyBonus)

        val level: PersonalizationLevel
        val description: String
        val nextMilestone: String?

        when {
            userDataDays < 3 -> {
                level = PersonalizationLevel.POPULATION
                description = "Your insights use general health benchmarks while we learn your patterns."
                val remaining = 3 - userDataDays
                nextMilestone = "Track $remaining more day${if (remaining == 1) "" else "s"} to begin personalizing insights."
            }
            userDataDays < 14 -> {
                level = PersonalizationLevel.EMERGING
                description = "Your insights are ${percent.toInt()}% personalized — we're learning your unique patterns."
                val remaining = 14 - userDataDays
                nextMilestone = "Track $remaining more day${if (remaining == 1) "" else "s"} for increasingly personal insights."
            }
            userDataDays < 21 -> {
                level = PersonalizationLevel.BLENDED
                description = "Your insights are ${percent.toInt()}% personalized to your body."
                val remaining = 21 - userDataDays
                nextMilestone = "Track $remaining more day${if (remaining == 1) "" else "s"} for highly personalized predictions."
            }
            userDataDays < 30 -> {
                level = PersonalizationLevel.PERSONALIZED
                description = "Your insights are ${percent.toInt()}% personalized — predictions are tailored to you."
                val remaining = 30 - userDataDays
                nextMilestone = "Track $remaining more day${if (remaining == 1) "" else "s"} for fully personalized insights."
            }
            else -> {
                level = PersonalizationLevel.FULLY_PERSONAL
                description = "Your insights are fully personalized to your body's unique patterns."
                nextMilestone = null
            }
        }

        return PersonalizationStatus(level, percent, description, nextMilestone)
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /** Sigmoid blending weight: 1 / (1 + exp(-(days - center) / scale)) */
    private fun sigmoidWeight(days: Int, rampCenter: Int, rampScale: Double): Double =
        1.0 / (1.0 + exp(-(days - rampCenter).toDouble() / rampScale))

    private fun sigmoid(x: Double): Double = 1.0 / (1.0 + exp(-x.coerceIn(-500.0, 500.0)))

    private fun clamp01(value: Double): Double = max(0.0, min(1.0, value))
}
