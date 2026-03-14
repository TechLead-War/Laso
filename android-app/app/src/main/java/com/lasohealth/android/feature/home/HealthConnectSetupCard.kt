package com.lasohealth.android.feature.home

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasohealth.android.app.AndroidAppConfig
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.health.HealthConnectAvailability
import com.lasohealth.android.health.HealthConnectManager
import com.lasohealth.android.health.HealthConnectUiState
import com.lasohealth.android.ui.theme.AccentBlue
import kotlinx.coroutines.launch

@Composable
fun HealthConnectSetupCard(
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val manager = remember(context) { HealthConnectManager(context) }
    val scope = rememberCoroutineScope()
    var uiState by remember {
        mutableStateOf(
            HealthConnectUiState(
                availability = manager.availability(),
                permissionsGranted = false,
                statusText = "Checking Health Connect availability...",
            ),
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = manager.requestPermissionsContract(),
    ) { granted ->
        scope.launch {
            uiState = uiState.copy(
                permissionsGranted = granted.containsAll(manager.permissions),
                statusText = if (granted.containsAll(manager.permissions)) {
                    "Health Connect permissions granted."
                } else {
                    "Health Connect access is still incomplete."
                },
            )
            uiState = manager.buildUiState()
        }
    }

    LaunchedEffect(manager) {
        uiState = manager.buildUiState()
    }

    LasoCard(
        modifier = modifier,
        tint = AccentBlue,
    ) {
        Text(
            text = "Health Connect",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            modifier = Modifier.padding(top = 8.dp),
            text = uiState.statusText,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.74f),
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            when (uiState.availability) {
                HealthConnectAvailability.AVAILABLE -> {
                    Button(
                        onClick = {
                            if (uiState.permissionsGranted) {
                                manager.openSettings()
                            } else {
                                permissionLauncher.launch(manager.permissions)
                            }
                        },
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(if (uiState.permissionsGranted) "Manage Access" else "Connect")
                    }
                }

                HealthConnectAvailability.UPDATE_REQUIRED -> {
                    Button(
                        onClick = manager::openPlayStoreListing,
                        modifier = Modifier.weight(1f),
                    ) {
                        Text("Install / Update")
                    }
                }

                HealthConnectAvailability.UNAVAILABLE -> {
                    OutlinedButton(
                        onClick = manager::openPlayStoreListing,
                        modifier = Modifier.weight(1f),
                    ) {
                        Text("Learn More")
                    }
                }
            }

            OutlinedButton(
                onClick = {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(AndroidAppConfig.privacyPolicyUrl)),
                    )
                },
                modifier = Modifier.weight(1f),
            ) {
                Text("Privacy")
            }
        }
        Column(
            modifier = Modifier.padding(top = 12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = "Expected sources: heart rate, HRV, sleep, steps, activity calories, oxygen saturation, respiratory rate, hydration, workouts, and more.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
            )
            Text(
                text = "Support: ${AndroidAppConfig.supportEmail}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
            )
        }
    }
}
