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
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.StressMonitorUiState
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import kotlin.math.cos
import kotlin.math.sin

private val TealAccent = Color(0xFF00897B)

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
            // 1. Hero Gauge
            item {
                HeroGaugeSection(
                    score = state.stressScore,
                    level = state.stressLevel,
                )
            }

            // 2. Driver Section
            item {
                DriverSection(
                    hrvDeviation = state.hrvDeviation,
                    hrElevation = state.hrElevation,
                )
            }

            // 3. 7-Day Chart
            item {
                WeeklyChartSection(weeklyScores = state.weeklyScores)
            }

            // 4. Weekly Comparison
            item {
                WeeklyComparisonSection(
                    weeklyAverage = state.weeklyAverage,
                    previousWeekAverage = state.previousWeekAverage,
                )
            }

            // 5. Tips Section
            item {
                TipsSection(stressLevel = state.stressLevel)
            }

            // 6. Breathing CTA
            item {
                BreathingCTAButton(navController = navController)
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Hero Gauge

@Composable
private fun HeroGaugeSection(
    score: Double,
    level: String,
) {
    val levelColor = stressLevelColor(level)
    val scoreFraction = (score / 3.0).coerceIn(0.0, 1.0)

    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = levelColor,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(LasoTokens.CardPadding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Arc gauge
            Box(
                modifier = Modifier.size(180.dp),
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.size(160.dp),
                ) {
                    val strokeWidth = 14.dp.toPx()
                    val arcSize = Size(size.width - strokeWidth, size.height - strokeWidth)
                    val topLeft = Offset(strokeWidth / 2f, strokeWidth / 2f)
                    val startAngle = 150f
                    val sweepAngle = 240f

                    // Background arc
                    drawArc(
                        color = Color.Gray.copy(alpha = 0.2f),
                        startAngle = startAngle,
                        sweepAngle = sweepAngle,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                    )

                    // 4 colored segments
                    val segments = listOf(
                        0.00f to 0.25f to AccentGreen,
                        0.25f to 0.50f to AccentYellow,
                        0.50f to 0.75f to AccentOrange,
                        0.75f to 1.00f to AccentRed,
                    )

                    for ((range, color) in segments) {
                        val (segStart, segEnd) = range
                        val segStartAngle = startAngle + segStart * sweepAngle
                        val segSweepAngle = (segEnd - segStart) * sweepAngle
                        val alpha = if (scoreFraction >= segStart) 1f else 0.3f

                        drawArc(
                            color = color.copy(alpha = alpha),
                            startAngle = segStartAngle,
                            sweepAngle = segSweepAngle,
                            useCenter = false,
                            topLeft = topLeft,
                            size = arcSize,
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                    }

                    // Needle indicator (white dot)
                    val needleAngle = Math.toRadians((startAngle + scoreFraction.toFloat() * sweepAngle).toDouble())
                    val radius = (size.width - strokeWidth) / 2f
                    val centerX = size.width / 2f
                    val centerY = size.height / 2f
                    val needleX = centerX + radius * cos(needleAngle).toFloat()
                    val needleY = centerY + radius * sin(needleAngle).toFloat()
                    val dotRadius = 5.dp.toPx()

                    // Shadow
                    drawCircle(
                        color = Color.Black.copy(alpha = 0.2f),
                        radius = dotRadius + 1.dp.toPx(),
                        center = Offset(needleX, needleY + 1.dp.toPx()),
                    )
                    // White dot
                    drawCircle(
                        color = Color.White,
                        radius = dotRadius,
                        center = Offset(needleX, needleY),
                    )
                }

                // Center score text
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(top = 10.dp),
                ) {
                    Text(
                        text = String.format("%.1f", score),
                        fontSize = 42.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "of 3.0",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    )
                }
            }

            // Level badge
            Box(
                modifier = Modifier
                    .background(
                        color = levelColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    text = level,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = levelColor,
                )
            }
        }
    }
}

// endregion

// region 2. Stress Drivers

@Composable
private fun DriverSection(
    hrvDeviation: Double,
    hrElevation: Double,
) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "What's Driving Your Stress")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(LasoTokens.CardPadding),
                verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            ) {
                DriverRow(
                    icon = Icons.Filled.MonitorHeart,
                    label = "HRV Deviation",
                    value = hrvDeviation,
                    color = driverColor(hrvDeviation),
                )

                DriverRow(
                    icon = Icons.Filled.Favorite,
                    label = "HR Elevation",
                    value = hrElevation,
                    color = driverColor(hrElevation),
                )
            }
        }
    }
}

@Composable
private fun DriverRow(
    icon: ImageVector,
    label: String,
    value: Double,
    color: Color,
) {
    val clampedValue = value.coerceIn(0.0, 1.0)

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(24.dp),
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
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = "${(clampedValue * 100).toInt()}%",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = color,
                )
            }

            // Progress bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(clampedValue.toFloat())
                        .height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(color),
                )
            }
        }
    }
}

// endregion

// region 3. 7-Day Chart

