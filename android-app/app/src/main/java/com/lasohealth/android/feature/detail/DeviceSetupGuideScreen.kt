package com.lasohealth.android.feature.detail

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.CategoryActivity
import com.lasohealth.android.ui.theme.CategoryHeart
import com.lasohealth.android.ui.theme.CategoryMindfulness
import com.lasohealth.android.ui.theme.CategoryRespiratory
import com.lasohealth.android.ui.theme.CategorySleep

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun DeviceSetupGuideScreen(navController: NavHostController) {
    val context = LocalContext.current

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Setup Guide",
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
            contentPadding = PaddingValues(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Hero Section
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp, bottom = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "\uD83D\uDCF1",
                        fontSize = 64.sp,
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = "Connect Your Device",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "Follow these steps to set up Health Connect",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 24.dp),
                    )
                }
            }

            // 2. Steps Section
            item {
                SectionHeading(title = "Getting Started")
            }

            val steps = listOf(
                SetupStep(
                    number = 1,
                    title = "Install Health Connect",
                    description = "Download Health Connect from the Play Store if you don't have it.",
                    color = CategoryHeart,
                ),
                SetupStep(
                    number = 2,
                    title = "Open Health Connect",
                    description = "Go to Settings > Connected Apps in Health Connect.",
                    color = CategorySleep,
                ),
                SetupStep(
                    number = 3,
                    title = "Grant Permissions",
                    description = "Allow Laso to read your health data.",
                    color = AccentGreen,
                ),
                SetupStep(
                    number = 4,
                    title = "Connect Your Wearable",
                    description = "Make sure your wearable app (Fitbit, Samsung Health, etc.) syncs to Health Connect.",
                    color = AccentBlue,
                ),
                SetupStep(
                    number = 5,
                    title = "Start Tracking",
                    description = "Your data will sync automatically once connected.",
                    color = CategoryMindfulness,
                ),
            )

            items(steps.size) { index ->
                StepCard(step = steps[index])
            }

            // 3. Supported Devices Section
            item {
                Spacer(modifier = Modifier.height(4.dp))
                SectionHeading(title = "Works With")
            }

            item {
                val devices = listOf(
                    SupportedDevice(emoji = "\u231A", name = "Pixel Watch"),
                    SupportedDevice(emoji = "\u2328\uFE0F", name = "Galaxy Watch"),
                    SupportedDevice(emoji = "\uD83D\uDCDF", name = "Fitbit"),
                    SupportedDevice(emoji = "\uD83D\uDCAD", name = "Oura Ring"),
                    SupportedDevice(emoji = "\u2696\uFE0F", name = "Withings"),
                    SupportedDevice(emoji = "\uD83E\uDDED", name = "Garmin"),
                )

                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    devices.forEach { device ->
                        SupportedDeviceCard(device = device)
                    }
                }
            }

            // 4. Troubleshooting Section
            item {
                Spacer(modifier = Modifier.height(4.dp))
                SectionHeading(title = "Having Issues?")
            }

            val faqItems = listOf(
                FaqItem(
                    question = "Data not syncing?",
                    answer = "Make sure Health Connect is installed and that Laso has permission to read your data. Open Health Connect, go to Connected Apps, and verify Laso is listed with read access enabled.",
                ),
                FaqItem(
                    question = "Missing metrics?",
                    answer = "Some metrics require specific hardware support. For example, HRV and blood oxygen readings need a compatible wearable. Check that your device supports the metrics you expect to see.",
                ),
                FaqItem(
                    question = "Connection drops?",
                    answer = "Try restarting both your wearable and the companion app. Also ensure that Health Connect is not being restricted by battery optimization settings on your phone.",
                ),
            )

            items(faqItems.size) { index ->
                FaqCard(item = faqItems[index])
            }

            // 5. CTA Button
            item {
                Spacer(modifier = Modifier.height(4.dp))

                Button(
                    onClick = { openHealthConnect(context) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(50.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                    ),
                ) {
                    Text(
                        text = "Open Health Connect",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

// region Data Classes

private data class SetupStep(
    val number: Int,
    val title: String,
    val description: String,
    val color: androidx.compose.ui.graphics.Color,
)

private data class SupportedDevice(
    val emoji: String,
    val name: String,
)

private data class FaqItem(
    val question: String,
    val answer: String,
)

// endregion

// region Step Card

@Composable
private fun StepCard(step: SetupStep) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Number circle
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(step.color, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "${step.number}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = androidx.compose.ui.graphics.Color.White,
                )
            }

            // Title + description
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = step.title,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = step.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
    }
}

// endregion

// region Supported Device Card

@Composable
private fun SupportedDeviceCard(device: SupportedDevice) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(LasoTokens.CardRadius))
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = device.emoji,
                fontSize = 20.sp,
            )
            Text(
                text = device.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

// endregion

// region FAQ Card

@Composable
private fun FaqCard(item: FaqItem) {
    var expanded by remember { mutableStateOf(false) }

    LasoCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = !expanded },
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = item.question,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )

                Icon(
                    imageVector = if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = if (expanded) "Collapse" else "Expand",
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }

            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically(),
                exit = shrinkVertically(),
            ) {
                Text(
                    text = item.answer,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }
}

// endregion

// region Health Connect Intent

private fun openHealthConnect(context: Context) {
    // Try the Health Connect main activity first
    val healthConnectIntent = Intent().apply {
        action = "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS"
    }
    if (healthConnectIntent.resolveActivity(context.packageManager) != null) {
        context.startActivity(healthConnectIntent)
        return
    }

    // Fallback: open Health Connect on Play Store
    val playStoreIntent = Intent(
        Intent.ACTION_VIEW,
        Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata"),
    )
    context.startActivity(playStoreIntent)
}

// endregion
