package com.lasohealth.android.core.ml

import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.model.HealthMetric
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

/**
 * Expected-utility decision framework for generating the daily "Today's Action" card.
 *
 * Generates intervention candidates from multiple ML signal sources (forecasts,
 * anomalies, health signals, patterns, correlations, state transitions), scores
 * them using expected utility (predicted uplift x confidence x novelty x effort),
 * applies fatigue/diversity controls, and produces ranked [PolicyDecision]s with
 * natural language output.
 *
 * Feedback integration closes the loop: per-actionType effectiveness is tracked
 * via exponential moving average and feeds back into future scoring.
 *
 * Ported from iOS `DecisionPolicyEngine.swift`.
 */
class DecisionPolicyEngine {

    companion object {
        /** EMA smoothing factor for effectiveness updates. */
        private const val EFFECTIVENESS_ALPHA = 0.15
        /** Maximum recent decisions retained. */
        private const val MAX_RECENT_DECISIONS = 50
        /** Maximum feedback entries retained. */
        private const val MAX_FEEDBACK_HISTORY = 200
        /** Rolling window for exposure tracking (days). */
        private const val EXPOSURE_WINDOW_DAYS = 7
    }

    // -- State ------------------------------------------------------------------

    /** Recent decisions for exposure tracking and diversity enforcement. */
    var recentDecisions: List<PolicyDecision> = emptyList()
        private set

    /** Per-actionType effectiveness learned from feedback (0.0-1.0). */
    var categoryEffectiveness: Map<String, Double> = emptyMap()
        private set

    /** Rolling 7-day exposure tracker: actionType -> list of shown dates. */
    private val exposureLog = mutableMapOf<String, MutableList<Long>>()

    /** Feedback history for closed-loop updates. */
    private val feedbackHistory = mutableListOf<RecommendationFeedback>()

    /** Whether the engine has produced any decisions. */
    val isReady: Boolean get() = recentDecisions.isNotEmpty()

    // -- Candidate Types --------------------------------------------------------

    enum class CandidateSource {
        FORECAST,           // Forecasted metric dip/spike
        ANOMALY,            // Detected anomaly
        HEALTH_SIGNAL,      // Predictive health signal (fatigue, burnout, etc.)
        PATTERN,            // Discovered pattern (e.g. weekly cycle)
        CORRELATION,        // Actionable correlation
        STATE_TRANSITION,   // Health state change
        BASELINE,           // Metric drifting from baseline
    }

    data class InterventionCandidate(
        val source: CandidateSource,
        val actionType: String,
        val action: String,
        val detail: String,
        val metric: HealthMetric?,
        val iconEmoji: String,
        val predictedUplift: Double,       // 0-1 how much benefit expected
        val confidence: Double,            // 0-1 model confidence
        val effortLevel: Double = 0.5,     // 0-1 how much effort required (lower = easier)
    )

    // -- Decision Generation ----------------------------------------------------