@Composable
private fun WeeklyChartSection(weeklyScores: List<Double>) {
    val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
    val barMaxHeight = 80.dp

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "7-Day Stress")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(LasoTokens.CardPadding)) {
                if (weeklyScores.isEmpty()) {
                    Text(
                        text = "Not enough data yet",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 20.dp),
                        textAlign = TextAlign.Center,
                    )
                } else {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(100.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.Bottom,
                    ) {
                        weeklyScores.take(7).forEachIndexed { index, score ->
                            val fraction = (score / 3.0).coerceIn(0.0, 1.0)
                            val barHeight = (barMaxHeight * fraction.toFloat()).coerceAtLeast(4.dp)
                            val barColor = stressBarColor(score)

                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.weight(1f),
                            ) {
                                // Vertical bar
                                Box(
                                    modifier = Modifier
                                        .width(24.dp)
                                        .height(barHeight)
                                        .clip(RoundedCornerShape(4.dp))
                                        .background(barColor),
                                )

                                // Day label
                                Text(
                                    text = dayLabels.getOrElse(index) { "" },
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

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
                            text = "3.0",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Weekly Comparison

@Composable
private fun WeeklyComparisonSection(
    weeklyAverage: Double,
    previousWeekAverage: Double,
) {
    val diff = weeklyAverage - previousWeekAverage
    val improved = diff <= 0
    val arrowIcon = if (improved) Icons.Filled.SouthEast else Icons.Filled.NorthEast
    val deltaColor = if (improved) AccentGreen else AccentRed
    val deltaLabel = if (improved) "Improved" else "Increased"
    val dividerColor = MaterialTheme.colorScheme.onSurface.copy(alpha = LasoTokens.BorderOpacity)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(LasoTokens.CardPadding),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // This Week
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "This Week",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Text(
                    text = String.format("%.1f", weeklyAverage),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            // Divider
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(LasoTokens.DividerHeight)
                    .background(dividerColor),
            )

            // Last Week
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "Last Week",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Text(
                    text = String.format("%.1f", previousWeekAverage),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }

            // Divider
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(LasoTokens.DividerHeight)
                    .background(dividerColor),
            )

            // Delta indicator
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = arrowIcon,
                    contentDescription = deltaLabel,
                    tint = deltaColor,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = deltaLabel,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = deltaColor,
                )
            }
        }
    }
}

// endregion

// region 5. Tips Section

@Composable
private fun TipsSection(stressLevel: String) {
    val levelColor = stressLevelColor(stressLevel)
    val tips = tipsForLevel(stressLevel)
    val icon = tipIconForLevel(stressLevel)

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Reduce Stress")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(LasoTokens.CardPadding),
                verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            ) {
                tips.forEach { tip ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        // Icon in colored circle
                        Box(
                            modifier = Modifier
                                .size(20.dp)
                                .clip(CircleShape)
                                .background(levelColor.copy(alpha = LasoTokens.BadgeBgOpacity)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                imageVector = icon,
                                contentDescription = null,
                                tint = levelColor,
                                modifier = Modifier.size(12.dp),
                            )
                        }

                        Text(
                            text = tip,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 6. Breathing CTA

@Composable
private fun BreathingCTAButton(navController: NavHostController) {
    Button(
        onClick = { navController.navigate(AppRoute.Breathwork.route) },
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp),
        shape = RoundedCornerShape(LasoTokens.CardRadius),
        colors = ButtonDefaults.buttonColors(
            containerColor = TealAccent,
            contentColor = Color.White,
        ),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.Air,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
            )
            Text(
                text = "Start Breathing Exercise",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

// endregion

// region Helpers

private fun stressLevelColor(level: String): Color {
    return when (level.lowercase()) {
        "low" -> AccentGreen
        "mild" -> AccentYellow
        "moderate" -> AccentOrange
        "high" -> AccentRed
        else -> AccentGreen
    }
}

private fun stressBarColor(score: Double): Color = when {
    score < 0.75 -> AccentGreen
    score < 1.5 -> AccentYellow
    score < 2.25 -> AccentOrange
    else -> AccentRed
}

private fun driverColor(value: Double): Color = when {
    value < 0.3 -> AccentGreen
    value < 0.6 -> AccentYellow
    value < 0.8 -> AccentOrange
    else -> AccentRed
}

private fun tipsForLevel(level: String): List<String> = when (level.lowercase()) {
    "low" -> listOf(
        "Your body is calm. Great time for challenging work.",
        "Maintain this state with regular sleep and hydration.",
        "Try a creative or deep-focus task right now.",
    )
    "mild" -> listOf(
        "Try a 5-minute breathing exercise.",
        "Step outside for fresh air if possible.",
        "A short walk can help reset your nervous system.",
    )
    "moderate" -> listOf(
        "Try a short walk or gentle stretching.",
        "Limiting caffeine and stimulants for the next few hours may help.",
        "Try progressive muscle relaxation.",
        "Shorten your to-do list and focus on essentials.",
    )
    "high" -> listOf(
        "Your body is signaling for rest. Lighter activity may serve you better right now.",
        "Box breathing can help: inhale 4s, hold 4s, exhale 4s, hold 4s.",
        "A quieter, screen-free environment may help your nervous system settle.",
        "Many people find that 8+ hours of sleep tonight helps them feel more resilient tomorrow.",
    )
    else -> listOf(
        "Monitor your stress throughout the day.",
        "Regular breaks can help manage stress levels.",
    )
}

private fun tipIconForLevel(level: String): ImageVector = when (level.lowercase()) {
    "low" -> Icons.Filled.CheckCircle
    "mild" -> Icons.Filled.Air
    "moderate" -> Icons.Filled.DirectionsWalk
    "high" -> Icons.Filled.Warning
    else -> Icons.Filled.CheckCircle
}

private infix fun <A, B, C> Pair<A, B>.to(third: C): Pair<Pair<A, B>, C> = Pair(this, third)

// endregion
