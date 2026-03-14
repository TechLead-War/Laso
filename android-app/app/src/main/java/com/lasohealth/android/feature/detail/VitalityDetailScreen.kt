package com.lasohealth.android.feature.detail

import androidx.compose.animation.core.LinearEasing
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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.lasohealth.android.core.design.LasoCard
import com.lasohealth.android.core.design.LasoTokens
import com.lasohealth.android.core.model.MetricContributionUi
import com.lasohealth.android.core.model.VitalityDetailUiState
import com.lasohealth.android.core.model.VitalityImprovementUi
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

// iOS Vitality colors
private val VitalityGreen = Color(0xFF00D9B0)
private val VitalityCyan = Color(0xFF2DD4BF)
private val VitalityYellow = Color(0xFFF5C542)
private val VitalityRed = Color(0xFFFF4D4F)
private val VitalityOrange = Color(0xFFFF9500)

private fun paceTint(paceLabel: String): Color = when (paceLabel.lowercase()) {
    "healthy" -> VitalityGreen
    "caution" -> VitalityYellow
    "risk" -> VitalityRed
    else -> VitalityGreen
}

private fun deltaTint(delta: Int): Color = when {
    delta <= -3 -> VitalityGreen
    delta < 0 -> VitalityCyan
    delta == 0 -> Color(0xFF4879A7)
    delta <= 3 -> VitalityOrange
    else -> VitalityRed
}

// ── Screen ──────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VitalityDetailScreen(
    state: VitalityDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    val tint = paceTint(state.paceLabel)

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Vitality", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Hero with Orb
            item {
                VitalityHeroSection(
                    vitalityAge = state.vitalityAge,
                    biologicalAge = state.biologicalAge,
                    delta = state.delta,
                    paceLabel = state.paceLabel,
                    heroNarrative = state.heroNarrative,
                    tint = tint,
                )
            }

            // 2. Metric Contributions
            if (state.contributions.isNotEmpty()) {
                item {
                    VitalityMetricContributionSection(
                        contributions = state.contributions,
                        biologicalAge = state.biologicalAge,
                    )
                }
            }

            // 3. Trend Section
            if (state.trendHistory.size >= 2) {
                item {
                    VitalityTrendSection(
                        history = state.trendHistory,
                        biologicalAge = state.biologicalAge,
                        paceLabel = state.paceLabel,
                        vitalityAge = state.vitalityAge,
                        tint = tint,
                    )
                }
            }

            // 4. Improvement Opportunities
            if (state.improvements.isNotEmpty()) {
                item {
                    VitalityImprovementSection(improvements = state.improvements)
                }
            }

            // 5. How This Works
            item {
                VitalityMethodologySection(text = state.methodologyText)
            }
        }
    }
}

// ── 1. Hero Section with Animated Orb ────────────────────────────────────────

@Composable
private fun VitalityHeroSection(
    vitalityAge: Int,
    biologicalAge: Int,
    delta: Int,
    paceLabel: String,
    heroNarrative: String,
    tint: Color,
) {
    val dColor = deltaTint(delta)

    // Orb rotation animation — iOS: linear 18s infinite
    val infiniteTransition = rememberInfiniteTransition(label = "orb")
    val orbPhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(18_000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "orbPhase",
    )
    // Glow pulse — iOS: easeInOut 2.4s autoreverses
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.15f,
        targetValue = 0.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(2_400),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "glow",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            // iOS: black 95% background, cornerRadius 26
            .background(
                color = Color.Black.copy(alpha = 0.95f),
                shape = RoundedCornerShape(26.dp),
            )
            .padding(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // Orb + center content overlay
        Box(
            modifier = Modifier
                .fillMaxWidth(0.75f)
                .aspectRatio(1f),
            contentAlignment = Alignment.Center,
        ) {
            // Animated organic orb
            OrganicOrb(
                phase = orbPhase,
                glowAlpha = glowAlpha,
                tint = tint,
                modifier = Modifier.fillMaxSize(),
            )

            // Center content over orb
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // iOS: 56pt bold rounded, white, monospacedDigit
                Text(
                    text = vitalityAge.toString(),
                    fontSize = 56.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = Color.White,
                )
                // iOS: 13pt semibold, white 68%, letterSpacing 2pt
                Text(
                    text = "VITALITY AGE",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 2.sp,
                    color = Color.White.copy(alpha = 0.68f),
                )
                // Delta — iOS: title3 bold, pace tint, monospacedDigit
                if (delta != 0) {
                    val deltaText = if (delta <= 0) "${abs(delta)}y younger" else "${delta}y older"
                    Text(
                        text = deltaText,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = dColor,
                    )
                }
            }
        }

        // Badge row — iOS: HStack(spacing: 8)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Actual age badge
            VitalityBadge(
                text = "Age $biologicalAge",
                tint = Color.White.copy(alpha = 0.36f),
                textColor = Color.White,
            )
            Spacer(modifier = Modifier.width(8.dp))
            // Pace badge
            VitalityBadge(
                text = paceLabel,
                tint = tint.copy(alpha = 0.25f),
                textColor = tint,
                icon = true,
            )
        }

        // Hero narrative — iOS: subheadline, white 72%, centered
        if (heroNarrative.isNotEmpty()) {
            Text(
                text = heroNarrative,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.72f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 8.dp),
            )
        }
    }
}

