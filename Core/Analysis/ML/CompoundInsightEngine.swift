import Foundation

/// Synthesizes outputs from all ML components into compound, multi-metric insights
/// that connect dots across metrics, time, and contexts. This is the crown jewel of the
/// ML pipeline. producing narratives no user could derive from single-metric observation alone.
final class CompoundInsightEngine {

    // MARK: - Types

    struct CompoundInsight {
        let id: String
        let title: String
        let narrative: String
        let recommendation: String
        let involvedMetrics: [HealthMetric]
        let severity: InsightSeverity
        let category: CompoundCategory
        let surpriseScore: Double
        let confidence: Double
        let evidenceSources: [String]
        let timeHorizon: TimeHorizon
        let isActionable: Bool

        enum InsightSeverity: Int, Comparable {
            case fyi = 0, notable = 1, important = 2, urgent = 3
            static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
        }

        enum CompoundCategory: String {
            case trajectory
            case hiddenPattern
            case causeAndEffect
            case personalRecord
            case riskWarning
            case optimization
            case recovery
            case breakthrough
        }

        enum TimeHorizon: String {
            case immediate
            case shortTerm
            case mediumTerm
            case longTerm
        }
    }

    // MARK: - Internal Types

    /// Trend direction and magnitude for a single metric over a time window
    private struct MetricTrend {
        let metric: HealthMetric
        let direction: TrendDirection
        let ratePerDay: Double
        let percentChange: Double
        let recentMean: Double
        let baselineMean: Double
        let dayCount: Int
    }

    /// A causal link in a chain: A -> B with lag and strength
    private struct CausalLink {
        let cause: HealthMetric
        let effect: HealthMetric
        let lag: Int
        let strength: Double
        let effectSize: Double
    }

    /// Day-of-week profile for a metric
    private struct WeekdayProfile {
        let metric: HealthMetric
        let dayMeans: [Int: Double]  // weekday (1=Sun..7=Sat) -> mean value
        let overallMean: Double
        let peakDay: Int
        let troughDay: Int
        let peakTroughDeltaPercent: Double
    }

    // MARK: - State

    private(set) var insights: [CompoundInsight] = []
    var isReady: Bool { !insights.isEmpty }

    private let calendar = Date.cal

    // Natural Language Generator
    private let llmGenerator = LLMInsightGenerator()

    // MARK: - Synthesis thresholds

    /// Maximum number of compound insights returned to the UI after final ranking.
    private static let maxRankedInsights = 10
    /// Minimum percent change for a metric trend to be considered notable in trajectory synthesis.
    private static let notableTrendPercent: Double = 5
    /// Minimum count of coordinated improving/declining trends needed to surface a coordinated-trend insight.
    private static let coordinatedTrendMinCount = 3
    /// Recent days within which an anomaly is still considered a fresh risk signal.
    private static let recentAnomalyWindowDays = 3
    /// Minimum percent decline over the recent window before a trend is added to the risk signal count.
    private static let riskTrendPercent: Double = 3
    /// Combined risk-signal count above which the converging-warning insight surfaces unconditionally.
    private static let riskSignalsHighThreshold = 3
    /// Combined risk-signal count required when the predictive risk crosses the auxiliary threshold.
    private static let riskSignalsLowThreshold = 2
    /// Predictive probability above which the converging-warning insight escalates to "urgent".
    private static let predictionUrgentProbability: Double = 0.6
    /// Predictive probability used as the auxiliary trigger alongside `riskSignalsLowThreshold`.
    private static let predictionAuxProbability: Double = 0.5
    /// Predictive probability above which a standalone prediction-breakdown insight is generated.
    private static let predictionStandaloneProbability: Double = 0.55
    /// Predictive probability above which the standalone prediction insight escalates to "urgent".
    private static let predictionUrgentStandalone: Double = 0.7
    /// Predictive probability above which a converging-signal narrative includes the tomorrow-risk hint.
    private static let predictionMentionProbability: Double = 0.3
    /// Score-history dip (points within a 7-day window) considered a "score crash".
    private static let scoreCrashDelta = 10
    /// Same-week score delta (points) required before the trajectory-shift insight surfaces.
    private static let scoreShiftDelta: Double = 5
    /// Same-week score delta (points) above which the trajectory-shift insight is escalated to "important".
    private static let scoreShiftImportantDelta: Double = 10
    /// Pearson |r| threshold above which a cross-category correlation is included.
    private static let strongCrossCategoryR: Double = 0.5
    /// Stability score above which a cross-category correlation is described as "reliable".
    private static let stableCorrelationStability: Double = 0.7
    /// Effect size above which a direct causal pair is surfaced on its own.
    private static let causalDirectMinEffect: Double = 0.1
    /// Effect size above which a direct causal pair is escalated to "important".
    private static let causalImportantEffect: Double = 0.25
    /// Effect size above which a direct causal effect is labelled "large".
    private static let causalLargeEffect: Double = 0.35
    /// Effect size above which a direct causal effect is labelled "medium".
    private static let causalMediumEffect: Double = 0.15
    /// Granger effect size above which a metric is treated as a meaningful score lever.
    private static let scoreLeverEffect: Double = 0.05
    /// Optimization gap (% deviation) above which a metric is flagged as a top opportunity.
    private static let optimizationGapPercent: Double = 8
    /// Optimization gap (% deviation) above which the top-opportunity insight is escalated to "important".
    private static let optimizationImportantGapPercent: Double = 20
    /// Score-impact multiplier (per absolute % gap) used to estimate optimization upside.
    private static let optimizationScoreImpactPerPercent: Double = 0.15
    /// Maximum estimated score-impact returned for an optimization gap.
    private static let maxOptimizationScoreImpact: Int = 12
    /// Percent change above which a recovery trend is considered notable.
    private static let recoveryNotablePercent: Double = 3
    /// Minimum number of improving recovery metrics required for the recovery insight to surface.
    private static let recoveryMinMetrics = 2
    /// Weekday peak-trough delta (%) above which a metric is considered "weekend-sensitive".
    private static let weekendSensitiveDeltaPercent: Double = 15
    /// Weekend deviation (%) above which a single week is counted as a weekend-pattern occurrence.
    private static let weekendDeviationPercent: Double = 10
    /// Weeks used when counting recurring weekend-pattern occurrences.
    private static let weekendPatternHistoryWeeks = 12
    /// Variability ratio above which the most-variable metric is highlighted vs the least-variable.
    private static let variabilityContrastRatio: Double = 1.5
    /// Best-day-formula percent diff threshold above which a metric is included.
    private static let bestDayDiffPercent: Double = 5
    /// Direction (per metric) score adjustment used to flag a trend as improving/declining.
    private static let metricDirectionAdjustedPercent: Double = 3
    /// Trailing window (days) used by the recent-trend computation per metric.
    private static let trendWindowDays: Int = 7
    /// Minimum samples within the trend window before a metric trend is computed.
    private static let trendMinSamples: Int = 4
    /// Minimum sample count before a weekday profile is computed for a metric.
    private static let weekdayProfileMinSamples: Int = 28
    /// Minimum number of distinct weekdays with data required to build a profile.
    private static let weekdayProfileMinDays: Int = 5
    /// Minimum samples per weekday before that weekday contributes to the profile.
    private static let weekdayProfilePerDayMin: Int = 3
    /// Minimum baseline sample count required for a metric to enter the variability-contrast comparison.
    private static let variabilityMinBaselineSamples: Int = 30
    /// Minimum number of metrics with baselines required to surface the variability-contrast insight.
    private static let variabilityMinMetrics: Int = 4
    /// Score-history minimum length required before the score-trajectory shift insight surfaces.
    private static let scoreShiftMinHistory: Int = 14
    /// Score-history minimum length required before the best-day profile insight surfaces.
    private static let bestDayMinHistory: Int = 30
    /// Minimum number of metrics that distinguish best-scoring days before the insight surfaces.
    private static let bestDayMinDistinguishingMetrics: Int = 2
    /// Default top-day percentile divisor when picking distinguishing metrics for best-day profile.
    private static let bestDayPercentileDivisor: Int = 10
    /// Maximum days-in-state value for the state-transition insight to be considered fresh.
    private static let stateTransitionFreshnessDays: Int = 3
    /// Transition probability below which a state transition is flagged as surprising.
    private static let surprisingTransitionProbability: Double = 0.2
    /// Metric-overlap fraction above which two same-category insights are treated as duplicates.
    private static let duplicateOverlapFraction: Double = 0.6
    /// Surprise bonus added per qualifying surprise dimension during scoring.
    private static let surpriseBonusStep: Double = 0.1
    /// Number of involved metrics at/above which a compound insight is rewarded as cross-metric.
    private static let crossMetricCount: Int = 3
    /// Number of distinct categories at/above which a compound insight is rewarded as cross-category.
    private static let crossCategoryCount: Int = 2

