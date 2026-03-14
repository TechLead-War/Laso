package com.lasohealth.android.feature.detail

import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Balance
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.Info
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
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
import com.lasohealth.android.core.model.StrainDetailUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

// ── Strain level → color mapping ─────────────────────────────────────────────

private fun strainLevelColor(level: String): Color {
    val lower = level.lowercase()
    return when {
        "all" in lower -> AccentRed        // All Out
        "overreaching" in lower -> AccentRed
        "high" in lower -> AccentOrange
        "moderate" in lower -> AccentGreen
        "light" in lower -> AccentBlue
        "low" in lower -> AccentBlue
        else -> AccentGreen
    }
}

// ── Balance → color mapping ──────────────────────────────────────────────────

private fun balanceColor(label: String): Color {
    val lower = label.lowercase()
    return when {
        "optimal" in lower -> AccentGreen
        "under" in lower -> AccentBlue
        "over" in lower -> AccentRed
        else -> AccentGreen
    }
}

// ── Zone colors ──────────────────────────────────────────────────────────────

private val ZoneColors = listOf(
    AccentBlue,     // Z1
    AccentGreen,    // Z2
    AccentYellow,   // Z3
    AccentOrange,   // Z4
    AccentRed,      // Z5
)

private val ZoneNames = listOf(
    "Active Recovery",
    "Fat Burn",
    "Aerobic",
    "Threshold",
    "Anaerobic",
)

// ── Strain level from score (for bar coloring) ──────────────────────────────

private fun strainLevelFromScore(score: Float): String = when {
    score >= 18f -> "All Out"
    score >= 14f -> "Overreaching"
    score >= 10f -> "High"
    score >= 6f -> "Moderate"
    score >= 3f -> "Light"
    else -> "Low"
}

// ── Scale reference levels ──────────────────────────────────────────────────

private data class ScaleLevel(val label: String, val color: Color)

