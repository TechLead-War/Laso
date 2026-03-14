package com.lasohealth.android.feature.reports

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.design.TrendBadge
import com.lasohealth.android.core.design.TrendDirection
import com.lasohealth.android.core.model.CategoryMonthUi
import com.lasohealth.android.core.model.DayHighlightUi
import com.lasohealth.android.core.model.MetricChangeMonthUi
import com.lasohealth.android.core.model.MonthlyReviewUiState
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MonthlyReviewScreen(
    state: MonthlyReviewUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "${state.monthName} ${state.year}",
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
            // 1. Hero — score ring + delta badge
            item {
                MonthlyHeroSection(
                    monthName = state.monthName,
                    year = state.year,
                    overallScore = state.overallScore,
                    scoreChange = state.scoreChangeFromPreviousMonth,
                )
            }

            // 2. Daily Scores — colored circles
            if (state.dailyScores.isNotEmpty()) {
                item {
                    DailyScoresSection(dailyScores = state.dailyScores)
                }
            }

            // 3. Highlights — best & worst day
            if (state.bestDay != null || state.worstDay != null) {
                item {
                    HighlightsSection(
                        bestDay = state.bestDay,
                        worstDay = state.worstDay,
                    )
                }
            }

            // 4. Category Breakdown
            if (state.categoryBreakdown.isNotEmpty()) {
                item {
                    CategoryBreakdownSection(categories = state.categoryBreakdown)
                }
            }

            // 5. Key Metrics
            if (state.topChangedMetrics.isNotEmpty()) {
                item {
                    KeyMetricsSection(metrics = state.topChangedMetrics)
                }
            }

            // 6. Insights Summary
            if (state.topInsights.isNotEmpty()) {
                item {
                    InsightsSummarySection(insights = state.topInsights)
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
private fun MonthlyHeroSection(
    monthName: String,
    year: Int,
    overallScore: Int,
    scoreChange: Int,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Month + year label
        Text(
            text = "$monthName $year",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )

        // Score ring
        HealthScoreRing(
            score = overallScore,
            size = 100.dp,
            strokeWidth = 10.dp,
            label = "Monthly Avg",
        )

        // Score change badge
        val deltaText = if (scoreChange >= 0) "+$scoreChange" else "$scoreChange"
        val deltaLabel = "$deltaText from last month"
        val deltaColor = when {
            scoreChange > 0 -> AccentGreen
            scoreChange < 0 -> AccentRed
            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        }
        val deltaBg = when {
            scoreChange > 0 -> AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity)
            scoreChange < 0 -> AccentRed.copy(alpha = LasoTokens.BadgeBgOpacity)
            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
        }

        Box(
            modifier = Modifier
                .background(
                    color = deltaBg,
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(
                text = deltaLabel,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = deltaColor,
            )
        }
    }
}

// endregion

// region 2. Daily Scores Section

@Composable
private fun DailyScoresSection(dailyScores: List<Int>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Daily Scores")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                contentPadding = PaddingValues(horizontal = 4.dp),
            ) {
                itemsIndexed(dailyScores) { index, score ->
                    DayCircle(dayNumber = index + 1, score = score)
                }
            }
        }
    }
}

