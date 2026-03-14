package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Detects early indicators of health issues BEFORE the user feels symptoms by
 * monitoring multi-metric patterns across fatigue, burnout, overtraining,
 * insomnia, immune compromise, and inactivity.
 *
 * Each detector uses minimum data guards, exponential moving averages for trend
 * detection, and produces natural-language explanations referencing the user's
 * actual values.
 *
 * Minimum 14 days of data for basic signals, 30 for full report.
 *
 * Ported from iOS `PredictiveHealthSignals.swift`.
 */
class PredictiveHealthSignals {

    companion object {
        /** Minimum days of data for any signal. */
        const val MINIMUM_DAYS = 14
        /** Minimum days for the full predictive report. */
        const val FULL_REPORT_MINIMUM_DAYS = 30
        /** EMA alpha for 7-day trend. */
        private const val EMA_ALPHA_7 = 2.0 / (7 + 1)
        /** EMA alpha for 14-day trend. */
        private const val EMA_ALPHA_14 = 2.0 / (14 + 1)
    }

    // -- Risk Level -------------------------------------------------------------

    enum class RiskLevel(val level: Int) {
        LOW(0), MODERATE(1), HIGH(2), CRITICAL(3);

        val displayName: String get() = name.lowercase().replaceFirstChar { it.uppercase() }
    }

    // -- Health Signal Report ---------------------------------------------------

    data class HealthSignalReport(
        val signals: List<PredictiveSignal>,
        val overallRisk: RiskLevel,
        val generatedAt: Long = System.currentTimeMillis(),
    ) {
        /** The most concerning signal, if any. */
        val topSignal: PredictiveSignal? get() = signals.maxByOrNull { it.probability }
    }

    /** Whether the engine has been run at least once. */
    var lastReport: HealthSignalReport? = null
        private set

    val isReady: Boolean get() = lastReport != null

    // -- Analysis ---------------------------------------------------------------

    /**
     * Analyze time series and baselines to generate predictive health signals.
     */
    fun analyze(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): HealthSignalReport {
        val signals = mutableListOf<PredictiveSignal>()

        val dayCount = timeSeries.values.maxOfOrNull { it.size } ?: 0
        if (dayCount < MINIMUM_DAYS) {
            val report = HealthSignalReport(emptyList(), RiskLevel.LOW)
            lastReport = report
            return report
        }

        // Run all 6 detectors.
        detectFatigue(timeSeries, baselines)?.let { signals.add(it) }
        detectBurnout(timeSeries, baselines)?.let { signals.add(it) }
        detectOvertraining(timeSeries, baselines)?.let { signals.add(it) }
        detectInsomnia(timeSeries, baselines)?.let { signals.add(it) }
        detectImmuneDip(timeSeries, baselines)?.let { signals.add(it) }
        detectInactivity(timeSeries, baselines)?.let { signals.add(it) }

        val overallRisk = signals.maxByOrNull { it.probability }?.let { topSignal ->
            when {
                topSignal.probability >= 0.7 -> RiskLevel.CRITICAL
                topSignal.probability >= 0.5 -> RiskLevel.HIGH
                topSignal.probability >= 0.3 -> RiskLevel.MODERATE
                else -> RiskLevel.LOW
            }
        } ?: RiskLevel.LOW

        val report = HealthSignalReport(signals, overallRisk)
        lastReport = report
        return report
    }

    // -- Fatigue Detector -------------------------------------------------------

