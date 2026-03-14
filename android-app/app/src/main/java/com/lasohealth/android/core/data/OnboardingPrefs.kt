package com.lasohealth.android.core.data

import android.content.Context
import android.content.SharedPreferences

class OnboardingPrefs(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("laso_onboarding", Context.MODE_PRIVATE)

    var onboardingCompleted: Boolean
        get() = prefs.getBoolean("onboarding_completed", false)
        set(value) = prefs.edit().putBoolean("onboarding_completed", value).apply()

    var userAge: Int
        get() = prefs.getInt("user_age", 0)
        set(value) = prefs.edit().putInt("user_age", value).apply()

    var userGender: String
        get() = prefs.getString("user_gender", "") ?: ""
        set(value) = prefs.edit().putString("user_gender", value).apply()

    var cycleTrackingEnabled: Boolean
        get() = prefs.getBoolean("cycle_tracking_enabled", false)
        set(value) = prefs.edit().putBoolean("cycle_tracking_enabled", value).apply()

    var healthFocuses: Set<String>
        get() = prefs.getStringSet("health_focuses", emptySet()) ?: emptySet()
        set(value) = prefs.edit().putStringSet("health_focuses", value).apply()

    var deviceId: String
        get() = prefs.getString("device_id", "") ?: ""
        set(value) = prefs.edit().putString("device_id", value).apply()
}
