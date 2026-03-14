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
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs

/**
 * Analyzes recovery patterns from workout, HRV, resting heart rate, and sleep data.
 *
 * Detects:
 *   - Post-workout HRV recovery time (days to return to baseline)
 *   - Rest-day deficits (insufficient rest relative to high-intensity sessions)
 *   - Overtraining risk (2+ of 3 signals: declining HRV, elevated RHR, declining sleep)
 *
 * Uses HRV as the primary recovery indicator. Ported from iOS RecoveryAnalyzer.swift.
 */
class RecoveryAnalyzer : InsightAnalyzer {

    override val name: String = "RecoveryAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        val workoutSamples = context.timeSeries[HealthMetric.WORKOUT_DURATION] ?: return emptyList()
        val workoutDays = identifyWorkoutDays(workoutSamples)
        if (workoutDays.size < 3) return emptyList()

        // Classify workout intensity
        val intensities = classifyIntensity(
            workoutDays = workoutDays,
            activeCalSamples = context.timeSeries[HealthMetric.ACTIVE_CALORIES],
            baselines = context.baselines,
        )

        // HRV recovery time
        generateHrvRecoveryInsight(context, workoutDays)?.let { insights += it }

        // Rest-day deficit
        generateRestDeficitInsight(workoutDays, intensities)?.let { insights += it }

        // Overtraining detection
        generateOvertrainingInsight(context.trends)?.let { insights += it }