private val ScaleLevels = listOf(
    ScaleLevel("Low", AccentBlue),
    ScaleLevel("Light", AccentBlue),
    ScaleLevel("Moderate", AccentGreen),
    ScaleLevel("High", AccentOrange),
    ScaleLevel("Overreaching", AccentRed),
)

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

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
                title = { Text("Strain", fontWeight = FontWeight.Bold) },
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
            // 1. Hero Section
            item { StrainHeroSection(state) }

            // 2. Strain Balance Section
            item { StrainBalanceSection(state) }

            // 3. Strain Coach Section
            item { StrainCoachSection(state) }

            // 4. HR Zone Breakdown
            if (state.zoneMinutes.isNotEmpty()) {
                item { HrZoneBreakdownSection(state.zoneMinutes) }
            }

            // 5. 7-Day History
            if (state.weeklyHistory.isNotEmpty()) {
                item {
                    WeeklyHistorySection(
                        history = state.weeklyHistory,
                        targetMin = state.targetMin.toFloat(),
                        targetMax = state.targetMax.toFloat(),
                    )
                }
            }

            // 6. Disclaimer
            item { DisclaimerSection() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. Hero Section — Animated ring, score, level badge, scale reference
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun StrainHeroSection(state: StrainDetailUiState) {
    val levelColor = strainLevelColor(state.strainLevel)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        levelColor.copy(alpha = 0.28f),
                        levelColor.copy(alpha = 0.10f),
                    ),
                ),
                shape = RoundedCornerShape(20.dp),
            )
            .border(
                width = 1.dp,
                color = levelColor.copy(alpha = 0.20f),
                shape = RoundedCornerShape(20.dp),
            )
            .padding(vertical = 24.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Animated strain ring
        StrainRing(
            score = state.strainScore.toFloat(),
            maxScore = 21f,
            color = levelColor,
        )

        // "of 21" subtitle
        Text(
            text = "of 21",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
        )

        // Level badge — white text on solid color capsule
        Box(
            modifier = Modifier
                .background(
                    color = levelColor,
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            Text(
                text = state.strainLevel,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Scale reference bar
        StrainScaleReference()
    }
}

@Composable
private fun StrainRing(
    score: Float,
    maxScore: Float,
    color: Color,
) {
    val targetProgress = (score / maxScore).coerceIn(0f, 1f)
    var animatedTarget by remember { mutableFloatStateOf(0f) }
    val progress by animateFloatAsState(
        targetValue = animatedTarget,
        animationSpec = tween(durationMillis = 1000, easing = EaseInOut),
        label = "strainRingProgress",
    )
    LaunchedEffect(score) {
        animatedTarget = targetProgress
    }

    val trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)

    Box(
        modifier = Modifier.size(120.dp),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(120.dp)) {
            val strokeWidth = 8.dp.toPx()
            val inset = strokeWidth / 2f
            val diameter = size.minDimension - strokeWidth

            // Track
            drawArc(
                color = trackColor,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(diameter, diameter),
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
            )

            // Progress arc
            drawArc(
                color = color,
                startAngle = -90f,
                sweepAngle = progress * 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = Size(diameter, diameter),
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
            )
        }

        // Score text centered
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = String.format("%.1f", score),
                fontSize = 40.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

@Composable
private fun StrainScaleReference() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        ScaleLevels.forEach { level ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                // Colored bar segment
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .background(
                            color = level.color,
                            shape = RoundedCornerShape(2.dp),
                        ),
                )
                // Label
                Text(
                    text = level.label,
                    style = MaterialTheme.typography.labelSmall,
                    fontSize = 9.sp,
                    color = level.color,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. Strain Balance Section
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun StrainBalanceSection(state: StrainDetailUiState) {
    val bColor = balanceColor(state.strainBalance)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StrainSectionHeader(
            icon = Icons.Filled.Balance,
            iconTint = bColor,
            title = "Strain Balance",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // Balance icon in colored rounded rect
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(
                            color = bColor.copy(alpha = 0.14f),
                            shape = RoundedCornerShape(12.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Balance,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = bColor,
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    // Balance label
                    Text(
                        text = state.strainBalance,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        color = bColor,
                    )

                    // Description
                    Text(
                        text = state.balanceLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    )
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. Strain Coach Section
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun StrainCoachSection(state: StrainDetailUiState) {
    val levelColor = strainLevelColor(state.strainLevel)
    val inTarget = state.strainScore >= state.targetMin && state.strainScore <= state.targetMax

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StrainSectionHeader(
            icon = Icons.Filled.GpsFixed,
            iconTint = levelColor,
            title = "Strain Coach",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column {
                // Row 1: Target strain range
                CoachRow(
                    icon = Icons.Filled.GpsFixed,
                    iconColor = AccentGreen,
                    label = "Target Range",
                    value = String.format("%.1f – %.1f", state.targetMin, state.targetMax),
                    trailing = {
                        if (inTarget) {
                            Icon(
                                imageVector = Icons.Filled.Check,
                                contentDescription = "In target",
                                modifier = Modifier.size(18.dp),
                                tint = AccentGreen,
                            )
                        } else {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = "Outside target",
                                modifier = Modifier.size(18.dp),
                                tint = AccentOrange,
                            )
                        }
                    },
                )

                HorizontalDivider(
                    modifier = Modifier.padding(start = 52.dp),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )

                // Row 2: Training zone
                CoachRow(
                    icon = Icons.Filled.FavoriteBorder,
                    iconColor = AccentRed,
                    label = "Training Zone",
                    value = state.trainingZone.ifEmpty { "—" },
                )

                HorizontalDivider(
                    modifier = Modifier.padding(start = 52.dp),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )

                // Row 3: Guidance
                CoachRow(
                    icon = Icons.AutoMirrored.Filled.Chat,
                    iconColor = AccentBlue,
                    label = "Guidance",
                    value = state.guidance,
                    singleLineValue = false,
                )
            }
        }
    }
}

@Composable
private fun CoachRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    value: String,
    singleLineValue: Boolean = true,
    trailing: @Composable (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = if (singleLineValue) Alignment.CenterVertically else Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Icon in colored circle
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(
                    color = iconColor.copy(alpha = 0.14f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = iconColor,
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (singleLineValue) FontWeight.SemiBold else FontWeight.Normal,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = if (singleLineValue) 1f else 0.85f),
                maxLines = if (singleLineValue) 1 else Int.MAX_VALUE,
            )
        }

        if (trailing != null) {
            trailing()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. HR Zone Breakdown
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun HrZoneBreakdownSection(zoneMinutes: Map<Int, Double>) {
    val totalMinutes = zoneMinutes.values.sum().coerceAtLeast(1.0)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StrainSectionHeader(
            icon = Icons.Filled.FavoriteBorder,
            iconTint = AccentRed,
            title = "HR Zone Breakdown",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                (1..5).forEachIndexed { index, zone ->
                    val minutes = zoneMinutes[zone] ?: 0.0
                    val fraction = (minutes / totalMinutes).toFloat().coerceIn(0f, 1f)
                    val zoneColor = ZoneColors.getOrElse(index) { AccentBlue }
                    val zoneName = ZoneNames.getOrElse(index) { "Zone $zone" }

                    ZoneRow(
                        zone = zone,
                        name = zoneName,
                        minutes = minutes,
                        fraction = fraction,
                        color = zoneColor,
                    )

                    if (index < 4) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 44.dp),
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ZoneRow(
    zone: Int,
    name: String,
    minutes: Double,
    fraction: Float,
    color: Color,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Zone circle label
        Box(
            modifier = Modifier
                .size(30.dp)
                .background(
                    color = color.copy(alpha = 0.14f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "Z$zone",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = color,
            )
        }

        // Zone name
        Text(
            text = name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.width(100.dp),
        )

        // Minutes label
        Text(
            text = "${minutes.toInt()}m",
            style = MaterialTheme.typography.labelMedium.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            modifier = Modifier.width(36.dp),
            textAlign = TextAlign.End,
        )

        // Percentage bar
        Box(
            modifier = Modifier
                .weight(1f)
                .height(8.dp),
        ) {
            // Track
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp)
                    .background(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                        shape = RoundedCornerShape(4.dp),
                    ),
            )
            // Fill
            if (fraction > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction)
                        .height(8.dp)
                        .background(
                            color = color,
                            shape = RoundedCornerShape(4.dp),
                        ),
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. 7-Day History — Canvas bars, day labels, target range dashes, legend, avg
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun WeeklyHistorySection(
    history: List<Float>,
    targetMin: Float,
    targetMax: Float,
) {
    val average = if (history.isNotEmpty()) history.average().toFloat() else 0f

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StrainSectionHeader(
            icon = Icons.AutoMirrored.Filled.ArrowForward,
            iconTint = AccentOrange,
            title = "7-Day History",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Canvas bar chart with target range
                val dayLabels = listOf("M", "T", "W", "T", "F", "S", "S")
                val chartMax = maxOf(
                    history.maxOrNull() ?: 0f,
                    targetMax * 1.15f,
                    14f,
                )

                val trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
                val targetLineColor = AccentGreen.copy(alpha = 0.55f)

                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp),
                ) {
                    val barCount = history.size.coerceAtMost(7)
                    if (barCount == 0) return@Canvas

                    val barSpacing = 10.dp.toPx()
                    val totalBarWidth = size.width - (barSpacing * (barCount + 1))
                    val barWidth = totalBarWidth / barCount
                    val chartHeight = size.height - 24.dp.toPx() // leave room for day labels
                    val cornerRadius = 4.dp.toPx()

                    // Draw target range dashed lines
                    val targetMinY = chartHeight * (1f - targetMin / chartMax)
                    val targetMaxY = chartHeight * (1f - targetMax / chartMax)
                    val dashEffect = PathEffect.dashPathEffect(
                        floatArrayOf(6.dp.toPx(), 4.dp.toPx()),
                    )

                    drawLine(
                        color = targetLineColor,
                        start = Offset(0f, targetMinY),
                        end = Offset(size.width, targetMinY),
                        strokeWidth = 1.dp.toPx(),
                        pathEffect = dashEffect,
                    )
                    drawLine(
                        color = targetLineColor,
                        start = Offset(0f, targetMaxY),
                        end = Offset(size.width, targetMaxY),
                        strokeWidth = 1.dp.toPx(),
                        pathEffect = dashEffect,
                    )

                    // Draw bars
                    history.take(7).forEachIndexed { index, value ->
                        val fraction = (value / chartMax).coerceIn(0f, 1f)
                        val barHeight = fraction * chartHeight
                        val x = barSpacing + index * (barWidth + barSpacing)
                        val y = chartHeight - barHeight
                        val barColor = strainLevelColor(strainLevelFromScore(value))

                        drawRoundRect(
                            color = barColor,
                            topLeft = Offset(x, y),
                            size = Size(barWidth, barHeight),
                            cornerRadius = CornerRadius(cornerRadius, cornerRadius),
                        )
                    }
                }

                // Day labels
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    dayLabels.take(history.size.coerceAtMost(7)).forEach { label ->
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                )

                // Legend row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Target range legend
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Canvas(modifier = Modifier.size(width = 16.dp, height = 2.dp)) {
                            drawLine(
                                color = AccentGreen.copy(alpha = 0.55f),
                                start = Offset(0f, size.height / 2),
                                end = Offset(size.width, size.height / 2),
                                strokeWidth = 2.dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(
                                    floatArrayOf(3.dp.toPx(), 2.dp.toPx()),
                                ),
                            )
                        }
                        Text(
                            text = "Target range",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                        )
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    // 7-day average badge
                    Box(
                        modifier = Modifier
                            .background(
                                color = strainLevelColor(strainLevelFromScore(average))
                                    .copy(alpha = LasoTokens.BadgeBgOpacity),
                                shape = RoundedCornerShape(12.dp),
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = "7d avg: ${String.format("%.1f", average)}",
                            style = MaterialTheme.typography.labelSmall.copy(
                                fontFamily = FontFamily.Monospace,
                            ),
                            fontWeight = FontWeight.SemiBold,
                            color = strainLevelColor(strainLevelFromScore(average)),
                        )
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. Disclaimer
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun DisclaimerSection() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = Icons.Filled.Info,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
        )
        Text(
            text = "Strain is calculated from heart rate, activity, and exercise data. It is an estimate and not a medical measurement.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared: Section Header (local, matches VitalityDetailScreen pattern)
// ═══════════════════════════════════════════════════════════════════════════════

@Composable
private fun StrainSectionHeader(
    icon: ImageVector,
    iconTint: Color,
    title: String,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = iconTint,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
    }
}
