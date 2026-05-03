package com.lasohealth.android.feature.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasohealth.android.ui.theme.AccentRed

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FocusSelectionStep(onContinue: (Set<HealthFocus>) -> Unit) {
    var selectedFocuses by remember { mutableStateOf(emptySet<HealthFocus>()) }

    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(64.dp)
                .background(
                    color = AccentRed,
                    shape = RoundedCornerShape(14.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "L",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "What matters most to you?",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Spacer(modifier = Modifier.height(10.dp))

        Text(
            text = "Pick your areas — those insights will be highlighted first.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp),
        )

        Spacer(modifier = Modifier.height(24.dp))

        FlowRow(
            modifier = Modifier.padding(horizontal = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            HealthFocus.entries.forEach { focus ->
                val isSelected = focus in selectedFocuses
                FocusChip(
                    focus = focus,
                    isSelected = isSelected,
                    onClick = {
                        selectedFocuses = if (isSelected) {
                            selectedFocuses - focus
                        } else {
                            selectedFocuses + focus
                        }
                    },
                )
            }
        }

        Spacer(modifier = Modifier.weight(2f))

        Button(
            onClick = { onContinue(selectedFocuses.toSet()) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            Text(
                text = "Continue",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
        }

        Spacer(modifier = Modifier.height(48.dp))
    }
}

@Composable
private fun FocusChip(
    focus: HealthFocus,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val chipShape = CircleShape
    val bgColor = if (isSelected) {
        focus.color.copy(alpha = 0.2f)
    } else {
        MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
    }
    val borderModifier = if (isSelected) {
        Modifier.border(width = 2.dp, color = focus.color, shape = chipShape)
    } else {
        Modifier
    }

    Row(
        modifier = Modifier
            .clip(chipShape)
            .then(borderModifier)
            .background(color = bgColor, shape = chipShape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = focus.icon,
            contentDescription = focus.displayName,
            modifier = Modifier.size(18.dp),
            tint = if (isSelected) focus.color else MaterialTheme.colorScheme.onBackground,
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = focus.displayName,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = if (isSelected) focus.color else MaterialTheme.colorScheme.onBackground,
        )
    }
}
