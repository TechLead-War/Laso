package com.lasohealth.android.core.design

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoGraph
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.automirrored.filled.ShowChart
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentYellow

private enum class ConfidenceTier(
    val label: String,
    val color: Color,
    val icon: ImageVector,
    val filledDots: Int,
    val description: String,
) {
    STARTER(
        label = "Starter",
        color = Color(0xFF8E8E93),
        icon = Icons.Default.Science,
        filledDots = 0,
        description = "0-6 days of data. Building your baseline.",
    ),
    BUILDING(
        label = "Building",
        color = AccentBlue,
        icon = Icons.AutoMirrored.Filled.ShowChart,
        filledDots = 1,
        description = "7-20 days. Early patterns emerging.",
    ),
    GROWING(
        label = "Growing",
        color = Color(0xFF7C3AED),
        icon = Icons.Default.Insights,
        filledDots = 2,
        description = "21-59 days. Trends are reliable.",
    ),
    MATURE(
        label = "Mature",
        color = AccentOrange,
        icon = Icons.Default.AutoGraph,
        filledDots = 3,
        description = "60-89 days. Full analysis active.",
    ),
    EXPERT(
        label = "Expert",
        color = AccentYellow,
        icon = Icons.Default.EmojiEvents,
        filledDots = 4,
        description = "90+ days. Maximum personalization.",
    ),
}

private fun tierForDays(days: Int): ConfidenceTier = when {
    days < 7 -> ConfidenceTier.STARTER
    days < 21 -> ConfidenceTier.BUILDING
    days < 60 -> ConfidenceTier.GROWING
    days < 90 -> ConfidenceTier.MATURE
    else -> ConfidenceTier.EXPERT
}

@Composable
fun DataConfidenceBadge(daysOfData: Int) {
    val tier = tierForDays(daysOfData)
    var expanded by remember { mutableStateOf(false) }

    Column {
        // Compact pill
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(tier.color.copy(alpha = LasoTokens.BadgeBgOpacity))
                .clickable { expanded = !expanded }
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = tier.icon,
                contentDescription = tier.label,
                tint = tier.color,
                modifier = Modifier.size(14.dp),
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = tier.label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = tier.color,
            )
            Spacer(modifier = Modifier.width(6.dp))
            // Progress dots
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                for (i in 0 until 4) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(
                                if (i < tier.filledDots)
                                    tier.color
                                else
                                    tier.color.copy(alpha = 0.2f)
                            ),
                    )
                }
            }
        }

        // Expandable timeline detail
        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(
                animationSpec = spring(
                    dampingRatio = 0.8f,
                    stiffness = 400f,
                ),
            ),
            exit = shrinkVertically(
                animationSpec = spring(
                    dampingRatio = 0.8f,
                    stiffness = 400f,
                ),
            ),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .clip(RoundedCornerShape(LasoTokens.CardRadius))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                    .padding(12.dp),
            ) {
                Text(
                    text = "$daysOfData days of data",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = tier.color,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = tier.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(8.dp))

                // Timeline milestones
                ConfidenceTier.entries.forEach { t ->
                    val isCurrent = t == tier
                    val isPast = t.ordinal < tier.ordinal
                    Row(
                        modifier = Modifier.padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(
                                    when {
                                        isCurrent -> tier.color
                                        isPast -> tier.color.copy(alpha = 0.5f)
                                        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.15f)
                                    }
                                ),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = t.label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                            color = if (isCurrent || isPast)
                                MaterialTheme.colorScheme.onSurface
                            else
                                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                        )
                    }
                }
            }
        }
    }
}
