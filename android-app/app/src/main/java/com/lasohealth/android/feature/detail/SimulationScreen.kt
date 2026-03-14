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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Psychology
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.HealthScoreRing
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.CategorySleep

private data class SimulationState(
    val sleepDuration: Float = 7.5f,
    val exerciseMinutes: Float = 30f,
    val hrvChange: Float = 0f,
    val stressLevel: Float = 40f,
    val hasSimulated: Boolean = false,
    val currentScore: Int = 72,
    val predictedScore: Int = 72,
    val predictedState: String = "Good",
    val keyChanges: List<Pair<String, Boolean>> = emptyList(), // label to isPositive
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SimulationScreen(navController: NavHostController) {
    var simState by remember {
        mutableStateOf(
            SimulationState(
                currentScore = 72,
                keyChanges = emptyList(),
            ),
        )
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "What-If Simulator",
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
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Current State Card
            item {
                CurrentStateCard(score = simState.currentScore)
            }

            // 2. Adjustment Sliders
            item {
                SlidersSection(
                    simState = simState,
                    onStateChange = { simState = it },
                )
            }

            // 3. Simulate Button
            item {
                Button(
                    onClick = {
                        simState = runSimulation(simState)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = AccentBlue,
                        contentColor = Color.White,
                    ),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Text(
                        text = "Simulate",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            // 4. Predicted Outcome
            if (simState.hasSimulated) {
                item {
                    PredictedOutcomeSection(simState = simState)
                }
            }

            // 5. Disclaimer
            item {
                Text(
                    text = "Predictions are estimates based on your personal health patterns. " +
                        "They are not medical advice. Actual outcomes may differ based on many factors.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp),
                )
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region 1. Current State Card

@Composable
private fun CurrentStateCard(score: Int) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Current State")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Score ring
                HealthScoreRing(
                    score = score,
                    size = 72.dp,
                    strokeWidth = 8.dp,
                    label = "Score",
                )

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    CurrentMetricRow(label = "HRV", value = "45 ms")
                    CurrentMetricRow(label = "Sleep", value = "7.2 h")
                    CurrentMetricRow(label = "Strain", value = "12.4")
                }
            }
        }
    }
}

@Composable
private fun CurrentMetricRow(label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            fontFamily = FontFamily.Monospace,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

// endregion

// region 2. Sliders Section

@Composable
private fun SlidersSection(
    simState: SimulationState,
    onStateChange: (SimulationState) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Adjust Metrics")

        // Sleep Duration
        SimulationSlider(
            icon = Icons.Default.Bedtime,
            iconTint = CategorySleep,
            label = "Sleep Duration",
            value = simState.sleepDuration,
            valueLabel = String.format("%.1f h", simState.sleepDuration),
            range = 5f..10f,
            steps = 9,
            onValueChange = { onStateChange(simState.copy(sleepDuration = it)) },
            sliderColor = CategorySleep,
        )

        // Exercise Minutes
        SimulationSlider(
            icon = Icons.AutoMirrored.Filled.DirectionsRun,
            iconTint = AccentGreen,
            label = "Exercise Minutes",
            value = simState.exerciseMinutes,
            valueLabel = "${simState.exerciseMinutes.toInt()} min",
            range = 0f..120f,
            steps = 23,
            onValueChange = { onStateChange(simState.copy(exerciseMinutes = it)) },
            sliderColor = AccentGreen,
        )

        // HRV Change
        SimulationSlider(
            icon = Icons.Default.FavoriteBorder,
            iconTint = AccentRed,
            label = "HRV Change",
            value = simState.hrvChange,
            valueLabel = "${if (simState.hrvChange >= 0) "+" else ""}${simState.hrvChange.toInt()} ms",
            range = -20f..20f,
            steps = 39,
            onValueChange = { onStateChange(simState.copy(hrvChange = it)) },
            sliderColor = AccentRed,
        )

        // Stress Level
        SimulationSlider(
            icon = Icons.Default.Psychology,
            iconTint = AccentOrange,
            label = "Stress Level",
            value = simState.stressLevel,
            valueLabel = "${simState.stressLevel.toInt()}",
            range = 0f..100f,
            steps = 19,
            onValueChange = { onStateChange(simState.copy(stressLevel = it)) },
            sliderColor = AccentOrange,
        )
    }
}

@Composable
private fun SimulationSlider(
    icon: ImageVector,
    iconTint: Color,
    label: String,
    value: Float,
    valueLabel: String,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    onValueChange: (Float) -> Unit,
    sliderColor: Color,
) {
    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(18.dp),
                    )
                    Text(
                        text = label,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                    )
                }

                Text(
                    text = valueLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = range,
                steps = steps,
                colors = SliderDefaults.colors(
                    thumbColor = sliderColor,
                    activeTrackColor = sliderColor,
                    inactiveTrackColor = sliderColor.copy(alpha = 0.12f),
                ),
            )
        }
    }
}