    /**
     * Generate the day's policy decision from all available ML signals.
     *
     * @param forecasts Multi-horizon forecasts per metric.
     * @param baselines Per-metric baselines.
     * @param anomalies Recent adaptive anomalies.
     * @param healthSignals Predictive health signal report.
     * @param patterns Discovered periodic patterns.
     * @param correlations FDR-significant correlations.
     * @param currentState Current health state.
     * @param dayCount Total days of user data.
     * @return The top [PolicyDecision], or a neutral fallback.
     */
    fun decide(
        forecasts: Map<HealthMetric, MultiHorizonForecast> = emptyMap(),
        baselines: Map<HealthMetric, MetricBaseline> = emptyMap(),
        anomalies: List<AdaptiveAnomalyDetector.AdaptiveAnomaly> = emptyList(),
        healthSignals: PredictiveHealthSignals.HealthSignalReport? = null,
        patterns: List<DiscoveredPattern> = emptyList(),
        correlations: List<MLCorrelation> = emptyList(),
        currentState: HealthState? = null,
        dayCount: Int = 0,
    ): PolicyDecision {
        // Step 1: Generate all intervention candidates.
        val candidates = mutableListOf<InterventionCandidate>()

        candidates.addAll(generateForecastCandidates(forecasts, baselines))
        candidates.addAll(generateAnomalyCandidates(anomalies))
        candidates.addAll(generateHealthSignalCandidates(healthSignals))
        candidates.addAll(generatePatternCandidates(patterns))
        candidates.addAll(generateCorrelationCandidates(correlations))
        candidates.addAll(generateStateCandidates(currentState))

        // Step 2: Score candidates by expected utility.
        val scored = candidates.map { candidate ->
            val utility = scoreCandidate(candidate, dayCount)
            candidate to utility
        }.sortedByDescending { it.second }

        // Step 3: Pick the top candidate that passes diversity checks.
        val now = System.currentTimeMillis()
        val decision = scored.firstOrNull { (candidate, _) ->
            passesDiversityCheck(candidate.actionType, now)
        }?.let { (candidate, utility) ->
            PolicyDecision(
                action = candidate.action,
                detail = candidate.detail,
                confidence = min(utility, 0.95),
                metric = candidate.metric,
                iconEmoji = candidate.iconEmoji,
            )
        } ?: neutralDecision()

        // Step 4: Record decision for exposure tracking.
        recordDecision(decision)

        return decision
    }

    // -- Candidate Generators ---------------------------------------------------

    private fun generateForecastCandidates(
        forecasts: Map<HealthMetric, MultiHorizonForecast>,
        baselines: Map<HealthMetric, MetricBaseline>,
    ): List<InterventionCandidate> {
        val candidates = mutableListOf<InterventionCandidate>()

        for ((metric, mhf) in forecasts) {
            val pred1d = mhf.forecasts[1] ?: continue
            val baseline = baselines[metric] ?: continue
            if (baseline.standardDeviation <= 0) continue

            val deviation = if (metric.higherIsBetter) {
                (baseline.mean - pred1d.predictedValue) / baseline.standardDeviation
            } else {
                (pred1d.predictedValue - baseline.mean) / baseline.standardDeviation
            }

            if (deviation > 1.0) {
                candidates.add(
                    InterventionCandidate(
                        source = CandidateSource.FORECAST,
                        actionType = "forecast_dip_${metric.name}",
                        action = "Pay attention to ${metric.displayName}",
                        detail = "Your ${metric.displayName} is forecast to dip tomorrow. " +
                            "A small adjustment to your routine may help.",
                        metric = metric,
                        iconEmoji = "\u26A0\uFE0F",
                        predictedUplift = min(deviation * 0.2, 0.8),
                        confidence = pred1d.confidence,
                    ),
                )
            }
        }

        return candidates
    }

    private fun generateAnomalyCandidates(
        anomalies: List<AdaptiveAnomalyDetector.AdaptiveAnomaly>,
    ): List<InterventionCandidate> {
        val surfaced = anomalies.filter { it.shouldSurface }
        if (surfaced.isEmpty()) return emptyList()

        return surfaced.take(3).map { anomaly ->
            val topFeature = anomaly.anomalousFeatures.firstOrNull()?.first?.metric
            InterventionCandidate(
                source = CandidateSource.ANOMALY,
                actionType = "anomaly_${topFeature?.name ?: "general"}",
                action = "Unusual pattern detected",
                detail = if (topFeature != null) {
                    "Your ${topFeature.displayName} is behaving unusually${if (anomaly.crossSignalConfirmation) " and confirmed across related metrics" else ""}."
                } else {
                    "Some of your health metrics are showing unusual patterns."
                },
                metric = topFeature,
                iconEmoji = "\uD83D\uDD0D",
                predictedUplift = 0.3,
                confidence = anomaly.globalScore,
            )
        }
    }