@Composable
private fun VitalityBadge(
    text: String,
    tint: Color,
    textColor: Color,
    icon: Boolean = false,
) {
    Row(
        modifier = Modifier
            .background(tint, shape = RoundedCornerShape(20.dp))
            .padding(horizontal = 15.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (icon) {
            Icon(
                imageVector = Icons.Filled.CheckCircle,
                contentDescription = null,
                modifier = Modifier.size(12.dp),
                tint = textColor,
            )
        }
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = textColor,
        )
    }
}

// ── Organic Orb (Canvas-based particle system) ──────────────────────────────

private data class ParticleSeed(
    val x: Float, val y: Float, val size: Float,
    val speed: Float, val phase: Float, val drift: Float,
    val tintMix: Float, val alpha: Float,
)

@Composable
private fun OrganicOrb(
    phase: Float,
    glowAlpha: Float,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    // Pre-generate particles deterministically
    val particles = remember {
        (0 until 160).map { i ->
            val hash = { n: Float -> ((sin(n.toDouble()) * 43758.5453) % 1.0).toFloat().let { abs(it) } }
            val angle = hash(i * 1.1f) * 2f * PI.toFloat()
            val radius = hash(i * 2.3f).let { r ->
                if (r < 0.3f) r * 0.15f else 0.15f + (r - 0.3f) * 0.85f / 0.7f * 0.35f
            }
            ParticleSeed(
                x = 0.5f + cos(angle) * radius,
                y = 0.5f + sin(angle) * radius,
                size = if (hash(i * 3.7f) < 0.08f) 3.6f + hash(i * 4.1f) * 2.2f else 0.9f + hash(i * 5.3f) * 1.6f,
                speed = 0.06f + hash(i * 6.7f) * 0.09f,
                phase = hash(i * 7.1f) * 2f * PI.toFloat(),
                drift = 3.5f + hash(i * 8.9f) * 6f,
                tintMix = hash(i * 9.3f),
                alpha = 0.34f + hash(i * 10.7f) * 0.62f,
            )
        }
    }

    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val cx = w / 2f
        val cy = h / 2f
        val baseRadius = min(w, h) * 0.43f

        // Build blob clip path
        val blobPath = Path()
        val segments = 120
        for (i in 0..segments) {
            val t = (i.toFloat() / segments) * 2f * PI.toFloat()
            val wobbleA = 0.0675f * sin(t * 3 + phase)
            val wobbleB = 0.0405f * sin(t * 5 + phase * 1.7f)
            val wobbleC = 0.027f * cos(t * 2 - phase * 0.9f)
            val r = baseRadius * (1f + wobbleA + wobbleB + wobbleC)
            val px = cx + cos(t) * r
            val py = cy + sin(t) * r
            if (i == 0) blobPath.moveTo(px, py) else blobPath.lineTo(px, py)
        }
        blobPath.close()

        // Radial gradient background inside blob
        drawPath(
            path = blobPath,
            brush = Brush.radialGradient(
                colors = listOf(
                    Color(0xFF041215),
                    Color(0xFF051C21),
                    tint.copy(alpha = 0.22f),
                ),
                center = Offset(cx, cy * 0.96f),
                radius = max(w, h) * 0.66f,
            ),
        )

        // Draw particles
        val time = phase * 3f // speed up for visual effect
        particles.forEach { p ->
            val px = p.x * w + cos(time * p.speed + p.phase) * p.drift
            val py = p.y * h + sin(time * p.speed * 0.82f + p.phase) * p.drift
            // Only draw if inside blob (approximate: check distance from center)
            val dx = px - cx
            val dy = py - cy
            val dist = kotlin.math.sqrt(dx * dx + dy * dy)
            if (dist < baseRadius * 1.1f) {
                val color = if (p.tintMix < 0.44f) tint.copy(alpha = p.alpha) else Color.White.copy(alpha = p.alpha)
                drawCircle(color = color, radius = p.size, center = Offset(px, py))
                // Glow halo for larger particles
                if (p.size > 3f) {
                    drawCircle(color = color.copy(alpha = 0.12f), radius = p.size * 2.6f, center = Offset(px, py))
                }
            }
        }

        // Blob border stroke — iOS: tint 78%, lineWidth 1.4
        drawPath(
            path = blobPath,
            color = tint.copy(alpha = 0.78f),
            style = Stroke(width = 1.4.dp.toPx()),
        )

        // Glow stroke — iOS: tint with glowPulse alpha, lineWidth 14, blur
        drawPath(
            path = blobPath,
            color = tint.copy(alpha = glowAlpha),
            style = Stroke(width = 14.dp.toPx()),
            blendMode = BlendMode.Screen,
        )
    }
}

