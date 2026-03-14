package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.ExperimentalMaterial3Api
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
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.CategoryDetailUiState
import com.lasohealth.android.core.model.CategoryMetricRow
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

private val categoryTimeRangeOptions = listOf(30, 90, 180, 365)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryDetailScreen(
    state: CategoryDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    var selectedTimeRange by remember { mutableIntStateOf(30) }
    val categoryColor = state.category.accentColor

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.category.displayName,
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
            // 1. Category Score Ring (centered)
            item(key = "scoreRing") {
                CategoryScoreHeader(
                    score = state.score,
                    categoryName = state.category.displayName,
                    scoreContribution = state.scoreContribution,
                )
            }

            // 2. Time Range Selector
            item(key = "timeRange") {
                TimeRangeSelector(
                    options = categoryTimeRangeOptions,
                    selected = selectedTimeRange,
                    onSelect = { selectedTimeRange = it },
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }

            // 3. Historical Highlights (conditional)
            if (state.historicalHighlights.isNotEmpty()) {
                item(key = "historicalHighlights") {
                    CategoryHistoricalHighlightsSection(
                        highlights = state.historicalHighlights,
                    )
                }
            }

            // 4. Insights (conditional)
            if (state.insights.isNotEmpty()) {
                item(key = "insights") {
                    CategoryInsightsSection(
                        insights = state.insights,
                        categoryColor = categoryColor,
                    )
                }
            }

            // 5. Metrics List
            item(key = "metricsHeader") {
                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                    SectionHeading(
                        title = "Metrics",
                        trailing = "${state.metrics.size} active",
                    )
                }
            }

            itemsIndexed(
                items = state.metrics,
                key = { _, row -> row.metric.name },
            ) { _, row ->
                CategoryMetricRowItem(
                    row = row,
                    categoryColor = categoryColor,
                    onClick = {
                        navController.navigate(
                            AppRoute.MetricDetail.createRoute(row.metric),
                        )
                    },
                )
            }

            // Bottom spacer
            item(key = "bottomSpacer") {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// ── Score Header ──────────────────────────────────────────────────────────────

@Composable
private fun CategoryScoreHeader(
    score: Int,
    categoryName: String,
    scoreContribution: String,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HealthScoreRing(
            score = score,
            size = 120.dp,
            strokeWidth = 12.dp,
            label = categoryName,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = scoreContribution,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// ── Historical Highlights ─────────────────────────────────────────────────────

@Composable
private fun CategoryHistoricalHighlightsSection(highlights: List<String>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "From Your History")

        highlights.forEach { highlight ->
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
                        text = highlight,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// ── Insights ──────────────────────────────────────────────────────────────────

@Composable
private fun CategoryInsightsSection(
    insights: List<InsightUi>,
    categoryColor: Color,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Insights")

        insights.forEach { insight ->
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Column {
                    // Lightbulb icon
                    Text(
                        text = "\uD83D\uDCA1",
                        style = MaterialTheme.typography.bodyMedium,
                    )

                    Spacer(modifier = Modifier.height(6.dp))

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
                    )
                }
            }
        }
    }
}

// ── Metric Row ────────────────────────────────────────────────────────────────

@Composable
private fun CategoryMetricRowItem(
    row: CategoryMetricRow,
    categoryColor: Color,
    onClick: () -> Unit,
) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Category-colored dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(categoryColor),
            )

            Spacer(modifier = Modifier.width(12.dp))

            // Metric name
            Text(
                text = row.metric.displayName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )

            Spacer(modifier = Modifier.width(8.dp))

            // Current value
            Text(
                text = row.currentValue,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.width(8.dp))

            // Status label badge
            val statusColor = categoryMetricStatusColor(row.statusLabel)
            Text(
                text = row.statusLabel,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = statusColor,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(statusColor.copy(alpha = LasoTokens.BadgeBgOpacity))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            )

            Spacer(modifier = Modifier.width(4.dp))

            // Chevron
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "View details",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

@Composable
private fun categoryMetricStatusColor(statusLabel: String): Color {
    val lower = statusLabel.lowercase()
    return when {
        lower.contains("optimal") || lower.contains("good") || lower.contains("normal") -> AccentGreen
        lower.contains("fair") || lower.contains("elevated") -> AccentYellow
        lower.contains("high") || lower.contains("low") || lower.contains("poor") -> AccentRed
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    }
}
