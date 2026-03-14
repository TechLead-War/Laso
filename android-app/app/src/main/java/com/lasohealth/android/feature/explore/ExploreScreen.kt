package com.lasohealth.android.feature.explore

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.AttentionUi
import com.lasohealth.android.core.model.CategoryScoreUi
import com.lasohealth.android.core.model.CorrelationUi
import com.lasohealth.android.core.model.ExploreUiState
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.TrendMetricUi
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentRed

@Composable
fun ExploreScreen(
    state: ExploreUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp),
        // iOS: VStack(spacing: 24)
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        // 1. Score Hero Section
        item {
            ScoreHeroSection(
                score = state.overallScore,
                scoreDelta = state.scoreChangeFromLastWeek,
                weakestCategory = state.weakestCategory,
                onInfoClick = { navController.navigate(AppRoute.ScoreGuide.route) },
            )
        }

        // 2. Data Summary Bar
        item {
            DataSummaryBar(
                metricsTracked = state.metricsTracked,
                totalDataPoints = state.totalDataPoints,
                daysOfData = state.daysOfData,
            )
        }

        // 3. Your Trends Section
        if (state.trendMetrics.isNotEmpty()) {
            item {
                YourTrendsSection(
                    items = state.trendMetrics,
                    onItemClick = { metric ->
                        navController.navigate(AppRoute.MetricDetail.createRoute(metric))
                    },
                )
            }
        }

        // 4. Categories Section
        item {
            CategoriesGridSection(
                items = state.categoryScores,
                onCategoryClick = { category ->
                    navController.navigate(AppRoute.CategoryDetail.createRoute(category))
                },
            )
        }

        // 5. Needs Attention Section (conditional)
        if (state.needsAttention.isNotEmpty()) {
            item {
                NeedsAttentionSection(
                    items = state.needsAttention,
                    onItemClick = { metric ->
                        navController.navigate(AppRoute.MetricDetail.createRoute(metric))
                    },
                )
            }
        }

        // 6. Correlations Section (conditional)
        if (state.correlations.isNotEmpty()) {
            item {
                CorrelationsSection(
                    items = state.correlations,
                    onSeeAllClick = { navController.navigate(AppRoute.CorrelationsDetail.route) },
                )
            }
        }

        // 7. Bottom spacer for nav bar clearance
        item {
            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

// ── 1. Score Hero Section ────────────────────────────────────────────────────
// iOS: ultraThinMaterial background, cornerRadius 20, padding 16
// HStack(spacing: 20) { ring(100pt) + VStack(label, score 44pt, delta) }

@Composable
private fun ScoreHeroSection(
    score: Int,
    scoreDelta: Int,
    weakestCategory: HealthCategory,
    onInfoClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp)
            // iOS: .ultraThinMaterial in RoundedRectangle(cornerRadius: 20)
            .background(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(20.dp),
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Top: Ring (left) + Score info (right) — iOS HStack(spacing: 20)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // iOS: HealthScoreRing(size: 100, lineWidth: 10)
            HealthScoreRing(
                score = score,
                size = 100.dp,
                strokeWidth = 10.dp,
            )

            // iOS: VStack(alignment: .leading, spacing: 6)
            Column(
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // "Health Score" label + info icon — iOS: HStack(spacing: 6)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    // iOS: .subheadline, .secondary
                    Text(
                        text = "Health Score",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                    // iOS: info.circle, .caption, .secondary
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Score info",
                        modifier = Modifier
                            .size(14.dp)
                            .clickable(onClick = onInfoClick),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }

                // Score number — iOS: .system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
                Text(
                    text = score.toString(),
                    fontSize = 44.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = LasoTokens.scoreColor(score),
                )

                // Delta badge OR score label
                if (scoreDelta != 0) {
                    val deltaColor = if (scoreDelta > 0) AccentGreen else AccentRed
                    val deltaPrefix = if (scoreDelta > 0) "+" else ""
                    // iOS: HStack(spacing: 4) { arrow icon + text }
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        // iOS: arrow.up.right / arrow.down.right, .caption2.weight(.bold)
                        Icon(
                            imageVector = if (scoreDelta > 0) Icons.Filled.NorthEast else Icons.Filled.SouthEast,
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                            tint = deltaColor,
                        )
                        // iOS: .caption.weight(.medium)
                        Text(
                            text = "${deltaPrefix}${scoreDelta} pts this week",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Medium,
                            color = deltaColor,
                        )
                    }
                } else {
                    Text(
                        text = LasoTokens.scoreLabel(score),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))
        }

        // Weakest category focus hint — iOS: category icon + text in secondary background
        Row(
            modifier = Modifier
                .background(
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    shape = RoundedCornerShape(10.dp),
                )
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            // iOS: Image(systemName: category.systemImageName).font(.caption)
            Icon(
                imageVector = weakestCategory.icon,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = weakestCategory.accentColor,
            )
            // iOS: .caption, .secondary
            Text(
                text = "Focus on ${weakestCategory.shortName} to improve",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

// ── 2. Data Summary Bar ──────────────────────────────────────────────────────
// iOS: HStack with dividers, .quaternary.opacity(0.3) background

@Composable
private fun DataSummaryBar(
    metricsTracked: Int,
    totalDataPoints: Int,
    daysOfData: Int,
) {
    // iOS: quaternary.opacity(0.3) in RoundedRectangle, not LasoCard
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                shape = RoundedCornerShape(LasoTokens.CardRadius),
            )
            .padding(vertical = 10.dp)
            .height(IntrinsicSize.Min),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SummaryStat(value = metricsTracked.toString(), label = "Metrics", modifier = Modifier.weight(1f))
        VerticalDivider(
            modifier = Modifier.fillMaxHeight().padding(vertical = 4.dp),
            thickness = 1.dp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f),
        )
        SummaryStat(value = formatDataPoints(totalDataPoints), label = "Data Points", modifier = Modifier.weight(1f))
        if (daysOfData > 0) {
            VerticalDivider(
                modifier = Modifier.fillMaxHeight().padding(vertical = 4.dp),
                thickness = 1.dp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f),
            )
            SummaryStat(value = daysOfData.toString(), label = if (daysOfData == 1) "Day" else "Days", modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun SummaryStat(value: String, label: String, modifier: Modifier = Modifier) {
    // iOS: VStack(spacing: 2) { .subheadline.weight(.bold).monospacedDigit() + .caption2, .secondary }
    Column(
        modifier = modifier.padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            ),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// ── 3. Your Trends Section ───────────────────────────────────────────────────
// iOS: heading + segmented picker (7D/30D/90D) + trend metric rows with sparklines

@Composable
private fun YourTrendsSection(
    items: List<TrendMetricUi>,
    onItemClick: (HealthMetric) -> Unit,
) {
    // iOS: Picker for timeframe
    var selectedTimeframe by remember { mutableIntStateOf(1) } // 0=7D, 1=30D, 2=90D
    val timeframeLabels = listOf("7D", "30D", "90D")

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // iOS: "Your Trends" .headline
        Text(
            text = "Your Trends",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        // iOS: Picker(.segmented) — 7D / 30D / 90D
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            timeframeLabels.forEachIndexed { index, label ->
                SegmentedButton(
                    shape = SegmentedButtonDefaults.itemShape(
                        index = index,
                        count = timeframeLabels.size,
                    ),
                    onClick = { selectedTimeframe = index },
                    selected = selectedTimeframe == index,
                    label = { Text(label) },
                )
            }
        }

        // iOS: ForEach(trendMetrics.prefix(8)) — trend rows
        items.take(8).forEach { trend ->
            TrendMetricRow(
                trend = trend,
                onClick = { onItemClick(trend.metric) },
            )
        }
    }
}

@Composable
private fun TrendMetricRow(
    trend: TrendMetricUi,
    onClick: () -> Unit,
) {
    val categoryColor = trend.metric.category.accentColor
    val trendColor = if (trend.metric.higherIsBetter) AccentGreen else AccentRed

    // iOS: HStack(spacing: 12) inside .cardStyle()
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // iOS: metric icon in colored rounded rect (DS.iconSize × DS.iconSize, DS.iconRadius)
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        color = categoryColor.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(10.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = trend.metric.category.icon,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = categoryColor,
                )
            }

            // iOS: VStack(alignment: .leading, spacing: 2) { metric name + rate label }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // iOS: .subheadline.weight(.semibold)
                Text(
                    text = trend.metric.displayName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                // iOS: .caption, .secondary — rate of change label
                Text(
                    text = trend.summary,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }

            // Sparkline mini chart — iOS: SparklineView(52×24)
            SparklineChart(
                color = trendColor,
                modifier = Modifier.size(width = 52.dp, height = 24.dp),
            )

            // iOS: trend direction icon + percent change
            Icon(
                imageVector = if (trend.metric.higherIsBetter) Icons.Filled.NorthEast else Icons.Filled.SouthEast,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = trendColor,
            )

            // iOS: chevron.right
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

// Simple sparkline chart matching iOS SparklineView
@Composable
private fun SparklineChart(
    color: Color,
    modifier: Modifier = Modifier,
) {
    // Generate a simple representative sparkline shape
    val values = remember {
        listOf(0.3f, 0.5f, 0.4f, 0.6f, 0.55f, 0.7f, 0.65f, 0.8f, 0.75f, 0.85f, 0.9f, 0.82f)
    }
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val path = Path()
        values.forEachIndexed { index, value ->
            val x = w * index / (values.size - 1).coerceAtLeast(1)
            val y = h - (h * value)
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 1.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

// ── 4. Categories Section ────────────────────────────────────────────────────
// iOS: vertical list with icons (not emojis), dividers, score rings, chevrons

@Composable
private fun CategoriesGridSection(
    items: List<CategoryScoreUi>,
    onCategoryClick: (HealthCategory) -> Unit,
) {
    val primaryCategories = listOf(
        HealthCategory.HEART, HealthCategory.SLEEP, HealthCategory.ACTIVITY,
        HealthCategory.BODY, HealthCategory.RESPIRATORY, HealthCategory.MINDFULNESS,
        HealthCategory.MOBILITY,
    )
    val filteredItems = items.filter { it.category in primaryCategories }
    val displayItems = filteredItems.ifEmpty { items }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // iOS: .headline
        Text(
            text = "Categories",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        // iOS: VStack(spacing: 0) with Dividers in .background(.background, cornerRadius)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = MaterialTheme.colorScheme.surface,
                    shape = RoundedCornerShape(LasoTokens.CardRadius),
                ),
        ) {
            displayItems.forEachIndexed { index, item ->
                CategoryRow(
                    item = item,
                    onClick = { onCategoryClick(item.category) },
                )
                if (index < displayItems.lastIndex) {
                    // iOS: Divider().padding(.leading, 56)
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 56.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    )
                }
            }
        }
    }
}

@Composable
private fun CategoryRow(
    item: CategoryScoreUi,
    onClick: () -> Unit,
) {
    val color = item.category.accentColor
    val needsAttention = item.score < 70
    val scoreStatus = when {
        item.score >= 85 -> "On track"
        item.score >= 70 -> "Doing well"
        item.score >= 55 -> "Room to improve"
        item.score >= 40 -> "Needs work"
        else -> "Needs attention"
    }
    val statusColor = when {
        item.score >= 80 -> AccentGreen
        item.score >= 60 -> Color.Unspecified // default text color at 0.6f alpha
        item.score >= 40 -> item.category.accentColor
        else -> AccentRed
    }

    // iOS: HStack(spacing: 14) .padding(.horizontal, 16) .padding(.vertical, 12)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // iOS: Image(systemName: category.systemImageName).font(.title3).frame(width: 32)
        Icon(
            imageVector = item.category.icon,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = color,
        )

        // iOS: VStack(alignment: .leading, spacing: 2)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            // iOS: .body.weight(needsAttention ? .bold : .medium)
            Text(
                text = item.category.displayName,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (needsAttention) FontWeight.Bold else FontWeight.Medium,
            )
            // iOS: HStack { scoreStatus + insightCount }
            Text(
                text = scoreStatus,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = if (needsAttention) FontWeight.SemiBold else FontWeight.Normal,
                color = if (statusColor == Color.Unspecified) {
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                } else {
                    statusColor
                },
            )
        }

        // iOS: HealthScoreRing(size: 36, lineWidth: 4)
        HealthScoreRing(
            score = item.score,
            size = 36.dp,
            strokeWidth = 4.dp,
        )

        // iOS: chevron.right .caption.weight(.semibold) .tertiary
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
        )
    }
}

