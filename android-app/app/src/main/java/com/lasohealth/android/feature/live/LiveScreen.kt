package com.lasohealth.android.feature.live

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
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
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FlightLand
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WaterDrop
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
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
import kotlin.math.min

// Colors matching iOS activity rings
private val RingPink = Color(0xFFFF2D55)
private val RingCyan = Color(0xFF00BCD4)
private val AccentPurple = Color(0xFF9C27B0)

// ── Live Screen ──────────────────────────────────────────────────────────────

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

        if (!state.hasAnyData) {
            // Empty state — waiting for data
            item { WaitingForDataView() }
        } else if (state.isStale && !state.isStreaming) {
            // Stale vitals prompt
            item { StaleVitalsPrompt(state = state) }
            item { ActivityRingsCard(state = state) }
            if (state.workout != null) {
                item { WorkoutCard(workout = state.workout, readinessScore = state.readinessScore) }
            }
            item { StatusFooter(label = state.lastUpdatedLabel) }
        } else {
            // Full live UI
            // 2. Heart Rate Hero Card
            item { HeartRateHeroCard(state = state) }

            // 3. Vitals Grid (SpO2 + Respiratory Rate)
            item { VitalsGrid(state = state) }

            // 4. Activity Rings Card
            item { ActivityRingsCard(state = state) }

            // 5. Blood Pressure + Temperature (conditional)
            if (state.systolic != null || state.bodyTemperature != null) {
                item { BloodPressureTempRow(state = state) }
            }

            // 6. Workout Card (conditional)
            if (state.workout != null) {
                item { WorkoutCard(workout = state.workout, readinessScore = state.readinessScore) }
            }

            // 7. Status Footer
            item { StatusFooter(label = state.lastUpdatedLabel) }
        }
    }
}

// ─── 1. Header Section ──────────────────────────────────────────────────────

@Composable
private fun LiveHeader(state: LiveUiState) {
    val dotColor = when {
        state.hasFreshData -> AccentGreen
        state.isAging -> AccentYellow
        state.isStale -> AccentOrange
        !state.hasAnyData -> Color.Gray
        else -> AccentOrange
    }

    val statusLabel = when {
        !state.hasAnyData -> "Waiting for data..."
        state.isStale -> "Data is stale"
        state.isStreaming && state.hasFreshData -> "Streaming"
        state.isAging -> "Updating..."
        else -> "Waiting for data..."
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "Live",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
            )
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
                Text(
                    text = statusLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }
        }
        Icon(
            imageVector = Icons.Filled.MonitorHeart,
            contentDescription = null,
            modifier = Modifier.size(28.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

// ─── Waiting For Data (Empty State) ─────────────────────────────────────────

@Composable
private fun WaitingForDataView() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.MonitorHeart,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Waiting for Live Data",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )

        Text(
            text = "Live heart rate, oxygen, and respiratory updates need a wearable source that syncs into Health.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 32.dp),
        )

        Text(
            text = "Fresh samples usually appear within a minute",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Tips card
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                WaitingTipRow(icon = Icons.Filled.MonitorHeart, text = "Wear your wearable and keep it nearby")
                WaitingTipRow(icon = Icons.Filled.Favorite, text = "Open the companion app or start a quick workout to generate a fresh sample")
                WaitingTipRow(icon = Icons.Filled.DateRange, text = "Return after the first wearable sync")
            }
        }
    }
}

@Composable
private fun WaitingTipRow(icon: ImageVector, text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = AccentBlue,
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.weight(1f),
        )
    }
}

// ─── Stale Vitals Prompt ────────────────────────────────────────────────────

