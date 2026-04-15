package com.lasohealth.android.app

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lasohealth.android.ui.theme.AccentBlue

private const val PREFS_NAME = "laso_disclaimer"
private const val KEY_ACKNOWLEDGED = "disclaimer_acknowledged"

/**
 * Reads/writes the medical disclaimer acknowledgment flag to SharedPreferences.
 */
class DisclaimerPrefs(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var acknowledged: Boolean
        get() = prefs.getBoolean(KEY_ACKNOWLEDGED, false)
        set(value) = prefs.edit().putBoolean(KEY_ACKNOWLEDGED, value).apply()
}

/**
 * Full-screen medical disclaimer shown once on first launch.
 * Required for Play Store compliance (health app guidelines).
 * Non-dismissible until the user taps "I Understand".
 */
@Composable
fun MedicalDisclaimerScreen(
    onAcknowledge: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Icon(
            imageVector = Icons.Filled.MedicalServices,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = AccentBlue,
        )

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "Important Health Information",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "Laso is not a medical device. It gives you health information, " +
                "not medical advice. Always consult a qualified professional before " +
                "making health decisions.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "The scores, patterns, and insights in this app are based on your " +
                "health data and are for informational purposes only. They should not " +
                "be used as a substitute for professional health guidance.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = onAcknowledge,
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = AccentBlue,
            ),
        ) {
            Text(
                text = "I Understand",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}