// endregion

// region 3. Predicted Outcome

@Composable
private fun PredictedOutcomeSection(simState: SimulationState) {
    Column(verticalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap)) {
        SectionHeading(title = "Predicted Outcome")

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Score comparison
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Current
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        HealthScoreRing(
                            score = simState.currentScore,
                            size = 72.dp,
                            strokeWidth = 8.dp,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Current",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }

                    // Arrow with delta
                    val delta = simState.predictedScore - simState.currentScore
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            imageVector = when {
                                delta > 0 -> Icons.Default.ArrowUpward
                                delta < 0 -> Icons.Default.ArrowDownward
                                else -> Icons.AutoMirrored.Filled.ArrowForward
                            },
                            contentDescription = null,
                            tint = when {
                                delta > 0 -> AccentGreen
                                delta < 0 -> AccentRed
                                else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                            },
                            modifier = Modifier.size(24.dp),
                        )
                        if (delta != 0) {
                            Text(
                                text = "${if (delta > 0) "+" else ""}$delta",
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                fontFamily = FontFamily.Monospace,
                                color = if (delta > 0) AccentGreen else AccentRed,
                            )
                        }
                    }

                    // Predicted
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        HealthScoreRing(
                            score = simState.predictedScore,
                            size = 72.dp,
                            strokeWidth = 8.dp,
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Predicted",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        )
                    }
                }

                // Predicted state label
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(
                            LasoTokens.scoreColor(simState.predictedScore)
                                .copy(alpha = LasoTokens.BadgeBgOpacity),
                        )
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = simState.predictedState,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = LasoTokens.scoreColor(simState.predictedScore),
                    )
                }

                // Key changes
                if (simState.keyChanges.isNotEmpty()) {
                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    )

                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "Key Changes",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )

                        simState.keyChanges.forEach { (change, isPositive) ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Icon(
                                    imageVector = if (isPositive) Icons.Default.ArrowUpward else Icons.Default.ArrowDownward,
                                    contentDescription = null,
                                    tint = if (isPositive) AccentGreen else AccentRed,
                                    modifier = Modifier.size(16.dp),
                                )
                                Text(
                                    text = change,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// endregion

// region Simulation Logic

private fun runSimulation(state: SimulationState): SimulationState {
    // Simple simulation heuristic
    var scoreDelta = 0

    // Sleep: optimal around 7.5-8.5h
    val sleepDelta = when {
        state.sleepDuration >= 7.5f && state.sleepDuration <= 8.5f -> 3
        state.sleepDuration >= 7f -> 1
        state.sleepDuration < 6f -> -4
        else -> 0
    }
    scoreDelta += sleepDelta

    // Exercise: moderate is best
    val exerciseDelta = when {
        state.exerciseMinutes in 30f..60f -> 4
        state.exerciseMinutes in 15f..90f -> 2
        state.exerciseMinutes > 90f -> 0
        state.exerciseMinutes < 10f -> -2
        else -> 0
    }
    scoreDelta += exerciseDelta

    // HRV improvement
    val hrvDelta = when {
        state.hrvChange > 10 -> 3
        state.hrvChange > 0 -> 1
        state.hrvChange < -10 -> -3
        state.hrvChange < 0 -> -1
        else -> 0
    }
    scoreDelta += hrvDelta

    // Stress: lower is better
    val stressDelta = when {
        state.stressLevel < 20 -> 3
        state.stressLevel < 40 -> 1
        state.stressLevel > 70 -> -3
        state.stressLevel > 50 -> -1
        else -> 0
    }
    scoreDelta += stressDelta

    val predicted = (state.currentScore + scoreDelta).coerceIn(0, 100)
    val predictedLabel = LasoTokens.scoreLabel(predicted)

    val changes = mutableListOf<Pair<String, Boolean>>()
    if (sleepDelta != 0) {
        changes.add("Sleep quality ${if (sleepDelta > 0) "improved" else "declined"}" to (sleepDelta > 0))
    }
    if (exerciseDelta != 0) {
        changes.add("Exercise impact ${if (exerciseDelta > 0) "positive" else "negative"}" to (exerciseDelta > 0))
    }
    if (hrvDelta != 0) {
        changes.add("HRV ${if (hrvDelta > 0) "recovery improved" else "recovery declined"}" to (hrvDelta > 0))
    }
    if (stressDelta != 0) {
        changes.add("Stress ${if (stressDelta > 0) "level optimal" else "level elevated"}" to (stressDelta > 0))
    }

    return state.copy(
        hasSimulated = true,
        predictedScore = predicted,
        predictedState = predictedLabel,
        keyChanges = changes,
    )
}

// endregion
