package com.lasohealth.android.feature.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import kotlin.math.roundToInt
import com.lasohealth.android.core.data.HealthDataRepository
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.navigation.AppRoute
import com.lasohealth.android.ui.theme.AccentRed

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    navController: NavHostController,
    repository: HealthDataRepository,
    modifier: Modifier = Modifier,
) {
    // Toggle states
    var dailySummaryEnabled by remember { mutableStateOf(true) }
    var weeklyReportEnabled by remember { mutableStateOf(true) }
    var heartRateSpikeAlerts by remember { mutableStateOf(false) }
    var highHRThreshold by remember { mutableFloatStateOf(140f) }
    var lowHRThreshold by remember { mutableFloatStateOf(45f) }
    var criticalAlerts by remember { mutableStateOf(true) }
    var warningAlerts by remember { mutableStateOf(true) }
    var trendReversalAlerts by remember { mutableStateOf(true) }
    var improvementCelebrations by remember { mutableStateOf(true) }
    var maxPerDay by remember { mutableIntStateOf(8) }
    val isPro = remember { false } // Subscription gating

    // Data stats (sample values matching iOS)
    val storedSamples = remember { 18_294 }
    val dataHistory = remember { "47 days" }
    val metricsTracked = remember { 26 }
    val connectedCount = remember { 1 }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Settings",
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
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // Section 1: Connected Devices
            item {
                SettingsSection(title = "Connected Devices") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    navController.navigate(AppRoute.ConnectedDevices.route)
                                }
                                .padding(vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = "\u2764\uFE0F",
                                style = MaterialTheme.typography.titleMedium,
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = "Connected Devices",
                                style = MaterialTheme.typography.bodyLarge,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                text = "$connectedCount connected",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                            )
                        }
                    }
                }
            }

            // Section 2: Daily Summary
            item {
                SettingsSection(title = "Daily Summary") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        ToggleRow(
                            label = "Enable Daily Summary",
                            checked = dailySummaryEnabled,
                            onCheckedChange = { dailySummaryEnabled = it },
                        )
                    }
                }
            }

            // Section 3: Weekly Summary
            item {
                SettingsSection(title = "Weekly Summary") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        ToggleRow(
                            label = "Enable Weekly Report",
                            checked = weeklyReportEnabled,
                            onCheckedChange = { weeklyReportEnabled = it },
                        )
                    }
                }
            }

            // Section 4: Heart Rate Alerts
            item {
                SettingsSection(title = "Heart Rate Alerts") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            ToggleRow(
                                label = "Heart Rate Spike Alerts",
                                checked = heartRateSpikeAlerts,
                                onCheckedChange = { heartRateSpikeAlerts = it },
                            )

                            if (heartRateSpikeAlerts) {
                                HorizontalDivider(
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                                )
                                Spacer(modifier = Modifier.height(4.dp))

                                // High HR Threshold
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = "High HR Threshold",
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                    Text(
                                        text = "${highHRThreshold.roundToInt()} bpm",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                    )
                                }
                                Slider(
                                    value = highHRThreshold,
                                    onValueChange = { highHRThreshold = it },
                                    valueRange = 100f..180f,
                                    steps = 15, // 15 intermediate values → 16 intervals → 5 bpm each
                                    colors = SliderDefaults.colors(
                                        thumbColor = AccentRed,
                                        activeTrackColor = AccentRed,
                                    ),
                                )

                                // Low HR Threshold
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        text = "Low HR Threshold",
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                    Text(
                                        text = "${lowHRThreshold.roundToInt()} bpm",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                    )
                                }
                                Slider(
                                    value = lowHRThreshold,
                                    onValueChange = { lowHRThreshold = it },
                                    valueRange = 30f..60f,
                                    steps = 5, // 5 intermediate values → 6 intervals → 5 bpm each
                                    colors = SliderDefaults.colors(
                                        thumbColor = AccentRed,
                                        activeTrackColor = AccentRed,
                                    ),
                                )

                                Text(
                                    text = "Get notified when your heart rate goes above or below these thresholds while not exercising.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                                )
                            }
                        }
                    }
                }
            }

            // Section 5: Alerts
            item {
                SettingsSection(title = "Alerts") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        Column {
                            ToggleRow(
                                label = "Critical Alerts",
                                checked = criticalAlerts,
                                onCheckedChange = { criticalAlerts = it },
                            )
                            SettingsDivider()
                            ToggleRow(
                                label = "Warning Alerts",
                                checked = warningAlerts,
                                onCheckedChange = { warningAlerts = it },
                            )
                            SettingsDivider()
                            ToggleRow(
                                label = "Trend Reversal Alerts",
                                checked = trendReversalAlerts,
                                onCheckedChange = { trendReversalAlerts = it },
                            )
                            SettingsDivider()
                            ToggleRow(
                                label = "Improvement Celebrations",
                                checked = improvementCelebrations,
                                onCheckedChange = { improvementCelebrations = it },
                            )
                            SettingsDivider()

                            // Max per day stepper
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = "Max per day",
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.weight(1f),
                                )

                                // Stepper
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
                                ) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        IconButton(
                                            onClick = {
                                                if (maxPerDay > 1) maxPerDay--
                                            },
                                            modifier = Modifier.size(36.dp),
                                        ) {
                                            Icon(
                                                imageVector = Icons.Filled.Remove,
                                                contentDescription = "Decrease",
                                                modifier = Modifier.size(18.dp),
                                                tint = if (maxPerDay > 1) {
                                                    MaterialTheme.colorScheme.onSurface
                                                } else {
                                                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                                                },
                                            )
                                        }
                                        Text(
                                            text = "$maxPerDay",
                                            style = MaterialTheme.typography.bodyLarge,
                                            fontWeight = FontWeight.SemiBold,
                                            modifier = Modifier.width(32.dp),
                                            textAlign = TextAlign.Center,
                                        )
                                        IconButton(
                                            onClick = {
                                                if (maxPerDay < 15) maxPerDay++
                                            },
                                            modifier = Modifier.size(36.dp),
                                        ) {
                                            Icon(
                                                imageVector = Icons.Filled.Add,
                                                contentDescription = "Increase",
                                                modifier = Modifier.size(18.dp),
                                                tint = if (maxPerDay < 15) {
                                                    MaterialTheme.colorScheme.onSurface
                                                } else {
                                                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                                                },
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Section 6: Data Export
            item {
                SettingsSection(title = "Data Export") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        if (isPro) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { /* Generate report */ }
                                    .padding(vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.Language,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp),
                                )
                                Text(
                                    text = "Generate Web Report",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        } else {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.Language,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                    modifier = Modifier.size(22.dp),
                                )
                                Text(
                                    text = "Generate Web Report",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                    modifier = Modifier.weight(1f),
                                )
                                Surface(
                                    shape = RoundedCornerShape(6.dp),
                                    color = MaterialTheme.colorScheme.primary,
                                ) {
                                    Text(
                                        text = "PRO",
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onPrimary,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // Section 7: On-Device Data
            item {
                SettingsSection(title = "On-Device Data") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        Column {
                            InfoRow(label = "Stored samples", value = "%,d".format(storedSamples))
                            SettingsDivider()
                            InfoRow(label = "Data history", value = dataHistory)
                            SettingsDivider()
                            InfoRow(label = "Metrics tracked", value = "$metricsTracked")
                        }
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "All your health data is stored securely on this device and never leaves without your permission.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }
            }

            // Section 8: About
            item {
                SettingsSection(title = "About") {
                    LasoCard(modifier = Modifier.fillMaxWidth()) {
                        Column {
                            InfoRow(label = "Version", value = "1.0.0")
                            SettingsDivider()
                            InfoRow(label = "Data Privacy", value = "Health Data On-Device")
                            SettingsDivider()

                            // Privacy Policy
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { /* Open privacy policy URL */ }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = "Privacy Policy",
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.weight(1f),
                                )
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.OpenInNew,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                )
                            }
                            SettingsDivider()

                            // Terms of Use
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { /* Open terms of use URL */ }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = "Terms of Use",
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.weight(1f),
                                )
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.OpenInNew,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                                )
                            }
                        }
                    }
                }
            }

            // Section 9: Medical Disclaimer
            item {
                Text(
                    text = "Laso provides health insights for wellness and informational purposes only. It is not a medical device and should not replace professional medical advice.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                )
                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }
}

// region Reusable Components

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
            letterSpacing = MaterialTheme.typography.labelMedium.letterSpacing,
            modifier = Modifier.padding(horizontal = 4.dp),
        )
        content()
    }
}

@Composable
private fun ToggleRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
                checkedTrackColor = MaterialTheme.colorScheme.primary,
            ),
        )
    }
}

@Composable
private fun InfoRow(
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )
    }
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f),
    )
}

// endregion
