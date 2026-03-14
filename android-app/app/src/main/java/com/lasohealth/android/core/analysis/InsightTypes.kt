package com.lasohealth.android.core.analysis

import com.lasohealth.android.core.model.HealthMetric

/**
 * Behavioural direction conveyed by an insight.
 *
 * Used by the contradiction resolver to detect conflicting advice
 * (e.g. REST vs INCREASE_ACTIVITY) and resolve by safety > severity > evidence.
 */
enum class InsightDirective {
    REST,
    INCREASE_ACTIVITY,
    REDUCE_INTENSITY,
    PUSH_HARDER,
    SLEEP_MORE,
    SLEEP_BETTER,
    SEEK_MEDICAL,
    MAINTAIN,
    INFORMATIONAL,
}

/**
 * Priority tier for ranking and capping insights shown to the user.
 */
enum class InsightPriority {
    CRITICAL,
    HIGH,
    MEDIUM,
    LOW,
    INFORMATIONAL,
}

/**
 * A single actionable or informational insight produced by an [InsightAnalyzer].
 */
data class AnalysisInsight(
    val id: String,
    val title: String,
    val detail: String,
    val metric: HealthMetric,
    val priority: InsightPriority,
    val directive: InsightDirective,
    val confidence: Double = 1.0,
    val timestamp: Long = System.currentTimeMillis(),
)

/**
 * Common interface for all insight analyzers in the engine.
 *
 * Each analyzer inspects a specific facet of the user's data (recovery, sleep quality,
 * workout effectiveness, etc.) and emits zero or more [AnalysisInsight]s.
 *
 * Implementations must be safe to call concurrently — the coordinator may run
 * multiple analyzers in parallel via coroutine fan-out.
 */
interface InsightAnalyzer {
    /** Human-readable name for logging and debugging. */
    val name: String

    /** Generate insights from the shared [AnalysisContext]. */
    suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight>
}
