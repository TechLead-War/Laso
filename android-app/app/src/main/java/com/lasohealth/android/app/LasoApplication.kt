package com.lasohealth.android.app

import android.app.Application
import com.lasohealth.android.firebase.FirebaseBootstrap

class LasoApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseBootstrap.initializeIfConfigured(this)
    }
}
