package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.Remove
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.CoachTargetUi
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.core.model.MetricChangeUi
import com.lasohealth.android.core.model.WeeklyReviewDetailUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeeklyReviewScreen(
    state: WeeklyReviewDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Weekly Review",
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
            // 1. Weekly Averages Hero
            item {
                WeeklyAveragesHero(state)
            }

            // 2. Highlights Section (best & worst)
            if (state.bestMetric != null || state.worstMetric != null) {
                item {
                    HighlightsSection(
                        bestMetric = state.bestMetric,
                        worstMetric = state.worstMetric,
                    )
                }
            }

            // 3. This Week's Wins (conditional)
            if (state.wins.isNotEmpty()) {
                item {
                    WinsSection(wins = state.wins)
                }
            }

            // 4. Key Discovery (conditional)
            if (state.topInsight != null) {
                item {
                    KeyDiscoverySection(insight = state.topInsight)
                }
            }

            // 5. Watch Out (conditional)
            if (state.watchOuts.isNotEmpty()) {
                item {
                    WatchOutSection(watchOuts = state.watchOuts)
                }
            }

            // 6. Progressive Coach (conditional)
            if (state.coachTarget != null) {
                item {
                    ProgressiveCoachSection(coach = state.coachTarget)
                }
            }

            // 7. Next Week Outlook
            item {
                NextWeekSection(message = state.nextWeekMessage)
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Weekly Averages Hero

@Composable
private fun WeeklyAveragesHero(state: WeeklyReviewDetailUiState) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Score ring
        HealthScoreRing(
            score = state.score,
            size = 120.dp,
            strokeWidth = 12.dp,
            label = "Score",
        )

        // Delta badge
        val deltaText = if (state.scoreDeltaFromLastWeek != null) {
            val prefix = if (state.scoreDeltaFromLastWeek >= 0) "+" else ""
            "$prefix${state.scoreDeltaFromLastWeek} from last week"
        } else {
            "First week \u2014 no comparison yet"
        }

        val deltaColor = when {
            state.scoreDeltaFromLastWeek == null -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            state.scoreDeltaFromLastWeek > 0 -> AccentGreen
            state.scoreDeltaFromLastWeek < 0 -> AccentRed
            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        }

        val deltaBgColor = when {
            state.scoreDeltaFromLastWeek == null -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
            state.scoreDeltaFromLastWeek > 0 -> AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity)
            state.scoreDeltaFromLastWeek < 0 -> AccentRed.copy(alpha = LasoTokens.BadgeBgOpacity)
            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)
        }

        Box(
            modifier = Modifier
                .background(
                    color = deltaBgColor,
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 12.dp, vertical = 6.dp),
        ) {
            Text(
                text = deltaText,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = deltaColor,
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(vertical = 4.dp),
            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
        )

        // 4-column grid: Score / Trend / Wins / Alerts
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            StatColumn(
                value = state.score.toString(),
                label = "Score",
            )
            StatColumn(
                value = state.trendDirection,
                label = "Trend",
                icon = {
                    val icon = when (state.trendDirection) {
                        "Up" -> Icons.Filled.ArrowUpward
                        "Down" -> Icons.Filled.ArrowDownward
                        else -> Icons.Filled.Remove
                    }
                    val tint = when (state.trendDirection) {
                        "Up" -> AccentGreen
                        "Down" -> AccentRed
                        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    }
                    Icon(
                        imageVector = icon,
                        contentDescription = state.trendDirection,
                        modifier = Modifier.size(16.dp),
                        tint = tint,
                    )
                },
            )
            StatColumn(
                value = state.winCount.toString(),
                label = "Wins",
            )
            StatColumn(
                value = state.alertCount.toString(),
                label = "Alerts",
            )
        }
    }
}

