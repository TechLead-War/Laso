package com.lasohealth.android.feature.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasohealth.android.core.model.MorningCheckInResult

/**
 * Compact 3-question morning check-in for subjective recovery data.
 * Sleep Quality, Energy Level, Body Soreness on 1-5 emoji scale.
 * iOS parity: MorningCheckInView.swift
 */
@Composable
fun MorningCheckInCard(
    onComplete: (MorningCheckInResult) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var sleepQuality by remember { mutableIntStateOf(0) }
    var energyLevel by remember { mutableIntStateOf(0) }
    var soreness by remember { mutableIntStateOf(0) }
    var isSubmitting by remember { mutableStateOf(false) }

    val isComplete = sleepQuality > 0 && energyLevel > 0 && soreness > 0
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(
            width = 0.5.dp,
            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Quick check in",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "Takes less than 10 seconds",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier.size(24.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Dismiss",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                    )
                }
            }

            // Questions
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                CheckInRow(
                    icon = Icons.Filled.Bedtime,
                    label = "Sleep quality",
                    emojis = listOf("\uD83D\uDE2B", "\uD83D\uDE15", "\uD83D\uDE10", "\uD83D\uDE0A", "\uD83D\uDE34"),
                    selection = sleepQuality,
                    onSelect = { sleepQuality = it },
                )
                CheckInRow(
                    icon = Icons.Filled.Bolt,
                    label = "Energy level",
                    emojis = listOf("\uD83E\uDEAB", "\uD83D\uDE2E\u200D\uD83D\uDCA8", "\uD83D\uDE10", "\uD83D\uDCAA", "\u26A1"),
                    selection = energyLevel,
                    onSelect = { energyLevel = it },
                )
                CheckInRow(
                    icon = Icons.Filled.DirectionsWalk,
                    label = "Body soreness",
                    emojis = listOf("\uD83D\uDE35", "\uD83D\uDE23", "\uD83D\uDE10", "\uD83D\uDC4C", "\uD83E\uDD38"),
                    selection = soreness,
                    onSelect = { soreness = it },
                )
            }

            // Submit button
            AnimatedVisibility(
                visible = isComplete,
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
            ) {
                Button(
                    onClick = {
                        isSubmitting = true
                        onComplete(
                            MorningCheckInResult(
                                sleepQuality = sleepQuality,
                                energyLevel = energyLevel,
                                soreness = soreness,
                            ),
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSubmitting,
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                    ),
                ) {
                    if (isSubmitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                    }
                    Text(
                        text = "Done",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = if (isSubmitting) 8.dp else 0.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun CheckInRow(
    icon: ImageVector,
    label: String,
    emojis: List<String>,
    selection: Int,
    onSelect: (Int) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            emojis.forEachIndexed { index, emoji ->
                val value = index + 1
                val isSelected = selection == value

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clickable { onSelect(value) }
                        .background(
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                            } else {
                                MaterialTheme.colorScheme.surface
                            },
                            shape = RoundedCornerShape(8.dp),
                        )
                        .then(
                            if (isSelected) {
                                Modifier.background(
                                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(8.dp),
                                )
                            } else {
                                Modifier
                            },
                        )
                        .padding(vertical = 6.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = emoji,
                        fontSize = 22.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}