// ── 5. Needs Attention Section ───────────────────────────────────────────────
// iOS: metric icon in colored rounded rect + metric name + reason + red impact number

@Composable
private fun NeedsAttentionSection(
    items: List<AttentionUi>,
    onItemClick: (HealthMetric) -> Unit,
) {
    // iOS: VStack(alignment: .leading, spacing: 10) with background card
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colorScheme.surface,
                shape = RoundedCornerShape(16.dp),
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // iOS: .headline
        Text(
            text = "Needs Attention",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        items.take(3).forEach { item ->
            NeedsAttentionRow(
                item = item,
                onClick = { onItemClick(item.metric) },
            )
        }
    }
}

@Composable
private fun NeedsAttentionRow(
    item: AttentionUi,
    onClick: () -> Unit,
) {
    val categoryColor = item.metric.category.accentColor

    // iOS: HStack(spacing: 10) .padding(.vertical, 4)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // iOS: metric icon in colored rounded rect (DS.iconSize, DS.iconRadius)
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(
                    color = categoryColor.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(10.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = item.metric.category.icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = categoryColor,
            )
        }

        // iOS: VStack(alignment: .leading, spacing: 2) { name + reason }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            // iOS: .subheadline.weight(.semibold)
            Text(
                text = item.metric.displayName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            // iOS: .caption, .secondary, lineLimit: 2
            Text(
                text = item.summary,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 2,
            )
        }

        // iOS: impact number — .subheadline.weight(.bold).monospacedDigit(), .red
        Text(
            text = item.impact.toString(),
            style = MaterialTheme.typography.bodyMedium.copy(
                fontFamily = FontFamily.Monospace,
            ),
            fontWeight = FontWeight.Bold,
            color = AccentRed,
        )
    }
}

