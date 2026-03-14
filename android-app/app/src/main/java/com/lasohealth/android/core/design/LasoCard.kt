package com.lasohealth.android.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * iOS-matched card component.
 * Light mode: white bg, subtle border, light shadow.
 * Dark mode: elevated surface (#1C1C1E), slightly brighter border for visibility.
 * Tinted variant: subtle color wash on background + colored border.
 */
@Composable
fun LasoCard(
    modifier: Modifier = Modifier,
    tint: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val isDark = isSystemInDarkTheme()

    val containerColor = when {
        tint != null && isDark -> tint.copy(alpha = 0.10f)  // More visible tint in dark mode
        tint != null -> tint.copy(alpha = 0.04f)
        else -> MaterialTheme.colorScheme.surface
    }

    val borderColor = when {
        tint != null && isDark -> tint.copy(alpha = 0.25f)  // Stronger colored border in dark
        tint != null -> tint.copy(alpha = 0.10f)
        isDark -> MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)  // Visible border in dark
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
    }

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(LasoTokens.CardRadius),
        colors = CardDefaults.cardColors(containerColor = containerColor),
        border = BorderStroke(if (isDark) 0.5.dp else 1.dp, borderColor),
        elevation = CardDefaults.cardElevation(
            defaultElevation = if (isDark) 0.dp else 2.dp,  // iOS: no shadow in dark mode
        ),
    ) {
        Column(
            modifier = Modifier.padding(LasoTokens.CardPadding),
            content = content,
        )
    }
}
