package com.lasohealth.android.feature.live

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.CellTower
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.LiveUiState
import com.lasohealth.android.ui.theme.AccentBlue
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import com.lasohealth.android.ui.theme.CategoryRespiratory

// ── Live Screen ──────────────────────────────────────────────────────────────
// Mirrors the iOS Live tab layout: header, heart-rate hero, vitals grid,
// activity card, conditional workout card, status footer.

@Composable
fun LiveScreen(
    state: LiveUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
    ) {
        // 1. Header
        item { LiveHeader(state = state) }

        // 2. Heart Rate Hero Card
        item { HeartRateHeroCard(state = state) }

        // 3. Vitals Grid (SpO2 + Respiratory Rate)
        item { VitalsGrid(state = state) }

        // 4. Activity Card
        item { ActivityCard(state = state) }

        // 5. Workout Card (conditional)
        if (state.workout != null) {
            item { WorkoutCard(workout = state.workout, readinessScore = state.readinessScore) }
        }

        // 6. Status Footer
        item { StatusFooter(label = state.lastUpdatedLabel) }
    }
}

// ─── 1. Header Section ──────────────────────────────────────────────────────

@Composable
private fun LiveHeader(state: LiveUiState) {
    // iOS: HStack { VStack(title + status) | Spacer | device icon }
    val dotColor = when {
        state.hasFreshData -> AccentGreen
        state.isAging -> AccentYellow
        else -> AccentOrange
    }

    val statusLabel = when {
        state.isStreaming && state.hasFreshData -> "Streaming"
        state.isAging -> "Updating..."
        else -> "Waiting for data..."
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Left: title + status row below (iOS VStack spacing: 4)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // iOS: .largeTitle.bold()
            Text(
                text = "Live",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
            )

            // Status dot + label (iOS: HStack spacing: 6)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .shadow(
                            elevation = if (state.hasFreshData) 4.dp else 0.dp,
                            shape = CircleShape,
                            ambientColor = if (state.hasFreshData) AccentGreen.copy(alpha = 0.6f) else Color.Transparent,
                            spotColor = if (state.hasFreshData) AccentGreen.copy(alpha = 0.6f) else Color.Transparent,
                        )
                        .background(color = dotColor, shape = CircleShape),
                )
                // iOS: .caption, .secondary
                Text(
                    text = statusLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }

        // Right: device icon (iOS: waveform.path.ecg, .title2, .secondary)
        Icon(
            imageVector = Icons.Filled.MonitorHeart,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// ─── 2. Heart Rate Hero Card ─────────────────────────────────────────────────

@Composable
private fun HeartRateHeroCard(state: LiveUiState) {
    val infiniteTransition = rememberInfiniteTransition(label = "heartPulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 800),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseScale",
    )

    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = AccentRed,
    ) {
        // Top row: pulsing heart + HR value + zone badge
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Pulsing heart icon — 64dp circle, red bg 0.1f, heart 32dp
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .scale(if (state.currentHeartRate != null) pulseScale else 1f)
                    .background(
                        color = AccentRed.copy(alpha = 0.1f),
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Favorite,
                    contentDescription = "Heart",
                    modifier = Modifier.size(32.dp),
                    tint = AccentRed,
                )
            }

            // HR value (52sp, bold, Monospace) + "bpm" inline (iOS: firstTextBaseline alignment)
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.Start,
            ) {
                if (state.currentHeartRate != null) {
                    Row(
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = state.currentHeartRate.toString(),
                            style = MaterialTheme.typography.displaySmall.copy(
                                fontSize = 52.sp,
                                fontFamily = FontFamily.Monospace,
                            ),
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = "bpm",
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            modifier = Modifier.padding(bottom = 8.dp),
                        )
                    }
                } else {
                    Text(
                        text = "Syncing",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    )
                }
            }

            // Zone badge capsule (white text on zoneColor bg)
            HeartRateZoneBadge(zoneLabel = state.heartRateZoneLabel)
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Zone progress bar — 8dp height
        ZoneProgressBar(
            progress = state.heartRateZonePercent,
            zoneLabel = state.heartRateZoneLabel,
        )

        Spacer(modifier = Modifier.height(14.dp))

        // Session stats: 3-column Min/Avg/Max with vertical dividers
        if (state.heartRateMin != null || state.heartRateAvg != null || state.heartRateMax != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(IntrinsicSize.Min),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SessionStatCell(
                    label = "Min",
                    value = state.heartRateMin?.toString(),
                    valueColor = AccentBlue,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .padding(vertical = 4.dp)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
                )
                SessionStatCell(
                    label = "Avg",
                    value = state.heartRateAvg?.toString(),
                    valueColor = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .padding(vertical = 4.dp)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)),
                )
                SessionStatCell(
                    label = "Max",
                    value = state.heartRateMax?.toString(),
                    valueColor = AccentRed,
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(10.dp))
        }

        // Today range: calendar icon + "Today: XX-XX bpm" (iOS matched)
        if (state.todayHeartRateMin != null && state.todayHeartRateMax != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.DateRange,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
                Text(
                    text = "Today: ${state.todayHeartRateMin}\u2013${state.todayHeartRateMax} bpm",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
            }
        }
    }
}

