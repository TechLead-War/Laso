package com.lasohealth.android.core.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * Notification channels for the Laso app.
 *
 * Channels:
 * - [ENGAGEMENT] — Day 0-7 onboarding engagement sequence
 * - [DAILY_SUMMARY] — Daily health briefing
 * - [ALERTS] — Critical and warning health alerts
 * - [REENGAGEMENT] — Low-priority reminders for lapsed users
 */
object NotificationChannels {

    const val ENGAGEMENT = "laso_engagement"
    const val DAILY_SUMMARY = "laso_daily_summary"
    const val ALERTS = "laso_alerts"
    const val REENGAGEMENT = "laso_reengagement"

    /**
     * Create all notification channels. Safe to call repeatedly — the system
     * ignores requests to create channels that already exist.
     */
    fun create(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channels = listOf(
            NotificationChannel(
                ENGAGEMENT,
                "Getting Started",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Tips and insights during your first week with Laso"
            },
            NotificationChannel(
                DAILY_SUMMARY,
                "Daily Summary",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Your daily health briefing"
            },
            NotificationChannel(
                ALERTS,
                "Health Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Critical and warning health alerts that need your attention"
            },
            NotificationChannel(
                REENGAGEMENT,
                "Reminders",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Gentle reminders to check in on your health data"
            },
        )

        manager.createNotificationChannels(channels)
    }
}
