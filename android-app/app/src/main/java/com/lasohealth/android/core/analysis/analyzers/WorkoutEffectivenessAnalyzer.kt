package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs

/**
 * Measures workout consistency, VO2 Max response, and calorie efficiency.
 *
 * Generates insights for:
 *   1. Workout consistency score (% of weeks with 3+ sessions over 4 weeks)
 *   2. VO2 Max trend (30-day vs prior 30-day comparison)
 *   3. Calorie efficiency (kcal/min this week vs 30-day average)
 *
 * Ported from iOS WorkoutEffectivenessAnalyzer.swift.
 */
class WorkoutEffectivenessAnalyzer : InsightAnalyzer {

    override val name: String = "WorkoutEffectivenessAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        context.timeSeries[HealthMetric.WORKOUT_DURATION]?.let { workoutSamples ->
            analyzeConsistency(workoutSamples)?.let { insights += it }
        }

        context.timeSeries[HealthMetric.VO2_MAX]?.let { vo2Samples ->
            analyzeVO2MaxResponse(vo2Samples)?.let { insights += it }
        }

        val calSamples = context.timeSeries[HealthMetric.ACTIVE_CALORIES]
        val exSamples = context.timeSeries[HealthMetric.EXERCISE_MINUTES]
        if (calSamples != null && exSamples != null) {
            analyzeCalorieEfficiency(calSamples, exSamples)?.let { insights += it }
        }

        return insights
    }

    // ----- 1. Workout Consistency -----

    private fun analyzeConsistency(workoutSamples: List<DailySample>): AnalysisInsight? {
        val now = System.currentTimeMillis()
        val last28 = workoutSamples.filter { it.date > now - 28 * DAY_MS }
        if (last28.size < 7) return null

        // Count workout days per week for the last 4 weeks
        val weekCounts = IntArray(4)
        for (weekOffset in 0 until 4) {
            val weekStart = now - (28 - weekOffset * 7) * DAY_MS
            val weekEnd = now - (21 - weekOffset * 7) * DAY_MS
            weekCounts[weekOffset] = last28.count { it.value > 0 && it.date in weekStart until weekEnd }
        }

        val weeksWithTarget = weekCounts.count { it >= 3 }
        val consistencyScore = weeksWithTarget / 4.0 * 100.0
        val weeklyAvg = weekCounts.sum() / 4.0
        val weekBreakdown = weekCounts.mapIndexed { i, c -> "Week ${i + 1}: $c" }.joinToString(", ")

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Workout Consistency",
            detail = "${consistencyScore.toInt()}% of the last 4 weeks had 3+ workout days " +
                "(avg ${String.format("%.1f", weeklyAvg)}/week). Breakdown: $weekBreakdown.",
            metric = HealthMetric.WORKOUT_DURATION,
            priority = if (consistencyScore < 50) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
            directive = if (consistencyScore < 50) InsightDirective.INCREASE_ACTIVITY else InsightDirective.MAINTAIN,
        )
    }

    // ----- 2. VO2 Max Response -----

    private fun analyzeVO2MaxResponse(vo2Samples: List<DailySample>): AnalysisInsight? {
        val now = System.currentTimeMillis()
        val recent = vo2Samples.filter { it.date > now - 30 * DAY_MS }
        val older = vo2Samples.filter { it.date > now - 60 * DAY_MS && it.date <= now - 30 * DAY_MS }

        if (recent.size < 3 || older.size < 3) return null

        val recentAvg = recent.map { it.value }.average()
        val olderAvg = older.map { it.value }.average()
        if (olderAvg <= 0) return null

        val change = ((recentAvg - olderAvg) / olderAvg) * 100.0

        // Weekly VO2 progression
        val weeklyAvgs = mutableListOf<String>()
        for (weekOffset in 3 downTo 0) {
            val weekStart = now - 7 * (weekOffset + 1).toLong() * DAY_MS
            val weekEnd = now - 7 * weekOffset.toLong() * DAY_MS
            val weekSamples = vo2Samples.filter { it.date in weekStart until weekEnd }
            if (weekSamples.isNotEmpty()) {
                weeklyAvgs += String.format("%.1f", weekSamples.map { it.value }.average())
            }
        }
        val weeklyProgression = if (weeklyAvgs.isNotEmpty()) " Weekly VO2: ${weeklyAvgs.joinToString(" \u2192 ")}." else ""

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "VO2 Max Response",
            detail = "Your VO2 Max ${if (change > 0) "improved" else "decreased"} ${String.format("%.1f", abs(change))}% " +
                "over the last 30 days (${String.format("%.1f", olderAvg)} \u2192 ${String.format("%.1f", recentAvg)} " +
                "${HealthMetric.VO2_MAX.unit}).$weeklyProgression",
            metric = HealthMetric.VO2_MAX,
            priority = if (abs(change) > 5) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
            directive = if (change > 0) InsightDirective.MAINTAIN else InsightDirective.INCREASE_ACTIVITY,
        )
    }

    // ----- 3. Calorie Efficiency -----

    private fun analyzeCalorieEfficiency(
        calSamples: List<DailySample>,
        exSamples: List<DailySample>,
    ): AnalysisInsight? {
        val now = System.currentTimeMillis()

        // Build day-aligned pairs
        val calByDay = calSamples.associate { startOfDay(it.date) to it.value }
        val exByDay = exSamples.associate { startOfDay(it.date) to it.value }

        val aligned7d = mutableListOf<Pair<Double, Double>>()
        val aligned30d = mutableListOf<Pair<Double, Double>>()

        for ((day, cal) in calByDay) {
            val ex = exByDay[day] ?: continue
            if (ex <= 0) continue
            if (day > now - 7 * DAY_MS) aligned7d += cal to ex
            if (day > now - 30 * DAY_MS) aligned30d += cal to ex
        }

        if (aligned7d.size < 3 || aligned30d.size < 7) return null

        val efficiency7d = aligned7d.map { it.first / it.second }.average()
        val efficiency30d = aligned30d.map { it.first / it.second }.average()
        if (efficiency30d <= 0) return null

        val change = ((efficiency7d - efficiency30d) / efficiency30d) * 100.0

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Calorie Efficiency",
            detail = "You're burning ${String.format("%.1f", efficiency7d)} kcal/min this week vs " +
                "${String.format("%.1f", efficiency30d)} kcal/min over 30 days " +
                "(${if (change > 0) "+" else ""}${String.format("%.0f", change)}%).",
            metric = HealthMetric.ACTIVE_CALORIES,
            priority = InsightPriority.INFORMATIONAL,
            directive = InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Helpers -----

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
