package com.lasohealth.android.feature.reports

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Share
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.design.TrendBadge
import com.lasohealth.android.core.design.TrendDirection
import com.lasohealth.android.core.model.AnnualReportUiState
import com.lasohealth.android.core.model.CategoryPerformanceUi
import com.lasohealth.android.core.model.DiscoveryUi
import com.lasohealth.android.core.model.MilestoneUi
import com.lasohealth.android.core.model.RecommendationUi
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen

private val MonthLabels = listOf("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnnualReportScreen(
    state: AnnualReportUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Year in Review",
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
                actions = {
                    IconButton(onClick = { /* share action */ }) {
                        Icon(
                            imageVector = Icons.Filled.Share,
                            contentDescription = "Share",
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
            // 1. Hero Section
            item {
                HeroSection(year = state.year)
            }

            // 2. Score Section — monthly bar chart
            item {
                ScoreSection(
                    monthlyScores = state.monthlyScores,
                    averageScore = state.averageScore,
                )
            }

            // 3. Stats Section — 2x2 grid
            item {
                StatsSection(
                    totalDaysTracked = state.totalDaysTracked,
                    insightsGenerated = state.insightsGenerated,
                    achievementsUnlocked = state.achievementsUnlocked,
                    longestStreak = state.longestStreak,
                )
            }

            // 4. Category Section
            if (state.categoryPerformance.isNotEmpty()) {
                item {
                    CategorySection(categories = state.categoryPerformance)
                }
            }

            // 5. Milestones Section
            if (state.milestones.isNotEmpty()) {
                item {
                    MilestonesSection(milestones = state.milestones)
                }
            }

            // 6. Discoveries Section
            if (state.topDiscoveries.isNotEmpty()) {
                item {
                    DiscoveriesSection(discoveries = state.topDiscoveries)
                }
            }

            // 7. Looking Ahead Section
            if (state.recommendations.isNotEmpty()) {
                item {
                    LookingAheadSection(recommendations = state.recommendations)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Hero Section

@Composable
private fun HeroSection(year: Int) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = year.toString(),
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
            color = AccentGreen,
        )

        Text(
            text = "Your Year in Health",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )

        Text(
            text = "A look back at your health journey",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
        )
    }
}

// endregion

// region 2. Score Section

@Composable
private fun ScoreSection(
    monthlyScores: List<Int>,
    averageScore: Int,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Monthly Scores")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Bar chart drawn with Canvas
                MonthlyBarChart(
                    scores = monthlyScores,
                    averageScore = averageScore,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                )

                // Month labels
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    MonthLabels.forEach { label ->
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }

                // Average badge
                Box(
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .background(
                            color = LasoTokens.scoreColor(averageScore)
                                .copy(alpha = LasoTokens.BadgeBgOpacity),
                            shape = RoundedCornerShape(20.dp),
                        )
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = "Average: $averageScore",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = LasoTokens.scoreColor(averageScore),
                    )
                }
            }
        }
    }
}

@Composable
private fun MonthlyBarChart(
    scores: List<Int>,
    averageScore: Int,
    modifier: Modifier = Modifier,
) {
    val barColors = scores.map { LasoTokens.scoreColor(it) }
    val avgLineColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)

    Canvas(modifier = modifier) {
        val barCount = scores.size.coerceAtMost(12)
        if (barCount == 0) return@Canvas

        val totalWidth = size.width
        val totalHeight = size.height
        val barSpacing = 6.dp.toPx()
        val barWidth = (totalWidth - barSpacing * (barCount + 1)) / barCount
        val maxScore = 100f
        val cornerRadius = 4.dp.toPx()

        // Draw bars
        for (i in 0 until barCount) {
            val score = scores[i].coerceIn(0, 100)
            val barHeight = (score / maxScore) * totalHeight * 0.9f
            val x = barSpacing + i * (barWidth + barSpacing)
            val y = totalHeight - barHeight

            drawRoundRect(
                color = barColors[i],
                topLeft = Offset(x, y),
                size = Size(barWidth, barHeight),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(cornerRadius, cornerRadius),
            )
        }

        // Draw average line
        val avgY = totalHeight - (averageScore.coerceIn(0, 100) / maxScore) * totalHeight * 0.9f
        drawLine(
            color = avgLineColor,
            start = Offset(0f, avgY),
            end = Offset(totalWidth, avgY),
            strokeWidth = 1.5.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(
                floatArrayOf(8.dp.toPx(), 4.dp.toPx()),
                0f,
            ),
        )
    }
}