@Composable
private fun StaleVitalsPrompt(state: LiveUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Device prompt
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    MaterialTheme.colorScheme.surfaceVariant,
                    RoundedCornerShape(14.dp),
                )
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.MonitorHeart,
                contentDescription = null,
                modifier = Modifier.size(28.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Live vitals data is stale",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = "Reopen the companion app or wear the device again to refresh live vitals.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    maxLines = 2,
                )
            }
        }

        // Last known readings
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.DateRange,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
                Text(
                    text = "Last Known Readings",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
            }
            Spacer(modifier = Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                if (state.currentHeartRate != null) {
                    StaleReadingPill(
                        icon = Icons.Filled.Favorite,
                        color = AccentRed,
                        value = "${state.currentHeartRate}",
                        unit = "bpm",
                    )
                }
                StaleReadingPill(
                    icon = Icons.Filled.WaterDrop,
                    color = AccentBlue,
                    value = if (state.bloodOxygen > 0) "${state.bloodOxygen}" else "—",
                    unit = if (state.bloodOxygen > 0) "%" else "",
                )
                StaleReadingPill(
                    icon = Icons.Filled.Air,
                    color = CategoryRespiratory,
                    value = if (state.respiratoryRate > 0.0) "${state.respiratoryRate.toInt()}" else "—",
                    unit = if (state.respiratoryRate > 0.0) "br/m" else "",
                )
            }
        }
    }
}

@Composable
private fun StaleReadingPill(
    icon: ImageVector,
    color: Color,
    value: String,
    unit: String,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = color.copy(alpha = 0.6f),
            )
            Row(
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                )
                Text(
                    text = unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                )
            }
        }
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

            HeartRateZoneBadge(zoneLabel = state.heartRateZoneLabel)
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Zone progress bar
        ZoneProgressBar(
            progress = state.heartRateZonePercent,
            zoneLabel = state.heartRateZoneLabel,
        )

        Spacer(modifier = Modifier.height(14.dp))

        // Session stats: Min/Avg/Max
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

        // Today range
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

            Spacer(modifier = Modifier.height(10.dp))
        }

        // 30-minute mini chart (iOS: Swift Charts line + area)
        if (state.recentHeartRates.size > 1) {
            HeartRateMiniChart(
                entries = state.recentHeartRates.map { it.minutesAgo to it.value },
            )
        }
    }
}

@Composable
private fun HeartRateMiniChart(
    entries: List<Pair<Int, Int>>,
) {
    val sortedEntries = entries.sortedBy { it.first }.reversed() // oldest first (highest minutesAgo)
    val minVal = (sortedEntries.minOfOrNull { it.second } ?: 60) - 5
    val maxVal = (sortedEntries.maxOfOrNull { it.second } ?: 160) + 5
    val range = (maxVal - minVal).coerceAtLeast(1).toFloat()
    val gridColor = MaterialTheme.colorScheme.onSurface
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant

    Column {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(80.dp),
        ) {
            val w = size.width
            val h = size.height
            val n = sortedEntries.size
            if (n < 2) return@Canvas

            // Horizontal dashed grid lines at BPM levels
            val gridBpmLevels = listOf(60, 80, 100, 120)
            gridBpmLevels.forEach { bpm ->
                if (bpm in minVal..maxVal) {
                    val gridY = h - ((bpm - minVal) / range) * h
                    val gridDashPath = Path().apply {
                        var gx = 0f
                        while (gx < w) {
                            moveTo(gx, gridY)
                            lineTo((gx + 4.dp.toPx()).coerceAtMost(w), gridY)
                            gx += 8.dp.toPx()
                        }
                    }
                    drawPath(
                        path = gridDashPath,
                        color = gridColor.copy(alpha = 0.08f),
                        style = Stroke(width = 1.dp.toPx()),
                    )
                }
            }

            val points = sortedEntries.mapIndexed { index, (_, value) ->
                val x = (index.toFloat() / (n - 1)) * w
                val y = h - ((value - minVal) / range) * h
                Offset(x, y)
            }

            // Area fill (red gradient, fading to transparent)
            val areaPath = Path().apply {
                moveTo(points.first().x, h)
                points.forEach { lineTo(it.x, it.y) }
                lineTo(points.last().x, h)
                close()
            }
            drawPath(
                path = areaPath,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        AccentRed.copy(alpha = 0.15f),
                        AccentRed.copy(alpha = 0.02f),
                    ),
                ),
            )

            // Line
            val linePath = Path().apply {
                moveTo(points.first().x, points.first().y)
                for (i in 1 until points.size) {
                    // Catmull-Rom-like smooth interpolation using cubic bezier
                    val prev = if (i > 0) points[i - 1] else points[i]
                    val curr = points[i]
                    val cpX = (prev.x + curr.x) / 2f
                    cubicTo(cpX, prev.y, cpX, curr.y, curr.x, curr.y)
                }
            }
            drawPath(
                path = linePath,
                color = AccentRed.copy(alpha = 0.7f),
                style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round),
            )
        }

        // Time axis labels
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            listOf("30m", "20m", "10m", "Now").forEach { label ->
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = labelColor,
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
        // Blood Oxygen card
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = AccentBlue,
        ) {
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
            Text(
                text = if (state.bloodOxygen > 0) "${state.bloodOxygen}%" else "—",
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(6.dp))
            if (state.bloodOxygen > 0) {
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
            } else {
                Text(
                    text = "No data",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                )
            }
        }

        // Respiratory Rate card
        LasoCard(
            modifier = Modifier.weight(1f),
            tint = CategoryRespiratory,
        ) {
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
            Text(
                text = if (state.respiratoryRate > 0.0) "${state.respiratoryRate.toInt()} br/min" else "—",
                style = MaterialTheme.typography.titleLarge.copy(
                    fontFamily = FontFamily.Monospace,
                ),
                fontWeight = FontWeight.Bold,
            )
            Spacer(modifier = Modifier.height(6.dp))
            if (state.respiratoryRate > 0.0) {
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
            } else {
                Text(
                    text = "No data",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                )
            }
        }
    }
}

