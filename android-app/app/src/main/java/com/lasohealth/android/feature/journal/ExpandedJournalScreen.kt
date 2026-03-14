package com.lasohealth.android.feature.journal

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale

// -- UI Models --

private data class JournalEntryUi(
    val date: LocalDate,
    val moodEmoji: String,
    val moodLabel: String,
    val energyLevel: Int,
    val notes: String,
    val tags: List<String>,
)

private data class CalendarDay(
    val date: LocalDate,
    val dayLetter: String,
    val dayNumber: String,
    val hasEntry: Boolean,
    val isToday: Boolean,
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ExpandedJournalScreen(navController: NavHostController) {
    // Sample data - in production this would come from a ViewModel
    val today = LocalDate.now()
    val sampleEntries = remember {
        listOf(
            JournalEntryUi(
                date = today,
                moodEmoji = "\uD83D\uDE04",
                moodLabel = "Great",
                energyLevel = 8,
                notes = "Had a great morning workout. Felt energized all day and slept well last night.",
                tags = listOf("Exercise", "Sleep"),
            ),
            JournalEntryUi(
                date = today.minusDays(1),
                moodEmoji = "\uD83D\uDE42",
                moodLabel = "Good",
                energyLevel = 6,
                notes = "Busy day at work but managed to take a lunch walk.",
                tags = listOf("Work", "Exercise"),
            ),
            JournalEntryUi(
                date = today.minusDays(3),
                moodEmoji = "\uD83D\uDE10",
                moodLabel = "Okay",
                energyLevel = 4,
                notes = "Didn't sleep well. Feeling a bit stressed about deadlines.",
                tags = listOf("Stress", "Sleep"),
            ),
        )
    }

    // Build calendar strip for last 7 days
    val calendarDays = remember {
        (6 downTo 0).map { offset ->
            val date = today.minusDays(offset.toLong())
            CalendarDay(
                date = date,
                dayLetter = date.dayOfWeek.getDisplayName(TextStyle.NARROW, Locale.getDefault()),
                dayNumber = date.dayOfMonth.toString(),
                hasEntry = sampleEntries.any { it.date == date },
                isToday = date == today,
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Journal",
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
        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    // Navigate to JournalEntryScreen
                },
                containerColor = AccentBlue,
                contentColor = androidx.compose.ui.graphics.Color.White,
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "New Entry",
                )
            }
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { innerPadding ->
        if (sampleEntries.isEmpty()) {
            // Empty state
            EmptyJournalState(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
            ) {
                // 1. Calendar strip
                item {
                    CalendarStrip(days = calendarDays)
                }

                // 2. Journal entries
                items(sampleEntries) { entry ->
                    JournalEntryCard(
                        entry = entry,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }

                // Bottom spacer for FAB
                item {
                    Spacer(modifier = Modifier.height(80.dp))
                }
            }
        }
    }
}

// region Calendar Strip

@Composable
private fun CalendarStrip(days: List<CalendarDay>) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            days.forEach { day ->
                CalendarDayCell(day = day)
            }
        }
    }
}

@Composable
private fun CalendarDayCell(day: CalendarDay) {
    val bgColor = when {
        day.isToday -> AccentBlue
        day.hasEntry -> AccentBlue.copy(alpha = 0.08f)
        else -> androidx.compose.ui.graphics.Color.Transparent
    }
    val textColor = when {
        day.isToday -> androidx.compose.ui.graphics.Color.White
        else -> MaterialTheme.colorScheme.onSurface
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        // Day letter
        Text(
            text = day.dayLetter,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )

        // Day number circle
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(bgColor),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = day.dayNumber,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                color = textColor,
            )
        }

        // Entry dot indicator
        if (day.hasEntry && !day.isToday) {
            Box(
                modifier = Modifier
                    .size(4.dp)
                    .clip(CircleShape)
                    .background(AccentBlue),
            )
        } else {
            Spacer(modifier = Modifier.size(4.dp))
        }
    }
}

// endregion

// region Journal Entry Card

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun JournalEntryCard(
    entry: JournalEntryUi,
    modifier: Modifier = Modifier,
) {
    val dateFormatter = DateTimeFormatter.ofPattern("EEEE, MMM d")

    LasoCard(modifier = modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // Top row: date + mood emoji
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = entry.date.format(dateFormatter),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = entry.moodEmoji,
                        fontSize = 20.sp,
                    )
                    Text(
                        text = entry.moodLabel,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }

            // Energy level badge
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                ) {
                    Text(
                        text = "Energy: ${entry.energyLevel}/10",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = AccentGreen,
                    )
                }
            }

            // Notes preview (2 lines max)
            if (entry.notes.isNotEmpty()) {
                Text(
                    text = entry.notes,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            // Tags as chips
            if (entry.tags.isNotEmpty()) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    entry.tags.forEach { tag ->
                        SuggestionChip(
                            onClick = { },
                            label = {
                                Text(
                                    text = tag,
                                    style = MaterialTheme.typography.labelSmall,
                                )
                            },
                            colors = SuggestionChipDefaults.suggestionChipColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant,
                            ),
                            border = SuggestionChipDefaults.suggestionChipBorder(
                                borderColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                                enabled = true,
                            ),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region Empty State

@Composable
private fun EmptyJournalState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "\uD83D\uDCD3",
            fontSize = 56.sp,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "No Journal Entries Yet",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Start tracking your mood, energy, and daily notes to discover patterns in your health.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

// endregion
