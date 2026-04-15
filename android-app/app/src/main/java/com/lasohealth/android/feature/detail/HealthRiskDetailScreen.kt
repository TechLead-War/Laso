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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
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
import com.lasohealth.android.core.design.SectionHeading
import com.lasohealth.android.core.model.HealthRiskDetailUiState
import com.lasohealth.android.core.model.RiskFactorUi
import com.lasohealth.android.core.model.RiskFocusAreaUi
import com.lasohealth.android.ui.theme.AccentGreen
import com.lasohealth.android.ui.theme.AccentOrange
import com.lasohealth.android.ui.theme.AccentRed
import com.lasohealth.android.ui.theme.AccentYellow
import kotlin.math.cos
import kotlin.math.sin

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HealthRiskDetailScreen(
    state: HealthRiskDetailUiState,
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = state.riskName,
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
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(LasoTokens.SectionGap),
        ) {
            // 1. Risk Gauge
            item {
                RiskGaugeSection(
                    score = state.riskScore,
                    grade = state.riskGrade,
                )
            }

            // 2. Description
            item {
                Text(
                    text = state.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                )
            }

            // 3. Focus Areas
            if (state.focusAreas.isNotEmpty()) {
                item {
                    SectionHeading(title = "What to Focus On")
                }
                items(state.focusAreas) { area ->
                    FocusAreaCard(area = area)
                }
            }

            // 4. Contributing Factors
            item {
                SectionHeading(title = "Contributing Factors")
            }
            items(state.contributingFactors) { factor ->
                ContributingFactorRow(factor = factor)
            }

            // 5. Disclaimer
            item {
                DisclaimerBox()
            }

            // Bottom spacer
            item {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// region Risk Gauge

@Composable
private fun RiskGaugeSection(
    score: Int,
    grade: String,
) {
    val gradeColor = riskGradeColor(grade)
    val scoreFraction = (score / 100.0).coerceIn(0.0, 1.0)

    LasoCard(
        modifier = Modifier.fillMaxWidth(),
        tint = gradeColor,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(LasoTokens.CardPadding),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Arc gauge
            Box(
                modifier = Modifier.size(180.dp),
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.size(160.dp),
                ) {
                    val strokeWidth = 14.dp.toPx()
                    val arcSize = Size(size.width - strokeWidth, size.height - strokeWidth)
                    val topLeft = Offset(strokeWidth / 2f, strokeWidth / 2f)
                    val startAngle = 150f
                    val sweepAngle = 240f

                    // Background arc
                    drawArc(
                        color = Color.Gray.copy(alpha = 0.2f),
                        startAngle = startAngle,
                        sweepAngle = sweepAngle,
                        useCenter = false,
                        topLeft = topLeft,
                        size = arcSize,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                    )

                    // 4 colored segments (green -> yellow -> orange -> red)
                    val segments = listOf(
                        0.00f to 0.25f to AccentGreen,
                        0.25f to 0.50f to AccentYellow,
                        0.50f to 0.75f to AccentOrange,
                        0.75f to 1.00f to AccentRed,
                    )

                    for ((range, color) in segments) {
                        val (segStart, segEnd) = range
                        val segStartAngle = startAngle + segStart * sweepAngle
                        val segSweepAngle = (segEnd - segStart) * sweepAngle
                        val alpha = if (scoreFraction >= segStart) 1f else 0.3f

                        drawArc(
                            color = color.copy(alpha = alpha),
                            startAngle = segStartAngle,
                            sweepAngle = segSweepAngle,
                            useCenter = false,
                            topLeft = topLeft,
                            size = arcSize,
                            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                        )
                    }

                    // Needle indicator (white dot)
                    val needleAngle = Math.toRadians(
                        (startAngle + scoreFraction.toFloat() * sweepAngle).toDouble(),
                    )
                    val radius = (size.width - strokeWidth) / 2f
                    val centerX = size.width / 2f
                    val centerY = size.height / 2f
                    val needleX = centerX + radius * cos(needleAngle).toFloat()
                    val needleY = centerY + radius * sin(needleAngle).toFloat()
                    val dotRadius = 5.dp.toPx()

                    // Shadow
                    drawCircle(
                        color = Color.Black.copy(alpha = 0.2f),
                        radius = dotRadius + 1.dp.toPx(),
                        center = Offset(needleX, needleY + 1.dp.toPx()),
                    )
                    // White dot
                    drawCircle(
                        color = Color.White,
                        radius = dotRadius,
                        center = Offset(needleX, needleY),
                    )
                }

                // Center score text
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(top = 10.dp),
                ) {
                    Text(
                        text = "$score",
                        fontSize = 42.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = gradeColor,
                    )
                    Text(
                        text = "of 100",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    )
                }
            }

            // Grade badge
            Box(
                modifier = Modifier
                    .background(
                        color = gradeColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "$grade Risk",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Bold,
                    color = gradeColor,
                )
            }
        }
    }
}

