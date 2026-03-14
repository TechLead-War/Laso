package com.lasohealth.android.feature.detail

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.AchievementUi
import com.lasohealth.android.core.model.AchievementsUiState
import com.lasohealth.android.core.model.StreakUi
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AchievementsScreen(
    state: AchievementsUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Achievements",
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
        modifier = modifier,
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.padding(innerPadding),
            contentPadding = PaddingValues(vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Level Display
            item {
                LevelDisplay(state)
            }

            // 2. Streaks Section
            item {
                StreaksSection(state)
            }

            // 3. Stats Summary Row
            item {
                StatsSummaryRow(state)
            }

            // 4. Achievements Grid
            item {
                AchievementsGrid(state)
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Level Display

@Composable
private fun LevelDisplay(state: AchievementsUiState) {
    val animatedProgress by animateFloatAsState(
        targetValue = state.progressToNext,
        animationSpec = tween(durationMillis = 800),
        label = "levelProgress",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Large emoji in circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(
                    color = AccentGreen.copy(alpha = 0.12f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = state.levelEmoji,
                fontSize = 48.sp,
            )
        }

        // Level name
        Text(
            text = state.levelName,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        // Progress bar
        LinearProgressIndicator(
            progress = { animatedProgress },
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp)),
            color = AccentGreen,
            trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
        )

        // Days tracked + percent to next
        val percentToNext = (state.progressToNext * 100).toInt()
        Text(
            text = "${state.totalDaysTracked} days tracked \u00B7 $percentToNext% to next level",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// endregion

// region 2. Streaks Section

@Composable
private fun StreaksSection(state: AchievementsUiState) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Current Streaks")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                StreakRow(emoji = "\uD83C\uDFC3", name = "Activity", streak = state.streaks.activity)
                StreakDivider()
                StreakRow(emoji = "\uD83C\uDF19", name = "Sleep", streak = state.streaks.sleep)
                StreakDivider()
                StreakRow(emoji = "\u2764\uFE0F", name = "Recovery", streak = state.streaks.recovery)
                StreakDivider()
                StreakRow(emoji = "\u2705", name = "Check-In", streak = state.streaks.checkIn)
                StreakDivider()
                StreakRow(emoji = "\uD83D\uDD25", name = "Master", streak = state.streaks.master)
            }
        }
    }
}

@Composable
private fun StreakRow(emoji: String, name: String, streak: StreakUi) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = emoji,
            fontSize = 20.sp,
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )

        // Current streak
        Text(
            text = "${streak.current} day${if (streak.current != 1) "s" else ""}",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        // Hot streak indicator
        if (streak.current >= 7) {
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "\uD83D\uDD25",
                fontSize = 14.sp,
            )
        }

        // Vertical divider
        Box(
            modifier = Modifier
                .padding(horizontal = 10.dp)
                .width(1.dp)
                .height(20.dp)
                .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
        )

        // Best
        Text(
            text = "best: ${streak.best}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

@Composable
private fun StreakDivider() {
    HorizontalDivider(
        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
    )
}

// endregion

// region 3. Stats Summary Row

@Composable
private fun StatsSummaryRow(state: AchievementsUiState) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SummaryStat(
                value = state.totalDaysTracked.toString(),
                label = "Total Days",
                modifier = Modifier.weight(1f),
            )

            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(40.dp)
                    .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
            )

            SummaryStat(
                value = "${state.unlockedAchievements}",
                label = "Unlocked",
                modifier = Modifier.weight(1f),
            )

            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(40.dp)
                    .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)),
            )

            SummaryStat(
                value = "${state.longestStreak}",
                label = "Longest Streak",
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun SummaryStat(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
        )
    }
}

// endregion

// region 4. Achievements Grid

@Composable
private fun AchievementsGrid(state: AchievementsUiState) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(
            title = "Achievements",
            trailing = "${state.unlockedAchievements}/${state.totalAchievements}",
        )

        // Using a fixed-height grid inside LazyColumn
        // Calculate rows needed
        val rows = (state.achievements.size + 1) / 2
        val gridHeight = (rows * 180).dp // approximate card height per row

        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier
                .fillMaxWidth()
                .height(gridHeight),
            horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            userScrollEnabled = false,
        ) {
            items(state.achievements) { achievement ->
                AchievementCard(achievement)
            }
        }
    }
}

@Composable
private fun AchievementCard(achievement: AchievementUi) {
    LasoCard(
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (!achievement.isUnlocked) Modifier.alpha(0.5f) else Modifier,
                ),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            // Emoji (large)
            Text(
                text = achievement.emoji,
                fontSize = 36.sp,
            )

            // Title
            Text(
                text = achievement.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )

            // Description
            Text(
                text = achievement.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            // Unlock date or lock indicator
            if (achievement.isUnlocked && achievement.unlockDate != null) {
                Text(
                    text = achievement.unlockDate,
                    style = MaterialTheme.typography.labelSmall,
                    color = AccentGreen,
                    fontWeight = FontWeight.SemiBold,
                )
            } else if (!achievement.isUnlocked) {
                Text(
                    text = "\uD83D\uDD12 Locked",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                )
            }
        }
    }
}

// endregion
