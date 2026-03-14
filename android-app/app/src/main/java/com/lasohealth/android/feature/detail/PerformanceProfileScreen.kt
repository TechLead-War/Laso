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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.Timelapse
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.design.TrendBadge
import com.lasohealth.android.core.design.TrendDirection
import com.lasohealth.android.core.model.PerformanceProfileUiState
import com.lasohealth.android.core.model.PersonalRecordUi
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentYellow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PerformanceProfileScreen(
    state: PerformanceProfileUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Performance Profile",
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Overall Performance Ring
            item {
                OverallPerformanceHero(
                    score = state.overallScore,
                    trend = state.performanceTrend,
                )
            }

            // 2. Stats Grid
            item {
                StatsGridSection(
                    totalWorkouts = state.totalWorkouts,
                    avgWeeklyStrain = state.avgWeeklyStrain,
                    recoveryDays = state.recoveryDays,
                    activeDaysPerWeek = state.activeDaysPerWeek,
                )
            }

            // 3. Personal Records
            if (state.personalRecords.isNotEmpty()) {
                item {
                    SectionHeading(title = "Personal Records")
                }
                item {
                    PersonalRecordsCard(records = state.personalRecords)
                }
            }

            // 4. Performance Trend
            item {
                PerformanceTrendSection(trend = state.performanceTrend)
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Overall Performance Hero

@Composable
private fun OverallPerformanceHero(
    score: Int,
    trend: String,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Avatar placeholder
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Default.EmojiEvents,
                contentDescription = null,
                tint = AccentYellow,
                modifier = Modifier.size(36.dp),
            )
        }

        // Score ring
        HealthScoreRing(
            score = score,
            size = 140.dp,
            strokeWidth = 14.dp,
            label = "Overall",
        )

        // Score label
        Text(
            text = LasoTokens.scoreLabel(score),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = LasoTokens.scoreColor(score),
        )
    }
}

// endregion

// region 2. Stats Grid

@Composable
private fun StatsGridSection(
    totalWorkouts: Int,
    avgWeeklyStrain: String,
    recoveryDays: Int,
    activeDaysPerWeek: Float,
) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Statistics")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                // Row 1
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    StatCell(
                        icon = Icons.Default.FitnessCenter,
                        value = totalWorkouts.toString(),
                        label = "Total Workouts",
                        modifier = Modifier.weight(1f),
                    )

                    StatCell(
                        icon = Icons.Default.LocalFireDepartment,
                        value = avgWeeklyStrain,
                        label = "Avg Weekly Strain",
                        modifier = Modifier.weight(1f),
                    )
                }

                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 10.dp),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                )

                // Row 2
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    StatCell(
                        icon = Icons.Default.SelfImprovement,
                        value = recoveryDays.toString(),
                        label = "Recovery Days",
                        modifier = Modifier.weight(1f),
                    )

                    StatCell(
                        icon = Icons.Default.Timelapse,
                        value = String.format("%.1f", activeDaysPerWeek),
                        label = "Active Days/Week",
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun StatCell(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    value: String,
    label: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = AccentBlue,
            modifier = Modifier.size(20.dp),
        )

        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
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

// region 3. Personal Records

@Composable
private fun PersonalRecordsCard(records: List<PersonalRecordUi>) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            records.forEachIndexed { index, record ->
                PersonalRecordRow(record = record)
                if (index < records.lastIndex) {
                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    )
                }
            }
        }
    }
}

@Composable
private fun PersonalRecordRow(record: PersonalRecordUi) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Emoji badge
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(LasoTokens.IconRadius))
                .background(AccentGreen.copy(alpha = LasoTokens.BadgeBgOpacity)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = record.emoji,
                fontSize = 18.sp,
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Label and date
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = record.label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = record.date,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
        }

        // Value
        Text(
            text = record.value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

// endregion

// region 4. Performance Trend

@Composable
private fun PerformanceTrendSection(trend: String) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Performance Trend")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Current Trend",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                val direction = when (trend.lowercase()) {
                    "improving" -> TrendDirection.IMPROVING
                    "declining" -> TrendDirection.DECLINING
                    else -> TrendDirection.STABLE
                }

                TrendBadge(direction = direction)
            }
        }
    }
}

// endregion