// ─── 4. Activity Rings Card ─────────────────────────────────────────────────

@Composable
private fun ActivityRingsCard(state: LiveUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Activity Rings",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        // Main rings card
        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Triple concentric rings — Canvas
                Box(
                    modifier = Modifier.size(100.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Canvas(modifier = Modifier.size(100.dp)) {
                        val center = Offset(size.width / 2f, size.height / 2f)
                        val strokeWidth = 8.dp.toPx()
                        val startAngle = -90f

                        // Stand ring (outer) — cyan, 90dp diameter
                        val standRadius = 45.dp.toPx()
                        drawArc(
                            color = RingCyan.copy(alpha = 0.15f),
                            startAngle = 0f,
                            sweepAngle = 360f,
                            useCenter = false,
                            topLeft = Offset(center.x - standRadius, center.y - standRadius),
                            size = Size(standRadius * 2, standRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                        drawArc(
                            color = RingCyan,
                            startAngle = startAngle,
                            sweepAngle = 360f * min(state.activity.standProgress, 1f),
                            useCenter = false,
                            topLeft = Offset(center.x - standRadius, center.y - standRadius),
                            size = Size(standRadius * 2, standRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )

                        // Exercise ring (middle) — green, 70dp diameter
                        val exerciseRadius = 35.dp.toPx()
                        drawArc(
                            color = AccentGreen.copy(alpha = 0.15f),
                            startAngle = 0f,
                            sweepAngle = 360f,
                            useCenter = false,
                            topLeft = Offset(center.x - exerciseRadius, center.y - exerciseRadius),
                            size = Size(exerciseRadius * 2, exerciseRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                        drawArc(
                            color = AccentGreen,
                            startAngle = startAngle,
                            sweepAngle = 360f * min(state.activity.exerciseProgress, 1f),
                            useCenter = false,
                            topLeft = Offset(center.x - exerciseRadius, center.y - exerciseRadius),
                            size = Size(exerciseRadius * 2, exerciseRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )

                        // Move ring (inner) — pink, 50dp diameter
                        val moveRadius = 25.dp.toPx()
                        drawArc(
                            color = RingPink.copy(alpha = 0.15f),
                            startAngle = 0f,
                            sweepAngle = 360f,
                            useCenter = false,
                            topLeft = Offset(center.x - moveRadius, center.y - moveRadius),
                            size = Size(moveRadius * 2, moveRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                        drawArc(
                            color = RingPink,
                            startAngle = startAngle,
                            sweepAngle = 360f * min(state.activity.moveProgress, 1f),
                            useCenter = false,
                            topLeft = Offset(center.x - moveRadius, center.y - moveRadius),
                            size = Size(moveRadius * 2, moveRadius * 2),
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                    }
                }

                // Labels column
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    RingLabel(
                        color = RingPink,
                        label = "Move",
                        value = "${state.activity.activeCalories}/${state.activity.moveGoal} kcal",
                        progress = state.activity.moveProgress,
                    )
                    RingLabel(
                        color = AccentGreen,
                        label = "Exercise",
                        value = "${state.activity.exerciseMinutes}/${state.activity.exerciseGoal} min",
                        progress = state.activity.exerciseProgress,
                    )
                    RingLabel(
                        color = RingCyan,
                        label = "Stand",
                        value = "${state.activity.standHours}/${state.activity.standGoal} hrs",
                        progress = state.activity.standProgress,
                    )
                }
            }
        }

        // Quick stats row (Steps / Distance / Flights) — iOS quickStatPill
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
        ) {
            QuickStatPill(
                icon = Icons.AutoMirrored.Filled.DirectionsWalk,
                value = formatNumber(state.activity.steps),
                label = "Steps",
                color = AccentGreen,
                modifier = Modifier.weight(1f),
            )
            QuickStatPill(
                icon = Icons.Filled.LocationOn,
                value = String.format("%.1f km", state.activity.distance),
                label = "Distance",
                color = AccentBlue,
                modifier = Modifier.weight(1f),
            )
            QuickStatPill(
                icon = Icons.Filled.FlightLand,
                value = "${state.activity.flightsClimbed}",
                label = "Flights",
                color = AccentPurple,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun RingLabel(
    color: Color,
    label: String,
    value: String,
    progress: Float,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(color, CircleShape),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            modifier = Modifier.width(52.dp),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "${(progress * 100).toInt()}%",
            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.Bold,
            color = color,
        )
    }
}

@Composable
private fun QuickStatPill(
    icon: ImageVector,
    value: String,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(
                color = color.copy(alpha = LasoTokens.BadgeBgOpacity),
                shape = RoundedCornerShape(LasoTokens.CardRadius),
            )
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = color,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
        )
    }
}

private fun formatNumber(value: Int): String {
    return when {
        value >= 10_000 -> "${value / 1_000}k"
        value >= 1_000 -> String.format("%.1fk", value / 1_000.0)
        else -> value.toString()
    }
}

// ─── 5. Blood Pressure + Temperature ────────────────────────────────────────

@Composable
private fun BloodPressureTempRow(state: LiveUiState) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(LasoTokens.ItemGap),
    ) {
        if (state.systolic != null && state.diastolic != null) {
            LasoCard(modifier = Modifier.weight(1f)) {
                // Header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.MonitorHeart,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = AccentPurple,
                    )
                    Text(
                        text = "Blood Pressure",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                // Value
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = "${state.systolic}/${state.diastolic}",
                        style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Monospace),
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "mmHg",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.padding(bottom = 2.dp),
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
                // Status
                val bpColor = when (state.bloodPressureStatus) {
                    "Normal" -> AccentGreen
                    "Elevated" -> AccentYellow
                    "High" -> AccentOrange
                    else -> AccentGreen
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(bpColor, CircleShape),
                    )
                    Text(
                        text = state.bloodPressureStatus,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = bpColor,
                    )
                }
            }
        }

        if (state.bodyTemperature != null) {
            LasoCard(modifier = Modifier.weight(1f)) {
                // Header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Thermostat,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = AccentOrange,
                    )
                    Text(
                        text = "Temperature",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                // Value
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = String.format("%.1f", state.bodyTemperature),
                        style = MaterialTheme.typography.titleLarge.copy(fontFamily = FontFamily.Monospace),
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = "\u00B0C",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        modifier = Modifier.padding(bottom = 2.dp),
                    )
                }
            }
        }
    }
}

// ─── 6. Workout Card ────────────────────────────────────────────────────────

@Composable
private fun WorkoutCard(
    workout: com.lasohealth.android.core.model.WorkoutUi,
    readinessScore: Int,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
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
                        imageVector = Icons.AutoMirrored.Filled.DirectionsRun,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = AccentGreen,
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = workout.title,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
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

// ─── 7. Status Footer ───────────────────────────────────────────────────────

@Composable
private fun StatusFooter(label: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
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
