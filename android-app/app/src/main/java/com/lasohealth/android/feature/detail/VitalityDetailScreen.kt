package com.lasohealth.android.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.MetricContributionUi
import com.lasohealth.android.core.model.VitalityDetailUiState
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentRed

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VitalityDetailScreen(
    state: VitalityDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Vitality",
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
            // 1. Vitality Hero
            item {
                VitalityHeroSection(
                    vitalityAge = state.vitalityAge,
                    biologicalAge = state.biologicalAge,
                    delta = state.delta,
                )
            }

            // 2. Score Card
            item {
                VitalityScoreCard(
                    score = state.score,
                    trendDirection = state.trendDirection,
                )
            }

            // 3. Contributions
            if (state.contributions.isNotEmpty()) {
                item {
                    SectionHeading(title = "Metric Contributions")
                }
                items(state.contributions) { contribution ->
                    VitalityContributionCard(contribution = contribution)
                }
            }

            // 4. Historical Comparison (conditional)
            if (state.historicalComparison != null) {
                item {
                    HistoricalComparisonCard(text = state.historicalComparison)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Vitality Hero

@Composable
private fun VitalityHeroSection(
    vitalityAge: Int,
    biologicalAge: Int,
    delta: Int,
) {
    val deltaColor = if (delta <= 0) AccentGreen else AccentRed
    val deltaLabel = if (delta <= 0) {
        "${-delta}y younger"
    } else {
        "${delta}y older"
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Runner emoji in green circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(AccentGreen.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "\uD83C\uDFC3",
                fontSize = 32.sp,
            )
        }

        // "Your Vitality Age" label
        Text(
            text = "Your Vitality Age",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )

        // Large age number
        Text(
            text = vitalityAge.toString(),
            style = MaterialTheme.typography.displayMedium,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
        )

        // "vs biological age [N]" subtitle
        Text(
            text = "vs biological age $biologicalAge",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )

        // Delta badge
        Box(
            modifier = Modifier
                .background(
                    color = deltaColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            Text(
                text = deltaLabel,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = deltaColor,
            )
        }
    }
}

// endregion

// region 2. Score Card

@Composable
private fun VitalityScoreCard(
    score: Int,
    trendDirection: String,
) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            HealthScoreRing(
                score = score,
                size = 80.dp,
                strokeWidth = 8.dp,
            )

            Text(
                text = trendDirection,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion

// region 3. Contribution Card

@Composable
private fun VitalityContributionCard(contribution: MetricContributionUi) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = contribution.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = contribution.value,
                style = MaterialTheme.typography.bodyMedium,
                fontFamily = FontFamily.Monospace,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = contribution.impact,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// endregion

// region 4. Historical Comparison

@Composable
private fun HistoricalComparisonCard(text: String) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
        )
    }
}

// endregion
