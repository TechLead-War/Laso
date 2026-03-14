package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.KingBed
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.SouthEast
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.BrainFactorUi
import com.lasohealth.android.core.model.BrainHealthUiState
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

private val BrainBlue = Color(0xFF4A90D9)

private fun brainStateColor(score: Int): Color = when {
    score >= 80 -> AccentGreen
    score >= 65 -> BrainBlue
    score >= 45 -> Color.Gray
    else -> AccentOrange
}

private fun readinessColor(fraction: Float): Color = when {
    fraction >= 0.7f -> AccentGreen
    fraction >= 0.5f -> AccentYellow
    fraction >= 0.3f -> AccentOrange
    else -> AccentRed
}

private fun chartBarColor(score: Int): Color = when {
    score >= 80 -> AccentGreen
    score >= 65 -> BrainBlue
    score >= 45 -> Color.Gray
    else -> AccentOrange
}

private fun trendIcon(trend: String): ImageVector = when (trend) {
    "improving" -> Icons.Filled.NorthEast
    "declining" -> Icons.Filled.SouthEast
    else -> Icons.Filled.Remove
}

private fun trendColor(trend: String): Color = when (trend) {
    "improving" -> AccentGreen
    "declining" -> AccentOrange
    else -> Color.Gray
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BrainHealthScreen(
    state: BrainHealthUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Brain Health",
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
            // 1. Hero
            item {
                BrainHeroSection(
                    score = state.score,
                    stateLabel = state.stateLabel,
                    headline = state.headline,
                    confidence = state.confidence,
                )
            }

            // 2. Cognitive Readiness
            item {
                CognitiveReadinessSection(
                    cognitiveReadiness = state.cognitiveReadiness,
                    memoryRecovery = state.memoryRecovery,
                    circadianAlignment = state.circadianAlignment,
                )
            }

            // 3. Memory & Recovery
            item {
                MemoryRecoverySection(
                    memoryRecovery = state.memoryRecovery,
                    cognitiveReadiness = state.cognitiveReadiness,
                    trend = state.trend,
                )
            }

            // 4. Cognitive Capacity
            item {
                CognitiveCapacitySection(
                    stressCognitionLoad = state.stressCognitionLoad,
                )
            }

            // 5. Long-Term Brain Fitness
            item {
                LongTermFitnessSection(
                    neurovascularFitness = state.neurovascularFitness,
                    circadianAlignment = state.circadianAlignment,
                )
            }

            // 6. 7-Day Chart
            item {
                WeeklyChartSection(
                    weeklyHistory = state.weeklyHistory,
                    trend = state.trend,
                )
            }

            // 7. Key Factors
            if (state.topFactors.isNotEmpty()) {
                item {
                    KeyFactorsSection(factors = state.topFactors)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Hero Section

@Composable
private fun BrainHeroSection(
    score: Int,
    stateLabel: String,
    headline: String,
    confidence: Float,
) {
    val stateColor = brainStateColor(score)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .shadow(
                elevation = 16.dp,
                shape = RoundedCornerShape(26.dp),
                ambientColor = stateColor.copy(alpha = 0.22f),
                spotColor = stateColor.copy(alpha = 0.22f),
            )
            .clip(RoundedCornerShape(26.dp))
            .background(Color.Black.copy(alpha = 0.95f))
            .border(
                width = 1.dp,
                color = stateColor.copy(alpha = 0.42f),
                shape = RoundedCornerShape(26.dp),
            )
            .padding(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Score
        Text(
            text = score.toString(),
            fontSize = 56.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = Color.White,
        )

        // "BRAIN HEALTH" label
        Text(
            text = "BRAIN HEALTH",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 2.sp,
            color = Color.White.copy(alpha = 0.68f),
        )

        // State label
        Text(
            text = stateLabel,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = stateColor,
        )

        // Headline
        if (headline.isNotEmpty()) {
            Text(
                text = headline,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.72f),
                textAlign = TextAlign.Center,
            )
        }

        // Confidence badge
        if (confidence < 0.7f) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.1f))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "\u23F3",
                    fontSize = 11.sp,
                )
                Text(
                    text = "Building your brain profile",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.5f),
                )
            }
        }
    }
}

// endregion

// region 2. Cognitive Readiness

@Composable
private fun CognitiveReadinessSection(
    cognitiveReadiness: Int,
    memoryRecovery: Int,
    circadianAlignment: Int,
) {
    val hrvFraction = (cognitiveReadiness / 100f).coerceIn(0f, 1f)
    val deepSleepFraction = (cognitiveReadiness * 0.9f / 100f).coerceIn(0f, 1f)
    val remFraction = (memoryRecovery / 100f).coerceIn(0f, 1f)
    val durationFraction = (circadianAlignment / 100f).coerceIn(0f, 1f)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "Cognitive Readiness",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            DriverRow(
                icon = Icons.Filled.MonitorHeart,
                label = "HRV Signal",
                fraction = hrvFraction,
            )

            DriverRow(
                icon = Icons.Filled.DarkMode,
                label = "Deep Sleep",
                fraction = deepSleepFraction,
            )

            DriverRow(
                icon = Icons.Filled.Psychology,
                label = "REM Sleep",
                fraction = remFraction,
            )

            DriverRow(
                icon = Icons.Filled.KingBed,
                label = "Sleep Duration",
                fraction = durationFraction,
            )
        }
    }
}

