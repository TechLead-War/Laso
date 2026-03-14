package com.lasohealth.android.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.HealthMetric

/**
 * Period summary section showing metric trends over selectable time ranges.
 * iOS: PeriodSummarySection.swift — segmented picker + metric change rows.
 */
data class MetricChangeItem(
    val metric: HealthMetric,
    val currentValue: String,
    val changePercent: Double,
    val nudge: String = "",
)

enum class TimePeriod(val label: String) {
    SEVEN_DAYS("7D"),
    THIRTY_DAYS("30D"),
    THREE_MONTHS("3M"),
    SIX_MONTHS("6M"),
}

@Composable
fun HomePeriodSummarySection(
    metricChanges: Map<TimePeriod, List<MetricChangeItem>>,
    onMetricClick: (HealthMetric) -> Unit,
    modifier: Modifier = Modifier,
) {
    var selectedPeriod by remember { mutableStateOf(TimePeriod.SEVEN_DAYS) }
    val changes = metricChanges[selectedPeriod] ?: emptyList()

    Column(
        modifier = modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionHeading(title = "Trends")

        // Period picker (iOS: segmented control)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TimePeriod.entries.forEach { period ->
                FilterChip(
                    selected = selectedPeriod == period,
                    onClick = { selectedPeriod = period },
                    label = {
                        Text(
                            text = period.label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (selectedPeriod == period) FontWeight.Bold else FontWeight.Medium,
                        )
                    },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        selectedLabelColor = MaterialTheme.colorScheme.primary,
                    ),
                )
            }
        }

        // Metric rows (max 4, sorted by absolute change, declined first)
        val sorted = changes
            .sortedWith(
                compareByDescending<MetricChangeItem> { it.changePercent < -2.0 }
                    .thenByDescending { kotlin.math.abs(it.changePercent) },
            )
            .take(4)

        sorted.forEach { item ->
            MetricChangeRow(
                item = item,
                onClick = { onMetricClick(item.metric) },
            )
        }
    }
}

@Composable
private fun MetricChangeRow(
    item: MetricChangeItem,
    onClick: () -> Unit,
) {
    val changeType = when {
        item.changePercent > 2.0 -> ChangeType.IMPROVED
        item.changePercent < -2.0 -> ChangeType.DECLINED
        else -> ChangeType.STABLE
    }

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Category color dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(
                        color = item.metric.category.accentColor,
                        shape = CircleShape,
                    ),
            )

            // Metric icon
            Icon(
                imageVector = item.metric.category.icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = item.metric.category.accentColor,
            )

            // Name + value + optional nudge
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = item.metric.displayName,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = item.currentValue,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
                if (item.nudge.isNotEmpty() && changeType == ChangeType.DECLINED) {
                    Text(
                        text = item.nudge,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFFFF9800),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            // Change % badge
            val badgeColor = when (changeType) {
                ChangeType.IMPROVED -> Color(0xFF4CAF50)
                ChangeType.DECLINED -> Color(0xFFEF5350)
                ChangeType.STABLE -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
            }
            val badgeIcon = when (changeType) {
                ChangeType.IMPROVED -> Icons.Filled.NorthEast
                ChangeType.DECLINED -> Icons.Filled.SouthEast
                ChangeType.STABLE -> Icons.Filled.ArrowForward
            }

            Box(
                modifier = Modifier
                    .background(
                        color = badgeColor.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Icon(
                        imageVector = badgeIcon,
                        contentDescription = null,
                        modifier = Modifier.size(10.dp),
                        tint = badgeColor,
                    )
                    Text(
                        text = "${kotlin.math.abs(item.changePercent).toInt()}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = badgeColor,
                    )
                }
            }

            // Chevron
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

private enum class ChangeType {
    IMPROVED,
    DECLINED,
    STABLE,
}
