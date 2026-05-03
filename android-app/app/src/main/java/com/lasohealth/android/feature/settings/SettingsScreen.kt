package com.lasohealth.android.feature.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.data.HealthDataRepository
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.navigation.AppRoute

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    navController: NavHostController,
    repository: HealthDataRepository,
    modifier: Modifier = Modifier,
) {
    val isPro = remember { false }
    val connectedCount = remember { 1 }
    val storedSamples = remember { 18294 }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.Bold) },
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
            // MARK: - Profile Section
            item {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(0.5f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column {
                            Text("HealthPulse", fontWeight = FontWeight.SemiBold, fontSize = 20.sp)
                            Text("Version 1.0.0 (1)", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                        }
                        Spacer(modifier = Modifier.weight(1f))
                        Column(horizontalAlignment = Alignment.End) {
                            Surface(
                                shape = CircleShape,
                                color = if (isPro) Color.Transparent else MaterialTheme.colorScheme.onSurface.copy(0.1f),
                                modifier = Modifier.background(
                                    if (isPro) Brush.linearGradient(listOf(Color(0xFF0A84FF), Color(0xFFBF5AF2)))
                                    else Brush.linearGradient(listOf(Color.Transparent, Color.Transparent)),
                                    CircleShape
                                )
                            ) {
                                Row(modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                    if (isPro) Icon(Icons.Default.Star, null, tint = Color.White, modifier = Modifier.size(12.dp))
                                    Text(if (isPro) "Pro Member" else "Free Plan", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = if (isPro) Color.White else MaterialTheme.colorScheme.onSurface)
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Subscription
            if (isPro) {
                item {
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Default.CreditCard, iconBg = Color.DarkGray,
                            title = "Manage Subscription", subtitle = "View plan details"
                        )
                    }
                }
            }

            // MARK: - Data Section
            item {
                Column {
                    SettingsHeader("YOUR DATA")
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Default.MonitorHeart, iconBg = Color(0xFF0A84FF),
                            title = "Manage Devices", subtitle = "$connectedCount connected",
                            onClick = { navController.navigate(AppRoute.ConnectedDevices.route) }
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.Storage, iconBg = Color(0xFF34C759),
                            title = "On-Device Data", subtitle = "$storedSamples samples · 47 days",
                            showChevron = false
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.IosShare, iconBg = Color(0xFF5856D6),
                            title = "Generate Web Report", subtitle = null
                        )
                    }
                    SettingsFooter("All your health data is stored securely on this device and never leaves without your permission.")
                }
            }

            // MARK: - Notifications Section
            item {
                Column {
                    SettingsHeader("NOTIFICATIONS")
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Default.Notifications, iconBg = Color(0xFFFF9F0A),
                            title = "Notifications", subtitle = "Daily Summary, Critical Alerts",
                            onClick = { navController.navigate(AppRoute.NotificationsSettings.route) }
                        )
                    }
                    SettingsFooter("Choose what HealthPulse can interrupt you for.")
                }
            }

            // MARK: - Support Section
            item {
                Column {
                    SettingsHeader("SUPPORT")
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Default.ArrowCircleDown, iconBg = Color(0xFF34C759),
                            title = "Update App", subtitle = "You are on the latest version"
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.Star, iconBg = Color(0xFFFFD60A),
                            title = "Rate on Google Play", subtitle = "Help others find us"
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.BugReport, iconBg = Color(0xFFFF453A),
                            title = "Report a Bug", subtitle = "Something broken?"
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.Help, iconBg = Color(0xFF0A84FF),
                            title = "Contact Us", subtitle = "Ask a question"
                        )
                    }
                }
            }

            // MARK: - About Section
            item {
                Column {
                    SettingsHeader("ABOUT")
                    SettingsGroup {
                        SettingsRow(
                            icon = Icons.Default.Person, iconBg = Color(0xFFBF5AF2),
                            title = "Signed in as", subtitle = "user@example.com", showChevron = false
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.PrivacyTip, iconBg = Color(0xFF0A84FF),
                            title = "Privacy Policy"
                        )
                        Divider(color = MaterialTheme.colorScheme.onSurface.copy(0.06f), modifier = Modifier.padding(start = 54.dp))
                        SettingsRow(
                            icon = Icons.Default.Description, iconBg = Color(0xFF5856D6),
                            title = "Terms of Use"
                        )
                    }
                }
            }

            // MARK: - Danger Zone
            item {
                Column {
                    SettingsHeader("DANGER ZONE", color = Color(0xFFFF453A))
                    SettingsGroup {
                        Row(modifier = Modifier.fillMaxWidth().clickable { }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(30.dp).background(Color(0xFFFF453A), RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
                                Icon(Icons.Default.Delete, null, tint = Color.White, modifier = Modifier.size(18.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text("Delete all my data", color = Color(0xFFFF453A), fontSize = 16.sp, fontWeight = FontWeight.Medium)
                                Text("Wipes everything from this device.", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }

            // MARK: - Disclaimer
            item {
                Text(
                    "HealthPulse provides insights for wellness purposes only.\nIt is not a medical device.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(0.6f),
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 16.dp, bottom = 40.dp)
                )
            }
        }
    }
}

@Composable
private fun SettingsHeader(text: String, color: Color = MaterialTheme.colorScheme.onSurfaceVariant) {
    Text(
        text,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.5.sp,
        color = color,
        modifier = Modifier.padding(start = 16.dp, bottom = 6.dp)
    )
}

@Composable
private fun SettingsFooter(text: String) {
    Text(
        text,
        fontSize = 13.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 16.dp, top = 6.dp, end = 16.dp)
    )
}

@Composable
private fun SettingsGroup(content: @Composable () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(0.3f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column { content() }
    }
}

@Composable
private fun SettingsRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconBg: Color,
    title: String,
    subtitle: String? = null,
    showChevron: Boolean = true,
    onClick: (() -> Unit)? = null
) {
    Row(
        modifier = Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(16.dp, 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.size(30.dp).background(iconBg, RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 16.sp, fontWeight = FontWeight.Medium)
            if (subtitle != null) {
                Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
            }
        }
        if (showChevron) {
            Icon(Icons.AutoMirrored.Filled.OpenInNew, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(0.5f))
        }
    }
}