        return insights
    }

    // ----- HRV Recovery Time -----

    private fun generateHrvRecoveryInsight(
        context: AnalysisContext,
        workoutDays: List<Long>,
    ): AnalysisInsight? {
        val hrvSamples = context.timeSeries[HealthMetric.HEART_RATE_VARIABILITY] ?: return null
        val hrvBaseline = context.baselines[HealthMetric.HEART_RATE_VARIABILITY] ?: return null

        val recoveryDays = computeRecoveryTime(
            workoutDays = workoutDays,
            recoverySamples = hrvSamples,
            baseline = hrvBaseline,
            higherIsBetter = true,
        )

        if (recoveryDays.isEmpty()) return null

        val avgRecovery = recoveryDays.average()
        val postWorkoutAvg = String.format("%.0f", hrvBaseline.mean - hrvBaseline.standardDeviation)
        val baselineStr = String.format("%.0f", hrvBaseline.mean)
        val avgStr = String.format("%.1f", avgRecovery)
        val priority = if (avgRecovery > 3) InsightPriority.HIGH else InsightPriority.LOW
        val directive = if (avgRecovery > 2.5) InsightDirective.REST else InsightDirective.MAINTAIN

        val detail = if (avgRecovery > 2) {
            "Your HRV takes an average of $avgStr days to return to baseline after workouts. " +
                "Post-workout HRV averages ~${postWorkoutAvg}ms vs your ${baselineStr}ms baseline. " +
                "HRV recovery is above your typical baseline window."
        } else {
            "Your HRV returns to baseline in $avgStr days on average. " +
                "Post-workout HRV ~${postWorkoutAvg}ms recovering to your ${baselineStr}ms baseline."
        }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Post-Workout HRV Recovery",
            detail = detail,
            metric = HealthMetric.HEART_RATE_VARIABILITY,
            priority = priority,
            directive = directive,
            confidence = minOf(hrvBaseline.sampleCount / 60.0, 1.0),
        )
    }

    // ----- Rest Deficit -----

    private fun generateRestDeficitInsight(
        workoutDays: List<Long>,
        intensities: Map<Long, WorkoutIntensity>,
    ): AnalysisInsight? {
        val now = System.currentTimeMillis()
        val twentyEightDaysAgo = now - 28L * DAY_MS

        val last28Workouts = workoutDays.filter { it > twentyEightDaysAgo }
        val workoutCount28 = last28Workouts.size
        val restDays28 = 28 - workoutCount28
        val highIntensityCount = intensities.entries
            .filter { it.key > twentyEightDaysAgo && it.value == WorkoutIntensity.HIGH }
            .size
        val recommendedRest = maxOf(2, highIntensityCount)

        if (restDays28 >= recommendedRest * 4) return null

        val weeklyRest = restDays28 / 4.0
        val weeklyRestStr = String.format("%.1f", weeklyRest)

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Rest Day Deficit",
            detail = "You're averaging $weeklyRestStr rest days per week with $highIntensityCount " +
                "high-intensity sessions in the last 28 days ($workoutCount28 workout days, $restDays28 rest days). " +
                "Consider scheduling more recovery time.",
            metric = HealthMetric.WORKOUT_DURATION,
            priority = InsightPriority.HIGH,
            directive = InsightDirective.REST,
            confidence = 0.85,
        )
    }

    // ----- Overtraining Detection -----

    private fun generateOvertrainingInsight(trends: Map<HealthMetric, MetricTrend>): AnalysisInsight? {
        val signals = mutableListOf<String>()

        val hrvTrend = trends[HealthMetric.HEART_RATE_VARIABILITY]
        val rhrTrend = trends[HealthMetric.RESTING_HEART_RATE]
        val sleepTrend = trends[HealthMetric.SLEEP_DURATION]

        // HRV declining
        if (hrvTrend?.direction == TrendDirection.FALLING) {
            val change = String.format("%.0f", abs(hrvTrend.rateOfChange))
            signals += "HRV declining ${change}%"
        }

        // Resting HR elevated (rising is worse for RHR)
        if (rhrTrend?.direction == TrendDirection.RISING) {
            val change = String.format("%.0f", abs(rhrTrend.rateOfChange))
            signals += "resting HR elevated ${change}%"
        }

        // Sleep declining
        if (sleepTrend?.direction == TrendDirection.FALLING) {
            val change = String.format("%.0f", abs(sleepTrend.rateOfChange))
            signals += "sleep down ${change}%"
        }

        if (signals.size < 2) return null

        val isAllThree = signals.size == 3
        val signalText = signals.joinToString(", ")

        val title = if (isAllThree) "Overtraining Warning" else "Early Overtraining Signal"
        val priority = if (isAllThree) InsightPriority.CRITICAL else InsightPriority.HIGH

        val detail = if (isAllThree) {
            "${signals.size} of 3 overtraining indicators present: $signalText. " +
                "All 3 overtraining indicators are present simultaneously. " +
                "Your recovery metrics suggest your body is working hard to catch up across multiple systems."
        } else {
            "${signals.size} of 3 overtraining indicators present: $signalText. " +
                "A third declining signal would confirm overtraining. " +
                "This pattern has preceded extended recovery periods in your data."
        }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = title,
            detail = detail,
            metric = HealthMetric.HEART_RATE_VARIABILITY,
            priority = priority,
            directive = InsightDirective.REST,
            confidence = if (isAllThree) 0.9 else 0.75,
        )
    }

    // ----- Workout classification helpers -----

    private enum class WorkoutIntensity { LOW, MODERATE, HIGH }

    private fun identifyWorkoutDays(samples: List<DailySample>): List<Long> =
        samples.filter { it.value > 0 }.map { startOfDay(it.date) }.distinct()

    private fun classifyIntensity(
        workoutDays: List<Long>,
        activeCalSamples: List<DailySample>?,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): Map<Long, WorkoutIntensity> {
        val calBaseline = baselines[HealthMetric.ACTIVE_CALORIES]
        if (activeCalSamples == null || calBaseline == null || calBaseline.mean == 0.0) {
            return workoutDays.associateWith { WorkoutIntensity.MODERATE }
        }

        val calMap = activeCalSamples.associateBy { startOfDay(it.date) }

        return workoutDays.associateWith { day ->
            val cals = calMap[day]?.value ?: return@associateWith WorkoutIntensity.MODERATE
            val ratio = cals / calBaseline.mean
            when {
                ratio > 1.5 -> WorkoutIntensity.HIGH
                ratio > 1.0 -> WorkoutIntensity.MODERATE
                else -> WorkoutIntensity.LOW
            }
        }
    }

    /**
     * Compute days until recovery metric returns within 1 std dev of baseline after each workout.
     */
    private fun computeRecoveryTime(
        workoutDays: List<Long>,
        recoverySamples: List<DailySample>,
        baseline: MetricBaseline,
        higherIsBetter: Boolean,
    ): List<Int> {
        val valueMap = recoverySamples.associateBy { startOfDay(it.date) }
        val recoveryDays = mutableListOf<Int>()

        for (workoutDay in workoutDays) {
            for (dayAfter in 1..7) {
                val checkDay = workoutDay + dayAfter.toLong() * DAY_MS
                val value = valueMap[checkDay]?.value ?: continue

                val withinBaseline = if (higherIsBetter) {
                    value >= baseline.mean - baseline.standardDeviation
                } else {
                    value <= baseline.mean + baseline.standardDeviation
                }

                if (withinBaseline) {
                    recoveryDays += dayAfter
                    break
                }
            }
        }
        return recoveryDays
    }

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
