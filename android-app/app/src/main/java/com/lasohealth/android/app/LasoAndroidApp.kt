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
    var showOnboarding by remember { mutableStateOf(!prefs.onboardingCompleted) }

    LasoTheme {
        if (showOnboarding) {
            OnboardingFlow(
                onComplete = { showOnboarding = false },
            )
        } else {
            val repository = remember { SampleHealthDataRepository() }
            LasoNavScaffold(repository = repository)
        }
    }
}
