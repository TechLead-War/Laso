package com.lasohealth.android.feature.onboarding.v2

import androidx.compose.animation.*
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier

@Composable
fun OnboardingV2Flow(
    onComplete: () -> Unit
) {
    var currentStep by remember { mutableIntStateOf(1) }
    val profile = remember { OnboardingV2Profile() }
    
    // Mock snapshot for screens 10-13
    val snapshot = remember { 
        OnboardingHealthSnapshot(
            heartRateAge = 2.0,
            sleepAge = 1.0,
            workoutsAge = 4.0,
            hrvAge = 2.0,
            hasRecoverySignal = true,
            restingHR = 58,
            restingHRMonthsCovered = 14,
            sleepAvgHours = 7,
            sleepAvgMins = 15,
            sleepLast7Nights = listOf(6.5, 7.2, 7.0, 6.8, 8.1, 7.5, 7.1),
            sleepMonthsCovered = 14,
            hrvWorstWeekday = 2, // Monday
            hrvWeekdayMeans = listOf(55.0, 42.0, 50.0, 54.0, 58.0, 60.0, 59.0),
            hrvWeeklyAvgMs = 54.0,
            hrvWeeksCovered = 52
        ) 
    }

    val goBack = { if (currentStep > 1) currentStep-- }
    val goNext = { if (currentStep < 16) currentStep++ else onComplete() }

    AnimatedContent(
        targetState = currentStep,
        transitionSpec = {
            if (targetState > initialState) {
                slideInHorizontally(initialOffsetX = { it }) + fadeIn() togetherWith
                        slideOutHorizontally(targetOffsetX = { -it }) + fadeOut()
            } else {
                slideInHorizontally(initialOffsetX = { -it }) + fadeIn() togetherWith
                        slideOutHorizontally(targetOffsetX = { it }) + fadeOut()
            }
        },
        modifier = Modifier.fillMaxSize(),
        label = "Onboarding Transition"
    ) { step ->
        when (step) {
            1 -> OnbV2Screen1Welcome(onContinue = goNext)
            2 -> OnbV2Screen2Promise(onBack = goBack, onContinue = goNext)
            3 -> OnbV2Screen3About(profile = profile, onBack = goBack, onContinue = goNext)
            4 -> OnbV2Screen4Goal(profile = profile, onBack = goBack, onContinue = goNext)
            5 -> OnbV2Screen5Symptoms(profile = profile, onBack = goBack, onContinue = goNext)
            6 -> OnbV2Screen6Activity(profile = profile, onBack = goBack, onContinue = goNext)
            7 -> OnbV2Screen7Wearable(profile = profile, onBack = goBack, onContinue = goNext)
            8 -> OnbV2Screen8Bridge(goal = profile.primaryGoal, onBack = goBack, onCTA = goNext) // Next is Health Auth
            9 -> goNext() // Screen 9 is Health Auth System prompt in iOS, we skip or handle in bridge
            10 -> OnbV2Screen10Scan(snapshot = snapshot, onComplete = goNext)
            11 -> OnbV2Screen11Heart(snapshot = snapshot, onBack = goBack, onContinue = goNext)
            12 -> OnbV2Screen12Sleep(snapshot = snapshot, onBack = goBack, onContinue = goNext)
            13 -> OnbV2Screen13HRV(snapshot = snapshot, onBack = goBack, onContinue = goNext)
            14 -> OnbV2Screen14Preview(onBack = goBack, onContinue = goNext)
            15 -> OnbV2Screen15SignIn(onBack = goBack, onSignedIn = goNext)
            16 -> OnbV2Screen16Paywall(onBack = goBack, onPurchased = onComplete)
        }
    }
}
