package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Hotel
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Watch
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.CategoryHeart
import com.lasohealth.android.ui.theme.CategoryMindfulness
import com.lasohealth.android.ui.theme.CategorySleep

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecoveryInfoScreen(
    score: Int,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Recovery",
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
                    TextButton(onClick = { navController.popBackStack() }) {
                        Text(
                            text = "Done",
                            fontWeight = FontWeight.SemiBold,
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
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState()),
        ) {
            // 1. Hero Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp, bottom = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                HealthScoreRing(
                    score = score,
                    size = 120.dp,
                    strokeWidth = 12.dp,
                    label = "Recovery",
                )

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "How Recovery Works",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "Your Recovery score (0\u2013100) tells you how recovered your body is, based on overnight data measured while you sleep.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 40.dp),
                )
            }

            // 2. Score Levels
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = "Score levels",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(LasoTokens.CardRadius))
                        .background(MaterialTheme.colorScheme.surface),
                ) {
                    RecoveryLevelRow(
                        range = "80\u2013100",
                        label = "Fully Recovered",
                        color = AccentGreen,
                        description = "Your body is well rested. Great day for a hard workout.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryLevelRow(
                        range = "60\u201379",
                        label = "Well Recovered",
                        color = AccentYellow,
                        description = "Decent recovery. Moderate intensity is ideal.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryLevelRow(
                        range = "40\u201359",
                        label = "Moderate",
                        color = AccentOrange,
                        description = "Partial recovery. Listen to your body and keep it light.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryLevelRow(
                        range = "20\u201339",
                        label = "Fatigued",
                        color = AccentRed,
                        description = "Your body needs rest. Prioritize easy movement and sleep.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryLevelRow(
                        range = "0\u201319",
                        label = "Strained",
                        color = AccentRed.copy(alpha = 0.7f),
                        description = "Significant recovery deficit. Rest and sleep are essential.",
                    )
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // 3. Recovery Factor Breakdown
            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = "How it\u2019s calculated",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )

                Text(
                    text = "Recovery is a weighted score from signals measured while you sleep. Each signal is compared to your personal baseline.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(LasoTokens.CardRadius))
                        .background(MaterialTheme.colorScheme.surface),
                ) {
                    RecoveryFactorWeightRow(
                        icon = Icons.Filled.MonitorHeart,
                        color = CategoryMindfulness,
                        name = "Heart Rate Variability",
                        weight = "35%",
                        weightFraction = 0.35f,
                        detail = "Higher HRV means better recovery and lower stress.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryFactorWeightRow(
                        icon = Icons.Filled.Favorite,
                        color = CategoryHeart,
                        name = "Resting Heart Rate",
                        weight = "25%",
                        weightFraction = 0.25f,
                        detail = "Lower resting HR means your heart is recovering well.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryFactorWeightRow(
                        icon = Icons.Filled.Hotel,
                        color = CategorySleep,
                        name = "Sleep Duration",
                        weight = "20%",
                        weightFraction = 0.20f,
                        detail = "7.5 hours is optimal. Too little or too much reduces the score.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryFactorWeightRow(
                        icon = Icons.Filled.DarkMode,
                        color = AccentBlue,
                        name = "Sleep Quality",
                        weight = "15%",
                        weightFraction = 0.15f,
                        detail = "Deep and REM sleep stages contribute to recovery quality.",
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 52.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                    )
                    RecoveryFactorWeightRow(
                        icon = Icons.AutoMirrored.Filled.DirectionsRun,
                        color = AccentGreen,
                        name = "Workout Recovery",
                        weight = "5%",
                        weightFraction = 0.05f,
                        detail = "Hard workouts lower recovery temporarily. The effect fades over 18\u201336 hours.",
                    )
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // 4. When does it update?
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(LasoTokens.CardRadius))
                    .background(AccentBlue.copy(alpha = 0.08f))
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Icon(
                    imageVector = Icons.Filled.Schedule,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = AccentBlue,
                )

                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        text = "When does it update?",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                    )

                    Text(
                        text = "Your Recovery score recalculates each morning using overnight data. It typically takes 1\u20133 days of consistent overnight wear before changes in your routine show up in the score.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // 5. Device requirement note
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(LasoTokens.CardRadius))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Filled.Watch,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )

                Text(
                    text = "Wear your smartwatch or fitness tracker overnight so it can measure HRV and resting heart rate while you sleep.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(28.dp))

            // 6. Got It button
            Button(
                onClick = { navController.popBackStack() },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(50.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Text(
                    text = "Got It",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

// region Row Components

@Composable
private fun RecoveryLevelRow(
    range: String,
    label: String,
    color: Color,
    description: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(color, CircleShape),
        )

        Spacer(modifier = Modifier.width(2.dp))

        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.weight(1f),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = range,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Medium,
                    color = color,
                )
            }
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

@Composable
private fun RecoveryFactorWeightRow(
    icon: ImageVector,
    color: Color,
    name: String,
    weight: String,
    weightFraction: Float,
    detail: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = color,
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.weight(1f),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
                Text(
                    text = weight,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
            }

            // Weight bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction = weightFraction)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(color),
                )
            }

            Text(
                text = detail,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion
