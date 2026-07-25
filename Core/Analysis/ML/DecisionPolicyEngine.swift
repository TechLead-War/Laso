import Foundation

// MARK: - Decision Policy Engine

/// Replaces the template-based DailyActionEngine with an expected-utility decision framework.
///
/// The engine generates intervention candidates from multiple ML sources, scores them using
/// expected utility (predicted uplift x confidence x adherence x novelty x effort),
/// applies fatigue/diversity controls, runs counterfactual sensitivity analysis via
/// PredictiveScorer, and produces ranked PolicyDecisions with natural language output.
///
/// Feedback integration closes the loop: per-actionType effectiveness is tracked via
/// exponential moving average and feeds back into future scoring.
final class DecisionPolicyEngine {

    // MARK: - Properties

    /// Recent decisions for exposure tracking and diversity enforcement
    private(set) var recentDecisions: [PolicyDecision] = []

    /// Recorded feedback for closed-loop effectiveness updates
    private(set) var feedbackHistory: [RecommendationFeedback] = []

    /// Per-actionType effectiveness learned from feedback (0.0-1.0)
    private(set) var categoryEffectiveness: [String: Double] = [:]

    /// Rolling 7-day exposure tracker: actionType rawValue -> list of shown dates
    private var exposureLog: [String: [Date]] = [:]

    /// Maximum recent decisions retained for exposure tracking
    private static let maxRecentDecisions = 50


    /// Cached decimal NumberFormatter — `formatted(_:)` is called
    /// up to three times per recommendation title. Per-call allocation is wasteful.
    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: - Candidate Generation

