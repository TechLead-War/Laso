package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import java.util.UUID
import kotlin.math.abs

/**
 * Detects when multiple metrics decline together, indicating compound health issues.
 *
 * A cluster of 3+ declining metrics in the same category is a stronger signal than any
 * single decline. Also detects cross-category compound decline (3+ categories affected).
 *
 * Ported from iOS MultiMetricClusterAnalyzer.swift.
 */
class MultiMetricClusterAnalyzer : InsightAnalyzer {

    override val name: String = "MultiMetricClusterAnalyzer"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        detectCategoryClusters(context)?.let { insights += it }
        detectCrossCategoryDecline(context.trends)?.let { insights += it }

        return insights
    }

    // ----- Category Clusters (3+ declining metrics in same category) -----

    private data class DecliningMetric(
        val metric: HealthMetric,
        val deviation: Double,
    )

    private fun detectCategoryClusters(context: AnalysisContext): List<AnalysisInsight>? {
        val decliningByCategory = mutableMapOf<HealthCategory, MutableList<DecliningMetric>>()

        for ((metric, trend) in context.trends) {
            if (trend.direction != TrendDirection.FALLING) continue

            val deviation = trend.rateOfChange
            // Also check anomalies for the metric
            val anomalyDeviation = context.anomalies
                .firstOrNull { it.metric == metric }
                ?.let { ((it.value - it.expected) / it.expected) * 100.0 }

            decliningByCategory
                .getOrPut(metric.category) { mutableListOf() }
                .add(DecliningMetric(metric, anomalyDeviation ?: deviation))
        }

        val insights = mutableListOf<AnalysisInsight>()

        for ((category, decliningMetrics) in decliningByCategory) {
            if (decliningMetrics.size < 3) continue

            val sorted = decliningMetrics.sortedByDescending { abs(it.deviation) }
            val avgDeviation = sorted.map { abs(it.deviation) }.average()

            // Build metric detail descriptions
            val metricDetails = sorted.take(4).joinToString(", ") { item ->
                val baseline = context.baselines[item.metric]
                if (baseline != null) {
                    val currentValue = baseline.mean * (1.0 + item.deviation / 100.0)
                    val formatted = InsightGenerator.formatValue(currentValue, item.metric)
                    val devStr = String.format("%.0f", abs(item.deviation))
                    val dir = if (item.deviation > 0) "above" else "below"
                    "${item.metric.displayName}: $formatted ${item.metric.unit} ($devStr% $dir baseline)"
                } else {
                    "${item.metric.displayName} (${String.format("%.0f", abs(item.deviation))}% deviation)"
                }
            }

            val recommendation = recommendationForCluster(
                category, decliningMetrics.size, avgDeviation,
                sorted.map { it.metric },
            )

            insights += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "${category.displayName} Declining",
                detail = "${decliningMetrics.size} metrics declining together in ${category.displayName}: $metricDetails.",
                metric = sorted.first().metric,
                priority = InsightPriority.HIGH,
                directive = directiveForCategory(category),
                confidence = 0.85,
            )
        }

        return insights.ifEmpty { null }
    }

    // ----- Cross-Category Decline (3+ categories with any declining metric) -----

    private fun detectCrossCategoryDecline(trends: Map<HealthMetric, MetricTrend>): AnalysisInsight? {
        val categoriesWithDecline = mutableSetOf<HealthCategory>()
        var totalDeclining = 0

        for ((metric, trend) in trends) {
            if (trend.direction != TrendDirection.FALLING) continue
            categoriesWithDecline += metric.category
            totalDeclining++
        }

        if (categoriesWithDecline.size < 3) return null

        val categoryNames = categoriesWithDecline.take(4).joinToString(", ") { it.displayName }

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Widespread Health Decline",
            detail = "$totalDeclining metrics across ${categoriesWithDecline.size} categories " +
                "are declining: $categoryNames.",
            metric = HealthMetric.RESTING_HEART_RATE,
            priority = InsightPriority.HIGH,
            directive = InsightDirective.INFORMATIONAL,
        )
    }

    // ----- Recommendations -----

    private fun recommendationForCluster(
        category: HealthCategory,
        count: Int,
        avgDeviation: Double,
        metrics: List<HealthMetric>,
    ): String {
        val devStr = String.format("%.0f", avgDeviation)
        val metricNames = metrics.take(4).joinToString(", ") { it.displayName }
        return when (category) {
            HealthCategory.HEART ->
                "Multiple heart metrics declining simultaneously \u2014 $count metrics affected: $metricNames. Avg ${devStr}% below baseline."
            HealthCategory.SLEEP ->
                "Sleep deteriorating across $count dimensions \u2014 $metricNames. Avg ${devStr}% below baseline."
            HealthCategory.ACTIVITY ->
                "Activity declining across $count metrics \u2014 $metricNames. Avg ${devStr}% below baseline."
            HealthCategory.BODY ->
                "Body composition metrics shifting \u2014 $count metrics affected: $metricNames. Avg ${devStr}% from baseline."
            HealthCategory.RESPIRATORY ->
                "Respiratory metrics elevated \u2014 $count metrics affected: $metricNames. Avg ${devStr}% from baseline."
            HealthCategory.MINDFULNESS ->
                "Mindfulness metrics declining \u2014 $count metrics affected: $metricNames. Avg ${devStr}% below baseline."
            HealthCategory.MOBILITY ->
                "Mobility metrics declining across $count indicators \u2014 $metricNames. Avg ${devStr}% below baseline."
            HealthCategory.NUTRITION ->
                "Nutrition metrics shifted from baseline \u2014 $count metrics affected: $metricNames. Avg ${devStr}% from baseline."
            HealthCategory.HEARING ->
                "Hearing metrics changed \u2014 $count metrics affected: $metricNames. Avg ${devStr}% from baseline."
        }
    }

    private fun directiveForCategory(category: HealthCategory): InsightDirective = when (category) {
        HealthCategory.HEART -> InsightDirective.REST
        HealthCategory.SLEEP -> InsightDirective.SLEEP_MORE
        HealthCategory.ACTIVITY -> InsightDirective.INCREASE_ACTIVITY
        HealthCategory.RESPIRATORY -> InsightDirective.SEEK_MEDICAL
        else -> InsightDirective.INFORMATIONAL
    }
}
