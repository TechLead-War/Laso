package com.lasohealth.android.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.LasoTheme

class PermissionsRationaleActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LasoTheme {
                PrivacyPolicyScreen(
                    onOpenPrivacyPolicy = {
                        startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(AndroidAppConfig.privacyPolicyUrl)),
                        )
                    },
                    onDone = ::finish,
                )
            }
        }
    }
}

@Composable
private fun PrivacyPolicyScreen(
    onOpenPrivacyPolicy: () -> Unit,
    onDone: () -> Unit,
) {
    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                text = "Privacy Policy",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Laso reads only the health data you explicitly allow through Health Connect. " +
                    "That data is used to compute recovery scores, trends, and coaching insights inside the app.",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = "Your health permissions can be revoked at any time in Health Connect settings. " +
                    "The Android app is set up to use local device storage and Firebase-backed services when configured.",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = "Full policy: ${AndroidAppConfig.privacyPolicyUrl}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f),
            )
            OutlinedButton(
                onClick = onOpenPrivacyPolicy,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Open Full Privacy Policy")
            }
            Button(
                onClick = onDone,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Done")
            }
        }
    }
}
