package com.lasohealth.android.core.design

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

object LasoTokens {
    val CardRadius = 16.dp
    val CardPadding = 14.dp
    val SectionGap = 20.dp
    val ItemGap = 12.dp
    val IconRadius = 10.dp
    const val TintedBgOpacity = 0.04f
    const val BadgeBgOpacity = 0.12f
    const val BorderOpacity = 0.10f
    val DividerHeight = 32.dp

    // iOS thresholds: 80+ green, 60-79 yellow, 40-59 orange, 0-39 red
    fun scoreColor(score: Int): Color = when {
        score >= 80 -> AccentGreen
        score >= 60 -> AccentYellow
        score >= 40 -> AccentOrange
        else -> AccentRed
    }

    fun scoreLabel(score: Int): String = when {
        score >= 80 -> "Optimal"
        score >= 60 -> "Good"
        score >= 40 -> "Fair"
        else -> "Poor"
    }

    fun scoreBrush(score: Int): Brush {
        val tint = scoreColor(score)
        return Brush.sweepGradient(
            listOf(tint.copy(alpha = 0.25f), tint, tint.copy(alpha = 0.35f)),
        )
    }
}
