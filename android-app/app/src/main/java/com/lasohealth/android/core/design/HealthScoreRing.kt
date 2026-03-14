package com.lasohealth.android.core.design

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.EaseInOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * iOS-matched HealthScoreRing.
 * Score text size scales with ring size (iOS uses 44pt for 160dp ring, ~28pt for 100dp).
 * Score text is colored by score value. Label is secondary.
 */
@Composable
fun HealthScoreRing(
    score: Int,
    modifier: Modifier = Modifier,
    size: Dp = 120.dp,
    strokeWidth: Dp = 12.dp,
    label: String? = null,
) {
    val targetProgress = score.coerceIn(0, 100) / 100f
    var animatedTarget by remember { mutableFloatStateOf(0f) }
    val progress by animateFloatAsState(
        targetValue = animatedTarget,
        animationSpec = tween(durationMillis = 1000, easing = EaseInOut),
        label = "scoreProgress",
    )
    LaunchedEffect(score) {
        animatedTarget = targetProgress
    }

    val scoreColor = LasoTokens.scoreColor(score)
    val trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)

    // Scale text size proportional to ring size (iOS: 44sp for 160dp, 28sp for 100dp, 14sp for 36dp)
    val scoreFontSize = when {
        size >= 140.dp -> 44.sp
        size >= 100.dp -> 28.sp
        size >= 60.dp -> 18.sp
        else -> 12.sp
    }
    val labelFontSize = when {
        size >= 100.dp -> 13.sp
        size >= 60.dp -> 10.sp
        else -> 8.sp
    }

    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val sw = strokeWidth.toPx()
            val inset = sw / 2f
            val diameter = this.size.minDimension - sw

            // Track
            drawArc(
                color = trackColor,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(diameter, diameter),
                style = Stroke(width = sw, cap = StrokeCap.Round),
            )

            // Progress arc in score color
            drawArc(
                brush = LasoTokens.scoreBrush(score),
                startAngle = -90f,
                sweepAngle = progress * 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(diameter, diameter),
                style = Stroke(width = sw, cap = StrokeCap.Round),
            )
        }

        // Center text: score (colored) + optional label (secondary)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = score.toString(),
                fontSize = scoreFontSize,
                fontWeight = FontWeight.Bold,
                color = scoreColor,
                textAlign = TextAlign.Center,
            )
            if (label != null) {
                Text(
                    text = label,
                    fontSize = labelFontSize,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}
