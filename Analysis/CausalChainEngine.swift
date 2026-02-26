import Foundation

// MARK: - Causal Chain Models

/// A single cause-effect link between two metrics, backed by a correlation
struct ChainLink {
    let causeMetric: HealthMetric
    let effectMetric: HealthMetric
    let correlation: Double          // Pearson r value
    let lagDays: Int                 // 0 = same day, 1+ = cause precedes effect
    let causeDeviation: Double       // % deviation from baseline (signed)
    let effectDeviation: Double      // % deviation from baseline (signed)
    let explanation: String          // e.g. "Your deep sleep dropped 25%"
}

/// A validated chain of cause-effect links culminating in a problematic metric
struct CausalChain: Identifiable {
    let id = UUID()
    let links: [ChainLink]
    let affectedMetric: HealthMetric // the end-effect metric (the "problem")
    let confidence: Double           // 0-1, higher = more trustworthy
    let narrative: String            // full human-readable causal story
}

// MARK: - Engine

/// Builds causal chain narratives explaining WHY metrics changed.
/// Connects correlations, anomalies, and trends into human-readable cause-effect stories.
struct CausalChainEngine {

    // MARK: - Configuration

    /// Minimum absolute correlation strength to consider a link valid
    private static let minCorrelation: Double = 0.3

    /// Minimum absolute z-score or deviation % to consider a metric "significantly changed"
    private static let minZScore: Double = 1.5
    private static let minWeekOverWeekChange: Double = 5.0

    /// Maximum number of links in a chain (longer = too speculative)
    private static let maxChainLength = 3

    /// Metric pairs that are mathematically coupled and not insightful
    private static let trivialPairs: Set<Set<HealthMetric>> = [
        [.steps, .activeCalories],
        [.steps, .distanceWalkingRunning],
        [.activeCalories, .distanceWalkingRunning],
        [.activeCalories, .exerciseMinutes],
        [.sleepDuration, .sleepCore],
        [.sleepDuration, .sleepREM],
        [.sleepDuration, .sleepDeep],
        [.weight, .bmi],
        [.weight, .bodyFatPercentage],
        [.bloodPressureSystolic, .bloodPressureDiastolic],
        [.workoutCount, .workoutDuration],
        [.exerciseMinutes, .workoutDuration],
        [.basalCalories, .weight],
    ]

    // MARK: - Public API

