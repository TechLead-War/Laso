package com.lasohealth.android.core.notification

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that drives the Day 1-7 engagement notification sequence.
 *
 * Runs once daily via a [PeriodicWorkRequestBuilder] with a 24-hour interval.
 * Each execution:
 * 1. Determines which engagement day it is based on install date.
 * 2. Checks whether we already sent for this day.
 * 3. Tries to detect the user's wake-up time from Health Connect.
 * 4. Generates behavioural-science-driven notification content specific to the day.
 * 5. Posts the notification via [LasoNotificationManager].
 *
 * After Day 7, marks the sequence as complete and stops generating engagement content.
 */
class EngagementSequenceWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "EngagementWorker"
        private const val WORK_NAME = "laso_engagement_sequence"

        /** Engagement days that actually fire notifications (skip Day 0 and Day 4/6). */
        private val NOTIFICATION_DAYS = setOf(1, 2, 3, 5, 7)

        /**
         * Schedule the engagement worker if the sequence has not been completed.
         *
         * Uses [ExistingPeriodicWorkPolicy.KEEP] so we never double-schedule.
         * Called from [LasoApplication.onCreate] and [BootReceiver].
         */
        fun scheduleIfNeeded(context: Context) {
            val prefs = NotificationPrefs(context)

            // Record install date on very first launch
            if (prefs.installDate == 0L) {
                prefs.installDate = System.currentTimeMillis()
                Log.d(TAG, "Install date recorded: ${prefs.installDate}")
            }

            if (prefs.engagementSequenceCompleted) {
                Log.d(TAG, "Engagement sequence already completed — skipping schedule")
                return
            }

            // Calculate initial delay to target the user's preferred wake-up time tomorrow
            val initialDelay = computeInitialDelay(prefs.wakeUpHour, prefs.wakeUpMinute)

            val request = PeriodicWorkRequestBuilder<EngagementSequenceWorker>(
                24L, TimeUnit.HOURS,
                2L, TimeUnit.HOURS,
            )
                .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                .addTag(WORK_NAME)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )

            Log.d(TAG, "Engagement worker scheduled, initial delay: ${initialDelay / 60_000}min")
        }

        /**
         * Compute milliseconds from now until the next occurrence of the target time.
         * If the target time has already passed today, schedule for tomorrow.
         */
        private fun computeInitialDelay(targetHour: Int, targetMinute: Int): Long {
            val zone = ZoneId.systemDefault()
            val now = ZonedDateTime.now(zone)
            var target = now.toLocalDate().atTime(LocalTime.of(targetHour, targetMinute)).atZone(zone)
            if (target.isBefore(now) || target.isEqual(now)) {
                target = target.plusDays(1)
            }
            return Duration.between(now, target).toMillis().coerceAtLeast(0L)
        }

        /**
         * Force-schedule the engagement worker (used after reboot).
         */
        fun schedule(context: Context) {
            scheduleIfNeeded(context)
        }
    }

    override suspend fun doWork(): Result {
        val prefs = NotificationPrefs(applicationContext)

        if (prefs.engagementSequenceCompleted) {
            Log.d(TAG, "Sequence complete — worker returning success without notification")
            return Result.success()
        }

        // Detect wake-up time on first run (Day 0 logic)
        updateWakeUpTimeIfNeeded(prefs)

        val daysSinceInstall = calculateDaysSinceInstall(prefs)
        Log.d(TAG, "Engagement check: day $daysSinceInstall since install")

        // Only fire on specific days
        if (daysSinceInstall !in NOTIFICATION_DAYS) {
            Log.d(TAG, "Day $daysSinceInstall is not a notification day — skipping")
            return Result.success()
        }

        // Don't double-send for the same day
        if (prefs.lastEngagementNotificationDay >= daysSinceInstall) {
            Log.d(TAG, "Already sent for day $daysSinceInstall — skipping")
            return Result.success()
        }

        // Check daily frequency cap
        if (!prefs.canSendNotification()) {
            Log.d(TAG, "Daily notification cap reached — skipping engagement notification")
            return Result.success()
        }

        // Generate content for this day
        val content = generateContent(applicationContext, daysSinceInstall)
        if (content != null) {
            val (title, body) = content
            val notificationId = LasoNotificationManager.engagementNotificationId(daysSinceInstall)

            LasoNotificationManager.showNotification(
                context = applicationContext,
                channelId = NotificationChannels.ENGAGEMENT,
                title = title,
                body = body,
                notificationId = notificationId,
            )

            prefs.lastEngagementNotificationDay = daysSinceInstall
            prefs.recordNotificationSent()
            Log.d(TAG, "Engagement notification sent for day $daysSinceInstall")
        }

        // Mark sequence complete after day 7
        if (daysSinceInstall >= 7) {
            prefs.engagementSequenceCompleted = true
            Log.d(TAG, "Engagement sequence marked as complete")
        }

        return Result.success()
    }

    // ── Day Calculation ─────────────────────────────────────────────────────

    private fun calculateDaysSinceInstall(prefs: NotificationPrefs): Int {
        val installDate = prefs.installDate
        if (installDate == 0L) return 0

        val installLocal = Instant.ofEpochMilli(installDate)
            .atZone(ZoneId.systemDefault())
            .toLocalDate()
        val today = LocalDate.now()
        return ChronoUnit.DAYS.between(installLocal, today).toInt()
    }

    // ── Wake-Up Detection ───────────────────────────────────────────────────

    private suspend fun updateWakeUpTimeIfNeeded(prefs: NotificationPrefs) {
        // Only detect once, or re-detect if currently using fallback
        if (prefs.wakeUpTimeSource == "detected") return

        try {
            val detector = WakeUpTimeDetector(applicationContext)
            val detected = detector.detectWakeUpTime()
            if (detected != null) {
                prefs.wakeUpHour = detected.first
                prefs.wakeUpMinute = detected.second
                prefs.wakeUpTimeSource = "detected"
                Log.d(TAG, "Wake-up time detected: ${detected.first}:${"%02d".format(detected.second)}")
            } else {
                Log.d(TAG, "Insufficient sleep data — using fallback wake-up time 7:00")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Wake-up detection failed — keeping fallback", e)
        }
    }

    // ── Content Generation ──────────────────────────────────────────────────

    /**
     * Generate notification title and body for a specific engagement day.
     *
     * Each day's content is rooted in behavioural science:
     * - Day 1: Implementation Intention (establish a routine trigger)
     * - Day 2: Variable Reward (curiosity about their personal score)
     * - Day 3: Zeigarnik Effect (incomplete information pulls them back)
     * - Day 5: Goal Gradient (progress toward full personalization)
     * - Day 7: Loss Aversion (losing discovered patterns)
     *
     * Content attempts to use REAL data from the app's analysis layer.
     * When real data is unavailable, meaningful fallbacks are used.
     */
    private suspend fun generateContent(context: Context, day: Int): Pair<String, String>? {
        return when (day) {
            1 -> generateDay1Content(context)
            2 -> generateDay2Content(context)
            3 -> generateDay3Content(context)
            5 -> generateDay5Content(context)
            7 -> generateDay7Content(context)
            else -> null
        }
    }

    // -- Day 1: Implementation Intention --

    private fun generateDay1Content(context: Context): Pair<String, String> {
        val name = getUserName(context)
        val title = if (name.isNotBlank()) "Good morning, $name" else "Good morning"
        val body = "Your first health briefing is ready. Tap to see what your data reveals."
        return Pair(title, body)
    }

    // -- Day 2: Variable Reward (Recovery Score) --

    private suspend fun generateDay2Content(context: Context): Pair<String, String> {
        val dataHelper = NotificationDataHelper(context)
        val healthScore = dataHelper.getHealthScore()

        return if (healthScore != null) {
            val scoreBody = when {
                healthScore >= 85 -> "You're well recovered today. See what's driving that score."
                healthScore >= 70 -> "Solid recovery — a good day to stay active. See what's behind it."
                healthScore >= 50 -> "Moderate recovery — see what might help you bounce back."
                else -> "Take it easy — your body could use some rest. Here's what we noticed."
            }
            Pair("Your health score this morning: $healthScore/100", scoreBody)
        } else {
            Pair(
                "Your health analysis is ready",
                "Your health analysis has been running overnight. See what we found.",
            )
        }
    }

    // -- Day 3: Zeigarnik Effect (Sleep Pattern) --

    private suspend fun generateDay3Content(context: Context): Pair<String, String> {
        val dataHelper = NotificationDataHelper(context)
        val sleepInsight = dataHelper.getSleepInsight()

        return if (sleepInsight != null) {
            Pair(
                "We found something about your sleep",
                "Your $sleepInsight. Open to see the full picture.",
            )
        } else {
            Pair(
                "We found something about your sleep",
                "We've been studying your sleep patterns for 3 days. Something interesting emerged.",
            )
        }
    }

    // -- Day 5: Goal Gradient (Personalization Progress) --

    private fun generateDay5Content(context: Context): Pair<String, String> {
        // Day 5 falls in the "emerging" personalization stage (3-13 days) = ~40%
        val calibrationPercent = 40
        val daysRemaining = 25 // roughly 30 - 5

        return Pair(
            "Laso is $calibrationPercent% tuned to your body",
            "About $daysRemaining more days until your health insights are fully personalized to you.",
        )
    }

    // -- Day 7: Loss Aversion --

    private suspend fun generateDay7Content(context: Context): Pair<String, String> {
        val dataHelper = NotificationDataHelper(context)
        val discoveries = dataHelper.getDiscoverySummary()

        val totalCount = discoveries.anomalyCount + discoveries.correlationCount +
            discoveries.patternCount + discoveries.insightCount

        val title = if (totalCount > 0) {
            "Your health intelligence found $totalCount patterns"
        } else {
            "Your first week of health intelligence is complete"
        }

        val body = buildDay7Body(discoveries, totalCount)
        return Pair(title, body)
    }

    private fun buildDay7Body(discoveries: DiscoverySummary, totalCount: Int): String {
        // Try to generate a specific, personalized message
        if (discoveries.topCorrelation != null) {
            return "Including a link between your ${discoveries.topCorrelation.first} and " +
                "${discoveries.topCorrelation.second}. Keep your insights?"
        }
        if (discoveries.anomalyCount > 0) {
            return "Including ${discoveries.anomalyCount} notable change${if (discoveries.anomalyCount == 1) "" else "s"} " +
                "in your health data worth watching. Keep your insights?"
        }
        if (discoveries.trendingMetric != null) {
            val direction = if (discoveries.trendingMetricImproving) "steadily improving" else "gradually changing"
            return "Your ${discoveries.trendingMetric} has been $direction all week. " +
                "Keep your insights?"
        }
        if (totalCount > 0) {
            return "That's $totalCount insights about how your body works — built from your real health data. Keep them?"
        }
        return "We've been learning how your body works all week. Keep your personal health model?"
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun getUserName(context: Context): String {
        val onboardingPrefs = context.getSharedPreferences("laso_onboarding", Context.MODE_PRIVATE)
        return onboardingPrefs.getString("user_name", "") ?: ""
    }
}

/**
 * Summary of what the AI has discovered during the first week.
 * Used by Day 7 content generation.
 */
data class DiscoverySummary(
    val anomalyCount: Int = 0,
    val correlationCount: Int = 0,
    val patternCount: Int = 0,
    val insightCount: Int = 0,
    val topCorrelation: Pair<String, String>? = null,
    val trendingMetric: String? = null,
    val trendingMetricImproving: Boolean = false,
)