@Composable
private fun DriverRow(
    icon: ImageVector,
    label: String,
    fraction: Float,
) {
    val color = readinessColor(fraction)
    val percentage = (fraction * 100).toInt()

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(22.dp),
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    text = "$percentage%",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = color,
                )
            }

            LinearProgressIndicator(
                progress = { fraction },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = color,
                trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                strokeCap = StrokeCap.Round,
            )
        }
    }
}

// endregion

// region 3. Memory & Recovery

@Composable
private fun MemoryRecoverySection(
    memoryRecovery: Int,
    cognitiveReadiness: Int,
    trend: String,
) {
    val remColor = readinessColor(memoryRecovery / 100f)
    val deepSleepValue = (cognitiveReadiness * 0.9).toInt()
    val deepSleepColor = readinessColor(deepSleepValue / 100f)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "Memory & Recovery",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // REM Quality
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "REM Quality",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = "$memoryRecovery%",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = remColor,
                    )
                }

                // Vertical divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(LasoTokens.DividerHeight)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
                )

                // Deep Sleep
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "Deep Sleep",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = "$deepSleepValue%",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = deepSleepColor,
                    )
                }

                // Vertical divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(LasoTokens.DividerHeight)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
                )

                // Trend indicator
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = trendIcon(trend),
                        contentDescription = trend,
                        tint = trendColor(trend),
                        modifier = Modifier.size(20.dp),
                    )
                    Text(
                        text = trend.replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = trendColor(trend),
                    )
                }
            }

            Text(
                text = "Deep sleep clears brain waste. REM consolidates memory.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion

// region 4. Cognitive Capacity

@Composable
private fun CognitiveCapacitySection(
    stressCognitionLoad: Int,
) {
    val fraction = (stressCognitionLoad / 100f).coerceIn(0f, 1f)
    val capColor = readinessColor(fraction)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "Cognitive Capacity",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "$stressCognitionLoad%",
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = capColor,
                )

                LinearProgressIndicator(
                    progress = { fraction },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(10.dp)
                        .clip(RoundedCornerShape(5.dp)),
                    color = capColor,
                    trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    strokeCap = StrokeCap.Round,
                )

                Text(
                    text = "Available cognitive bandwidth after stress load",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// endregion

// region 5. Long-Term Brain Fitness

@Composable
private fun LongTermFitnessSection(
    neurovascularFitness: Int,
    circadianAlignment: Int,
) {
    val neuroColor = readinessColor(neurovascularFitness / 100f)
    val circadianColor = readinessColor(circadianAlignment / 100f)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "Long-Term Brain Fitness",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Neurovascular
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "Neurovascular",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = "$neurovascularFitness%",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = neuroColor,
                    )
                }

                // Vertical divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(LasoTokens.DividerHeight)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
                )

                // Circadian
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "Circadian",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = "$circadianAlignment%",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = circadianColor,
                    )
                }
            }

            Text(
                text = "Cardiovascular fitness and sleep regularity predict long-term brain health.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion

// region 6. 7-Day Chart

@Composable
private fun WeeklyChartSection(
    weeklyHistory: List<Int>,
    trend: String,
) {
    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
    val barMaxHeight = 80.dp

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "7-Day Brain Health",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            if (weeklyHistory.isEmpty()) {
                Text(
                    text = "Not enough data yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 20.dp),
                    textAlign = TextAlign.Center,
                )
            } else {
                // Bar chart
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(barMaxHeight + 24.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    weeklyHistory.take(7).forEachIndexed { index, score ->
                        val fraction = (score / 100f).coerceIn(0f, 1f)
                        val barHeight = (barMaxHeight * fraction).coerceAtLeast(4.dp)
                        val barColor = chartBarColor(score)

                        Column(
                            modifier = Modifier.weight(1f),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            // Bar
                            Box(
                                modifier = Modifier
                                    .width(20.dp)
                                    .height(barHeight)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(barColor),
                            )

                            // Day label
                            Text(
                                text = dayLabels.getOrElse(index) { "" },
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            )
                        }
                    }
                }

                // Scale labels
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = "0",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                    )
                    Text(
                        text = "100",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                    )
                }

                // Average + trend badge
                val avg = weeklyHistory.average().toInt()

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = "Avg",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                        Text(
                            text = avg.toString(),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                        )
                    }

                    // Trend badge
                    val tColor = trendColor(trend)
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(tColor.copy(alpha = LasoTokens.BadgeBgOpacity))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Icon(
                            imageVector = trendIcon(trend),
                            contentDescription = trend,
                            tint = tColor,
                            modifier = Modifier.size(14.dp),
                        )
                        Text(
                            text = trend.replaceFirstChar { it.uppercase() },
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium,
                            color = tColor,
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 7. Key Factors

@Composable
private fun KeyFactorsSection(factors: List<BrainFactorUi>) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
            Text(
                text = "Key Factors",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
            )

            factors.forEach { factor ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(
                        imageVector = if (factor.isPositive) {
                            Icons.Filled.ArrowUpward
                        } else {
                            Icons.Filled.ArrowDownward
                        },
                        contentDescription = if (factor.isPositive) "Positive" else "Negative",
                        tint = if (factor.isPositive) AccentGreen else AccentOrange,
                        modifier = Modifier.size(20.dp),
                    )

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(
                            text = factor.label,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                        )
                        Text(
                            text = factor.impact,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }
                }
            }
        }
    }
}

// endregion
