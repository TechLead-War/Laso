package com.lasohealth.android.feature.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.NorthEast
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.AlertUi
import com.lasohealth.android.core.model.BodyInsightUi
import com.lasohealth.android.core.model.CorrelationUi
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.HomeUiState
import com.lasohealth.android.core.model.MetricTileUi
import com.lasohealth.android.core.model.WeeklyReviewUi
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentOrange
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun HomeScreen(
    state: HomeUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    // iOS: VStack(spacing: 0) with manual .padding(.top, X) per section
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(vertical = 16.dp),
    ) {
        // 1. Coach Greeting Header — .padding(.top, 12) in iOS
        item {
            CoachGreetingHeader(
                recoverySubtitle = state.recoveryLabel,
                streakDays = state.streakDays,
                onSettingsClick = { navController.navigate(AppRoute.Settings.route) },
            )
        }

        // Health Connect Setup (conditional)
        item {
            HealthConnectSetupCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp),
            )
        }

        // 2. Recovery Hero Card — immediately after greeting (iOS: no extra top padding)
        item {
            RecoveryHeroCard(
                score = state.score,
                recoveryStateLabel = state.recoveryStateLabel,
                scoreDelta = state.scoreDelta,
                dayClassification = state.dayClassification,
                onClick = { navController.navigate(AppRoute.ScoreGuide.route) },
            )
        }

        // 3. Today's Action Card — .padding(.top, 8)
        item {
            Spacer(modifier = Modifier.height(8.dp))
            TodaysActionCard(
                title = state.primaryAction.title,
                detail = state.primaryAction.detail,
                iconEmoji = state.primaryAction.iconEmoji,
                scoreColor = LasoTokens.scoreColor(state.score),
                onClick = { navController.navigate(AppRoute.InsightsDetail.route) },
            )
        }

        // 4. Alert Banners (conditional) — .padding(.top, 8)
        if (state.alerts.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(8.dp))
                AlertBanners(
                    alerts = state.alerts,
                    onClick = { navController.navigate(AppRoute.InsightsDetail.route) },
                )
            }
        }

        // 5. Metric Strip — .padding(.top, 12) (more breathing room)
        if (state.metrics.isNotEmpty()) {
            item {
                Spacer(modifier = Modifier.height(12.dp))
                MetricStrip(
                    metrics = state.metrics,
                    onMetricClick = { tile ->
                        val route = when (tile.label) {
                            "Vitality" -> AppRoute.VitalityDetail.route
                            "Sleep" -> AppRoute.SleepCoach.route
                            "Strain" -> AppRoute.StrainDetail.route
                            "Brain" -> AppRoute.BrainHealth.route
                            "Stress" -> AppRoute.StressMonitor.route
                            "HRV" -> AppRoute.MetricDetail.createRoute(HealthMetric.HEART_RATE_VARIABILITY)
                            else -> AppRoute.MetricDetail.createRoute(tile.metric)
                        }
                        navController.navigate(route)
                    },
                )
            }
        }

        // 6. Level Badge Card — .padding(.top, 8)
        item {
            Spacer(modifier = Modifier.height(8.dp))
            LevelBadgeCard(
                level = state.level,
                score = state.score,
                totalDaysTracked = state.totalDaysTracked,
                progressToNextLevel = state.progressToNextLevel,
                activityStreak = state.activityStreak,
                sleepStreak = state.sleepStreak,
                recoveryStreak = state.recoveryStreak,
                onClick = { navController.navigate(AppRoute.Achievements.route) },
            )
        }

        // 7. Body Insights Section (conditional) — .padding(.top, 8)
        if (state.bodyInsight != null) {
            item {
                Spacer(modifier = Modifier.height(8.dp))
                BodyInsightsSection(
                    bodyInsight = state.bodyInsight,
                    onClick = { navController.navigate(AppRoute.InsightsDetail.route) },
                )
            }
        }


        // 8. Weekly Review Card — .padding(.top, 8)
        item {
            Spacer(modifier = Modifier.height(8.dp))
            WeeklyReviewSection(
                weeklyReview = state.weeklyReview,
                onClick = { navController.navigate(AppRoute.WeeklyReview.route) },
            )
        }

        // 9. Last Updated Footer — .padding(.top, 8)
        item {
            Spacer(modifier = Modifier.height(8.dp))
            LastUpdatedFooter(lastUpdated = state.lastUpdated)
        }
    }
}

// region 1. Coach Greeting Header

