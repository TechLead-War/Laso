package com.lasohealth.android.feature.journal

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.CategoryMindfulness

// -- UI Models --

private data class MoodDay(
    val dayLabel: String,
    val emoji: String,
)

private data class EnergyDay(
    val dayLabel: String,
    val level: Int, // 1-10
)

private data class TagUsage(
    val tag: String,
    val count: Int,
)

private data class JournalInsight(
    val title: String,
    val description: String,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JournalInsightsScreen(navController: NavHostController) {
    // Sample data - in production this would come from a ViewModel
    val hasSufficientData = remember { true } // Toggle for empty state

    val moodTrend = remember {
        listOf(
            MoodDay("M", "\uD83D\uDE04"),
            MoodDay("T", "\uD83D\uDE42"),
            MoodDay("W", "\uD83D\uDE42"),
            MoodDay("T", "\uD83D\uDE10"),
            MoodDay("F", "\uD83D\uDE04"),
            MoodDay("S", "\uD83D\uDE04"),
            MoodDay("S", "\uD83D\uDE42"),
        )
    }

    val energyData = remember {
        listOf(
            EnergyDay("M", 8),
            EnergyDay("T", 6),
            EnergyDay("W", 7),
            EnergyDay("T", 4),
            EnergyDay("F", 9),
            EnergyDay("S", 7),
            EnergyDay("S", 6),
        )
    }

    val commonTags = remember {
        listOf(
            TagUsage("Exercise", 12),
            TagUsage("Sleep", 10),
            TagUsage("Stress", 8),
            TagUsage("Work", 7),
            TagUsage("Social", 5),
        )
    }

    val insights = remember {
        listOf(
            JournalInsight(
                title = "Exercise boosts your mood",
                description = "Days with exercise tags show 40% more 'Great' mood entries compared to days without.",
            ),
            JournalInsight(
                title = "Sleep quality matters",
                description = "Your energy level is 2.3 points higher on days following good sleep entries.",
            ),
            JournalInsight(
                title = "Weekend recovery pattern",
                description = "Your mood consistently improves on Fridays and Saturdays, suggesting weekday stress accumulation.",
            ),
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Journal Insights",
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
        containerColor = MaterialTheme.colorScheme.background,
    ) { innerPadding ->
        if (!hasSufficientData) {
            // Empty state
            InsufficientDataState(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
            ) {
                // 1. Mood Trend Section
                item {
                    MoodTrendSection(moodDays = moodTrend)
                }

                // 2. Energy Pattern Section
                item {
                    EnergyPatternSection(energyDays = energyData)
                }

                // 3. Common Tags Section
                item {
                    CommonTagsSection(tags = commonTags)
                }

                // 4. Insight Cards
                item {
                    SectionHeading(title = "Patterns & Observations")
                }

                items(insights) { insight ->
                    InsightCard(insight = insight)
                }

                // Bottom spacer
                item {
                    Spacer(modifier = Modifier.height(80.dp))
                }
            }
        }
    }
}

// region 1. Mood Trend

@Composable
private fun MoodTrendSection(moodDays: List<MoodDay>) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Mood Trend", trailing = "7 days")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Emoji row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    moodDays.forEach { day ->
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Text(
                                text = day.emoji,
                                fontSize = 24.sp,
                            )
                            Text(
                                text = day.dayLabel,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            )
                        }
                    }
                }

                // Trend summary
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.TrendingUp,
                        contentDescription = null,
                        tint = AccentGreen,
                        modifier = Modifier.size(16.dp),
                    )
                    Text(
                        text = "Mood trending upward this week",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = AccentGreen,
                    )
                }
            }
        }
    }
}

// endregion

// region 2. Energy Pattern

@Composable
private fun EnergyPatternSection(energyDays: List<EnergyDay>) {
    val maxLevel = 10
    val barMaxHeight = 80.dp

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Energy Pattern", trailing = "7 days")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom,
            ) {
                energyDays.forEach { day ->
                    val fraction = day.level.toFloat() / maxLevel
                    val barHeight = barMaxHeight * fraction
                    val barColor = when {
                        day.level >= 7 -> AccentGreen
                        day.level >= 4 -> AccentYellow
                        else -> AccentRed
                    }

                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        // Value label
                        Text(
                            text = day.level.toString(),
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )

                        // Bar
                        Box(
                            modifier = Modifier
                                .width(24.dp)
                                .height(barHeight)
                                .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                                .background(barColor),
                        )

                        // Day label
                        Text(
                            text = day.dayLabel,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 3. Common Tags

@Composable
private fun CommonTagsSection(tags: List<TagUsage>) {
    val maxCount = tags.maxOfOrNull { it.count } ?: 1

    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Most Used Tags")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                tags.forEach { tagUsage ->
                    val fraction = tagUsage.count.toFloat() / maxCount

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        // Tag icon
                        Icon(
                            imageVector = Icons.Default.Tag,
                            contentDescription = null,
                            tint = AccentBlue,
                            modifier = Modifier.size(16.dp),
                        )

                        Spacer(modifier = Modifier.width(8.dp))

                        // Tag name
                        Text(
                            text = tagUsage.tag,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.width(72.dp),
                        )

                        Spacer(modifier = Modifier.width(8.dp))

                        // Progress bar
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(8.dp),
                        ) {
                            // Track
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(8.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)),
                            )
                            // Fill
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(fraction)
                                    .height(8.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(AccentBlue),
                            )
                        }

                        Spacer(modifier = Modifier.width(8.dp))

                        // Count
                        Text(
                            text = "${tagUsage.count}x",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.SemiBold,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Insight Card

@Composable
private fun InsightCard(insight: JournalInsight) {
    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = CategoryMindfulness,
    ) {
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(CategoryMindfulness.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Lightbulb,
                    contentDescription = null,
                    tint = CategoryMindfulness,
                    modifier = Modifier.size(20.dp),
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = insight.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = insight.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
            }
        }
    }
}

// endregion

// region Empty State

@Composable
private fun InsufficientDataState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                modifier = Modifier.size(40.dp),
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "Insights Unlocking...",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Log 14+ days of journal entries to discover how your behaviors affect your health. The more you log, the more patterns we can find.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Progress hint icons
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            listOf("\uD83D\uDE04", "\uD83D\uDCAA", "\uD83D\uDE34", "\u2764\uFE0F", "\uD83C\uDFC3").forEach { emoji ->
                Text(
                    text = emoji,
                    fontSize = 24.sp,
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .padding(8.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Start logging to see connections",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
        )
    }
}

// endregion
