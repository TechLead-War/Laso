package com.lasohealth.android.feature.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasohealth.android.core.model.ActivationProgressUi
import com.lasohealth.android.core.model.MilestoneEventUi
import kotlinx.coroutines.delay

/**
 * Compact banner shown during the first 8 days. Displays calibration progress,
 * next milestone preview, and celebratory animations when milestones unlock.
 * iOS parity: ActivationProgressBanner.swift
 */
@Composable
fun ActivationProgressBanner(
    state: ActivationProgressUi,
    onDismissCelebration: () -> Unit,
    modifier: Modifier = Modifier,
) {
    if (state.isComplete) return

    var showCelebration by remember { mutableStateOf(false) }

    // Auto-show celebration when milestone arrives
    LaunchedEffect(state.latestMilestone) {
        if (state.latestMilestone != null) {
            showCelebration = true
            delay(4000)
            showCelebration = false
            onDismissCelebration()
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        // Milestone celebration overlay
        AnimatedVisibility(
            visible = showCelebration && state.latestMilestone != null,
            enter = slideInVertically(spring(stiffness = Spring.StiffnessMediumLow)) { -it } + fadeIn(),
            exit = slideOutVertically(tween(300)) { -it } + fadeOut(tween(300)),
        ) {
            state.latestMilestone?.let { milestone ->
                CelebrationCard(
                    milestone = milestone,
                    onDismiss = {
                        showCelebration = false
                        onDismissCelebration()
                    },
                )
            }
        }

        // Progress bar section
        ProgressBarSection(
            currentDay = state.currentDay,
            progressFraction = state.progressFraction,
            progressDescription = state.progressDescription,
        )
    }
}

@Composable
private fun ProgressBarSection(
    currentDay: Int,
    progressFraction: Float,
    progressDescription: String,
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progressFraction,
        animationSpec = spring(stiffness = Spring.StiffnessLow),
        label = "progress",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(12.dp),
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // Header row: description + percentage
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = progressDescription,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Text(
                text = "${(progressFraction * 100).toInt()}%",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        // Progress bar with gradient fill (iOS: blue -> purple)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(animatedProgress)
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                Color(0xFF3478F6), // blue
                                Color(0xFF8B5CF6), // purple
                            ),
                        ),
                    ),
            )
        }

        // Milestone dots (8 days)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            for (day in 1..8) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .background(
                            color = if (day <= currentDay) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                            shape = CircleShape,
                        ),
                )
            }
        }
    }
}

@Composable
private fun CelebrationCard(
    milestone: MilestoneEventUi,
    onDismiss: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(14.dp),
                ambientColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                spotColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
            )
            .background(
                color = MaterialTheme.colorScheme.surface,
                shape = RoundedCornerShape(14.dp),
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Icon in accent rounded rect
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = RoundedCornerShape(10.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = milestone.icon,
                style = MaterialTheme.typography.titleMedium,
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = milestone.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = milestone.detail,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 2,
            )
        }

        IconButton(
            onClick = onDismiss,
            modifier = Modifier.size(24.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Dismiss",
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
            )
        }
    }
}
