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
import kotlin.math.sqrt

/**
 * Identifies day-of-week patterns, weakest/strongest days, weekday vs weekend gaps,
 * and weekly consistency for activity and sleep metrics.
 *
 * Ported from iOS WeeklyPatternAnalyzer.swift.
 */
class WeeklyPatternAnalyzer : InsightAnalyzer {

    override val name: String = "WeeklyPatternAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        findWeakestDay(context.timeSeries)?.let { insights += it }
        analyzeWeekendGap(context.timeSeries)?.let { insights += it }
        analyzeWeeklyConsistency(context.timeSeries)?.let { insights += it }

        return insights
    }

    // ----- Weakest Day (multi-metric) -----

    private fun findWeakestDay(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ): AnalysisInsight? {
        data class MetricEntry(val metric: HealthMetric, val label: String)

        val metricsToCheck = listOf(
            MetricEntry(HealthMetric.STEPS, "steps"),
            MetricEntry(HealthMetric.ACTIVE_CALORIES, "active calories"),
            MetricEntry(HealthMetric.EXERCISE_MINUTES, "exercise minutes"),
        )

        for (entry in metricsToCheck) {
            val samples = timeSeries[entry.metric] ?: continue
            val groups = groupByDayOfWeek(samples)

            val dayAverages = groups.mapNotNull { (day, values) ->
                if (values.size < 2) null
                else day to values.average()
            }.sortedBy { it.second }

            if (dayAverages.size < 5) continue

            val overallAvg = dayAverages.map { it.second }.average()
            val weakest = dayAverages.first()
            val strongest = dayAverages.last()
            if (overallAvg <= 0) continue

            val deficit = ((overallAvg - weakest.second) / overallAvg) * 100.0
            if (deficit < 10) continue

            val weakestName = dayName(weakest.first)
            val strongestName = dayName(strongest.first)

            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Weakest Day: $weakestName",
                detail = "$weakestName is your least active day with ${fmt0(weakest.second)} avg ${entry.label} " +
                    "— ${fmt0(deficit)}% below your daily average. $strongestName is your strongest (${fmt0(strongest.second)}).",
                metric = entry.metric,
                priority = if (deficit >= 25) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
                directive = InsightDirective.INCREASE_ACTIVITY,
            )
        }
        return null
    }

    // ----- Weekend vs Weekday Gap -----

    private fun analyzeWeekendGap(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ): AnalysisInsight? {
        data class MetricEntry(val metric: HealthMetric, val label: String, val unit: String)

        val metricsToCheck = listOf(
            MetricEntry(HealthMetric.STEPS, "steps", "steps"),
            MetricEntry(HealthMetric.EXERCISE_MINUTES, "exercise", "min"),
            MetricEntry(HealthMetric.ACTIVE_CALORIES, "active calories", "cal"),
            MetricEntry(HealthMetric.SLEEP_DURATION, "sleep", "hrs"),
        )

        for (entry in metricsToCheck) {
            val samples = timeSeries[entry.metric] ?: continue
            val groups = groupByDayOfWeek(samples)

            // Weekdays: Mon(2)..Fri(6)
            var weekdaySum = 0.0; var weekdayCount = 0
            for (day in listOf(Calendar.MONDAY, Calendar.TUESDAY, Calendar.WEDNESDAY, Calendar.THURSDAY, Calendar.FRIDAY)) {
                val values = groups[day] ?: continue
                weekdayCount += values.size
                weekdaySum += values.sum()
            }

            // Weekends: Sat(7), Sun(1)
            var weekendSum = 0.0; var weekendCount = 0
            for (day in listOf(Calendar.SATURDAY, Calendar.SUNDAY)) {
                val values = groups[day] ?: continue
                weekendCount += values.size
                weekendSum += values.sum()
            }

            if (weekdayCount < 5 || weekendCount < 2) continue

            val weekdayAvg = weekdaySum / weekdayCount
            val weekendAvg = weekendSum / weekendCount
            if (weekdayAvg <= 0) continue

            val gap = ((weekdayAvg - weekendAvg) / weekdayAvg) * 100.0
            if (abs(gap) < 15) continue

            val moreActive = if (gap > 0) "weekdays" else "weekends"

            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${entry.metric.displayName}: Weekday vs Weekend",
                detail = "Your ${entry.label} is ${fmt0(abs(gap))}% higher on $moreActive. " +
                    "Weekday avg: ${fmt0(weekdayAvg)} ${entry.unit}, weekend avg: ${fmt0(weekendAvg)} ${entry.unit}.",
                metric = entry.metric,
                priority = if (abs(gap) >= 30) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
                directive = InsightDirective.INFORMATIONAL,
            )
        }
        return null
    }

    // ----- Weekly Consistency -----

    private fun analyzeWeeklyConsistency(
        timeSeries: Map<HealthMetric, List<DailySample>>,
    ): AnalysisInsight? {
        val metricsToCheck = listOf(
            HealthMetric.STEPS,
            HealthMetric.EXERCISE_MINUTES,
            HealthMetric.ACTIVE_CALORIES,
            HealthMetric.SLEEP_DURATION,
        )

        for (metric in metricsToCheck) {
            val samples = timeSeries[metric] ?: continue
            val groups = groupByDayOfWeek(samples)

            val dayAverages = (1..7).mapNotNull { day ->
                val values = groups[day] ?: return@mapNotNull null
                if (values.size < 2) null else values.average()
            }

            if (dayAverages.size < 5) continue

            val mean = dayAverages.average()
            if (mean <= 0) continue

            val stdDev = stddev(dayAverages)
            val cv = stdDev / mean * 100.0
            val isConsistent = cv < 20

            return AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${metric.displayName} Consistency",
                detail = if (isConsistent) {
                    "Your ${metric.displayName.lowercase()} is consistent across the week " +
                        "with a coefficient of variation of ${fmt0(cv)}%."
                } else {
                    "Your ${metric.displayName.lowercase()} varies ${fmt0(cv)}% across the week " +
                        "(coefficient of variation)."
                },
                metric = metric,
                priority = if (cv > 35) InsightPriority.MEDIUM else InsightPriority.INFORMATIONAL,
                directive = InsightDirective.INFORMATIONAL,
            )
        }
        return null
    }

    // ----- Helpers -----

    /**
     * Groups sample values by day-of-week (Calendar.SUNDAY=1 .. Calendar.SATURDAY=7).
     */
    private fun groupByDayOfWeek(samples: List<DailySample>): Map<Int, List<Double>> {
        val cal = Calendar.getInstance()
        val groups = mutableMapOf<Int, MutableList<Double>>()
        for (sample in samples) {
            cal.timeInMillis = sample.date
            val dow = cal.get(Calendar.DAY_OF_WEEK)
            groups.getOrPut(dow) { mutableListOf() }.add(sample.value)
        }
        return groups
    }

    private fun dayName(calendarDayOfWeek: Int): String = when (calendarDayOfWeek) {
        Calendar.SUNDAY -> "Sunday"
        Calendar.MONDAY -> "Monday"
        Calendar.TUESDAY -> "Tuesday"
        Calendar.WEDNESDAY -> "Wednesday"
        Calendar.THURSDAY -> "Thursday"
        Calendar.FRIDAY -> "Friday"
        Calendar.SATURDAY -> "Saturday"
        else -> "Unknown"
    }

    private fun stddev(values: List<Double>): Double {
        val mean = values.average()
        val variance = values.map { (it - mean) * (it - mean) }.average()
        return sqrt(variance)
    }

    private fun fmt0(v: Double): String = String.format("%.0f", v)
}
