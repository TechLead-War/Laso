package com.lasohealth.android.feature.detail

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.core.model.MetricDetailUiState
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

private val timeRangeOptions = listOf(30, 90, 180, 365)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MetricDetailScreen(
    state: MetricDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    var selectedTimeRange by remember { mutableIntStateOf(30) }
    val categoryColor = state.metric.category.accentColor
    val filteredChartValues = remember(state.chartValues, selectedTimeRange) {
        state.chartValues.takeLast(selectedTimeRange)
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.metric.displayName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
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
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Current Value Header
            item(key = "header") {
                MetricCurrentValueHeader(state = state)
            }

            // 2. Action Recommendation Banner (conditional — iOS: yellow lightbulb card)
            if (state.actionRecommendation.isNotEmpty()) {
                item(key = "actionBanner") {
                    Column {
                        ActionRecommendationBanner(
                            text = state.actionRecommendation,
                            modifier = Modifier.padding(horizontal = 16.dp),
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        HorizontalDivider(
                            modifier = Modifier.padding(horizontal = 16.dp),
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.15f),
                        )
                    }
                }
            }

            // 3. Time Range Selector
            item(key = "timeRange") {
                TimeRangeSelector(
                    options = timeRangeOptions,
                    selected = selectedTimeRange,
                    onSelect = { selectedTimeRange = it },
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }

            // 4. Chart Visualization (the biggest gap — now filled)
            if (filteredChartValues.isNotEmpty()) {
                item(key = "chart") {
                    MetricChart(
                        values = filteredChartValues,
                        color = categoryColor,
                        timeRangeDays = selectedTimeRange,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
            }

            // 5. Week-over-Week badge + Data Source (conditional)
            if (state.weekOverWeekBadge.isNotEmpty() || state.dataSource.isNotEmpty()) {
                item(key = "badges") {
                    MetricBadgesRow(
                        weekBadge = state.weekOverWeekBadge,
                        dataSource = state.dataSource,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
            }

            // 6. Stats Summary (2-column: Average+Change | Range+Trend)
            item(key = "stats") {
                MetricStatsSummaryCard(state = state)
            }

            // 5. Historical Context (conditional)
            if (state.historicalFacts.isNotEmpty()) {
                item(key = "historicalContext") {
                    MetricHistoricalContextSection(facts = state.historicalFacts)
                }
            }

            // 6. Score Breakdown
            item(key = "scoreBreakdown") {
                MetricScoreBreakdownCard(state = state)
            }

            // 7. Related Insights (conditional)
            if (state.relatedInsights.isNotEmpty()) {
                item(key = "insights") {
                    MetricInsightsSection(
                        insights = state.relatedInsights,
                        onInsightTap = { insight ->
                            navController.navigate(
                                AppRoute.MetricDetail.createRoute(insight.metric),
                            )
                        },
                    )
                }
            }

            // Bottom spacer
            item(key = "bottomSpacer") {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// ── Time Range Selector (shared across detail screens) ────────────────────────

@Composable
internal fun TimeRangeSelector(
    options: List<Int>,
    selected: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { days ->
            val label = if (days < 365) "${days}d" else "1y"
            val isSelected = days == selected

            FilterChip(
                selected = isSelected,
                onClick = { onSelect(days) },
                label = {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.onSurface,
                    selectedLabelColor = MaterialTheme.colorScheme.surface,
                ),
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// ── Current Value Header ──────────────────────────────────────────────────────

@Composable
private fun MetricCurrentValueHeader(state: MetricDetailUiState) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Large value + unit
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = state.currentValue,
                    style = MaterialTheme.typography.displayMedium,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = state.unit,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(bottom = 8.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Baseline comparison
            Text(
                text = "Baseline: ${state.baselineValue}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Status badge capsule
            val statusColor = metricStatusBadgeColor(state.statusLabel)
            Text(
                text = state.statusLabel,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(statusColor)
                    .padding(horizontal = 12.dp, vertical = 4.dp),
            )
        }
    }
}

// ── Stats Summary (2-column: Average+Change | Range+Trend) ───────────────────

@Composable
private fun MetricStatsSummaryCard(state: MetricDetailUiState) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Min),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            // Left column: Average + Change
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                MetricStatCell(label = "Average", value = state.average)
                Spacer(modifier = Modifier.height(12.dp))
                MetricStatCell(
                    label = "Change",
                    value = state.monthOverMonthChange ?: "—",
                    valueColor = state.monthOverMonthChange?.let {
                        if (!it.startsWith("-")) AccentGreen else AccentRed
                    },
                )
            }

            VerticalDividerLine()

            // Right column: Range + Trend
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                MetricStatCell(label = "Range", value = "${state.min}–${state.max}")
                Spacer(modifier = Modifier.height(12.dp))
                MetricStatCell(
                    label = "Trend",
                    value = state.weekOverWeekBadge.ifEmpty { "—" },
                    valueColor = if (state.weekOverWeekBadge.startsWith("+")) AccentGreen
                    else if (state.weekOverWeekBadge.startsWith("-")) AccentRed
                    else null,
                )
            }
        }
    }
}

@Composable
private fun MetricStatCell(
    label: String,
    value: String,
    valueColor: Color? = null,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = valueColor ?: MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

@Composable
private fun VerticalDividerLine() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .fillMaxHeight()
            .padding(vertical = 4.dp)
            .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
    )
}

// ── Historical Context ────────────────────────────────────────────────────────

private val historicalFactIcons: List<ImageVector> = listOf(
    Icons.Filled.Timeline,
    Icons.Filled.TrendingUp,
    Icons.Filled.Star,
    Icons.Filled.History,
    Icons.Filled.Insights,
)

@Composable
private fun MetricHistoricalContextSection(facts: List<String>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "From Your History")

        facts.forEachIndexed { index, fact ->
            val icon = historicalFactIcons[index % historicalFactIcons.size]
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    Text(
                        text = fact,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// ── Score Breakdown ────────────────────────────────────────────────────────────

@Composable
private fun MetricScoreBreakdownCard(state: MetricDetailUiState) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Column {
            Text(
                text = "Score Impact",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Contributes ${state.scoreContribution}% to your overall score",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(8.dp))

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
            )

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(state.metric.category.accentColor),
                )
                Text(
                    text = "${state.metric.category.displayName} \u2014 ${state.categoryImpact}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// ── Insights Section ──────────────────────────────────────────────────────────

@Composable
private fun MetricInsightsSection(
    insights: List<InsightUi>,
    onInsightTap: (InsightUi) -> Unit,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Insights")

        insights.forEach { insight ->
            LasoCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onInsightTap(insight) },
            ) {
                Column {
                    // Top row: lightbulb + category dot + badge
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "\uD83D\uDCA1",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(insight.metric.category.accentColor),
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Text(
                            text = insight.metric.category.shortName,
                            style = MaterialTheme.typography.labelSmall,
                            color = insight.metric.category.accentColor,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(
                                    insight.metric.category.accentColor.copy(
                                        alpha = LasoTokens.BadgeBgOpacity,
                                    ),
                                )
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Title
                    Text(
                        text = insight.title,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    // Detail
                    Text(
                        text = insight.detail,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        maxLines = 3,
                    )
                }
            }
        }
    }
}

// ── Action Recommendation Banner ─────────────────────────────────────────────

@Composable
private fun ActionRecommendationBanner(
    text: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = AccentYellow.copy(alpha = 0.12f),
                shape = RoundedCornerShape(LasoTokens.CardRadius),
            )
            .padding(LasoTokens.CardPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Lightbulb,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = AccentYellow,
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
    }
}

// ── Metric Chart ─────────────────────────────────────────────────────────────

@Composable
private fun MetricChart(
    values: List<Float>,
    color: Color,
    timeRangeDays: Int = 30,
    modifier: Modifier = Modifier,
) {
    if (values.size < 2) return

    val minVal = values.min() - (values.max() - values.min()) * 0.1f
    val maxVal = values.max() + (values.max() - values.min()) * 0.1f
    val range = (maxVal - minVal).coerceAtLeast(1f)
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant

    LasoCard(modifier = modifier.fillMaxWidth()) {
        Column {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp),
            ) {
                val w = size.width
                val h = size.height
                val n = values.size

                val points = values.mapIndexed { index, value ->
                    val x = (index.toFloat() / (n - 1)) * w
                    val y = h - ((value - minVal) / range) * h
                    Offset(x, y)
                }

                // Baseline dashed line at average
                val avg = values.average().toFloat()
                val avgY = h - ((avg - minVal) / range) * h
                val dashPath = Path().apply {
                    var x = 0f
                    while (x < w) {
                        moveTo(x, avgY)
                        lineTo((x + 6.dp.toPx()).coerceAtMost(w), avgY)
                        x += 12.dp.toPx()
                    }
                }
                drawPath(
                    path = dashPath,
                    color = color.copy(alpha = 0.25f),
                    style = Stroke(width = 1.dp.toPx()),
                )

                // Area fill
                val areaPath = Path().apply {
                    moveTo(points.first().x, h)
                    points.forEach { lineTo(it.x, it.y) }
                    lineTo(points.last().x, h)
                    close()
                }
                drawPath(
                    path = areaPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            color.copy(alpha = 0.18f),
                            color.copy(alpha = 0.02f),
                        ),
                    ),
                )

                // Line
                val linePath = Path().apply {
                    moveTo(points.first().x, points.first().y)
                    for (i in 1 until points.size) {
                        val prev = points[i - 1]
                        val curr = points[i]
                        val cpX = (prev.x + curr.x) / 2f
                        cubicTo(cpX, prev.y, cpX, curr.y, curr.x, curr.y)
                    }
                }
                drawPath(
                    path = linePath,
                    color = color,
                    style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round),
                )

                // End dot
                val last = points.last()
                drawCircle(
                    color = color,
                    radius = 4.dp.toPx(),
                    center = last,
                )
                drawCircle(
                    color = Color.White,
                    radius = 2.dp.toPx(),
                    center = last,
                )
            }

            // Time axis labels
            val startLabel = if (timeRangeDays >= 365) "1y ago"
                else "${timeRangeDays}d ago"
            val midLabel = if (timeRangeDays >= 365) "6mo ago"
                else "${timeRangeDays / 2}d ago"
            Spacer(modifier = Modifier.height(6.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = startLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = labelColor,
                )
                Text(
                    text = midLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = labelColor,
                )
                Text(
                    text = "Today",
                    style = MaterialTheme.typography.labelSmall,
                    color = labelColor,
                )
            }
        }
    }
}

// ── Badges Row (Week-over-Week + Data Source) ────────────────────────────────

@Composable
private fun MetricBadgesRow(
    weekBadge: String,
    dataSource: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (weekBadge.isNotEmpty()) {
            val isPositive = weekBadge.startsWith("+")
            val badgeColor = if (isPositive) AccentGreen else AccentRed
            val icon = if (isPositive) Icons.Filled.NorthEast else Icons.Filled.SouthEast
            Row(
                modifier = Modifier
                    .background(
                        color = badgeColor.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(50),
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = badgeColor,
                )
                Text(
                    text = weekBadge,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = badgeColor,
                )
            }
        }
        if (dataSource.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .background(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                        shape = RoundedCornerShape(50),
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.Watch,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
                Text(
                    text = dataSource,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

@Composable
private fun metricStatusBadgeColor(statusLabel: String): Color {
    val lower = statusLabel.lowercase()
    return when {
        lower.contains("optimal") || lower.contains("good") || lower.contains("normal") -> AccentGreen
        lower.contains("fair") || lower.contains("elevated") -> AccentYellow
        lower.contains("high") || lower.contains("low") || lower.contains("poor") -> AccentRed
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    }
}