// ── 2. Metric Contributions ─────────────────────────────────────────────────

@Composable
private fun VitalityMetricContributionSection(
    contributions: List<MetricContributionUi>,
    biologicalAge: Int,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // iOS: vitalitySectionHeader(icon: "chart.bar.fill", title: "Metric Contributions")
        SectionHeader(
            icon = Icons.AutoMirrored.Filled.ShowChart,
            iconTint = VitalityGreen,
            title = "Metric Contributions",
        )

        // iOS: VStack(spacing: 0) with dividers inside cardStyle
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    MaterialTheme.colorScheme.surface,
                    RoundedCornerShape(LasoTokens.CardRadius),
                ),
        ) {
            contributions.forEachIndexed { index, contribution ->
                ContributionRow(
                    contribution = contribution,
                    biologicalAge = biologicalAge,
                )
                if (index < contributions.lastIndex) {
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 60.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                    )
                }
            }
        }
    }
}

@Composable
private fun ContributionRow(
    contribution: MetricContributionUi,
    biologicalAge: Int,
) {
    val categoryColor = contribution.metric?.category?.accentColor ?: VitalityGreen
    val ageDelta = contribution.delta
    val ageTint = deltaTint(ageDelta)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // Row: icon + name/subtitle + age/delta
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // iOS: 34x34 icon in colored rounded rect
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .background(
                        categoryColor.copy(alpha = 0.14f),
                        RoundedCornerShape(10.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (contribution.metric != null) {
                    Icon(
                        imageVector = contribution.metric.category.icon,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                        tint = categoryColor,
                    )
                }
            }

            // Name + subtitle
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = contribution.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = contribution.subtitle.ifEmpty { contribution.value },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                )
            }

            // Age label + delta
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                // iOS: caption bold monospacedDigit, tint color
                Text(
                    text = "${contribution.metricAge}y",
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    fontWeight = FontWeight.Bold,
                    color = ageTint,
                )
                // iOS: caption2 semibold
                val deltaLabel = if (ageDelta <= 0) "${ageDelta}y" else "+${ageDelta}y"
                Text(
                    text = deltaLabel,
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    fontWeight = FontWeight.SemiBold,
                    color = ageTint.copy(alpha = 0.85f),
                )
            }
        }

        // Gauge bar — iOS: gradient red→yellow→green with white marker
        GaugeBar(
            position = contribution.gaugePosition,
            tint = ageTint,
        )
    }
}

@Composable
private fun GaugeBar(
    position: Float,
    tint: Color,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(8.dp),
    ) {
        // Gradient background capsule
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(5.dp)
                .align(Alignment.Center)
                .clip(RoundedCornerShape(3.dp)),
        ) {
            drawRect(
                brush = Brush.horizontalGradient(
                    colors = listOf(
                        VitalityRed.copy(alpha = 0.8f),
                        VitalityYellow.copy(alpha = 0.8f),
                        VitalityGreen.copy(alpha = 0.85f),
                    ),
                ),
            )
        }

        // Marker dot — iOS: 8pt white circle at calculated position
        val clampedPos = position.coerceIn(0.02f, 0.98f)
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp),
        ) {
            val markerX = size.width * clampedPos
            val markerY = size.height / 2f
            // White outline
            drawCircle(
                color = Color.White.copy(alpha = 0.9f),
                radius = 5.dp.toPx(),
                center = Offset(markerX, markerY),
            )
            // Tint fill
            drawCircle(
                color = tint,
                radius = 3.5.dp.toPx(),
                center = Offset(markerX, markerY),
            )
        }
    }
}

// ── 3. Trend Section ────────────────────────────────────────────────────────

