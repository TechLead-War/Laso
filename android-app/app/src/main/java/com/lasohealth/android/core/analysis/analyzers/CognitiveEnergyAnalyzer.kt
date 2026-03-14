package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthMetric
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Detects patterns impacting cognitive performance (brain fog, slow processing, poor focus)
 * and physical energy/fatigue using existing health metric data.
 *
 * Generates insights for:
 *   1. Cognitive readiness score (composite of HRV, deep sleep, REM, SpO2, sleep duration)
 *   2. Sleep debt tracker (cumulative deficit vs baseline)
 *   3. Mental fatigue pattern (HRV + deep sleep declining together)
 *   4. Physical energy forecast (sleep deficit + elevated RHR + steps declining)
 *   5. Recovery day needed (consecutive high-activity days + declining recovery markers)
 *
 * Ported from iOS CognitiveEnergyAnalyzer.swift.
 */
class CognitiveEnergyAnalyzer : InsightAnalyzer {

    override val name: String = "CognitiveEnergyAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        cognitiveReadinessInsight(context)?.let { insights += it }
        sleepDebtInsight(context)?.let { insights += it }
        mentalFatigueInsight(context)?.let { insights += it }
        physicalEnergyInsight(context)?.let { insights += it }
        recoveryDayNeededInsight(context)?.let { insights += it }