@Composable
private fun StatColumn(
    value: String,
    label: String,
    icon: (@Composable () -> Unit)? = null,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (icon != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                icon()
                Text(
                    text = value,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }
        } else {
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// endregion

// region 2. Highlights Section

@Composable
private fun HighlightsSection(
    bestMetric: MetricChangeUi?,
    worstMetric: MetricChangeUi?,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Highlights")

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Min),
            horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
        ) {
            // Best Metric card
            if (bestMetric != null) {
                LasoCard(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    tint = AccentGreen,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.ArrowUpward,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = AccentGreen,
                            )
                            Text(
                                text = "Best Metric",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = AccentGreen,
                            )
                        }

                        Text(
                            text = bestMetric.metricName,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )

                        Box(
                            modifier = Modifier
                                .background(
                                    color = AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity),
                                    shape = RoundedCornerShape(12.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Text(
                                text = bestMetric.changePercent,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = AccentGreen,
                            )
                        }
                    }
                }
            }

            // Needs Attention card
            if (worstMetric != null) {
                LasoCard(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    tint = AccentOrange,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.ArrowDownward,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = AccentOrange,
                            )
                            Text(
                                text = "Needs Attention",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = AccentOrange,
                            )
                        }

                        Text(
                            text = worstMetric.metricName,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )

                        Box(
                            modifier = Modifier
                                .background(
                                    color = AccentRed.copy(alpha = LasoTokens.BadgeBgOpacity),
                                    shape = RoundedCornerShape(12.dp),
                                )
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Text(
                                text = worstMetric.changePercent,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = AccentRed,
                            )
                        }
                    }
                }
            }
        }
    }
}

// endregion

// region 3. This Week's Wins

@Composable
private fun WinsSection(wins: List<MetricChangeUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "\uD83C\uDFC6 This Week\u2019s Wins")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                wins.forEach { win ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.CheckCircle,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = AccentGreen,
                            )
                            Text(
                                text = win.metricName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f),
                            )
                            Box(
                                modifier = Modifier
                                    .background(
                                        color = AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity),
                                        shape = RoundedCornerShape(12.dp),
                                    )
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            ) {
                                Text(
                                    text = win.changePercent,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = AccentGreen,
                                )
                            }
                        }
                        if (win.nudge.isNotEmpty()) {
                            Text(
                                text = win.nudge,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                modifier = Modifier.padding(start = 30.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

// endregion

// region 4. Key Discovery

@Composable
private fun KeyDiscoverySection(insight: InsightUi) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "\uD83D\uDCA1 Key Discovery")

        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = AccentYellow,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = insight.title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = insight.detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
            }
        }
    }
}

// endregion

// region 5. Watch Out

@Composable
private fun WatchOutSection(watchOuts: List<MetricChangeUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "\u26A0\uFE0F Watch Out")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                watchOuts.forEach { item ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.ErrorOutline,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = AccentOrange,
                            )
                            Text(
                                text = item.metricName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f),
                            )
                            Box(
                                modifier = Modifier
                                    .background(
                                        color = AccentRed.copy(alpha = LasoTokens.BadgeBgOpacity),
                                        shape = RoundedCornerShape(12.dp),
                                    )
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            ) {
                                Text(
                                    text = item.changePercent,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = AccentRed,
                                )
                            }
                        }
                        if (item.nudge.isNotEmpty()) {
                            Text(
                                text = item.nudge,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                modifier = Modifier.padding(start = 30.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

// endregion

// region 6. Progressive Coach

@Composable
private fun ProgressiveCoachSection(coach: CoachTargetUi) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "\uD83C\uDFC3 Progressive Coach")

        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = AccentBlue,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // Current target
                CoachRow(label = "Current target", value = coach.currentTarget)

                // Current average
                CoachRow(label = "Current average", value = coach.currentAverage)

                // Status / adherence badge
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Status",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    )

                    val adherenceColor = when {
                        coach.adherenceLabel.contains("ahead", ignoreCase = true) ||
                            coach.adherenceLabel.contains("on track", ignoreCase = true) ||
                            coach.adherenceLabel.contains("met", ignoreCase = true) -> AccentGreen
                        coach.adherenceLabel.contains("behind", ignoreCase = true) ||
                            coach.adherenceLabel.contains("miss", ignoreCase = true) -> AccentRed
                        else -> AccentOrange
                    }

                    Box(
                        modifier = Modifier
                            .background(
                                color = adherenceColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                                shape = RoundedCornerShape(12.dp),
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = coach.adherenceLabel,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            color = adherenceColor,
                        )
                    }
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                )

                // Next week target
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Next week target",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = coach.nextWeekTarget,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = coach.nextWeekDelta,
                            style = MaterialTheme.typography.labelSmall,
                            color = AccentBlue,
                        )
                    }
                }

                // Coaching message
                Text(
                    text = coach.coachingMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
            }
        }
    }
}

@Composable
private fun CoachRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

// endregion

// region 7. Next Week Outlook

@Composable
private fun NextWeekSection(message: String) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "\u27A1\uFE0F Next Week")

        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = AccentBlue,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "Powered by your personal health model",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                )
            }
        }
    }
}

// endregion