@Composable
private fun VitalityTrendSection(
    history: List<Float>,
    biologicalAge: Int,
    paceLabel: String,
    vitalityAge: Int,
    tint: Color,
) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionHeader(
            icon = Icons.AutoMirrored.Filled.TrendingUp,
            iconTint = tint,
            title = "90-Day Trend",
        )

        LasoCard(
            modifier = Modifier.fillMaxWidth(),
            tint = tint,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Chart
                VitalityTrendChart(
                    history = history,
                    biologicalAge = biologicalAge.toFloat(),
                    tint = tint,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                )

                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))

                // Stats row — iOS: 3 stats with dividers
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    val change = if (history.size >= 2) (history.last() - history.first()).toInt() else 0
                    val changeText = if (change <= 0) "${change}y" else "+${change}y"

                    TrendStat("90D CHANGE", changeText, deltaTint(change))
                    TrendStat("PACE", paceLabel, tint)
                    TrendStat("CURRENT", "${vitalityAge}y", tint)
                }
            }
        }
    }
}

@Composable
private fun VitalityTrendChart(
    history: List<Float>,
    biologicalAge: Float,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val padding = 8.dp.toPx()

        val allValues = history + biologicalAge
        val minVal = allValues.min() - 2f
        val maxVal = allValues.max() + 2f
        val range = (maxVal - minVal).coerceAtLeast(1f)

        fun yPos(value: Float): Float = padding + (h - 2 * padding) * (1f - (value - minVal) / range)

        // Baseline rule mark — iOS: red 45%, dashed
        val baselineY = yPos(biologicalAge)
        drawLine(
            color = VitalityRed.copy(alpha = 0.45f),
            start = Offset(padding, baselineY),
            end = Offset(w - padding, baselineY),
            strokeWidth = 1.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(
                floatArrayOf(5.dp.toPx(), 4.dp.toPx()),
            ),
        )

        // Build line path
        val linePath = Path()
        val fillPath = Path()
        history.forEachIndexed { i, value ->
            val x = padding + (w - 2 * padding) * i / (history.size - 1).coerceAtLeast(1)
            val y = yPos(value)
            if (i == 0) {
                linePath.moveTo(x, y)
                fillPath.moveTo(x, y)
            } else {
                linePath.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
        }

        // Fill area between line and baseline
        val lastX = padding + (w - 2 * padding)
        val firstX = padding
        fillPath.lineTo(lastX, baselineY)
        fillPath.lineTo(firstX, baselineY)
        fillPath.close()

        drawPath(
            path = fillPath,
            color = tint.copy(alpha = 0.16f),
        )

        // Trend line — iOS: 2.5pt catmullRom
        drawPath(
            path = linePath,
            color = tint,
            style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round),
        )

        // Latest point marker
        if (history.isNotEmpty()) {
            val lastValue = history.last()
            val lx = padding + (w - 2 * padding)
            val ly = yPos(lastValue)
            drawCircle(tint, radius = 4.dp.toPx(), center = Offset(lx, ly))
            drawCircle(Color.White, radius = 2.dp.toPx(), center = Offset(lx, ly))
        }
    }
}

@Composable
private fun TrendStat(label: String, value: String, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            fontWeight = FontWeight.Bold,
            color = color,
        )
    }
}

// ── 4. Improvement Opportunities ────────────────────────────────────────────

@Composable
private fun VitalityImprovementSection(improvements: List<VitalityImprovementUi>) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionHeader(
            icon = Icons.Filled.Lightbulb,
            iconTint = VitalityOrange,
            title = "Top Improvements",
        )

        improvements.forEach { item ->
            ImprovementCard(item)
        }
    }
}

@Composable
private fun ImprovementCard(item: VitalityImprovementUi) {
    // iOS: cardStyle(tint: .orange)
    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = VitalityOrange,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                // iOS: orange icon in 30x30 rounded rect
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .background(
                            VitalityOrange.copy(alpha = 0.14f),
                            RoundedCornerShape(9.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Lightbulb,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = VitalityOrange,
                    )
                }

                Text(
                    text = item.metricName,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )

                // iOS: impact badge "+Xy" in orange capsule
                Box(
                    modifier = Modifier
                        .background(VitalityOrange, RoundedCornerShape(20.dp))
                        .padding(horizontal = 14.dp, vertical = 5.dp),
                ) {
                    Text(
                        text = "+${item.impactYears}y",
                        style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                }
            }

            Text(
                text = item.description,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// ── 5. Methodology ──────────────────────────────────────────────────────────

@Composable
private fun VitalityMethodologySection(text: String) {
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SectionHeader(
            icon = Icons.Filled.Info,
            iconTint = MaterialTheme.colorScheme.primary,
            title = "How This Works",
        )

        LasoCard(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
        }
    }
}

// ── Shared: Section Header ──────────────────────────────────────────────────

@Composable
private fun SectionHeader(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = iconTint,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )
    }
}
