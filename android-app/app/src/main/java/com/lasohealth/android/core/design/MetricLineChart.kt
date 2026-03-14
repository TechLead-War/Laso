package com.lasohealth.android.core.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun MetricLineChart(
    dataPoints: List<Float>,
    labels: List<String> = emptyList(),
    baselineValue: Float? = null,
    normalRangeMin: Float? = null,
    normalRangeMax: Float? = null,
    lineColor: Color = Color(0xFF007AFF),
    modifier: Modifier = Modifier,
) {
    if (dataPoints.isEmpty()) return

    val textMeasurer = rememberTextMeasurer()
    val labelColor = MaterialTheme.colorScheme.onSurfaceVariant
    val labelStyle = TextStyle(fontSize = 10.sp, color = labelColor)
    val surfaceColor = MaterialTheme.colorScheme.onSurface

    var selectedIndex by remember { mutableStateOf<Int?>(null) }
    var touchX by remember { mutableFloatStateOf(-1f) }

    Column(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .pointerInput(dataPoints) {
                    detectTapGestures(
                        onPress = { offset ->
                            touchX = offset.x
                            tryAwaitRelease()
                            selectedIndex = null
                            touchX = -1f
                        },
                    )
                }
                .pointerInput(dataPoints) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            selectedIndex = null
                            touchX = -1f
                        },
                        onHorizontalDrag = { change, _ ->
                            touchX = change.position.x
                            change.consume()
                        },
                    )
                },
        ) {
            Canvas(modifier = Modifier.matchParentSize()) {
                val chartPaddingTop = 8.dp.toPx()
                val chartPaddingBottom = if (labels.isNotEmpty()) 24.dp.toPx() else 8.dp.toPx()
                val chartPaddingH = 4.dp.toPx()

                val chartWidth = size.width - chartPaddingH * 2
                val chartHeight = size.height - chartPaddingTop - chartPaddingBottom

                val minVal = dataPoints.min()
                val maxVal = dataPoints.max()
                val valueRange = (maxVal - minVal).coerceAtLeast(1f)

                // Add 5% padding to value range
                val paddedMin = minVal - valueRange * 0.05f
                val paddedRange = valueRange * 1.1f

                fun valueToY(value: Float): Float {
                    return chartPaddingTop + chartHeight * (1f - (value - paddedMin) / paddedRange)
                }

                fun indexToX(index: Int): Float {
                    return if (dataPoints.size == 1) {
                        chartPaddingH + chartWidth / 2f
                    } else {
                        chartPaddingH + chartWidth * index / (dataPoints.size - 1).toFloat()
                    }
                }

                // Normal range area (green @ 5% opacity)
                if (normalRangeMin != null && normalRangeMax != null) {
                    val rangeTop = valueToY(normalRangeMax)
                    val rangeBottom = valueToY(normalRangeMin)
                    drawRect(
                        color = Color(0xFF4F8A62).copy(alpha = 0.05f),
                        topLeft = Offset(chartPaddingH, rangeTop),
                        size = Size(chartWidth, rangeBottom - rangeTop),
                    )
                }

                // Baseline dashed line
                if (baselineValue != null) {
                    val baseY = valueToY(baselineValue)
                    drawLine(
                        color = surfaceColor.copy(alpha = 0.3f),
                        start = Offset(chartPaddingH, baseY),
                        end = Offset(chartPaddingH + chartWidth, baseY),
                        strokeWidth = 1.dp.toPx(),
                        pathEffect = PathEffect.dashPathEffect(
                            floatArrayOf(6.dp.toPx(), 4.dp.toPx()),
                        ),
                    )
                }

                // Build smooth path using Catmull-Rom to cubic Bezier conversion
                val points = dataPoints.mapIndexed { i, v -> Offset(indexToX(i), valueToY(v)) }

                if (points.size >= 2) {
                    val linePath = Path()
                    val fillPath = Path()

                    linePath.moveTo(points[0].x, points[0].y)
                    fillPath.moveTo(points[0].x, chartPaddingTop + chartHeight)
                    fillPath.lineTo(points[0].x, points[0].y)

                    if (points.size == 2) {
                        linePath.lineTo(points[1].x, points[1].y)
                        fillPath.lineTo(points[1].x, points[1].y)
                    } else {
                        for (i in 0 until points.size - 1) {
                            val p0 = points[(i - 1).coerceAtLeast(0)]
                            val p1 = points[i]
                            val p2 = points[(i + 1).coerceAtMost(points.lastIndex)]
                            val p3 = points[(i + 2).coerceAtMost(points.lastIndex)]

                            val cp1x = p1.x + (p2.x - p0.x) / 6f
                            val cp1y = p1.y + (p2.y - p0.y) / 6f
                            val cp2x = p2.x - (p3.x - p1.x) / 6f
                            val cp2y = p2.y - (p3.y - p1.y) / 6f

                            linePath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
                            fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
                        }
                    }

                    // Close fill path along bottom
                    fillPath.lineTo(points.last().x, chartPaddingTop + chartHeight)
                    fillPath.close()

                    // Gradient fill (15% to 1% opacity)
                    drawPath(
                        path = fillPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                lineColor.copy(alpha = 0.15f),
                                lineColor.copy(alpha = 0.01f),
                            ),
                            startY = points.minOf { it.y },
                            endY = chartPaddingTop + chartHeight,
                        ),
                    )

                    // Line stroke
                    drawPath(
                        path = linePath,
                        color = lineColor,
                        style = Stroke(
                            width = 2.dp.toPx(),
                            cap = StrokeCap.Round,
                        ),
                    )
                }

                // Touch selection indicator
                if (touchX >= 0f) {
                    val stepWidth = if (dataPoints.size > 1)
                        chartWidth / (dataPoints.size - 1).toFloat() else chartWidth
                    val idx = ((touchX - chartPaddingH) / stepWidth)
                        .toInt()
                        .coerceIn(0, dataPoints.lastIndex)
                    selectedIndex = idx

                    val selX = indexToX(idx)
                    val selY = valueToY(dataPoints[idx])

                    // Vertical indicator line
                    drawLine(
                        color = surfaceColor.copy(alpha = 0.2f),
                        start = Offset(selX, chartPaddingTop),
                        end = Offset(selX, chartPaddingTop + chartHeight),
                        strokeWidth = 1.dp.toPx(),
                    )

                    // Selection dot
                    drawCircle(
                        color = lineColor,
                        radius = 5.dp.toPx(),
                        center = Offset(selX, selY),
                    )
                    drawCircle(
                        color = Color.White,
                        radius = 3.dp.toPx(),
                        center = Offset(selX, selY),
                    )

                    // Value label
                    val valueText = String.format("%.1f", dataPoints[idx])
                    val measuredText = textMeasurer.measure(
                        text = valueText,
                        style = TextStyle(fontSize = 11.sp, color = surfaceColor),
                    )
                    val labelX = (selX - measuredText.size.width / 2f)
                        .coerceIn(0f, size.width - measuredText.size.width)
                    drawText(
                        textLayoutResult = measuredText,
                        topLeft = Offset(labelX, selY - measuredText.size.height - 6.dp.toPx()),
                    )
                }

                // X-axis labels (adaptive: 4-6 labels)
                if (labels.isNotEmpty()) {
                    val maxLabels = 6.coerceAtMost(labels.size)
                    val step = if (labels.size <= maxLabels) 1
                    else (labels.size - 1) / (maxLabels - 1)

                    val indicesToDraw = if (labels.size <= maxLabels) {
                        labels.indices.toList()
                    } else {
                        (0 until maxLabels).map { i ->
                            (i * step).coerceAtMost(labels.lastIndex)
                        }.distinct()
                    }

                    val axisY = chartPaddingTop + chartHeight + 6.dp.toPx()
                    for (idx in indicesToDraw) {
                        if (idx < labels.size) {
                            val measured = textMeasurer.measure(labels[idx], labelStyle)
                            val lx = (indexToX(idx) - measured.size.width / 2f)
                                .coerceIn(0f, size.width - measured.size.width)
                            drawText(
                                textLayoutResult = measured,
                                topLeft = Offset(lx, axisY),
                            )
                        }
                    }
                }
            }
        }

        // Show selected value below chart
        selectedIndex?.let { idx ->
            val valueStr = String.format("%.1f", dataPoints[idx])
            val labelStr = if (idx < labels.size) " - ${labels[idx]}" else ""
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$valueStr$labelStr",
                style = MaterialTheme.typography.labelSmall,
                color = labelColor,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
        }
    }
}