    /// Build validated causal chains from analysis data.
    /// Returns chains sorted by confidence (highest first).
    static func buildChains(
        correlations: [HealthCorrelation],
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [CausalChain] {

        // Step 1: Identify effect metrics — metrics that are problematically deviating
        let effectMetrics = identifyEffectMetrics(anomalies: anomalies, trends: trends)
        guard !effectMetrics.isEmpty else { return [] }

        // Build lookup structures
        let anomalyByMetric = Dictionary(uniqueKeysWithValues: anomalies.map { ($0.metric, $0) })
        let correlationIndex = buildCorrelationIndex(correlations: correlations)

        // Step 2 & 3: For each effect metric, find and validate causal chains
        var allChains: [CausalChain] = []

        for effect in effectMetrics {
            let chains = traceChains(
                effectMetric: effect,
                correlationIndex: correlationIndex,
                anomalyByMetric: anomalyByMetric,
                trends: trends,
                timeSeries: timeSeries,
                baselines: baselines,
                visited: [effect]
            )
            allChains.append(contentsOf: chains)
        }

        // Step 4: Score, deduplicate, and rank
        let deduplicated = deduplicateChains(allChains)
        return deduplicated.sorted { $0.confidence > $1.confidence }
    }

    /// Convert causal chains into Insight objects for display in the insights feed
    static func generateInsights(from chains: [CausalChain]) -> [Insight] {
        chains.compactMap { chain -> Insight? in
            guard !chain.links.isEmpty else { return nil }

            let allMetrics = chain.links.flatMap { [$0.causeMetric, $0.effectMetric] }
            let uniqueRelated = Array(Set(allMetrics).subtracting([chain.affectedMetric]))

            // Severity based on the effect's deviation magnitude
            let effectDeviation = abs(chain.links.last?.effectDeviation ?? 0)
            let severity: Severity
            if effectDeviation >= 20 || chain.confidence >= 0.7 {
                severity = .warning
            } else {
                severity = .info
            }

            // Trend direction is always declining (we only chain problematic metrics)
            let recommendation = buildRecommendation(chain: chain)

            return Insight(
                metric: chain.affectedMetric,
                title: buildInsightTitle(chain: chain),
                summary: chain.narrative,
                recommendation: recommendation,
                severity: severity,
                trend: .declining,
                currentValue: chain.links.last?.effectDeviation ?? 0,
                baselineValue: 0,
                deviationPercent: chain.links.last?.effectDeviation ?? 0,
                category: .correlation,
                relatedMetrics: uniqueRelated
            )
        }
    }

    // MARK: - Step 1: Identify Effect Metrics

    /// Find metrics that are significantly deviating in a problematic direction.
    /// Only metrics that are declining or anomalous qualify as "effects" to explain.
    private static func identifyEffectMetrics(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> [HealthMetric] {
        var effects = Set<HealthMetric>()

        // Anomalies with significant z-scores in the wrong direction
        for anomaly in anomalies {
            let isProblematic: Bool
            if anomaly.metric.higherIsBetter {
                // For HRV, sleep, etc.: below baseline is bad
                isProblematic = !anomaly.isAboveBaseline
            } else {
                // For resting HR, etc.: above baseline is bad
                isProblematic = anomaly.isAboveBaseline
            }
            if isProblematic && abs(anomaly.zScore) >= minZScore {
                effects.insert(anomaly.metric)
            }
        }

        // Declining trends with meaningful week-over-week change
        for (metric, trend) in trends {
            if trend.direction == .declining && abs(trend.weekOverWeekChange) >= minWeekOverWeekChange {
                effects.insert(metric)
            }
        }

        return Array(effects)
    }

    // MARK: - Step 2: Correlation Index

    /// Build a lookup: for a given "effect" metric, what correlations could explain it?
    /// Returns: [effectMetric: [(causeMetric, correlation)]]
    private static func buildCorrelationIndex(
        correlations: [HealthCorrelation]
    ) -> [HealthMetric: [(cause: HealthMetric, corr: HealthCorrelation)]] {
        var index: [HealthMetric: [(cause: HealthMetric, corr: HealthCorrelation)]] = [:]

        for corr in correlations {
            guard abs(corr.correlation) >= minCorrelation else { continue }
            guard !isTrivialPair(corr.metricA, corr.metricB) else { continue }

            // metricA is the "cause" side, metricB is the "effect" side
            // (CorrelationAnalyzer structures them as cause → effect with dayOffset)
            index[corr.metricB, default: []].append((cause: corr.metricA, corr: corr))

            // For same-day correlations (dayOffset == 0), the direction is ambiguous,
            // so also index the reverse
            if corr.dayOffset == 0 {
                index[corr.metricA, default: []].append((cause: corr.metricB, corr: corr))
            }
        }

        return index
    }

    // MARK: - Step 2 & 3: Trace and Validate Chains

    /// Recursively trace causal chains backward from an effect metric.
    /// Returns all validated chains of length 1..maxChainLength.
    private static func traceChains(
        effectMetric: HealthMetric,
        correlationIndex: [HealthMetric: [(cause: HealthMetric, corr: HealthCorrelation)]],
        anomalyByMetric: [HealthMetric: AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        visited: Set<HealthMetric>,
        currentDepth: Int = 0
    ) -> [CausalChain] {

        guard currentDepth < maxChainLength else { return [] }

        // Find potential causes for this effect
        guard let potentialCauses = correlationIndex[effectMetric] else { return [] }

        var chains: [CausalChain] = []

        for (causeMetric, corr) in potentialCauses {
            // Avoid cycles
            guard !visited.contains(causeMetric) else { continue }

            // Validate this link: did the cause metric actually deviate?
            guard let link = validateLink(
                causeMetric: causeMetric,
                effectMetric: effectMetric,
                correlation: corr,
                anomalyByMetric: anomalyByMetric,
                trends: trends,
                timeSeries: timeSeries,
                baselines: baselines
            ) else { continue }

            // Build a 1-link chain from this link
            let singleLinkChain = assembleChain(links: [link], affectedMetric: effectMetric, baselines: baselines)
            chains.append(singleLinkChain)

            // Recurse: try to extend the chain by finding causes of the cause
            let deeperChains = traceChains(
                effectMetric: causeMetric,
                correlationIndex: correlationIndex,
                anomalyByMetric: anomalyByMetric,
                trends: trends,
                timeSeries: timeSeries,
                baselines: baselines,
                visited: visited.union([causeMetric]),
                currentDepth: currentDepth + 1
            )

            // Extend each deeper chain by prepending it to our link
            for deeperChain in deeperChains {
                let extendedLinks = deeperChain.links + [link]
                let extended = assembleChain(links: extendedLinks, affectedMetric: effectMetric, baselines: baselines)
                chains.append(extended)
            }
        }

        return chains
    }

    // MARK: - Step 3: Link Validation

    /// Validate a single cause→effect link. Returns nil if the link doesn't hold.
    private static func validateLink(
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        correlation: HealthCorrelation,
        anomalyByMetric: [HealthMetric: AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> ChainLink? {

        guard let causeBaseline = baselines[causeMetric],
              baselines[effectMetric] != nil else { return nil }

        let lag = correlation.dayOffset

        // Get cause metric's recent deviation, accounting for lag
        // If lag = 1, we check the cause metric 1+ days ago
        let causeDeviation = computeDeviation(
            metric: causeMetric,
            lagDays: lag,
            timeSeries: timeSeries,
            baselines: baselines,
            anomalyByMetric: anomalyByMetric
        )

        guard let causeDevPct = causeDeviation else { return nil }

        // The cause must have actually moved meaningfully
        guard abs(causeDevPct) >= 5.0 else { return nil }

        // Get effect metric's deviation (always "now")
        let effectDeviation = computeDeviation(
            metric: effectMetric,
            lagDays: 0,
            timeSeries: timeSeries,
            baselines: baselines,
            anomalyByMetric: anomalyByMetric
        )

        guard let effectDevPct = effectDeviation else { return nil }

        // Directional consistency: the deviations must align with the correlation direction
        // Positive correlation: both should deviate in the same direction
        // Negative correlation: they should deviate in opposite directions
        let deviationsAligned: Bool
        if correlation.isPositive {
            deviationsAligned = (causeDevPct > 0 && effectDevPct > 0) || (causeDevPct < 0 && effectDevPct < 0)
        } else {
            deviationsAligned = (causeDevPct > 0 && effectDevPct < 0) || (causeDevPct < 0 && effectDevPct > 0)
        }

        guard deviationsAligned else { return nil }

        // Build the explanation for this link
        let explanation = buildLinkExplanation(
            causeMetric: causeMetric,
            causeDeviation: causeDevPct,
            causeBaseline: causeBaseline
        )

        return ChainLink(
            causeMetric: causeMetric,
            effectMetric: effectMetric,
            correlation: correlation.correlation,
            lagDays: lag,
            causeDeviation: causeDevPct,
            effectDeviation: effectDevPct,
            explanation: explanation
        )
    }

    /// Compute a metric's deviation from baseline, optionally shifted by lag days.
    /// Returns nil if insufficient data.
    private static func computeDeviation(
        metric: HealthMetric,
        lagDays: Int,
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        anomalyByMetric: [HealthMetric: AnomalyDetector.AnomalyResult]
    ) -> Double? {

        // Fast path: if lag is 0 and we have a precomputed anomaly, use it
        if lagDays == 0, let anomaly = anomalyByMetric[metric] {
            return anomaly.deviationPercent
        }

        // Otherwise compute from time series
        guard let series = timeSeries[metric],
              let baseline = baselines[metric],
              baseline.mean != 0 else { return nil }

        // Get samples from the relevant window
        // For lag=0: last 3 days (matches AnomalyDetector)
        // For lag=N: N+1 to N+3 days ago
        let samples = series.sortedSamples
        let calendar = Calendar.current
        let now = Date()

        let windowStart = calendar.date(byAdding: .day, value: -(lagDays + 3), to: now) ?? now
        let windowEnd = calendar.date(byAdding: .day, value: -lagDays, to: now) ?? now

        let windowSamples = samples.filter { $0.date >= windowStart && $0.date <= windowEnd }
        guard !windowSamples.isEmpty else { return nil }

        let avg = windowSamples.map(\.value).mean
        return baseline.deviationPercent(for: avg)
    }

    // MARK: - Step 4: Chain Assembly and Scoring

    /// Assemble a chain from validated links, compute confidence, and generate narrative.
    private static func assembleChain(
        links: [ChainLink],
        affectedMetric: HealthMetric,
        baselines: [HealthMetric: UserBaseline]
    ) -> CausalChain {
        let confidence = computeConfidence(links: links)
        let narrative = generateNarrative(links: links, affectedMetric: affectedMetric, baselines: baselines)

        return CausalChain(
            links: links,
            affectedMetric: affectedMetric,
            confidence: confidence,
            narrative: narrative
        )
    }

    /// Chain confidence = average |correlation| of all links, scaled by chain length bonus.
    /// Longer validated chains get a modest boost (they explain more of the story).
    private static func computeConfidence(links: [ChainLink]) -> Double {
        guard !links.isEmpty else { return 0 }

        let avgCorrelation = links.map { abs($0.correlation) }.mean
        let lengthBonus: Double = switch links.count {
        case 1: 1.0
        case 2: 1.15
        case 3: 1.25
        default: 1.0
        }

        // Also factor in deviation magnitudes — bigger deviations = more convincing
        let avgDeviation = links.map { abs($0.causeDeviation) }.mean
        let deviationBonus = min(avgDeviation / 50.0, 0.2) // Up to +0.2 for large deviations

        return min((avgCorrelation * lengthBonus) + deviationBonus, 1.0)
    }

    /// Remove chains that are strict subsets of longer chains for the same affected metric.
    private static func deduplicateChains(_ chains: [CausalChain]) -> [CausalChain] {
        guard chains.count > 1 else { return chains }

        // Group by affected metric
        let grouped = Dictionary(grouping: chains) { $0.affectedMetric }
        var result: [CausalChain] = []

        for (_, group) in grouped {
            // Sort by link count descending — prefer longer chains
            let sorted = group.sorted { $0.links.count > $1.links.count }

            var kept: [CausalChain] = []
            for chain in sorted {
                let chainMetrics = Set(chain.links.map(\.causeMetric))

                // Check if this chain's cause metrics are a subset of any already-kept chain
                let isSubset = kept.contains { existing in
                    let existingMetrics = Set(existing.links.map(\.causeMetric))
                    return chainMetrics.isSubset(of: existingMetrics) && chain.links.count < existing.links.count
                }

                if !isSubset {
                    kept.append(chain)
                }
            }

            // Keep at most 2 chains per affected metric (best confidence)
            let topChains = kept.sorted { $0.confidence > $1.confidence }.prefix(2)
            result.append(contentsOf: topChains)
        }

        return result
    }

    // MARK: - Narrative Generation

    /// Generate a natural-language narrative for the full causal chain.
    private static func generateNarrative(
        links: [ChainLink],
        affectedMetric: HealthMetric,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        guard !links.isEmpty else { return "" }

        switch links.count {
        case 1:
            return generateSingleLinkNarrative(link: links[0], baselines: baselines)
        case 2:
            return generateTwoLinkNarrative(links: links, affectedMetric: affectedMetric, baselines: baselines)
        case 3:
            return generateThreeLinkNarrative(links: links, affectedMetric: affectedMetric, baselines: baselines)
        default:
            return generateSingleLinkNarrative(link: links[0], baselines: baselines)
        }
    }

    /// Narrative for a direct 1-link chain: "X changed because of Y"
    private static func generateSingleLinkNarrative(
        link: ChainLink,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        let effectName = link.effectMetric.displayName.lowercased()
        let causeName = link.causeMetric.displayName.lowercased()
        let effectDev = formatDeviation(link.effectDeviation)
        let causeDev = formatDeviation(link.causeDeviation)
        let effectDirection = link.effectDeviation > 0 ? "increased" : "decreased"
        let causeDirection = link.causeDeviation > 0 ? "increased" : "decreased"
        let absR = String(format: "%.2f", abs(link.correlation))
        let timeFrame = link.lagDays == 0 ? "this week" : (link.lagDays == 1 ? "over the past few days" : "over the past \(link.lagDays + 2) days")

        var narrative = "Your \(effectName) \(effectDirection) \(effectDev) \(timeFrame). "
        narrative += "Based on your personal data, this appears most likely connected to your \(causeName) "
        narrative += "\(causeDirection == "decreased" ? "dropping" : "rising") \(causeDev)"

        // Add baseline context if available
        if let causeBaseline = baselines[link.causeMetric] {
            let baselineFormatted = link.causeMetric.formatValue(causeBaseline.mean)
            narrative += " (from your \(baselineFormatted) \(link.causeMetric.unit) baseline)"
        }

        narrative += ". "

        // Add personal pattern context
        let strengthWord = abs(link.correlation) >= 0.5 ? "strong" : "moderate"
        narrative += "Your data shows a \(strengthWord) personal pattern between these metrics (r=\(absR))"

        if link.lagDays > 0 {
            narrative += " with effects typically showing \(link.lagDays == 1 ? "the next day" : "after \(link.lagDays) days")"
        }

        narrative += "."

        return narrative
    }

    /// Narrative for a 2-link chain: "X changed because of Y, which changed because of Z"
    private static func generateTwoLinkNarrative(
        links: [ChainLink],
        affectedMetric: HealthMetric,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        guard links.count == 2 else { return "" }

        let rootLink = links[0]   // root cause → intermediate
        let finalLink = links[1]  // intermediate → affected metric

        let affectedName = affectedMetric.displayName.lowercased()
        let intermediateName = finalLink.causeMetric.displayName.lowercased()
        let rootCauseName = rootLink.causeMetric.displayName.lowercased()

        let affectedDev = formatDeviation(finalLink.effectDeviation)
        let intermediateDev = formatDeviation(rootLink.effectDeviation)
        let rootDev = formatDeviation(rootLink.causeDeviation)

        let affectedDirection = finalLink.effectDeviation > 0 ? "increased" : "dropped"
        let intermediateDirection = rootLink.effectDeviation > 0 ? "increased" : "decreased"
        let rootDirection = rootLink.causeDeviation > 0 ? "increased" : "decreased"

        let rootR = String(format: "%.2f", abs(rootLink.correlation))

        var narrative = "Your \(affectedName) \(affectedDirection) \(affectedDev) this week. "
        narrative += "This appears connected to your \(intermediateName) — "

        if intermediateDirection == "decreased" {
            narrative += "your \(intermediateName) \(intermediateDirection) \(intermediateDev) over the same period. "
        } else {
            narrative += "your \(intermediateName) \(intermediateDirection) \(intermediateDev) recently. "
        }

        narrative += "Looking deeper, your \(rootCauseName) \(rootDirection) \(rootDev)"

        // Add time context for root cause
        let rootTimeWindow = rootLink.lagDays + finalLink.lagDays
        if rootTimeWindow > 0 {
            narrative += " in the past \(rootTimeWindow + 3) days"
        } else {
            narrative += " over the past week"
        }

        narrative += ", which correlates with \(intermediateDirection == "decreased" ? "reduced" : "elevated") \(intermediateName) for you (r=\(rootR)). "

        // The punchline: the likely chain
        narrative += "The likely chain: \(rootDirection) \(rootCauseName) -> "
        narrative += "\(intermediateDirection == "decreased" ? "less" : "more") \(intermediateName) -> "
        narrative += "\(affectedDirection == "dropped" ? "lower" : "higher") \(affectedName)."

        return narrative
    }

    /// Narrative for a 3-link chain: full story from root cause to final effect
    private static func generateThreeLinkNarrative(
        links: [ChainLink],
        affectedMetric: HealthMetric,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        guard links.count == 3 else { return "" }

        let rootLink = links[0]
        let midLink = links[1]
        let finalLink = links[2]

        let affectedName = affectedMetric.displayName.lowercased()
        let affectedDev = formatDeviation(finalLink.effectDeviation)
        let affectedDirection = finalLink.effectDeviation > 0 ? "increased" : "dropped"

        var narrative = "Your \(affectedName) \(affectedDirection) \(affectedDev) this week. "
        narrative += "Your data suggests a cascade of connected changes. "

        // Root cause
        let rootName = rootLink.causeMetric.displayName.lowercased()
        let rootDev = formatDeviation(rootLink.causeDeviation)
        let rootDirection = rootLink.causeDeviation > 0 ? "rose" : "dropped"
        narrative += "It started with your \(rootName), which \(rootDirection) \(rootDev). "

        // Middle link
        let midEffectName = midLink.effectMetric.displayName.lowercased()
        let midDev = formatDeviation(midLink.effectDeviation)
        let midDirection = midLink.effectDeviation > 0 ? "increased" : "decreased"
        narrative += "That appears to have \(midDirection == "decreased" ? "reduced" : "elevated") your \(midEffectName) (\(midDirection) \(midDev)). "

        // Final link
        let finalCauseName = finalLink.causeMetric.displayName.lowercased()
        let finalDirection = finalLink.effectDeviation > 0 ? "pushed up" : "brought down"
        narrative += "In turn, the change in \(finalCauseName) likely \(finalDirection) your \(affectedName). "

        // Summary chain
        let chainSummary = links.map { link in
            let dir = link.causeDeviation > 0 ? "higher" : "lower"
            return "\(dir) \(link.causeMetric.displayName.lowercased())"
        }
        narrative += "Likely chain: " + chainSummary.joined(separator: " -> ") + " -> \(affectedDirection) \(affectedName)."

        return narrative
    }

    // MARK: - Insight Helpers

    /// Generate an insight title for a chain
    private static func buildInsightTitle(chain: CausalChain) -> String {
        let affectedName = chain.affectedMetric.displayName
        if chain.links.count == 1 {
            let causeName = chain.links[0].causeMetric.displayName
            return "\(causeName) May Be Affecting Your \(affectedName)"
        } else {
            let rootCauseName = chain.links[0].causeMetric.displayName
            return "Why Your \(affectedName) Changed: \(rootCauseName) Connection"
        }
    }

    /// Generate a recommendation based on the chain's root cause
    private static func buildRecommendation(chain: CausalChain) -> String {
        guard let rootLink = chain.links.first else {
            return "Monitor your \(chain.affectedMetric.displayName.lowercased()) over the next few days."
        }

        let rootMetric = rootLink.causeMetric
        let rootIsProblematic: Bool
        if rootMetric.higherIsBetter {
            rootIsProblematic = rootLink.causeDeviation < 0
        } else {
            rootIsProblematic = rootLink.causeDeviation > 0
        }

        let metricName = rootMetric.displayName.lowercased()

        // Generate metric-specific recommendations
        switch rootMetric.category {
        case .sleep:
            if rootIsProblematic {
                return "Focus on improving your \(metricName). Consider consistent bedtimes, reducing screen time before bed, and keeping your room cool. This may have a cascading positive effect on your \(chain.affectedMetric.displayName.lowercased())."
            } else {
                return "Your \(metricName) increase may be affecting downstream metrics. If you've changed your sleep schedule recently, give your body a few days to adjust."
            }
        case .activity:
            if rootIsProblematic {
                return "Your \(metricName) has dropped. Try gradually increasing your activity level — even short walks can help. This could positively influence your \(chain.affectedMetric.displayName.lowercased())."
            } else {
                return "Your increased \(metricName) may be putting extra strain on recovery. Consider adding rest days or reducing intensity to let your body adapt. Your \(chain.affectedMetric.displayName.lowercased()) may improve as a result."
            }
        case .heart:
            return "Your \(metricName) change appears connected to other metrics. Focus on the root cause — the upstream factors in this chain — rather than the \(metricName) directly. Stress management, sleep quality, and exercise balance all play a role."
        case .mindfulness:
            if rootIsProblematic {
                return "Your \(metricName) has decreased. Even 5-10 minutes of mindfulness practice can help. This may have broader effects on your \(chain.affectedMetric.displayName.lowercased()) through stress reduction."
            } else {
                return "Your \(metricName) routine appears to be positively influencing other metrics. Keep it up."
            }
        default:
            if rootIsProblematic {
                return "Address the root factor: your \(metricName) has shifted from your baseline. Bringing it back to your normal range may help your \(chain.affectedMetric.displayName.lowercased()) recover."
            } else {
                return "Monitor whether your \(metricName) change continues. If your \(chain.affectedMetric.displayName.lowercased()) doesn't stabilize in a few days, consider other contributing factors."
            }
        }
    }

    // MARK: - Utility

    /// Format a deviation percentage for human-readable output
    private static func formatDeviation(_ deviation: Double) -> String {
        let abs = Swift.abs(deviation)
        if abs >= 10 {
            return String(format: "%.0f%%", abs)
        } else {
            return String(format: "%.1f%%", abs)
        }
    }

    /// Build a natural-language explanation for a single cause link
    private static func buildLinkExplanation(
        causeMetric: HealthMetric,
        causeDeviation: Double,
        causeBaseline: UserBaseline
    ) -> String {
        let name = causeMetric.displayName.lowercased()
        let dev = formatDeviation(causeDeviation)
        let direction = causeDeviation > 0 ? "increased" : "dropped"
        let baselineFormatted = causeMetric.formatValue(causeBaseline.mean)

        return "Your \(name) \(direction) \(dev) from your baseline of \(baselineFormatted) \(causeMetric.unit)"
    }

    /// Check if a metric pair is trivially correlated (just math, not insight)
    private static func isTrivialPair(_ a: HealthMetric, _ b: HealthMetric) -> Bool {
        trivialPairs.contains([a, b])
    }
}
