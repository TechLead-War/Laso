package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.model.HealthMetric
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

/**
 * Coordinates all insight analyzers: runs them, resolves contradictions,
 * deduplicates, and caps the result set.
 *
 * Resolution order: safety > severity > evidence depth.
 *
 * Pipeline:
 *   1. Run all analyzers (concurrently via coroutine fan-out)
 *   2. Infer directives for insights still tagged INFORMATIONAL (where possible)
 *   3. Resolve contradictions (e.g. REST vs INCREASE_ACTIVITY) — safety wins
 *   4. Deduplicate by metric (max 2 per metric)
 *   5. Sort by priority and cap at [MAX_INSIGHTS]
 *
 * Ported from iOS InsightCoordinator.swift.
 */
class InsightCoordinator {

    /**
     * Run all [analyzers] against the given [context], resolve contradictions,
     * deduplicate, and return at most [MAX_INSIGHTS] prioritised insights.
     */
    suspend fun coordinate(
        context: AnalysisContext,
        analyzers: List<InsightAnalyzer>,
    ): List<AnalysisInsight> = coroutineScope {
        // Step 1: Run all analyzers concurrently
        val rawInsights = analyzers
            .map { analyzer ->
                async {
                    try {
                        analyzer.generateInsights(context)
                    } catch (_: Exception) {
                        emptyList()
                    }
                }
            }
            .awaitAll()
            .flatten()

        if (rawInsights.isEmpty()) return@coroutineScope emptyList()

        // Step 2: Infer directives for any insight still tagged INFORMATIONAL
        var tagged = rawInsights.map { insight ->
            if (insight.directive == InsightDirective.INFORMATIONAL) {
                insight.copy(directive = inferDirective(insight))
            } else {
                insight
            }
        }

        // Step 3: Resolve contradictions
        tagged = resolveConflicts(tagged)

        // Step 4: Deduplicate (max 2 per metric)
        tagged = deduplicateByMetric(tagged)

        // Step 5: Sort by priority and cap
        tagged
            .sortedWith(
                compareBy<AnalysisInsight> { it.priority.ordinal }
                    .thenByDescending { it.confidence },
            )
            .take(MAX_INSIGHTS)
    }

    // ----- Directive Inference -----

    /**
     * Infer a directive from the insight's title and detail text when the analyzer
     * did not assign one explicitly.
     */
    private fun inferDirective(insight: AnalysisInsight): InsightDirective {
        val title = insight.title.lowercase()
        val detail = insight.detail.lowercase()

        // Text-based rules ordered by priority: medical > rest > sleep > activity > intensity
        for (rule in TEXT_RULES) {
            if (rule.matches(title, detail)) {
                return rule.directive
            }
        }

        return InsightDirective.INFORMATIONAL
    }

    // ----- Conflict Resolution -----

    /**
     * Resolve contradicting insights. When two insights have conflicting directives
     * and at least one is HIGH priority or above, the safer/more important directive wins.
     */
    private fun resolveConflicts(insights: List<AnalysisInsight>): List<AnalysisInsight> {
        val suppressed = mutableSetOf<String>()

        for (insightA in insights) {
            if (insightA.id in suppressed) continue
            val conflictsA = CONFLICTS[insightA.directive] ?: continue
            if (conflictsA.isEmpty()) continue

            for (insightB in insights) {
                if (insightA.id == insightB.id) continue
                if (insightB.id in suppressed) continue
                if (insightB.directive !in conflictsA) continue

                // Only resolve if at least one is HIGH+ priority
                if (insightA.priority.ordinal > InsightPriority.HIGH.ordinal &&
                    insightB.priority.ordinal > InsightPriority.HIGH.ordinal
                ) continue

                // Determine winner
                val priorityA = RESOLUTION_PRIORITY[insightA.directive] ?: 0
                val priorityB = RESOLUTION_PRIORITY[insightB.directive] ?: 0

                val aWins = when {
                    priorityA != priorityB -> priorityA > priorityB
                    insightA.priority != insightB.priority ->
                        insightA.priority.ordinal < insightB.priority.ordinal
                    else -> insightA.confidence >= insightB.confidence
                }

                suppressed += if (aWins) insightB.id else insightA.id

                // If A lost, stop checking A against others
                if (!aWins) break
            }
        }

        return insights.filter { it.id !in suppressed }
    }

    // ----- Deduplication -----