@Composable
private fun CoachGreetingHeader(
    recoverySubtitle: String,
    streakDays: Int,
    onSettingsClick: () -> Unit,
) {
    val now = LocalTime.now()
    val timeGreeting = when {
        now.hour < 5 -> "Good Night"
        now.hour < 12 -> "Good Morning"
        now.hour < 17 -> "Good Afternoon"
        now.hour < 22 -> "Good Evening"
        else -> "Good Night"
    }

    // iOS: "EEEE, MMM d" (abbreviated month)
    val dateLabel = LocalDate.now().format(
        DateTimeFormatter.ofPattern("EEEE, MMM d", Locale.getDefault()),
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        // iOS: VStack(alignment: .leading, spacing: 2)
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            // iOS: .title2.weight(.bold)
            Text(
                text = timeGreeting,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onBackground,
            )

            // iOS: .subheadline, .secondary
            Text(
                text = recoverySubtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            )

            // iOS: Date + streak badge inline in HStack(spacing: 6) .padding(.top, 1)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.padding(top = 1.dp),
            ) {
                // iOS: .caption, .tertiary
                Text(
                    text = dateLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                )

                if (streakDays > 1) {
                    // iOS: .caption.weight(.bold).monospacedDigit() in Capsule
                    Box(
                        modifier = Modifier
                            .background(
                                color = AccentOrange.copy(alpha = LasoTokens.BadgeBgOpacity),
                                shape = RoundedCornerShape(20.dp),
                            )
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    ) {
                        Text(
                            text = "\uD83D\uDD25 ${streakDays}d streak",
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                            ),
                            fontWeight = FontWeight.Bold,
                            color = AccentOrange,
                        )
                    }
                }
            }
        }

        IconButton(onClick = onSettingsClick) {
            Icon(
                imageVector = Icons.Filled.Settings,
                contentDescription = "Settings",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion

// region 2. Recovery Hero Card

@Composable
private fun RecoveryHeroCard(
    score: Int,
    recoveryStateLabel: String,
    scoreDelta: Int?,
    dayClassification: String,
    onClick: () -> Unit,
) {
    val scoreColor = LasoTokens.scoreColor(score)
    val isDark = isSystemInDarkTheme()

    // iOS-matched gradient: scoreColor.opacity(0.28) -> scoreColor.opacity(0.10)
    val gradientBrush = remember(score, isDark) {
        Brush.linearGradient(
            colors = listOf(
                scoreColor.copy(alpha = if (isDark) 0.32f else 0.28f),
                scoreColor.copy(alpha = if (isDark) 0.14f else 0.10f),
            ),
        )
    }

    // iOS-matched border: scoreColor at double stroke alpha
    val borderColor = scoreColor.copy(alpha = if (isDark) 0.30f else 0.20f)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick)
            // iOS: shadow(color: scoreColor.opacity(0.15), radius: 12, y: 4)
            .shadow(
                elevation = 12.dp,
                shape = RoundedCornerShape(LasoTokens.CardRadius),
                ambientColor = scoreColor.copy(alpha = 0.15f),
                spotColor = scoreColor.copy(alpha = 0.15f),
            ),
    ) {
        Surface(
            shape = RoundedCornerShape(LasoTokens.CardRadius),
            color = Color.Transparent,
            border = BorderStroke(
                width = if (isDark) 0.5.dp else 1.dp,
                color = borderColor,
            ),
        ) {
            Column(
                modifier = Modifier
                    .background(gradientBrush)
                    .padding(18.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    HealthScoreRing(
                        score = score,
                        size = 120.dp,
                        strokeWidth = 12.dp,
                        label = "Recovery",
                    )

                    Column(
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.weight(1f),
                    ) {
                        // Recovery state label
                        Text(
                            text = recoveryStateLabel,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )

                        // Score delta badge capsule — iOS: arrow icon + delta + "from yesterday"
                        if (scoreDelta != null && scoreDelta != 0) {
                            val deltaText = if (scoreDelta > 0) "+$scoreDelta" else "$scoreDelta"
                            val deltaBadgeColor = if (scoreDelta > 0) {
                                LasoTokens.scoreColor(76) // green
                            } else {
                                LasoTokens.scoreColor(20) // red
                            }

                            Box(
                                modifier = Modifier
                                    .background(
                                        color = deltaBadgeColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                                        shape = RoundedCornerShape(20.dp),
                                    )
                                    .padding(horizontal = 10.dp, vertical = 5.dp),
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    // iOS: arrow.up.right / arrow.down.right
                                    Icon(
                                        imageVector = if (scoreDelta > 0) {
                                            Icons.Filled.NorthEast
                                        } else {
                                            Icons.Filled.SouthEast
                                        },
                                        contentDescription = null,
                                        modifier = Modifier.size(12.dp),
                                        tint = deltaBadgeColor,
                                    )
                                    Text(
                                        text = deltaText,
                                        style = MaterialTheme.typography.bodySmall.copy(
                                            fontFamily = FontFamily.Monospace,
                                        ),
                                        fontWeight = FontWeight.SemiBold,
                                        color = deltaBadgeColor,
                                    )
                                    Text(
                                        text = "vs last week",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = deltaBadgeColor,
                                    )
                                }
                            }
                        }

                        // Day classification in scoreColor capsule
                        Box(
                            modifier = Modifier
                                .background(
                                    color = scoreColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                                    shape = RoundedCornerShape(20.dp),
                                )
                                .padding(horizontal = 10.dp, vertical = 5.dp),
                        ) {
                            Text(
                                text = dayClassification,
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = scoreColor,
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Tap hint row
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.TouchApp,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                    )
                    Text(
                        text = "Tap to understand your score",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Today's Action Card

@Composable
private fun TodaysActionCard(
    title: String,
    detail: String,
    iconEmoji: String,
    scoreColor: Color,
    onClick: () -> Unit,
) {
    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
    ) {
        // "TODAY'S ACTION" label with sparkle icon
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.padding(bottom = 10.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.AutoAwesome,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                text = "TODAY\u2019S ACTION",
                style = MaterialTheme.typography.labelSmall,
                letterSpacing = 1.5.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Emoji in 40dp rounded rect with scoreColor bg at 0.15 alpha
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        color = scoreColor.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(10.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = iconEmoji.ifEmpty { "\u2728" },
                    style = MaterialTheme.typography.bodyLarge,
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

// endregion

// region 4. Alert Banners

@Composable
private fun AlertBanners(
    alerts: List<AlertUi>,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        alerts.forEach { alert ->
            AlertBannerRow(alert = alert, onClick = onClick)
        }
    }
}

@Composable
private fun AlertBannerRow(
    alert: AlertUi,
    onClick: () -> Unit,
) {
    val accentColor = alert.severity.accentColor

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 4dp colored accent bar
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(40.dp)
                    .background(
                        color = accentColor,
                        shape = RoundedCornerShape(2.dp),
                    ),
            )

            // Warning icon in colored circle background
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(
                        color = accentColor.copy(alpha = 0.12f),
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Warning,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = accentColor,
                )
            }

            // Title + detail
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = alert.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = alert.detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
            }

            // Severity badge capsule
            Box(
                modifier = Modifier
                    .background(
                        color = accentColor,
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text = alert.severity.label,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
            }

            // Chevron
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

// endregion

// region 5. Metric Strip

@Composable
private fun MetricStrip(
    metrics: List<MetricTileUi>,
    onMetricClick: (MetricTileUi) -> Unit,
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        // iOS: HStack(spacing: 10)
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(metrics) { metric ->
            MetricTile(metric = metric, onClick = { onMetricClick(metric) })
        }
    }
}

@Composable
private fun MetricTile(
    metric: MetricTileUi,
    onClick: () -> Unit,
) {
    val tileColor = metric.metric.category.accentColor
    val isDark = isSystemInDarkTheme()

    // iOS: .frame(width: 96).padding(.vertical, 10).background(.background, cornerRadius)
    // .overlay(strokeBorder(tile.color.opacity(DS.strokeAlpha)))
    // NOT using LasoCard — iOS has only vertical padding (10pt), no horizontal padding
    Surface(
        modifier = Modifier
            .width(96.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(LasoTokens.CardRadius),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(
            width = if (isDark) 0.5.dp else 1.dp,
            color = tileColor.copy(alpha = LasoTokens.BorderOpacity),
        ),
        shadowElevation = if (isDark) 0.dp else 2.dp,
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            // iOS: .padding(.vertical, 10) — no horizontal padding, content fills 96pt width
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
        ) {
            // iOS: 30x30 colored rounded rect (cornerRadius 8) with WHITE icon
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .background(
                        color = tileColor,
                        shape = RoundedCornerShape(8.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = metricTileIcon(metric.label, metric.metric),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = Color.White,
                )
            }

            // iOS: .headline.weight(.bold).monospacedDigit()
            Text(
                text = metric.value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )

            // iOS: .caption2.weight(.medium), .secondary
            Text(
                text = metric.label.ifEmpty { metric.metric.displayName },
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )

            // iOS: .caption2.weight(.bold), tile.color — or placeholder space
            if (metric.badge.isNotEmpty()) {
                Text(
                    text = metric.badge,
                    style = MaterialTheme.typography.labelSmall,
                    color = tileColor,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                )
            } else {
                // Placeholder to keep consistent height across tiles
                Text(
                    text = " ",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

/** Maps tile label to the matching iOS SF Symbol → Material Icon.
 *  iOS icons: figure.run, moon.fill, flame.fill, brain, waveform.path.ecg, heart.fill */
private fun metricTileIcon(label: String, metric: HealthMetric): ImageVector = when (label) {
    "Vitality" -> Icons.AutoMirrored.Filled.DirectionsRun
    "Sleep" -> Icons.Filled.Bedtime
    "Strain" -> Icons.Filled.LocalFireDepartment
    "Brain" -> Icons.Filled.Psychology
    "Stress" -> Icons.Filled.MonitorHeart
    "HRV" -> Icons.Filled.Favorite
    else -> metric.category.icon
}

// endregion

// region 6. Level Badge Card

@Composable
private fun LevelBadgeCard(
    level: String,
    score: Int,
    totalDaysTracked: Int,
    progressToNextLevel: Float,
    activityStreak: Int,
    sleepStreak: Int,
    recoveryStreak: Int,
    onClick: () -> Unit,
) {
    val scoreColor = LasoTokens.scoreColor(score)
    val levelEmoji = levelEmoji(level)

    val animatedProgress by animateFloatAsState(
        targetValue = progressToNextLevel,
        animationSpec = tween(durationMillis = 800),
        label = "levelProgress",
    )

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Left: level icon
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(
                        color = scoreColor.copy(alpha = 0.15f),
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = levelEmoji,
                    style = MaterialTheme.typography.titleMedium,
                )
            }

            // Center: level name + progress
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(
                    text = level,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                LinearProgressIndicator(
                    progress = { animatedProgress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(5.dp)
                        .clip(RoundedCornerShape(3.dp)),
                    color = scoreColor,
                    trackColor = scoreColor.copy(alpha = 0.15f),
                )

                val percentToNext = (progressToNextLevel * 100).toInt()
                Text(
                    text = "$totalDaysTracked days \u00B7 $percentToNext% to next",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                )
            }

            // Right: mini streak counters (iOS streakColumn)
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                StreakRow(
                    icon = Icons.AutoMirrored.Filled.DirectionsRun,
                    count = activityStreak,
                    isHot = activityStreak >= 7,
                )
                StreakRow(
                    icon = Icons.Filled.Bedtime,
                    count = sleepStreak,
                    isHot = sleepStreak >= 7,
                )
                StreakRow(
                    icon = Icons.Filled.Favorite,
                    count = recoveryStreak,
                    isHot = recoveryStreak >= 7,
                )
            }

            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        }
    }
}

@Composable
private fun StreakRow(
    icon: ImageVector,
    count: Int,
    isHot: Boolean,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (isHot) {
            Icon(
                imageVector = Icons.Filled.LocalFireDepartment,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = AccentOrange,
            )
        }
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(12.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )
        Text(
            text = "$count",
            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.Bold,
        )
    }
}

private fun levelEmoji(level: String): String {
    val lower = level.lowercase()
    return when {
        "platinum" in lower || "diamond" in lower -> "\uD83D\uDC8E"
        "gold" in lower -> "\uD83E\uDD47"
        "silver" in lower -> "\uD83E\uDD48"
        "bronze" in lower -> "\uD83E\uDD49"
        else -> "\u2B50"
    }
}

// endregion

// region 7. Body Insights Section

@Composable
private fun BodyInsightsSection(
    bodyInsight: BodyInsightUi,
    onClick: () -> Unit,
) {
    // iOS: no section header — solid colored card with white text
    val bgColor = if (bodyInsight.isChain) {
        Color(0xFF5856D6) // Indigo (iOS .indigo.gradient)
    } else {
        Color(0xFF4879A7) // Blue (iOS .blue.gradient)
    }

    val icon = if (bodyInsight.isChain) {
        Icons.Filled.Link
    } else {
        Icons.Filled.Lightbulb
    }

    val gradientBrush = Brush.linearGradient(
        colors = listOf(bgColor, bgColor.copy(alpha = 0.85f)),
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(LasoTokens.CardRadius))
            .background(gradientBrush)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(LasoTokens.CardPadding),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = Color.White.copy(alpha = 0.8f),
            )

            Text(
                text = bodyInsight.narrative,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                maxLines = 2,
                modifier = Modifier.weight(1f),
            )

            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = Color.White.copy(alpha = 0.5f),
            )
        }
    }
}

// endregion

// region 8. Weekly Review Section

@Composable
private fun WeeklyReviewSection(
    weeklyReview: WeeklyReviewUi,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionHeading(title = "Weekly Review")

        LasoCard(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = weeklyReview.title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Text(
                    text = weeklyReview.detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )

                if (weeklyReview.highlight.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Box(
                        modifier = Modifier
                            .background(
                                color = MaterialTheme.colorScheme.primary.copy(
                                    alpha = LasoTokens.BadgeBgOpacity,
                                ),
                                shape = RoundedCornerShape(12.dp),
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = weeklyReview.highlight,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
        }
    }
}

// endregion

// region 9. Last Updated Footer

@Composable
private fun LastUpdatedFooter(lastUpdated: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = lastUpdated,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
        )
    }
}

// endregion

