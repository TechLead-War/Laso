package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.TodayWorkoutUiState
import com.lasohealth.android.core.model.WorkoutBlockUi
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

// ── Recovery band color mapping ─────────────────────────────────────────────

private fun recoveryBandColor(band: String): Color {
    val lower = band.lowercase()
    return when {
        "green" in lower -> AccentGreen
        "yellow" in lower -> AccentYellow
        "red" in lower -> AccentRed
        else -> AccentGreen
    }
}

// ── Zone color mapping ──────────────────────────────────────────────────────

private fun zoneColor(zone: Int): Color = when (zone) {
    1 -> AccentBlue
    2 -> AccentGreen
    3 -> AccentYellow
    4 -> AccentOrange
    5 -> AccentRed
    else -> AccentGreen
}

// ── Block tint based on name ────────────────────────────────────────────────

private fun blockTint(name: String): Color {
    val lower = name.lowercase()
    return when {
        "warm" in lower -> AccentOrange
        "cool" in lower -> AccentBlue
        else -> AccentGreen
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayWorkoutScreen(
    state: TodayWorkoutUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Today's Workout",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
        modifier = modifier,
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.padding(innerPadding),
            contentPadding = PaddingValues(bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Summary Card
            item(key = "summary") {
                WorkoutSummaryCard(state)
            }

            // 2. Workout Blocks
            itemsIndexed(
                items = state.blocks,
                key = { index, _ -> "block_$index" },
            ) { _, block ->
                WorkoutBlockCard(block = block)
            }

            // 3. Recovery note
            item(key = "recoveryNote") {
                LasoCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.FitnessCenter,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                            tint = recoveryBandColor(state.recoveryBand),
                        )
                        Text(
                            text = "Recovery band: ${state.recoveryBand}. Adjust intensity based on how you feel.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                        )
                    }
                }
            }

            // 4. Bottom spacer
            item(key = "bottomSpacer") {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. Summary Card
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun WorkoutSummaryCard(state: TodayWorkoutUiState) {
    val bandColor = recoveryBandColor(state.recoveryBand)

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        tint = bandColor,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            // Title row with icon
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .background(
                            color = bandColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                            shape = RoundedCornerShape(14.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.FitnessCenter,
                        contentDescription = null,
                        modifier = Modifier.size(24.dp),
                        tint = bandColor,
                    )
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = state.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = state.summary,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }

            // Metric pills row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                MetricPill(
                    value = state.recoveryBand,
                    label = "Recovery",
                    tint = bandColor,
                    modifier = Modifier.weight(1f),
                )
                MetricPill(
                    value = "${state.targetDuration}m",
                    label = "Duration",
                    tint = AccentBlue,
                    modifier = Modifier.weight(1f),
                )
                MetricPill(
                    value = "${state.targetCalories}",
                    label = "Cal",
                    tint = AccentOrange,
                    modifier = Modifier.weight(1f),
                )
            }

            // Target zone chip
            WorkoutChip(
                icon = Icons.Filled.FavoriteBorder,
                text = state.targetZone,
                tint = AccentRed,
            )
        }
    }
}

@Composable
private fun MetricPill(
    value: String,
    label: String,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(
                color = tint.copy(alpha = LasoTokens.BadgeBgOpacity),
                shape = RoundedCornerShape(12.dp),
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Bold,
            color = tint,
            maxLines = 1,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )
    }
}

@Composable
private fun WorkoutChip(
    icon: ImageVector,
    text: String,
    tint: Color,
) {
    Row(
        modifier = Modifier
            .background(
                color = tint.copy(alpha = LasoTokens.BadgeBgOpacity),
                shape = RoundedCornerShape(50),
            )
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(14.dp),
            tint = tint,
        )
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = tint,
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. Workout Block Card
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun WorkoutBlockCard(block: WorkoutBlockUi) {
    val tint = blockTint(block.name)
    val hrZoneColor = zoneColor(block.targetHeartRateZone)

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            // Header: block name + duration badge
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = block.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = "${block.duration} min",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = tint,
                    modifier = Modifier
                        .background(
                            color = tint.copy(alpha = LasoTokens.BadgeBgOpacity),
                            shape = RoundedCornerShape(50),
                        )
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }

            // Target HR zone + BPM
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Zone circle
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .background(
                            color = hrZoneColor.copy(alpha = 0.14f),
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Z${block.targetHeartRateZone}",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = hrZoneColor,
                    )
                }

                Icon(
                    imageVector = Icons.Filled.FavoriteBorder,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                )

                Text(
                    text = block.targetBpm,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontFamily = FontFamily.Monospace,
                    ),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }

            // Exercise list with bullet points
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                block.exercises.forEach { exercise ->
                    ExerciseRow(
                        text = exercise,
                        tint = tint,
                    )
                }
            }
        }
    }
}

@Composable
private fun ExerciseRow(
    text: String,
    tint: Color,
) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Bullet dot
        Box(
            modifier = Modifier
                .padding(top = 6.dp)
                .size(6.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.6f)),
        )

        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
        )
    }
}
