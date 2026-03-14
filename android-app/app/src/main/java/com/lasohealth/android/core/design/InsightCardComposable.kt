package com.lasohealth.android.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun InsightCardItem(
    metricName: String,
    metricIcon: ImageVector,
    metricColor: Color,
    actionText: String,
    severityLabel: String? = null,
    onClick: () -> Unit = {},
) {
    LasoCard(
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .defaultMinSize(minHeight = 72.dp)
                .padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Icon circle: 36x36dp with metric category color
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(metricColor),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = metricIcon,
                    contentDescription = metricName,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp),
                )
            }

            Spacer(modifier = Modifier.width(LasoTokens.ItemGap))

            // Content
            Column(modifier = Modifier.weight(1f)) {
                // Action text (first sentence only)
                Text(
                    text = actionText,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )

                Spacer(modifier = Modifier.height(4.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = metricName,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    if (severityLabel != null) {
                        Spacer(modifier = Modifier.width(8.dp))
                        val severity = when (severityLabel.lowercase()) {
                            "critical" -> InsightSeverity.CRITICAL
                            "warning" -> InsightSeverity.WARNING
                            else -> InsightSeverity.INFO
                        }
                        SeverityBadge(severity = severity)
                    }
                }
            }
        }
    }
}
