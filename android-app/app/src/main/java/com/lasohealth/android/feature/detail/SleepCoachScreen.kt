package com.lasohealth.android.feature.detail

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.SleepCoachUiState
import com.lasohealth.android.core.model.SleepDayUi
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.CategorySleep

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SleepCoachScreen(
    state: SleepCoachUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Sleep Coach",
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
            // 1. Sleep Target Hero
            item {
                SleepTargetHero(baseHours = state.baseHoursNeeded)
            }

            // 2. Schedule Card
            item {
                ScheduleCard(
                    bedtime = state.recommendedBedtime,
                    wakeTime = state.recommendedWakeTime,
                )
            }

            // 3. Sleep Debt Card (conditional)
            if (state.sleepDebt > 0) {
                item {
                    SleepDebtCard(sleepDebt = state.sleepDebt)
                }
            }

            // 4. Consistency Card
            item {
                ConsistencyCard(score = state.consistencyScore)
            }

            // 5. Daily History
            if (state.dailyHistory.isNotEmpty()) {
                item {
                    DailyHistorySection(days = state.dailyHistory)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Sleep Target Hero

@Composable
private fun SleepTargetHero(baseHours: Double) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Moon emoji in indigo circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .background(
                    color = CategorySleep.copy(alpha = 0.12f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\uD83C\uDF19",
                fontSize = 40.sp,
            )
        }

        // "You need" label
        Text(
            text = "You need",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )

        // Base hours value
        Text(
            text = formatHours(baseHours),
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            color = CategorySleep,
        )

        // "hours per night" label
        Text(
            text = "hours per night",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

private fun formatHours(hours: Double): String {
    return if (hours == hours.toLong().toDouble()) {
        hours.toLong().toString()
    } else {
        String.format("%.1f", hours)
    }
}

// endregion

// region 2. Schedule Card

@Composable
private fun ScheduleCard(bedtime: String, wakeTime: String) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = CategorySleep,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = "Recommended Schedule",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Bedtime",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    )
                    Text(
                        text = bedtime,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outline.copy(alpha = 0.15f),
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Wake time",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    )
                    Text(
                        text = wakeTime,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Sleep Debt Card

@Composable
private fun SleepDebtCard(sleepDebt: Double) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = AccentOrange,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Sleep Debt",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = formatHours(sleepDebt),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                    color = AccentOrange,
                )

                Text(
                    text = "hours owed",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )

                Text(
                    text = "Accumulated from recent nights below your target.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// endregion

// region 4. Consistency Card

@Composable
private fun ConsistencyCard(score: Int) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "Sleep Consistency",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                HealthScoreRing(
                    score = score,
                    size = 80.dp,
                    strokeWidth = 8.dp,
                    label = "Consistency",
                )

                val description = when {
                    score >= 80 -> "Excellent consistency. Your sleep schedule is very stable."
                    score >= 60 -> "Good consistency. Minor variations in your sleep schedule."
                    else -> "Room to improve. Try keeping a more regular sleep schedule."
                }

                Text(
                    text = description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// endregion

// region 5. Daily History

@Composable
private fun DailyHistorySection(days: List<SleepDayUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "This Week")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                days.forEachIndexed { index, day ->
                    SleepDayRow(day = day)
                    if (index < days.lastIndex) {
                        HorizontalDivider(
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SleepDayRow(day: SleepDayUi) {
    val metTarget = day.actual >= day.target
    val barColor = if (metTarget) AccentGreen else AccentOrange

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Day name
        Text(
            text = day.day,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.width(40.dp),
        )

        Spacer(modifier = Modifier.width(10.dp))

        // Bar visualization
        Box(
            modifier = Modifier
                .weight(1f)
                .height(12.dp),
        ) {
            // Target reference bar (full width, subtle)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(12.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)),
            )

            // Actual bar (proportional to target)
            val fraction = if (day.target > 0) {
                (day.actual / day.target).toFloat().coerceIn(0f, 1.2f) / 1.2f
            } else {
                0f
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction)
                    .height(12.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(barColor),
            )
        }

        Spacer(modifier = Modifier.width(10.dp))

        // Hours text
        Text(
            text = "${formatHours(day.actual)}h",
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Bold,
            color = barColor,
            modifier = Modifier.width(36.dp),
            textAlign = TextAlign.End,
        )

        Text(
            text = " / ${formatHours(day.target)}h",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
        )
    }
}

// endregion