// endregion

// region 3. Stats Section

@Composable
private fun StatsSection(
    totalDaysTracked: Int,
    insightsGenerated: Int,
    achievementsUnlocked: Int,
    longestStreak: Int,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Year at a Glance")

        // 2x2 grid — fixed height so it works inside LazyColumn
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp),
            horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
            userScrollEnabled = false,
        ) {
            item {
                StatCard(emoji = "\uD83D\uDCC5", value = totalDaysTracked.toString(), label = "Days Tracked")
            }
            item {
                StatCard(emoji = "\uD83D\uDCA1", value = insightsGenerated.toString(), label = "Insights Generated")
            }
            item {
                StatCard(emoji = "\uD83C\uDFC6", value = achievementsUnlocked.toString(), label = "Achievements Unlocked")
            }
            item {
                StatCard(emoji = "\uD83D\uDD25", value = "$longestStreak days", label = "Longest Streak")
            }
        }
    }
}

@Composable
private fun StatCard(
    emoji: String,
    value: String,
    label: String,
) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = emoji,
                fontSize = 28.sp,
            )
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
}

// endregion

// region 4. Category Section

@Composable
private fun CategorySection(categories: List<CategoryPerformanceUi>) {
    val sorted = categories.sortedByDescending { it.score }

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Category Performance")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                sorted.forEachIndexed { index, category ->
                    CategoryRow(category)
                    if (index < sorted.lastIndex) {
                        Spacer(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(0.5.dp)
                                .padding(horizontal = 4.dp)
                                .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.12f)),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryRow(category: CategoryPerformanceUi) {
    val trendDirection = when (category.trend) {
        "Improving" -> TrendDirection.IMPROVING
        "Declining" -> TrendDirection.DECLINING
        else -> TrendDirection.STABLE
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Emoji
        Text(
            text = category.emoji,
            fontSize = 22.sp,
        )

        Spacer(modifier = Modifier.width(10.dp))

        // Name
        Text(
            text = category.name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )

        // Score ring
        HealthScoreRing(
            score = category.score,
            size = 48.dp,
            strokeWidth = 5.dp,
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Trend badge
        TrendBadge(direction = trendDirection)
    }
}

// endregion

// region 5. Milestones Section

@Composable
private fun MilestonesSection(milestones: List<MilestoneUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Milestones")

        milestones.forEach { milestone ->
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = milestone.emoji,
                        fontSize = 28.sp,
                    )

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(
                            text = milestone.title,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = milestone.date,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 6. Discoveries Section

@Composable
private fun DiscoveriesSection(discoveries: List<DiscoveryUi>) {
    val items = discoveries.take(5)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Top Discoveries")

        items.forEach { discovery ->
            LasoCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = "\uD83D\uDCA1",
                        fontSize = 20.sp,
                    )

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = discovery.text,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            text = discovery.date,
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

// region 7. Looking Ahead Section

@Composable
private fun LookingAheadSection(recommendations: List<RecommendationUi>) {
    val items = recommendations.take(3)

    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        SectionHeading(title = "Looking Ahead")

        items.forEach { rec ->
            LasoCard(
                modifier = Modifier.fillMaxWidth(),
                tint = AccentBlue,
            ) {
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = rec.emoji,
                        fontSize = 24.sp,
                    )

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = rec.title,
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = rec.description,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                        )
                    }
                }
            }
        }
    }
}

// endregion
