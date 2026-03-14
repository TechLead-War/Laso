package com.lasohealth.android.feature.detail

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.LocalCafe
import androidx.compose.material.icons.outlined.PhonelinkOff
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.SleepCoachUiState
import com.lasohealth.android.core.model.SleepDayUi
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.CategorySleep
import kotlin.math.ceil

// region Performance Level

private enum class PerformanceLevel(val label: String, val adjustment: Double) {
    Peak("Peak", 0.75),
    Perform("Perform", 0.0),
    GetBy("Get By", -0.75),
}

// endregion

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SleepCoachScreen(
    state: SleepCoachUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    var performanceLevel by remember { mutableStateOf(PerformanceLevel.Perform) }
    var showAllTips by remember { mutableStateOf(false) }

    val adjustedNeed = (state.baseHoursNeeded + performanceLevel.adjustment).coerceAtLeast(4.0)

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Sleep Coach",
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
            // 1. Hero Section
            item {
                HeroSection(
                    adjustedNeed = adjustedNeed,
                    performanceLevel = performanceLevel,
                )
            }

            // 2. Performance Level Picker
            item {
                PerformancePicker(
                    selected = performanceLevel,
                    onSelected = { performanceLevel = it },
                )
            }

            // 3. Schedule Section
            item {
                ScheduleSection(
                    bedtime = state.recommendedBedtime,
                    wakeTime = state.recommendedWakeTime,
                )
            }

            // 4. Sleep Debt Section
            item {
                DebtSection(
                    sleepDebt = state.sleepDebt,
                    dailyHistory = state.dailyHistory,
                )
            }

            // 5. 14-Day History
            if (state.dailyHistory.isNotEmpty()) {
                item {
                    HistorySection(days = state.dailyHistory)
                }
            }

            // 6. Consistency Section
            item {
                ConsistencySection(score = state.consistencyScore)
            }

            // 7. Tips Section
            item {
                TipsSection(
                    sleepDebt = state.sleepDebt,
                    daysToPayOff = computeDaysToPayOff(state.sleepDebt),
                    showAllTips = showAllTips,
                    onShowMore = { showAllTips = true },
                )
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
private fun HeroSection(adjustedNeed: Double, performanceLevel: PerformanceLevel) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Circular progress ring
            Box(
                modifier = Modifier.size(120.dp),
                contentAlignment = Alignment.Center,
            ) {
                val fraction = (adjustedNeed / 12.0).coerceIn(0.0, 1.0).toFloat()
                val trackColor = CategorySleep.copy(alpha = 0.2f)

                Canvas(modifier = Modifier.fillMaxSize()) {
                    val sw = 8.dp.toPx()
                    val inset = sw / 2f
                    val diameter = size.minDimension - sw

                    // Track ring
                    drawArc(
                        color = trackColor,
                        startAngle = 0f,
                        sweepAngle = 360f,
                        useCenter = false,
                        topLeft = Offset(inset, inset),
                        size = Size(diameter, diameter),
                        style = Stroke(width = sw, cap = StrokeCap.Round),
                    )

                    // Progress arc
                    drawArc(
                        color = CategorySleep,
                        startAngle = -90f,
                        sweepAngle = fraction * 360f,
                        useCenter = false,
                        topLeft = Offset(inset, inset),
                        size = Size(diameter, diameter),
                        style = Stroke(width = sw, cap = StrokeCap.Round),
                    )
                }

                // Center content: moon icon + duration + "Tonight"
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "\uD83C\uDF19",
                        fontSize = 22.sp,
                    )
                    Text(
                        text = formatDuration(adjustedNeed),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = "Tonight",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }

            // Recommendation text below ring
            Text(
                text = "Recommended for ${performanceLevel.label.lowercase()} performance",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                textAlign = TextAlign.Center,
            )
        }
    }
}

// endregion

