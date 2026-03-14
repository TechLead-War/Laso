package com.lasohealth.android.core.analysis.scoring

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthMetric

// ── Result Type ─────────────────────────────────────────────────────────────

/**
 * An identified health risk with probability, severity, and contributing metrics.
 *
 * @property category risk domain: "cardiovascular", "respiratory", "metabolic",
 *   "musculoskeletal", or "sleep_disorder".
 * @property probability estimated probability (0.0 - 1.0) based on available signals.
 * @property severity "low", "moderate", or "high".
 * @property description human-readable explanation of the risk.
 * @property metrics the health metrics that contributed to this risk assessment.
 */
data class HealthRisk(
    val category: String,
    val probability: Double,
    val severity: String,
    val description: String,
    val metrics: List<HealthMetric>,
)

// ── Engine ───────────────────────────────────────────────────────────────────

/**
 * Identifies potential health risks by combining clinical thresholds with trend analysis.
 *
 * The engine evaluates five risk categories:
 *
 * | Category         | Key Signals                                                   |
 * |------------------|---------------------------------------------------------------|
 * | Cardiovascular   | Elevated RHR, low HRV, high BP, AFib, declining VO2 max      |
 * | Respiratory      | Low SpO2, elevated respiratory rate, breathing disturbances   |
 * | Metabolic        | Elevated BMI/body fat, blood glucose, low activity            |
 * | Musculoskeletal  | Declining walking speed, asymmetry, low mobility metrics      |
 * | Sleep Disorder   | Short duration, high breathing disturbances, fragmentation    |
 *
 * Each risk is scored with a probability (0-1) and classified by severity.
 * Only risks with probability >= [MIN_PROBABILITY] are returned.
 */
class HealthRiskEngine {

    /**
     * Assess health risks from current data.
     *
     * @param timeSeries daily samples for all available metrics.
     * @param baselines pre-computed baselines for deviation analysis.
     * @param trends recent trend analysis results.
     * @return list of identified [HealthRisk]s sorted by probability descending.
     */
    fun assess(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): List<HealthRisk> {
        val risks = mutableListOf<HealthRisk>()

        assessCardiovascular(timeSeries, baselines, trends)?.let { risks += it }
        assessRespiratory(timeSeries, baselines, trends)?.let { risks += it }
        assessMetabolic(timeSeries, baselines, trends)?.let { risks += it }
        assessMusculoskeletal(timeSeries, baselines, trends)?.let { risks += it }
        assessSleepDisorder(timeSeries, baselines, trends)?.let { risks += it }

        return risks
            .filter { it.probability >= MIN_PROBABILITY }
            .sortedByDescending { it.probability }
    }

    // ── Risk Assessors ──────────────────────────────────────────────────────

