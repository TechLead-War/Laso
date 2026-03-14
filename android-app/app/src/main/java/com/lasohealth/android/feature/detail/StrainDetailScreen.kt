package com.lasohealth.android.feature.detail

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.StrainDetailUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StrainDetailScreen(
    state: StrainDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Strain",
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
        containerColor = MaterialTheme.colorScheme.background,
        modifier = modifier,
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.padding(innerPadding),
            contentPadding = PaddingValues(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Strain Hero
            item {
                StrainHero(state)
            }

            // 2. Target Range Card
            item {
                TargetRangeCard(state)
            }

            // 3. Zone Minutes Card
            item {
                ZoneMinutesCard(zoneMinutes = state.zoneMinutes)
            }

            // 4. Weekly History
            if (state.weeklyHistory.isNotEmpty()) {
                item {
                    WeeklyHistorySection(
                        history = state.weeklyHistory,
                        targetMin = state.targetMin.toFloat(),
                        targetMax = state.targetMax.toFloat(),
                    )
                }
            }

            // 5. Guidance Card
            item {
                GuidanceCard(guidance = state.guidance)
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Strain Hero

@Composable
private fun StrainHero(state: StrainDetailUiState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Flame emoji in orange circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(
                    color = AccentOrange.copy(alpha = 0.12f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\uD83D\uDD25",
                fontSize = 40.sp,
            )
        }

        // Strain score
        Text(
            text = String.format("%.1f", state.strainScore),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
        )

        // Strain level badge
        val levelColor = strainLevelColor(state.strainLevel)

        Box(
            modifier = Modifier
                .background(
                    color = levelColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 14.dp, vertical = 6.dp),
        ) {
            Text(
                text = state.strainLevel,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = levelColor,
            )
        }
    }
}

private fun strainLevelColor(level: String): Color {
    val lower = level.lowercase()
    return when {
        "low" in lower -> AccentBlue
        "moderate" in lower -> AccentGreen
        "high" in lower -> AccentOrange
        "overreaching" in lower || "over" in lower -> AccentRed
        else -> AccentYellow
    }
}

// endregion

// region 2. Target Range Card

@Composable
private fun TargetRangeCard(state: StrainDetailUiState) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "Target Strain Range",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                // Visual range indicator
                StrainRangeBar(
                    current = state.strainScore.toFloat(),
                    min = state.targetMin.toFloat(),
                    max = state.targetMax.toFloat(),
                )

                // Balance label
                val balanceColor = when {
                    state.balanceLabel.contains("optimal", ignoreCase = true) -> AccentGreen
                    state.balanceLabel.contains("under", ignoreCase = true) -> AccentBlue
                    else -> AccentOrange
                }

                Box(
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .background(
                            color = balanceColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                            shape = RoundedCornerShape(12.dp),
                        )
                        .padding(horizontal = 12.dp, vertical = 5.dp),
                ) {
                    Text(
                        text = state.balanceLabel,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = balanceColor,
                    )
                }
            }
        }
    }
}

@Composable
private fun StrainRangeBar(
    current: Float,
    min: Float,
    max: Float,
) {
    // Calculate the visual scale: show from 0 to max * 1.5 (or current if higher)
    val visualMax = maxOf(max * 1.5f, current * 1.2f, 21f)
    val trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
    val rangeColor = AccentGreen.copy(alpha = 0.25f)
    val dotColor = strainLevelColor(
        when {
            current < min -> "low"
            current > max -> "overreaching"
            else -> "moderate"
        },
    )

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(24.dp),
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(24.dp),
            ) {
                val barHeight = 8.dp.toPx()
                val barY = (size.height - barHeight) / 2f

                // Full track
                drawRoundRect(
                    color = trackColor,
                    topLeft = Offset(0f, barY),
                    size = Size(size.width, barHeight),
                    cornerRadius = CornerRadius(barHeight / 2f),
                )

                // Target range zone
                val rangeStart = (min / visualMax) * size.width
                val rangeEnd = (max / visualMax) * size.width

                drawRoundRect(
                    color = rangeColor,
                    topLeft = Offset(rangeStart, barY),
                    size = Size(rangeEnd - rangeStart, barHeight),
                    cornerRadius = CornerRadius(barHeight / 2f),
                )

                // Current position dot
                val dotX = (current / visualMax) * size.width
                val dotRadius = 8.dp.toPx()

                drawCircle(
                    color = dotColor,
                    radius = dotRadius,
                    center = Offset(dotX.coerceIn(dotRadius, size.width - dotRadius), size.height / 2f),
                )
            }
        }

        // Min and max labels
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = String.format("%.1f", min),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = String.format("%.1f", max),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }
    }
}

// endregion

// region 3. Zone Minutes Card

@Composable
private fun ZoneMinutesCard(zoneMinutes: Int) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = "Zone Minutes",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = zoneMinutes.toString(),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                    color = AccentGreen,
                )

                Text(
                    text = "minutes in target zone today",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// endregion

// region 4. Weekly History

@Composable
private fun WeeklyHistorySection(
    history: List<Float>,
    targetMin: Float,
    targetMax: Float,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "This Week")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
            val maxValue = maxOf(
                history.maxOrNull() ?: 0f,
                targetMax,
                1f,
            )

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Bar chart
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    history.take(7).forEachIndexed { index, value ->
                        val fraction = if (maxValue > 0) (value / maxValue).coerceIn(0f, 1f) else 0f
                        val barColor = when {
                            value < targetMin -> AccentBlue
                            value > targetMax -> AccentOrange
                            else -> AccentGreen
                        }

                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Bottom,
                            modifier = Modifier
                                .weight(1f)
                                .height(120.dp),
                        ) {
                            // Bar
                            Box(
                                modifier = Modifier
                                    .width(20.dp)
                                    .height((fraction * 100).dp)
                                    .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                    .background(barColor),
                            )
                        }
                    }
                }

                // Day labels
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    dayLabels.take(history.size.coerceAtMost(7)).forEachIndexed { _, label ->
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 5. Guidance Card

@Composable
private fun GuidanceCard(guidance: String) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Training Guidance")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = guidance,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
            )
        }
    }
}

// endregion