    private fun generateHealthSignalCandidates(
        report: PredictiveHealthSignals.HealthSignalReport?,
    ): List<InterventionCandidate> {
        if (report == null) return emptyList()

        return report.signals.filter { it.probability >= 0.3 }.map { signal ->
            val (action, emoji) = when (signal.type) {
                SignalType.FATIGUE -> "Focus on rest today" to "\uD83D\uDCA4"
                SignalType.BURNOUT -> "Take a recovery day" to "\u2764\uFE0F"
                SignalType.OVERTRAINING -> "Try a deload" to "\uD83C\uDFCB\uFE0F"
                SignalType.INSOMNIA -> "Focus on sleep quality" to "\uD83C\uDF19"
                SignalType.IMMUNE_DIP -> "Support your immune system" to "\uD83C\uDF4A"
                SignalType.INACTIVITY -> "Get moving today" to "\uD83C\uDFC3"
            }

            InterventionCandidate(
                source = CandidateSource.HEALTH_SIGNAL,
                actionType = "signal_${signal.type.name}",
                action = action,
                detail = signal.description,
                metric = null,
                iconEmoji = emoji,
                predictedUplift = signal.probability * 0.6,
                confidence = min(signal.probability + 0.2, 0.9),
            )
        }
    }

    private fun generatePatternCandidates(
        patterns: List<DiscoveredPattern>,
    ): List<InterventionCandidate> {
        // Only suggest when today matches a pattern's trough day.
        val today = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_WEEK)
        val candidates = mutableListOf<InterventionCandidate>()

        for (pattern in patterns) {
            if (pattern.patternType != PatternType.WEEKLY) continue
            if (pattern.troughDayOfWeek != today) continue

            candidates.add(
                InterventionCandidate(
                    source = CandidateSource.PATTERN,
                    actionType = "pattern_${pattern.metric.name}_weekly",
                    action = "Today is typically a dip day for ${pattern.metric.displayName}",
                    detail = pattern.description,
                    metric = pattern.metric,
                    iconEmoji = "\uD83D\uDCC9",
                    predictedUplift = 0.15,
                    confidence = pattern.strength,
                    effortLevel = 0.2,
                ),
            )
        }