@Composable
private fun HeartRateZoneBadge(zoneLabel: String) {
    val zoneColor = heartRateZoneColor(zoneLabel)

    Text(
        text = zoneLabel,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = Color.White,
        modifier = Modifier
            .background(
                color = zoneColor,
                shape = RoundedCornerShape(50),
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun ZoneProgressBar(
    progress: Float,
    zoneLabel: String,
) {
    val clampedProgress = progress.coerceIn(0f, 1f)
    val zoneColor = heartRateZoneColor(zoneLabel)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(8.dp)
            .clip(RoundedCornerShape(4.dp)),
    ) {
        // Background gradient bar (blue->green->yellow->red at 0.2f alpha)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
                .background(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            AccentBlue.copy(alpha = 0.2f),
                            AccentGreen.copy(alpha = 0.2f),
                            AccentYellow.copy(alpha = 0.2f),
                            AccentRed.copy(alpha = 0.2f),
                        ),
                    ),
                    shape = RoundedCornerShape(4.dp),
                ),
        )

        // Active fill gradient (blue->zoneColor)
        if (clampedProgress > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(clampedProgress)
                    .height(8.dp)
                    .background(
                        brush = Brush.horizontalGradient(
                            colors = listOf(AccentBlue, zoneColor),
                        ),
                        shape = RoundedCornerShape(4.dp),
                    ),
            )
        }

        // White dot indicator at end
        if (clampedProgress > 0f) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(clampedProgress)
                    .height(8.dp),
                contentAlignment = Alignment.CenterEnd,
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .shadow(
                            elevation = 3.dp,
                            shape = CircleShape,
                            ambientColor = zoneColor.copy(alpha = 0.5f),
                        )
                        .background(Color.White, shape = CircleShape),
                )
            }
        }
    }
}

@Composable
private fun SessionStatCell(
    label: String,
    value: String?,
    valueColor: Color = Color.Unspecified,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        // Value + "bpm" (iOS: firstTextBaseline alignment, colored)
        if (value != null) {
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        fontFamily = FontFamily.Monospace,
                    ),
                    fontWeight = FontWeight.Bold,
                    color = valueColor,
                )
                Text(
                    text = "bpm",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
            }
        } else {
            Text(
                text = "\u00B7\u00B7\u00B7",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f),
            )
        }
        // Label below value
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )
    }
}

private fun heartRateZoneColor(zoneLabel: String): Color {
    val lower = zoneLabel.lowercase()
    return when {
        lower.contains("recovery") || lower.contains("rest") -> AccentBlue
        lower.contains("aerobic") || lower.contains("fat") || lower.contains("warm") -> AccentGreen
        lower.contains("threshold") || lower.contains("tempo") -> AccentYellow
        lower.contains("peak") || lower.contains("max") || lower.contains("anaerobic") -> AccentRed
        else -> AccentGreen
    }
}

// ─── 3. Vitals Grid ──────────────────────────────────────────────────────────