    /**
     * Remove duplicate insights about the same metric across all analyzers.
     * Keeps max 2 per metric, selecting by priority then confidence.
     */
    private fun deduplicateByMetric(insights: List<AnalysisInsight>): List<AnalysisInsight> {
        val grouped = insights.groupBy { it.metric }
        val result = mutableListOf<AnalysisInsight>()

        for ((_, metricInsights) in grouped) {
            if (metricInsights.size <= 2) {
                result += metricInsights
                continue
            }

            // Sort by priority (critical first), then confidence descending
            val sorted = metricInsights.sortedWith(
                compareBy<AnalysisInsight> { it.priority.ordinal }
                    .thenByDescending { it.confidence },
            )

            // Keep the top 2
            result += sorted.take(2)
        }

        return result
    }

    // ----- Conflict Tables -----

    private data class TextRule(
        val directive: InsightDirective,
        val titleKeywords: List<String>,
        val detailKeywords: List<String>,
    ) {
        fun matches(title: String, detail: String): Boolean {
            val titleMatch = titleKeywords.isEmpty() || titleKeywords.any { title.contains(it) }
            val detailMatch = detailKeywords.isEmpty() || detailKeywords.any { detail.contains(it) }
            return when {
                titleKeywords.isEmpty() -> detailMatch
                detailKeywords.isEmpty() -> titleMatch
                else -> titleMatch || detailMatch
            }
        }
    }

    companion object {
        const val MAX_INSIGHTS = 15

        /**
         * Directives that directly contradict each other.
         * Two insights with mutually conflicting directives cannot coexist
         * when at least one carries HIGH+ priority.
         */
        private val CONFLICTS: Map<InsightDirective, Set<InsightDirective>> = mapOf(
            InsightDirective.REST to setOf(
                InsightDirective.INCREASE_ACTIVITY,
                InsightDirective.PUSH_HARDER,
            ),
            InsightDirective.INCREASE_ACTIVITY to setOf(
                InsightDirective.REST,
                InsightDirective.REDUCE_INTENSITY,
            ),
            InsightDirective.REDUCE_INTENSITY to setOf(
                InsightDirective.PUSH_HARDER,
                InsightDirective.INCREASE_ACTIVITY,
            ),
            InsightDirective.PUSH_HARDER to setOf(
                InsightDirective.REST,
                InsightDirective.REDUCE_INTENSITY,
            ),
            InsightDirective.SLEEP_MORE to emptySet(),
            InsightDirective.SLEEP_BETTER to emptySet(),
            InsightDirective.SEEK_MEDICAL to emptySet(),     // never suppressed
            InsightDirective.MAINTAIN to emptySet(),
            InsightDirective.INFORMATIONAL to emptySet(),
        )

        /**
         * Resolution priority for conflicting directives.
         * Higher value wins. Safety-oriented directives outrank performance pushes.
         */
        private val RESOLUTION_PRIORITY: Map<InsightDirective, Int> = mapOf(
            InsightDirective.SEEK_MEDICAL to 100,
            InsightDirective.REST to 80,
            InsightDirective.REDUCE_INTENSITY to 70,
            InsightDirective.SLEEP_MORE to 60,
            InsightDirective.SLEEP_BETTER to 50,
            InsightDirective.INCREASE_ACTIVITY to 40,
            InsightDirective.PUSH_HARDER to 30,
            InsightDirective.MAINTAIN to 20,
            InsightDirective.INFORMATIONAL to 10,
        )

        /**
         * Text-based rules for inferring directives from insight content.
         * Ordered by priority: medical > rest > sleep > activity > intensity.
         */
        private val TEXT_RULES = listOf(
            TextRule(
                InsightDirective.SEEK_MEDICAL,
                emptyList(),
                listOf("consult", "healthcare provider", "doctor"),
            ),
            TextRule(
                InsightDirective.REST,
                listOf("overtraining", "rest day", "recovery day", "rest deficit"),
                listOf("rest day", "genuine rest"),
            ),
            TextRule(
                InsightDirective.SLEEP_MORE,
                listOf("sleep debt"),
                listOf("bedtime alarm", "more sleep"),
            ),
            TextRule(
                InsightDirective.SLEEP_BETTER,
                listOf("sleep consistency", "bedtime"),
                listOf("consistent bedtime"),
            ),
            TextRule(
                InsightDirective.INCREASE_ACTIVITY,
                listOf("workout consistency"),
                listOf("20-min walk", "20 min walk", "more active"),
            ),
            TextRule(
                InsightDirective.PUSH_HARDER,
                emptyList(),
                listOf("push harder", "increase intensity", "progressive overload"),
            ),
            TextRule(
                InsightDirective.REDUCE_INTENSITY,
                emptyList(),
                listOf("lower intensity", "lighter sessions", "reduce intensity"),
            ),
        )
    }
}