// region 2. Performance Level Picker

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PerformancePicker(
    selected: PerformanceLevel,
    onSelected: (PerformanceLevel) -> Unit,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SleepSectionHeader(
            icon = Icons.Outlined.Tune,
            title = "Performance Level",
        )

        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            PerformanceLevel.entries.forEachIndexed { index, level ->
                SegmentedButton(
                    selected = selected == level,
                    onClick = { onSelected(level) },
                    shape = SegmentedButtonDefaults.itemShape(
                        index = index,
                        count = PerformanceLevel.entries.size,
                    ),
                    icon = {},
                ) {
                    Text(
                        text = level.label,
                        fontWeight = if (selected == level) FontWeight.Bold else FontWeight.Normal,
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Schedule Section

@Composable
private fun ScheduleSection(bedtime: String, wakeTime: String) {
    Row(
        modifier = Modifier.padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Bedtime card
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = CategorySleep,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "\uD83C\uDF19",
                    fontSize = 24.sp,
                )
                Text(
                    text = "BEDTIME",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Text(
                    text = bedtime.ifEmpty { "--:--" },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        // Wake Up card
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = AccentOrange,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "\uD83C\uDF05",
                    fontSize = 24.sp,
                )
                Text(
                    text = "WAKE UP",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Text(
                    text = wakeTime.ifEmpty { "--:--" },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        }
    }
}

// endregion

// region 4. Sleep Debt Section

@Composable
private fun DebtSection(
    sleepDebt: Double,
    dailyHistory: List<SleepDayUi>,
) {
    val daysToPayOff = computeDaysToPayOff(sleepDebt)
    val (debtLevelText, debtLevelColor) = computeDebtLevel(sleepDebt)
    val debtBarColor = computeDebtColor(sleepDebt)
    val debtFraction = (sleepDebt / 10.0).coerceIn(0.0, 1.0).toFloat()
    val (trendLabel, trendColor, trendArrow) = computeDebtTrend(dailyHistory)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SleepSectionHeader(
            icon = Icons.Filled.Warning,
            title = "Sleep Debt",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Top row: debt value + badge / days to pay off
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top,
                ) {
                    // Left: label + value
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = "CURRENT DEBT",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                        Text(
                            text = formatDuration(sleepDebt),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = if (sleepDebt > 0) {
                                MaterialTheme.colorScheme.onSurface
                            } else {
                                AccentGreen
                            },
                        )
                    }

                    // Right: badge + days to pay off
                    Column(
                        horizontalAlignment = Alignment.End,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        // Debt level badge
                        Text(
                            text = debtLevelText,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = debtLevelColor,
                            modifier = Modifier
                                .background(
                                    color = debtLevelColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                                    shape = RoundedCornerShape(50),
                                )
                                .padding(horizontal = 8.dp, vertical = 3.dp),
                        )

                        if (sleepDebt > 0) {
                            Text(
                                text = "~$daysToPayOff days to pay off",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            )
                        }
                    }
                }

                // Progress bar
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp),
                ) {
                    // Track
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp)
                            .background(
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                                shape = RoundedCornerShape(3.dp),
                            ),
                    )
                    // Fill
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(debtFraction)
                            .height(6.dp)
                            .background(
                                color = debtBarColor,
                                shape = RoundedCornerShape(3.dp),
                            ),
                    )
                }

                // Trend indicator
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = trendArrow,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = trendColor,
                    )
                    Text(
                        text = trendLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = trendColor,
                    )
                }
            }
        }
    }
}

// endregion

// region 5. 14-Day History

@Composable
private fun HistorySection(days: List<SleepDayUi>) {
    val visibleDays = days.takeLast(14)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SleepSectionHeader(
            icon = null,
            title = "14-Day History",
            emojiIcon = "\uD83D\uDCCA",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                visibleDays.forEach { day ->
                    HistoryBarRow(day = day)
                }
            }
        }
    }
}

