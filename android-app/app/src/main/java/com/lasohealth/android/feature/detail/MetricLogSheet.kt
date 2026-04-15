package com.lasohealth.android.feature.detail

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.ui.theme.AccentGreen
import kotlinx.coroutines.delay

// ── Input type classification ────────────────────────────────────────────────

private enum class MetricInputType { SLIDER, COUNT }

private fun HealthMetric.inputType(): MetricInputType = when (this) {
    HealthMetric.WEIGHT,
    HealthMetric.BODY_TEMPERATURE,
    HealthMetric.BODY_FAT_PERCENTAGE,
    HealthMetric.BMI,
    -> MetricInputType.SLIDER

    else -> MetricInputType.COUNT
}

private fun HealthMetric.sliderRange(): ClosedFloatingPointRange<Float> = when (this) {
    HealthMetric.WEIGHT -> 30f..250f
    HealthMetric.BODY_TEMPERATURE -> 35f..42f
    HealthMetric.BODY_FAT_PERCENTAGE -> 3f..60f
    HealthMetric.BMI -> 12f..50f
    else -> 0f..1000f
}

private fun HealthMetric.sliderStep(): Float = when (this) {
    HealthMetric.WEIGHT -> 0.1f
    HealthMetric.BODY_TEMPERATURE -> 0.1f
    HealthMetric.BODY_FAT_PERCENTAGE -> 0.1f
    HealthMetric.BMI -> 0.1f
    else -> 1f
}

private fun HealthMetric.defaultValue(): Float = when (this) {
    HealthMetric.WEIGHT -> 70f
    HealthMetric.BODY_TEMPERATURE -> 36.6f
    HealthMetric.BODY_FAT_PERCENTAGE -> 20f
    HealthMetric.BMI -> 23f
    HealthMetric.STEPS -> 0f
    HealthMetric.WATER_INTAKE -> 250f
    HealthMetric.MINDFUL_MINUTES -> 10f
    HealthMetric.ACTIVE_CALORIES -> 0f
    HealthMetric.EXERCISE_MINUTES -> 0f
    else -> 0f
}

private fun formatValue(metric: HealthMetric, value: Float): String {
    return when (metric.inputType()) {
        MetricInputType.SLIDER -> String.format("%.1f", value)
        MetricInputType.COUNT -> value.toInt().toString()
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MetricLogSheet
// ═══════════════════════════════════════════════════════════════════════════════

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MetricLogSheet(
    metric: HealthMetric,
    onDismiss: () -> Unit,
    onLog: (value: Float, notes: String) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var loggedSuccess by remember { mutableStateOf(false) }

    // Auto-dismiss after success
    LaunchedEffect(loggedSuccess) {
        if (loggedSuccess) {
            delay(1500L)
            onDismiss()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        AnimatedContent(
            targetState = loggedSuccess,
            transitionSpec = {
                (fadeIn() + scaleIn(initialScale = 0.85f))
                    .togetherWith(fadeOut())
            },
            label = "logSheetContent",
        ) { isSuccess ->
            if (isSuccess) {
                SuccessContent()
            } else {
                LogFormContent(
                    metric = metric,
                    onLog = { value, notes ->
                        onLog(value, notes)
                        loggedSuccess = true
                    },
                )
            }
        }
    }
}

// ── Success State ────────────────────────────────────────────────────────────

@Composable
private fun SuccessContent() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Filled.Check,
            contentDescription = "Logged",
            modifier = Modifier.size(48.dp),
            tint = AccentGreen,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "Logged",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = AccentGreen,
        )
    }
}

// ── Log Form ─────────────────────────────────────────────────────────────────

@Composable
private fun LogFormContent(
    metric: HealthMetric,
    onLog: (value: Float, notes: String) -> Unit,
) {
    var value by remember { mutableFloatStateOf(metric.defaultValue()) }
    var countText by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .padding(bottom = 32.dp),
    ) {
        // Title
        Text(
            text = "Log ${metric.displayName}",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(24.dp))

        when (metric.inputType()) {
            MetricInputType.SLIDER -> {
                SliderInput(
                    metric = metric,
                    value = value,
                    onValueChange = { value = it },
                )
            }

            MetricInputType.COUNT -> {
                CountInput(
                    metric = metric,
                    text = countText,
                    onTextChange = { countText = it },
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Notes field
        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            label = { Text("Notes (optional)") },
            modifier = Modifier.fillMaxWidth(),
            maxLines = 3,
            textStyle = MaterialTheme.typography.bodyMedium,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Log button
        Button(
            onClick = {
                val finalValue = when (metric.inputType()) {
                    MetricInputType.SLIDER -> value
                    MetricInputType.COUNT -> countText.toFloatOrNull() ?: 0f
                }
                onLog(finalValue, notes)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.onSurface,
                contentColor = MaterialTheme.colorScheme.surface,
            ),
        ) {
            Text(
                text = "Log",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
            )
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ── Slider Input ─────────────────────────────────────────────────────────────

@Composable
private fun SliderInput(
    metric: HealthMetric,
    value: Float,
    onValueChange: (Float) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Large value display
        Text(
            text = "${formatValue(metric, value)} ${metric.unit}",
            style = MaterialTheme.typography.displaySmall,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(16.dp))

        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = metric.sliderRange(),
            steps = ((metric.sliderRange().endInclusive - metric.sliderRange().start) / metric.sliderStep()).toInt() - 1,
            modifier = Modifier.fillMaxWidth(),
            colors = SliderDefaults.colors(
                thumbColor = MaterialTheme.colorScheme.onSurface,
                activeTrackColor = MaterialTheme.colorScheme.onSurface,
                inactiveTrackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f),
            ),
        )
    }
}

// ── Count Input ──────────────────────────────────────────────────────────────

@Composable
private fun CountInput(
    metric: HealthMetric,
    text: String,
    onTextChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = text,
        onValueChange = { newValue ->
            // Only accept numeric input
            if (newValue.isEmpty() || newValue.all { it.isDigit() || it == '.' }) {
                onTextChange(newValue)
            }
        },
        label = { Text("${metric.displayName} (${metric.unit})") },
        modifier = Modifier.fillMaxWidth(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        singleLine = true,
        textStyle = MaterialTheme.typography.headlineMedium.copy(
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        ),
        placeholder = {
            Text(
                text = "0",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
        },
    )
}
