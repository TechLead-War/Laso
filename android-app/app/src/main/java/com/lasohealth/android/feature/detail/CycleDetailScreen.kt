package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.CycleDetailUiState
import com.lasohealth.android.core.model.PhaseDurationUi
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.CategoryMindfulness

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CycleDetailScreen(
    state: CycleDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Cycle Tracking",
                        fontWeight = FontWeight.Bold,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Cycle Hero
            item {
                CycleHeroSection(
                    currentPhase = state.currentPhase,
                    dayInCycle = state.dayInCycle,
                    cycleLength = state.cycleLength,
                    phaseColor = state.phaseColor,
                    phaseProgress = state.phaseProgress,
                )
            }

            // 2. Upcoming Card (conditional)
            if (state.daysUntilPeriod != null || state.nextPeriodEstimate != null) {
                item {
                    UpcomingCard(
                        daysUntilPeriod = state.daysUntilPeriod,
                        nextPeriodEstimate = state.nextPeriodEstimate,
                    )
                }
            }

            // 3. Phase Breakdown
            if (state.phaseDurations.isNotEmpty()) {
                item {
                    PhaseBreakdownSection(
                        phaseDurations = state.phaseDurations,
                        cycleLength = state.cycleLength,
                    )
                }
            }

            // 4. Cycle History
            if (state.cycleHistory.isNotEmpty()) {
                item {
                    CycleHistorySection(cycleHistory = state.cycleHistory)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Cycle Hero

@Composable
private fun CycleHeroSection(
    currentPhase: String,
    dayInCycle: Int,
    cycleLength: Int,
    phaseColor: String,
    phaseProgress: Float,
) {
    val color = parsePhaseColor(phaseColor)
    val phaseEmoji = phaseEmoji(currentPhase)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Phase emoji in colored circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(color.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = phaseEmoji,
                fontSize = 32.sp,
            )
        }

        // Phase name
        Text(
            text = currentPhase,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = color,
        )

        // "Day [N] of [length]"
        Text(
            text = "Day $dayInCycle of $cycleLength",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )

        // Phase progress bar
        LinearProgressIndicator(
            progress = { phaseProgress.coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp)),
            color = color,
            trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
        )
    }
}

// endregion

// region 2. Upcoming Card

@Composable
private fun UpcomingCard(
    daysUntilPeriod: Int?,
    nextPeriodEstimate: String?,
) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (daysUntilPeriod != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Days until period",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = daysUntilPeriod.toString(),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }

            if (nextPeriodEstimate != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Estimated next period",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = nextPeriodEstimate,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Phase Breakdown

@Composable
private fun PhaseBreakdownSection(
    phaseDurations: List<PhaseDurationUi>,
    cycleLength: Int,
) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Phase Durations")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Segmented bar showing all phases proportionally
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(12.dp)
                        .clip(RoundedCornerShape(6.dp)),
                ) {
                    phaseDurations.forEach { phase ->
                        val weight = if (cycleLength > 0) {
                            phase.days.toFloat() / cycleLength
                        } else {
                            1f / phaseDurations.size
                        }
                        val color = parsePhaseColor(phase.color)

                        Box(
                            modifier = Modifier
                                .weight(weight.coerceAtLeast(0.01f))
                                .height(12.dp)
                                .background(color),
                        )
                    }
                }

                // Legend rows
                phaseDurations.forEach { phase ->
                    val color = parsePhaseColor(phase.color)

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        // Color dot
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(color),
                        )

                        // Phase name
                        Text(
                            text = phase.name,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f),
                        )

                        // Days count
                        Text(
                            text = "${phase.days} days",
                            style = MaterialTheme.typography.bodyMedium,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Cycle History

@Composable
private fun CycleHistorySection(cycleHistory: List<Int>) {
    val avgLength = if (cycleHistory.isNotEmpty()) cycleHistory.average().toInt() else 28
    val maxLength = (cycleHistory.maxOrNull() ?: 35).coerceAtLeast(1)

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Past Cycles", trailing = "Avg ${avgLength}d")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                cycleHistory.forEachIndexed { index, length ->
                    val fraction = length.toFloat() / maxLength
                    val barColor = if (length in 24..35) AccentGreen else AccentOrange

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        // Cycle number
                        Text(
                            text = "#${cycleHistory.size - index}",
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.width(28.dp),
                        )

                        // Bar
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(16.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(fraction.coerceAtLeast(0.05f))
                                    .height(16.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(barColor.copy(alpha = 0.7f)),
                            )
                        }

                        // Length label
                        Text(
                            text = "${length}d",
                            style = MaterialTheme.typography.labelMedium,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.width(32.dp),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region Helpers

private fun parsePhaseColor(colorName: String): Color {
    val lower = colorName.lowercase()
    return when {
        "red" in lower || "menstrual" in lower -> AccentRed
        "orange" in lower || "follicular" in lower -> AccentOrange
        "green" in lower || "ovulat" in lower -> AccentGreen
        "yellow" in lower || "luteal" in lower -> AccentYellow
        "blue" in lower -> AccentBlue
        "purple" in lower || "violet" in lower -> CategoryMindfulness
        else -> AccentBlue
    }
}

private fun phaseEmoji(phase: String): String {
    val lower = phase.lowercase()
    return when {
        "menstrual" in lower -> "\uD83C\uDF19"
        "follicular" in lower -> "\uD83C\uDF31"
        "ovulat" in lower -> "\u2600\uFE0F"
        "luteal" in lower -> "\uD83C\uDF43"
        else -> "\uD83D\uDD2E"
    }
}

// endregion
