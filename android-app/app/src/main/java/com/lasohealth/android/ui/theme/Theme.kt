package com.lasohealth.android.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

// iOS-matched light scheme
private val LightColors = lightColorScheme(
    primary = AccentRed,
    secondary = AccentBlue,
    tertiary = AccentGreen,
    background = Color(0xFFF2F2F7),       // iOS systemGroupedBackground light
    surface = Color(0xFFFFFFFF),           // iOS .background (card bg) light
    surfaceVariant = Color(0xFFF2F2F7),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color(0xFF1C1C1E),     // iOS .primary text light
    onSurface = Color(0xFF1C1C1E),        // iOS .primary text light
    onSurfaceVariant = Color(0xFF8E8E93), // iOS .secondary text light
    outline = Color(0xFFC6C6C8),          // iOS separator
    outlineVariant = Color(0xFFE5E5EA),   // iOS .quaternary
    surfaceContainerHighest = Color(0xFFE5E5EA),
)

// iOS-matched dark scheme — proper contrast
private val DarkColors = darkColorScheme(
    primary = AccentRed,
    secondary = AccentBlue,
    tertiary = AccentGreen,
    background = Color(0xFF000000),        // iOS systemGroupedBackground dark (pure black)
    surface = Color(0xFF1C1C1E),           // iOS systemGray6 (card bg) dark
    surfaceVariant = Color(0xFF2C2C2E),    // iOS systemGray5
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color(0xFFFFFFFF),      // iOS .primary text dark
    onSurface = Color(0xFFFFFFFF),         // iOS .primary text dark (WHITE, full contrast)
    onSurfaceVariant = Color(0xFF8E8E93),  // iOS .secondary text dark (system gray)
    outline = Color(0xFF48484A),           // iOS separator dark
    outlineVariant = Color(0xFF38383A),    // iOS systemGray4
    surfaceContainerHighest = Color(0xFF3A3A3C),
)

@Composable
fun LasoTheme(content: @Composable () -> Unit) {
    val darkTheme = isSystemInDarkTheme()
    val colorScheme = if (darkTheme) DarkColors else LightColors

    // Match iOS: status bar adapts to theme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as? Activity)?.window ?: return@SideEffect
            window.statusBarColor = Color.Transparent.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content,
    )
}
