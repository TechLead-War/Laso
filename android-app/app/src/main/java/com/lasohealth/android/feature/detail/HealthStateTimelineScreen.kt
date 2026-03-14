package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.HealthStateEntryUi
import com.lasohealth.android.core.model.HealthStateTimelineUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.CategoryMindfulness
import com.lasohealth.android.ui.theme.CategorySleep

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthStateTimelineScreen(
    state: HealthStateTimelineUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Health States",
                        fontWeight = FontWeight.Bold,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Current State Card
            item {
                CurrentStateCard(
                    currentState = state.currentState,
                    stateDuration = state.stateDuration,
                )
            }

            // 2. Timeline
            if (state.states.isNotEmpty()) {
                item {
                    SectionHeading(title = "Timeline")
                }

                itemsIndexed(state.states) { index, entry ->
                    TimelineEntry(
                        entry = entry,
                        isLast = index == state.states.lastIndex,
                    )
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Current State Card

@Composable
private fun CurrentStateCard(
    currentState: String,
    stateDuration: String,
) {
    val stateColor = parseStateColor(currentState)

    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = stateColor,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Colored indicator
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(stateColor),
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = currentState,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stateDuration,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// endregion

// region 2. Timeline Entry

@Composable
private fun TimelineEntry(
    entry: HealthStateEntryUi,
    isLast: Boolean,
) {
    val entryColor = parseEntryColor(entry.color)

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Timeline indicator: dot + connecting line
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.width(20.dp),
        ) {
            // Dot
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(entryColor),
            )

            // Connecting line (not for last item)
            if (!isLast) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(48.dp)
                        .background(
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f),
                        ),
                )
            }
        }

        // Entry content
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = entry.label,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = entry.startDate,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = entry.duration,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )

            if (!isLast) {
                Spacer(modifier = Modifier.height(12.dp))
            }
        }
    }
}

// endregion

// region Helpers

private fun parseStateColor(state: String): Color {
    val lower = state.lowercase()
    return when {
        "optimal" in lower || "thriving" in lower || "peak" in lower -> AccentGreen
        "recovered" in lower || "good" in lower || "balanced" in lower -> AccentBlue
        "fatigued" in lower || "strained" in lower || "tired" in lower -> AccentOrange
        "stressed" in lower || "depleted" in lower || "poor" in lower -> AccentRed
        "resting" in lower || "sleeping" in lower -> CategorySleep
        "recovering" in lower -> AccentYellow
        "active" in lower -> CategoryMindfulness
        else -> AccentBlue
    }
}

private fun parseEntryColor(colorName: String): Color {
    val lower = colorName.lowercase()
    return when {
        "green" in lower -> AccentGreen
        "red" in lower -> AccentRed
        "orange" in lower -> AccentOrange
        "yellow" in lower -> AccentYellow
        "blue" in lower -> AccentBlue
        "purple" in lower || "violet" in lower -> CategoryMindfulness
        "indigo" in lower -> CategorySleep
        else -> AccentBlue
    }
}

// endregion
