package com.lasohealth.android.feature.home

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.East
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasohealth.android.core.model.ForecastDirection
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.MetricForecastUi
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange

/**
 * Displays forward-looking metric forecasts with statistically guaranteed confidence intervals.
 * Shows predicted values, direction arrows, and confidence percentages.
 * iOS parity: PersonalHealthForecastCard.swift
 */
@Composable
fun PersonalHealthForecastCard(
    forecasts: List<MetricForecastUi>,
    onTapMetric: (HealthMetric) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (forecasts.isEmpty()) return

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(
            width = 0.5.dp,
            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Filled.ShowChart,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = Color(0xFF3478F6),
                    )
                    Text(
                        text = "YOUR FORECAST",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        letterSpacing = 1.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    )
                }
                Text(
                    text = "Next 7 days",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
            }

            // Forecast rows
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                forecasts.take(3).forEach { forecast ->
                    ForecastRow(
                        forecast = forecast,
                        onClick = { onTapMetric(forecast.metric) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ForecastRow(
    forecast: MetricForecastUi,
    onClick: () -> Unit,
) {
    val directionColor = when {
        forecast.directionIcon == ForecastDirection.STABLE -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        forecast.isFavorable -> AccentGreen
        else -> AccentOrange
    }

    val directionVector: ImageVector = when (forecast.directionIcon) {
        ForecastDirection.UP -> Icons.Filled.NorthEast
        ForecastDirection.DOWN -> Icons.Filled.SouthEast
        ForecastDirection.STABLE -> Icons.Filled.East
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Metric icon badge
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(
                    color = directionColor.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(7.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = metricIcon(forecast.metric),
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = directionColor,
            )
        }

        // Metric name + range
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = forecast.metric.displayName,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = forecast.rangeDescription,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }

        // Direction + value + confidence
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = directionVector,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = directionColor,
                )
                Text(
                    text = forecast.predictedValueFormatted,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = directionColor,
                )
            }
            Text(
                text = "${forecast.confidencePercent}% conf",
                style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }
    }
}

/** Map metric to a Material icon for forecast rows. */
@Composable
private fun metricIcon(metric: HealthMetric): ImageVector {
    return when (metric) {
        HealthMetric.HEART_RATE, HealthMetric.RESTING_HEART_RATE -> Icons.Filled.Favorite
        HealthMetric.HEART_RATE_VARIABILITY -> Icons.Filled.MonitorHeart
        HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP, HealthMetric.SLEEP_REM -> Icons.Filled.Bedtime
        HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES -> Icons.Filled.DirectionsRun
        HealthMetric.VO2_MAX -> Icons.Filled.ShowChart
        else -> Icons.Filled.ShowChart
    }
}