@Composable
private fun HistoryBarRow(day: SleepDayUi) {
    val metTarget = day.actual >= day.target
    val barColor = if (metTarget) CategorySleep else AccentOrange

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Day label
        Text(
            text = day.day,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.width(30.dp),
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Stacked bars
        Box(
            modifier = Modifier
                .weight(1f)
                .height(14.dp),
        ) {
            val maxHours = 12.0
            val neededFraction = (day.target / maxHours).coerceIn(0.0, 1.0).toFloat()
            val actualFraction = (day.actual / maxHours).coerceIn(0.0, 1.0).toFloat()

            // Needed baseline (gray)
            Box(
                modifier = Modifier
                    .fillMaxWidth(neededFraction)
                    .height(14.dp)
                    .background(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(3.dp),
                    ),
            )

            // Actual sleep (colored)
            Box(
                modifier = Modifier
                    .fillMaxWidth(actualFraction)
                    .height(14.dp)
                    .background(
                        color = barColor,
                        shape = RoundedCornerShape(3.dp),
                    ),
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Hours value
        Text(
            text = formatDuration(day.actual),
            style = MaterialTheme.typography.labelSmall,
            color = if (metTarget) {
                MaterialTheme.colorScheme.onSurface
            } else {
                AccentOrange
            },
            modifier = Modifier.width(44.dp),
            textAlign = TextAlign.End,
        )
    }
}

// endregion

// region 6. Consistency Section

@Composable
private fun ConsistencySection(score: Int) {
    val consistencyColor = computeConsistencyColor(score)
    val consistencyLabel = computeConsistencyLabel(score)
    val consistencyDescription = computeConsistencyDescription(score)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SleepSectionHeader(
            icon = null,
            title = "Consistency",
            emojiIcon = "\uD83C\uDFAF",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                // Ring gauge
                Box(
                    modifier = Modifier.size(72.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    val fraction = (score / 100.0).coerceIn(0.0, 1.0).toFloat()
                    val trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)

                    Canvas(modifier = Modifier.fillMaxSize()) {
                        val sw = 6.dp.toPx()
                        val inset = sw / 2f
                        val diameter = size.minDimension - sw

                        drawArc(
                            color = trackColor,
                            startAngle = 0f,
                            sweepAngle = 360f,
                            useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(diameter, diameter),
                            style = Stroke(width = sw, cap = StrokeCap.Round),
                        )

                        drawArc(
                            color = consistencyColor,
                            startAngle = -90f,
                            sweepAngle = fraction * 360f,
                            useCenter = false,
                            topLeft = Offset(inset, inset),
                            size = Size(diameter, diameter),
                            style = Stroke(width = sw, cap = StrokeCap.Round),
                        )
                    }

                    Text(
                        text = score.toString(),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                // Label + description
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = consistencyLabel,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = consistencyDescription,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }
        }
    }
}

// endregion

// region 7. Tips Section

private data class SleepTip(
    val icon: ImageVector,
    val color: Color,
    val title: String,
    val detail: String,
)

@Composable
private fun TipsSection(
    sleepDebt: Double,
    daysToPayOff: Int,
    showAllTips: Boolean,
    onShowMore: () -> Unit,
) {
    val tips = rememberTips(sleepDebt, daysToPayOff)
    val visibleTips = if (showAllTips) tips else tips.take(2)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SleepSectionHeader(
            icon = Icons.Filled.Lightbulb,
            title = if (sleepDebt > 2) "Paying Off Debt" else "Sleep Tips",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.animateContentSize()) {
                visibleTips.forEachIndexed { index, tip ->
                    TipRow(tip = tip)
                    if (index < visibleTips.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 44.dp),
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
                        )
                    }
                }

                if (!showAllTips && tips.size > 2) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 44.dp),
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
                    )
                    TextButton(
                        onClick = onShowMore,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = "Show ${tips.size - 2} more tips",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TipRow(tip: SleepTip) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Icon in colored rounded rect
        Box(
            modifier = Modifier
                .size(32.dp)
                .background(
                    color = tip.color.copy(alpha = LasoTokens.BadgeBgOpacity),
                    shape = RoundedCornerShape(LasoTokens.IconRadius),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = tip.icon,
                contentDescription = null,
                tint = tip.color,
                modifier = Modifier.size(18.dp),
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = tip.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = tip.detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

@Composable
private fun rememberTips(sleepDebt: Double, daysToPayOff: Int): List<SleepTip> {
    return remember(sleepDebt, daysToPayOff) {
        if (sleepDebt > 2) {
            listOf(
                SleepTip(
                    icon = Icons.Outlined.AddCircleOutline,
                    color = CategorySleep,
                    title = "Add 30\u201345 Minutes",
                    detail = "Go to bed 30\u201345 min early tonight to start chipping away at your debt.",
                ),
                SleepTip(
                    icon = Icons.Outlined.CalendarMonth,
                    color = AccentOrange,
                    title = "Be Patient",
                    detail = "It takes about $daysToPayOff days to fully recover. Add a little sleep each night rather than one long marathon.",
                ),
                SleepTip(
                    icon = Icons.Outlined.LocalCafe,
                    color = Color(0xFF795548),
                    title = "Cut Caffeine After 2 PM",
                    detail = "Caffeine has a 6-hour half-life. Afternoon coffee can silently reduce deep sleep even if you fall asleep fine.",
                ),
                SleepTip(
                    icon = Icons.Outlined.PhonelinkOff,
                    color = AccentRed,
                    title = "Screen Curfew",
                    detail = "Put screens away 45\u201360 min before bed. Blue light suppresses melatonin and delays sleep onset.",
                ),
            )
        } else {
            listOf(
                SleepTip(
                    icon = Icons.Outlined.Schedule,
                    color = CategorySleep,
                    title = "Consistent Schedule",
                    detail = "Going to bed and waking up at the same time every day is the single most impactful sleep habit.",
                ),
                SleepTip(
                    icon = Icons.Outlined.AcUnit,
                    color = Color(0xFF00BCD4),
                    title = "Cool Bedroom",
                    detail = "Keep your room between 65\u201368\u00B0F (18\u201320\u00B0C). A cool environment triggers natural drowsiness.",
                ),
                SleepTip(
                    icon = Icons.Outlined.WbSunny,
                    color = AccentOrange,
                    title = "Morning Sunlight",
                    detail = "Get 10\u201315 minutes of sunlight within an hour of waking to anchor your circadian rhythm.",
                ),
                SleepTip(
                    icon = Icons.Outlined.DirectionsWalk,
                    color = AccentGreen,
                    title = "Exercise Timing",
                    detail = "Regular exercise improves sleep quality, but finish vigorous workouts at least 3 hours before bed.",
                ),
            )
        }
    }
}

// endregion

// region Section Header

@Composable
private fun SleepSectionHeader(
    icon: ImageVector?,
    title: String,
    emojiIcon: String? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (emojiIcon != null) {
            Text(
                text = emojiIcon,
                fontSize = 16.sp,
            )
        } else if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = CategorySleep,
                modifier = Modifier.size(18.dp),
            )
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

// endregion

// region Computed Helpers

private fun formatDuration(hours: Double): String {
    val h = hours.toInt()
    val m = ((hours - h) * 60).toInt()
    return if (h == 0) "${m}m" else "${h}h ${String.format("%02d", m)}m"
}

private fun computeDaysToPayOff(debtHours: Double): Int {
    if (debtHours <= 0) return 0
    return ceil(debtHours / 0.75).toInt().coerceAtLeast(1)
}

private fun computeDebtLevel(debtHours: Double): Pair<String, Color> {
    return when {
        debtHours <= 0.5 -> "Clear" to AccentGreen
        debtHours <= 2.0 -> "Low" to Color(0xFF4A90D9)
        debtHours <= 5.0 -> "Moderate" to AccentOrange
        else -> "High" to AccentRed
    }
}

private fun computeDebtColor(debtHours: Double): Color {
    return when {
        debtHours <= 1.0 -> AccentGreen
        debtHours <= 4.0 -> AccentOrange
        else -> AccentRed
    }
}

private data class TrendInfo(
    val label: String,
    val color: Color,
    val arrow: String,
)

private fun computeDebtTrend(dailyHistory: List<SleepDayUi>): TrendInfo {
    val recent = dailyHistory.takeLast(3)
    if (recent.size < 2) return TrendInfo("Tracking", Color.Gray, "\u2192")

    val avgDelta = recent.map { it.actual - it.target }.average()
    return when {
        avgDelta > 0.25 -> TrendInfo("Paying Off", AccentGreen, "\u2198")
        avgDelta < -0.25 -> TrendInfo("Accumulating", AccentOrange, "\u2197")
        else -> TrendInfo("Stable", Color.Gray, "\u2192")
    }
}

private fun computeConsistencyColor(score: Int): Color {
    return when {
        score >= 80 -> AccentGreen
        score >= 60 -> Color(0xFF4A90D9)
        score >= 40 -> AccentOrange
        else -> AccentRed
    }
}

private fun computeConsistencyLabel(score: Int): String {
    return when {
        score >= 80 -> "Excellent"
        score >= 60 -> "Good"
        score >= 40 -> "Needs Work"
        else -> "Irregular"
    }
}

private fun computeConsistencyDescription(score: Int): String {
    return when {
        score >= 80 -> "Your sleep schedule is very consistent. This is one of the strongest predictors of good sleep quality."
        score >= 60 -> "Minor variations in your schedule. Tightening your bedtime window could improve sleep quality."
        score >= 40 -> "Your sleep times vary quite a bit. Try to keep bedtime within a 30-minute window each night."
        else -> "Irregular sleep schedule detected. Your body\u2019s circadian rhythm works best with consistency."
    }
}

// endregion
