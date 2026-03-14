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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.DeviceDetailUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceDetailScreen(
    state: DeviceDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    val isActive = state.statusLabel.lowercase().contains("active") &&
        !state.statusLabel.lowercase().contains("inactive")

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.name,
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
            // 1. Device Hero
            item {
                DeviceHeroSection(
                    emoji = state.emoji,
                    name = state.name,
                    statusLabel = state.statusLabel,
                    isActive = isActive,
                )
            }

            // 2. Metrics Provided
            if (state.metricsProvided.isNotEmpty()) {
                item {
                    SectionHeading(title = "Metrics Provided")
                }
                item {
                    MetricsProvidedCard(metrics = state.metricsProvided)
                }
            }

            // 3. Last Sync
            item {
                LastSyncCard(lastSync = state.lastSync)
            }

            // 4. Troubleshooting (conditional)
            if (state.troubleshooting != null) {
                item {
                    TroubleshootingCard(text = state.troubleshooting)
                }
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Device Hero

@Composable
private fun DeviceHeroSection(
    emoji: String,
    name: String,
    statusLabel: String,
    isActive: Boolean,
) {
    val accentColor = if (isActive) AccentGreen else AccentOrange
    val circleColor = AccentBlue

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Large emoji in colored circle
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(circleColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = emoji,
                fontSize = 36.sp,
            )
        }

        // Device name
        Text(
            text = name,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        // Status badge
        Box(
            modifier = Modifier
                .background(
                    color = accentColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                    shape = RoundedCornerShape(20.dp),
                )
                .padding(horizontal = 14.dp, vertical = 5.dp),
        ) {
            Text(
                text = statusLabel,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = accentColor,
            )
        }
    }
}

// endregion

// region 2. Metrics Provided

@Composable
private fun MetricsProvidedCard(metrics: List<String>) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            metrics.forEach { metric ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    // Checkmark dot
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .clip(CircleShape)
                            .background(AccentGreen),
                    )

                    Text(
                        text = metric,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

// endregion

// region 3. Last Sync

@Composable
private fun LastSyncCard(lastSync: String) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Last synced",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Text(
                text = lastSync,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

// endregion

// region 4. Troubleshooting

@Composable
private fun TroubleshootingCard(text: String) {
    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = AccentOrange,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = AccentOrange,
        )
    }
}

// endregion