    // MARK: - Main Entry Point

    /// Synthesize compound insights from all ML component outputs.
    func synthesize(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        correlations: [MLCorrelation],
        patterns: [DiscoveredPattern],
        currentState: HealthState?,
        stateHistory: [SmoothedHealthState],
        prediction: MLPrediction?,
        scoreHistory: [(date: Date, score: Int)],
        anomalies: [(date: Date, metric: HealthMetric, severity: String)]
    ) {
        var candidates: [CompoundInsight] = []

        // Compute shared intermediate analyses
        let trends = computeRecentTrends(timeSeries: timeSeries, baselines: baselines)
        let causalLinks = buildCausalLinks(from: correlations)
        let weekdayProfiles = buildWeekdayProfiles(timeSeries: timeSeries)

        // 1. Trajectory synthesis
        candidates.append(contentsOf: synthesizeTrajectory(
            trends: trends, currentState: currentState, stateHistory: stateHistory,
            scoreHistory: scoreHistory, timeSeries: timeSeries
        ))

        // 2. Hidden pattern synthesis
        candidates.append(contentsOf: synthesizeHiddenPatterns(
            patterns: patterns, correlations: correlations,
            weekdayProfiles: weekdayProfiles, timeSeries: timeSeries, baselines: baselines
        ))

        // 3. Cause-effect chains
        candidates.append(contentsOf: synthesizeCauseEffectChains(
            causalLinks: causalLinks, correlations: correlations, baselines: baselines
        ))

        // 4. Risk trajectory
        candidates.append(contentsOf: synthesizeRiskTrajectory(
            prediction: prediction, trends: trends, currentState: currentState,
            anomalies: anomalies, scoreHistory: scoreHistory
        ))

        // 5. Optimization insights
        candidates.append(contentsOf: synthesizeOptimization(
            trends: trends, correlations: correlations, baselines: baselines,
            timeSeries: timeSeries, scoreHistory: scoreHistory
        ))

        // 6. Recovery synthesis
        candidates.append(contentsOf: synthesizeRecovery(
            trends: trends, currentState: currentState, stateHistory: stateHistory,
            baselines: baselines
        ))

        // 7. Score surprise scoring and deduplication
        let scored = applySurpriseScoring(candidates)
        let deduplicated = deduplicateAndCohere(scored)

        // Final ranking: severity * surprise * confidence, capped at maxRankedInsights
        insights = deduplicated
            .sorted { rankScore($0) > rankScore($1) }
            .prefix(Self.maxRankedInsights)
            .map { $0 }
    }

    // MARK: - Trajectory Synthesis