    /// Generate intervention candidates from all available ML signal sources.
    ///
    /// Each source contributes zero or more candidates. Candidates include uplift estimates,
    /// effort costs, adherence likelihoods, and evidence from the originating model.
    func generateCandidates(
        currentState: HealthState?,
        tomorrowRisk: MLPrediction?,
        causalDiscoveries: [MLCorrelation],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        anomalies: [AnomalyDetector.AnomalyResult],
        circadianRecommendations: [CircadianAnalyzer.TimingRecommendation],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        var candidates: [InterventionCandidate] = []

        candidates.append(contentsOf: candidatesFromPrediction(
            tomorrowRisk, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromCausal(
            causalDiscoveries, trends: trends, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromState(
            currentState, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromAnomalies(
            anomalies, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromTrends(
            trends, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromCircadian(
            circadianRecommendations, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromBaselines(
            baselines, trends: trends, timeSeries: timeSeries))

        return candidates
    }

    // MARK: - Expected Utility Scoring

    /// Score a candidate by expected utility.
    ///
    /// ```
    /// utility = predictedUplift * upliftConfidence * adherenceLikelihood
    ///         * noveltyFactor * (1 - effortPenalty)
    /// ```
    ///
    /// If historicalEffectiveness is available, blend:
    /// `utility *= (0.5 + historicalEffectiveness)`
    func scoreCandidate(_ candidate: InterventionCandidate) -> Double {
        let novelty = noveltyFactor(for: candidate.actionType)
        let effortPenalty = candidate.effortCost * 0.3

        var utility = candidate.predictedUplift
            * candidate.upliftConfidence
            * candidate.adherenceLikelihood
            * novelty
            * (1.0 - effortPenalty)

        if let historical = candidate.historicalEffectiveness {
            utility *= (0.5 + historical)
        }

        return max(0, utility)
    }

    // MARK: - Counterfactual Sensitivity

    /// Estimate what happens if the user follows this intervention.
    ///
    /// Modifies the target metric's raw feature by the predicted uplift,
    /// re-runs PredictiveScorer on the modified vector, and returns the
    /// delta in probability: P(bad_day | modified) - P(bad_day | current).
    ///
    /// A negative return means the intervention reduces bad-day probability (good).
    func estimateCounterfactual(
        action: InterventionCandidate,
        currentVector: DailyFeatureVector,
        scorer: PredictiveScorer
    ) -> Double? {
        // Get baseline prediction
        guard let basePrediction = scorer.predict(todayVector: currentVector) else {
            return nil
        }
        let baseProb = basePrediction.probability

        // Build modified vector: shift target metric's raw feature by predicted uplift
        var modifiedFeatures = currentVector.features
        let targetKey = FeatureKey(metric: action.targetMetric, type: .raw)

        guard let currentRaw = modifiedFeatures[targetKey],
              currentRaw != FeatureKey.missingSentinel else {
            return nil
        }

        // For higherIsBetter metrics, uplift means increasing the raw z-score.
        // For lowerIsBetter metrics, uplift means decreasing it.
        let upliftDirection: Double = action.targetMetric.higherIsBetter ? 1.0 : -1.0
        modifiedFeatures[targetKey] = currentRaw + (action.predictedUplift * upliftDirection)

        let modifiedVector = DailyFeatureVector(
            date: currentVector.date,
            features: modifiedFeatures,
            context: currentVector.context
        )

        // Get counterfactual prediction
        guard let modifiedPrediction = scorer.predict(todayVector: modifiedVector) else {
            return nil
        }

        // Delta: negative means reduced risk (intervention helps)
        return modifiedPrediction.probability - baseProb
    }

    // MARK: - Novelty and Fatigue Controls

    /// Compute novelty factor for an action type.
    /// Returns 1.0 if never shown, decays exponentially with exposure.
    func noveltyFactor(for actionType: InterventionCandidate.ActionType) -> Double {
        let count = recentExposureCount(for: actionType)
        return exp(-0.3 * Double(count))
    }

    /// Count how many times this actionType was shown in the past 7 days.
    func recentExposureCount(for actionType: InterventionCandidate.ActionType) -> Int {
        let key = actionType.rawValue
        let cutoff = Date.cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        guard let dates = exposureLog[key] else { return 0 }
        return dates.filter { $0 > cutoff }.count
    }

    /// Whether a candidate should be suppressed due to fatigue.
    /// Suppressed if shown 3+ times in 7 days AND no positive feedback received.
    private func isSuppressed(_ candidate: InterventionCandidate) -> Bool {
        let exposure = recentExposureCount(for: candidate.actionType)
        guard exposure >= 3 else { return false }

        // Check for any positive feedback for this action type in recent history
        let cutoff = Date.cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let hasPositiveFeedback = feedbackHistory.contains { feedback in
            feedback.actionType == candidate.actionType.rawValue
                && feedback.shownAt > cutoff
                && (feedback.estimatedUplift ?? 0) > 0
        }

        return !hasPositiveFeedback
    }

    /// Record that an action type was shown to the user.
    private func recordExposure(_ actionType: InterventionCandidate.ActionType) {
        let key = actionType.rawValue
        var dates = exposureLog[key] ?? []
        dates.append(Date())

        // Trim to last 14 days
        let cutoff = Date.cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        dates = dates.filter { $0 > cutoff }
        exposureLog[key] = dates
    }

    // MARK: - Decision Making

    /// Select the best intervention(s) from scored candidates.
    ///
    /// - Scores all candidates via expected utility
    /// - Applies novelty/fatigue suppression
    /// - Selects top candidate as primary
    /// - Selects best remaining candidate targeting a different metric as secondary
    /// - Generates rationale and confidence
    func decide(candidates: [InterventionCandidate], focusCategories: Set<HealthCategory> = []) -> PolicyDecision? {
        guard !candidates.isEmpty else { return nil }

        // Score and filter suppressed candidates; if all suppressed, fall back to unfiltered
        var scored = scoreCandidates(candidates, focusCategories: focusCategories, applySuppression: true)
        if scored.isEmpty {
            scored = scoreCandidates(candidates, focusCategories: focusCategories, applySuppression: false)
        }

        // Sort by utility descending
        scored.sort { $0.utility > $1.utility }

        guard let primary = scored.first else { return nil }

        // Build ranked interventions (language generated later via generateLanguage)
        let allRanked: [PolicyDecision.RankedIntervention] = scored.map { item in
            PolicyDecision.RankedIntervention(
                candidate: item.candidate,
                expectedUtility: item.utility,
                noveltyFactor: item.novelty,
                title: "",
                description: "",
                whyItMatters: "",
                expectedBenefit: ""
            )
        }

        // Secondary must target a different metric for diversity
        let secondary = scored.dropFirst().first { item in
            item.candidate.targetMetric != primary.candidate.targetMetric
        }

        // Build primary ranked intervention
        let primaryRanked = PolicyDecision.RankedIntervention(
            candidate: primary.candidate,
            expectedUtility: primary.utility,
            noveltyFactor: primary.novelty,
            title: "",
            description: "",
            whyItMatters: "",
            expectedBenefit: ""
        )

        let secondaryRanked: PolicyDecision.RankedIntervention?
        if let sec = secondary {
            secondaryRanked = PolicyDecision.RankedIntervention(
                candidate: sec.candidate,
                expectedUtility: sec.utility,
                noveltyFactor: sec.novelty,
                title: "",
                description: "",
                whyItMatters: "",
                expectedBenefit: ""
            )
        } else {
            secondaryRanked = nil
        }

        // Rationale: explain why primary was chosen
        let rationale = buildRationale(primary: primary.candidate, utility: primary.utility,
                                        secondary: secondary?.candidate)

        let decisionConfidence = computeDecisionConfidence(scored: scored)

        // Record exposure for selected actions
        recordExposure(primary.candidate.actionType)
        if let sec = secondary {
            recordExposure(sec.candidate.actionType)
        }

        let decision = PolicyDecision(
            primaryAction: primaryRanked,
            secondaryAction: secondaryRanked,
            allCandidates: allRanked,
            rationale: rationale,
            decisionConfidence: min(1.0, decisionConfidence),
            decidedAt: Date(),
            prescriptiveHeadline: "",
            targetSleepTime: nil,
            strainBudget: nil
        )

        // Store decision
        recentDecisions.append(decision)
        if recentDecisions.count > Self.maxRecentDecisions {
            recentDecisions.removeFirst(recentDecisions.count - Self.maxRecentDecisions)
        }

        return decision
    }

    // MARK: - Decision helpers

    private typealias ScoredCandidate = (candidate: InterventionCandidate, utility: Double, novelty: Double)

    /// Score every candidate, optionally skipping ones that are currently suppressed.
    private func scoreCandidates(
        _ candidates: [InterventionCandidate],
        focusCategories: Set<HealthCategory>,
        applySuppression: Bool
    ) -> [ScoredCandidate] {
        var scored: [ScoredCandidate] = []
        for candidate in candidates {
            if applySuppression, isSuppressed(candidate) { continue }
            var utility = scoreCandidate(candidate)
            let novelty = noveltyFactor(for: candidate.actionType)
            // Boost utility for candidates targeting user's focus areas
            if !focusCategories.isEmpty && focusCategories.contains(candidate.targetMetric.category) {
                utility *= 1.3
            }
            scored.append((candidate, utility, novelty))
        }
        return scored
    }

    /// Decision confidence: weighted mean of top 3 candidates' upliftConfidence.
    private func computeDecisionConfidence(scored: [ScoredCandidate]) -> Double {
        let top3 = scored.prefix(3)
        let totalUtility = top3.reduce(0.0) { $0 + $1.utility }
        if totalUtility > 0 {
            return top3.reduce(0.0) { sum, item in
                sum + item.candidate.upliftConfidence * (item.utility / totalUtility)
            }
        }
        return top3.reduce(0.0) { $0 + $1.candidate.upliftConfidence }
            / max(1.0, Double(top3.count))
    }

    // MARK: - Natural Language Generation

    /// Generate metric-specific natural language for a candidate intervention.
    ///
    /// Returns (title, description, whyMatters, expectedBenefit) with interpolated
    /// values from the user's baselines, trends, current values, and the candidate's evidence.
    func generateLanguage(
        for candidate: InterventionCandidate,
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries] = [:]
    ) -> (title: String, description: String, whyMatters: String, expectedBenefit: String) {
        let metric = candidate.targetMetric
        let baseline = baselines[metric]
        let trend = trends[metric]
        let unit = metric.unit
        let currentValue = timeSeries[metric]?.latestValue

        let title = generateTitle(candidate: candidate, baseline: baseline, currentValue: currentValue)
        let description = generateDescription(candidate: candidate, baseline: baseline, trend: trend, currentValue: currentValue)
        let whyMatters = generateWhyMatters(candidate: candidate, trend: trend, currentValue: currentValue, baseline: baseline)
        let expectedBenefit = generateExpectedBenefit(candidate: candidate, baseline: baseline, unit: unit, trend: trend)

        return (title, description, whyMatters, expectedBenefit)
    }

    // MARK: - Title Generation

    private func generateTitle(
        candidate: InterventionCandidate,
        baseline: UserBaseline?,
        currentValue: Double? = nil
    ) -> String {
        let metric = candidate.targetMetric
        let effectiveness = candidate.historicalEffectiveness

        // Build a context suffix when we have strong historical signal
        let effectivenessSuffix: String
        if let eff = effectiveness, eff > 0.6 {
            effectivenessSuffix = ". worked \(Int(eff * 100))% of the time for you"
        } else {
            effectivenessSuffix = ""
        }

        // Build a deviation context when current value differs from baseline
        func deviationContext() -> String {
            guard let current = currentValue, let bl = baseline, bl.mean > 0 else { return "" }
            let pct = Int(abs(bl.deviationPercent(for: current)))
            guard pct >= 10 else { return "" }
            let dir = current < bl.mean ? "below" : "above"
            return " (\(metric.formatValue(current)) \(metric.unit) is \(pct)% \(dir) your \(metric.formatValue(bl.mean)) \(metric.unit) baseline)"
        }

        let title: String
        switch candidate.actionType {
        case .sleepEarlier:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                let deficit = bl.mean - current
                if deficit > 0 {
                    title = "Your sleep is averaging \(metric.formatValue(current)) \(metric.unit). \(String(format: "%.1f", deficit)) \(metric.unit) below your \(metric.formatValue(bl.mean)) \(metric.unit) baseline"
                } else {
                    title = "Your sleep metrics shifted from baseline" + deviationContext()
                }
            } else {
                title = "Your sleep metrics shifted from baseline" + deviationContext()
            }
        case .sleepLater:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your sleep has been averaging \(metric.formatValue(current)) \(metric.unit) vs your \(metric.formatValue(bl.mean)) \(metric.unit) baseline"
            } else {
                title = "Your sleep metrics suggest a deficit"
            }
        case .extendSleep:
            if let bl = baseline, bl.mean > 0 {
                let targetHrs = bl.mean + 0.5
                if let current = currentValue, current < bl.mean {
                    title = "Your sleep is averaging \(metric.formatValue(current)) \(metric.unit). aim for \(String(format: "%.1f", targetHrs)) \(metric.unit) to exceed your \(String(format: "%.1f", bl.mean)) \(metric.unit) baseline"
                } else {
                    title = "Your sleep baseline is \(String(format: "%.1f", bl.mean)) \(metric.unit). target \(String(format: "%.1f", targetHrs)) \(metric.unit) for optimal recovery"
                }
            } else {
                title = "Your sleep metrics are below baseline"
            }
        case .reduceScreenTime:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                let pct = Int(abs(bl.deviationPercent(for: current)))
                title = "Your \(metric.displayName.lowercased()) is \(pct)% off baseline" + deviationContext()
            } else {
                title = "Your evening metrics shifted from baseline" + deviationContext()
            }
        case .reduceEvening:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your evening \(metric.displayName.lowercased()) is at \(metric.formatValue(current)) \(metric.unit) vs \(metric.formatValue(bl.mean)) \(metric.unit) baseline"
            } else {
                title = "Your evening metrics are off baseline"
            }
        case .activeRecovery:
            if let current = currentValue, let bl = baseline {
                let pct = Int(abs(bl.deviationPercent(for: current)))
                if pct >= 15 {
                    title = "Your \(metric.displayName.lowercased()) is \(pct)% off baseline. recovery mode"
                } else {
                    title = "Your \(metric.displayName.lowercased()) is near baseline. light active recovery zone"
                }
            } else {
                title = "Your recovery metrics suggest active recovery"
            }
        case .intensifyExercise:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your \(metric.displayName.lowercased()) is \(Int(abs(bl.deviationPercent(for: current))))% above baseline. recovery metrics are strong"
            } else {
                title = "Recovery metrics are above baseline. capacity is high"
            }
        case .reduceExercise:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your \(metric.displayName.lowercased()) is \(Int(abs(bl.deviationPercent(for: current))))% off baseline (\(metric.formatValue(current)) \(metric.unit) vs \(metric.formatValue(bl.mean)) \(metric.unit))"
            } else {
                title = "Your recovery metrics are below baseline"
            }
        case .shiftCaffeineTiming:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your \(metric.displayName.lowercased()) is \(metric.formatValue(current)) \(metric.unit). baseline is \(metric.formatValue(bl.mean)) \(metric.unit)"
            } else {
                title = "Your sleep-related metrics shifted from baseline"
            }
        case .reduceCaffeine:
            if let current = currentValue, let bl = baseline {
                title = "Your \(metric.displayName.lowercased()) is at \(metric.formatValue(current)) \(metric.unit). baseline is \(metric.formatValue(bl.mean)) \(metric.unit)"
            } else {
                title = "Your caffeine-related metrics are off baseline"
            }
        case .breathingSession:
            if let current = currentValue, let bl = baseline, metric == .heartRateVariability {
                let diff = Int(bl.mean - current)
                if diff > 5 {
                    title = "Your HRV is \(diff) \(metric.unit) below baseline (\(metric.formatValue(current)) \(metric.unit) vs \(metric.formatValue(bl.mean)) \(metric.unit))"
                } else {
                    title = "Your HRV is near baseline at \(metric.formatValue(current)) \(metric.unit)"
                }
            } else {
                title = "Your autonomic metrics are shifted from baseline"
            }
        case .meditation:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your stress-related metrics are \(Int(abs(bl.deviationPercent(for: current))))% off baseline"
            } else {
                title = "Your stress-related metrics shifted from baseline"
            }
        case .adjustMealTiming:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your \(metric.displayName.lowercased()) is at \(metric.formatValue(current)) \(metric.unit). baseline is \(metric.formatValue(bl.mean)) \(metric.unit)"
            } else {
                title = "Your sleep metrics suggest a digestion-related pattern"
            }
        case .hydration:
            if let bl = baseline, let current = currentValue {
                title = "Your hydration-related \(metric.displayName.lowercased()) is at \(metric.formatValue(current)) \(metric.unit). baseline is \(metric.formatValue(bl.mean)) \(metric.unit)"
            } else if let bl = baseline {
                title = "Your hydration baseline is \(metric.formatValue(bl.mean)) \(metric.unit)"
            } else {
                title = "Your hydration-related metrics are off baseline"
            }
        case .increaseSteps:
            if let bl = baseline {
                let rounded = (Int(bl.mean) / 500) * 500
                if let current = currentValue {
                    let gap = rounded - Int(current)
                    if gap > 1000 {
                        title = "Your steps are at \(Self.formatted(Int(current))). \(Self.formatted(gap)) below your \(Self.formatted(rounded)) baseline"
                    } else {
                        title = "Your steps are near your \(Self.formatted(rounded)) baseline"
                    }
                } else {
                    title = "Your step baseline is \(Self.formatted(rounded)) per day"
                }
            } else {
                title = "Your activity metrics are below baseline"
            }
        case .reduceSteps:
            if let current = currentValue, let bl = baseline, current > bl.mean * 1.3 {
                title = "Your activity is at \(metric.formatValue(current)) \(metric.unit). \(Int(bl.deviationPercent(for: current)))% above your \(metric.formatValue(bl.mean)) \(metric.unit) baseline"
            } else {
                title = "Your activity metrics are elevated above baseline"
            }
        case .napRecommendation:
            if let current = currentValue, let bl = baseline, bl.mean > 0 {
                title = "Your sleep deficit is \(metric.formatValue(abs(bl.mean - current))) \(metric.unit) below your \(metric.formatValue(bl.mean)) \(metric.unit) baseline"
            } else {
                title = "Your sleep metrics indicate a deficit"
            }
        }

        return title + effectivenessSuffix
    }

    // MARK: - Description Generation

    private func generateDescription(
        candidate: InterventionCandidate,
        baseline: UserBaseline?,
        trend: TrendAnalyzer.TrendResult?,
        currentValue: Double? = nil
    ) -> String {
        let metric = candidate.targetMetric
        var parts: [String] = []

        // Lead with current state vs baseline. use actual numbers
        if let bl = baseline {
            let evidence = candidate.evidence
            if let historical = evidence.historicalResponseMean, evidence.historicalResponseCount >= 3 {
                let direction = metric.higherIsBetter
                    ? (historical > 0 ? "improved" : "declined")
                    : (historical < 0 ? "improved" : "increased")
                parts.append(
                    "When you've taken similar action before, your \(metric.displayName.lowercased())"
                    + " \(direction) by \(metric.formatValue(abs(historical))) \(metric.unit)"
                    + " on average (\(evidence.historicalResponseCount) observations)."
                )
            } else if let current = currentValue {
                let dev = bl.deviationPercent(for: current)
                let absDevPct = Int(abs(dev))
                if absDevPct >= 5 {
                    let dir = dev < 0 ? "below" : "above"
                    parts.append(
                        "Your \(metric.displayName.lowercased()) is \(metric.formatValue(current)) \(metric.unit)"
                        + ". \(absDevPct)% \(dir) your personal baseline of \(metric.formatValue(bl.mean)) \(metric.unit)."
                    )
                } else {
                    parts.append(
                        "Your \(metric.displayName.lowercased()) is \(metric.formatValue(current)) \(metric.unit)"
                        + " (near your \(metric.formatValue(bl.mean)) \(metric.unit) baseline)."
                    )
                }
            } else {
                parts.append(
                    "Your \(metric.displayName.lowercased()) baseline is"
                    + " \(metric.formatValue(bl.mean)) \(metric.unit)."
                )
            }
        }

        // Add trend context with actual numbers
        if let trend, trend.direction == .declining {
            let wowAbs = Int(abs(trend.weekOverWeekChange))
            if wowAbs > 8 {
                parts.append(
                    "It has dropped \(wowAbs)% this week alone. the decline is accelerating."
                )
            } else if wowAbs > 2 {
                parts.append(
                    "It's been drifting down \(wowAbs)% week-over-week."
                )
            }
        } else if let trend, trend.direction == .improving {
            let wowAbs = Int(abs(trend.weekOverWeekChange))
            if wowAbs > 5 {
                parts.append(
                    "The positive trend (\(wowAbs)% up this week) makes now a good time to build on momentum."
                )
            }
        }

        // Source-specific detail. use actual evidence values
        switch candidate.source {
        case .predictiveModel:
            let factors = candidate.evidence.contributingFeatures.prefix(2)
            if !factors.isEmpty {
                let factorNames = factors.map { f in
                    let featureDesc: String
                    switch f.featureType {
                    case .roc: featureDesc = "\(f.metric.displayName) rate of change"
                    case .vol7: featureDesc = "\(f.metric.displayName) volatility"
                    case .devBaseline: featureDesc = "\(f.metric.displayName) baseline deviation"
                    default: featureDesc = f.metric.displayName
                    }
                    return featureDesc.lowercased()
                }
                let prob = Int(candidate.upliftConfidence * 100)
                parts.append(
                    "Tomorrow's risk model (\(prob)% confidence) identified \(factorNames.joined(separator: " and "))"
                    + " as the top drivers. this action targets the most impactful one."
                )
            } else {
                parts.append(
                    "Tomorrow's risk model flagged this as the highest-leverage action"
                    + " (\(Int(candidate.upliftConfidence * 100))% confidence)."
                )
            }

        case .causalDiscovery:
            let pValue = candidate.evidence.grangerPValue ?? 1.0
            let effectSize = candidate.evidence.grangerEffectSize ?? 0
            let lag = candidate.evidence.grangerOptimalLag
            if pValue < 0.05 {
                var causalDetail = "Causal analysis shows changes in \(metric.displayName.lowercased())"
                    + " reliably predict downstream health outcomes"
                if let lag, lag > 0 {
                    causalDetail += " \(lag) day\(lag == 1 ? "" : "s") later"
                }
                if effectSize > 0.15 {
                    causalDetail += " (strong effect size: f²=\(String(format: "%.2f", effectSize)))"
                } else if effectSize > 0.02 {
                    causalDetail += " (moderate effect)"
                }
                parts.append(causalDetail + ".")
            }

        case .stateTransition:
            let stateName = candidate.evidence.contributingFeatures.isEmpty
                ? "a suboptimal state"
                : "your current health state"
            parts.append(
                "You've been in \(stateName) for \(max(1, Int(candidate.upliftConfidence / 0.03))) days."
                + " Improving \(metric.displayName.lowercased()) is the key differentiator"
                + " to shift toward a healthier operating mode."
            )

        case .anomalyResponse:
            if let current = currentValue, let bl = baseline {
                let devPct = Int(abs(bl.deviationPercent(for: current)))
                parts.append(
                    "Your \(metric.displayName.lowercased()) (\(metric.formatValue(current)) \(metric.unit))"
                    + " is \(devPct)% outside your normal range."
                    + " Addressing it now prevents cascading effects on sleep and recovery."
                )
            } else {
                parts.append(
                    "Your recent reading is unusual compared to your personal history."
                    + " This action helps bring it back to your normal range."
                )
            }

        case .trendReversal:
            if let trend {
                let wowPct = Int(abs(trend.weekOverWeekChange))
                let inflectionNote = trend.inflection == .accelerating
                    ? " and the decline is accelerating" : ""
                parts.append(
                    "Your \(metric.displayName.lowercased()) is down \(wowPct)% week-over-week\(inflectionNote)."
                    + " Intervening now is easier than reversing a deeper decline."
                )
            }

        case .circadianTiming:
            parts.append(
                "Your circadian data shows this is your optimal window."
                + " Aligning with your biological rhythm multiplies the benefit."
            )

        case .baselineRecovery:
            if let current = currentValue, let bl = baseline {
                let devPct = Int(abs(bl.deviationPercent(for: current)))
                let gap = metric.formatValue(abs(current - bl.mean))
                parts.append(
                    "You're \(gap) \(metric.unit) (\(devPct)%) away from your personal baseline."
                    + " Closing this gap is the fastest path to feeling the difference."
                )
            } else {
                parts.append(
                    "You're significantly below your personal baseline."
                    + " This action focuses on recovering to your normal level."
                )
            }

        case .counterfactual:
            if let delta = candidate.evidence.forecastedScoreDelta {
                let direction = delta > 0 ? "improve" : "change"
                parts.append(
                    "Counterfactual analysis estimates this could \(direction)"
                    + " your overall score by \(Int(abs(delta))) points tomorrow."
                )
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Why It Matters

    private func generateWhyMatters(
        candidate: InterventionCandidate,
        trend: TrendAnalyzer.TrendResult?,
        currentValue: Double? = nil,
        baseline: UserBaseline? = nil
    ) -> String {
        let metric = candidate.targetMetric

        switch candidate.source {
        case .predictiveModel:
            let prob = Int(candidate.upliftConfidence * 100)
            if let factor = candidate.evidence.contributingFeatures.first {
                return Copy.Policy.predictiveWithFactor(prob: prob, factorMetric: factor.metric.displayName.lowercased())
            }
            return Copy.Policy.predictiveDefault(prob: prob)

        case .causalDiscovery:
            let lag = candidate.evidence.grangerOptimalLag
            let effectSize = candidate.evidence.grangerEffectSize ?? 0
            let effectLabel = effectSize > 0.35 ? Copy.Policy.effectStrong : effectSize > 0.15 ? Copy.Policy.effectNotable : Copy.Policy.effectMeasurable
            if let lag, lag > 0 {
                return Copy.Policy.causalWithLag(effectLabel: effectLabel, metric: metric.displayName.lowercased(), lag: lag)
            }
            return Copy.Policy.causalDefault(metric: metric.displayName.lowercased(), effectLabel: effectLabel)

        case .stateTransition:
            return Copy.Policy.stateTransition(days: max(1, Int(candidate.upliftConfidence / 0.03)), metricName: metric.displayName)

        case .anomalyResponse:
            if let current = currentValue, let bl = baseline {
                let devPct = Int(abs(bl.deviationPercent(for: current)))
                return Copy.Policy.anomalyWithDeviation(metric: metric.displayName.lowercased(), devPct: devPct)
            }
            return Copy.Policy.anomalyDefault(metric: metric.displayName.lowercased())

        case .trendReversal:
            if let trend {
                let wowPct = Int(abs(trend.weekOverWeekChange))
                let rate: String
                switch trend.rateOfChange {
                case .rapid: rate = Copy.Policy.rateRapidly
                case .moderate: rate = Copy.Policy.rateSteadily
                case .gradual: rate = Copy.Policy.rateGradually
                case .negligible: rate = Copy.Policy.rateSlightly
                }
                return Copy.Policy.trendDeclining(metric: metric.displayName.lowercased(), rate: rate, wowPct: wowPct)
            }
            return Copy.Policy.trendDecliningDefault

        case .circadianTiming:
            return Copy.Policy.circadianTiming(metric: metric.displayName.lowercased())

        case .baselineRecovery:
            if let current = currentValue, let bl = baseline {
                let gap = metric.formatValue(abs(current - bl.mean))
                return Copy.Policy.baselineRecovery(gap: gap, unit: metric.unit, baseline: metric.formatValue(bl.mean))
            }
            return Copy.Policy.baselineRecoveryDefault

        case .counterfactual:
            if let delta = candidate.evidence.forecastedScoreDelta {
                return Copy.Policy.counterfactualWithDelta(delta: Int(abs(delta)))
            }
            return Copy.Policy.counterfactualDefault
        }
    }

    // MARK: - Expected Benefit

    private func generateExpectedBenefit(
        candidate: InterventionCandidate,
        baseline: UserBaseline?,
        unit: String,
        trend: TrendAnalyzer.TrendResult? = nil
    ) -> String {
        let metric = candidate.targetMetric
        let uplift = candidate.predictedUplift

        let timeframe: String
        switch candidate.timeToBenefit {
        case .immediate: timeframe = Copy.Policy.timeframeToday
        case .nextDay: timeframe = Copy.Policy.timeframeByTomorrow
        case .twoDays: timeframe = Copy.Policy.timeframeWithin2Days
        case .threeDays: timeframe = Copy.Policy.timeframeWithin3Days
        case .oneWeek: timeframe = Copy.Policy.timeframeOverNextWeek
        case .twoWeeks: timeframe = Copy.Policy.timeframeOver2Weeks
        }

        // Best case: concrete numeric benefit from baseline statistics
        if let bl = baseline, bl.standardDeviation > 0 {
            let rawDelta = uplift * bl.standardDeviation
            let formatted = metric.formatValue(abs(rawDelta))

            let verb = metric.higherIsBetter ? "improve" : "decrease"
            let confPct = Int(candidate.upliftConfidence * 100)

            // Include confidence interval if available
            if let band = candidate.evidence.uncertaintyBand {
                let lower = metric.formatValue(abs(band.lower))
                let upper = metric.formatValue(abs(band.upper))
                return "Your \(metric.displayName) may \(verb) by \(lower)–\(upper) \(unit)"
                    + " \(timeframe) (\(confPct)% confidence)."
            }

            return "Your \(metric.displayName) may \(verb) by ~\(formatted) \(unit)"
                + " \(timeframe) (\(confPct)% confidence)."
        }

        // Fallback with uncertainty band
        if let evidence = candidate.evidence.uncertaintyBand {
            let lower = String(format: "%.1f", abs(evidence.lower))
            let upper = String(format: "%.1f", abs(evidence.upper))
            return "Expected improvement: \(lower)–\(upper) \(unit)"
                + " \(timeframe) (\(Int(candidate.upliftConfidence * 100))% confidence)."
        }

        // Fallback using trend data to quantify
        if let trend, abs(trend.weekOverWeekChange) > 2 {
            let wowPct = Int(abs(trend.weekOverWeekChange))
            let verb = metric.higherIsBetter ? "slow the decline" : "reduce the increase"
            return "This could \(verb) of \(wowPct)% per week"
                + " and begin recovery \(timeframe)."
        }

        // Historical effectiveness fallback
        if let eff = candidate.historicalEffectiveness, eff > 0.4 {
            return "Based on \(Int(eff * 100))% past effectiveness, this should improve"
                + " your \(metric.displayName.lowercased()) \(timeframe)."
        }

        // Minimal fallback. still includes timeframe and confidence
        let confPct = Int(candidate.upliftConfidence * 100)
        return "Expected to improve your \(metric.displayName.lowercased())"
            + " \(timeframe) (\(confPct)% model confidence)."
    }

    // MARK: - Rationale Builder

    private func buildRationale(
        primary: InterventionCandidate,
        utility: Double,
        secondary: InterventionCandidate?
    ) -> String {
        var rationale = "Selected \(primary.targetMetric.displayName.lowercased())"
            + " (\(primary.actionType.rawValue)) as the primary action"
            + " because it has the highest expected utility"
            + " (\(String(format: "%.3f", utility)))."

        rationale += " Source: \(sourceDescription(primary.source))."

        if primary.upliftConfidence >= 0.6 {
            rationale += " High confidence in predicted uplift."
        }

        if let hist = primary.historicalEffectiveness, hist > 0.5 {
            rationale += " Historically effective for you"
                + " (effectiveness: \(Int(hist * 100))%)."
        }

        if let sec = secondary {
            rationale += " Secondary action targets"
                + " \(sec.targetMetric.displayName.lowercased())"
                + " for diversified benefit."
        }

        return rationale
    }

    // MARK: - Candidate Generators

    private func candidatesFromPrediction(
        _ prediction: MLPrediction?,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        guard let prediction, prediction.probability > 0.3 else { return [] }

        let riskFactors = prediction.topFactors.filter { $0.isRiskFactor }
        guard !riskFactors.isEmpty else { return [] }

        let maxContribution = riskFactors.first?.contribution ?? 1.0

        return riskFactors.compactMap { factor -> InterventionCandidate? in
            let metric = factor.metric
            guard ActionableMetric.isActionable(metric) else { return nil }

            let relativeContribution = maxContribution > 0
                ? abs(factor.contribution) / maxContribution : 0.5
            let uplift = min(1.0, prediction.probability * relativeContribution)

            let actionType = bestActionType(for: metric, trend: nil, source: .predictiveModel)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "pred_\(metric.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: metric,
                actionType: actionType,
                source: .predictiveModel,
                predictedUplift: uplift,
                upliftConfidence: prediction.confidence,
                effortCost: effortCost(for: metric, deltaFraction: 0.3),
                timeToBenefit: .nextDay,
                adherenceLikelihood: adherenceLikelihood(for: metric),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [factor],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromCausal(
        _ correlations: [MLCorrelation],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        // Only use Granger-causal relationships with significant p-values
        let causal = correlations.filter { $0.grangerCausal && $0.grangerPValue < 0.05 }

        return causal.compactMap { corr -> InterventionCandidate? in
            // A Granger-causes B: if B is declining, recommend changing A
            let upstream = corr.metricA
            guard ActionableMetric.isActionable(upstream) else { return nil }

            let downstreamTrend = trends[corr.metricB]
            guard downstreamTrend?.direction == .declining else { return nil }

            let effectSize = corr.overallStrength
            let uplift = min(1.0, effectSize * 0.8)
            let confidence = min(1.0, (1.0 - corr.grangerPValue) * corr.stability)

            let actionType = bestActionType(for: upstream, trend: trends[upstream], source: .causalDiscovery)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "causal_\(upstream.rawValue)_\(corr.metricB.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: upstream,
                actionType: actionType,
                source: .causalDiscovery,
                predictedUplift: uplift,
                upliftConfidence: confidence,
                effortCost: effortCost(for: upstream, deltaFraction: 0.25),
                timeToBenefit: .twoDays,
                adherenceLikelihood: adherenceLikelihood(for: upstream),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: corr.sampleCount,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: corr.grangerPValue,
                    grangerEffectSize: effectSize,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromState(
        _ state: HealthState?,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        guard let state else { return [] }

        // Focus on characteristics that deviate most from normal in suboptimal direction
        let suboptimal = state.characteristics.filter { char in
            switch char.level {
            case .low where char.metric.higherIsBetter: return true
            case .high where !char.metric.higherIsBetter: return true
            default: return false
            }
        }

        return suboptimal.compactMap { char -> InterventionCandidate? in
            guard ActionableMetric.isActionable(char.metric) else { return nil }

            let uplift = min(1.0, abs(char.zScore) * 0.3)
            let confidence = min(1.0, 0.4 + Double(state.daysInState) * 0.03)

            let actionType = bestActionType(for: char.metric, trend: nil, source: .stateTransition)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "state_\(char.metric.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: char.metric,
                actionType: actionType,
                source: .stateTransition,
                predictedUplift: uplift,
                upliftConfidence: confidence,
                effortCost: effortCost(for: char.metric, deltaFraction: 0.3),
                timeToBenefit: .twoDays,
                adherenceLikelihood: adherenceLikelihood(for: char.metric),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromAnomalies(
        _ anomalies: [AnomalyDetector.AnomalyResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        // Focus on significant anomalies in the suboptimal direction
        let actionable = anomalies.filter { anomaly in
            guard ActionableMetric.isActionable(anomaly.metric) else { return false }
            let isSuboptimal: Bool
            if anomaly.metric.higherIsBetter {
                isSuboptimal = !anomaly.isAboveBaseline
            } else {
                isSuboptimal = anomaly.isAboveBaseline
            }
            return isSuboptimal && anomaly.outsideNormalRange
        }

        return actionable.map { anomaly in
            let severityFactor: Double
            switch anomaly.severity {
            case .critical: severityFactor = 0.9
            case .warning: severityFactor = 0.7
            case .info: severityFactor = 0.3
            }

            let deviationFactor = min(1.0, abs(anomaly.deviationPercent) / 30.0)
            let uplift = min(1.0, severityFactor * (0.5 + deviationFactor * 0.5))
            let confidence = min(1.0, abs(anomaly.zScore) / 3.0)
                * (anomaly.outsideNormalRange ? 0.95 : 0.7)

            let actionType = bestActionType(for: anomaly.metric, trend: nil, source: .anomalyResponse)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "anomaly_\(anomaly.metric.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: anomaly.metric,
                actionType: actionType,
                source: .anomalyResponse,
                predictedUplift: uplift,
                upliftConfidence: confidence,
                effortCost: effortCost(for: anomaly.metric, deltaFraction: 0.2),
                timeToBenefit: .nextDay,
                adherenceLikelihood: adherenceLikelihood(for: anomaly.metric),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromTrends(
        _ trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        let declining = trends.filter { metric, result in
            result.direction == .declining
                && result.rateOfChange >= .gradual
                && ActionableMetric.isActionable(metric)
        }

        return declining.map { metric, result in
            let rateFactor: Double
            switch result.rateOfChange {
            case .rapid: rateFactor = 0.9
            case .moderate: rateFactor = 0.7
            case .gradual: rateFactor = 0.4
            case .negligible: rateFactor = 0.2
            }

            let inflectionBoost: Double = result.inflection == .accelerating ? 0.15 : 0.0
            let uplift = min(1.0, rateFactor + inflectionBoost)

            // Confidence from short/long term alignment
            let shortLongAlignment: Double
            if result.movingAverage7d > 0 && result.movingAverage30d > 0 {
                let ratio = result.movingAverage7d / result.movingAverage30d
                shortLongAlignment = ratio < 1.0 ? min(1.0, (1.0 - ratio) * 5) : 0.3
            } else {
                shortLongAlignment = 0.5
            }
            let confidence = min(1.0, shortLongAlignment * 0.7 + 0.3)

            let actionType = bestActionType(for: metric, trend: result, source: .trendReversal)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "trend_\(metric.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: metric,
                actionType: actionType,
                source: .trendReversal,
                predictedUplift: uplift,
                upliftConfidence: confidence,
                effortCost: effortCost(for: metric, deltaFraction: 0.2),
                timeToBenefit: .threeDays,
                adherenceLikelihood: adherenceLikelihood(for: metric),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromCircadian(
        _ recommendations: [CircadianAnalyzer.TimingRecommendation],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        return recommendations.compactMap { rec -> InterventionCandidate? in
            let metric: HealthMetric
            let actionType: InterventionCandidate.ActionType

            switch rec.activity {
            case .workout:
                metric = .exerciseMinutes
                actionType = .intensifyExercise
            case .sleep:
                metric = .sleepDuration
                actionType = .sleepEarlier
            case .focusedWork:
                metric = .mindfulMinutes
                actionType = .meditation
            case .recovery:
                metric = .heartRateVariability
                actionType = .activeRecovery
            }

            guard ActionableMetric.isActionable(metric) else { return nil }

            let uplift = min(1.0, rec.confidence * 0.6)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "circadian_\(rec.activity.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: metric,
                actionType: actionType,
                source: .circadianTiming,
                predictedUplift: uplift,
                upliftConfidence: rec.confidence,
                effortCost: effortCost(for: metric, deltaFraction: 0.15),
                timeToBenefit: .immediate,
                adherenceLikelihood: adherenceLikelihood(for: metric) * 1.1, // timing-aware boost
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    private func candidatesFromBaselines(
        _ baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [InterventionCandidate] {
        return baselines.compactMap { metric, baseline -> InterventionCandidate? in
            guard ActionableMetric.isActionable(metric) else { return nil }
            guard let series = timeSeries[metric],
                  let current = series.latestValue else { return nil }

            let deviation = baseline.deviationPercent(for: current)

            // Only recommend if significantly far from baseline (>15%) in suboptimal direction
            let isSuboptimal: Bool
            if metric.higherIsBetter {
                isSuboptimal = deviation < -15
            } else {
                isSuboptimal = deviation > 15
            }
            guard isSuboptimal else { return nil }

            // Skip if already covered by trend reversal
            if let trend = trends[metric], trend.direction == .declining, trend.rateOfChange >= .moderate {
                return nil
            }

            let uplift = min(1.0, abs(deviation) / 50.0 * 0.7)
            let confidence = min(1.0, Double(baseline.sampleCount) / 60.0) * 0.75

            let actionType = bestActionType(for: metric, trend: trends[metric], source: .baselineRecovery)
            let effectiveness = categoryEffectiveness[actionType.rawValue]
            let exposure = recentExposureCount(for: actionType)

            return InterventionCandidate(
                id: "baseline_\(metric.rawValue)_\(UUID().uuidString.prefix(8))",
                targetMetric: metric,
                actionType: actionType,
                source: .baselineRecovery,
                predictedUplift: uplift,
                upliftConfidence: confidence,
                effortCost: effortCost(for: metric, deltaFraction: abs(deviation) / 100.0),
                timeToBenefit: .threeDays,
                adherenceLikelihood: adherenceLikelihood(for: metric),
                recentExposureCount: exposure,
                historicalEffectiveness: effectiveness,
                evidence: InterventionEvidence(
                    historicalResponseMean: nil,
                    historicalResponseCount: 0,
                    forecastedScoreDelta: nil,
                    uncertaintyBand: nil,
                    contributingFeatures: [],
                    grangerPValue: nil,
                    grangerEffectSize: nil,
                    grangerOptimalLag: nil
                )
            )
        }
    }

    // MARK: - Action Type Mapping

    /// Select the best actionType for a given metric and context.
    private func bestActionType(
        for metric: HealthMetric,
        trend: TrendAnalyzer.TrendResult?,
        source: InterventionCandidate.InterventionSource
    ) -> InterventionCandidate.ActionType {
        switch metric {
        case .sleepDuration:
            return .extendSleep
        case .sleepDeep:
            return .reduceScreenTime
        case .sleepREM:
            return .reduceEvening
        case .steps:
            if trend?.direction == .declining {
                return .increaseSteps
            }
            return .increaseSteps
        case .activeCalories, .exerciseMinutes:
            if source == .anomalyResponse || source == .stateTransition {
                return .activeRecovery
            }
            return .intensifyExercise
        case .standHours:
            return .increaseSteps
        case .heartRateVariability:
            return .breathingSession
        case .restingHeartRate:
            return .reduceExercise
        case .mindfulMinutes:
            return .meditation
        case .timeInDaylight:
            return .increaseSteps
        case .waterIntake:
            return .hydration
        case .caffeineIntake:
            return .reduceCaffeine
        case .weight, .bodyFatPercentage:
            return .increaseSteps
        case .vo2Max:
            return .intensifyExercise
        case .walkingSpeed:
            return .increaseSteps
        default:
            return .activeRecovery
        }
    }

    // MARK: - Effort & Adherence Estimation

    /// Effort cost (0 = trivial, 1 = very hard) for a given metric and change magnitude.
    private func effortCost(for metric: HealthMetric, deltaFraction: Double) -> Double {
        let baseDifficulty: Double
        switch metric {
        case .mindfulMinutes:                  baseDifficulty = 0.1
        case .waterIntake:                     baseDifficulty = 0.15
        case .standHours:                      baseDifficulty = 0.2
        case .timeInDaylight:                  baseDifficulty = 0.25
        case .steps:                           baseDifficulty = 0.3
        case .sleepDuration:                   baseDifficulty = 0.35
        case .activeCalories:                  baseDifficulty = 0.4
        case .exerciseMinutes:                 baseDifficulty = 0.45
        case .sleepDeep, .sleepREM:            baseDifficulty = 0.6
        case .walkingSpeed:                    baseDifficulty = 0.5
        case .restingHeartRate:                baseDifficulty = 0.7
        case .heartRateVariability:            baseDifficulty = 0.75
        case .vo2Max:                          baseDifficulty = 0.8
        case .weight, .bodyFatPercentage:      baseDifficulty = 0.85
        default:                               baseDifficulty = 0.5
        }

        let magnitudePenalty = min(0.15, deltaFraction * 0.3)
        return min(1.0, baseDifficulty + magnitudePenalty)
    }

    /// Estimated adherence likelihood (0-1) based on how easy the metric is to influence.
    private func adherenceLikelihood(for metric: HealthMetric) -> Double {
        switch metric {
        case .mindfulMinutes:              return 0.85
        case .waterIntake:                 return 0.80
        case .standHours:                  return 0.75
        case .timeInDaylight:              return 0.70
        case .steps:                       return 0.70
        case .sleepDuration:               return 0.60
        case .activeCalories:              return 0.60
        case .exerciseMinutes:             return 0.55
        case .sleepDeep, .sleepREM:        return 0.40
        case .walkingSpeed:                return 0.50
        case .restingHeartRate:            return 0.35
        case .heartRateVariability:        return 0.30
        case .vo2Max:                      return 0.25
        case .weight, .bodyFatPercentage:  return 0.20
        case .caffeineIntake:              return 0.65
        default:                           return 0.50
        }
    }

    // MARK: - Prescriptive Language Generation

    /// Generate a bold, body-focused prescriptive headline based on overall recovery state.
    ///
    /// The headline is direct and actionable:
    /// - Green days: motivating, push-forward language
    /// - Yellow days: balanced, moderate language
    /// - Red days: protective, recovery-focused language
    func generatePrescriptiveHeadline(
        primaryCandidate: InterventionCandidate,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> String {
        let recoveryScore = estimateRecoveryScore(baselines: baselines, timeSeries: timeSeries)

        switch recoveryScore {
        case .excellent:
            return excellentDayHeadline(primaryCandidate: primaryCandidate)
        case .good:
            return goodDayHeadline(primaryCandidate: primaryCandidate)
        case .moderate:
            return moderateDayHeadline(primaryCandidate: primaryCandidate)
        case .poor:
            return poorDayHeadline(primaryCandidate: primaryCandidate)
        case .depleted:
            return depletedDayHeadline(primaryCandidate: primaryCandidate)
        }
    }

    /// Compute a target bedtime based on sleep debt and current strain.
    ///
    /// Returns a formatted time string like "10:30 PM" or nil if insufficient data.
    func computeTargetSleepTime(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> String? {
        guard let sleepBaseline = baselines[.sleepDuration],
              sleepBaseline.mean > 0 else { return nil }

        let currentSleep = timeSeries[.sleepDuration]?.latestValue ?? sleepBaseline.mean
        let sleepDebtHours = max(0, sleepBaseline.mean - currentSleep)

        // Estimate strain from exercise + steps deviation
        let strainFactor = estimateStrainFactor(baselines: baselines, timeSeries: timeSeries)

        // Base wake time assumption: 7:00 AM
        let baseWakeHour = 7.0

        // Target sleep hours: baseline + debt recovery (cap at 1hr extra) + strain adjustment
        let debtRecovery = min(1.0, sleepDebtHours * 0.5)
        let strainAdjustment = strainFactor > 1.2 ? 0.5 : (strainFactor > 1.0 ? 0.25 : 0.0)
        let targetSleepHours = sleepBaseline.mean + debtRecovery + strainAdjustment

        // Compute bedtime from wake time
        let bedtimeHour = baseWakeHour - targetSleepHours + 24.0
        let normalizedHour = bedtimeHour.truncatingRemainder(dividingBy: 24.0)

        let hour = Int(normalizedHour)
        let minute = Int((normalizedHour - Double(hour)) * 60)
        let roundedMinute = (minute / 15) * 15

        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"

        return String(format: "%d:%02d %@", displayHour, roundedMinute, period)
    }

    /// Compute a strain budget suggestion based on recovery and recent exertion.
    ///
    /// Returns "High intensity OK", "Moderate effort recommended", or "Light activity only".
    func computeStrainBudget(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> String? {
        let recoveryScore = estimateRecoveryScore(baselines: baselines, timeSeries: timeSeries)

        switch recoveryScore {
        case .excellent, .good:
            return Copy.Policy.highIntensityOK
        case .moderate:
            return Copy.Policy.moderateEffort
        case .poor, .depleted:
            return Copy.Policy.lightActivityOnly
        }
    }

    // MARK: - Recovery Score Estimation

    private enum RecoveryLevel {
        case excellent, good, moderate, poor, depleted
    }

    /// Estimate overall recovery from HRV, resting HR, and sleep relative to baselines.
    private func estimateRecoveryScore(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> RecoveryLevel {
        var signals: [Double] = []

        // HRV: higher is better
        if let bl = baselines[.heartRateVariability],
           let current = timeSeries[.heartRateVariability]?.latestValue,
           bl.standardDeviation > 0 {
            let zScore = (current - bl.mean) / bl.standardDeviation
            signals.append(min(2, max(-2, zScore)))
        }

        // Resting HR: lower is better
        if let bl = baselines[.restingHeartRate],
           let current = timeSeries[.restingHeartRate]?.latestValue,
           bl.standardDeviation > 0 {
            let zScore = (bl.mean - current) / bl.standardDeviation
            signals.append(min(2, max(-2, zScore)))
        }

        // Sleep duration: higher is better (up to a point)
        if let bl = baselines[.sleepDuration],
           let current = timeSeries[.sleepDuration]?.latestValue,
           bl.standardDeviation > 0 {
            let zScore = (current - bl.mean) / bl.standardDeviation
            signals.append(min(2, max(-2, zScore)))
        }

        guard !signals.isEmpty else { return .moderate }

        let avgSignal = signals.reduce(0, +) / Double(signals.count)

        if avgSignal > 0.8 { return .excellent }
        if avgSignal > 0.2 { return .good }
        if avgSignal > -0.3 { return .moderate }
        if avgSignal > -0.8 { return .poor }
        return .depleted
    }

    /// Estimate strain factor from exercise/activity deviation above baseline.
    private func estimateStrainFactor(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Double {
        var factors: [Double] = []

        if let bl = baselines[.activeCalories],
           let current = timeSeries[.activeCalories]?.latestValue,
           bl.mean > 0 {
            factors.append(current / bl.mean)
        }

        if let bl = baselines[.exerciseMinutes],
           let current = timeSeries[.exerciseMinutes]?.latestValue,
           bl.mean > 0 {
            factors.append(current / bl.mean)
        }

        guard !factors.isEmpty else { return 1.0 }
        return factors.reduce(0, +) / Double(factors.count)
    }

    // MARK: - Headline Generators

    private func excellentDayHeadline(primaryCandidate: InterventionCandidate) -> String {
        let options = Copy.Policy.excellentHeadlines
        return selectHeadline(from: options, candidate: primaryCandidate)
    }

    private func goodDayHeadline(primaryCandidate: InterventionCandidate) -> String {
        let options = Copy.Policy.goodHeadlines
        return selectHeadline(from: options, candidate: primaryCandidate)
    }

    private func moderateDayHeadline(primaryCandidate: InterventionCandidate) -> String {
        let options = Copy.Policy.moderateHeadlines
        return selectHeadline(from: options, candidate: primaryCandidate)
    }

    private func poorDayHeadline(primaryCandidate: InterventionCandidate) -> String {
        let options = Copy.Policy.poorHeadlines
        return selectHeadline(from: options, candidate: primaryCandidate)
    }

    private func depletedDayHeadline(primaryCandidate: InterventionCandidate) -> String {
        let options = Copy.Policy.depletedHeadlines
        return selectHeadline(from: options, candidate: primaryCandidate)
    }

    /// Select a headline pseudo-randomly based on the candidate ID to avoid repetition.
    private func selectHeadline(from options: [String], candidate: InterventionCandidate) -> String {
        let hash = abs(candidate.id.hashValue)
        return options[hash % options.count]
    }

    // MARK: - Helpers

    private func sourceDescription(_ source: InterventionCandidate.InterventionSource) -> String {
        switch source {
        case .predictiveModel: return Copy.Policy.sourcePredictive
        case .causalDiscovery: return Copy.Policy.sourceCausal
        case .circadianTiming: return Copy.Policy.sourceCircadian
        case .stateTransition: return Copy.Policy.sourceState
        case .anomalyResponse: return Copy.Policy.sourceAnomaly
        case .trendReversal: return Copy.Policy.sourceTrend
        case .baselineRecovery: return Copy.Policy.sourceBaseline
        case .counterfactual: return Copy.Policy.sourceCounterfactual
        }
    }

    private static func formatted(_ value: Int) -> String {
        return Self.decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
