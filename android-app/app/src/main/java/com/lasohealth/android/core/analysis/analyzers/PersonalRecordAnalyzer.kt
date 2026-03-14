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
 * Tracks rolling personal records (7-day / 30-day moving average PRs),
 * activity streaks, and milestone achievements.
 *
 * Ported from iOS PersonalRecordAnalyzer.swift.
 */
class PersonalRecordAnalyzer : InsightAnalyzer {

    override val name: String = "PersonalRecordAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()
        insights += findRollingPRs(context.timeSeries)
        insights += findStreaks(context.timeSeries)
        insights += findMilestones(context.timeSeries)
        return insights
    }

    // ----- Configuration -----

    private data class TrackedMetric(
        val metric: HealthMetric,
        val lowerIsBetter: Boolean,
        val milestoneThreshold: Double?,
        val milestoneLabel: String?,
        val streakThreshold: Double?,
        val streakLabel: String?,
    )

    private val trackedMetrics = listOf(
        TrackedMetric(HealthMetric.STEPS, false, 10_000.0, "10K step day", 8_000.0, "8K+ steps"),
        TrackedMetric(HealthMetric.ACTIVE_CALORIES, false, null, null, null, null),
        TrackedMetric(HealthMetric.EXERCISE_MINUTES, false, null, null, 30.0, "30+ min exercise"),
        TrackedMetric(HealthMetric.VO2_MAX, false, null, null, null, null),
        TrackedMetric(HealthMetric.HEART_RATE_VARIABILITY, false, 50.0, "HRV above 50ms", null, null),
        TrackedMetric(HealthMetric.SLEEP_DURATION, false, 8.0, "8-hour sleep night", 7.0, "7+ hr sleep"),
        TrackedMetric(HealthMetric.RESTING_HEART_RATE, true, null, null, null, null),
        TrackedMetric(HealthMetric.STAND_HOURS, false, null, null, 10.0, "10+ stand hours"),
    )

    // ----- Rolling PRs -----

    private fun findRollingPRs(timeSeries: Map<HealthMetric, List<DailySample>>): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()
        for (tracked in trackedMetrics) {
            val samples = timeSeries[tracked.metric] ?: continue
            val sorted = samples.sortedBy { it.date }
            if (sorted.size < 30) continue
            val values = sorted.map { it.value }

            checkRollingPR(tracked.metric, values, 7, "7-day", tracked.lowerIsBetter)?.let { insights += it }
            checkRollingPR(tracked.metric, values, 30, "30-day", tracked.lowerIsBetter)?.let { insights += it }
        }
        return insights
    }

    private fun checkRollingPR(
        metric: HealthMetric,
        values: List<Double>,
        window: Int,
        windowLabel: String,
        lowerIsBetter: Boolean,
    ): AnalysisInsight? {
        if (values.size < window) return null

        val movingAverages = movingAverage(values, window)
        if (movingAverages.size <= 1) return null

        val currentAvg = movingAverages.last()
        val previous = movingAverages.dropLast(1)
        val bestPrevious = if (lowerIsBetter) previous.min() else previous.max()

        val isPR = if (lowerIsBetter) currentAvg <= bestPrevious else currentAvg >= bestPrevious
        if (!isPR) return null

        val improvement = if (bestPrevious != 0.0) {
            abs((currentAvg - bestPrevious) / bestPrevious) * 100.0
        } else 0.0

        // Only report meaningful PRs (>2% improvement) unless it's the first window
        if (improvement < 2.0 && movingAverages.size > window + 1) return null

        val previousBestIndex = if (lowerIsBetter) {
            previous.withIndex().minByOrNull { it.value }?.index ?: 0
        } else {
            previous.withIndex().maxByOrNull { it.value }?.index ?: 0
        }
        val recordAgeDays = previous.size - previousBestIndex
        val recordAgeNote = if (recordAgeDays > 7) " You beat a record that stood for $recordAgeDays days." else ""

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "New $windowLabel PR: ${metric.displayName}",
            detail = "Your $windowLabel average ${metric.displayName.lowercase()} hit a personal record: " +
                "${fmt1(currentAvg)} ${metric.unit}. Previous best: ${fmt1(bestPrevious)} ${metric.unit} " +
                "(${fmt1(improvement)}% improvement).$recordAgeNote",
            metric = metric,
            priority = InsightPriority.LOW,
            directive = InsightDirective.MAINTAIN,
        )
    }

    // ----- Streaks -----

    private fun findStreaks(timeSeries: Map<HealthMetric, List<DailySample>>): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()
        for (tracked in trackedMetrics) {
            val threshold = tracked.streakThreshold ?: continue
            val label = tracked.streakLabel ?: continue
            val samples = timeSeries[tracked.metric] ?: continue

            val valueMap = buildDayValueMap(samples)
            var currentStreak = 0
            var day = startOfToday()

            while (true) {
                val value = valueMap[day]
                if (value != null && value >= threshold) {
                    currentStreak++
                    day -= DAY_MS
                } else {
                    break
                }
            }

            if (currentStreak < 3) continue

            insights += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "$currentStreak-Day Streak: $label",
                detail = "You've hit $label for $currentStreak consecutive days. Keep the momentum going!",
                metric = tracked.metric,
                priority = InsightPriority.INFORMATIONAL,
                directive = InsightDirective.MAINTAIN,
            )
        }
        return insights
    }

    // ----- Milestones -----

    private fun findMilestones(timeSeries: Map<HealthMetric, List<DailySample>>): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()
        val now = System.currentTimeMillis()

        for (tracked in trackedMetrics) {
            val threshold = tracked.milestoneThreshold ?: continue
            val label = tracked.milestoneLabel ?: continue
            val samples = timeSeries[tracked.metric] ?: continue

            val recent = samples.filter { it.date > now - 7 * DAY_MS }
            val achieved = recent.any { sample ->
                if (tracked.lowerIsBetter) sample.value <= threshold else sample.value >= threshold
            }

            val older = samples.filter { it.date > now - 90 * DAY_MS && it.date <= now - 7 * DAY_MS }
            val previouslyAchieved = older.any { sample ->
                if (tracked.lowerIsBetter) sample.value <= threshold else sample.value >= threshold
            }

            if (!achieved || previouslyAchieved) continue

            insights += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Milestone: $label",
                detail = "You reached a new milestone: $label for the first time in 90 days. " +
                    "This shows real progress.",
                metric = tracked.metric,
                priority = InsightPriority.LOW,
                directive = InsightDirective.MAINTAIN,
            )
        }
        return insights
    }

    // ----- Helpers -----

    private fun movingAverage(values: List<Double>, window: Int): List<Double> {
        if (values.size < window) return emptyList()
        return (window..values.size).map { end ->
            values.subList(end - window, end).average()
        }
    }

    private fun buildDayValueMap(samples: List<DailySample>): Map<Long, Double> {
        val map = mutableMapOf<Long, Double>()
        for (sample in samples) {
            val day = startOfDay(sample.date)
            map[day] = sample.value // last write wins for same day
        }
        return map
    }

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun startOfToday(): Long = startOfDay(System.currentTimeMillis())

    private fun fmt1(v: Double): String = String.format("%.1f", v)

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
