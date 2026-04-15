package com.lasohealth.android.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.lasohealth.android.core.data.OnboardingPrefs
import com.lasohealth.android.core.data.SampleHealthDataRepository
import com.lasohealth.android.feature.onboarding.OnboardingFlow
import com.lasohealth.android.navigation.LasoNavScaffold
import com.lasohealth.android.ui.theme.LasoTheme

@Composable
fun LasoAndroidApp() {
    val context = LocalContext.current
    val prefs = remember { OnboardingPrefs(context) }
    val disclaimerPrefs = remember { DisclaimerPrefs(context) }

    var showOnboarding by remember { mutableStateOf(!prefs.onboardingCompleted) }
    var disclaimerAcknowledged by remember { mutableStateOf(disclaimerPrefs.acknowledged) }

    // Placeholder flags for Firebase Remote Config integration.
    // Set these to true to test the respective blocking screens.
    var forceUpdateRequired by remember { mutableStateOf(false) }
    var killSwitchEnabled by remember { mutableStateOf(false) }
    var killSwitchMessage by remember { mutableStateOf("We are performing scheduled maintenance. We will be back soon.") }
    var killSwitchDismissed by remember { mutableStateOf(false) }

    LasoTheme {
        when {
            // Priority 1: Force update blocks everything
            forceUpdateRequired -> {
                ForceUpdateScreen()
            }
            // Priority 2: Maintenance / kill switch (dismissible)
            killSwitchEnabled && !killSwitchDismissed -> {
                MaintenanceScreen(
                    message = killSwitchMessage,
                    onContinue = { killSwitchDismissed = true },
                )
            }
            // Priority 3: Onboarding (first launch)
            showOnboarding -> {
                OnboardingFlow(
                    onComplete = { showOnboarding = false },
                )
            }
            // Priority 4: Medical disclaimer (shown once after onboarding)
            !disclaimerAcknowledged -> {
                MedicalDisclaimerScreen(
                    onAcknowledge = {
                        disclaimerPrefs.acknowledged = true
                        disclaimerAcknowledged = true
                    },
                )
            }
            // Priority 5: Main app
            else -> {
                val repository = remember { SampleHealthDataRepository() }
                LasoNavScaffold(repository = repository)
            }
        }
    }
}
