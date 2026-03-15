package com.lasohealth.android.core.notification

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Detects the user's typical wake-up time from Health Connect sleep data.
 *
 * Queries the most recent 14 days of [SleepSessionRecord]s and computes
 * the median end time (when the user woke up). Returns null if fewer than
 * 3 sessions are available, letting the caller fall back to 7:00 AM.
 */
class WakeUpTimeDetector(private val context: Context) {

    companion object {
        private const val TAG = "WakeUpTimeDetector"
        private const val LOOKBACK_DAYS = 14L
        private const val MIN_SESSIONS = 3
    }

    /**
     * Detect the user's median wake-up time from Health Connect sleep sessions.
     *
     * @return A pair of (hour, minute) representing the median wake-up time,
     *         or `null` if insufficient data is available.
     */
    suspend fun detectWakeUpTime(): Pair<Int, Int>? {
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val now = Instant.now()
            val start = now.minus(LOOKBACK_DAYS, ChronoUnit.DAYS)

            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, now),
                ),
            )

            val sessions = response.records
            if (sessions.size < MIN_SESSIONS) {
                Log.d(TAG, "Only ${sessions.size} sleep sessions found (need $MIN_SESSIONS)")
                return null
            }

            // Extract wake-up times (end of each sleep session) in the device's local timezone
            val zone = ZoneId.systemDefault()
            val wakeUpMinutesOfDay = sessions.map { session ->
                val localEnd = session.endTime.atZone(zone).toLocalTime()
                localEnd.hour * 60 + localEnd.minute
            }.sorted()

            // Compute median
            val median = if (wakeUpMinutesOfDay.size % 2 == 0) {
                val mid = wakeUpMinutesOfDay.size / 2
                (wakeUpMinutesOfDay[mid - 1] + wakeUpMinutesOfDay[mid]) / 2
            } else {
                wakeUpMinutesOfDay[wakeUpMinutesOfDay.size / 2]
            }

            val hour = median / 60
            val minute = median % 60

            Log.d(TAG, "Detected median wake-up time: ${"%02d".format(hour)}:${"%02d".format(minute)} from ${sessions.size} sessions")
            Pair(hour, minute)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to detect wake-up time", e)
            null
        }
    }
}