    private func synthesizeTrajectory(
        trends: [MetricTrend],
        currentState: HealthState?,
        stateHistory: [SmoothedHealthState],
        scoreHistory: [(date: Date, score: Int)],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []

        // Find coordinated trends: multiple metrics moving in the same direction
        let improving = trends.filter { $0.direction == .improving && abs($0.percentChange) > Self.notableTrendPercent }
        let declining = trends.filter { $0.direction == .declining && abs($0.percentChange) > Self.notableTrendPercent }

        // Coordinated improvement
        if improving.count >= Self.coordinatedTrendMinCount {
            let metrics = improving.map(\.metric)
            let categories = Set(metrics.map(\.category))
            let avgChange = improving.map { abs($0.percentChange) }.reduce(0, +) / Double(improving.count)

            let topMetric = improving.max(by: { abs($0.percentChange) < abs($1.percentChange) })!
            
            // Generate Semantic LLM Context
            let context = LLMInsightGenerator.InsightContext(
                baseTopic: "health",
                primaryMetric: topMetric.metric,
                trendChange: topMetric.percentChange,
                riskScore: 0.1, // Proxy for momentum
                relatedMetrics: Array(metrics.prefix(3)),
                causalLag: nil,
                severity: .notable
            )
            
            let narrative = llmGenerator.synthesizeParagraph(context: context)

            results.append(CompoundInsight(
                id: "trajectory_coordinated_improvement",
                title: Copy.Insights.healthBuildingMomentum,
                narrative: narrative,
                recommendation: "\(improving.count) metrics improving in lockstep, averaging \(formatPercent(avgChange)) over 7 days across \(categories.count) categories.",
                involvedMetrics: metrics,
                severity: .notable,
                category: .trajectory,
                surpriseScore: categories.count > 2 ? 0.7 : 0.5,
                confidence: min(0.9, Double(improving.count) * 0.15 + 0.3),
                evidenceSources: ["TrendAnalysis", "StateClassifier", "LLMGenerator"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // Coordinated decline
        if declining.count >= Self.coordinatedTrendMinCount {
            let metrics = declining.map(\.metric)
            let categories = Set(metrics.map(\.category))
            let avgChange = declining.map { abs($0.percentChange) }.reduce(0, +) / Double(declining.count)
            let topMetric = declining.max(by: { abs($0.percentChange) < abs($1.percentChange) })!

            // Generate Semantic LLM Context
            let context = LLMInsightGenerator.InsightContext(
                baseTopic: "system",
                primaryMetric: topMetric.metric,
                trendChange: topMetric.percentChange, // real signed change: a decline must read as downward, not upward
                riskScore: 0.8, // High proxy for decline
                relatedMetrics: Array(metrics.prefix(3)),
                causalLag: nil,
                severity: .important
            )
            
            let narrative = llmGenerator.synthesizeParagraph(context: context)

            results.append(CompoundInsight(
                id: "trajectory_coordinated_decline",
                title: Copy.Insights.multipleMetricsDecliningTogether,
                narrative: narrative,
                recommendation: "\(declining.count) metrics declining simultaneously, averaging \(formatPercent(avgChange)) over 7 days across \(categories.count) categories. \(topMetric.metric.displayName) is the most affected.",
                involvedMetrics: metrics,
                severity: .important,
                category: .trajectory,
                surpriseScore: categories.count > 2 ? 0.7 : 0.5,
                confidence: min(0.85, Double(declining.count) * 0.15 + 0.3),
                evidenceSources: ["TrendAnalysis", "StateClassifier", "LLMGenerator"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // State transition insight
        if let state = currentState, state.daysInState <= Self.stateTransitionFreshnessDays,
           let prevState = findPreviousState(stateHistory: stateHistory) {

            let transitionProb = prevState.transitionProbabilities[state.label] ?? 0

            if transitionProb > 0 {
                let narrative = "You transitioned from \"\(prevState.label)\" to \"\(state.label)\" \(state.daysInState) day\(state.daysInState == 1 ? "" : "s") ago. This transition had a \(formatPercent(transitionProb * 100)) historical probability. \(describeStateCharacteristics(state))"

                results.append(CompoundInsight(
                    id: "trajectory_state_transition",
                    title: Copy.Insights.newHealthPhase(state.label),
                    narrative: narrative,
                    recommendation: "Transitioned from \"\(prevState.label)\" to \"\(state.label)\". this transition had a \(formatPercent(transitionProb * 100)) historical probability.",
                    involvedMetrics: state.characteristics.map(\.metric),
                    severity: .notable,
                    category: .trajectory,
                    surpriseScore: transitionProb < Self.surprisingTransitionProbability ? 0.8 : 0.4,
                    confidence: 0.7,
                    evidenceSources: ["HealthStateClassifier", "HMM"],
                    timeHorizon: .shortTerm,
                    isActionable: false
                ))
            }
        }

        // Score trajectory insight
        if scoreHistory.count >= Self.scoreShiftMinHistory {
            let recent7 = scoreHistory.suffix(7).map { Double($0.score) }
            let prior7 = scoreHistory.dropLast(7).suffix(7).map { Double($0.score) }

            if !recent7.isEmpty && !prior7.isEmpty {
                let recentAvg = recent7.reduce(0, +) / Double(recent7.count)
                let priorAvg = prior7.reduce(0, +) / Double(prior7.count)
                let delta = recentAvg - priorAvg

                if abs(delta) >= Self.scoreShiftDelta {
                    let direction = delta > 0 ? "up" : "down"
                    let narrative = "Your health score has moved \(direction) \(formatValue(abs(delta))) points this week vs last week (from \(formatValue(priorAvg)) to \(formatValue(recentAvg))). \(delta > 0 ? "This is one of your strongest weekly improvements." : "This is a meaningful dip worth investigating.")"

                    results.append(CompoundInsight(
                        id: "trajectory_score_shift",
                        title: delta > 0 ? "Score Climbing: +\(Int(abs(delta))) This Week" : "Score Dipped \(Int(abs(delta))) Points",
                        narrative: narrative,
                        recommendation: delta > 0
                            ? "Score moved from \(formatValue(priorAvg)) to \(formatValue(recentAvg)) week-over-week. a \(formatValue(abs(delta)))-point improvement."
                            : "Score dropped from \(formatValue(priorAvg)) to \(formatValue(recentAvg)) week-over-week. a \(formatValue(abs(delta)))-point decline.",
                        involvedMetrics: trends.prefix(3).map(\.metric),
                        severity: abs(delta) >= Self.scoreShiftImportantDelta ? .important : .notable,
                        category: .trajectory,
                        surpriseScore: abs(delta) >= Self.scoreShiftImportantDelta ? 0.6 : 0.3,
                        confidence: 0.8,
                        evidenceSources: ["ScoreHistory", "TrendAnalysis"],
                        timeHorizon: .mediumTerm,
                        isActionable: delta < 0
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Hidden Pattern Synthesis

    private func synthesizeHiddenPatterns(
        patterns: [DiscoveredPattern],
        correlations: [MLCorrelation],
        weekdayProfiles: [WeekdayProfile],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []

        // Weekend vs weekday behavioral cascade
        let weekendSensitiveMetrics = weekdayProfiles.filter { $0.peakTroughDeltaPercent > Self.weekendSensitiveDeltaPercent }
        if weekendSensitiveMetrics.count >= 2 {
            // Find the metric with the biggest weekend shift
            let sorted = weekendSensitiveMetrics.sorted { $0.peakTroughDeltaPercent > $1.peakTroughDeltaPercent }
            let top = sorted[0]
            let second = sorted[1]

            let topPeakName = dayName(top.peakDay)
            let topTroughName = dayName(top.troughDay)

            // Check if there's a downstream effect: does the trough day on one metric
            // correlate with a lagged change on another?
            let weekendCount = countWeekendPatternOccurrences(
                metric: top.metric, weekdayProfiles: weekdayProfiles, timeSeries: timeSeries
            )

            var narrative = "Your \(top.metric.displayName) swings \(formatPercent(top.peakTroughDeltaPercent)) between \(topPeakName) (peak) and \(topTroughName) (trough). "
            narrative += "\(second.metric.displayName) also shifts \(formatPercent(second.peakTroughDeltaPercent)) across the week. "

            if weekendCount > 0 {
                narrative += "This pattern has occurred in \(weekendCount) of the last 12 weeks."
            }

            let involvedMetrics = sorted.prefix(3).map(\.metric)

            results.append(CompoundInsight(
                id: "hidden_weekend_cascade",
                title: Copy.Insights.troughProblem(topTroughName),
                narrative: narrative,
                recommendation: "Your \(top.metric.displayName) swings \(formatPercent(top.peakTroughDeltaPercent)) between \(topPeakName) and \(topTroughName) weekly. \(second.metric.displayName) also shifts \(formatPercent(second.peakTroughDeltaPercent)).",
                involvedMetrics: involvedMetrics,
                severity: .notable,
                category: .hiddenPattern,
                surpriseScore: 0.75,
                confidence: min(0.85, 0.5 + Double(weekendSensitiveMetrics.count) * 0.1),
                evidenceSources: ["PatternMiner", "WeekdayAnalysis"],
                timeHorizon: .mediumTerm,
                isActionable: true
            ))
        }

        // Cross-category correlation insight
        let crossCategoryCorrelations = correlations.filter { corr in
            corr.metricA.category != corr.metricB.category &&
            abs(corr.pearsonR) >= Self.strongCrossCategoryR &&
            corr.survivedFDR
        }

        if let strongest = crossCategoryCorrelations.max(by: { abs($0.pearsonR) < abs($1.pearsonR) }) {
            let catA = strongest.metricA.category
            let catB = strongest.metricB.category
            let rPct = formatPercent(abs(strongest.pearsonR) * 100)
            let rCoeff = "r=\(formatValue(strongest.pearsonR, decimals: 2))"
            let direction = strongest.pearsonR > 0 ? "move together" : "move opposite"

            var narrative = "Your \(catA.rawValue) and \(catB.rawValue) metrics are \(rPct) correlated. they \(direction). "
            narrative += "Specifically, \(strongest.metricA.displayName) and \(strongest.metricB.displayName) (\(rCoeff)). "

            if strongest.grangerCausal {
                let causalDirection = strongest.metricA.displayName
                narrative += "\(causalDirection) appears to drive this relationship with a \(strongest.grangerOptimalLag)-day lag."
            }

            if strongest.stability > Self.stableCorrelationStability {
                narrative += " This is a stable, reliable connection in your data."
            }

            results.append(CompoundInsight(
                id: "hidden_cross_category_\(catA.rawValue)_\(catB.rawValue)",
                title: Copy.Insights.categoriesLinked(catA.rawValue.capitalized, catB.rawValue.capitalized),
                narrative: narrative,
                recommendation: "\(strongest.metricA.displayName) and \(strongest.metricB.displayName) \(direction) (\(rCoeff))\(strongest.grangerCausal ? ", with \(strongest.metricA.displayName) leading by \(strongest.grangerOptimalLag) day\(strongest.grangerOptimalLag == 1 ? "" : "s")" : "").",
                involvedMetrics: [strongest.metricA, strongest.metricB],
                severity: .notable,
                category: .hiddenPattern,
                surpriseScore: 0.7,
                confidence: min(0.9, abs(strongest.pearsonR) + 0.2),
                evidenceSources: ["CorrelationDiscovery", "GrangerCausality"],
                timeHorizon: .longTerm,
                isActionable: strongest.grangerCausal
            ))
        }

        // Variability comparison insight
        let metricsWithBaseline = baselines.filter { $0.value.sampleCount >= Self.variabilityMinBaselineSamples }
        if metricsWithBaseline.count >= Self.variabilityMinMetrics {
            let cvs: [(HealthMetric, Double)] = metricsWithBaseline.compactMap { (metric, baseline) in
                guard baseline.mean != 0 else { return nil }
                let cv = baseline.standardDeviation / abs(baseline.mean)
                return (metric, cv)
            }.sorted { $0.1 > $1.1 }

            if cvs.count >= 2 {
                let mostVariable = cvs[0]
                let leastVariable = cvs[cvs.count - 1]
                let ratio = mostVariable.1 / max(leastVariable.1, 0.001)

                if ratio > Self.variabilityContrastRatio {
                    let narrative = "Your \(mostVariable.0.displayName) is \(formatPercent(ratio * 100 - 100)) more variable day-to-day than your \(leastVariable.0.displayName). This means \(mostVariable.0.displayName) is more sensitive to your daily choices and habits, making it a better barometer of your lifestyle impact."

                    results.append(CompoundInsight(
                        id: "hidden_variability_contrast",
                        title: Copy.Insights.mostResponsiveMetric,
                        narrative: narrative,
                        recommendation: "\(mostVariable.0.displayName) has \(formatPercent(ratio * 100 - 100)) more day-to-day variability than \(leastVariable.0.displayName). it responds most to daily changes in your data.",
                        involvedMetrics: [mostVariable.0, leastVariable.0],
                        severity: .fyi,
                        category: .hiddenPattern,
                        surpriseScore: 0.65,
                        confidence: 0.8,
                        evidenceSources: ["BaselineAnalysis", "FeatureEngine"],
                        timeHorizon: .longTerm,
                        isActionable: true
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Cause-Effect Chain Synthesis

    private func synthesizeCauseEffectChains(
        causalLinks: [CausalLink],
        correlations: [MLCorrelation],
        baselines: [HealthMetric: UserBaseline]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []
        guard causalLinks.count >= 2 else { return results }

        // Build a directed graph from causal links
        var graph: [HealthMetric: [(target: HealthMetric, lag: Int, strength: Double)]] = [:]
        for link in causalLinks {
            graph[link.cause, default: []].append((link.effect, link.lag, link.strength))
        }

        // Find 2-step chains: A -> B -> C
        var chains: [(source: HealthMetric, mid: HealthMetric, dest: HealthMetric,
                       lag1: Int, lag2: Int, strength1: Double, strength2: Double)] = []

        for (source, targets) in graph {
            for target in targets {
                if let downstream = graph[target.target] {
                    for dest in downstream where dest.target != source {
                        chains.append((
                            source: source, mid: target.target, dest: dest.target,
                            lag1: target.lag, lag2: dest.lag,
                            strength1: target.strength, strength2: dest.strength
                        ))
                    }
                }
            }
        }

        // Pick the strongest chain
        if let best = chains.max(by: { ($0.strength1 * $0.strength2) < ($1.strength1 * $1.strength2) }) {
            let totalLag = best.lag1 + best.lag2
            let combinedR = best.strength1 * best.strength2
            // Generate Semantic LLM Context
            let context = LLMInsightGenerator.InsightContext(
                baseTopic: "system performance",
                primaryMetric: best.source,
                trendChange: nil, // causal chain has no trend magnitude — no fabricated %
                riskScore: 0.2, 
                relatedMetrics: [best.mid, best.dest],
                causalLag: totalLag,
                severity: .notable
            )
            
            let narrative = llmGenerator.synthesizeParagraph(context: context)
            
            results.append(CompoundInsight(
                id: "causal_chain_\(best.source.rawValue)_\(best.dest.rawValue)",
                title: "\(best.source.displayName) Drives a Chain Reaction",
                narrative: narrative,
                recommendation: "\(best.source.displayName) influences \(best.mid.displayName) (\(best.lag1)-day lag), which influences \(best.dest.displayName) (\(best.lag2)-day lag). Total chain effect: r=\(formatValue(combinedR, decimals: 2)) over \(totalLag) days.",
                involvedMetrics: [best.source, best.mid, best.dest],
                severity: .notable,
                category: .causeAndEffect,
                surpriseScore: 0.85,
                confidence: min(0.8, combinedR + 0.3),
                evidenceSources: ["GrangerCausality", "CorrelationDiscovery"],
                timeHorizon: .mediumTerm,
                isActionable: true
            ))
        }

        // Direct strong causal pair (even if no chain)
        if let strongestDirect = causalLinks.max(by: { $0.effectSize < $1.effectSize }),
           strongestDirect.effectSize > Self.causalDirectMinEffect {

            // Generate Semantic LLM Context
            let context = LLMInsightGenerator.InsightContext(
                baseTopic: "biological metrics",
                primaryMetric: strongestDirect.cause,
                trendChange: nil, // effect size is not a percent change — no fabricated %
                riskScore: 0.3,
                relatedMetrics: [strongestDirect.effect],
                causalLag: strongestDirect.lag,
                severity: strongestDirect.effectSize > Self.causalImportantEffect ? .important : .notable
            )
            
            let narrative = llmGenerator.synthesizeParagraph(context: context)

            // Avoid duplicating the chain insight
            let chainAlreadyCovers = chains.contains {
                ($0.source == strongestDirect.cause && $0.mid == strongestDirect.effect) ||
                ($0.mid == strongestDirect.cause && $0.dest == strongestDirect.effect)
            }

            let effectSizeLabel = strongestDirect.effectSize > Self.causalLargeEffect ? "large" : strongestDirect.effectSize > Self.causalMediumEffect ? "medium" : "small"
            let lagStr = strongestDirect.lag > 0 ? "after \(strongestDirect.lag) day\(strongestDirect.lag == 1 ? "" : "s")" : "same day"

            if !chainAlreadyCovers {
                results.append(CompoundInsight(
                    id: "causal_direct_\(strongestDirect.cause.rawValue)_\(strongestDirect.effect.rawValue)",
                    title: "\(strongestDirect.cause.displayName) Drives \(strongestDirect.effect.displayName)",
                    narrative: narrative,
                    recommendation: "\(strongestDirect.cause.displayName) causally predicts \(strongestDirect.effect.displayName) with a \(effectSizeLabel) effect size (f\u{00B2}=\(formatValue(strongestDirect.effectSize, decimals: 2))), visible \(lagStr).",
                    involvedMetrics: [strongestDirect.cause, strongestDirect.effect],
                    severity: strongestDirect.effectSize > Self.causalImportantEffect ? .important : .notable,
                    category: .causeAndEffect,
                    surpriseScore: 0.7,
                    confidence: min(0.85, strongestDirect.strength + 0.2),
                    evidenceSources: ["GrangerCausality"],
                    timeHorizon: strongestDirect.lag <= 1 ? .shortTerm : .mediumTerm,
                    isActionable: true
                ))
            }
        }

        return results
    }

    // MARK: - Risk Trajectory Synthesis

    private func synthesizeRiskTrajectory(
        prediction: MLPrediction?,
        trends: [MetricTrend],
        currentState: HealthState?,
        anomalies: [(date: Date, metric: HealthMetric, severity: String)],
        scoreHistory: [(date: Date, score: Int)]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []

        // Converging negative signals
        let decliningTrends = trends.filter { $0.direction == .declining && abs($0.percentChange) > Self.riskTrendPercent }
        let recentAnomalies = anomalies.filter {
            calendar.dateComponents([.day], from: $0.date, to: Date()).day ?? 999 <= Self.recentAnomalyWindowDays
        }

        let riskSignals = decliningTrends.count + recentAnomalies.count
        let predictionRisk = prediction?.probability ?? 0
        let pastCrashes: Int = {
            guard scoreHistory.count >= 2 else { return 0 }
            var count = 0
            for i in 1..<scoreHistory.count {
                if scoreHistory[i].score < scoreHistory[i - 1].score - Self.scoreCrashDelta { count += 1 }
            }
            return count
        }()

        if riskSignals >= Self.riskSignalsHighThreshold || (riskSignals >= Self.riskSignalsLowThreshold && predictionRisk > Self.predictionAuxProbability) {
            let allMetrics = (decliningTrends.map(\.metric) + recentAnomalies.map(\.metric))
            let uniqueMetrics = Array(Set(allMetrics))
            
            // Generate Semantic LLM Context
            let context = LLMInsightGenerator.InsightContext(
                baseTopic: "overall readiness",
                primaryMetric: uniqueMetrics.first ?? .restingHeartRate,
                trendChange: nil, // converging-risk synthesis has no single trend %
                riskScore: predictionRisk > 0 ? predictionRisk : 0.8,
                relatedMetrics: Array(uniqueMetrics.prefix(2)),
                causalLag: nil,
                severity: predictionRisk > Self.predictionUrgentProbability ? .urgent : .important
            )
            
            let narrative = llmGenerator.synthesizeParagraph(context: context)

            results.append(CompoundInsight(
                id: "risk_converging_signals",
                title: Copy.Insights.warningSignsConverging,
                narrative: narrative,
                recommendation: "\(riskSignals) risk signals converging.\(pastCrashes >= 2 ? " Similar patterns preceded your last \(pastCrashes) score dips." : "")\(predictionRisk > Self.predictionMentionProbability ? " Tomorrow's risk estimate: \(Int(predictionRisk * 100))%." : "")",
                involvedMetrics: Array(uniqueMetrics.prefix(5)),
                severity: predictionRisk > Self.predictionUrgentProbability ? .urgent : .important,
                category: .riskWarning,
                surpriseScore: 0.6,
                confidence: min(0.85, 0.4 + Double(riskSignals) * 0.1 + predictionRisk * 0.2),
                evidenceSources: ["PredictiveScorer", "AnomalyDetector", "TrendAnalysis"],
                timeHorizon: .immediate,
                isActionable: true
            ))
        }

        // High prediction risk with top factors
        if let pred = prediction, pred.probability > Self.predictionStandaloneProbability, pred.topFactors.count >= 2 {
            let riskFactors = pred.topFactors.filter { $0.isRiskFactor }.prefix(3)
            let protective = pred.topFactors.filter { !$0.isRiskFactor }.prefix(2)

            if !riskFactors.isEmpty {
                var narrative = "Tomorrow's outlook: \(Int(pred.probability * 100))% risk of a below-average day. "
                narrative += "Main risk factors: "
                narrative += riskFactors.map { factor in
                    "\(factor.metric.displayName) (\(factor.featureType == .raw ? "current level" : factor.featureType.rawValue))"
                }.joined(separator: ", ")
                narrative += "."

                if !protective.isEmpty {
                    narrative += " Working in your favor: \(protective.map(\.metric.displayName).joined(separator: ", "))."
                }

                results.append(CompoundInsight(
                    id: "risk_prediction_breakdown",
                    title: Copy.Insights.tomorrowsRisk(Int(pred.probability * 100)),
                    narrative: narrative,
                    recommendation: "Top risk factor: \(riskFactors.first?.metric.displayName ?? "recovery") (\(riskFactors.first?.featureType.rawValue ?? "current level")).\(protective.isEmpty ? "" : " Protective factors: \(protective.map(\.metric.displayName).joined(separator: ", ")).")",
                    involvedMetrics: (Array(riskFactors) + Array(protective)).map(\.metric),
                    severity: pred.probability > Self.predictionUrgentStandalone ? .urgent : .important,
                    category: .riskWarning,
                    surpriseScore: 0.5,
                    confidence: pred.confidence,
                    evidenceSources: ["PredictiveScorer", "GBT"],
                    timeHorizon: .immediate,
                    isActionable: true
                ))
            }
        }

        return results
    }

    // MARK: - Optimization Insights

    private func synthesizeOptimization(
        trends: [MetricTrend],
        correlations: [MLCorrelation],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        scoreHistory: [(date: Date, score: Int)]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []

        // Find the biggest gap between current and baseline
        let gaps: [(metric: HealthMetric, gap: Double, current: Double, baseline: Double)] = trends.compactMap { trend in
            guard let baseline = baselines[trend.metric] else { return nil }
            let currentMean = trend.recentMean
            let gap = baseline.deviationPercent(for: currentMean)

            // Only include if notably below baseline (or above for "lower is better" metrics)
            let isBelowOptimal: Bool
            if trend.metric.higherIsBetter {
                isBelowOptimal = gap < -Self.optimizationGapPercent
            } else {
                isBelowOptimal = gap > Self.optimizationGapPercent
            }
            guard isBelowOptimal else { return nil }
            return (trend.metric, gap, currentMean, baseline.mean)
        }.sorted { abs($0.gap) > abs($1.gap) }

        if let biggest = gaps.first {
            let gapStr = formatPercent(abs(biggest.gap))
            let currentStr = biggest.metric.formatValue(biggest.current)
            let baselineStr = biggest.metric.formatValue(biggest.baseline)

            // Check if this metric causally influences score
            let scoreLever = correlations.first { corr in
                (corr.metricA == biggest.metric || corr.metricB == biggest.metric) &&
                corr.grangerCausal && corr.grangerEffectSize > Self.scoreLeverEffect
            }

            var narrative = "Your biggest lever right now is \(biggest.metric.displayName). you're at \(currentStr) \(biggest.metric.unit), which is \(gapStr) \(biggest.metric.higherIsBetter ? "below" : "above") your personal baseline of \(baselineStr) \(biggest.metric.unit)."

            if let lever = scoreLever {
                let other = lever.metricA == biggest.metric ? lever.metricB : lever.metricA
                narrative += " \(biggest.metric.displayName) also has a causal link to \(other.displayName), so closing this gap creates a multiplier effect."
            }

            // Estimate score impact
            let estimatedScoreImpact = min(Self.maxOptimizationScoreImpact, Int(abs(biggest.gap) * Self.optimizationScoreImpactPerPercent))

            results.append(CompoundInsight(
                id: "optimization_biggest_gap",
                title: Copy.Insights.biggestOpportunity(biggest.metric.displayName),
                narrative: narrative,
                recommendation: "Your \(biggest.metric.displayName) is at \(currentStr) \(biggest.metric.unit). \(gapStr) \(biggest.metric.higherIsBetter ? "below" : "above") your \(baselineStr) \(biggest.metric.unit) baseline. Estimated score impact: ~\(estimatedScoreImpact) points.",
                involvedMetrics: [biggest.metric] + (scoreLever.map { [$0.metricA == biggest.metric ? $0.metricB : $0.metricA] } ?? []),
                severity: abs(biggest.gap) > Self.optimizationImportantGapPercent ? .important : .notable,
                category: .optimization,
                surpriseScore: 0.5,
                confidence: 0.75,
                evidenceSources: ["BaselineAnalysis", "CorrelationDiscovery"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // Best-day profile: find what distinguished top-score days
        if scoreHistory.count >= Self.bestDayMinHistory {
            let sortedScores = scoreHistory.sorted { $0.score > $1.score }
            let topDays = sortedScores.prefix(max(Self.bestDayMinDistinguishingMetrics + 1, scoreHistory.count / Self.bestDayPercentileDivisor))
            let topDates = Set(topDays.map { calendar.startOfDay(for: $0.date) })

            // Find metrics where top-score days differ most from average
            var metricDiffs: [(HealthMetric, Double, Double, Double)] = [] // metric, topDayMean, overallMean, diffPercent
            for (metric, series) in timeSeries {
                let topDayValues = series.sortedSamples.filter { topDates.contains(calendar.startOfDay(for: $0.date)) }.map(\.value)
                guard topDayValues.count >= 2 else { continue }
                let topMean = topDayValues.reduce(0, +) / Double(topDayValues.count)
                let overallMean = series.mean
                guard overallMean != 0 else { continue }
                let diff = ((topMean - overallMean) / abs(overallMean)) * 100
                if abs(diff) > Self.bestDayDiffPercent {
                    metricDiffs.append((metric, topMean, overallMean, diff))
                }
            }

            metricDiffs.sort { abs($0.3) > abs($1.3) }

            if metricDiffs.count >= Self.bestDayMinDistinguishingMetrics {
                let top = metricDiffs[0]
                let second = metricDiffs[1]

                let narrative = "On your best-scoring days, \(top.0.displayName) averages \(top.0.formatValue(top.1)) \(top.0.unit) (vs \(top.0.formatValue(top.2)) \(top.0.unit) overall, a \(formatPercent(abs(top.3))) difference) and \(second.0.displayName) averages \(second.0.formatValue(second.1)) \(second.0.unit) (vs \(second.0.formatValue(second.2)) \(second.0.unit)). These two metrics best distinguish your great days from average ones."

                results.append(CompoundInsight(
                    id: "optimization_best_day_profile",
                    title: Copy.Insights.yourBestDayFormula,
                    narrative: narrative,
                    recommendation: "On your best days, \(top.0.displayName) averages \(top.0.formatValue(top.1)) \(top.0.unit) and \(second.0.displayName) averages \(second.0.formatValue(second.1)) \(second.0.unit). These two metrics best distinguish your top-scoring days.",
                    involvedMetrics: metricDiffs.prefix(3).map(\.0),
                    severity: .fyi,
                    category: .optimization,
                    surpriseScore: 0.6,
                    confidence: min(0.85, 0.5 + Double(topDays.count) * 0.05),
                    evidenceSources: ["ScoreHistory", "BaselineAnalysis"],
                    timeHorizon: .longTerm,
                    isActionable: true
                ))
            }
        }

        return results
    }

    // MARK: - Recovery Synthesis

    private func synthesizeRecovery(
        trends: [MetricTrend],
        currentState: HealthState?,
        stateHistory: [SmoothedHealthState],
        baselines: [HealthMetric: UserBaseline]
    ) -> [CompoundInsight] {
        var results: [CompoundInsight] = []

        // Core recovery metrics
        let recoveryMetrics: Set<HealthMetric> = [
            .heartRateVariability, .restingHeartRate, .sleepDuration, .sleepDeep
        ]

        let recoveryTrends = trends.filter { recoveryMetrics.contains($0.metric) }
        let improvingRecovery = recoveryTrends.filter { trend in
            let isImproving: Bool
            if trend.metric.higherIsBetter {
                isImproving = trend.direction == .improving
            } else {
                isImproving = trend.direction == .improving
            }
            return isImproving && abs(trend.percentChange) > Self.recoveryNotablePercent
        }

        if improvingRecovery.count >= Self.recoveryMinMetrics {
            let metricDetails = improvingRecovery.map { trend -> String in
                let dir = trend.metric.higherIsBetter ? "up" : "down"
                return "\(trend.metric.displayName) \(dir) \(formatPercent(abs(trend.percentChange)))"
            }

            var narrative = "Your body is in a recovery trajectory. Over the past \(improvingRecovery.first?.dayCount ?? 7) days: \(metricDetails.joined(separator: ", ")). "

            // Check if returning toward baseline
            let returningToBaseline = improvingRecovery.filter { trend in
                guard let baseline = baselines[trend.metric] else { return false }
                let currentDev = abs(baseline.deviationPercent(for: trend.recentMean))
                let priorDev = abs(baseline.deviationPercent(for: trend.baselineMean))
                return currentDev < priorDev
            }

            if !returningToBaseline.isEmpty {
                narrative += "\(returningToBaseline.count) metric\(returningToBaseline.count == 1 ? " is" : "s are") converging back toward baseline."
            }

            // Historical: how long does recovery typically take?
            let avgRecoveryDays = estimateRecoveryDuration(stateHistory: stateHistory)
            if let days = avgRecoveryDays {
                narrative += " Based on your history, full recovery typically takes \(days) days."
            }

            results.append(CompoundInsight(
                id: "recovery_trajectory",
                title: Copy.Insights.recoveryUnderway,
                narrative: narrative,
                recommendation: "\(improvingRecovery.count) metrics recovering over \(improvingRecovery.first?.dayCount ?? 7) days.\(returningToBaseline.isEmpty ? "" : " \(returningToBaseline.count) converging back toward baseline.")\(avgRecoveryDays.map { " Historical average recovery: \($0) days." } ?? "")",
                involvedMetrics: improvingRecovery.map(\.metric),
                severity: .notable,
                category: .recovery,
                surpriseScore: 0.45,
                confidence: min(0.85, 0.5 + Double(improvingRecovery.count) * 0.12),
                evidenceSources: ["TrendAnalysis", "BaselineAnalysis", "StateClassifier"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        return results
    }

    // MARK: - Surprise Scoring

    private func applySurpriseScoring(_ insights: [CompoundInsight]) -> [CompoundInsight] {
        return insights.map { insight in
            var adjustedSurprise = insight.surpriseScore

            // Cross-metric insights are inherently more surprising
            if insight.involvedMetrics.count >= Self.crossMetricCount {
                adjustedSurprise = min(1.0, adjustedSurprise + Self.surpriseBonusStep)
            }

            // Cross-category insights get a boost
            let categories = Set(insight.involvedMetrics.map(\.category))
            if categories.count >= Self.crossCategoryCount {
                adjustedSurprise = min(1.0, adjustedSurprise + Self.surpriseBonusStep)
            }

            // Cause-effect with temporal lag is more surprising than same-day correlation
            if insight.category == .causeAndEffect && insight.timeHorizon != .immediate {
                adjustedSurprise = min(1.0, adjustedSurprise + Self.surpriseBonusStep)
            }

            return CompoundInsight(
                id: insight.id,
                title: insight.title,
                narrative: insight.narrative,
                recommendation: insight.recommendation,
                involvedMetrics: insight.involvedMetrics,
                severity: insight.severity,
                category: insight.category,
                surpriseScore: adjustedSurprise,
                confidence: insight.confidence,
                evidenceSources: insight.evidenceSources,
                timeHorizon: insight.timeHorizon,
                isActionable: insight.isActionable
            )
        }
    }

    // MARK: - Deduplication and Coherence

    private func deduplicateAndCohere(_ insights: [CompoundInsight]) -> [CompoundInsight] {
        var kept: [CompoundInsight] = []

        for insight in insights {
            // Check overlap with already-kept insights
            let isDuplicate = kept.contains { existing in
                // Same category + high metric overlap = duplicate
                if existing.category == insight.category {
                    let overlapCount = Set(existing.involvedMetrics).intersection(Set(insight.involvedMetrics)).count
                    let maxCount = max(existing.involvedMetrics.count, insight.involvedMetrics.count)
                    return maxCount > 0 && Double(overlapCount) / Double(maxCount) > Self.duplicateOverlapFraction
                }
                return false
            }

            // Check for contradiction with kept insights
            let contradicts = kept.contains { existing in
                // If one says "improving" and another says "declining" for the same primary metric
                let sameMetrics = Set(existing.involvedMetrics).intersection(Set(insight.involvedMetrics))
                if !sameMetrics.isEmpty {
                    let oneIsRisk = existing.category == .riskWarning || insight.category == .riskWarning
                    let oneIsRecovery = existing.category == .recovery || insight.category == .recovery
                    return oneIsRisk && oneIsRecovery
                }
                return false
            }

            if !isDuplicate && !contradicts {
                kept.append(insight)
            } else if isDuplicate {
                // Keep the one with higher rank score
                if let existingIdx = kept.firstIndex(where: { existing in
                    existing.category == insight.category &&
                    Double(Set(existing.involvedMetrics).intersection(Set(insight.involvedMetrics)).count) /
                    Double(max(existing.involvedMetrics.count, insight.involvedMetrics.count)) > Self.duplicateOverlapFraction
                }) {
                    if rankScore(insight) > rankScore(kept[existingIdx]) {
                        kept[existingIdx] = insight
                    }
                }
            }
            // If contradicts, skip the lower-confidence one (the new one, since we already have the other)
        }

        return kept
    }

    // MARK: - Conversion to Insight

    /// Convert compound insights to the app's Insight type for UI display.
    func toInsights() -> [Insight] {
        insights.map { compound in
            let primaryMetric = compound.involvedMetrics.first ?? .heartRateVariability
            let severity: Severity = switch compound.severity {
            case .urgent, .important: .critical
            case .notable: .warning
            case .fyi: .info
            }
            let trend: TrendDirection = switch compound.category {
            case .recovery, .breakthrough, .personalRecord: .improving
            case .riskWarning: .declining
            default: .stable
            }
            let insightCategory: InsightCategory = switch compound.category {
            case .trajectory: .scoreTrajectory
            case .hiddenPattern: .mlPattern
            case .causeAndEffect: .causalChain
            case .personalRecord: .personalRecord
            case .riskWarning: .mlPrediction
            case .optimization: .correlation
            case .recovery: .recovery
            case .breakthrough: .mlState
            }

            return Insight(
                metric: primaryMetric,
                title: compound.title,
                summary: compound.narrative,
                recommendation: compound.recommendation,
                severity: severity,
                trend: trend,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: compound.surpriseScore * 100,
                category: insightCategory,
                relatedMetrics: Array(compound.involvedMetrics.dropFirst()),
                context: InsightContext(
                    confidenceLevel: compound.confidence,
                    dataPointCount: compound.evidenceSources.count
                )
            )
        }
    }

    // MARK: - Shared Analysis Helpers

    /// Compute 7-day trend for each metric with sufficient data.
    private func computeRecentTrends(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [MetricTrend] {
        let windowDays = Self.trendWindowDays

        return timeSeries.compactMap { (metric, series) -> MetricTrend? in
            let recentSamples = series.samples(lastDays: windowDays)
            guard recentSamples.count >= Self.trendMinSamples else { return nil }

            let values = recentSamples.map(\.value)
            let recentMean = values.reduce(0, +) / Double(values.count)

            let priorSamples = series.samples(lastDays: windowDays * 2)
                .filter { sample in
                    let daysAgo = calendar.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
                    return daysAgo > windowDays && daysAgo <= windowDays * 2
                }

            let baselineMean: Double
            if !priorSamples.isEmpty {
                baselineMean = priorSamples.valueMean
            } else if let bl = baselines[metric] {
                baselineMean = bl.mean
            } else {
                baselineMean = series.mean
            }

            guard baselineMean != 0 else { return nil }

            let percentChange = ((recentMean - baselineMean) / abs(baselineMean)) * 100
            let ratePerDay = (recentMean - baselineMean) / Double(windowDays)

            let direction: TrendDirection
            let adjustedChange = metric.higherIsBetter ? percentChange : -percentChange
            if adjustedChange > Self.metricDirectionAdjustedPercent {
                direction = .improving
            } else if adjustedChange < -Self.metricDirectionAdjustedPercent {
                direction = .declining
            } else {
                direction = .stable
            }

            return MetricTrend(
                metric: metric,
                direction: direction,
                ratePerDay: ratePerDay,
                percentChange: percentChange,
                recentMean: recentMean,
                baselineMean: baselineMean,
                dayCount: windowDays
            )
        }
    }

    /// Extract causal links from correlation data.
    private func buildCausalLinks(from correlations: [MLCorrelation]) -> [CausalLink] {
        correlations.compactMap { corr -> CausalLink? in
            guard corr.grangerCausal, corr.survivedFDR else { return nil }
            return CausalLink(
                cause: corr.metricA,
                effect: corr.metricB,
                lag: corr.grangerOptimalLag,
                strength: abs(corr.pearsonR),
                effectSize: corr.grangerEffectSize
            )
        }
    }

    /// Build day-of-week profiles for metrics with weekly patterns.
    private func buildWeekdayProfiles(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [WeekdayProfile] {
        return timeSeries.compactMap { (metric, series) -> WeekdayProfile? in
            guard series.sortedSamples.count >= Self.weekdayProfileMinSamples else { return nil }

            var dayValues: [Int: [Double]] = [:]
            for sample in series.sortedSamples {
                let weekday = calendar.component(.weekday, from: sample.date)
                dayValues[weekday, default: []].append(sample.value)
            }

            // Need data for enough distinct weekdays
            guard dayValues.count >= Self.weekdayProfileMinDays else { return nil }

            var dayMeans: [Int: Double] = [:]
            for (day, values) in dayValues where values.count >= Self.weekdayProfilePerDayMin {
                dayMeans[day] = values.reduce(0, +) / Double(values.count)
            }

            guard dayMeans.count >= Self.weekdayProfileMinDays else { return nil }

            let overallMean = series.mean
            guard overallMean != 0 else { return nil }

            let peakDay = dayMeans.max(by: { $0.value < $1.value })!
            let troughDay = dayMeans.min(by: { $0.value < $1.value })!

            let deltaPercent = abs((peakDay.value - troughDay.value) / abs(overallMean)) * 100

            return WeekdayProfile(
                metric: metric,
                dayMeans: dayMeans,
                overallMean: overallMean,
                peakDay: peakDay.key,
                troughDay: troughDay.key,
                peakTroughDeltaPercent: deltaPercent
            )
        }
    }

    // MARK: - Utility Helpers

    /// Find the previous state before the current one from state history.
    private func findPreviousState(stateHistory: [SmoothedHealthState]) -> HealthState? {
        guard stateHistory.count >= 2 else { return nil }
        let sorted = stateHistory.sorted { $0.date > $1.date }
        // Find the first transition day going backwards
        for state in sorted.dropFirst() {
            if state.isTransitionDay {
                return state.assignedState
            }
        }
        // If no transition found, return the oldest state
        return sorted.last?.assignedState
    }

    /// Describe the dominant characteristics of a health state.
    private func describeStateCharacteristics(_ state: HealthState) -> String {
        let notable = state.characteristics.filter { $0.level != .normal }.prefix(3)
        guard !notable.isEmpty else { return Copy.Insights.normalAcrossMetrics }

        let descriptions = notable.map { char in
            "\(char.level.rawValue) \(char.metric.displayName)"
        }
        return Copy.Insights.characterizedBy(descriptions.joined(separator: ", "))
    }

    /// Count how many of the last 12 weekends showed a similar day-of-week pattern.
    private func countWeekendPatternOccurrences(
        metric: HealthMetric,
        weekdayProfiles: [WeekdayProfile],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Int {
        guard let series = timeSeries[metric] else { return 0 }

        let samples = series.sortedSamples
        guard samples.count >= 28 else { return 0 }

        // Check the last weekendPatternHistoryWeeks for weekend dips/spikes
        let cutoff = calendar.date(byAdding: .day, value: -Self.weekendPatternHistoryWeeks * 7, to: Date()) ?? Date()
        let recentSamples = samples.filter { $0.date >= cutoff }
        guard recentSamples.count >= 14 else { return 0 }

        let overallMean = recentSamples.valueMean
        guard overallMean != 0 else { return 0 }

        var weekendDeviationCount = 0
        // Group by week number
        var weeks: [Int: [MetricSample]] = [:]
        for sample in recentSamples {
            let weekNum = calendar.component(.weekOfYear, from: sample.date)
            weeks[weekNum, default: []].append(sample)
        }

        for (_, weekSamples) in weeks {
            let weekendValues = weekSamples.filter {
                let wd = calendar.component(.weekday, from: $0.date)
                return wd == 1 || wd == 7
            }.map(\.value)

            let weekdayValues = weekSamples.filter {
                let wd = calendar.component(.weekday, from: $0.date)
                return wd >= 2 && wd <= 6
            }.map(\.value)

            guard !weekendValues.isEmpty, !weekdayValues.isEmpty else { continue }

            let weMean = weekendValues.reduce(0, +) / Double(weekendValues.count)
            let wdMean = weekdayValues.reduce(0, +) / Double(weekdayValues.count)
            let diff = abs((weMean - wdMean) / abs(overallMean)) * 100

            if diff > Self.weekendDeviationPercent {
                weekendDeviationCount += 1
            }
        }

        return weekendDeviationCount
    }

    /// Estimate typical recovery duration from state history.
    private func estimateRecoveryDuration(stateHistory: [SmoothedHealthState]) -> Int? {
        guard stateHistory.count >= 14 else { return nil }

        let sorted = stateHistory.sorted { $0.date < $1.date }
        var recoveryDurations: [Int] = []
        var currentRunLength = 0
        var inRecoveryLikeState = false

        for state in sorted {
            let isRecoveryLike = state.assignedState.characteristics.contains { char in
                (char.metric == .heartRateVariability && char.level == .high) ||
                (char.metric == .restingHeartRate && char.level == .low)
            }

            if isRecoveryLike {
                currentRunLength += 1
                inRecoveryLikeState = true
            } else if inRecoveryLikeState {
                if currentRunLength >= 2 {
                    recoveryDurations.append(currentRunLength)
                }
                currentRunLength = 0
                inRecoveryLikeState = false
            }
        }

        guard !recoveryDurations.isEmpty else { return nil }
        return recoveryDurations.reduce(0, +) / recoveryDurations.count
    }

    /// Compute a rank score for sorting insights.
    private func rankScore(_ insight: CompoundInsight) -> Double {
        let severityWeight = Double(insight.severity.rawValue + 1) * 1.5
        let surpriseWeight = insight.surpriseScore
        let confidenceWeight = insight.confidence
        let actionBonus = insight.isActionable ? 1.2 : 1.0
        return severityWeight * surpriseWeight * confidenceWeight * actionBonus
    }

    // MARK: - Formatting Helpers

    private func dayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return Copy.Insights.daySunday
        case 2: return Copy.Insights.dayMonday
        case 3: return Copy.Insights.dayTuesday
        case 4: return Copy.Insights.dayWednesday
        case 5: return Copy.Insights.dayThursday
        case 6: return Copy.Insights.dayFriday
        case 7: return Copy.Insights.daySaturday
        default: return "Day \(weekday)"
        }
    }

    private func formatPercent(_ value: Double) -> String {
        if abs(value) >= 10 {
            return "\(Int(value.rounded()))%"
        } else {
            return String(format: "%.1f%%", value)
        }
    }

    private func formatValue(_ value: Double, decimals: Int = 1) -> String {
        if decimals == 0 || abs(value) >= 100 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.\(decimals)f", value)
    }
}
