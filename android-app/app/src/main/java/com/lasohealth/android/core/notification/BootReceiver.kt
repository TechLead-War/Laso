package com.lasohealth.android.core.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-schedules the engagement sequence and daily summary workers
 * after the device reboots.
 *
 * WorkManager persists its work database across reboots, but periodic
 * work with initial delays needs to be re-enqueued to maintain correct
 * timing relative to the user's wake-up schedule.
 *
 * Registered in AndroidManifest.xml with BOOT_COMPLETED intent filter.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        Log.d(TAG, "Device booted — re-scheduling notification workers")
        EngagementSequenceWorker.schedule(context)
    }
}
