package com.lasohealth.android.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingFlat
import androidx.compose.material.icons.automirrored.filled.TrendingUp
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
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentRed

enum class TrendDirection {
    IMPROVING, STABLE, DECLINING
}

@Composable
fun TrendBadge(
    direction: TrendDirection,
    changeText: String? = null,
) {
    val color: Color = when (direction) {
        TrendDirection.IMPROVING -> AccentGreen
        TrendDirection.STABLE -> MaterialTheme.colorScheme.onSurfaceVariant
        TrendDirection.DECLINING -> AccentRed
    }

    val icon: ImageVector = when (direction) {
        TrendDirection.IMPROVING -> Icons.AutoMirrored.Filled.TrendingUp
        TrendDirection.STABLE -> Icons.AutoMirrored.Filled.TrendingFlat
        TrendDirection.DECLINING -> Icons.AutoMirrored.Filled.TrendingDown
    }

    val label = changeText ?: when (direction) {
        TrendDirection.IMPROVING -> "Improving"
        TrendDirection.STABLE -> "Stable"
        TrendDirection.DECLINING -> "Declining"
    }

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(color.copy(alpha = LasoTokens.BadgeBgOpacity))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = direction.name,
            tint = color,
            modifier = Modifier.size(14.dp),
        )
        Spacer(modifier = Modifier.width(3.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = color,
        )
    }
}
