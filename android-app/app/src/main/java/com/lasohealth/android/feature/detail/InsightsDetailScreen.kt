package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.CategoryActivity
import com.lasohealth.android.ui.theme.CategoryBody
import com.lasohealth.android.ui.theme.CategoryHeart
import com.lasohealth.android.ui.theme.CategorySleep

private const val FILTER_ALL = "All"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InsightsDetailScreen(
    insights: List<InsightUi>,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    var selectedFilter by remember { mutableStateOf(FILTER_ALL) }

    // Build filter options dynamically from insight categories
    val filterOptions by remember(insights) {
        derivedStateOf {
            val categoryCounts = insights
                .groupBy { it.metric.category.shortName }
                .mapValues { it.value.size }
                .toSortedMap()

            buildList {
                add(FILTER_ALL to insights.size)
                categoryCounts.forEach { (name, count) ->
                    add(name to count)
                }
            }
        }
    }

    // Filter insights by selected category
    val filteredInsights by remember(insights, selectedFilter) {
        derivedStateOf {
            if (selectedFilter == FILTER_ALL) {
                insights
            } else {
                insights.filter { it.metric.category.shortName == selectedFilter }
            }
        }
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Insights",
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
            verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
        ) {
            // 1. Filter Chips (horizontal scrolling row)
            item(key = "filterChips") {
                InsightsFilterChips(
                    options = filterOptions,
                    selected = selectedFilter,
                    onSelect = { selectedFilter = it },
                )
            }

            if (filteredInsights.isNotEmpty()) {
                // 2. Insights List
                items(
                    items = filteredInsights,
                    key = { "${it.metric.name}_${it.title.hashCode()}" },
                ) { insight ->
                    InsightListItem(
                        insight = insight,
                        onClick = {
                            navController.navigate(
                                AppRoute.MetricDetail.createRoute(insight.metric),
                            )
                        },
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }
            } else {
                // 3. Empty State
                item(key = "emptyState") {
                    InsightsEmptyState(selectedFilter = selectedFilter)
                }
            }

            // Bottom spacer
            item(key = "bottomSpacer") {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// ── Filter Chips ──────────────────────────────────────────────────────────────

@Composable
private fun InsightsFilterChips(
    options: List<Pair<String, Int>>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { (label, count) ->
            val isSelected = label == selected
            val chipColor = filterChipAccentColor(label)

            FilterChip(
                selected = isSelected,
                onClick = { onSelect(label) },
                label = {
                    Text(
                        text = "$label ($count)",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = chipColor,
                    selectedLabelColor = androidx.compose.ui.graphics.Color.White,
                ),
            )
        }
    }
}

// ── Insight List Item ─────────────────────────────────────────────────────────

@Composable
private fun InsightListItem(
    insight: InsightUi,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LasoCard(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column {
            // Top row: category dot + metric display name
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(insight.metric.category.accentColor),
                )
                Text(
                    text = insight.metric.displayName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "View metric",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    modifier = Modifier.size(18.dp),
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Title
            Text(
                text = insight.title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(4.dp))

            // Detail (max 3 lines)
            Text(
                text = insight.detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 3,
            )
        }
    }
}

// ── Empty State ───────────────────────────────────────────────────────────────

@Composable
private fun InsightsEmptyState(selectedFilter: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 60.dp, bottom = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Filled.Search,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            modifier = Modifier.size(64.dp),
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "No insights yet",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = if (selectedFilter == FILTER_ALL) {
                "More data will unlock deeper insights over time."
            } else {
                "No ${selectedFilter.lowercase()} insights right now."
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 48.dp),
        )
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun filterChipAccentColor(label: String): androidx.compose.ui.graphics.Color {
    return when (label) {
        FILTER_ALL -> AccentBlue
        "Heart" -> CategoryHeart
        "Sleep" -> CategorySleep
        "Activity" -> CategoryActivity
        "Body" -> CategoryBody
        else -> AccentBlue
    }
}
