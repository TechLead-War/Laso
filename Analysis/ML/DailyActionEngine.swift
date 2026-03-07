import Foundation

// MARK: - Daily Action Types

/// The single highest-impact personalized action for today
struct DailyAction: Identifiable {
    let id: UUID
    let date: Date
    let metric: HealthMetric
    let actionTitle: String
    let actionDescription: String
    let whyThisMatters: String
    let expectedBenefit: String
    let effort: EffortLevel
    let impactScore: Double
    let confidenceScore: Double
    let compositeScore: Double
    let source: ActionSource
    let alternativeActions: [AlternativeAction]
}

/// A runner-up action (top 3 alternatives)
struct AlternativeAction: Identifiable {
    let id: UUID
    let metric: HealthMetric
    let title: String
    let compositeScore: Double
}

/// Which ML component originated the action recommendation
enum ActionSource: String {
    case predictiveModel
    case circadianTiming
    case causalDiscovery
    case stateTransition
    case trendIntervention
    case baselineRecovery
}

// MARK: - Daily Action Engine

/// Computes a single highest-impact personalized action for the user each day by gathering
/// candidate interventions from all ML components, scoring them on impact/confidence/effort/time,
/// and generating natural language recommendations grounded in the user's own data.
final class DailyActionEngine {

    // MARK: - Candidate

    /// Internal scoring container for a potential action
    private struct Candidate {
        let metric: HealthMetric
        let source: ActionSource
        let impact: Double       // 0-1
        let confidence: Double   // 0-1
        let effort: Double       // 0-1 (inverse: 1 = easy)
        let timeToBenefit: Double // 0-1 (1 = tomorrow)
        let context: CandidateContext
    }

    /// Data needed to generate natural language for a candidate
    private struct CandidateContext {
        var currentValue: Double?
        var baselineValue: Double?
        var deviationPercent: Double?
        var trendDirection: TrendDirection?
        var weekOverWeekChange: Double?
        var causalTarget: HealthMetric?
        var causalCorrelation: Double?
        var causalEffectDescription: String?
        var stateLabel: String?
        var circadianWindowStart: Int?
        var circadianWindowEnd: Int?
        var riskContribution: Double?
        var recentAverage: Double?
        var optimalValue: Double?
    }

    // MARK: - Public API

