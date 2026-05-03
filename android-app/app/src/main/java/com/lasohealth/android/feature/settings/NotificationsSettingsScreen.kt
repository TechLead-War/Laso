package com.lasohealth.android.feature.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsSettingsScreen(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notifications", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background)
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { padding ->
        LazyColumn(
            modifier = modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            item {
                Column {
                    SettingsHeader("SUMMARIES")
                    SettingsGroup {
                        ToggleRow("Daily Summary", dailySummaryEnabled) { dailySummaryEnabled = it }
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                        ToggleRow("Weekly Report", weeklyReportEnabled) { weeklyReportEnabled = it }
                    }
                    SettingsFooter("We'll send you a brief wrap-up of your health trends.")
                }
            }

            item {
                Column {
                    SettingsHeader("HEART RATE ALERTS")
                    SettingsGroup {
                        ToggleRow("Heart Rate Spike Alerts", heartRateSpikeAlerts) { heartRateSpikeAlerts = it }
                        if (heartRateSpikeAlerts) {
                            Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("High HR Threshold", fontSize = 16.sp)
                                    Text("${highHRThreshold.roundToInt()} bpm", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Slider(value = highHRThreshold, onValueChange = { highHRThreshold = it }, valueRange = 100f..180f, steps = 15)

                                Spacer(modifier = Modifier.height(8.dp))

                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Low HR Threshold", fontSize = 16.sp)
                                    Text("${lowHRThreshold.roundToInt()} bpm", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Slider(value = lowHRThreshold, onValueChange = { lowHRThreshold = it }, valueRange = 30f..60f, steps = 5)
                            }
                        }
                    }
                    SettingsFooter("Get notified when your heart rate goes above or below these thresholds while not exercising.")
                }
            }

            item {
                Column {
                    SettingsHeader("ALERTS & INSIGHTS")
                    SettingsGroup {
                        ToggleRow("Critical Alerts", criticalAlerts) { criticalAlerts = it }
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                        ToggleRow("Warning Alerts", warningAlerts) { warningAlerts = it }
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                        ToggleRow("Trend Reversals", trendReversalAlerts) { trendReversalAlerts = it }
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                        ToggleRow("Improvement Celebrations", improvementCelebrations) { improvementCelebrations = it }
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 16.dp))
                        
                        Row(modifier = Modifier.fillMaxWidth().padding(16.dp, 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("Max per day", fontSize = 16.sp, modifier = Modifier.weight(1f))
                            Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.onSurface.copy(0.06f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(onClick = { if (maxPerDay > 1) maxPerDay-- }, modifier = Modifier.size(36.dp)) { Icon(Icons.Default.Remove, null) }
                                    Text("$maxPerDay", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(32.dp), textAlign = TextAlign.Center)
                                    IconButton(onClick = { if (maxPerDay < 15) maxPerDay++ }, modifier = Modifier.size(36.dp)) { Icon(Icons.Default.Add, null) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsHeader(text: String, color: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.onSurfaceVariant) {
    Text(text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.5.sp, color = color, modifier = Modifier.padding(start = 16.dp, bottom = 6.dp))
}

@Composable
private fun SettingsFooter(text: String) {
    Text(text, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 16.dp, top = 6.dp, end = 16.dp))
}

@Composable
private fun SettingsGroup(content: @Composable () -> Unit) {
    Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceVariant.copy(0.3f), modifier = Modifier.fillMaxWidth()) {
        Column { content() }
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, fontSize = 16.sp, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
