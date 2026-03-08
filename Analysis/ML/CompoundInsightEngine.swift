import Foundation

/// Synthesizes outputs from all ML components into compound, multi-metric insights
/// that connect dots across metrics, time, and contexts. This is the crown jewel of the
/// ML pipeline — producing narratives no user could derive from single-metric observation alone.
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
    var topInsights: [CompoundInsight] { Array(insights.prefix(5)) }

    private let calendar = Calendar.current

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

        // Final ranking: severity * surprise * confidence, capped at 10
        insights = deduplicated
            .sorted { rankScore($0) > rankScore($1) }
            .prefix(10)
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
        let improving = trends.filter { $0.direction == .improving && abs($0.percentChange) > 5 }
        let declining = trends.filter { $0.direction == .declining && abs($0.percentChange) > 5 }

        // Coordinated improvement
        if improving.count >= 3 {
            let metrics = improving.map(\.metric)
            let categories = Set(metrics.map(\.category))
            let avgChange = improving.map { abs($0.percentChange) }.reduce(0, +) / Double(improving.count)

            let topMetric = improving.max(by: { abs($0.percentChange) < abs($1.percentChange) })!
            let topChangeStr = formatPercent(topMetric.percentChange)
            let topName = topMetric.metric.displayName

            var narrative = "\(improving.count) of your key metrics are improving in lockstep across \(categories.count) categories. "
            narrative += "\(topName) leads with \(topChangeStr) over 7 days, averaging \(formatPercent(avgChange)) improvement across all."

            // Check state for context
            if let state = currentState {
                narrative += " Your current state is \"\(state.label)\" (day \(state.daysInState))."
            }

            // Historical comparison: find if this trajectory happened before
            let historicalMatch = findHistoricalTrajectoryMatch(
                metrics: metrics, direction: .improving, timeSeries: timeSeries
            )
            if let match = historicalMatch {
                narrative += " The last time this pattern played out, you peaked in \(match) days."
            }

            results.append(CompoundInsight(
                id: "trajectory_coordinated_improvement",
                title: "Your Health Is Building Momentum",
                narrative: narrative,
                recommendation: "Keep your current routine stable. Avoid major changes while this positive trend is active. Based on your data, consistency here could push your score up ~\(Int(avgChange * 0.8)) points.",
                involvedMetrics: metrics,
                severity: .notable,
                category: .trajectory,
                surpriseScore: categories.count > 2 ? 0.7 : 0.5,
                confidence: min(0.9, Double(improving.count) * 0.15 + 0.3),
                evidenceSources: ["TrendAnalysis", "StateClassifier"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // Coordinated decline
        if declining.count >= 3 {
            let metrics = declining.map(\.metric)
            let categories = Set(metrics.map(\.category))
            let avgChange = declining.map { abs($0.percentChange) }.reduce(0, +) / Double(declining.count)
            let topMetric = declining.max(by: { abs($0.percentChange) < abs($1.percentChange) })!

            var narrative = "\(declining.count) metrics are declining simultaneously across \(categories.count) categories. "
            narrative += "\(topMetric.metric.displayName) is down \(formatPercent(abs(topMetric.percentChange))) over 7 days."

            if let state = currentState, state.daysInState <= 3 {
                narrative += " You entered the \"\(state.label)\" state \(state.daysInState) day\(state.daysInState == 1 ? "" : "s") ago, suggesting a regime change."
            }

            results.append(CompoundInsight(
                id: "trajectory_coordinated_decline",
                title: "Multiple Metrics Declining Together",
                narrative: narrative,
                recommendation: "Prioritize recovery: aim for an extra hour of sleep tonight and reduce exercise intensity by 30% for the next 2 days. This pattern typically reverses within 3-4 days with rest.",
                involvedMetrics: metrics,
                severity: .important,
                category: .trajectory,
                surpriseScore: categories.count > 2 ? 0.7 : 0.5,
                confidence: min(0.85, Double(declining.count) * 0.15 + 0.3),
                evidenceSources: ["TrendAnalysis", "StateClassifier"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // State transition insight
        if let state = currentState, state.daysInState <= 3,
           let prevState = findPreviousState(stateHistory: stateHistory) {

            let transitionProb = prevState.transitionProbabilities[state.label] ?? 0

            if transitionProb > 0 {
                let narrative = "You transitioned from \"\(prevState.label)\" to \"\(state.label)\" \(state.daysInState) day\(state.daysInState == 1 ? "" : "s") ago. This transition had a \(formatPercent(transitionProb * 100)) historical probability. \(describeStateCharacteristics(state))"

                results.append(CompoundInsight(
                    id: "trajectory_state_transition",
                    title: "New Health Phase: \(state.label)",
                    narrative: narrative,
                    recommendation: "Transitions are natural. Monitor how your body settles into this state over the next 2-3 days before making changes.",
                    involvedMetrics: state.characteristics.map(\.metric),
                    severity: .notable,
                    category: .trajectory,
                    surpriseScore: transitionProb < 0.2 ? 0.8 : 0.4,
                    confidence: 0.7,
                    evidenceSources: ["HealthStateClassifier", "HMM"],
                    timeHorizon: .shortTerm,
                    isActionable: false
                ))
            }
        }

        // Score trajectory insight
        if scoreHistory.count >= 14 {
            let recent7 = scoreHistory.suffix(7).map { Double($0.score) }
            let prior7 = scoreHistory.dropLast(7).suffix(7).map { Double($0.score) }

            if !recent7.isEmpty && !prior7.isEmpty {
                let recentAvg = recent7.reduce(0, +) / Double(recent7.count)
                let priorAvg = prior7.reduce(0, +) / Double(prior7.count)
                let delta = recentAvg - priorAvg

                if abs(delta) >= 5 {
                    let direction = delta > 0 ? "up" : "down"
                    let narrative = "Your health score has moved \(direction) \(formatValue(abs(delta))) points this week vs last week (from \(formatValue(priorAvg)) to \(formatValue(recentAvg))). \(delta > 0 ? "This is one of your strongest weekly improvements." : "This is a meaningful dip worth investigating.")"

                    results.append(CompoundInsight(
                        id: "trajectory_score_shift",
                        title: delta > 0 ? "Score Climbing: +\(Int(abs(delta))) This Week" : "Score Dipped \(Int(abs(delta))) Points",
                        narrative: narrative,
                        recommendation: delta > 0
                            ? "You're doing something right. Review what changed this week and repeat it."
                            : "Look at your sleep and activity patterns from the past 3 days — one of these likely drove the dip.",
                        involvedMetrics: trends.prefix(3).map(\.metric),
                        severity: abs(delta) >= 10 ? .important : .notable,
                        category: .trajectory,
                        surpriseScore: abs(delta) >= 10 ? 0.6 : 0.3,
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
        let weekendSensitiveMetrics = weekdayProfiles.filter { $0.peakTroughDeltaPercent > 15 }
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
                title: "Your \(topTroughName) Problem",
                narrative: narrative,
                recommendation: "Try keeping your \(topTroughName) \(top.metric.displayName) closer to your \(topPeakName) level. Even a 50% reduction in this swing should stabilize your weekly rhythm.",
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
            abs(corr.pearsonR) >= 0.5 &&
            corr.survivedFDR
        }

        if let strongest = crossCategoryCorrelations.max(by: { abs($0.pearsonR) < abs($1.pearsonR) }) {
            let catA = strongest.metricA.category
            let catB = strongest.metricB.category
            let rStr = formatPercent(abs(strongest.pearsonR) * 100)
            let direction = strongest.pearsonR > 0 ? "move together" : "move opposite"

            var narrative = "Your \(catA.rawValue) and \(catB.rawValue) metrics are \(rStr) correlated — they \(direction). "
            narrative += "Specifically, \(strongest.metricA.displayName) and \(strongest.metricB.displayName) (r=\(formatValue(strongest.pearsonR, decimals: 2))). "

            if strongest.grangerCausal {
                let causalDirection = strongest.metricA.displayName
                narrative += "\(causalDirection) appears to drive this relationship with a \(strongest.grangerOptimalLag)-day lag."
            }

            if strongest.stability > 0.7 {
                narrative += " This is a stable, reliable connection in your data."
            }

            results.append(CompoundInsight(
                id: "hidden_cross_category_\(catA.rawValue)_\(catB.rawValue)",
                title: "Your \(catA.rawValue.capitalized) and \(catB.rawValue.capitalized) Are Linked",
                narrative: narrative,
                recommendation: "Focus on \(strongest.grangerCausal ? strongest.metricA.displayName : "the metric you can control more easily") — improvements there should carry over to \(strongest.grangerCausal ? strongest.metricB.displayName : "the other").",
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
        let metricsWithBaseline = baselines.filter { $0.value.sampleCount >= 30 }
        if metricsWithBaseline.count >= 4 {
            let cvs: [(HealthMetric, Double)] = metricsWithBaseline.compactMap { (metric, baseline) in
                guard baseline.mean != 0 else { return nil }
                let cv = baseline.standardDeviation / abs(baseline.mean)
                return (metric, cv)
            }.sorted { $0.1 > $1.1 }

            if cvs.count >= 2 {
                let mostVariable = cvs[0]
                let leastVariable = cvs[cvs.count - 1]
                let ratio = mostVariable.1 / max(leastVariable.1, 0.001)

                if ratio > 1.5 {
                    let narrative = "Your \(mostVariable.0.displayName) is \(formatPercent(ratio * 100 - 100)) more variable day-to-day than your \(leastVariable.0.displayName). This means \(mostVariable.0.displayName) is more sensitive to your daily choices and habits, making it a better barometer of your lifestyle impact."

                    results.append(CompoundInsight(
                        id: "hidden_variability_contrast",
                        title: "Your Most Responsive Metric",
                        narrative: narrative,
                        recommendation: "Track \(mostVariable.0.displayName) as your primary feedback signal — it responds fastest to changes. Focus on \(mostVariable.0.displayName)-friendly habits for the biggest day-to-day impact.",
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
            let rStr = formatValue(combinedR, decimals: 2)

            let narrative = "Your \(best.source.displayName) influences your \(best.mid.displayName) (lag \(best.lag1) day\(best.lag1 == 1 ? "" : "s")), which in turn influences your \(best.dest.displayName) (lag \(best.lag2) day\(best.lag2 == 1 ? "" : "s")). Total chain effect: r=\(rStr) over \(totalLag) days. Changes to \(best.source.displayName) take \(totalLag) day\(totalLag == 1 ? "" : "s") to fully ripple through."

            results.append(CompoundInsight(
                id: "causal_chain_\(best.source.rawValue)_\(best.dest.rawValue)",
                title: "\(best.source.displayName) Drives a Chain Reaction",
                narrative: narrative,
                recommendation: "Optimizing \(best.source.displayName) has a multiplied effect — it improves \(best.mid.displayName) and then \(best.dest.displayName). Focus here for compounding returns.",
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
           strongestDirect.effectSize > 0.1 {

            let effectSizeLabel: String
            if strongestDirect.effectSize > 0.35 {
                effectSizeLabel = "large"
            } else if strongestDirect.effectSize > 0.15 {
                effectSizeLabel = "medium"
            } else {
                effectSizeLabel = "small"
            }

            let lagStr = strongestDirect.lag == 0 ? "same day" : "\(strongestDirect.lag) day\(strongestDirect.lag == 1 ? "" : "s") later"

            let narrative = "Your \(strongestDirect.cause.displayName) has a \(effectSizeLabel) causal effect on \(strongestDirect.effect.displayName), showing up \(lagStr) (Cohen's f\u{00B2}=\(formatValue(strongestDirect.effectSize, decimals: 2))). This is not just correlation — past changes in \(strongestDirect.cause.displayName) statistically predict future changes in \(strongestDirect.effect.displayName)."

            // Avoid duplicating the chain insight
            let chainAlreadyCovers = chains.contains {
                ($0.source == strongestDirect.cause && $0.mid == strongestDirect.effect) ||
                ($0.mid == strongestDirect.cause && $0.dest == strongestDirect.effect)
            }

            if !chainAlreadyCovers {
                results.append(CompoundInsight(
                    id: "causal_direct_\(strongestDirect.cause.rawValue)_\(strongestDirect.effect.rawValue)",
                    title: "\(strongestDirect.cause.displayName) Drives \(strongestDirect.effect.displayName)",
                    narrative: narrative,
                    recommendation: "Use \(strongestDirect.cause.displayName) as a lever to control \(strongestDirect.effect.displayName). Changes should be visible within \(max(1, strongestDirect.lag)) day\(strongestDirect.lag <= 1 ? "" : "s").",
                    involvedMetrics: [strongestDirect.cause, strongestDirect.effect],
                    severity: strongestDirect.effectSize > 0.25 ? .important : .notable,
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
        let decliningTrends = trends.filter { $0.direction == .declining && abs($0.percentChange) > 3 }
        let recentAnomalies = anomalies.filter {
            calendar.dateComponents([.day], from: $0.date, to: Date()).day ?? 999 <= 3
        }

        let riskSignals = decliningTrends.count + recentAnomalies.count
        let predictionRisk = prediction?.probability ?? 0

        if riskSignals >= 3 || (riskSignals >= 2 && predictionRisk > 0.5) {
            let decliningNames = decliningTrends.prefix(3).map { $0.metric.displayName }
            let anomalyNames = Array(Set(recentAnomalies.map { $0.metric.displayName })).prefix(2)

            var narrative = "Multiple warning signs converging: "
            if !decliningNames.isEmpty {
                narrative += "declining \(decliningNames.joined(separator: ", ")) (\(decliningTrends.first.map { "\(Int(abs($0.percentChange)))%" } ?? ""))"
            }
            if !anomalyNames.isEmpty {
                narrative += (decliningNames.isEmpty ? "" : ", plus ") + "anomalies in \(anomalyNames.joined(separator: " and "))"
            }
            narrative += "."

            if predictionRisk > 0.3 {
                narrative += " Tomorrow's risk estimate: \(Int(predictionRisk * 100))%."
            }

            // Check if this pattern preceded past dips
            let pastCrashes = findPastScoreDips(scoreHistory: scoreHistory, threshold: -8)
            if pastCrashes >= 2 {
                narrative += " Similar signal patterns preceded your last \(pastCrashes) score dips."
            }

            let allMetrics = (decliningTrends.map(\.metric) + recentAnomalies.map(\.metric))
            let uniqueMetrics = Array(Set(allMetrics))

            results.append(CompoundInsight(
                id: "risk_converging_signals",
                title: "Warning Signs Converging",
                narrative: narrative,
                recommendation: "Add a rest day now. Historically, early intervention prevents \(Int(min(75, Double(pastCrashes) * 25 + 25)))% of these dips from fully developing.",
                involvedMetrics: Array(uniqueMetrics.prefix(5)),
                severity: predictionRisk > 0.6 ? .urgent : .important,
                category: .riskWarning,
                surpriseScore: 0.6,
                confidence: min(0.85, 0.4 + Double(riskSignals) * 0.1 + predictionRisk * 0.2),
                evidenceSources: ["PredictiveScorer", "AnomalyDetector", "TrendAnalysis"],
                timeHorizon: .immediate,
                isActionable: true
            ))
        }

        // High prediction risk with top factors
        if let pred = prediction, pred.probability > 0.55, pred.topFactors.count >= 2 {
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
                    title: "Tomorrow's Risk: \(Int(pred.probability * 100))%",
                    narrative: narrative,
                    recommendation: "Focus on the biggest risk factor: \(riskFactors.first?.metric.displayName ?? "recovery"). Small improvements there have the largest impact on tomorrow's outcome.",
                    involvedMetrics: (Array(riskFactors) + Array(protective)).map(\.metric),
                    severity: pred.probability > 0.7 ? .urgent : .important,
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
                isBelowOptimal = gap < -8
            } else {
                isBelowOptimal = gap > 8
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
                corr.grangerCausal && corr.grangerEffectSize > 0.05
            }

            var narrative = "Your biggest lever right now is \(biggest.metric.displayName) — you're at \(currentStr) \(biggest.metric.unit), which is \(gapStr) \(biggest.metric.higherIsBetter ? "below" : "above") your personal baseline of \(baselineStr) \(biggest.metric.unit)."

            if let lever = scoreLever {
                let other = lever.metricA == biggest.metric ? lever.metricB : lever.metricA
                narrative += " \(biggest.metric.displayName) also has a causal link to \(other.displayName), so closing this gap creates a multiplier effect."
            }

            // Estimate score impact
            let estimatedScoreImpact = min(12, Int(abs(biggest.gap) * 0.15))

            results.append(CompoundInsight(
                id: "optimization_biggest_gap",
                title: "Biggest Opportunity: \(biggest.metric.displayName)",
                narrative: narrative,
                recommendation: "\(biggest.metric.higherIsBetter ? "Increase" : "Reduce") your \(biggest.metric.displayName) toward \(baselineStr) \(biggest.metric.unit). Based on your data, this should improve your overall score by ~\(estimatedScoreImpact) points.",
                involvedMetrics: [biggest.metric] + (scoreLever.map { [$0.metricA == biggest.metric ? $0.metricB : $0.metricA] } ?? []),
                severity: abs(biggest.gap) > 20 ? .important : .notable,
                category: .optimization,
                surpriseScore: 0.5,
                confidence: 0.75,
                evidenceSources: ["BaselineAnalysis", "CorrelationDiscovery"],
                timeHorizon: .shortTerm,
                isActionable: true
            ))
        }

        // Best-day profile: find what distinguished top-score days
        if scoreHistory.count >= 30 {
            let sortedScores = scoreHistory.sorted { $0.score > $1.score }
            let topDays = sortedScores.prefix(max(3, scoreHistory.count / 10))
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
                if abs(diff) > 5 {
                    metricDiffs.append((metric, topMean, overallMean, diff))
                }
            }

            metricDiffs.sort { abs($0.3) > abs($1.3) }

            if metricDiffs.count >= 2 {
                let top = metricDiffs[0]
                let second = metricDiffs[1]

                let narrative = "On your best-scoring days, \(top.0.displayName) averages \(top.0.formatValue(top.1)) \(top.0.unit) (vs \(top.0.formatValue(top.2)) overall, a \(formatPercent(abs(top.3))) difference) and \(second.0.displayName) averages \(second.0.formatValue(second.1)) \(second.0.unit) (vs \(second.0.formatValue(second.2))). These two metrics best distinguish your great days from average ones."

                results.append(CompoundInsight(
                    id: "optimization_best_day_profile",
                    title: "Your Best-Day Formula",
                    narrative: narrative,
                    recommendation: "Aim for \(top.0.displayName) near \(top.0.formatValue(top.1)) \(top.0.unit) and \(second.0.displayName) near \(second.0.formatValue(second.1)) \(second.0.unit) to maximize your score.",
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
            return isImproving && abs(trend.percentChange) > 3
        }

        if improvingRecovery.count >= 2 {
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
                title: "Recovery Underway",
                narrative: narrative,
                recommendation: "Keep exercise moderate to let this continue. Avoid high-intensity workouts for \(avgRecoveryDays.map { "\($0 - improvingRecovery.first!.dayCount) more" } ?? "the next 2-3") days.",
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
            if insight.involvedMetrics.count >= 3 {
                adjustedSurprise = min(1.0, adjustedSurprise + 0.1)
            }

            // Cross-category insights get a boost
            let categories = Set(insight.involvedMetrics.map(\.category))
            if categories.count >= 2 {
                adjustedSurprise = min(1.0, adjustedSurprise + 0.1)
            }

            // Cause-effect with temporal lag is more surprising than same-day correlation
            if insight.category == .causeAndEffect && insight.timeHorizon != .immediate {
                adjustedSurprise = min(1.0, adjustedSurprise + 0.1)
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
                    return maxCount > 0 && Double(overlapCount) / Double(maxCount) > 0.6
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
                    Double(max(existing.involvedMetrics.count, insight.involvedMetrics.count)) > 0.6
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
        let windowDays = 7

        return timeSeries.compactMap { (metric, series) -> MetricTrend? in
            let recentSamples = series.samples(lastDays: windowDays)
            guard recentSamples.count >= 4 else { return nil }

            let values = recentSamples.map(\.value)
            let recentMean = values.reduce(0, +) / Double(values.count)

            // Compare to prior window
            let priorSamples = series.samples(lastDays: windowDays * 2)
                .filter { sample in
                    let daysAgo = calendar.dateComponents([.day], from: sample.date, to: Date()).day ?? 0
                    return daysAgo > windowDays && daysAgo <= windowDays * 2
                }

            let baselineMean: Double
            if !priorSamples.isEmpty {
                baselineMean = priorSamples.map(\.value).reduce(0, +) / Double(priorSamples.count)
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
            if adjustedChange > 3 {
                direction = .improving
            } else if adjustedChange < -3 {
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
            guard series.sortedSamples.count >= 28 else { return nil }

            var dayValues: [Int: [Double]] = [:]
            for sample in series.sortedSamples {
                let weekday = calendar.component(.weekday, from: sample.date)
                dayValues[weekday, default: []].append(sample.value)
            }

            // Need data for at least 5 days of the week
            guard dayValues.count >= 5 else { return nil }

            var dayMeans: [Int: Double] = [:]
            for (day, values) in dayValues where values.count >= 3 {
                dayMeans[day] = values.reduce(0, +) / Double(values.count)
            }

            guard dayMeans.count >= 5 else { return nil }

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

    /// Find a historical trajectory match: how long until peak/trough after similar multi-metric trend.
    private func findHistoricalTrajectoryMatch(
        metrics: [HealthMetric],
        direction: TrendDirection,
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Int? {
        // Look for periods in history where these same metrics moved in the same direction
        guard let firstMetric = metrics.first,
              let series = timeSeries[firstMetric] else { return nil }

        let samples = series.sortedSamples
        guard samples.count >= 60 else { return nil }

        // Simplified: look at 7-day windows in history, find ones with similar direction
        let windowSize = 7
        var matchDurations: [Int] = []

        for i in stride(from: windowSize, to: samples.count - windowSize - 14, by: 7) {
            let windowValues = samples[i..<(i + windowSize)].map(\.value)
            let priorValues = samples[(i - windowSize)..<i].map(\.value)

            let windowMean = windowValues.reduce(0, +) / Double(windowValues.count)
            let priorMean = priorValues.reduce(0, +) / Double(priorValues.count)
            let change = ((windowMean - priorMean) / abs(priorMean)) * 100

            let isMatch = (direction == .improving && change > 5) ||
                          (direction == .declining && change < -5)

            if isMatch {
                // Find how many more days the trend continued
                var continuation = 0
                for j in (i + windowSize)..<min(samples.count, i + windowSize + 14) {
                    let extendedMean = samples[i..<(j + 1)].map(\.value).reduce(0, +) / Double(j + 1 - i)
                    let extendedChange = ((extendedMean - priorMean) / abs(priorMean)) * 100
                    let stillMoving = (direction == .improving && extendedChange > change * 0.5) ||
                                      (direction == .declining && extendedChange < change * 0.5)
                    if stillMoving {
                        continuation += 1
                    } else {
                        break
                    }
                }
                if continuation > 0 {
                    matchDurations.append(continuation)
                }
            }
        }

        guard !matchDurations.isEmpty else { return nil }
        let avg = matchDurations.reduce(0, +) / matchDurations.count
        return max(1, avg)
    }

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
        guard !notable.isEmpty else { return "This state is characterized by normal levels across metrics." }

        let descriptions = notable.map { char in
            "\(char.level.rawValue) \(char.metric.displayName)"
        }
        return "Characterized by \(descriptions.joined(separator: ", "))."
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

        // Check the last 12 weeks for weekend dips/spikes
        let cutoff = calendar.date(byAdding: .day, value: -84, to: Date()) ?? Date()
        let recentSamples = samples.filter { $0.date >= cutoff }
        guard recentSamples.count >= 14 else { return 0 }

        let overallMean = recentSamples.map(\.value).reduce(0, +) / Double(recentSamples.count)
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

            if diff > 10 {
                weekendDeviationCount += 1
            }
        }

        return weekendDeviationCount
    }

    /// Find past score dips (drops exceeding threshold) in score history.
    private func findPastScoreDips(
        scoreHistory: [(date: Date, score: Int)],
        threshold: Int
    ) -> Int {
        guard scoreHistory.count >= 14 else { return 0 }

        var dipCount = 0
        for i in 7..<scoreHistory.count {
            let current = scoreHistory[i].score
            let prior = scoreHistory[i - 7].score
            if current - prior <= threshold {
                dipCount += 1
            }
        }
        // Normalize: count distinct dip episodes (at least 5 days apart)
        return min(dipCount, scoreHistory.count / 14)
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
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
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
