package com.lasohealth.android.feature.detail

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import kotlinx.coroutines.delay

// -- Breathing phase model --

private enum class BreathPhase(val label: String, val durationMs: Long, val targetScale: Float) {
    BREATHE_IN("Breathe In", 4_000L, 1.0f),
    HOLD("Hold", 7_000L, 1.0f),
    BREATHE_OUT("Breathe Out", 8_000L, 0.4f),
}

private enum class SessionState {
    IDLE, ACTIVE, PAUSED,
}

private val TealAccent = Color(0xFF00897B)
private val TealLight = Color(0xFF4DB6AC)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BreathworkScreen(navController: NavHostController) {
    var sessionState by remember { mutableStateOf(SessionState.IDLE) }
    var currentPhaseIndex by remember { mutableIntStateOf(0) }
    var phaseElapsedMs by remember { mutableLongStateOf(0L) }
    var totalElapsedMs by remember { mutableLongStateOf(0L) }
    var roundCount by remember { mutableIntStateOf(0) }

    val phases = BreathPhase.entries
    val currentPhase = phases[currentPhaseIndex]
    val phaseRemainingMs = (currentPhase.durationMs - phaseElapsedMs).coerceAtLeast(0L)
    val phaseRemainingSeconds = ((phaseRemainingMs + 999) / 1000).toInt()

    // Animated circle scale
    val targetScale = if (sessionState == SessionState.IDLE) 0.5f else currentPhase.targetScale
    val circleScale by animateFloatAsState(
        targetValue = targetScale,
        animationSpec = tween(
            durationMillis = if (sessionState == SessionState.IDLE) 600 else currentPhase.durationMs.toInt(),
            easing = EaseInOut,
        ),
        label = "circleScale",
    )

    // Timer loop
    LaunchedEffect(sessionState) {
        if (sessionState == SessionState.ACTIVE) {
            val tickMs = 50L
            while (sessionState == SessionState.ACTIVE) {
                delay(tickMs)
                phaseElapsedMs += tickMs
                totalElapsedMs += tickMs

                if (phaseElapsedMs >= currentPhase.durationMs) {
                    phaseElapsedMs = 0L
                    val nextIndex = (currentPhaseIndex + 1) % phases.size
                    if (nextIndex == 0) {
                        roundCount++
                    }
                    currentPhaseIndex = nextIndex
                }
            }
        }
    }

    // Background gradient
    val bgTop = TealAccent.copy(alpha = 0.06f)
    val bgBottom = MaterialTheme.colorScheme.background

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Breathwork",
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
                    containerColor = Color.Transparent,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(listOf(bgTop, bgBottom)),
                )
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(modifier = Modifier.weight(0.1f))

                // Phase instruction label
                val phaseLabel = if (sessionState == SessionState.IDLE) "Ready" else currentPhase.label
                val labelColor by animateColorAsState(
                    targetValue = TealAccent,
                    animationSpec = tween(300),
                    label = "phaseColor",
                )

                Text(
                    text = phaseLabel,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = labelColor,
                )

                Spacer(modifier = Modifier.height(24.dp))

                // Breathing circle with progress ring
                Box(
                    modifier = Modifier.size(240.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    // Session progress ring (outer)
                    if (sessionState != SessionState.IDLE) {
                        Canvas(modifier = Modifier.size(240.dp)) {
                            val sw = 4.dp.toPx()
                            val inset = sw / 2f
                            val diameter = size.minDimension - sw

                            // Track
                            drawArc(
                                color = TealAccent.copy(alpha = 0.12f),
                                startAngle = 0f,
                                sweepAngle = 360f,
                                useCenter = false,
                                topLeft = Offset(inset, inset),
                                size = Size(diameter, diameter),
                                style = Stroke(width = sw, cap = StrokeCap.Round),
                            )

                            // Phase progress
                            val phaseFraction = if (currentPhase.durationMs > 0) {
                                phaseElapsedMs.toFloat() / currentPhase.durationMs.toFloat()
                            } else 0f

                            drawArc(
                                color = TealAccent.copy(alpha = 0.35f),
                                startAngle = -90f,
                                sweepAngle = phaseFraction * 360f,
                                useCenter = false,
                                topLeft = Offset(inset, inset),
                                size = Size(diameter, diameter),
                                style = Stroke(width = sw, cap = StrokeCap.Round),
                            )
                        }
                    }

                    // Inner breathing circle
                    val circleSize = 200.dp * circleScale
                    Box(
                        modifier = Modifier
                            .size(circleSize)
                            .clip(CircleShape)
                            .background(
                                Brush.radialGradient(
                                    colors = listOf(
                                        TealAccent.copy(alpha = 0.4f),
                                        TealAccent.copy(alpha = 0.15f),
                                        TealAccent.copy(alpha = 0.05f),
                                    ),
                                ),
                            ),
                    )

                    // Circle border
                    Canvas(modifier = Modifier.size(circleSize)) {
                        drawCircle(
                            color = TealAccent.copy(alpha = 0.5f),
                            radius = size.minDimension / 2f,
                            style = Stroke(width = 2.dp.toPx()),
                        )
                    }

                    // Inner glow dot
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(TealAccent.copy(alpha = 0.6f)),
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Phase timer countdown
                if (sessionState != SessionState.IDLE) {
                    Text(
                        text = phaseRemainingSeconds.toString(),
                        fontSize = 48.sp,
                        fontWeight = FontWeight.Light,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Session elapsed timer
                    val totalSec = (totalElapsedMs / 1000).toInt()
                    val minutes = totalSec / 60
                    val seconds = totalSec % 60
                    Text(
                        text = String.format("%d:%02d", minutes, seconds),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    )

                    Spacer(modifier = Modifier.height(4.dp))

                    // Round counter
                    Text(
                        text = "Round $roundCount",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                // Controls
                when (sessionState) {
                    SessionState.IDLE -> {
                        Button(
                            onClick = {
                                sessionState = SessionState.ACTIVE
                                currentPhaseIndex = 0
                                phaseElapsedMs = 0L
                                totalElapsedMs = 0L
                                roundCount = 0
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = TealAccent,
                                contentColor = Color.White,
                            ),
                            shape = RoundedCornerShape(16.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = null,
                                modifier = Modifier.size(20.dp),
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Begin Session",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }

                    SessionState.ACTIVE, SessionState.PAUSED -> {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(32.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            // Stop button
                            IconButton(
                                onClick = {
                                    sessionState = SessionState.IDLE
                                    currentPhaseIndex = 0
                                    phaseElapsedMs = 0L
                                    totalElapsedMs = 0L
                                    roundCount = 0
                                },
                                modifier = Modifier
                                    .size(56.dp)
                                    .background(
                                        MaterialTheme.colorScheme.surfaceVariant,
                                        CircleShape,
                                    ),
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Stop,
                                    contentDescription = "Stop",
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                                )
                            }

                            // Play/Pause button
                            IconButton(
                                onClick = {
                                    sessionState = if (sessionState == SessionState.ACTIVE) {
                                        SessionState.PAUSED
                                    } else {
                                        SessionState.ACTIVE
                                    }
                                },
                                modifier = Modifier
                                    .size(72.dp)
                                    .background(TealAccent, CircleShape),
                            ) {
                                Icon(
                                    imageVector = if (sessionState == SessionState.PAUSED) {
                                        Icons.Default.PlayArrow
                                    } else {
                                        Icons.Default.Pause
                                    },
                                    contentDescription = if (sessionState == SessionState.PAUSED) "Resume" else "Pause",
                                    tint = Color.White,
                                    modifier = Modifier.size(32.dp),
                                )
                            }

                            // Spacer for symmetry
                            Spacer(modifier = Modifier.size(56.dp))
                        }
                    }
                }

                Spacer(modifier = Modifier.height(40.dp))
            }
        }
    }
}