    /// Compute the single best daily action from all available ML signals.
    /// Returns nil only when no actionable candidates can be generated.
    static func computeDailyAction(
        prediction: MLPrediction?,
        circadianProfile: CircadianAnalyzer.CircadianProfile?,
        timingRecommendations: [CircadianAnalyzer.TimingRecommendation],
        causalCorrelations: [MLCorrelation],
        currentState: HealthState?,
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        adherenceMultiplier: ((InsightCategory) -> Double)?
    ) -> DailyAction? {
        var candidates: [Candidate] = []

        // 1. Gather candidates from each source
        candidates.append(contentsOf: candidatesFromPrediction(
            prediction, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromCircadian(
            circadianProfile, timingRecommendations: timingRecommendations,
            baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromCausal(
            causalCorrelations, trends: trends, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromState(
            currentState, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromAnomalies(
            anomalies, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromTrends(
            trends, baselines: baselines, timeSeries: timeSeries))
        candidates.append(contentsOf: candidatesFromBaselines(
            baselines, timeSeries: timeSeries, trends: trends))

        guard !candidates.isEmpty else { return nil }

        // 2. Score and rank
        let scored = candidates.map { candidate -> (Candidate, Double) in
            var score = compositeScore(candidate)

            // Apply adherence effectiveness multiplier
            if let multiplier = adherenceMultiplier {
                let category = insightCategory(for: candidate.source)
                score *= multiplier(category)
            }

            return (candidate, score)
        }
        .sorted { $0.1 > $1.1 }

        guard let (winner, winnerScore) = scored.first else { return nil }

        // 3. Build alternatives (top 3 distinct metrics, excluding winner)
        var seenMetrics: Set<HealthMetric> = [winner.metric]
        var alternatives: [AlternativeAction] = []
        for (candidate, score) in scored.dropFirst() {
            guard !seenMetrics.contains(candidate.metric) else { continue }
            seenMetrics.insert(candidate.metric)
            alternatives.append(AlternativeAction(
                id: UUID(),
                metric: candidate.metric,
                title: generateActionTitle(metric: candidate.metric, context: candidate.context, source: candidate.source),
                compositeScore: score
            ))
            if alternatives.count >= 3 { break }
        }

        // 4. Generate natural language
        let title = generateActionTitle(metric: winner.metric, context: winner.context, source: winner.source)
        let description = generateActionDescription(metric: winner.metric, context: winner.context, source: winner.source)
        let whyMatters = generateWhyThisMatters(metric: winner.metric, context: winner.context, source: winner.source)
        let expectedBenefit = generateExpectedBenefit(metric: winner.metric, context: winner.context, source: winner.source)

        return DailyAction(
            id: UUID(),
            date: Date(),
            metric: winner.metric,
            actionTitle: title,
            actionDescription: description,
            whyThisMatters: whyMatters,
            expectedBenefit: expectedBenefit,
            effort: effortLevel(inverseEffort: winner.effort),
            impactScore: winner.impact,
            confidenceScore: winner.confidence,
            compositeScore: winnerScore,
            source: winner.source,
            alternativeActions: alternatives
        )
    }

    // MARK: - Composite Scoring

    /// actionScore = impact^1.5 * confidence * effort^0.7 * timeToBenefit^0.5
    private static func compositeScore(_ c: Candidate) -> Double {
        let impactTerm = pow(max(c.impact, 0.001), 1.5)
        let confidenceTerm = max(c.confidence, 0.001)
        let effortTerm = pow(max(c.effort, 0.001), 0.7)
        let timeTerm = pow(max(c.timeToBenefit, 0.001), 0.5)
        return impactTerm * confidenceTerm * effortTerm * timeTerm
    }

    /// Map ActionSource to InsightCategory for adherence multiplier lookup
    private static func insightCategory(for source: ActionSource) -> InsightCategory {
        switch source {
        case .predictiveModel: return .mlPrediction
        case .circadianTiming: return .circadian
        case .causalDiscovery: return .causalChain
        case .stateTransition: return .mlState
        case .trendIntervention: return .trend
        case .baselineRecovery: return .anomaly
        }
    }

    /// Convert inverse-effort (0-1, 1=easy) back to EffortLevel
    private static func effortLevel(inverseEffort: Double) -> EffortLevel {
        if inverseEffort >= 0.7 { return .low }
        if inverseEffort >= 0.4 { return .medium }
        return .high
    }

    // MARK: - Candidate Gathering: Predictive Model

    private static func candidatesFromPrediction(
        _ prediction: MLPrediction?,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        guard let prediction, prediction.probability > 0.3 else { return [] }

        // Focus on risk factors (positive contribution = increases P(bad day))
        let riskFactors = prediction.topFactors.filter { $0.isRiskFactor }
        guard !riskFactors.isEmpty else { return [] }

        return riskFactors.compactMap { factor -> Candidate? in
            let metric = factor.metric
            guard ActionableMetric.isActionable(metric) else { return nil }

            let baseline = baselines[metric]
            let series = timeSeries[metric]
            let current = series?.latestValue ?? baseline?.mean
            let recentAvg = series?.mean(lastDays: 7)

            // Impact scales with prediction probability and factor contribution
            let maxContribution = riskFactors.first?.contribution ?? 1.0
            let relativeContribution = maxContribution > 0
                ? abs(factor.contribution) / maxContribution : 0.5
            let impact = min(1.0, prediction.probability * relativeContribution * 1.2)

            var ctx = CandidateContext()
            ctx.currentValue = current
            ctx.baselineValue = baseline?.mean
            ctx.deviationPercent = current.flatMap { baseline?.deviationPercent(for: $0) }
            ctx.riskContribution = factor.contribution
            ctx.recentAverage = recentAvg

            return Candidate(
                metric: metric,
                source: .predictiveModel,
                impact: impact,
                confidence: prediction.confidence,
                effort: inverseEffort(for: metric, deltaFraction: 0.3),
                timeToBenefit: 0.9, // Predictive model targets tomorrow
                context: ctx
            )
        }
    }

    // MARK: - Candidate Gathering: Circadian Timing

    private static func candidatesFromCircadian(
        _ profile: CircadianAnalyzer.CircadianProfile?,
        timingRecommendations: [CircadianAnalyzer.TimingRecommendation],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        guard let profile else { return [] }

        var candidates: [Candidate] = []

        for rec in timingRecommendations {
            let (metric, impact, ttb) = circadianMetricMapping(activity: rec.activity, baselines: baselines, timeSeries: timeSeries)

            var ctx = CandidateContext()
            ctx.circadianWindowStart = rec.optimalWindowStart
            ctx.circadianWindowEnd = rec.optimalWindowEnd
            ctx.currentValue = timeSeries[metric]?.latestValue
            ctx.baselineValue = baselines[metric]?.mean

            candidates.append(Candidate(
                metric: metric,
                source: .circadianTiming,
                impact: impact,
                confidence: profile.confidence * rec.confidence,
                effort: rec.activity == .sleep ? 0.7 : 0.6,
                timeToBenefit: ttb,
                context: ctx
            ))
        }

        return candidates
    }

    /// Map circadian activity types to actionable metrics with estimated impact
    private static func circadianMetricMapping(
        activity: CircadianAnalyzer.ActivityType,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> (metric: HealthMetric, impact: Double, timeToBenefit: Double) {
        switch activity {
        case .sleep:
            let sleepSeries = timeSeries[.sleepDuration]
            let baseline = baselines[.sleepDuration]
            let recentAvg = sleepSeries?.mean(lastDays: 7) ?? 7.0
            let target = baseline?.mean ?? 7.5
            let deficit = max(0, target - recentAvg)
            let impact = min(1.0, deficit / 2.0 * 0.8)
            return (.sleepDuration, max(0.3, impact), 0.85)

        case .workout:
            return (.exerciseMinutes, 0.5, 0.7)

        case .recovery:
            return (.heartRateVariability, 0.4, 0.6)

        case .focusedWork:
            return (.mindfulMinutes, 0.3, 0.8)
        }
    }

    // MARK: - Candidate Gathering: Causal Discovery

    private static func candidatesFromCausal(
        _ correlations: [MLCorrelation],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        // Find causal relationships where the downstream metric is declining
        // and the upstream metric is actionable
        let causal = correlations.filter { $0.grangerCausal && $0.grangerPValue < 0.05 }
        guard !causal.isEmpty else { return [] }

        return causal.compactMap { corr -> Candidate? in
            // A Granger-causes B: if B is declining, recommend improving A
            let upstream = corr.metricA
            let downstream = corr.metricB
            let downstreamTrend = trends[downstream]

            guard downstreamTrend?.direction == .declining else { return nil }
            guard ActionableMetric.isActionable(upstream) else { return nil }

            let downstreamBaseline = baselines[downstream]
            let downstreamCurrent = timeSeries[downstream]?.latestValue
            let upstreamBaseline = baselines[upstream]
            let upstreamCurrent = timeSeries[upstream]?.latestValue

            // Impact scales with correlation strength and downstream decline severity
            let declineRate = abs(downstreamTrend?.weekOverWeekChange ?? 0) / 100.0
            let impact = min(1.0, corr.overallStrength * (0.5 + declineRate))

            // Confidence from Granger p-value, stability, and sample count
            let pValueConfidence = max(0, 1.0 - corr.grangerPValue * 10)
            let sampleConfidence = min(1.0, Double(corr.sampleCount) / 90.0)
            let confidence = pValueConfidence * corr.stability * sampleConfidence

            var ctx = CandidateContext()
            ctx.currentValue = upstreamCurrent
            ctx.baselineValue = upstreamBaseline?.mean
            ctx.causalTarget = downstream
            ctx.causalCorrelation = corr.pearsonR

            // Build a description of the causal effect
            if let downCur = downstreamCurrent, let downBase = downstreamBaseline {
                let pct = downBase.deviationPercent(for: downCur)
                let dir = pct < 0 ? "below" : "above"
                ctx.causalEffectDescription = "\(downstream.displayName) is \(abs(Int(pct)))% \(dir) baseline"
            }

            return Candidate(
                metric: upstream,
                source: .causalDiscovery,
                impact: impact,
                confidence: confidence,
                effort: inverseEffort(for: upstream, deltaFraction: 0.25),
                timeToBenefit: 0.6, // Causal effects take 1-3 days typically
                context: ctx
            )
        }
    }

    // MARK: - Candidate Gathering: State Transition

    private static func candidatesFromState(
        _ state: HealthState?,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        guard let state else { return [] }

        // Find characteristics that are pulling the user into a suboptimal state
        let suboptimalCharacteristics = state.characteristics.filter { char in
            let isSuboptimal: Bool
            if char.metric.higherIsBetter {
                isSuboptimal = char.level == .low
            } else {
                isSuboptimal = char.level == .high
            }
            return isSuboptimal && ActionableMetric.isActionable(char.metric)
        }

        guard !suboptimalCharacteristics.isEmpty else { return [] }

        // State-specific action templates
        let stateActions = stateSpecificActions(label: state.label)

        return suboptimalCharacteristics.compactMap { char -> Candidate? in
            let metric = char.metric
            let baseline = baselines[metric]
            let series = timeSeries[metric]
            let current = series?.latestValue

            // Impact scales with z-score magnitude (how far from centroid normal)
            let impact = min(1.0, abs(char.zScore) * 0.3)

            // Confidence based on days in state (longer = more certain)
            let daysConfidence = min(1.0, Double(state.daysInState) / 7.0)
            let confidence = daysConfidence * 0.8

            var ctx = CandidateContext()
            ctx.currentValue = current
            ctx.baselineValue = baseline?.mean
            ctx.stateLabel = state.label
            ctx.deviationPercent = current.flatMap { baseline?.deviationPercent(for: $0) }

            // State-specific effort and time-to-benefit
            let (effort, ttb) = stateActions[metric] ?? (0.5, 0.6)

            return Candidate(
                metric: metric,
                source: .stateTransition,
                impact: impact,
                confidence: confidence,
                effort: effort,
                timeToBenefit: ttb,
                context: ctx
            )
        }
    }

    /// State-specific effort and time-to-benefit overrides
    private static func stateSpecificActions(label: String) -> [HealthMetric: (effort: Double, ttb: Double)] {
        switch label {
        case "Recovery":
            // In recovery: recommend easy, quick-win actions
            return [
                .sleepDuration: (0.8, 0.9),
                .mindfulMinutes: (0.9, 0.85),
                .steps: (0.7, 0.8),
                .waterIntake: (0.9, 0.7),
            ]
        case "Stressed":
            return [
                .sleepDuration: (0.6, 0.85),
                .mindfulMinutes: (0.85, 0.9),
                .exerciseMinutes: (0.5, 0.7),
                .heartRateVariability: (0.4, 0.5),
            ]
        case "Under-Slept":
            return [
                .sleepDuration: (0.7, 0.95),
                .sleepDeep: (0.4, 0.8),
                .mindfulMinutes: (0.85, 0.8),
            ]
        case "Peak Performance":
            return [
                .exerciseMinutes: (0.6, 0.7),
                .steps: (0.7, 0.8),
                .activeCalories: (0.6, 0.7),
            ]
        case "Active":
            return [
                .sleepDuration: (0.7, 0.9),
                .heartRateVariability: (0.4, 0.5),
                .waterIntake: (0.9, 0.7),
            ]
        case "Fatigued":
            return [
                .sleepDuration: (0.7, 0.9),
                .mindfulMinutes: (0.85, 0.85),
                .steps: (0.8, 0.75),
            ]
        default:
            return [:]
        }
    }

    // MARK: - Candidate Gathering: Anomalies

    private static func candidatesFromAnomalies(
        _ anomalies: [AnomalyDetector.AnomalyResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        // Only consider warning+ anomalies on actionable metrics, where direction is suboptimal
        let actionable = anomalies.filter { anomaly in
            guard anomaly.severity >= .warning else { return false }
            guard ActionableMetric.isActionable(anomaly.metric) else { return false }
            // Only act on anomalies in the "wrong" direction
            if anomaly.metric.higherIsBetter {
                return !anomaly.isAboveBaseline // Low is bad
            } else {
                return anomaly.isAboveBaseline // High is bad
            }
        }

        return actionable.map { anomaly in
            let series = timeSeries[anomaly.metric]
            let recentAvg = series?.mean(lastDays: 7)

            // Impact scales with severity and deviation magnitude
            let severityFactor: Double = anomaly.severity == .critical ? 0.9 : 0.6
            let deviationFactor = min(1.0, abs(anomaly.deviationPercent) / 30.0)
            let impact = min(1.0, severityFactor * (0.5 + deviationFactor * 0.5))

            // Confidence from z-score strength and whether it's outside normal range
            let zConfidence = min(1.0, abs(anomaly.zScore) / 3.0)
            let confidence = anomaly.outsideNormalRange ? zConfidence * 0.95 : zConfidence * 0.7

            var ctx = CandidateContext()
            ctx.currentValue = anomaly.currentValue
            ctx.baselineValue = anomaly.baselineValue
            ctx.deviationPercent = anomaly.deviationPercent
            ctx.recentAverage = recentAvg

            return Candidate(
                metric: anomaly.metric,
                source: .baselineRecovery,
                impact: impact,
                confidence: confidence,
                effort: inverseEffort(for: anomaly.metric, deltaFraction: 0.2),
                timeToBenefit: 0.75,
                context: ctx
            )
        }
    }

    // MARK: - Candidate Gathering: Declining Trends

    private static func candidatesFromTrends(
        _ trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Candidate] {
        let declining = trends.filter { metric, result in
            result.direction == .declining
                && result.rateOfChange >= .gradual
                && ActionableMetric.isActionable(metric)
        }

        return declining.map { metric, result in
            let baseline = baselines[metric]
            let series = timeSeries[metric]
            let current = series?.latestValue

            // Impact scales with rate of change
            let rateFactor: Double
            switch result.rateOfChange {
            case .rapid: rateFactor = 0.9
            case .moderate: rateFactor = 0.7
            case .gradual: rateFactor = 0.4
            case .negligible: rateFactor = 0.2
            }

            // Accelerating declines get a boost
            let inflectionBoost: Double = result.inflection == .accelerating ? 0.15 : 0.0
            let impact = min(1.0, rateFactor + inflectionBoost)

            // Confidence from trend stability (7d vs 30d alignment)
            let shortLongAlignment: Double
            if result.movingAverage7d > 0 && result.movingAverage30d > 0 {
                let ratio = result.movingAverage7d / result.movingAverage30d
                shortLongAlignment = ratio < 1.0 ? min(1.0, (1.0 - ratio) * 5) : 0.3
            } else {
                shortLongAlignment = 0.5
            }
            let confidence = min(1.0, shortLongAlignment * 0.7 + 0.3)

            var ctx = CandidateContext()
            ctx.currentValue = current
            ctx.baselineValue = baseline?.mean
            ctx.trendDirection = .declining
            ctx.weekOverWeekChange = result.weekOverWeekChange
            ctx.deviationPercent = current.flatMap { baseline?.deviationPercent(for: $0) }

            return Candidate(
                metric: metric,
                source: .trendIntervention,
                impact: impact,
                confidence: confidence,
                effort: inverseEffort(for: metric, deltaFraction: 0.2),
                timeToBenefit: 0.5, // Trend reversal takes days
                context: ctx
            )
        }
    }

    // MARK: - Candidate Gathering: Baseline Deviation

    private static func candidatesFromBaselines(
        _ baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> [Candidate] {
        return baselines.compactMap { metric, baseline -> Candidate? in
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

            // Skip if already covered by trend (avoid duplicate candidates for same metric)
            if let trend = trends[metric], trend.direction == .declining, trend.rateOfChange >= .moderate {
                return nil
            }

            let impact = min(1.0, abs(deviation) / 50.0 * 0.7)
            let confidence = min(1.0, Double(baseline.sampleCount) / 60.0) * 0.75

            var ctx = CandidateContext()
            ctx.currentValue = current
            ctx.baselineValue = baseline.mean
            ctx.deviationPercent = deviation
            ctx.optimalValue = baseline.mean

            return Candidate(
                metric: metric,
                source: .baselineRecovery,
                impact: impact,
                confidence: confidence,
                effort: inverseEffort(for: metric, deltaFraction: abs(deviation) / 100.0),
                timeToBenefit: 0.55,
                context: ctx
            )
        }
    }

    // MARK: - Effort Estimation

    /// Returns inverse effort (1.0 = easy, 0.0 = very hard) based on metric type and change magnitude
    private static func inverseEffort(for metric: HealthMetric, deltaFraction: Double) -> Double {
        let baseDifficulty: Double
        switch metric {
        case .mindfulMinutes:          baseDifficulty = 0.9
        case .waterIntake:             baseDifficulty = 0.85
        case .standHours:              baseDifficulty = 0.8
        case .timeInDaylight:          baseDifficulty = 0.75
        case .steps:                   baseDifficulty = 0.7
        case .sleepDuration:           baseDifficulty = 0.65
        case .activeCalories:          baseDifficulty = 0.6
        case .exerciseMinutes:         baseDifficulty = 0.55
        case .sleepDeep, .sleepREM:    baseDifficulty = 0.4
        case .walkingSpeed:            baseDifficulty = 0.5
        case .restingHeartRate:        baseDifficulty = 0.3
        case .heartRateVariability:    baseDifficulty = 0.25
        case .vo2Max:                  baseDifficulty = 0.2
        case .weight, .bodyFatPercentage: baseDifficulty = 0.15
        default:                       baseDifficulty = 0.5
        }

        // Larger changes are harder
        let magnitudePenalty = min(0.3, deltaFraction * 0.5)
        return max(0.05, baseDifficulty - magnitudePenalty)
    }

    // MARK: - Natural Language Generation

    private static func generateActionTitle(
        metric: HealthMetric,
        context: CandidateContext,
        source: ActionSource
    ) -> String {
        switch metric {
        case .sleepDuration:
            if let windowStart = context.circadianWindowStart, source == .circadianTiming {
                return "Get to bed by \(formatHour(windowStart)) tonight"
            }
            if let current = context.currentValue, let baseline = context.baselineValue {
                let deficit = baseline - current
                if deficit > 0.25 {
                    let minutes = Int(deficit * 60)
                    return "Sleep \(minutes) minutes longer tonight"
                }
            }
            return "Prioritize a full night of sleep tonight"

        case .steps:
            if let current = context.currentValue, let baseline = context.baselineValue {
                let gap = Int(max(0, baseline - current))
                if gap > 500 {
                    let rounded = (gap / 500) * 500
                    return "Walk \(formatted(rounded)) more steps today"
                }
            }
            return "Take a 20-minute walk today"

        case .exerciseMinutes:
            if source == .circadianTiming, let start = context.circadianWindowStart, let end = context.circadianWindowEnd {
                return "Exercise between \(formatHour(start)) and \(formatHour(end)) today"
            }
            if let state = context.stateLabel, state == "Recovery" {
                return "Do 15 minutes of light movement today"
            }
            return "Fit in a 20-minute workout today"

        case .mindfulMinutes:
            if let state = context.stateLabel, state == "Stressed" {
                return "Do a 10-minute breathing exercise now"
            }
            return "Take 10 minutes for breathing or meditation today"

        case .heartRateVariability:
            return "Do a breathing exercise before bed tonight"

        case .restingHeartRate:
            if let state = context.stateLabel, state == "Stressed" {
                return "Take a recovery day from intense exercise"
            }
            return "Reduce stress with deep breathing today"

        case .standHours:
            return "Stand and move every hour during work today"

        case .activeCalories:
            if let current = context.currentValue, let baseline = context.baselineValue {
                let gap = Int(max(0, baseline - current))
                if gap > 50 {
                    return "Burn \(gap) more active calories today"
                }
            }
            return "Add an extra 15-minute activity session today"

        case .waterIntake:
            if let current = context.currentValue, let baseline = context.baselineValue {
                let gap = Int(max(0, baseline - current))
                if gap > 250 {
                    let glasses = max(1, gap / 250)
                    return "Drink \(glasses) more glass\(glasses == 1 ? "" : "es") of water today"
                }
            }
            return "Drink an extra glass of water every 2 hours today"

        case .timeInDaylight:
            return "Get 20 minutes of natural daylight this morning"

        case .sleepDeep:
            return "Avoid screens 1 hour before bed tonight"

        case .sleepREM:
            return "Skip alcohol tonight to protect REM sleep"

        case .walkingSpeed:
            return "Add 10 minutes of brisk walking today"

        case .weight, .bodyFatPercentage:
            return "Focus on whole foods and an extra walk today"

        case .vo2Max:
            return "Add a 20-minute cardio interval session today"

        default:
            return "Focus on improving your \(metric.displayName) today"
        }
    }

    private static func generateActionDescription(
        metric: HealthMetric,
        context: CandidateContext,
        source: ActionSource
    ) -> String {
        var parts: [String] = []

        // Lead with the user's own data
        if let current = context.currentValue, let baseline = context.baselineValue {
            let deviation = context.deviationPercent ?? ((current - baseline) / baseline * 100)
            let deviationAbs = Int(abs(deviation))

            if deviationAbs > 5 {
                let direction = deviation < 0 ? "below" : "above"
                let currentFormatted = metric.formatValue(current)
                let baselineFormatted = metric.formatValue(baseline)
                parts.append("Your \(metric.displayName.lowercased()) is \(currentFormatted) \(metric.unit) — \(deviationAbs)% \(direction) your personal baseline of \(baselineFormatted) \(metric.unit).")
            }
        }

        // Add weekly context
        if let recentAvg = context.recentAverage, let baseline = context.baselineValue {
            let weekDeviation = Int(((recentAvg - baseline) / baseline) * 100)
            if abs(weekDeviation) > 3 {
                let direction = weekDeviation < 0 ? "lower" : "higher"
                parts.append("This week's average has been \(abs(weekDeviation))% \(direction) than your norm.")
            }
        }

        // Add trend context
        if let wowChange = context.weekOverWeekChange, abs(wowChange) > 2 {
            let direction = wowChange < 0 ? "dropped" : "risen"
            parts.append("It has \(direction) \(Int(abs(wowChange)))% compared to last week.")
        }

        // Source-specific context
        switch source {
        case .predictiveModel:
            if let contribution = context.riskContribution {
                let severity = contribution > 0.3 ? "the top" : "a key"
                parts.append("This is \(severity) risk factor in tomorrow's health prediction.")
            }

        case .circadianTiming:
            if let start = context.circadianWindowStart, let end = context.circadianWindowEnd {
                parts.append("Your circadian data shows the \(formatHour(start))–\(formatHour(end)) window aligns best with your body's natural rhythm.")
            }

        case .causalDiscovery:
            if let target = context.causalTarget, let effect = context.causalEffectDescription {
                parts.append("Your data shows a causal link: changes in \(metric.displayName.lowercased()) directly affect your \(target.displayName.lowercased()). Right now, \(effect.lowercased()).")
            }

        case .stateTransition:
            if let state = context.stateLabel {
                parts.append("You're currently in a \"\(state)\" state. Improving \(metric.displayName.lowercased()) is the fastest path to a better state.")
            }

        case .trendIntervention:
            parts.append("Catching this trend early makes it easier to reverse before it compounds.")

        case .baselineRecovery:
            if let optimal = context.optimalValue {
                parts.append("Your personal optimal is around \(metric.formatValue(optimal)) \(metric.unit). Small daily improvements add up fast.")
            }
        }

        return parts.isEmpty
            ? "Based on your recent data, improving \(metric.displayName.lowercased()) today would have the highest positive impact on your health score."
            : parts.joined(separator: " ")
    }

    private static func generateWhyThisMatters(
        metric: HealthMetric,
        context: CandidateContext,
        source: ActionSource
    ) -> String {
        switch source {
        case .predictiveModel:
            return predictiveWhyMatters(metric: metric, context: context)

        case .circadianTiming:
            return circadianWhyMatters(metric: metric, context: context)

        case .causalDiscovery:
            return causalWhyMatters(metric: metric, context: context)

        case .stateTransition:
            return stateWhyMatters(metric: metric, context: context)

        case .trendIntervention:
            return trendWhyMatters(metric: metric, context: context)

        case .baselineRecovery:
            return baselineWhyMatters(metric: metric, context: context)
        }
    }

    private static func generateExpectedBenefit(
        metric: HealthMetric,
        context: CandidateContext,
        source: ActionSource
    ) -> String {
        switch metric {
        case .sleepDuration:
            if let current = context.currentValue, let baseline = context.baselineValue {
                let deficit = baseline - current
                if deficit > 0.25 {
                    return "Sleeping \(Int(deficit * 60)) minutes more could improve your HRV and energy levels by tomorrow."
                }
            }
            return "A full night of sleep tonight could boost your recovery score by tomorrow morning."

        case .steps:
            if let deviation = context.deviationPercent, abs(deviation) > 10 {
                return "Getting your steps back to baseline could lift your activity score within a day."
            }
            return "An extra walk today can improve your cardiovascular metrics by tomorrow."

        case .exerciseMinutes:
            return "Even a short workout today can improve your resting heart rate and sleep quality tonight."

        case .mindfulMinutes:
            return "A brief breathing exercise can lower your heart rate within minutes and improve your HRV overnight."

        case .heartRateVariability:
            return "Improving your HRV is your body's single strongest recovery signal — it affects sleep, energy, and stress resilience."

        case .restingHeartRate:
            return "A lower resting heart rate signals better cardiovascular fitness and recovery."

        case .standHours:
            return "Regular movement throughout the day can improve blood flow and reduce afternoon energy dips."

        case .activeCalories:
            return "Hitting your calorie burn target supports weight management and cardiovascular health."

        case .waterIntake:
            return "Better hydration supports cognitive performance and can improve your heart rate variability."

        case .timeInDaylight:
            return "Morning daylight exposure helps anchor your circadian rhythm, improving sleep onset tonight."

        case .sleepDeep:
            return "More deep sleep strengthens your immune system and physical recovery."

        case .sleepREM:
            return "Better REM sleep supports memory consolidation and emotional regulation."

        case .walkingSpeed:
            return "Walking speed is a validated longevity indicator — small improvements compound over time."

        case .weight, .bodyFatPercentage:
            return "Consistent small choices build momentum — focus on today, and the trend follows."

        case .vo2Max:
            return "Improving VO2 max is one of the strongest predictors of long-term health and longevity."

        default:
            if let deviation = context.deviationPercent, abs(deviation) > 10 {
                return "Bringing your \(metric.displayName.lowercased()) closer to your baseline could improve your overall health score."
            }
            return "Improving \(metric.displayName.lowercased()) supports your overall health profile."
        }
    }

    // MARK: - Source-Specific "Why This Matters"

    private static func predictiveWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        var parts: [String] = []

        parts.append("Our predictive model flagged \(metric.displayName.lowercased()) as the most impactful lever you can pull today.")

        if let contribution = context.riskContribution, contribution > 0 {
            parts.append("It's currently pushing your risk of a tough day tomorrow higher than any other factor.")
        }

        if let current = context.currentValue, let baseline = context.baselineValue {
            let pctOff = abs(Int(((current - baseline) / baseline) * 100))
            if pctOff > 5 {
                parts.append("At \(metric.formatValue(current)) \(metric.unit), you're \(pctOff)% off your usual \(metric.formatValue(baseline)) \(metric.unit).")
            }
        }

        return parts.joined(separator: " ")
    }

    private static func circadianWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        if let start = context.circadianWindowStart, let end = context.circadianWindowEnd {
            return "Your body's internal clock peaks between \(formatHour(start)) and \(formatHour(end)) for this activity. Aligning with your circadian rhythm means less effort for more benefit — your physiology is doing half the work."
        }
        return "Timing matters as much as effort. Your circadian data suggests this window will give you the best results with the least strain."
    }

    private static func causalWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        guard let target = context.causalTarget else {
            return "Your data reveals that \(metric.displayName.lowercased()) has a measurable downstream effect on other key metrics."
        }

        var text = "Your data shows that when \(metric.displayName.lowercased()) improves, \(target.displayName.lowercased()) follows within 1-3 days."

        if let corr = context.causalCorrelation {
            let strength = abs(corr) > 0.5 ? "strong" : "moderate"
            text += " This is a \(strength) causal relationship backed by \(Int(abs(corr) * 100))% correlation in your personal data."
        }

        return text
    }

    private static func stateWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        guard let state = context.stateLabel else {
            return "\(metric.displayName) is one of the defining characteristics of your current health state. Improving it is the fastest way to shift into a better state."
        }

        switch state {
        case "Recovery":
            return "You're in a recovery phase. Your body is rebuilding. Supporting \(metric.displayName.lowercased()) now helps you transition to peak performance faster — gentle effort, big payoff."
        case "Stressed":
            return "Your body is showing stress signals across multiple metrics. \(metric.displayName) is the most actionable way to break the stress cycle today."
        case "Under-Slept":
            return "Sleep debt is affecting your metrics across the board. Fixing \(metric.displayName.lowercased()) tonight is the single most impactful thing you can do."
        case "Peak Performance":
            return "You're performing well. Maintaining \(metric.displayName.lowercased()) helps you stay in this high-performance zone longer."
        case "Fatigued":
            return "Your body is running on empty. Improving \(metric.displayName.lowercased()) is the gentlest way to start recovering without overloading yourself."
        default:
            return "Based on your current health state (\(state)), \(metric.displayName.lowercased()) is the key metric to focus on for the biggest improvement."
        }
    }

    private static func trendWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        var parts: [String] = []

        parts.append("Your \(metric.displayName.lowercased()) has been trending downward.")

        if let wowChange = context.weekOverWeekChange {
            parts.append("It dropped \(Int(abs(wowChange)))% this week compared to last.")
        }

        parts.append("Catching a decline early is far easier than reversing an entrenched trend. A small correction today can prevent a bigger problem next week.")

        return parts.joined(separator: " ")
    }

    private static func baselineWhyMatters(metric: HealthMetric, context: CandidateContext) -> String {
        if let current = context.currentValue, let baseline = context.baselineValue {
            let pct = abs(Int(((current - baseline) / baseline) * 100))
            return "Your \(metric.displayName.lowercased()) is \(pct)% away from your personal baseline. Your body performs best when this metric stays near \(metric.formatValue(baseline)) \(metric.unit). Closing this gap is one of the fastest ways to feel the difference."
        }
        return "Bringing \(metric.displayName.lowercased()) back toward your personal baseline would restore balance across your health metrics."
    }

    // MARK: - Formatting Helpers

    /// Format an hour (0-23) as a human-readable time string
    private static func formatHour(_ hour: Int) -> String {
        let normalizedHour = ((hour % 24) + 24) % 24
        if normalizedHour == 0 { return "12:00 AM" }
        if normalizedHour == 12 { return "12:00 PM" }
        if normalizedHour < 12 {
            return "\(normalizedHour):00 AM"
        }
        return "\(normalizedHour - 12):00 PM"
    }

    /// Format an integer with thousands separator
    private static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
