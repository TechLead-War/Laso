package com.lasohealth.android.core.notification

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Centralized notification delivery for the Laso app.
 *
 * Handles permission checks, building notifications with consistent
 * styling, and managing the notification lifecycle (show, cancel, cancelAll).
 *
 * All notifications open the main launcher activity when tapped.
 */
object LasoNotificationManager {

    private const val TAG = "LasoNotification"

    /** Permission request code for POST_NOTIFICATIONS on Android 13+. */
    const val PERMISSION_REQUEST_CODE = 9001

    // ── Notification IDs ────────────────────────────────────────────────────

    /** Engagement Day 1 notification. */
    const val ID_ENGAGEMENT_DAY_1 = 1001

    /** Engagement Day 2 notification. */
    const val ID_ENGAGEMENT_DAY_2 = 1002

    /** Engagement Day 3 notification. */
    const val ID_ENGAGEMENT_DAY_3 = 1003

    /** Engagement Day 5 notification. */
    const val ID_ENGAGEMENT_DAY_5 = 1005

    /** Engagement Day 7 notification. */
    const val ID_ENGAGEMENT_DAY_7 = 1007

    /** Daily summary notification. */
    const val ID_DAILY_SUMMARY = 2001

    /** Health alert base ID. */
    const val ID_ALERT_BASE = 3000

    /**
     * Map engagement day number to a stable notification ID.
     */
    fun engagementNotificationId(day: Int): Int = when (day) {
        1 -> ID_ENGAGEMENT_DAY_1
        2 -> ID_ENGAGEMENT_DAY_2
        3 -> ID_ENGAGEMENT_DAY_3
        5 -> ID_ENGAGEMENT_DAY_5
        7 -> ID_ENGAGEMENT_DAY_7
        else -> ID_ENGAGEMENT_DAY_1 + day
    }

    // ── Show Notification ───────────────────────────────────────────────────

    /**
     * Build and display a notification on the given channel.
     *
     * Silently returns without showing if the app lacks POST_NOTIFICATIONS
     * permission on Android 13+.
     *
     * @param context       Application or service context.
     * @param channelId     One of [NotificationChannels] channel IDs.
     * @param title         Notification title text.
     * @param body          Notification body text.
     * @param notificationId Stable ID for this notification (used for updates/cancellation).
     * @param autoCancel    Whether tapping the notification dismisses it (default true).
     */
    fun showNotification(
        context: Context,
        channelId: String,
        title: String,
        body: String,
        notificationId: Int,
        autoCancel: Boolean = true,
    ) {
        if (!hasNotificationPermission(context)) {
            Log.d(TAG, "Skipping notification — permission not granted")
            return
        }

        // Intent to open the main launcher activity
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent().apply {
                setClassName(context.packageName, "com.lasohealth.android.app.MainActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(autoCancel)
            .setPriority(
                when (channelId) {
                    NotificationChannels.ALERTS -> NotificationCompat.PRIORITY_HIGH
                    NotificationChannels.REENGAGEMENT -> NotificationCompat.PRIORITY_LOW
                    else -> NotificationCompat.PRIORITY_DEFAULT
                },
            )
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification)
        Log.d(TAG, "Notification shown: id=$notificationId, channel=$channelId")
    }

    // ── Permission Handling ─────────────────────────────────────────────────

    /**
     * Check whether the app has permission to post notifications.
     *
     * On Android 12 and below, notification permission is granted at install time.
     * On Android 13+ (API 33), the user must explicitly grant POST_NOTIFICATIONS.
     */
    fun hasNotificationPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Request the POST_NOTIFICATIONS permission on Android 13+.
     *
     * On earlier API levels this is a no-op since the permission is granted at install.
     *
     * @param activity The activity from which to launch the permission request.
     */
    fun requestPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                PERMISSION_REQUEST_CODE,
            )
        }
    }

    // ── Cancellation ────────────────────────────────────────────────────────

    /**
     * Cancel a specific notification by ID.
     */
    fun cancelNotification(context: Context, notificationId: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notificationId)
    }

    /**
     * Cancel all notifications posted by this app.
     */
    fun cancelAllNotifications(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancelAll()
    }
}
