package com.lasohealth.android.feature.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.lasohealth.android.core.data.OnboardingPrefs

/**
 * Main onboarding flow container that manages the multi-step pager.
 *
 * Steps (without cycle):  Welcome -> ValueProp -> Profile -> ConnectHealth -> FocusSelection -> Calibration
 * Steps (with cycle):     Welcome -> ValueProp -> Profile -> ConnectHealth -> CycleOptIn -> FocusSelection -> Calibration
 */
@Composable
fun OnboardingFlow(
    onComplete: () -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember { OnboardingPrefs(context) }

    var currentStep by remember { mutableIntStateOf(0) }
    var profileGender by remember { mutableStateOf("") }
    var profileAge by remember { mutableIntStateOf(0) }

    // Cycle step is only included for female users.
    val includesCycleStep = profileGender.lowercase() == "female"
    val totalSteps = if (includesCycleStep) 7 else 6

    // Step indices:
    //   0 = Welcome
    //   1 = ValueProp
    //   2 = Profile
    //   3 = ConnectHealth
    //   4 = CycleOptIn (female) | FocusSelection (non-female)
    //   5 = FocusSelection (female) | Calibration (non-female)
    //   6 = Calibration (female only)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        AnimatedContent(
            targetState = currentStep,
            transitionSpec = {
                slideInHorizontally { width -> width } + fadeIn() togetherWith
                    slideOutHorizontally { width -> -width } + fadeOut()
            },
            label = "onboarding_step",
        ) { step ->
            when (step) {
                0 -> WelcomeStep(
                    onContinue = { currentStep = 1 },
                )

                1 -> ValuePropositionStep(
                    onContinue = { currentStep = 2 },
                )

                2 -> ProfileCaptureStep(
                    onContinue = { age, gender ->
                        profileAge = age
                        profileGender = gender
                        prefs.userAge = age
                        prefs.userGender = gender
                        currentStep = 3
                    },
                )

                3 -> ConnectHealthStep(
                    onContinue = { currentStep = 4 },
                )

                4 -> if (includesCycleStep) {
                    CycleOptInStep(
                        onEnable = {
                            prefs.cycleTrackingEnabled = true
                            currentStep = 5
                        },
                        onSkip = {
                            prefs.cycleTrackingEnabled = false
                            currentStep = 5
                        },
                    )
                } else {
                    FocusSelectionStep(
                        onContinue = { focuses ->
                            prefs.healthFocuses = focuses.map { it.name }.toSet()
                            currentStep = 5
                        },
                    )
                }

                5 -> if (includesCycleStep) {
                    FocusSelectionStep(
                        onContinue = { focuses ->
                            prefs.healthFocuses = focuses.map { it.name }.toSet()
                            currentStep = 6
                        },
                    )
                } else {
                    CalibrationStep(
                        onComplete = {
                            prefs.onboardingCompleted = true
                            onComplete()
                        },
                    )
                }

                6 -> CalibrationStep(
                    onComplete = {
                        prefs.onboardingCompleted = true
                        onComplete()
                    },
                )
            }
        }

        // Progress dots — hidden on the welcome step.
        if (currentStep > 0) {
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                repeat(totalSteps) { index ->
                    val isActive = index <= currentStep
                    Box(
                        modifier = Modifier
                            .size(if (index == currentStep) 8.dp else 6.dp)
                            .background(
                                color = if (isActive) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f)
                                },
                                shape = CircleShape,
                            ),
                    )
                }
            }
        }
    }
}
