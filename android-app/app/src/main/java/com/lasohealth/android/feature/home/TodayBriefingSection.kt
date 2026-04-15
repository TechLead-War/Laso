package com.lasohealth.android.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.IntelligenceCardUi
import com.lasohealth.android.core.model.IntelligenceSeverity

/**
 * Horizontal scroll strip of intelligence cards showing non-obvious health findings
 * surfaced by the on-device ML engine. Each card is a compact, information-dense
 * tile showing a single predictive or analytical finding.
 * iOS parity: TodayBriefingView.swift
 */
@Composable
fun TodayBriefingSection(
    cards: List<IntelligenceCardUi>,
    modifier: Modifier = Modifier,
) {
    if (cards.isEmpty()) return

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        // Section header: "Body Intelligence"
        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.Psychology,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = "BODY INTELLIGENCE",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = LasoTokens.LabelLetterSpacing,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }

        // Horizontal scroll of briefing cards
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(start = 16.dp, end = 40.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            cards.forEach { card ->
                BriefingCard(card = card)
            }
        }
    }
}

@Composable
private fun BriefingCard(card: IntelligenceCardUi) {
    val accent = card.accentColor.color
    val isDark = isSystemInDarkTheme()

    val severityDotColor = when (card.severity) {
        IntelligenceSeverity.CRITICAL -> Color(0xFFCC4B4C)
        IntelligenceSeverity.WARNING -> Color(0xFFD16C37)
        IntelligenceSeverity.NOTABLE -> Color(0xFFC4972F)
        IntelligenceSeverity.INFO -> Color(0xFF4F8A62)
    }

    Column(
        modifier = Modifier
            .width(220.dp)
            .shadow(
                elevation = 6.dp,
                shape = RoundedCornerShape(LasoTokens.CardRadius),
                ambientColor = Color.Black.copy(alpha = 0.04f),
                spotColor = Color.Black.copy(alpha = 0.04f),
            )
            .clip(RoundedCornerShape(LasoTokens.CardRadius))
            .background(
                color = accent.copy(alpha = LasoTokens.TintedBgOpacity),
            ),
    ) {
        // Accent bar at top (3dp)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(3.dp)
                .background(accent),
        )

        Column(
            modifier = Modifier
                .padding(LasoTokens.CardPadding)
                .height(120.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // Label
                Text(
                    text = card.label,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )

                // Headline
                Text(
                    text = card.headline,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )

                // Detail
                Text(
                    text = card.detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            // Bottom row: confidence pill + severity dot
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Confidence badge
                Box(
                    modifier = Modifier
                        .background(
                            color = accent.copy(alpha = LasoTokens.BadgeBgOpacity),
                            shape = RoundedCornerShape(20.dp),
                        )
                        .padding(horizontal = LasoTokens.BadgeH, vertical = LasoTokens.BadgeV),
                ) {
                    Text(
                        text = "${card.confidencePercent}% conf",
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontFamily = FontFamily.Monospace,
                        ),
                        color = accent,
                    )
                }

                // Severity dot
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .background(severityDotColor, CircleShape),
                )
            }
        }
    }
}
