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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.StressMonitorUiState
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StressMonitorScreen(
    state: StressMonitorUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Stress Monitor",
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
            // 1. Stress Hero
            item {
                StressHeroSection(
                    score = state.stressScore,
                    level = state.stressLevel,
                )
            }

            // 2. Signals Card
            item {
                StressSignalsCard(
                    hrvDeviation = state.hrvDeviation,
                    hrElevation = state.hrElevation,
                )
            }

            // 3. Weekly History
            item {
                WeeklyHistorySection(weeklyScores = state.weeklyScores)
            }

            // 4. Comparison Card
            item {
                ComparisonCard(
                    weeklyAverage = state.weeklyAverage,
                    previousWeekAverage = state.previousWeekAverage,
                )
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Stress Hero

@Composable
private fun StressHeroSection(
    score: Int,
    level: String,
) {
    val levelColor = stressLevelColor(level)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Waveform emoji in colored circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(levelColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\u3030\uFE0F",
                fontSize = 32.sp,
            )
        }

        // Score
        Text(
            text = score.toString(),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = levelColor,
        )

        // Level badge
        Box(
            modifier = Modifier
                .background(
                    color = levelColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            Text(
                text = level,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = levelColor,
            )
        }
    }
}

// endregion

// region 2. Stress Signals

@Composable
private fun StressSignalsCard(
    hrvDeviation: String,
    hrElevation: String,
) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Stress Signals")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column {
                // HRV Deviation row
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "HRV Deviation",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = hrvDeviation,
                        style = MaterialTheme.typography.bodyLarge,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )

                // HR Elevation row
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "HR Elevation",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = hrElevation,
                        style = MaterialTheme.typography.bodyLarge,
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Weekly History

@Composable
private fun WeeklyHistorySection(weeklyScores: List<Int>) {
    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
    val maxScore = (weeklyScores.maxOrNull() ?: 100).coerceAtLeast(1)
    val barMaxHeight = 120.dp

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "This Week")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom,
            ) {
                weeklyScores.take(7).forEachIndexed { index, score ->
                    val fraction = score.toFloat() / maxScore
                    val barHeight = (barMaxHeight * fraction).coerceAtLeast(4.dp)
                    val barColor = stressScoreColor(score)

                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        // Score label above bar
                        Text(
                            text = score.toString(),
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )

                        // Vertical bar
                        Box(
                            modifier = Modifier
                                .width(24.dp)
                                .height(barHeight)
                                .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                .background(barColor),
                        )

                        // Day label
                        Text(
                            text = dayLabels.getOrElse(index) { "" },
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Comparison Card

@Composable
private fun ComparisonCard(
    weeklyAverage: Int,
    previousWeekAverage: Int,
) {
    val delta = weeklyAverage - previousWeekAverage
    // For stress: lower is better, so negative delta = improvement
    val improved = delta < 0
    val deltaColor = if (improved) AccentGreen else AccentRed
    val deltaArrow = if (improved) "\u2193" else "\u2191"
    val deltaText = if (delta > 0) "+$delta" else "$delta"

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Comparison")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Weekly Average
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Weekly Average",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = weeklyAverage.toString(),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                // Previous Week
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Previous Week",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = previousWeekAverage.toString(),
                        style = MaterialTheme.typography.bodyLarge,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )

                // Delta row
                if (delta != 0) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            text = deltaArrow,
                            style = MaterialTheme.typography.bodyLarge,
                            color = deltaColor,
                        )
                        Text(
                            text = deltaText,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                            color = deltaColor,
                        )
                        Text(
                            text = if (improved) "improvement" else "increase",
                            style = MaterialTheme.typography.bodyMedium,
                            color = deltaColor,
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region Helpers

private fun stressLevelColor(level: String): Color {
    val lower = level.lowercase()
    return when {
        "high" in lower -> AccentRed
        "moderate" in lower -> AccentOrange
        "mild" in lower || "low" in lower -> AccentYellow
        else -> AccentGreen
    }
}

private fun stressScoreColor(score: Int): Color = when {
    score >= 70 -> AccentRed
    score >= 50 -> AccentOrange
    score >= 30 -> AccentYellow
    else -> AccentGreen
}

// endregion
