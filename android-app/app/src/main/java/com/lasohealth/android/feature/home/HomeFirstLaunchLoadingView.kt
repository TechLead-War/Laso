package com.lasohealth.android.feature.home

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.AccentOrange
import kotlinx.coroutines.delay

/**
 * Animated first-launch loading screen during initial data sync and analysis.
 * iOS: HomeFirstLaunchLoadingView.swift — pulsing circles + phase-based icon/text.
 */
enum class LoadingPhase {
    IMPORTING,
    ANALYZING,
    DISCOVERING,
    COMPLETE,
}

@Composable
fun HomeFirstLaunchLoadingView(
    phase: LoadingPhase,
    dataPointCount: Int = 0,
    modifier: Modifier = Modifier,
) {
    val purple = Color(0xFF9C27B0)
    val green = Color(0xFF4CAF50)

    val phaseColor = when (phase) {
        LoadingPhase.IMPORTING, LoadingPhase.ANALYZING -> purple
        LoadingPhase.DISCOVERING -> AccentOrange
        LoadingPhase.COMPLETE -> green
    }

    val phaseText = when (phase) {
        LoadingPhase.IMPORTING -> "Syncing health data"
        LoadingPhase.ANALYZING -> if (dataPointCount > 0) {
            "Analyzing $dataPointCount data points"
        } else {
            "Analyzing your data"
        }
        LoadingPhase.DISCOVERING -> "Discovering patterns"
        LoadingPhase.COMPLETE -> "Ready"
    }

    // Animated dot count (1→2→3) cycling
    var dotCount by remember { mutableIntStateOf(1) }
    LaunchedEffect(phase) {
        if (phase != LoadingPhase.COMPLETE) {
            while (true) {
                delay(500)
                dotCount = (dotCount % 3) + 1
            }
        }
    }

    val dots = ".".repeat(dotCount)

    // Pulsing animation
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")

    val iconScale by infiniteTransition.animateFloat(
        initialValue = 0.8f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "iconScale",
    )

    val outerCircleScale by infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "outerCircle",
    )

    val middleCircleScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "middleCircle",
    )

    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Pulsing concentric circles + icon
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(180.dp),
        ) {
            // Middle circle (larger, more transparent)
            Canvas(modifier = Modifier.size(160.dp)) {
                val radius = (size.minDimension / 2) * middleCircleScale
                drawCircle(
                    color = phaseColor.copy(alpha = 0.08f),
                    radius = radius,
                    style = Stroke(width = 1.5f),
                )
            }

            // Outer circle
            Canvas(modifier = Modifier.size(120.dp)) {
                val radius = (size.minDimension / 2) * outerCircleScale
                drawCircle(
                    color = phaseColor.copy(alpha = 0.15f),
                    radius = radius,
                    style = Stroke(width = 2f),
                )
            }

            // Center icon
            val iconModifier = Modifier.size((48 * iconScale).dp)
            when (phase) {
                LoadingPhase.IMPORTING, LoadingPhase.ANALYZING -> Icon(
                    imageVector = Icons.Filled.Psychology,
                    contentDescription = null,
                    modifier = iconModifier,
                    tint = purple,
                )
                LoadingPhase.DISCOVERING -> Icon(
                    imageVector = Icons.Filled.AutoAwesome,
                    contentDescription = null,
                    modifier = iconModifier,
                    tint = AccentOrange,
                )
                LoadingPhase.COMPLETE -> Icon(
                    imageVector = Icons.Filled.CheckCircle,
                    contentDescription = null,
                    modifier = iconModifier,
                    tint = green,
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Phase text with animated dots
        Text(
            text = if (phase == LoadingPhase.COMPLETE) phaseText else "$phaseText$dots",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "This only happens once",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
        )
    }
}
