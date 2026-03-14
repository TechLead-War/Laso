package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import java.util.Calendar
import java.util.UUID
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Builds causal chain narratives explaining WHY metrics changed.
 *
 * Connects correlations, anomalies, and trends into human-readable cause-effect stories.
 * Traces chains of up to 3 links from root cause to final problematic metric.
 *
 * The engine:
 *   1. Identifies "effect" metrics (problematically deviating)
 *   2. Uses cross-metric correlations to find potential causes
 *   3. Validates that causes actually deviated in the expected direction
 *   4. Assembles chains, computes confidence, and generates narratives
 *
 * Ported from iOS CausalChainEngine.swift.
 */
class CausalChainEngine : InsightAnalyzer {

    override val name: String = "CausalChainEngine"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val chains = buildChains(context)
        return chains.take(3).mapNotNull { chain -> chainToInsight(chain) }
    }

    // ----- Models -----

    private data class ChainLink(
        val causeMetric: HealthMetric,
        val effectMetric: HealthMetric,
        val correlation: Double,
        val lagDays: Int,
        val causeDeviation: Double,
        val effectDeviation: Double,
    )

    private data class CausalChain(
        val links: List<ChainLink>,
        val affectedMetric: HealthMetric,
        val confidence: Double,
        val narrative: String,
    )

    /**
     * Lightweight correlation placeholder derived from pairwise analysis of the
     * [AnalysisContext.timeSeries] data. Represents a known metric-pair relationship.
     */
    private data class MetricCorrelation(
        val metricA: HealthMetric,
        val metricB: HealthMetric,
        val r: Double,
        val dayOffset: Int,
        val isPositive: Boolean,
    )

    // ----- Configuration -----

    companion object {
        private const val MIN_CORRELATION = 0.3
        private const val MIN_DEVIATION_PCT = 5.0
        private const val MAX_CHAIN_LENGTH = 3
        private const val DAY_MS = 86_400_000L

        /** Metric pairs that are mathematically coupled and not insightful. */
        private val TRIVIAL_PAIRS: Set<Set<HealthMetric>> = setOf(
            setOf(HealthMetric.STEPS, HealthMetric.ACTIVE_CALORIES),
            setOf(HealthMetric.STEPS, HealthMetric.DISTANCE_WALKING_RUNNING),
            setOf(HealthMetric.ACTIVE_CALORIES, HealthMetric.DISTANCE_WALKING_RUNNING),
            setOf(HealthMetric.ACTIVE_CALORIES, HealthMetric.EXERCISE_MINUTES),
            setOf(HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_CORE),
            setOf(HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_REM),
            setOf(HealthMetric.SLEEP_DURATION, HealthMetric.SLEEP_DEEP),
            setOf(HealthMetric.WEIGHT, HealthMetric.BMI),
            setOf(HealthMetric.WEIGHT, HealthMetric.BODY_FAT_PERCENTAGE),
            setOf(HealthMetric.BLOOD_PRESSURE_SYSTOLIC, HealthMetric.BLOOD_PRESSURE_DIASTOLIC),
            setOf(HealthMetric.WORKOUT_COUNT, HealthMetric.WORKOUT_DURATION),
            setOf(HealthMetric.EXERCISE_MINUTES, HealthMetric.WORKOUT_DURATION),
            setOf(HealthMetric.BASAL_CALORIES, HealthMetric.WEIGHT),
        )

        /**
         * Pre-defined physiologically plausible metric pairs with lag information.
         * Drawn from the same registry used by [CorrelationAnalyzer].
         */
        private val KNOWN_PAIRS = listOf(
            Triple(HealthMetric.SLEEP_DURATION, HealthMetric.RESTING_HEART_RATE, 1),
            Triple(HealthMetric.SLEEP_DURATION, HealthMetric.HEART_RATE_VARIABILITY, 1),
            Triple(HealthMetric.SLEEP_DEEP, HealthMetric.HEART_RATE_VARIABILITY, 1),
            Triple(HealthMetric.EXERCISE_MINUTES, HealthMetric.HEART_RATE_VARIABILITY, 1),
            Triple(HealthMetric.ACTIVE_CALORIES, HealthMetric.RESTING_HEART_RATE, 1),
            Triple(HealthMetric.ACTIVE_CALORIES, HealthMetric.SLEEP_DEEP, 0),
            Triple(HealthMetric.STEPS, HealthMetric.SLEEP_DURATION, 0),
            Triple(HealthMetric.MINDFUL_MINUTES, HealthMetric.HEART_RATE_VARIABILITY, 0),
            Triple(HealthMetric.SLEEP_DURATION, HealthMetric.STEPS, 1),
            Triple(HealthMetric.SLEEP_DEEP, HealthMetric.ACTIVE_CALORIES, 1),
            Triple(HealthMetric.EXERCISE_MINUTES, HealthMetric.SLEEP_DEEP, 0),
            Triple(HealthMetric.STEPS, HealthMetric.HEART_RATE_VARIABILITY, 0),
            Triple(HealthMetric.EXERCISE_MINUTES, HealthMetric.RESTING_HEART_RATE, 1),
        )
    }

    // ----- Chain Building Pipeline -----

    private fun buildChains(context: AnalysisContext): List<CausalChain> {
        // Step 1: Identify effect metrics — those deviating in a bad direction
        val effectMetrics = identifyEffectMetrics(context)
        if (effectMetrics.isEmpty()) return emptyList()

        // Step 2: Discover correlations from the time series
        val correlations = discoverCorrelations(context)
        val correlationIndex = buildCorrelationIndex(correlations)

        // Step 3: For each effect metric, trace chains backward
        val allChains = mutableListOf<CausalChain>()
        for (effect in effectMetrics) {
            val chains = traceChains(
                effectMetric = effect,
                correlationIndex = correlationIndex,
                context = context,
                visited = setOf(effect),
                depth = 0,
            )
            allChains += chains
        }

        // Step 4: Deduplicate and rank
        return deduplicateChains(allChains).sortedByDescending { it.confidence }
    }

    // ----- Step 1: Identify Effect Metrics -----

    private fun identifyEffectMetrics(context: AnalysisContext): List<HealthMetric> {
        val effects = mutableSetOf<HealthMetric>()

        // Anomalies in the problematic direction
        for (anomaly in context.anomalies) {
            val isProblematic = if (anomaly.metric.higherIsBetter) {
                anomaly.value < anomaly.expected
            } else {
                anomaly.value > anomaly.expected
            }
            if (isProblematic && abs(anomaly.zScore) >= 1.5) {
                effects += anomaly.metric
            }
        }

        // Declining trends with meaningful week-over-week change
        for ((metric, trend) in context.trends) {
            if (trend.direction == TrendDirection.FALLING && abs(trend.rateOfChange) >= MIN_DEVIATION_PCT) {
                effects += metric
            }
        }

        return effects.toList()
    }

    // ----- Step 2: Discover Correlations -----

    /**
     * Compute lightweight pairwise correlations from the time series for the known pairs.
     */
    private fun discoverCorrelations(context: AnalysisContext): List<MetricCorrelation> {
        val results = mutableListOf<MetricCorrelation>()

        for ((metricA, metricB, lag) in KNOWN_PAIRS) {
            val samplesA = context.timeSeries[metricA] ?: continue
            val samplesB = context.timeSeries[metricB] ?: continue

            val aligned = alignSamples(samplesA, samplesB, lag)
            if (aligned.size < 14) continue

            val r = pearsonCorrelation(aligned) ?: continue
            if (abs(r) < MIN_CORRELATION) continue

            results += MetricCorrelation(metricA, metricB, r, lag, r > 0)
        }

        return results
    }

    private fun buildCorrelationIndex(
        correlations: List<MetricCorrelation>,
    ): Map<HealthMetric, List<Pair<HealthMetric, MetricCorrelation>>> {
        val index = mutableMapOf<HealthMetric, MutableList<Pair<HealthMetric, MetricCorrelation>>>()

        for (corr in correlations) {
            if (TRIVIAL_PAIRS.contains(setOf(corr.metricA, corr.metricB))) continue

            // metricA = cause, metricB = effect
            index.getOrPut(corr.metricB) { mutableListOf() }
                .add(corr.metricA to corr)

            // For same-day correlations, direction is ambiguous
            if (corr.dayOffset == 0) {
                index.getOrPut(corr.metricA) { mutableListOf() }
                    .add(corr.metricB to corr)
            }
        }

        return index
    }

    // ----- Step 3: Trace Chains -----

    private fun traceChains(
        effectMetric: HealthMetric,
        correlationIndex: Map<HealthMetric, List<Pair<HealthMetric, MetricCorrelation>>>,
        context: AnalysisContext,
        visited: Set<HealthMetric>,
        depth: Int,
    ): List<CausalChain> {
        if (depth >= MAX_CHAIN_LENGTH) return emptyList()

        val potentialCauses = correlationIndex[effectMetric] ?: return emptyList()
        val chains = mutableListOf<CausalChain>()

        for ((causeMetric, corr) in potentialCauses) {
            if (causeMetric in visited) continue

            val link = validateLink(causeMetric, effectMetric, corr, context) ?: continue

            // Single-link chain
            chains += assembleChain(listOf(link), effectMetric, context.baselines)

            // Recurse for deeper chains
            val deeper = traceChains(
                effectMetric = causeMetric,
                correlationIndex = correlationIndex,
                context = context,
                visited = visited + causeMetric,
                depth = depth + 1,
            )
            for (deepChain in deeper) {
                chains += assembleChain(deepChain.links + link, effectMetric, context.baselines)
            }
        }

        return chains
    }

    // ----- Link Validation -----

    private fun validateLink(
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        correlation: MetricCorrelation,
        context: AnalysisContext,
    ): ChainLink? {
        val causeBaseline = context.baselines[causeMetric] ?: return null
        context.baselines[effectMetric] ?: return null

        val causeDevPct = computeDeviation(causeMetric, correlation.dayOffset, context) ?: return null
        if (abs(causeDevPct) < MIN_DEVIATION_PCT) return null

        val effectDevPct = computeDeviation(effectMetric, 0, context) ?: return null

        // Check directional consistency
        val aligned = if (correlation.isPositive) {
            (causeDevPct > 0 && effectDevPct > 0) || (causeDevPct < 0 && effectDevPct < 0)
        } else {
            (causeDevPct > 0 && effectDevPct < 0) || (causeDevPct < 0 && effectDevPct > 0)
        }
        if (!aligned) return null

        return ChainLink(
            causeMetric = causeMetric,
            effectMetric = effectMetric,
            correlation = correlation.r,
            lagDays = correlation.dayOffset,
            causeDeviation = causeDevPct,
            effectDeviation = effectDevPct,
        )
    }

    private fun computeDeviation(
        metric: HealthMetric,
        lagDays: Int,
        context: AnalysisContext,
    ): Double? {
        // Fast path: anomaly data for lag=0
        if (lagDays == 0) {
            val anomaly = context.anomalies.firstOrNull { it.metric == metric }
            if (anomaly != null && anomaly.expected != 0.0) {
                return ((anomaly.value - anomaly.expected) / anomaly.expected) * 100.0
            }
        }

        val samples = context.timeSeries[metric] ?: return null
        val baseline = context.baselines[metric] ?: return null
        if (baseline.mean == 0.0) return null

        val now = System.currentTimeMillis()
        val windowStart = now - (lagDays + 3).toLong() * DAY_MS
        val windowEnd = now - lagDays.toLong() * DAY_MS

        val windowSamples = samples.filter { it.date in windowStart..windowEnd }
        if (windowSamples.isEmpty()) return null

        val avg = windowSamples.map { it.value }.average()
        return ((avg - baseline.mean) / baseline.mean) * 100.0
    }

    // ----- Chain Assembly & Scoring -----

    private fun assembleChain(
        links: List<ChainLink>,
        affectedMetric: HealthMetric,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): CausalChain {
        val confidence = computeConfidence(links)
        val narrative = generateNarrative(links, affectedMetric, baselines)
        return CausalChain(links, affectedMetric, confidence, narrative)
    }

    private fun computeConfidence(links: List<ChainLink>): Double {
        if (links.isEmpty()) return 0.0
        val avgCorr = links.map { abs(it.correlation) }.average()
        val lengthBonus = when (links.size) {
            1 -> 1.0; 2 -> 1.15; 3 -> 1.25; else -> 1.0
        }
        val avgDev = links.map { abs(it.causeDeviation) }.average()
        val devBonus = (avgDev / 50.0).coerceAtMost(0.2)
        return ((avgCorr * lengthBonus) + devBonus).coerceAtMost(1.0)
    }

    private fun deduplicateChains(chains: List<CausalChain>): List<CausalChain> {
        if (chains.size <= 1) return chains

        val grouped = chains.groupBy { it.affectedMetric }
        val result = mutableListOf<CausalChain>()

        for ((_, group) in grouped) {
            val sorted = group.sortedByDescending { it.links.size }
            val kept = mutableListOf<CausalChain>()
            for (chain in sorted) {
                val metrics = chain.links.map { it.causeMetric }.toSet()
                val isSubset = kept.any { existing ->
                    val existingMetrics = existing.links.map { it.causeMetric }.toSet()
                    metrics.isSubsetOf(existingMetrics) && chain.links.size < existing.links.size
                }
                if (!isSubset) kept += chain
            }
            result += kept.sortedByDescending { it.confidence }.take(2)
        }

        return result
    }

    private fun <T> Set<T>.isSubsetOf(other: Set<T>): Boolean = this.all { it in other }

    // ----- Narrative Generation -----

    private fun generateNarrative(
        links: List<ChainLink>,
        affectedMetric: HealthMetric,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): String {
        if (links.isEmpty()) return ""

        return when (links.size) {
            1 -> generateSingleLinkNarrative(links[0], baselines)
            2 -> generateTwoLinkNarrative(links, affectedMetric, baselines)
            else -> generateMultiLinkNarrative(links, affectedMetric, baselines)
        }
    }

    private fun generateSingleLinkNarrative(link: ChainLink, baselines: Map<HealthMetric, MetricBaseline>): String {
        val effectName = link.effectMetric.displayName.lowercase()
        val causeName = link.causeMetric.displayName.lowercase()
        val effectDir = if (link.effectDeviation > 0) "increased" else "decreased"
        val causeDir = if (link.causeDeviation > 0) "rising" else "dropping"
        val effectDev = fmtDev(link.effectDeviation)
        val causeDev = fmtDev(link.causeDeviation)
        val absR = String.format("%.2f", abs(link.correlation))
        val strength = if (abs(link.correlation) >= 0.5) "strong" else "moderate"

        var text = "Your $effectName $effectDir $effectDev this week. " +
            "Based on your personal data, this appears connected to your $causeName $causeDir $causeDev"

        baselines[link.causeMetric]?.let {
            text += " (from your ${InsightGenerator.formatValue(it.mean, link.causeMetric)} ${link.causeMetric.unit} baseline)"
        }

        text += ". Your data shows a $strength personal pattern between these metrics (r=$absR)"
        if (link.lagDays > 0) {
            text += " with effects typically showing ${if (link.lagDays == 1) "the next day" else "after ${link.lagDays} days"}"
        }
        text += "."
        return text
    }

    private fun generateTwoLinkNarrative(
        links: List<ChainLink>,
        affectedMetric: HealthMetric,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): String {
        val root = links[0]; val final_ = links[1]
        val affectedName = affectedMetric.displayName.lowercase()
        val intermediateName = final_.causeMetric.displayName.lowercase()
        val rootCauseName = root.causeMetric.displayName.lowercase()

        val affectedDir = if (final_.effectDeviation > 0) "increased" else "dropped"
        val rootDir = if (root.causeDeviation > 0) "increased" else "decreased"

        return "Your $affectedName $affectedDir ${fmtDev(final_.effectDeviation)} this week. " +
            "This appears connected to your $intermediateName, which ${if (root.effectDeviation > 0) "increased" else "decreased"} " +
            "${fmtDev(root.effectDeviation)} over the same period. " +
            "Looking deeper, your $rootCauseName $rootDir ${fmtDev(root.causeDeviation)} recently, " +
            "which correlates with changes in $intermediateName for you (r=${String.format("%.2f", abs(root.correlation))})."
    }

    private fun generateMultiLinkNarrative(
        links: List<ChainLink>,
        affectedMetric: HealthMetric,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): String {
        val affectedName = affectedMetric.displayName.lowercase()
        val affectedDir = if (links.last().effectDeviation > 0) "increased" else "dropped"
        val rootName = links[0].causeMetric.displayName.lowercase()
        val rootDir = if (links[0].causeDeviation > 0) "rose" else "dropped"

        var text = "Your $affectedName $affectedDir ${fmtDev(links.last().effectDeviation)} this week. " +
            "Your data suggests a cascade of connected changes. " +
            "It started with your $rootName, which $rootDir ${fmtDev(links[0].causeDeviation)}."

        if (links.size >= 2) {
            val mid = links[1]
            val midName = mid.effectMetric.displayName.lowercase()
            val midDir = if (mid.effectDeviation > 0) "increased" else "decreased"
            text += " That appears to have ${if (midDir == "decreased") "reduced" else "elevated"} " +
                "your $midName ($midDir ${fmtDev(mid.effectDeviation)})."
        }

        val chainSummary = links.joinToString(" -> ") {
            "${if (it.causeDeviation > 0) "higher" else "lower"} ${it.causeMetric.displayName.lowercase()}"
        }
        text += " Likely chain: $chainSummary -> $affectedDir $affectedName."
        return text
    }

    // ----- Insight Conversion -----

    private fun chainToInsight(chain: CausalChain): AnalysisInsight? {
        if (chain.links.isEmpty()) return null

        val effectDev = abs(chain.links.last().effectDeviation)
        val priority = if (effectDev >= 20 || chain.confidence >= 0.7) InsightPriority.HIGH else InsightPriority.MEDIUM

        val title = if (chain.links.size == 1) {
            val cause = chain.links[0].causeMetric.displayName
            val affected = chain.affectedMetric.displayName
            "$cause \u2192 $affected"
        } else {
            val root = chain.links[0].causeMetric.displayName
            "Why ${chain.affectedMetric.displayName} Changed: $root"
        }

        val recommendation = buildRecommendation(chain)

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = title,
            detail = chain.narrative + " " + recommendation,
            metric = chain.affectedMetric,
            priority = priority,
            directive = directiveForRootCause(chain),
            confidence = chain.confidence,
        )
    }

    private fun buildRecommendation(chain: CausalChain): String {
        val rootLink = chain.links.firstOrNull() ?: return ""
        val rootMetric = rootLink.causeMetric
        val isProblematic = if (rootMetric.higherIsBetter) rootLink.causeDeviation < 0 else rootLink.causeDeviation > 0
        val metricName = rootMetric.displayName.lowercase()
        val affectedName = chain.affectedMetric.displayName.lowercase()

        return when (rootMetric.category) {
            HealthCategory.SLEEP -> if (isProblematic) {
                "Focus on improving your $metricName. Consistent bedtimes and reduced screen time before bed " +
                    "may have a cascading positive effect on your $affectedName."
            } else {
                "Your $metricName increase may be affecting downstream metrics. Give your body a few days to adjust."
            }
            HealthCategory.ACTIVITY -> if (isProblematic) {
                "Your $metricName has dropped. Gradually increasing activity \u2014 even short walks \u2014 could " +
                    "positively influence your $affectedName."
            } else {
                "Your increased $metricName may be straining recovery. Consider adding rest days."
            }
            HealthCategory.HEART -> {
                "Your $metricName change appears connected to other metrics. Focus on upstream factors \u2014 " +
                    "stress management, sleep quality, and exercise balance."
            }
            else -> if (isProblematic) {
                "Address the root factor: your $metricName has shifted from baseline. Restoring it may help your $affectedName recover."
            } else {
                "Monitor whether your $metricName change continues. If your $affectedName doesn't stabilize, consider other factors."
            }
        }
    }

    private fun directiveForRootCause(chain: CausalChain): InsightDirective {
        val rootMetric = chain.links.firstOrNull()?.causeMetric ?: return InsightDirective.INFORMATIONAL
        return when (rootMetric.category) {
            HealthCategory.SLEEP -> InsightDirective.SLEEP_MORE
            HealthCategory.ACTIVITY -> InsightDirective.REST
            HealthCategory.HEART -> InsightDirective.REST
            else -> InsightDirective.INFORMATIONAL
        }
    }

    // ----- Utility -----

    private fun fmtDev(deviation: Double): String {
        val abs = abs(deviation)
        return if (abs >= 10) String.format("%.0f%%", abs) else String.format("%.1f%%", abs)
    }

    private fun alignSamples(
        samplesA: List<DailySample>,
        samplesB: List<DailySample>,
        dayOffset: Int,
    ): List<Pair<Double, Double>> {
        val mapA = mutableMapOf<Long, Double>()
        for (s in samplesA) mapA[startOfDay(s.date)] = s.value
        val mapB = mutableMapOf<Long, Double>()
        for (s in samplesB) mapB[startOfDay(s.date)] = s.value

        val aligned = mutableListOf<Pair<Double, Double>>()
        for ((day, valA) in mapA) {
            val target = day + dayOffset.toLong() * DAY_MS
            val valB = mapB[target] ?: continue
            aligned += valA to valB
        }
        return aligned
    }

    private fun pearsonCorrelation(aligned: List<Pair<Double, Double>>): Double? {
        if (aligned.size < 5) return null
        val meanA = aligned.map { it.first }.average()
        val meanB = aligned.map { it.second }.average()
        var num = 0.0; var dA = 0.0; var dB = 0.0
        for ((a, b) in aligned) {
            val da = a - meanA; val db = b - meanB
            num += da * db; dA += da * da; dB += db * db
        }
        if (dA <= 0 || dB <= 0) return null
        return num / (sqrt(dA) * sqrt(dB))
    }

    private fun startOfDay(epochMs: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = epochMs }
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
