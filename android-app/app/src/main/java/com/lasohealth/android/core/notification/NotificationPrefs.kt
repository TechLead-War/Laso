package com.lasohealth.android.core.notification

import android.content.Context
import android.content.SharedPreferences
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * SharedPreferences-backed persistence for all notification state.
 *
 * Tracks engagement sequence progress, wake-up time detection,
 * daily summary preferences, alert preferences, and per-day
 * frequency caps.
 */
class NotificationPrefs(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("laso_notifications", Context.MODE_PRIVATE)

    // ── Engagement Sequence ─────────────────────────────────────────────────

    /** Epoch millis when the app was first launched. Set once on initial boot. */
    var installDate: Long
        get() = prefs.getLong(KEY_INSTALL_DATE, 0L)
        set(value) = prefs.edit().putLong(KEY_INSTALL_DATE, value).apply()

    /** Which day of the engagement sequence we are currently on (0-7+). */
    var engagementDay: Int
        get() = prefs.getInt(KEY_ENGAGEMENT_DAY, 0)
        set(value) = prefs.edit().putInt(KEY_ENGAGEMENT_DAY, value).apply()

    /** The last day index for which we sent an engagement notification. */
    var lastEngagementNotificationDay: Int
        get() = prefs.getInt(KEY_LAST_ENGAGEMENT_NOTIFICATION_DAY, -1)
        set(value) = prefs.edit().putInt(KEY_LAST_ENGAGEMENT_NOTIFICATION_DAY, value).apply()

    /** Whether the 7-day engagement sequence has finished. */
    var engagementSequenceCompleted: Boolean
        get() = prefs.getBoolean(KEY_ENGAGEMENT_COMPLETED, false)
        set(value) = prefs.edit().putBoolean(KEY_ENGAGEMENT_COMPLETED, value).apply()

    // ── Wake-Up Time ────────────────────────────────────────────────────────

    /** Detected or fallback wake-up hour (0-23). Default: 7 (7 AM). */
    var wakeUpHour: Int
        get() = prefs.getInt(KEY_WAKEUP_HOUR, 7)
        set(value) = prefs.edit().putInt(KEY_WAKEUP_HOUR, value).apply()

    /** Detected or fallback wake-up minute (0-59). Default: 0. */
    var wakeUpMinute: Int
        get() = prefs.getInt(KEY_WAKEUP_MINUTE, 0)
        set(value) = prefs.edit().putInt(KEY_WAKEUP_MINUTE, value).apply()

    /** "detected" if derived from sleep data, "fallback" otherwise. */
    var wakeUpTimeSource: String
        get() = prefs.getString(KEY_WAKEUP_SOURCE, "fallback") ?: "fallback"
        set(value) = prefs.edit().putString(KEY_WAKEUP_SOURCE, value).apply()

    // ── Daily Summary ───────────────────────────────────────────────────────

    /** Whether the user wants a daily summary notification. */
    var dailySummaryEnabled: Boolean
        get() = prefs.getBoolean(KEY_DAILY_SUMMARY_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_DAILY_SUMMARY_ENABLED, value).apply()

    /** Hour of day for the daily summary (0-23). Default: 8 (8 AM). */
    var dailySummaryHour: Int
        get() = prefs.getInt(KEY_DAILY_SUMMARY_HOUR, 8)
        set(value) = prefs.edit().putInt(KEY_DAILY_SUMMARY_HOUR, value).apply()

    /** Minute of the daily summary time. Default: 0. */
    var dailySummaryMinute: Int
        get() = prefs.getInt(KEY_DAILY_SUMMARY_MINUTE, 0)
        set(value) = prefs.edit().putInt(KEY_DAILY_SUMMARY_MINUTE, value).apply()

    // ── Weekly Report ─────────────────────────────────────────────────────

    /** Whether the user wants a weekly report notification. */
    var weeklyReportEnabled: Boolean
        get() = prefs.getBoolean(KEY_WEEKLY_REPORT_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_WEEKLY_REPORT_ENABLED, value).apply()

    // ── Heart Rate Alerts ─────────────────────────────────────────────────

    /** Whether heart rate spike alerts are enabled. */
    var heartRateSpikeAlertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_HR_SPIKE_ALERTS, false)
        set(value) = prefs.edit().putBoolean(KEY_HR_SPIKE_ALERTS, value).apply()

    /** High heart rate threshold in bpm. Default: 140. */
    var highHRThreshold: Float
        get() = prefs.getFloat(KEY_HIGH_HR_THRESHOLD, 140f)
        set(value) = prefs.edit().putFloat(KEY_HIGH_HR_THRESHOLD, value).apply()

    /** Low heart rate threshold in bpm. Default: 45. */
    var lowHRThreshold: Float
        get() = prefs.getFloat(KEY_LOW_HR_THRESHOLD, 45f)
        set(value) = prefs.edit().putFloat(KEY_LOW_HR_THRESHOLD, value).apply()

    // ── Alert Preferences ───────────────────────────────────────────────────

    /** Whether critical health alerts are enabled. */
    var criticalAlertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_CRITICAL_ALERTS, true)
        set(value) = prefs.edit().putBoolean(KEY_CRITICAL_ALERTS, value).apply()

    /** Whether warning-level alerts are enabled (off by default to reduce noise). */
    var warningAlertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_WARNING_ALERTS, false)
        set(value) = prefs.edit().putBoolean(KEY_WARNING_ALERTS, value).apply()

    /** Whether trend reversal alerts are enabled. */
    var trendReversalAlertsEnabled: Boolean
        get() = prefs.getBoolean(KEY_TREND_REVERSAL_ALERTS, true)
        set(value) = prefs.edit().putBoolean(KEY_TREND_REVERSAL_ALERTS, value).apply()

    /** Whether improvement celebration alerts are enabled. */
    var improvementCelebrationsEnabled: Boolean
        get() = prefs.getBoolean(KEY_IMPROVEMENT_CELEBRATIONS, true)
        set(value) = prefs.edit().putBoolean(KEY_IMPROVEMENT_CELEBRATIONS, value).apply()

    /** Maximum notifications allowed per calendar day. */
    var maxNotificationsPerDay: Int
        get() = prefs.getInt(KEY_MAX_PER_DAY, 8)
        set(value) = prefs.edit().putInt(KEY_MAX_PER_DAY, value).apply()

    // ── Frequency Tracking ──────────────────────────────────────────────────

    /** Number of notifications sent so far on [lastNotificationDate]. */
    var notificationsSentToday: Int
        get() = prefs.getInt(KEY_SENT_TODAY, 0)
        set(value) = prefs.edit().putInt(KEY_SENT_TODAY, value).apply()

    /** The date (yyyy-MM-dd) for which [notificationsSentToday] was last recorded. */
    var lastNotificationDate: String
        get() = prefs.getString(KEY_LAST_NOTIFICATION_DATE, "") ?: ""
        set(value) = prefs.edit().putString(KEY_LAST_NOTIFICATION_DATE, value).apply()

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Increment the daily counter, resetting it if the date has rolled over.
     *
     * @return `true` if the notification is within the daily cap, `false` if we
     *         should suppress it.
     */
    fun recordNotificationSent(): Boolean {
        val today = LocalDate.now().format(DATE_FORMAT)
        if (lastNotificationDate != today) {
            lastNotificationDate = today
            notificationsSentToday = 0
        }
        return if (notificationsSentToday < maxNotificationsPerDay) {
            notificationsSentToday++
            true
        } else {
            false
        }
    }

    /**
     * Check whether we are still under the daily cap without consuming a slot.
     */
    fun canSendNotification(): Boolean {
        val today = LocalDate.now().format(DATE_FORMAT)
        if (lastNotificationDate != today) return true
        return notificationsSentToday < maxNotificationsPerDay
    }

    companion object {
        private val DATE_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

        private const val KEY_INSTALL_DATE = "install_date"
        private const val KEY_ENGAGEMENT_DAY = "engagement_day"
        private const val KEY_LAST_ENGAGEMENT_NOTIFICATION_DAY = "last_engagement_notification_day"
        private const val KEY_ENGAGEMENT_COMPLETED = "engagement_completed"
        private const val KEY_WAKEUP_HOUR = "wakeup_hour"
        private const val KEY_WAKEUP_MINUTE = "wakeup_minute"
        private const val KEY_WAKEUP_SOURCE = "wakeup_source"
        private const val KEY_DAILY_SUMMARY_ENABLED = "daily_summary_enabled"
        private const val KEY_DAILY_SUMMARY_HOUR = "daily_summary_hour"
        private const val KEY_DAILY_SUMMARY_MINUTE = "daily_summary_minute"
        private const val KEY_WEEKLY_REPORT_ENABLED = "weekly_report_enabled"
        private const val KEY_HR_SPIKE_ALERTS = "hr_spike_alerts_enabled"
        private const val KEY_HIGH_HR_THRESHOLD = "high_hr_threshold"
        private const val KEY_LOW_HR_THRESHOLD = "low_hr_threshold"
        private const val KEY_CRITICAL_ALERTS = "critical_alerts_enabled"
        private const val KEY_WARNING_ALERTS = "warning_alerts_enabled"
        private const val KEY_TREND_REVERSAL_ALERTS = "trend_reversal_alerts_enabled"
        private const val KEY_IMPROVEMENT_CELEBRATIONS = "improvement_celebrations_enabled"
        private const val KEY_MAX_PER_DAY = "max_per_day"
        private const val KEY_SENT_TODAY = "sent_today"
        private const val KEY_LAST_NOTIFICATION_DATE = "last_notification_date"
    }
}
