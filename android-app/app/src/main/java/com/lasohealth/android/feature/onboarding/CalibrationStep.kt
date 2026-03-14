package com.lasohealth.android.feature.onboarding

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasohealth.android.ui.theme.AccentBlue
import kotlinx.coroutines.delay

private val SuccessGreen = Color(0xFF34C759)
private val ErrorRed = Color(0xFFFF3B30)

private enum class CalibrationState {
    RUNNING,
    SUCCESS,
    FAILED,
}

@Composable
fun CalibrationStep(onComplete: () -> Unit) {
    var state by remember { mutableStateOf(CalibrationState.RUNNING) }
    var errorMessage by remember { mutableStateOf("") }

    // Simulate calibration
    LaunchedEffect(state) {
        if (state == CalibrationState.RUNNING) {
            delay(3000L)
            state = CalibrationState.SUCCESS
        }
    }

    // Animated dots for running state
    var dotIndex by remember { mutableIntStateOf(0) }
    LaunchedEffect(state) {
        if (state == CalibrationState.RUNNING) {
            while (true) {
                delay(500L)
                dotIndex = (dotIndex + 1) % 4
            }
        }
    }
    val dots = ".".repeat(dotIndex)

    // Rotation animation for settings icon
    val infiniteTransition = rememberInfiniteTransition(label = "rotation")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000, easing = LinearEasing),
        ),
        label = "iconRotation",
    )

    val iconColor = when (state) {
        CalibrationState.RUNNING -> AccentBlue
        CalibrationState.SUCCESS -> SuccessGreen
        CalibrationState.FAILED -> ErrorRed
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Text(
            text = "Final step",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = "Laso",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
        )

        Spacer(modifier = Modifier.height(32.dp))

        Box(
            modifier = Modifier
                .size(88.dp)
                .background(
                    color = iconColor.copy(alpha = 0.12f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            when (state) {
                CalibrationState.RUNNING -> {
                    Icon(
                        imageVector = Icons.Filled.Settings,
                        contentDescription = "Calibrating",
                        modifier = Modifier
                            .size(44.dp)
                            .rotate(rotation),
                        tint = iconColor,
                    )
                }
                CalibrationState.SUCCESS -> {
                    Icon(
                        imageVector = Icons.Filled.Verified,
                        contentDescription = "Complete",
                        modifier = Modifier.size(44.dp),
                        tint = iconColor,
                    )
                }
                CalibrationState.FAILED -> {
                    Icon(
                        imageVector = Icons.Filled.Error,
                        contentDescription = "Failed",
                        modifier = Modifier.size(44.dp),
                        tint = iconColor,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        Text(
            text = when (state) {
                CalibrationState.RUNNING -> "Calibrating Your Baseline$dots"
                CalibrationState.SUCCESS -> "Calibration Complete"
                CalibrationState.FAILED -> "Calibration Incomplete"
            },
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Spacer(modifier = Modifier.height(10.dp))

        Text(
            text = when (state) {
                CalibrationState.RUNNING ->
                    "Your baseline is being built from historical health data. This happens only once."
                CalibrationState.SUCCESS ->
                    "Your historical baseline is ready. You will now start with personalized insights instead of generic ones."
                CalibrationState.FAILED -> errorMessage
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp),
        )

        if (state == CalibrationState.RUNNING) {
            Spacer(modifier = Modifier.height(12.dp))
            CircularProgressIndicator(
                modifier = Modifier.size(32.dp),
                color = AccentBlue,
                strokeWidth = 3.dp,
            )
        }

        if (state == CalibrationState.SUCCESS) {
            Spacer(modifier = Modifier.height(20.dp))
            Surface(
                modifier = Modifier.padding(horizontal = 32.dp),
                shape = RoundedCornerShape(12.dp),
                color = AccentBlue.copy(alpha = 0.12f),
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .background(
                                color = AccentBlue.copy(alpha = 0.12f),
                                shape = CircleShape,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Mic,
                            contentDescription = "Microphone",
                            modifier = Modifier.size(18.dp),
                            tint = AccentBlue,
                        )
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column {
                        Text(
                            text = "Works with Google Assistant",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onBackground,
                        )
                        Text(
                            text = "Try saying \"Hey Google, open Laso\"",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        when (state) {
            CalibrationState.RUNNING -> {
                // No buttons during calibration
            }
            CalibrationState.SUCCESS -> {
                Button(
                    onClick = onComplete,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(
                        text = "Start Your Journey",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            CalibrationState.FAILED -> {
                Button(
                    onClick = {
                        errorMessage = ""
                        state = CalibrationState.RUNNING
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp),
                    shape = RoundedCornerShape(14.dp),
                ) {
                    Text(
                        text = "Retry Calibration",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                TextButton(onClick = onComplete) {
                    Text(
                        text = "Skip for Now",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f),
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(48.dp))
    }
}
