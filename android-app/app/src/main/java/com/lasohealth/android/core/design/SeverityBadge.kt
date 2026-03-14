package com.lasohealth.android.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
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
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed

enum class InsightSeverity {
    INFO, WARNING, CRITICAL
}

@Composable
fun SeverityBadge(severity: InsightSeverity) {
    val color: Color = when (severity) {
        InsightSeverity.INFO -> AccentBlue
        InsightSeverity.WARNING -> AccentOrange
        InsightSeverity.CRITICAL -> AccentRed
    }

    val icon: ImageVector = when (severity) {
        InsightSeverity.INFO -> Icons.Default.Info
        InsightSeverity.WARNING -> Icons.Default.Warning
        InsightSeverity.CRITICAL -> Icons.Default.Error
    }

    val label = when (severity) {
        InsightSeverity.INFO -> "Info"
        InsightSeverity.WARNING -> "Warning"
        InsightSeverity.CRITICAL -> "Critical"
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
            contentDescription = severity.name,
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
