package com.lasohealth.android.feature.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lasohealth.android.core.referral.ReferralManager
import kotlinx.coroutines.launch

private val Purple = Color(0xFF8B5CF6)

@Composable
fun ReferralCodeStep(onContinue: () -> Unit) {
    val context = LocalContext.current
    val referralManager = remember { ReferralManager.getInstance(context) }
    val scope = rememberCoroutineScope()

    var codeInput by remember { mutableStateOf(TextFieldValue("")) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var successMessage by remember { mutableStateOf<String?>(null) }
    var isRedeeming by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.weight(1f))

        // Branding
        Text(
            text = "Laso",
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Gift icon in purple circle
        Box(
            modifier = Modifier
                .size(88.dp)
                .background(
                    color = Purple.copy(alpha = 0.12f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Filled.CardGiftcard,
                contentDescription = "Referral",
                modifier = Modifier.size(44.dp),
                tint = Purple,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // Title
        Text(
            text = "Have a Referral Code?",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )

        Spacer(modifier = Modifier.height(10.dp))

        // Subtitle
        Text(
            text = "If a friend shared their code with you, enter it below to unlock 30 days of Pro features for free.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp),
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Form card
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surface,
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                OutlinedTextField(
                    value = codeInput,
                    onValueChange = { newValue ->
                        codeInput = newValue
                        errorMessage = null
                        successMessage = null
                    },
                    label = { Text("Referral Code") },
                    placeholder = { Text("e.g. HEALTH-ABC123") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Purple,
                        focusedLabelColor = Purple,
                        cursorColor = Purple,
                    ),
                    isError = errorMessage != null,
                )

                // Error / success messages
                if (errorMessage != null) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = errorMessage!!,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                if (successMessage != null) {
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = successMessage!!,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color(0xFF4F8A62),
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Apply Code button
                Button(
                    onClick = {
                        val code = codeInput.text.trim()
                        if (code.isEmpty()) {
                            errorMessage = "Please enter a referral code"
                            return@Button
                        }
                        isRedeeming = true
                        errorMessage = null
                        successMessage = null
                        scope.launch {
                            val result = referralManager.redeemCode(code)
                            isRedeeming = false
                            when (result) {
                                is ReferralManager.RedeemResult.Success -> {
                                    successMessage = "Code applied! Your Pro access will activate when you subscribe."
                                    errorMessage = null
                                }
                                is ReferralManager.RedeemResult.Error -> {
                                    errorMessage = result.message
                                    successMessage = null
                                }
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isRedeeming,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Purple,
                    ),
                ) {
                    if (isRedeeming) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = Color.White,
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Text(
                            text = "Apply Code",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Skip / Continue button
        if (successMessage != null) {
            Button(
                onClick = onContinue,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
            ) {
                Text(
                    text = "Continue",
                    style = MaterialTheme.typography.headlineSmall,
                )
            }
        } else {
            TextButton(
                onClick = onContinue,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
            ) {
                Text(
                    text = "Skip",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f),
                )
            }
        }

        Spacer(modifier = Modifier.height(48.dp))
    }
}