    private fun detectFatigue(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Fatigue = declining HRV + rising RHR + reduced activity.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        // HRV declining trend.
        val hrvTrend = recentTrend(timeSeries[HealthMetric.HEART_RATE_VARIABILITY], 7)
        if (hrvTrend != null && hrvTrend < -0.3) {
            score += abs(hrvTrend) * 0.4
            evidenceCount++
            details.add("HRV declining")
        }

        // RHR rising trend.
        val rhrTrend = recentTrend(timeSeries[HealthMetric.RESTING_HEART_RATE], 7)
        if (rhrTrend != null && rhrTrend > 0.3) {
            score += rhrTrend * 0.3
            evidenceCount++
            details.add("RHR rising")
        }

        // Activity below baseline.
        val stepsDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.STEPS], baselines[HealthMetric.STEPS], 7,
        )
        if (stepsDeviation != null && stepsDeviation < -0.5) {
            score += abs(stepsDeviation) * 0.3
            evidenceCount++
            details.add("activity reduced")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.FATIGUE,
            probability = probability,
            timeHorizon = 2,
            description = "Fatigue indicators detected: ${details.joinToString(", ")}. " +
                "Consider extra rest over the next 1-2 days.",
        )
    }

    // -- Burnout Detector -------------------------------------------------------

    private fun detectBurnout(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Burnout = sustained low HRV + consistently elevated RHR + poor sleep over 14+ days.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        val hrvDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.HEART_RATE_VARIABILITY],
            baselines[HealthMetric.HEART_RATE_VARIABILITY], 14,
        )
        if (hrvDeviation != null && hrvDeviation < -0.8) {
            score += abs(hrvDeviation) * 0.35
            evidenceCount++
            details.add("persistently low HRV")
        }

        val rhrDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.RESTING_HEART_RATE],
            baselines[HealthMetric.RESTING_HEART_RATE], 14,
        )
        if (rhrDeviation != null && rhrDeviation > 0.8) {
            score += rhrDeviation * 0.3
            evidenceCount++
            details.add("elevated resting heart rate")
        }

        val sleepDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.SLEEP_DURATION],
            baselines[HealthMetric.SLEEP_DURATION], 14,
        )
        if (sleepDeviation != null && sleepDeviation < -0.5) {
            score += abs(sleepDeviation) * 0.35
            evidenceCount++
            details.add("sustained sleep deficit")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.BURNOUT,
            probability = probability,
            timeHorizon = 7,
            description = "Burnout risk elevated: ${details.joinToString(", ")}. " +
                "Your body may need a recovery period.",
        )
    }

    // -- Overtraining Detector --------------------------------------------------

    private fun detectOvertraining(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Overtraining = high exercise load + declining HRV + rising RHR.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        val exerciseDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.EXERCISE_MINUTES],
            baselines[HealthMetric.EXERCISE_MINUTES], 7,
        )
        if (exerciseDeviation != null && exerciseDeviation > 1.0) {
            score += exerciseDeviation * 0.3
            evidenceCount++
            details.add("training load elevated")
        }

        val hrvTrend = recentTrend(timeSeries[HealthMetric.HEART_RATE_VARIABILITY], 7)
        if (hrvTrend != null && hrvTrend < -0.5) {
            score += abs(hrvTrend) * 0.4
            evidenceCount++
            details.add("HRV dropping despite training")
        }

        val rhrTrend = recentTrend(timeSeries[HealthMetric.RESTING_HEART_RATE], 7)
        if (rhrTrend != null && rhrTrend > 0.5) {
            score += rhrTrend * 0.3
            evidenceCount++
            details.add("RHR climbing")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.OVERTRAINING,
            probability = probability,
            timeHorizon = 3,
            description = "Overtraining risk: ${details.joinToString(", ")}. " +
                "A deload or rest day could help your body recover.",
        )
    }

    // -- Insomnia Detector ------------------------------------------------------

    private fun detectInsomnia(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Insomnia = reduced sleep duration + reduced deep sleep + elevated awake time.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        val sleepDuration = deviationFromBaseline(
            timeSeries[HealthMetric.SLEEP_DURATION],
            baselines[HealthMetric.SLEEP_DURATION], 7,
        )
        if (sleepDuration != null && sleepDuration < -0.5) {
            score += abs(sleepDuration) * 0.35
            evidenceCount++
            details.add("sleep duration reduced")
        }

        val deepSleep = deviationFromBaseline(
            timeSeries[HealthMetric.SLEEP_DEEP],
            baselines[HealthMetric.SLEEP_DEEP], 7,
        )
        if (deepSleep != null && deepSleep < -0.5) {
            score += abs(deepSleep) * 0.35
            evidenceCount++
            details.add("deep sleep declining")
        }

        val awakeDev = deviationFromBaseline(
            timeSeries[HealthMetric.SLEEP_AWAKE],
            baselines[HealthMetric.SLEEP_AWAKE], 7,
        )
        if (awakeDev != null && awakeDev > 0.5) {
            score += awakeDev * 0.3
            evidenceCount++
            details.add("more awake time at night")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.INSOMNIA,
            probability = probability,
            timeHorizon = 3,
            description = "Insomnia risk: ${details.joinToString(", ")}. " +
                "Sleep hygiene adjustments may help.",
        )
    }

    // -- Immune Dip Detector ----------------------------------------------------

    private fun detectImmuneDip(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Immune dip = HRV crash + RHR spike + elevated respiratory rate + reduced activity.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        val hrvDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.HEART_RATE_VARIABILITY],
            baselines[HealthMetric.HEART_RATE_VARIABILITY], 3,
        )
        if (hrvDeviation != null && hrvDeviation < -1.5) {
            score += abs(hrvDeviation) * 0.3
            evidenceCount++
            details.add("HRV significantly below baseline")
        }

        val rhrDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.RESTING_HEART_RATE],
            baselines[HealthMetric.RESTING_HEART_RATE], 3,
        )
        if (rhrDeviation != null && rhrDeviation > 1.0) {
            score += rhrDeviation * 0.3
            evidenceCount++
            details.add("RHR elevated")
        }

        val respDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.RESPIRATORY_RATE],
            baselines[HealthMetric.RESPIRATORY_RATE], 3,
        )
        if (respDeviation != null && respDeviation > 0.5) {
            score += respDeviation * 0.2
            evidenceCount++
            details.add("respiratory rate elevated")
        }

        val bodyTempDev = deviationFromBaseline(
            timeSeries[HealthMetric.BODY_TEMPERATURE],
            baselines[HealthMetric.BODY_TEMPERATURE], 3,
        )
        if (bodyTempDev != null && bodyTempDev > 1.0) {
            score += bodyTempDev * 0.2
            evidenceCount++
            details.add("body temperature elevated")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.IMMUNE_DIP,
            probability = probability,
            timeHorizon = 2,
            description = "Potential immune compromise detected: ${details.joinToString(", ")}. " +
                "Extra rest and hydration are advisable.",
        )
    }

    // -- Inactivity Detector ----------------------------------------------------

    private fun detectInactivity(
        timeSeries: Map<HealthMetric, List<DailySample>>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): PredictiveSignal? {
        // Inactivity = sustained low steps + low exercise + low active calories.
        var score = 0.0
        var evidenceCount = 0
        val details = mutableListOf<String>()

        val stepsDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.STEPS],
            baselines[HealthMetric.STEPS], 7,
        )
        if (stepsDeviation != null && stepsDeviation < -1.0) {
            score += abs(stepsDeviation) * 0.4
            evidenceCount++
            details.add("steps well below baseline")
        }

        val exerciseDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.EXERCISE_MINUTES],
            baselines[HealthMetric.EXERCISE_MINUTES], 7,
        )
        if (exerciseDeviation != null && exerciseDeviation < -0.8) {
            score += abs(exerciseDeviation) * 0.3
            evidenceCount++
            details.add("exercise minutes reduced")
        }

        val calsDeviation = deviationFromBaseline(
            timeSeries[HealthMetric.ACTIVE_CALORIES],
            baselines[HealthMetric.ACTIVE_CALORIES], 7,
        )
        if (calsDeviation != null && calsDeviation < -0.8) {
            score += abs(calsDeviation) * 0.3
            evidenceCount++
            details.add("active calories low")
        }

        if (evidenceCount < 2) return null

        val probability = min(score, 1.0)
        return PredictiveSignal(
            type = SignalType.INACTIVITY,
            probability = probability,
            timeHorizon = 7,
            description = "Inactivity pattern detected: ${details.joinToString(", ")}. " +
                "Even a short walk can help break the cycle.",
        )
    }

    // -- Helpers ----------------------------------------------------------------

    /**
     * Compute EMA-based trend of the last [windowDays] samples.
     * Returns z-score normalized slope: positive = increasing, negative = decreasing.
     * Null if insufficient data.
     */
    private fun recentTrend(samples: List<DailySample>?, windowDays: Int): Double? {
        if (samples == null || samples.size < windowDays) return null

        val sorted = samples.sortedBy { it.date }
        val recent = sorted.takeLast(windowDays).map { it.value }
        if (recent.size < 3) return null

        val mean = recent.average()
        val sd = welfordStdDev(recent)
        if (sd <= 0) return null

        // EMA of the last half vs first half.
        val half = recent.size / 2
        val firstHalf = recent.subList(0, half).average()
        val secondHalf = recent.subList(half, recent.size).average()

        return (secondHalf - firstHalf) / sd
    }

    /**
     * Compute average deviation from baseline over the last [windowDays] samples.
     * Returns z-score deviation. Null if insufficient data.
     */
    private fun deviationFromBaseline(
        samples: List<DailySample>?,
        baseline: MetricBaseline?,
        windowDays: Int,
    ): Double? {
        if (samples == null || baseline == null || baseline.standardDeviation <= 0) return null

        val sorted = samples.sortedBy { it.date }
        val recent = sorted.takeLast(windowDays).map { it.value }
        if (recent.size < min(3, windowDays)) return null

        val recentMean = recent.average()
        return (recentMean - baseline.mean) / baseline.standardDeviation
    }

    private fun welfordStdDev(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        var mean = 0.0
        var m2 = 0.0
        for ((i, v) in values.withIndex()) {
            val n = i + 1
            val delta = v - mean
            mean += delta / n
            m2 += delta * (v - mean)
        }
        return sqrt(m2 / values.size)
    }
}
