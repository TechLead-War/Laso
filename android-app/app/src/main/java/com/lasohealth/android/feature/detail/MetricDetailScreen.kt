package com.lasohealth.android.feature.detail

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
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
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
import androidx.compose.ui.graphics.Color
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

            // 2. Time Range Selector
            item(key = "timeRange") {
                TimeRangeSelector(
                    options = timeRangeOptions,
                    selected = selectedTimeRange,
                    onSelect = { selectedTimeRange = it },
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }

            // 3. Stats Summary
            item(key = "stats") {
                MetricStatsSummaryCard(state = state)
            }

            // 4. Month-over-Month (conditional)
            if (state.monthOverMonthChange != null) {
                item(key = "monthOverMonth") {
                    MetricMonthOverMonthCard(change = state.monthOverMonthChange)
                }
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

// ── Stats Summary (3-column) ─────────────────────────────────────────────────

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
            MetricStatColumn(label = "Average", value = state.average, modifier = Modifier.weight(1f))
            VerticalDividerLine()
            MetricStatColumn(label = "Min", value = state.min, modifier = Modifier.weight(1f))
            VerticalDividerLine()
            MetricStatColumn(label = "Max", value = state.max, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun MetricStatColumn(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
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

// ── Month-over-Month ──────────────────────────────────────────────────────────

@Composable
private fun MetricMonthOverMonthCard(change: String) {
    val isPositive = !change.startsWith("-")
    val changeColor = if (isPositive) AccentGreen else AccentRed
    val arrow = if (isPositive) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = "vs Last Month",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(
                    imageVector = arrow,
                    contentDescription = if (isPositive) "Increased" else "Decreased",
                    tint = changeColor,
                    modifier = Modifier.size(24.dp),
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = change,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = changeColor,
                )
            }
        }
    }
}

// ── Historical Context ────────────────────────────────────────────────────────

@Composable
private fun MetricHistoricalContextSection(facts: List<String>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "From Your History")

        facts.forEach { fact ->
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = "\u23F0",
                        style = MaterialTheme.typography.bodyMedium,
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