    /**
     * Cardiovascular risk: elevated RHR, low HRV, high blood pressure, AFib,
     * declining VO2 max.
     */
    private fun assessCardiovascular(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthRisk? {
        var signals = 0.0
        var maxSignals = 0.0
        val involvedMetrics = mutableListOf<HealthMetric>()
        val reasons = mutableListOf<String>()

        // Elevated resting heart rate (> 80 bpm or > 1.5 SD above baseline).
        recentValue(timeSeries[HealthMetric.RESTING_HEART_RATE])?.let { rhr ->
            maxSignals += 2.0
            val baseline = baselines[HealthMetric.RESTING_HEART_RATE]
            val isElevated = rhr > 80 || (baseline != null && baseline.standardDeviation > 0 &&
                    (rhr - baseline.mean) / baseline.standardDeviation > 1.5)
            if (isElevated) {
                signals += if (rhr > 90) 2.0 else 1.5
                involvedMetrics += HealthMetric.RESTING_HEART_RATE
                reasons += "Elevated resting heart rate (${rhr.toInt()} bpm)"
            }
        }

        // Low HRV (< 20ms or > 1.5 SD below baseline).
        recentValue(timeSeries[HealthMetric.HEART_RATE_VARIABILITY])?.let { hrv ->
            maxSignals += 2.0
            val baseline = baselines[HealthMetric.HEART_RATE_VARIABILITY]
            val isLow = hrv < 20 || (baseline != null && baseline.standardDeviation > 0 &&
                    (baseline.mean - hrv) / baseline.standardDeviation > 1.5)
            if (isLow) {
                signals += if (hrv < 15) 2.0 else 1.5
                involvedMetrics += HealthMetric.HEART_RATE_VARIABILITY
                reasons += "Low heart rate variability (${hrv.toInt()} ms)"
            }
        }

        // High blood pressure (systolic > 140 or diastolic > 90).
        recentValue(timeSeries[HealthMetric.BLOOD_PRESSURE_SYSTOLIC])?.let { sys ->
            maxSignals += 2.0
            if (sys > 140) {
                signals += if (sys > 160) 2.0 else 1.5
                involvedMetrics += HealthMetric.BLOOD_PRESSURE_SYSTOLIC
                reasons += "Elevated systolic blood pressure (${sys.toInt()} mmHg)"
            }
        }
        recentValue(timeSeries[HealthMetric.BLOOD_PRESSURE_DIASTOLIC])?.let { dia ->
            maxSignals += 1.0
            if (dia > 90) {
                signals += 1.0
                involvedMetrics += HealthMetric.BLOOD_PRESSURE_DIASTOLIC
                reasons += "Elevated diastolic blood pressure (${dia.toInt()} mmHg)"
            }
        }

        // AFib burden.
        recentValue(timeSeries[HealthMetric.ATRIAL_FIBRILLATION_BURDEN])?.let { afib ->
            maxSignals += 2.0
            if (afib > 5) {
                signals += if (afib > 20) 2.0 else 1.5
                involvedMetrics += HealthMetric.ATRIAL_FIBRILLATION_BURDEN
                reasons += "Elevated AFib burden (${String.format("%.0f", afib)}%)"
            }
        }

        // Declining VO2 max trend.
        trends[HealthMetric.VO2_MAX]?.let { trend ->
            maxSignals += 1.0
            if (trend.direction == TrendDirection.FALLING && trend.confidence > 0.5) {
                signals += 1.0
                involvedMetrics += HealthMetric.VO2_MAX
                reasons += "VO2 Max trending downward"
            }
        }

        if (maxSignals <= 0 || signals <= 0) return null

        val probability = (signals / maxSignals).coerceIn(0.0, 1.0)
        return HealthRisk(
            category = "cardiovascular",
            probability = probability,
            severity = classifySeverity(probability),
            description = reasons.joinToString(". ") + ".",
            metrics = involvedMetrics.distinct(),
        )
    }

    /**
     * Respiratory risk: low SpO2, elevated respiratory rate, declining lung function,
     * sleep breathing disturbances.
     */
    private fun assessRespiratory(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthRisk? {
        var signals = 0.0
        var maxSignals = 0.0
        val involvedMetrics = mutableListOf<HealthMetric>()
        val reasons = mutableListOf<String>()

        // Low blood oxygen (< 95%).
        recentValue(timeSeries[HealthMetric.BLOOD_OXYGEN])?.let { spo2 ->
            maxSignals += 2.0
            if (spo2 < 95) {
                signals += if (spo2 < 92) 2.0 else 1.5
                involvedMetrics += HealthMetric.BLOOD_OXYGEN
                reasons += "Low blood oxygen (${String.format("%.1f", spo2)}%)"
            }
        }

        // Elevated respiratory rate (> 20 br/min or > 1.5 SD above baseline).
        recentValue(timeSeries[HealthMetric.RESPIRATORY_RATE])?.let { rr ->
            maxSignals += 1.5
            val baseline = baselines[HealthMetric.RESPIRATORY_RATE]
            val isElevated = rr > 20 || (baseline != null && baseline.standardDeviation > 0 &&
                    (rr - baseline.mean) / baseline.standardDeviation > 1.5)
            if (isElevated) {
                signals += if (rr > 24) 1.5 else 1.0
                involvedMetrics += HealthMetric.RESPIRATORY_RATE
                reasons += "Elevated respiratory rate (${String.format("%.1f", rr)} br/min)"
            }
        }

        // Declining VO2 max.
        trends[HealthMetric.VO2_MAX]?.let { trend ->
            maxSignals += 1.0
            if (trend.direction == TrendDirection.FALLING && trend.confidence > 0.5) {
                signals += 1.0
                involvedMetrics += HealthMetric.VO2_MAX
                reasons += "VO2 Max trending downward"
            }
        }

        // Sleep breathing disturbances.
        recentValue(timeSeries[HealthMetric.SLEEP_BREATHING_DISTURBANCES])?.let { events ->
            maxSignals += 1.5
            if (events > 5) {
                signals += if (events > 15) 1.5 else 1.0
                involvedMetrics += HealthMetric.SLEEP_BREATHING_DISTURBANCES
                reasons += "Elevated sleep breathing disturbances (${String.format("%.0f", events)} events/hr)"
            }
        }

        if (maxSignals <= 0 || signals <= 0) return null

        val probability = (signals / maxSignals).coerceIn(0.0, 1.0)
        return HealthRisk(
            category = "respiratory",
            probability = probability,
            severity = classifySeverity(probability),
            description = reasons.joinToString(". ") + ".",
            metrics = involvedMetrics.distinct(),
        )
    }

    /**
     * Metabolic risk: elevated BMI/body fat, blood glucose, low activity, rising weight.
     */
    private fun assessMetabolic(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthRisk? {
        var signals = 0.0
        var maxSignals = 0.0
        val involvedMetrics = mutableListOf<HealthMetric>()
        val reasons = mutableListOf<String>()

        // Elevated BMI (> 30 = obese).
        recentValue(timeSeries[HealthMetric.BMI])?.let { bmi ->
            maxSignals += 2.0
            if (bmi > 30) {
                signals += if (bmi > 35) 2.0 else 1.5
                involvedMetrics += HealthMetric.BMI
                reasons += "BMI in obese range (${String.format("%.1f", bmi)})"
            } else if (bmi > 25) {
                signals += 0.5
                involvedMetrics += HealthMetric.BMI
                reasons += "BMI in overweight range (${String.format("%.1f", bmi)})"
            }
        }

        // High body fat %.
        recentValue(timeSeries[HealthMetric.BODY_FAT_PERCENTAGE])?.let { bf ->
            maxSignals += 1.5
            if (bf > 30) {
                signals += if (bf > 35) 1.5 else 1.0
                involvedMetrics += HealthMetric.BODY_FAT_PERCENTAGE
                reasons += "Elevated body fat (${String.format("%.0f", bf)}%)"
            }
        }

        // Elevated blood glucose.
        recentValue(timeSeries[HealthMetric.BLOOD_GLUCOSE])?.let { glucose ->
            maxSignals += 2.0
            if (glucose > 126) {
                signals += 2.0
                involvedMetrics += HealthMetric.BLOOD_GLUCOSE
                reasons += "Fasting blood glucose elevated (${glucose.toInt()} mg/dL)"
            } else if (glucose > 100) {
                signals += 1.0
                involvedMetrics += HealthMetric.BLOOD_GLUCOSE
                reasons += "Blood glucose in pre-diabetic range (${glucose.toInt()} mg/dL)"
            }
        }

        // Low activity levels.
        recentValue(timeSeries[HealthMetric.STEPS])?.let { steps ->
            maxSignals += 1.0
            if (steps < 4000) {
                signals += if (steps < 2000) 1.0 else 0.5
                involvedMetrics += HealthMetric.STEPS
                reasons += "Low daily step count (${steps.toInt()} steps)"
            }
        }

        // Rising weight trend.
        trends[HealthMetric.WEIGHT]?.let { trend ->
            maxSignals += 1.0
            if (trend.direction == TrendDirection.RISING && trend.confidence > 0.5) {
                signals += 0.75
                involvedMetrics += HealthMetric.WEIGHT
                reasons += "Weight trending upward"
            }
        }

        if (maxSignals <= 0 || signals <= 0) return null

        val probability = (signals / maxSignals).coerceIn(0.0, 1.0)
        return HealthRisk(
            category = "metabolic",
            probability = probability,
            severity = classifySeverity(probability),
            description = reasons.joinToString(". ") + ".",
            metrics = involvedMetrics.distinct(),
        )
    }

    /**
     * Musculoskeletal risk: declining walking speed, asymmetry, reduced mobility, falls.
     */
    private fun assessMusculoskeletal(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthRisk? {
        var signals = 0.0
        var maxSignals = 0.0
        val involvedMetrics = mutableListOf<HealthMetric>()
        val reasons = mutableListOf<String>()

        // Low walking speed.
        recentValue(timeSeries[HealthMetric.WALKING_SPEED])?.let { speed ->
            maxSignals += 1.5
            if (speed < 3.5) {
                signals += if (speed < 2.5) 1.5 else 1.0
                involvedMetrics += HealthMetric.WALKING_SPEED
                reasons += "Low walking speed (${String.format("%.1f", speed)} km/h)"
            }
        }

        // Declining walking speed trend.
        trends[HealthMetric.WALKING_SPEED]?.let { trend ->
            maxSignals += 1.0
            if (trend.direction == TrendDirection.FALLING && trend.confidence > 0.5) {
                signals += 1.0
                involvedMetrics += HealthMetric.WALKING_SPEED
                reasons += "Walking speed declining"
            }
        }

        // Walking asymmetry (> 10% is concerning).
        recentValue(timeSeries[HealthMetric.WALKING_ASYMMETRY])?.let { asym ->
            maxSignals += 1.5
            if (asym > 10) {
                signals += if (asym > 20) 1.5 else 1.0
                involvedMetrics += HealthMetric.WALKING_ASYMMETRY
                reasons += "Walking asymmetry detected (${String.format("%.0f", asym)}%)"
            }
        }

        // Walking steadiness below threshold.
        recentValue(timeSeries[HealthMetric.WALKING_STEADINESS])?.let { steadiness ->
            maxSignals += 1.0
            if (steadiness < 70) {
                signals += 1.0
                involvedMetrics += HealthMetric.WALKING_STEADINESS
                reasons += "Reduced walking steadiness (${String.format("%.0f", steadiness)}%)"
            }
        }

        // Falls detected.
        recentValue(timeSeries[HealthMetric.NUMBER_OF_TIMES_FALLEN])?.let { falls ->
            maxSignals += 1.0
            if (falls > 0) {
                signals += 1.0
                involvedMetrics += HealthMetric.NUMBER_OF_TIMES_FALLEN
                reasons += "Fall(s) detected recently"
            }
        }

        if (maxSignals <= 0 || signals <= 0) return null

        val probability = (signals / maxSignals).coerceIn(0.0, 1.0)
        return HealthRisk(
            category = "musculoskeletal",
            probability = probability,
            severity = classifySeverity(probability),
            description = reasons.joinToString(". ") + ".",
            metrics = involvedMetrics.distinct(),
        )
    }

    /**
     * Sleep disorder risk: short duration, breathing disturbances, fragmentation,
     * declining sleep trend.
     */
    private fun assessSleepDisorder(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
        trends: Map<HealthMetric, MetricTrend>,
    ): HealthRisk? {
        var signals = 0.0
        var maxSignals = 0.0
        val involvedMetrics = mutableListOf<HealthMetric>()
        val reasons = mutableListOf<String>()

        // Chronic short sleep (< 6h average).
        recentAverage(timeSeries[HealthMetric.SLEEP_DURATION], days = 7)?.let { avg ->
            maxSignals += 2.0
            if (avg < 6.0) {
                signals += if (avg < 5.0) 2.0 else 1.5
                involvedMetrics += HealthMetric.SLEEP_DURATION
                reasons += "Chronically short sleep (${String.format("%.1f", avg)} hrs avg)"
            }
        }

        // Sleep breathing disturbances (apnea indicator).
        recentValue(timeSeries[HealthMetric.SLEEP_BREATHING_DISTURBANCES])?.let { events ->
            maxSignals += 2.0
            if (events > 5) {
                signals += when {
                    events > 30 -> 2.0 // severe apnea range
                    events > 15 -> 1.5 // moderate apnea range
                    else -> 1.0        // mild
                }
                involvedMetrics += HealthMetric.SLEEP_BREATHING_DISTURBANCES
                reasons += "Elevated breathing disturbances during sleep (${String.format("%.0f", events)} events/hr)"
            }
        }

        // Excessive awake time during sleep (fragmentation).
        val awakeDuration = recentAverage(timeSeries[HealthMetric.SLEEP_AWAKE], days = 7)
        val sleepDuration = recentAverage(timeSeries[HealthMetric.SLEEP_DURATION], days = 7)
        if (awakeDuration != null && sleepDuration != null && sleepDuration > 0) {
            maxSignals += 1.5
            val awakeRatio = awakeDuration / (sleepDuration + awakeDuration)
            if (awakeRatio > 0.15) {
                signals += if (awakeRatio > 0.25) 1.5 else 1.0
                involvedMetrics += HealthMetric.SLEEP_AWAKE
                reasons += "Fragmented sleep (${String.format("%.0f", awakeRatio * 100)}% time awake)"
            }
        }

        // Low deep sleep.
        recentValue(timeSeries[HealthMetric.SLEEP_DEEP])?.let { deep ->
            maxSignals += 1.0
            if (deep < 0.8) {
                signals += 1.0
                involvedMetrics += HealthMetric.SLEEP_DEEP
                reasons += "Low deep sleep (${String.format("%.1f", deep)} hrs)"
            }
        }

        // Declining sleep duration trend.
        trends[HealthMetric.SLEEP_DURATION]?.let { trend ->
            maxSignals += 1.0
            if (trend.direction == TrendDirection.FALLING && trend.confidence > 0.5) {
                signals += 0.75
                involvedMetrics += HealthMetric.SLEEP_DURATION
                reasons += "Sleep duration trending downward"
            }
        }

        if (maxSignals <= 0 || signals <= 0) return null

        val probability = (signals / maxSignals).coerceIn(0.0, 1.0)
        return HealthRisk(
            category = "sleep_disorder",
            probability = probability,
            severity = classifySeverity(probability),
            description = reasons.joinToString(". ") + ".",
            metrics = involvedMetrics.distinct(),
        )
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Get the most recent value for a metric. */
    private fun recentValue(samples: List<DailySample>?): Double? {
        return samples?.maxByOrNull { it.date }?.value
    }

    /** Get a recent average over [days], requiring at least [MIN_SAMPLES] samples. */
    private fun recentAverage(samples: List<DailySample>?, days: Int): Double? {
        if (samples.isNullOrEmpty()) return null
        val sorted = samples.sortedByDescending { it.date }
        val cutoff = sorted.first().date - days * MILLIS_PER_DAY
        val recent = sorted.filter { it.date >= cutoff }
        if (recent.size < MIN_SAMPLES) return null
        return recent.map { it.value }.average()
    }

    /** Classify severity from probability. */
    private fun classifySeverity(probability: Double): String = when {
        probability >= 0.7 -> "high"
        probability >= 0.4 -> "moderate"
        else -> "low"
    }

    companion object {
        private const val MILLIS_PER_DAY = 86_400_000L
        private const val MIN_SAMPLES = 3
        /** Minimum probability to include a risk in results. */
        private const val MIN_PROBABILITY = 0.15
    }
}
