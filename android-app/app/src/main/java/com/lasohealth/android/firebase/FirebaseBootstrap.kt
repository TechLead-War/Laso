package com.lasohealth.android.firebase

import android.content.Context
import com.lasohealth.android.BuildConfig
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics

object FirebaseBootstrap {
    fun initializeIfConfigured(context: Context): Boolean {
        val googleAppId = context.resources.getIdentifier("google_app_id", "string", context.packageName)
        if (googleAppId == 0) {
            return false
        }

        if (FirebaseApp.getApps(context).isEmpty()) {
            FirebaseApp.initializeApp(context) ?: return false
        }

        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(!BuildConfig.DEBUG)
        return true
    }
}
