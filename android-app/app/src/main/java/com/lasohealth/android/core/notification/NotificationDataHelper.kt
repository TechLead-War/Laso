package com.lasohealth.android.core.notification

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Reads Health Connect data for notification content generation.
 *
 * This helper bridges the gap between the WorkManager worker (which runs
 * outside the UI layer and doesn't have access to ViewModels or the
 * AnalysisEngine singleton) and Health Connect. It performs lightweight,
 * targeted queries to populate notification text with real data.
 *
 * When Health Connect is unavailable or data is insufficient, every
 * method returns null so the caller can use fallback copy.
 */
class NotificationDataHelper(private val context: Context) {

    companion object {
        private const val TAG = "NotificationData"
    }

    // ── Health Score ────────────────────────────────────────────────────────

    /**
     * Estimate a health score from recent data.
     *
     * This is a lightweight approximation (not the full AnalysisEngine pipeline)
     * based on the most recent heart rate variability and resting heart rate.
     * Returns a score from 0-100, or null if data is insufficient.
     */
    suspend fun getHealthScore(): Int? {
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val now = Instant.now()
            val dayStart = now.minus(24, ChronoUnit.HOURS)

            // Read recent heart rate data
            val hrResponse = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(dayStart, now),
                ),
            )

            if (hrResponse.records.isEmpty()) return null

            // Calculate average heart rate from samples
            val allSamples = hrResponse.records.flatMap { it.samples }
            if (allSamples.isEmpty()) return null

            val avgHr = allSamples.map { it.beatsPerMinute }.average()

            // Read recent sleep
            val sleepStart = now.minus(2, ChronoUnit.DAYS)
            val sleepResponse = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(sleepStart, now),
                ),
            )

            val sleepHours = if (sleepResponse.records.isNotEmpty()) {
                val lastSession = sleepResponse.records.maxByOrNull { it.endTime }!!
                Duration.between(lastSession.startTime, lastSession.endTime).toMinutes() / 60.0
            } else {
                null
            }

            // Simple composite score:
            // Heart rate component: 60bpm=100, 80bpm=70, 100bpm=40
            val hrScore = ((100.0 - avgHr) * 1.5 + 50.0).coerceIn(20.0, 100.0)

            // Sleep component: 7-9hrs=100, <5hrs=40, >10hrs=60
            val sleepScore = if (sleepHours != null) {
                when {
                    sleepHours in 7.0..9.0 -> 95.0
                    sleepHours in 6.0..7.0 -> 80.0
                    sleepHours in 5.0..6.0 -> 65.0
                    sleepHours > 9.0 -> 70.0
                    else -> 45.0
                }
            } else {
                null
            }

            val score = if (sleepScore != null) {
                ((hrScore * 0.5) + (sleepScore * 0.5)).toInt()
            } else {
                hrScore.toInt()
            }

            score.coerceIn(0, 100)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to compute health score for notification", e)
            null
        }
    }

    // ── Sleep Insight ───────────────────────────────────────────────────────

    /**
     * Generate a brief sleep insight string from recent sleep sessions.
     *
     * Returns a fragment like "sleep duration dropped to 5.8 hours last night"
     * or "sleep has been consistent at 7.2 hours", or null if data is insufficient.
     */
    suspend fun getSleepInsight(): String? {
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val now = Instant.now()
            val start = now.minus(7, ChronoUnit.DAYS)

            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, now),
                ),
            )

            val sessions = response.records
            if (sessions.size < 2) return null

            val durations = sessions
                .sortedBy { it.endTime }
                .map { Duration.between(it.startTime, it.endTime).toMinutes() / 60.0 }

            val latest = durations.last()
            val average = durations.average()
            val latestFormatted = "%.1f".format(latest)
            val averageFormatted = "%.1f".format(average)

            when {
                latest < average * 0.85 ->
                    "sleep dropped to $latestFormatted hours last night, below your $averageFormatted-hour average"
                latest > average * 1.15 ->
                    "sleep jumped to $latestFormatted hours last night, above your usual $averageFormatted hours"
                durations.size >= 3 -> {
                    val stdDev = standardDeviation(durations)
                    if (stdDev < 0.5) {
                        "sleep has been remarkably consistent at around $averageFormatted hours"
                    } else {
                        "sleep has been averaging $averageFormatted hours with some variation"
                    }
                }
                else ->
                    "sleep averaged $averageFormatted hours over the past few nights"
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to generate sleep insight", e)
            null
        }
    }

    // ── Discovery Summary ───────────────────────────────────────────────────

    /**
     * Build a summary of patterns, correlations, anomalies, and insights
     * the AI has found during the user's first week.
     *
     * This queries Health Connect for basic trend data and generates
     * approximate counts. For a worker running outside the analysis engine,
     * this is a best-effort approximation.
     */
    suspend fun getDiscoverySummary(): DiscoverySummary {
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val now = Instant.now()
            val weekStart = now.minus(7, ChronoUnit.DAYS)

            // Count step trends as a proxy for activity insights
            val stepsResponse = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(weekStart, now),
                ),
            )

            // Count sleep sessions
            val sleepResponse = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(weekStart, now),
                ),
            )

            // Count heart rate readings
            val hrResponse = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(weekStart, now),
                ),
            )

            val hasSteps = stepsResponse.records.isNotEmpty()
            val hasSleep = sleepResponse.records.size >= 3
            val hasHr = hrResponse.records.isNotEmpty()

            // Approximate discovery counts based on data availability
            var insightCount = 0
            var patternCount = 0
            var correlationCount = 0
            var anomalyCount = 0
            var topCorrelation: Pair<String, String>? = null
            var trendingMetric: String? = null
            var trendingImproving = false

            if (hasSleep) {
                insightCount += 2  // sleep duration + consistency insights
                patternCount += 1  // sleep pattern detected

                // Check for sleep trend
                val sleepDurations = sleepResponse.records
                    .sortedBy { it.endTime }
                    .map { Duration.between(it.startTime, it.endTime).toMinutes() / 60.0 }
                if (sleepDurations.size >= 3) {
                    val trend = sleepDurations.last() - sleepDurations.first()
                    if (kotlin.math.abs(trend) > 0.5) {
                        trendingMetric = "sleep duration"
                        trendingImproving = trend > 0
                    }
                }
            }

            if (hasSteps) {
                insightCount += 1  // activity insight
                // Detect step variability as potential pattern
                val dailySteps = stepsResponse.records
                    .groupBy {
                        it.startTime.atZone(ZoneId.systemDefault()).toLocalDate()
                    }
                    .mapValues { (_, records) -> records.sumOf { it.count } }

                if (dailySteps.size >= 3) {
                    patternCount += 1
                    val values = dailySteps.values.toList()
                    val avg = values.average()
                    val deviations = values.count { kotlin.math.abs(it - avg) > avg * 0.3 }
                    if (deviations > 0) anomalyCount += deviations.coerceAtMost(2)
                }
            }

            if (hasHr && hasSleep) {
                correlationCount += 1  // HR-sleep correlation likely detectable
                topCorrelation = Pair("Heart Rate", "Sleep Duration")
            }

            if (hasHr) {
                insightCount += 1  // resting HR insight
                val allSamples = hrResponse.records.flatMap { it.samples }
                if (allSamples.size >= 10) {
                    val sorted = allSamples.sortedBy { it.time }
                    val firstHalf = sorted.take(sorted.size / 2).map { it.beatsPerMinute }.average()
                    val secondHalf = sorted.drop(sorted.size / 2).map { it.beatsPerMinute }.average()
                    if (kotlin.math.abs(firstHalf - secondHalf) > 5) {
                        if (trendingMetric == null) {
                            trendingMetric = "resting heart rate"
                            trendingImproving = secondHalf < firstHalf  // lower resting HR is better
                        }
                    }
                }
            }

            DiscoverySummary(
                anomalyCount = anomalyCount,
                correlationCount = correlationCount,
                patternCount = patternCount,
                insightCount = insightCount,
                topCorrelation = topCorrelation,
                trendingMetric = trendingMetric,
                trendingMetricImproving = trendingImproving,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to build discovery summary", e)
            DiscoverySummary()
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun standardDeviation(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.average()
        val variance = values.sumOf { (it - mean) * (it - mean) } / (values.size - 1)
        return kotlin.math.sqrt(variance)
    }
}