// endregion

// region Focus Areas

@Composable
private fun FocusAreaCard(area: RiskFocusAreaUi) {
    val impactColor = impactColor(area.impact)

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(LasoTokens.CardPadding),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Impact badge
            Box(
                modifier = Modifier
                    .background(
                        color = impactColor.copy(alpha = LasoTokens.BadgeBgOpacity),
                        shape = RoundedCornerShape(20.dp),
                    )
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            ) {
                Text(
                    text = "${area.impact} Impact",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = impactColor,
                )
            }

            // Title
            Text(
                text = area.title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            // Description
            Text(
                text = area.description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 3,
            )
        }
    }
}

// endregion

// region Contributing Factors

@Composable
private fun ContributingFactorRow(factor: RiskFactorUi) {
    val statusIcon = if (factor.status == "ok") Icons.Filled.CheckCircle else Icons.Filled.Warning
    val statusColor = if (factor.status == "ok") AccentGreen else AccentOrange

    LasoCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(LasoTokens.CardPadding),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Status icon
            Icon(
                imageVector = statusIcon,
                contentDescription = factor.status,
                tint = statusColor,
                modifier = Modifier.size(24.dp),
            )

            // Content column
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                // Metric name + current value
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = factor.metricName,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        text = factor.currentValue,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }

                // Optimal range
                Text(
                    text = "Optimal: ${factor.optimalRange}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
                )

                // Risk contribution bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RiskContributionBar(
                        contribution = factor.riskContribution,
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "${(factor.riskContribution * 100).toInt()}%",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                        color = contributionBarColor(factor.riskContribution),
                    )
                }
            }

            // Chevron
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

@Composable
private fun RiskContributionBar(
    contribution: Float,
    modifier: Modifier = Modifier,
) {
    val barColor = contributionBarColor(contribution)
    val clampedContribution = contribution.coerceIn(0f, 1f)

    Box(
        modifier = modifier
            .height(6.dp)
            .clip(RoundedCornerShape(3.dp))
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(clampedContribution)
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(barColor),
        )
    }
}

// endregion

// region Disclaimer

@Composable
private fun DisclaimerBox() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = AccentOrange.copy(alpha = 0.08f),
                shape = RoundedCornerShape(12.dp),
            )
            .border(
                border = BorderStroke(1.dp, AccentOrange.copy(alpha = 0.3f)),
                shape = RoundedCornerShape(12.dp),
            )
            .clip(RoundedCornerShape(12.dp)),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                imageVector = Icons.Filled.Info,
                contentDescription = "Disclaimer",
                tint = AccentOrange,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = "This risk assessment is for informational purposes only and does not constitute medical advice. Always consult a healthcare professional for medical decisions.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}

// endregion

// region Helpers

private fun riskGradeColor(grade: String): Color = when (grade.lowercase()) {
    "low" -> AccentGreen
    "medium" -> AccentYellow
    "high" -> AccentOrange
    "critical" -> AccentRed
    else -> AccentYellow
}

private fun impactColor(impact: String): Color = when (impact.lowercase()) {
    "high" -> AccentRed
    "medium" -> AccentOrange
    "low" -> AccentYellow
    else -> AccentYellow
}

private fun contributionBarColor(contribution: Float): Color = when {
    contribution < 0.15f -> AccentGreen
    contribution < 0.35f -> AccentYellow
    contribution < 0.60f -> AccentOrange
    else -> AccentRed
}

private infix fun <A, B, C> Pair<A, B>.to(third: C): Pair<Pair<A, B>, C> = Pair(this, third)

// endregion