        return insights
    }

    // ----- 1. Cognitive Readiness Score -----

    private fun cognitiveReadinessInsight(context: AnalysisContext): AnalysisInsight? {
        val hrvBaseline = context.baselines[HealthMetric.HEART_RATE_VARIABILITY] ?: return null
        context.baselines[HealthMetric.SLEEP_DURATION] ?: return null

        var score = 0.0
        var totalWeight = 0.0
        val components = mutableListOf<Pair<String, String>>()

        // HRV z-score (30%)
        recentAvg(context, HealthMetric.HEART_RATE_VARIABILITY, 3)?.let { avg ->
            val z = (avg - hrvBaseline.mean) / max(hrvBaseline.standardDeviation, 1.0)
            val normalized = min(max((z + 2) / 4.0, 0.0), 1.0) * 100.0
            score += normalized * 0.30
            totalWeight += 0.30
            if (z < -0.5) {
                val pctBelow = fmt0(abs(z * hrvBaseline.standardDeviation / hrvBaseline.mean * 100))
                components += "HRV" to "down ${pctBelow}% from baseline"
            }
        }

        // Deep sleep (25%)
        context.baselines[HealthMetric.SLEEP_DEEP]?.let { deepBaseline ->
            recentAvg(context, HealthMetric.SLEEP_DEEP, 3)?.let { avg ->
                val z = (avg - deepBaseline.mean) / max(deepBaseline.standardDeviation, 0.1)
                score += min(max((z + 2) / 4.0, 0.0), 1.0) * 100.0 * 0.25
                totalWeight += 0.25
                if (z < -0.5) {
                    val pct = fmt0(abs((avg - deepBaseline.mean) / deepBaseline.mean * 100))
                    components += "deep sleep" to "${pct}% below baseline"
                }
            }
        }

        // REM sleep (15%)
        context.baselines[HealthMetric.SLEEP_REM]?.let { remBaseline ->
            recentAvg(context, HealthMetric.SLEEP_REM, 3)?.let { avg ->
                val z = (avg - remBaseline.mean) / max(remBaseline.standardDeviation, 0.1)
                score += min(max((z + 2) / 4.0, 0.0), 1.0) * 100.0 * 0.15
                totalWeight += 0.15
                if (z < -0.5) {
                    val pct = fmt0(abs((avg - remBaseline.mean) / remBaseline.mean * 100))
                    components += "REM sleep" to "${pct}% below baseline"
                }
            }
        }

        // Blood oxygen (15%)
        context.baselines[HealthMetric.BLOOD_OXYGEN]?.let { o2Baseline ->
            recentAvg(context, HealthMetric.BLOOD_OXYGEN, 3)?.let { avg ->
                val z = (avg - o2Baseline.mean) / max(o2Baseline.standardDeviation, 0.1)
                score += min(max((z + 2) / 4.0, 0.0), 1.0) * 100.0 * 0.15
                totalWeight += 0.15
            }
        }

        // Sleep duration (15%)
        val sleepBaseline = context.baselines[HealthMetric.SLEEP_DURATION]!!
        recentAvg(context, HealthMetric.SLEEP_DURATION, 3)?.let { avg ->
            val z = (avg - sleepBaseline.mean) / max(sleepBaseline.standardDeviation, 0.1)
            score += min(max((z + 2) / 4.0, 0.0), 1.0) * 100.0 * 0.15
            totalWeight += 0.15
            if (z < -0.5) {
                val deficit = String.format("%.1f", sleepBaseline.mean - avg)
                components += "sleep duration" to "${deficit} hrs below your baseline"
            }
        }

        // Need at least HRV + one sleep metric
        if (totalWeight < 0.45) return null

        val finalScore = (score / totalWeight).roundToInt()
        // Only generate when noteworthy
        if (finalScore in 66..84) return null

        val isLow = finalScore <= 65
        val componentText = if (components.isEmpty()) "" else
            " \u2014 your ${components.joinToString(", ") { "${it.first} ${it.second}" }}"

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = if (isLow) "Low Cognitive Readiness" else "Strong Cognitive Readiness",
            detail = if (isLow) {
                "Your cognitive readiness is at $finalScore/100$componentText. " +
                    "Addressing these factors can sharpen mental clarity and processing speed."
            } else {
                "Your cognitive readiness is strong at $finalScore/100. " +
                    "HRV, sleep quality, and recovery markers are all above baseline."
            },
            metric = HealthMetric.HEART_RATE_VARIABILITY,
            priority = if (finalScore <= 40) InsightPriority.HIGH else InsightPriority.INFORMATIONAL,
            directive = if (isLow) InsightDirective.SLEEP_MORE else InsightDirective.MAINTAIN,
            confidence = min(totalWeight / 0.60, 1.0),
        )
    }

    // ----- 2. Sleep Debt Tracker -----

    private fun sleepDebtInsight(context: AnalysisContext): AnalysisInsight? {
        val sleepBaseline = context.baselines[HealthMetric.SLEEP_DURATION] ?: return null
        val samples = context.timeSeries[HealthMetric.SLEEP_DURATION] ?: return null

        val now = System.currentTimeMillis()
        val last7 = samples.filter { it.date > now - 7 * DAY_MS }
        if (last7.size < 5) return null

        val weeklyAvg = last7.map { it.value }.average()
        val dailyDeficit = sleepBaseline.mean - weeklyAvg
        val cumulativeDebt = dailyDeficit * last7.size
        if (cumulativeDebt < 2.0) return null

        val avgStr = String.format("%.1f", weeklyAvg)
        val baselineStr = String.format("%.1f", sleepBaseline.mean)
        val debtStr = String.format("%.1f", cumulativeDebt)
        val catchUpNights = kotlin.math.ceil(cumulativeDebt / 1.0).toInt()

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Sleep Debt Accumulating",
            detail = "You've accumulated $debtStr hours of sleep debt this week (averaging $avgStr hrs " +
                "vs your $baselineStr hr baseline). Cognitive impairment compounds with each deficit day " +
                "\u2014 reaction time and decision-making are most affected. " +
                "An extra hour per night for $catchUpNights nights can help clear this deficit.",
            metric = HealthMetric.SLEEP_DURATION,
            priority = if (cumulativeDebt >= 5.0) InsightPriority.HIGH else InsightPriority.MEDIUM,
            directive = InsightDirective.SLEEP_MORE,
        )
    }

    // ----- 3. Mental Fatigue Pattern -----

    private fun mentalFatigueInsight(context: AnalysisContext): AnalysisInsight? {
        val hrvTrend = context.trends[HealthMetric.HEART_RATE_VARIABILITY]
        val deepTrend = context.trends[HealthMetric.SLEEP_DEEP]

        val hrvDeclining = hrvTrend?.direction == TrendDirection.FALLING
        val deepDeclining = deepTrend?.direction == TrendDirection.FALLING
        if (!hrvDeclining && !deepDeclining) return null

        val hrvChange = hrvTrend?.rateOfChange ?: 0.0
        val deepChange = deepTrend?.rateOfChange ?: 0.0

        var signals = 0
        if (hrvDeclining && abs(hrvChange) > 5) signals++
        if (deepDeclining && abs(deepChange) > 5) signals++

        // Check mindfulness declining as additional signal
        val mindfulTrend = context.trends[HealthMetric.MINDFUL_MINUTES]
        if (mindfulTrend != null && mindfulTrend.rateOfChange < -10) signals++

        if (signals < 2) return null

        val parts = mutableListOf<String>()
        if (hrvDeclining) parts += "HRV dropped ${fmt0(abs(hrvChange))}%"
        if (deepDeclining) parts += "deep sleep down ${fmt0(abs(deepChange))}%"

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Mental Fatigue Pattern Detected",
            detail = "Your ${parts.joinToString(" and ")} over the past week \u2014 this combination " +
                "is strongly associated with mental fatigue, slower processing, and difficulty concentrating.",
            metric = HealthMetric.HEART_RATE_VARIABILITY,
            priority = InsightPriority.HIGH,
            directive = InsightDirective.SLEEP_MORE,
        )
    }

    // ----- 4. Physical Energy Forecast -----

    private fun physicalEnergyInsight(context: AnalysisContext): AnalysisInsight? {
        val signals = mutableListOf<String>()

        // Sleep deficit
        context.baselines[HealthMetric.SLEEP_DURATION]?.let { sleepBaseline ->
            recentAvg(context, HealthMetric.SLEEP_DURATION, 3)?.let { avg ->
                val deficit = (sleepBaseline.mean - avg) / sleepBaseline.mean * 100.0
                if (deficit > 8) {
                    signals += "sleep averaging ${String.format("%.1f", avg)} hrs (${fmt0(deficit)}% below baseline)"
                }
            }
        }

        // Elevated RHR
        val rhrTrend = context.trends[HealthMetric.RESTING_HEART_RATE]
        if (rhrTrend?.direction == TrendDirection.RISING && abs(rhrTrend.rateOfChange) > 3) {
            context.baselines[HealthMetric.RESTING_HEART_RATE]?.let { rhrBaseline ->
                val bpmIncrease = rhrBaseline.mean * abs(rhrTrend.rateOfChange) / 100.0
                signals += "resting HR elevated ${fmt0(bpmIncrease)} bpm"
            }
        }

        // Steps declining
        val stepsTrend = context.trends[HealthMetric.STEPS]
        if (stepsTrend?.direction == TrendDirection.FALLING && abs(stepsTrend.rateOfChange) > 10) {
            signals += "steps down ${fmt0(abs(stepsTrend.rateOfChange))}%"
        }

        if (signals.size < 2) return null

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Low Physical Energy",
            detail = "Your physical energy indicators are low: ${signals.joinToString(", ")}. " +
                "A 20-min walk will boost energy more than rest. Light movement improves circulation " +
                "and reduces fatigue more effectively than staying sedentary.",
            metric = HealthMetric.STEPS,
            priority = if (signals.size >= 3) InsightPriority.HIGH else InsightPriority.MEDIUM,
            directive = InsightDirective.INCREASE_ACTIVITY,
        )
    }

    // ----- 5. Recovery Day Needed -----

    private fun recoveryDayNeededInsight(context: AnalysisContext): AnalysisInsight? {
        val calSamples = context.timeSeries[HealthMetric.ACTIVE_CALORIES] ?: return null
        val calBaseline = context.baselines[HealthMetric.ACTIVE_CALORIES] ?: return null

        val now = System.currentTimeMillis()
        val recent7 = calSamples
            .filter { it.date > now - 7 * DAY_MS }
            .sortedByDescending { it.date }

        var consecutiveHighDays = 0
        for (sample in recent7) {
            if (sample.value > calBaseline.mean * 1.2) consecutiveHighDays++ else break
        }
        if (consecutiveHighDays < 3) return null

        val hrvDeclining = context.trends[HealthMetric.HEART_RATE_VARIABILITY]?.direction == TrendDirection.FALLING
        val rhrElevated = context.trends[HealthMetric.RESTING_HEART_RATE]?.direction == TrendDirection.RISING
        if (!hrvDeclining && !rhrElevated) return null

        val recoverySignals = mutableListOf<String>()
        if (hrvDeclining) {
            val change = context.trends[HealthMetric.HEART_RATE_VARIABILITY]?.rateOfChange ?: 0.0
            recoverySignals += "HRV down ${fmt0(abs(change))}%"
        }
        if (rhrElevated) {
            val change = context.trends[HealthMetric.RESTING_HEART_RATE]?.rateOfChange ?: 0.0
            recoverySignals += "resting HR up ${fmt0(abs(change))}%"
        }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Recovery Day Needed",
            detail = "You've been highly active for $consecutiveHighDays days straight and your recovery markers " +
                "are strained \u2014 ${recoverySignals.joinToString(", ")}. Without recovery, both mental sharpness " +
                "and physical performance decline. Consider a lighter day with walking, stretching, and extra sleep.",
            metric = HealthMetric.HEART_RATE_VARIABILITY,
            priority = InsightPriority.HIGH,
            directive = InsightDirective.REST,
        )
    }

    // ----- Helpers -----

    private fun recentAvg(context: AnalysisContext, metric: HealthMetric, days: Int): Double? {
        val samples = context.timeSeries[metric] ?: return null
        val now = System.currentTimeMillis()
        val recent = samples.filter { it.date > now - days * DAY_MS }
        return if (recent.isEmpty()) null else recent.map { it.value }.average()
    }

    private fun fmt0(v: Double): String = String.format("%.0f", v)

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
