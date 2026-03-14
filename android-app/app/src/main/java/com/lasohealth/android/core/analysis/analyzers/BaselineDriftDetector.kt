package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs

/**
 * Detects when a metric's personal baseline has drifted significantly over time.
 *
 * Compares recent averages against historical windows (30d, 90d, 180d, 365d) to find
 * gradual shifts that daily anomaly detection misses. Also identifies co-drifting metrics.
 *
 * Ported from iOS BaselineDriftDetector.swift.
 */
class BaselineDriftDetector : InsightAnalyzer {

    override val name: String = "BaselineDriftDetector"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        // Build drift results for all metrics first (to find co-drifting metrics)
        val driftResults = mutableMapOf<HealthMetric, DriftResult>()
        for ((metric, samples) in context.timeSeries) {
            if (samples.size < 30) continue
            val baseline = context.baselines[metric] ?: continue
            computeDrift(metric, baseline, samples)?.let { driftResults[metric] = it }
        }

        // Generate insights with co-drift context
        for ((metric, samples) in context.timeSeries) {
            if (samples.size < 30) continue
            val baseline = context.baselines[metric] ?: continue
            detectDrift(metric, baseline, samples, driftResults)?.let { insights += it }
        }

        return insights
    }

    // ----- Models -----

    private data class DriftResult(
        val percent: Double,
        val label: String,
    )

    // ----- Comparison Windows -----

    private data class ComparisonWindow(val days: Int, val label: String, val threshold: Double)

    private val windows = listOf(
        ComparisonWindow(30, "month", 8.0),
        ComparisonWindow(90, "3 months", 6.0),
        ComparisonWindow(180, "6 months", 5.0),
        ComparisonWindow(365, "year", 5.0),
    )

    // ----- Drift Computation -----

    private fun computeDrift(
        metric: HealthMetric,
        currentBaseline: MetricBaseline,
        samples: List<DailySample>,
    ): DriftResult? {
        val now = System.currentTimeMillis()
        var bestDrift: DriftResult? = null

        for (window in windows) {
            val cutoff = now - window.days.toLong() * DAY_MS
            val olderSamples = samples.filter { it.date <= cutoff }
            if (olderSamples.size < 7) continue

            val oldMean = olderSamples.map { it.value }.average()
            if (abs(oldMean) < 0.001) continue

            val drift = ((currentBaseline.mean - oldMean) / abs(oldMean)) * 100.0
            if (abs(drift) <= window.threshold) continue

            if (bestDrift == null || abs(drift) > abs(bestDrift.percent) * 0.8) {
                bestDrift = DriftResult(drift, window.label)
            }
        }
        return bestDrift
    }

    // ----- Insight Generation -----

    private fun detectDrift(
        metric: HealthMetric,
        currentBaseline: MetricBaseline,
        samples: List<DailySample>,
        allDriftResults: Map<HealthMetric, DriftResult>,
    ): AnalysisInsight? {
        val now = System.currentTimeMillis()
        var bestDrift: Triple<Double, String, Double>? = null // percent, label, oldMean

        for (window in windows) {
            val cutoff = now - window.days.toLong() * DAY_MS
            val olderSamples = samples.filter { it.date <= cutoff }
            if (olderSamples.size < 7) continue

            val oldMean = olderSamples.map { it.value }.average()
            if (abs(oldMean) < 0.001) continue

            val drift = ((currentBaseline.mean - oldMean) / abs(oldMean)) * 100.0
            if (abs(drift) <= window.threshold) continue

            if (bestDrift == null || abs(drift) > abs(bestDrift.first) * 0.8) {
                bestDrift = Triple(drift, window.label, oldMean)
            }
        }

        val (driftPercent, periodLabel, oldMean) = bestDrift ?: return null

        val improving = if (metric.higherIsBetter) driftPercent > 0 else driftPercent < 0
        val absDrift = String.format("%.1f", abs(driftPercent))
        val direction = if (driftPercent > 0) "increased" else "decreased"
        val oldFormatted = InsightGenerator.formatValue(oldMean, metric)
        val newFormatted = InsightGenerator.formatValue(currentBaseline.mean, metric)

        // Find co-drifting metrics
        val coDriftMetrics = allDriftResults
            .filter { it.key != metric && abs(it.value.percent) > 5 }
            .entries
            .sortedByDescending { abs(it.value.percent) }
            .take(2)

        val coDriftNote = if (coDriftMetrics.isNotEmpty()) {
            val parts = coDriftMetrics.map { (m, dr) ->
                val sign = if (dr.percent > 0) "+" else ""
                "${m.displayName.lowercase()} $sign${String.format("%.0f", dr.percent)}%"
            }
            " Over the same period: ${parts.joinToString(", ")} also shifted."
        } else ""

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "${metric.displayName} Baseline Shift (${periodLabel.replaceFirstChar { it.uppercase() }})",
            detail = "Your ${metric.displayName.lowercase()} baseline has $direction $absDrift% over the " +
                "last $periodLabel ($oldFormatted \u2192 $newFormatted ${metric.unit}) \u2014 this shift is " +
                "gradual and responsive to changes in your routine.$coDriftNote",
            metric = metric,
            priority = if (improving) InsightPriority.INFORMATIONAL else InsightPriority.MEDIUM,
            directive = if (improving) InsightDirective.MAINTAIN else InsightDirective.INFORMATIONAL,
        )
    }

    companion object {
        private const val DAY_MS = 86_400_000L
    }
}