// ── 6. Correlations Section ──────────────────────────────────────────────────
// iOS: "Connections" heading + "See all" link, max 2 cards with metricA→arrow→metricB icons

@Composable
private fun CorrelationsSection(
    items: List<CorrelationUi>,
    onSeeAllClick: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // iOS: HStack { "Connections" .headline + Spacer + "See all" button }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Connections",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            // iOS: HStack(spacing: 4) { "See all" + chevron } .tint
            Row(
                modifier = Modifier
                    .clickable(onClick = onSeeAllClick)
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = "See all",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary,
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }

        // iOS: ForEach(correlations.prefix(2))
        items.take(2).forEach { item ->
            CorrelationCard(item = item)
        }
    }
}

@Composable
private fun CorrelationCard(item: CorrelationUi) {
    val colorA = item.metricA.category.accentColor
    val colorB = item.metricB.category.accentColor

    // iOS: HStack(spacing: 10) { metricA icon → arrow → metricB icon + text }
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // MetricA icon in circle — iOS: c.metricA.systemImageName in c.metricA.category.color circle
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .background(
                        color = colorA.copy(alpha = 0.12f),
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = item.metricA.category.icon,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = colorA,
                )
            }

            // iOS: arrow.right .caption2 .tertiary
            Icon(
                imageVector = Icons.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )

            // MetricB icon in circle — iOS: c.metricB.systemImageName in c.metricB.category.color circle
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .background(
                        color = colorB.copy(alpha = 0.12f),
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = item.metricB.category.icon,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = colorB,
                )
            }

            // iOS: VStack(alignment: .leading, spacing: 2) { effectSummary + strengthLabel }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // iOS: .caption, .primary
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.labelMedium,
                    maxLines = 2,
                )
                // iOS: .caption2.weight(.semibold), .purple
                Text(
                    text = item.summary,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF9C27B0), // purple
                )
            }
        }
    }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

private fun formatDataPoints(count: Int): String {
    return when {
        count >= 10_000 -> "${count / 1000}k"
        count >= 1_000 -> String.format("%.1fk", count / 1000.0)
        else -> count.toString()
    }
}