@Composable
private fun VitalsGrid(state: LiveUiState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        // Blood Oxygen card — tint=AccentBlue
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = AccentBlue,
        ) {
            // WaterDrop icon in 28dp blue circle + "Blood Oxygen" label
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .background(
                            color = AccentBlue.copy(alpha = 0.15f),
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.WaterDrop,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = AccentBlue,
                    )
                }
                Text(
                    text = "Blood Oxygen",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
            Spacer(modifier = Modifier.height(10.dp))
            // Value "XX%" (titleLarge Monospace bold)
            Text(
                text = "${state.bloodOxygen}%",
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(6.dp))
            // Status dot + "Normal"/"Low" colored text
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                val isNormal = state.bloodOxygen >= 95
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .background(
                            color = if (isNormal) AccentGreen else AccentOrange,
                            shape = CircleShape,
                        ),
                )
                Text(
                    text = if (isNormal) "Normal" else "Low",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isNormal) AccentGreen else AccentOrange,
                )
            }
        }

        // Respiratory Rate card — tint=CategoryRespiratory
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = CategoryRespiratory,
        ) {
            // Air icon in 28dp teal circle + "Respiratory Rate" label
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .background(
                            color = CategoryRespiratory.copy(alpha = 0.15f),
                            shape = CircleShape,
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Air,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = CategoryRespiratory,
                    )
                }
                Text(
                    text = "Respiratory Rate",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
            Spacer(modifier = Modifier.height(10.dp))
            // Value "XX br/min" (titleLarge Monospace bold)
            Text(
                text = "${state.respiratoryRate.toInt()} br/min",
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(6.dp))
            // Status dot + "Normal"/"Abnormal" colored text
            val isNormal = state.respiratoryRate in 12.0..20.0
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .background(
                            color = if (isNormal) AccentGreen else AccentOrange,
                            shape = CircleShape,
                        ),
                )
                Text(
                    text = if (isNormal) "Normal" else "Abnormal",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isNormal) AccentGreen else AccentOrange,
                )
            }
        }
    }
}

// ─── 4. Activity Card ────────────────────────────────────────────────────────

@Composable
private fun ActivityCard(state: LiveUiState) {
    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = AccentGreen,
    ) {
        // "Activity Rings" title (matching iOS .headline)
        Text(
            text = "Activity Rings",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        Spacer(modifier = Modifier.height(LasoTokens.ItemGap))

        // 4 rows with HorizontalDivider between
        ActivityStatRow(
            icon = Icons.Filled.DirectionsWalk,
            iconColor = AccentGreen,
            label = "Steps",
            value = formatNumber(state.activity.steps),
        )
        ActivityDivider()
        ActivityStatRow(
            icon = Icons.Filled.LocalFireDepartment,
            iconColor = AccentOrange,
            label = "Active Calories",
            value = "${state.activity.activeCalories} kcal",
        )
        ActivityDivider()
        ActivityStatRow(
            icon = Icons.Filled.Timer,
            iconColor = AccentBlue,
            label = "Exercise Minutes",
            value = "${state.activity.exerciseMinutes} min",
        )
        ActivityDivider()
        ActivityStatRow(
            icon = Icons.Filled.DirectionsRun,
            iconColor = MaterialTheme.colorScheme.primary,
            label = "Stand Hours",
            value = "${state.activity.standHours} hrs",
        )
    }
}

@Composable
private fun ActivityStatRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = iconColor,
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium.copy(
                fontFamily = FontFamily.Monospace,
            ),
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun ActivityDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(vertical = 2.dp),
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
    )
}

private fun formatNumber(value: Int): String {
    return when {
        value >= 10_000 -> "${value / 1_000}k"
        value >= 1_000 -> String.format("%.1fk", value / 1_000.0)
        else -> value.toString()
    }
}

// ─── 5. Workout Card (conditional) — matches iOS LiveWorkoutSection ─────────

@Composable
private fun WorkoutCard(
    workout: com.lasohealth.android.core.model.WorkoutUi,
    readinessScore: Int,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // iOS: "Last Workout" heading (.headline)
        Text(
            text = "Last Workout",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // iOS: Figure icon in green badge (DS.iconSize circle)
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(
                            color = AccentGreen.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(10.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.DirectionsRun,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = AccentGreen,
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    // Workout type (.subheadline.weight(.semibold))
                    Text(
                        text = workout.title,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    // Duration + calories row (.caption.monospacedDigit())
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Timer,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp),
                                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            )
                            Text(
                                text = "${workout.durationMinutes} min",
                                style = MaterialTheme.typography.bodySmall.copy(
                                    fontFamily = FontFamily.Monospace,
                                ),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            )
                        }
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.LocalFireDepartment,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp),
                                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                            )
                            Text(
                                text = workout.strainLabel,
                                style = MaterialTheme.typography.bodySmall.copy(
                                    fontFamily = FontFamily.Monospace,
                                ),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                            )
                        }
                    }
                }
            }
        }
    }
}

// ─── 6. Status Footer ───────────────────────────────────────────────────────

@Composable
private fun StatusFooter(label: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        // iOS: HStack(spacing: 6) { antenna icon + "Last signal X ago" } .caption2, .tertiary
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.CellTower,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
            )
        }
    }
}