        return candidates
    }

    private fun generateCorrelationCandidates(
        correlations: List<MLCorrelation>,
    ): List<InterventionCandidate> {
        // Surface strong actionable correlations as nudges.
        return correlations
            .filter { it.survivedFDR && abs(it.coefficient) >= 0.4 }
            .take(2)
            .map { corr ->
                val direction = if (corr.coefficient > 0) "positively" else "inversely"
                InterventionCandidate(
                    source = CandidateSource.CORRELATION,
                    actionType = "correlation_${corr.metricA.name}_${corr.metricB.name}",
                    action = "${corr.metricA.displayName} and ${corr.metricB.displayName} are linked",
                    detail = "Your ${corr.metricA.displayName} is $direction correlated with " +
                        "${corr.metricB.displayName} (r=${"%.2f".format(corr.coefficient)}).",
                    metric = corr.metricA,
                    iconEmoji = "\uD83D\uDD17",
                    predictedUplift = 0.15,
                    confidence = corr.stability,
                    effortLevel = 0.2,
                )
            }
    }

    private fun generateStateCandidates(
        currentState: HealthState?,
    ): List<InterventionCandidate> {
        if (currentState == null) return emptyList()

        val label = currentState.label
        val (action, detail, emoji) = when {
            label.contains("Stressed", ignoreCase = true) ->
                Triple("Help your body recover", "You're in a stressed state. Recovery activities could help.", "\uD83E\uDDD8")
            label.contains("Fatigued", ignoreCase = true) ->
                Triple("Rest and recharge", "Your body is showing signs of fatigue. Take it easy.", "\uD83D\uDE34")
            label.contains("Overreaching", ignoreCase = true) ->
                Triple("Balance training and rest", "You're training hard but recovery isn't keeping up.", "\u26A0\uFE0F")
            label.contains("Peak", ignoreCase = true) ->
                Triple("You're in great form", "Your body is performing well. Great time for a challenging workout.", "\u2B50")
            else -> return emptyList()
        }

        return listOf(
            InterventionCandidate(
                source = CandidateSource.STATE_TRANSITION,
                actionType = "state_${label.lowercase().replace(" ", "_")}",
                action = action,
                detail = detail,
                metric = null,
                iconEmoji = emoji,
                predictedUplift = 0.3,
                confidence = currentState.probability,
            ),
        )
    }

    // -- Scoring ----------------------------------------------------------------

    /**
     * Score a candidate by expected utility:
     * utility = predictedUplift * confidence * noveltyFactor * (1 - effortPenalty) * effectivenessBoost
     */
    private fun scoreCandidate(candidate: InterventionCandidate, dayCount: Int): Double {
        val uplift = candidate.predictedUplift
        val confidence = candidate.confidence

        // Novelty: penalize recently shown action types.
        val noveltyFactor = noveltyScore(candidate.actionType)

        // Effort penalty: higher effort = lower score.
        val effortPenalty = candidate.effortLevel * 0.3

        // Effectiveness boost from feedback history.
        val effectivenessMultiplier = categoryEffectiveness[candidate.actionType] ?: 0.5
        val effectivenessBoost = 0.5 + effectivenessMultiplier * 0.5

        // Personalization stage bonus.
        val personalWeight = if (dayCount >= 30) 1.0 else dayCount.toDouble() / 30.0

        return uplift * confidence * noveltyFactor * (1.0 - effortPenalty) * effectivenessBoost * (0.5 + 0.5 * personalWeight)
    }

    /** Novelty score: 1.0 if never shown, decays with recent exposures. */
    private fun noveltyScore(actionType: String): Double {
        val now = System.currentTimeMillis()
        val windowMs = EXPOSURE_WINDOW_DAYS.toLong() * 86_400_000L
        val recentDates = exposureLog[actionType]?.filter { now - it < windowMs } ?: emptyList()
        if (recentDates.isEmpty()) return 1.0
        return 1.0 / (1.0 + recentDates.size)
    }

    // -- Diversity Check --------------------------------------------------------

    /** Ensure we don't show the same action type more than twice in a week. */
    private fun passesDiversityCheck(actionType: String, now: Long): Boolean {
        val windowMs = EXPOSURE_WINDOW_DAYS.toLong() * 86_400_000L
        val recentCount = exposureLog[actionType]?.count { now - it < windowMs } ?: 0
        return recentCount < 2
    }

    // -- Recording & Feedback ---------------------------------------------------

    private fun recordDecision(decision: PolicyDecision) {
        val now = decision.decidedAt
        val actionType = decision.action.lowercase().replace(" ", "_")

        exposureLog.getOrPut(actionType) { mutableListOf() }.add(now)

        recentDecisions = (recentDecisions + decision).takeLast(MAX_RECENT_DECISIONS)
    }

    /**
     * Record user feedback on a recommendation.
     *
     * @param actionType The action type that was recommended.
     * @param wasHelpful Whether the user found the recommendation helpful (true/false).
     */
    fun recordFeedback(actionType: String, wasHelpful: Boolean) {
        val feedback = RecommendationFeedback(actionType, wasHelpful, System.currentTimeMillis())
        feedbackHistory.add(feedback)
        if (feedbackHistory.size > MAX_FEEDBACK_HISTORY) {
            feedbackHistory.removeAt(0)
        }

        // EMA update of category effectiveness.
        val current = categoryEffectiveness[actionType] ?: 0.5
        val observation = if (wasHelpful) 1.0 else 0.0
        val updated = current * (1.0 - EFFECTIVENESS_ALPHA) + observation * EFFECTIVENESS_ALPHA
        categoryEffectiveness = categoryEffectiveness + (actionType to updated)
    }

    data class RecommendationFeedback(
        val actionType: String,
        val wasHelpful: Boolean,
        val timestamp: Long,
    )

    // -- Neutral Fallback -------------------------------------------------------

    private fun neutralDecision(): PolicyDecision = PolicyDecision(
        action = "Stay the course",
        detail = "Your metrics look stable. Keep up your current routine.",
        confidence = 0.6,
        metric = null,
        iconEmoji = "\u2705",
    )
}