@Composable
private fun DayCircle(dayNumber: Int, score: Int) {
    val color = LasoTokens.scoreColor(score)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(color = color, shape = CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = dayNumber.toString(),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                color = androidx.compose.ui.graphics.Color.White,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// endregion

// region 3. Highlights Section

@Composable
private fun HighlightsSection(
    bestDay: DayHighlightUi?,
    worstDay: DayHighlightUi?,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Highlights")

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
        ) {
            // Best day
            if (bestDay != null) {
                LasoCard(
                    modifier = Modifier.weight(1f),
                    tint = AccentGreen,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = "\u2B06\uFE0F Best Day",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = AccentGreen,
                        )

                        Text(
                            text = bestDay.score.toString(),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = AccentGreen,
                        )

                        Text(
                            text = bestDay.date,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )

                        Text(
                            text = bestDay.reason,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }

            // Worst day
            if (worstDay != null) {
                LasoCard(
                    modifier = Modifier.weight(1f),
                    tint = AccentOrange,
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = "\u2B07\uFE0F Worst Day",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = AccentOrange,
                        )

                        Text(
                            text = worstDay.score.toString(),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = AccentOrange,
                        )

                        Text(
                            text = worstDay.date,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )

                        Text(
                            text = worstDay.reason,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                            textAlign = TextAlign.Center,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Category Breakdown Section

@Composable
private fun CategoryBreakdownSection(categories: List<CategoryMonthUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Category Breakdown")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                categories.forEachIndexed { index, category ->
                    CategoryMonthRow(category)
                    if (index < categories.lastIndex) {
                        HorizontalDivider(
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryMonthRow(category: CategoryMonthUi) {
    val trendDirection = when (category.trend) {
        "Improving" -> TrendDirection.IMPROVING
        "Declining" -> TrendDirection.DECLINING
        else -> TrendDirection.STABLE
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Name + trend
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = category.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                TrendBadge(direction = trendDirection)
            }

            // Sparkline
            if (category.dailyScores.isNotEmpty()) {
                Sparkline(
                    values = category.dailyScores,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(24.dp),
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Score
        Text(
            text = category.averageScore.toString(),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = LasoTokens.scoreColor(category.averageScore),
        )
    }
}

@Composable
private fun Sparkline(
    values: List<Int>,
    modifier: Modifier = Modifier,
) {
    val lineColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)

    Canvas(modifier = modifier) {
        val count = values.size
        if (count < 2) return@Canvas

        val maxVal = values.max().coerceAtLeast(1).toFloat()
        val minVal = values.min().toFloat()
        val range = (maxVal - minVal).coerceAtLeast(1f)
        val w = size.width
        val h = size.height
        val padding = 2.dp.toPx()
        val usableHeight = h - padding * 2

        for (i in 0 until count - 1) {
            val x1 = w * i / (count - 1)
            val y1 = padding + usableHeight * (1f - (values[i] - minVal) / range)
            val x2 = w * (i + 1) / (count - 1)
            val y2 = padding + usableHeight * (1f - (values[i + 1] - minVal) / range)

            drawLine(
                color = lineColor,
                start = Offset(x1, y1),
                end = Offset(x2, y2),
                strokeWidth = 1.5.dp.toPx(),
                cap = StrokeCap.Round,
            )
        }
    }
}

// endregion

// region 5. Key Metrics Section

@Composable
private fun KeyMetricsSection(metrics: List<MetricChangeMonthUi>) {
    val items = metrics.take(5)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Key Metrics")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                items.forEachIndexed { index, metric ->
                    MetricChangeRow(metric)
                    if (index < items.lastIndex) {
                        HorizontalDivider(
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricChangeRow(metric: MetricChangeMonthUi) {
    val isUp = metric.direction == "up"
    val directionColor = if (isUp) AccentGreen else AccentRed
    val directionIcon = if (isUp) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = metric.name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(
                imageVector = directionIcon,
                contentDescription = metric.direction,
                modifier = Modifier.size(16.dp),
                tint = directionColor,
            )

            Box(
                modifier = Modifier
                    .background(
                        color = directionColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                        shape = RoundedCornerShape(12.dp),
                    )
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text = metric.changePercent,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = directionColor,
                )
            }
        }
    }
}

// endregion

// region 6. Insights Summary Section

@Composable
private fun InsightsSummarySection(insights: List<String>) {
    val items = insights.take(3)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Insights Summary")

        items.forEach { insight ->
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = "\uD83D\uDCA1",
                        fontSize = 18.sp,
                    )
                    Text(
                        text = insight,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

// endregion
