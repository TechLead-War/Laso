import Foundation

/// Synthesizes analysis results into prioritized actionable insights
struct InsightGenerator {

    /// Generate insights from anomalies and trends with inflection-aware context
    static func generate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] = [:],
        correlations: [HealthCorrelation] = [],
        timeSeries: [HealthMetric: MetricTimeSeries] = [:]
    ) -> [Insight] {
        var insights: [Insight] = []

        for anomaly in anomalies {
            let trendResult = trends[anomaly.metric]
            let trend = trendResult?.direction ?? .stable
            let rateOfChange = trendResult?.rateOfChange ?? .negligible
            let inflection = trendResult?.inflection ?? .steady

            // Only generate insights for non-trivial findings
            guard anomaly.severity >= .warning || trend == .declining else { continue }

            // Escalate severity for rapid changes or accelerating declines
            let effectiveSeverity: Severity
            if rateOfChange == .rapid && anomaly.severity == .warning {
                effectiveSeverity = .critical
            } else if inflection == .accelerating && trend == .declining && anomaly.severity == .warning {
                effectiveSeverity = .critical
            } else {
                effectiveSeverity = anomaly.severity
            }

            let context = buildContext(
                metric: anomaly.metric,
                baselines: baselines,
                historicalContext: historicalContext,
                correlations: correlations,
                timeSeries: timeSeries,
                trends: trends
            )

            let insight = createInsight(
                metric: anomaly.metric,
                severity: effectiveSeverity,
                trend: trend,
                rateOfChange: rateOfChange,
                inflection: inflection,
                currentValue: anomaly.currentValue,
                baselineValue: anomaly.baselineValue,
                deviationPercent: anomaly.deviationPercent,
                historicalContext: historicalContext[anomaly.metric],
                insightContext: context
            )
            insights.append(insight)
        }

        // Also check for declining trends without anomalies
        for (metric, trendResult) in trends {
            guard trendResult.direction == .declining else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let context = buildContext(
                metric: metric,
                baselines: baselines,
                historicalContext: historicalContext,
                correlations: correlations,
                timeSeries: timeSeries,
                trends: trends
            )

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .declining,
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange,
                insightContext: context
            )
            insights.append(insight)
        }

        // Add positive insights for significantly improving metrics
        for (metric, trendResult) in trends {
            guard trendResult.direction == .improving,
                  abs(trendResult.weekOverWeekChange) > 5 else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let context = buildContext(
                metric: metric,
                baselines: baselines,
                historicalContext: historicalContext,
                correlations: correlations,
                timeSeries: timeSeries,
                trends: trends
            )

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .improving,
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange,
                insightContext: context
            )
            insights.append(insight)
        }

        // Add reversal insights — these are high-signal events worth surfacing
        for (metric, trendResult) in trends {
            guard trendResult.inflection == .reversing else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)
            let isPositiveReversal = (trendResult.direction == .improving)

            insights.append(Insight(
                metric: metric,
                title: "\(metric.displayName) \(isPositiveReversal ? "Turning Around" : "Reversing Course")",
                summary: "Your \(metric.displayName.lowercased()) trend has reversed direction in the past week. \(isPositiveReversal ? "Previous decline is now recovering." : "Previous improvement is now declining.")",
                recommendation: isPositiveReversal
                    ? "Good news — your \(metric.displayName.lowercased()) is recovering. Keep doing what you changed recently."
                    : "Your \(metric.displayName.lowercased()) was improving but is now declining. Review any recent changes to your routine.",
                severity: isPositiveReversal ? .info : .warning,
                trend: trendResult.direction,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
            ))
        }

        // Deduplicate and sort by priority
        return deduplicate(insights).sorted { $0.priorityScore > $1.priorityScore }
    }

    // MARK: - Deduplication

    /// Remove duplicate insights about the same metric, keeping only the highest-priority
    /// insight per metric. Exception: keep both if one is a causal chain and the other is
    /// an anomaly — they provide fundamentally different information.
    private static func deduplicate(_ insights: [Insight]) -> [Insight] {
        var grouped: [HealthMetric: [Insight]] = [:]
        for insight in insights {
            grouped[insight.metric, default: []].append(insight)
        }

        var result: [Insight] = []
        for (_, metricInsights) in grouped {
            if metricInsights.count <= 1 {
                result.append(contentsOf: metricInsights)
                continue
            }

            // Separate causal chain and anomaly insights — they provide different info
            let causalChains = metricInsights.filter { $0.category == .causalChain }
            let anomalies = metricInsights.filter { $0.category == .anomaly }
            let others = metricInsights.filter { $0.category != .causalChain && $0.category != .anomaly }

            // Keep the best causal chain if any exist
            if let bestCausal = causalChains.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestCausal)
            }

            // Keep the best anomaly if any exist
            if let bestAnomaly = anomalies.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestAnomaly)
            }

            // For everything else, keep only the single highest-priority
            if let bestOther = others.max(by: { $0.priorityScore < $1.priorityScore }) {
                // Only add if we didn't already keep a causal or anomaly (avoid triple-stacking)
                if causalChains.isEmpty && anomalies.isEmpty {
                    result.append(bestOther)
                } else if bestOther.priorityScore > (causalChains.first?.priorityScore ?? 0)
                            && bestOther.priorityScore > (anomalies.first?.priorityScore ?? 0) {
                    result.append(bestOther)
                }
            }
        }

        return result
    }

    // MARK: - Actionability Scoring

    /// Rate how actionable an insight is on a 0-100 scale.
    /// Higher scores indicate insights that are specific, timely, and provide concrete guidance.
    static func actionabilityScore(_ insight: Insight) -> Int {
        var score = 0

        // Contains specific numbers (deviation %, values) → +20
        let hasNumbers = insight.summary.contains("%") ||
            insight.summary.range(of: #"\d+\.?\d*\s*(bpm|ms|hrs|kcal|steps|min|kg|mmHg|°C|km|%)"#, options: .regularExpression) != nil
        if hasNumbers { score += 20 }

        // References a specific time frame → +15
        let timeFramePatterns = ["week", "month", "day", "year", "last", "past", "recent", "today", "yesterday"]
        let hasTimeFrame = timeFramePatterns.contains { insight.summary.localizedCaseInsensitiveContains($0) }
        if hasTimeFrame { score += 15 }

        // Provides a concrete action (not just "monitor") → +25
        let concreteActions = ["consider", "try", "increase", "reduce", "consult", "adjust", "review", "focus", "prioritize", "aim for", "schedule"]
        let genericActions = ["monitor", "keep an eye", "watch", "observe", "track", "note"]
        let recLower = insight.recommendation.lowercased()
        let hasConcrete = concreteActions.contains { recLower.contains($0) }
        let isGenericAction = !hasConcrete && genericActions.contains { recLower.contains($0) }
        if hasConcrete { score += 25 }
        if isGenericAction { score -= 10 }
        if recLower.contains("priority today") { score += 10 }

        let genericRecommendationPatterns = [
            "within normal range",
            "is normal",
            "is stable",
            "holding steady"
        ]
        if insight.severity == .info &&
            genericRecommendationPatterns.contains(where: { recLower.contains($0) }) &&
            abs(insight.deviationPercent) < 8 {
            score -= 15
        }

        // Severity is warning or critical → +20
        if insight.severity >= .warning { score += 20 }

        // Has related metrics (cross-metric insight) → +20
        if !insight.relatedMetrics.isEmpty { score += 20 }

        // Is a causal chain or illness warning → +20 (inherently actionable)
        if insight.category == .causalChain || insight.category == .illnessWarning { score += 20 }

        // Penalize generic stable/improving platitudes → -30
        let summaryLower = insight.summary.lowercased()
        let genericPatterns = [" is stable", " is improving", " looks good", " within normal", " on track"]
        let isGenericAdvice = genericPatterns.contains { summaryLower.contains($0) }
            && insight.severity == .info
            && abs(insight.deviationPercent) < 5
        if isGenericAdvice { score -= 30 }

        // Boost context-rich insights
        if let ctx = insight.context {
            if !ctx.correlatedFactors.isEmpty { score += 10 }
            if ctx.projectedDaysToThreshold != nil { score += 5 }
            if ctx.rootCauseMetric != nil { score += 10 }
        }

        return max(0, min(100, score))
    }

    // MARK: - High-Quality Filtering

    /// Return only high-quality, actionable insights suitable for a Today/Home section.
    /// Filters to actionability score >= 40, sorted by priority, limited to maxCount.
    /// Excludes stable/improving platitudes that don't tell the user what to do.
    static func filterToActionable(_ insights: [Insight], maxCount: Int = 5) -> [Insight] {
        insights
            .filter { insight in
                // Only show insights the user can act on: declining trends or warning+ severity
                if insight.severity >= .warning { return true }
                if insight.trend == .declining && abs(insight.deviationPercent) >= 5 {
                    return actionabilityScore(insight) >= 40
                }
                // Exception: extreme percentiles (bottom 10%) even if stable
                if let pct = insight.context?.allTimePercentile, pct <= 10 {
                    return true
                }
                return false
            }
            .sorted { $0.priorityScore > $1.priorityScore }
            .prefix(maxCount)
            .map { $0 }
    }

    private static func createInsight(
        metric: HealthMetric,
        severity: Severity,
        trend: TrendDirection,
        rateOfChange: TrendAnalyzer.RateOfChange = .negligible,
        inflection: TrendAnalyzer.Inflection = .steady,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        historicalContext: HistoricalAnalyzer.HistoricalContext? = nil,
        insightContext: InsightContext? = nil
    ) -> Insight {
        let triage = SafetyTriageEngine.assess(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            trend: trend
        )
        let effectiveSeverity = max(severity, triage.level.minimumSeverity)

        let title = generateTitle(
            metric: metric,
            trend: trend,
            severity: effectiveSeverity,
            rateOfChange: rateOfChange,
            inflection: inflection
        )
        var summary = generateSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend,
            inflection: inflection,
            historicalContext: historicalContext,
            insightContext: insightContext
        )
        if let triageNote = triage.summaryNote {
            summary += " \(triageNote)"
        }

        let baseRecommendation = RulesConfiguration.recommendation(
            for: metric, severity: effectiveSeverity, trend: trend,
            currentValue: currentValue, deviationPercent: deviationPercent,
            context: insightContext
        )
        let personalizedRecommendation = personalizeRecommendation(
            baseRecommendation: baseRecommendation,
            metric: metric,
            severity: effectiveSeverity,
            trend: trend,
            deviationPercent: deviationPercent,
            context: insightContext
        )
        let recommendation = triage.decorateRecommendation(personalizedRecommendation)

        return Insight(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: effectiveSeverity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            context: insightContext
        )
    }

    // MARK: - Context Building

    /// Build rich InsightContext for a metric from all available data sources
    private static func buildContext(
        metric: HealthMetric,
        baselines: [HealthMetric: UserBaseline],
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext],
        correlations: [HealthCorrelation],
        timeSeries: [HealthMetric: MetricTimeSeries],
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) -> InsightContext? {
        var ctx = InsightContext()
        var hasData = false

        // Slope + projected days to threshold
        if let trend = trends[metric], let baseline = baselines[metric] {
            ctx.slope = trend.weekOverWeekChange / 7.0
            if trend.direction == .declining, let slope = ctx.slope, abs(slope) > 0.1 {
                let range = RulesConfiguration.normalRange(for: metric)
                let threshold = metric.higherIsBetter ? range.low : range.high
                let current = baseline.mean * (1.0 + trend.weekOverWeekChange / 100.0)
                let distToThreshold = abs(current - threshold)
                let dailyChange = abs(slope) * baseline.mean / 100.0
                if dailyChange > 0 {
                    let days = Int(distToThreshold / dailyChange)
                    if days > 0 && days <= 21 {
                        ctx.projectedDaysToThreshold = days
                        hasData = true
                    }
                }
            }
            ctx.comparisonToLastWeek = trend.weekOverWeekChange
            hasData = true
        }

        // Historical context
        if let hist = historicalContext[metric] {
            if hist.totalDataPoints >= 180 {
                ctx.allTimePercentile = hist.allTimePercentile
                hasData = true
            }
            if let seasonal = hist.seasonalDeviation, abs(seasonal) >= 5, hist.yearsOfData >= 2 {
                ctx.seasonalDeviation = seasonal
                hasData = true
            }
            if let yoy = hist.yearOverYearChange, abs(yoy) > 2 {
                ctx.yearOverYearChange = yoy
                hasData = true
            }
            ctx.dataPointCount = hist.totalDataPoints
        }

        // Top 3 correlated factors for this metric
        let relevantCorrelations = correlations
            .filter { $0.metricA == metric || $0.metricB == metric }
            .sorted { abs($0.correlation) > abs($1.correlation) }
        let topCorrelations = Array(relevantCorrelations.prefix(3))

        ctx.correlatedFactors = topCorrelations.map { corr in
            let factorMetric = corr.metricA == metric ? corr.metricB : corr.metricA
            return CorrelatedFactor(
                metric: factorMetric,
                correlation: corr.correlation,
                effectPercent: corr.effectPercentDiff,
                dayOffset: corr.dayOffset,
                sampleCount: corr.sampleCount
            )
        }
        if !ctx.correlatedFactors.isEmpty { hasData = true }

        // Infer a likely root cause metric when enough directional evidence exists.
        if let rootCause = inferRootCause(
            metric: metric,
            correlations: relevantCorrelations,
            trends: trends,
            baselines: baselines,
            timeSeries: timeSeries
        ) {
            ctx.rootCauseMetric = rootCause.metric
            ctx.rootCauseDeviation = rootCause.deviation
            hasData = true
        }

        // Recent values (last 7 days)
        if let series = timeSeries[metric] {
            let recent = series.samples(lastDays: 7)
            if !recent.isEmpty {
                ctx.recentValues = recent.map { (date: $0.date, value: $0.value) }
                hasData = true
            }
        }

        // Confidence level based on data depth
        if let baseline = baselines[metric] {
            let confidence = min(Double(baseline.sampleCount) / 90.0, 1.0)
            ctx.confidenceLevel = confidence
        }

        return hasData ? ctx : nil
    }

    // MARK: - Root Cause Inference

    private static func inferRootCause(
        metric: HealthMetric,
        correlations: [HealthCorrelation],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> (metric: HealthMetric, deviation: Double)? {
        var best: (metric: HealthMetric, deviation: Double, score: Double)?

        for corr in correlations {
            let candidateMetric: HealthMetric
            if corr.metricB == metric {
                candidateMetric = corr.metricA
            } else if corr.metricA == metric, corr.dayOffset == 0 {
                candidateMetric = corr.metricB
            } else {
                continue
            }

            guard candidateMetric != metric,
                  let deviation = deviationPercent(
                    for: candidateMetric,
                    trends: trends,
                    baselines: baselines,
                    timeSeries: timeSeries
                  ),
                  abs(deviation) >= 4 else { continue }

            let correlationStrength = abs(corr.correlation)               // 0...1
            let effectStrength = min(abs(corr.effectPercentDiff) / 20, 1) // 0...1
            let deviationStrength = min(abs(deviation) / 20, 1)           // 0...1
            let sampleStrength = min(Double(corr.sampleCount) / 45, 1)    // 0...1
            let lagBonus = (corr.metricB == metric && corr.dayOffset > 0) ? 0.1 : 0

            var score = (0.35 * correlationStrength) +
                (0.30 * effectStrength) +
                (0.20 * deviationStrength) +
                (0.15 * sampleStrength) +
                lagBonus

            if trends[candidateMetric]?.direction == .declining {
                score += 0.05
            }

            guard score >= 0.55 else { continue }

            if best == nil || score > best!.score {
                best = (candidateMetric, deviation, score)
            }
        }

        return best.map { (metric: $0.metric, deviation: $0.deviation) }
    }

    private static func deviationPercent(
        for metric: HealthMetric,
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> Double? {
        if let trend = trends[metric], abs(trend.weekOverWeekChange) > 0 {
            return trend.weekOverWeekChange
        }

        guard let baseline = baselines[metric],
              baseline.mean != 0,
              let latest = timeSeries[metric]?.latestValue else { return nil }

        return ((latest - baseline.mean) / baseline.mean) * 100.0
    }

    // MARK: - Personalized Recommendation Composition

    private static func personalizeRecommendation(
        baseRecommendation: String,
        metric: HealthMetric,
        severity: Severity,
        trend: TrendDirection,
        deviationPercent: Double,
        context: InsightContext?
    ) -> String {
        let lever = bestPersonalLever(targetMetric: metric, context: context)
        let needsAction = severity >= .warning || trend == .declining || abs(deviationPercent) >= 10
        guard needsAction || lever != nil else { return baseRecommendation }

        var parts: [String] = []

        if let priority = priorityActionSentence(
            metric: metric,
            severity: severity,
            trend: trend,
            lever: lever
        ) {
            parts.append(priority)
        }

        parts.append(baseRecommendation)

        if let lever {
            let leadTime = leadTimeLabel(for: lever.dayOffset)
            let impact = String(format: "%.0f", abs(lever.effectPercent))
            let evidence = evidenceLabel(context: context, sampleCount: lever.sampleCount)
            parts.append(
                "Why this is personalized: your data links \(lever.metric.displayName.lowercased()) to \(metric.displayName.lowercased()) with ~\(impact)% impact (\(leadTime), \(evidence) confidence)."
            )
        } else if let confidence = context?.confidenceLevel, confidence < 0.45 {
            parts.append("Personalization confidence is still building. Keep syncing daily so the action plan can adapt to your own patterns.")
        }

        if let followUp = followUpSentence(severity: severity, context: context) {
            parts.append(followUp)
        }

        return parts.joined(separator: " ")
    }

    private static func bestPersonalLever(targetMetric: HealthMetric, context: InsightContext?) -> CorrelatedFactor? {
        guard let factors = context?.correlatedFactors else { return nil }

        return factors
            .filter {
                $0.metric != targetMetric &&
                abs($0.correlation) >= 0.30 &&
                abs($0.effectPercent) >= 6 &&
                $0.sampleCount >= 12
            }
            .max {
                (abs($0.correlation) * abs($0.effectPercent)) <
                    (abs($1.correlation) * abs($1.effectPercent))
            }
    }

    private static func priorityActionSentence(
        metric: HealthMetric,
        severity: Severity,
        trend: TrendDirection,
        lever: CorrelatedFactor?
    ) -> String? {
        guard severity >= .warning || trend == .declining || lever != nil else { return nil }
        let actionMetric = lever?.metric ?? metric
        return "Priority today: \(actionProtocol(for: actionMetric, severity: severity))."
    }

    private static func followUpSentence(severity: Severity, context: InsightContext?) -> String? {
        if let days = context?.projectedDaysToThreshold, days <= 7 {
            return "Follow-up: recheck in 48 hours to confirm this is stabilizing before it reaches warning range."
        }
        if severity >= .warning {
            return "Follow-up: review this trend again in 3 days to verify the direction has improved."
        }
        return nil
    }

    private static func leadTimeLabel(for dayOffset: Int) -> String {
        if dayOffset <= 0 { return "same-day signal" }
        if dayOffset == 1 { return "next-day signal" }
        return "\(dayOffset)-day lead signal"
    }

    private static func evidenceLabel(context: InsightContext?, sampleCount: Int) -> String {
        let confidence = context?.confidenceLevel ?? 0
        let points = max(sampleCount, context?.dataPointCount ?? 0)
        if confidence >= 0.75 && points >= 90 { return "high" }
        if confidence >= 0.50 && points >= 45 { return "medium" }
        return "early"
    }

    private static func actionProtocol(for metric: HealthMetric, severity: Severity) -> String {
        switch metric {
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore, .sleepAwake:
            return "protect an 8-hour sleep window tonight and cut screens 60 minutes before bed"
        case .steps, .activeCalories, .exerciseMinutes, .appleMoveTime, .distanceWalkingRunning, .standHours:
            return "add two 10-minute brisk walks today and hit at least 30 active minutes"
        case .heartRateVariability:
            return "do 10 minutes of slow breathing and finish dinner at least 3 hours before bedtime"
        case .restingHeartRate, .heartRate, .walkingHeartRateAverage:
            return "avoid caffeine after 2 PM and do a 10-minute wind-down breathing session before sleep"
        case .mindfulMinutes, .electrodermalActivity:
            return "run one 10-minute mindfulness session now and one before bed"
        case .timeInDaylight:
            return "get 20 minutes of outdoor light before noon"
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return severity >= .warning
                ? "cap sodium under 2300mg today and complete a 20-minute easy walk"
                : "check blood pressure at the same time tomorrow morning"
        case .bloodOxygen, .atrialFibrillationBurden, .bodyTemperature, .respiratoryRate:
            return severity >= .warning
                ? "repeat the measurement now and contact a clinician if it stays abnormal"
                : "recheck this metric later today after rest"
        case .weight, .bmi, .bodyFatPercentage, .waistCircumference:
            return "anchor meals around protein and fiber today and avoid late-night snacking"
        case .vo2Max, .heartRateRecovery:
            return "schedule one 25-minute zone-2 cardio session today or tomorrow"
        case .walkingSpeed, .walkingStepLength, .walkingAsymmetry, .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance:
            return "add a 10-minute mobility and balance block before your next walk"
        default:
            return "run one small habit experiment today and compare tomorrow's metric response"
        }
    }

    private static func generateTitle(
        metric: HealthMetric,
        trend: TrendDirection,
        severity: Severity,
        rateOfChange: TrendAnalyzer.RateOfChange = .negligible,
        inflection: TrendAnalyzer.Inflection = .steady
    ) -> String {
        let metricName = metric.displayName
        let ratePrefix = rateOfChange >= .moderate ? "\(rateOfChange.displayLabel.capitalized) " : ""
        let inflectionSuffix: String
        switch inflection {
        case .accelerating where trend == .declining: inflectionSuffix = " & Accelerating"
        case .decelerating where trend == .declining: inflectionSuffix = " (Slowing)"
        case .reversing: inflectionSuffix = " — Reversing"
        default: inflectionSuffix = ""
        }

        switch (trend, severity) {
        case (.declining, .critical): return "\(metricName) Critically Low\(inflectionSuffix)"
        case (.declining, .warning): return "\(metricName) \(ratePrefix)Needs Attention\(inflectionSuffix)"
        case (.declining, .info): return "\(metricName) \(ratePrefix)Declining\(inflectionSuffix)"
        case (.improving, _): return "\(metricName) \(ratePrefix)Improving\(inflection == .accelerating ? " & Gaining Momentum" : "")"
        case (.stable, .critical): return "\(metricName) Outside Safe Range"
        case (.stable, .warning): return "\(metricName) Elevated"
        case (.stable, .info): return "\(metricName) Stable"
        }
    }

    private static func generateSummary(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        trend: TrendDirection,
        inflection: TrendAnalyzer.Inflection = .steady,
        historicalContext: HistoricalAnalyzer.HistoricalContext? = nil,
        insightContext: InsightContext? = nil
    ) -> String {
        let formattedCurrent = formatValue(currentValue, metric: metric)
        let formattedBaseline = formatValue(baselineValue, metric: metric)
        let absDeviation = String(format: "%.1f", abs(deviationPercent))
        let direction = deviationPercent > 0 ? "above" : "below"

        let inflectionNote: String
        switch inflection {
        case .accelerating: inflectionNote = " The rate of change is accelerating."
        case .decelerating: inflectionNote = " The decline is slowing — a recovery may be starting."
        case .reversing: inflectionNote = " The trend has recently reversed direction."
        case .steady: inflectionNote = ""
        }

        // Build historical context sentence if available
        var historyNote = ""
        if let ctx = historicalContext {
            var parts: [String] = []

            // Year-over-year comparison
            if let yoy = ctx.yearOverYearChange, abs(yoy) > 2 {
                let yoyAbs = String(format: "%.0f", abs(yoy))
                parts.append("\(yoy > 0 ? "up" : "down") \(yoyAbs)% vs this time last year")
            }

            // All-time percentile
            if ctx.totalDataPoints >= 180 {
                let pct = Int(ctx.allTimePercentile.rounded())
                if pct <= 20 || pct >= 80 {
                    let label = pct >= 80 ? "top \(100 - pct)%" : "bottom \(pct)%"
                    parts.append("in the \(label) of your \(ctx.yearsOfData)-year history")
                }
            }

            // Seasonal context
            if let seasonalDev = ctx.seasonalDeviation, abs(seasonalDev) >= 5, ctx.yearsOfData >= 2 {
                let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
                let seasonalAbs = String(format: "%.0f", abs(seasonalDev))
                parts.append("\(seasonalDev > 0 ? "above" : "below") your typical \(monthName) by \(seasonalAbs)%")
            }

            if !parts.isEmpty {
                historyNote = " Historically: " + parts.joined(separator: ", ") + "."
            }
        }

        // Build causal hint from historical context correlations
        let causalHint = generateCausalHint(metric: metric, deviationPercent: deviationPercent, historicalContext: historicalContext)

        // Projection sentence from InsightContext
        let projectionNote: String
        if trend == .declining, let days = insightContext?.projectedDaysToThreshold, days > 0, days <= 21 {
            projectionNote = " At the current rate, this could reach warning level in ~\(days) days."
        } else {
            projectionNote = ""
        }

        switch trend {
        case .declining:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit)). Current: \(formattedCurrent) \(metric.unit).\(inflectionNote)\(projectionNote)\(causalHint)\(historyNote)"
        case .improving:
            return "Your \(metric.displayName.lowercased()) has improved \(absDeviation)% from your baseline. Current: \(formattedCurrent) \(metric.unit).\(inflectionNote)\(causalHint)\(historyNote)"
        case .stable:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit)).\(causalHint)\(historyNote)"
        }
    }

    /// Generate a causal hint sentence based on known metric relationships and historical context.
    /// For example: "Based on your history, this level typically follows nights with less than 6 hours of sleep."
    private static func generateCausalHint(
        metric: HealthMetric,
        deviationPercent: Double,
        historicalContext: HistoricalAnalyzer.HistoricalContext?
    ) -> String {
        // Only provide causal hints for notable deviations
        guard abs(deviationPercent) > 10 else { return "" }

        // Known causal relationships (metric being affected → likely cause description)
        let causalMap: [HealthMetric: String] = [
            .heartRateVariability: "Based on your history, this level typically follows nights with less than 6 hours of sleep.",
            .restingHeartRate: "Based on your history, elevated resting heart rate often follows periods of reduced sleep or high stress.",
            .bloodOxygen: "Based on your history, lower blood oxygen typically correlates with disrupted sleep patterns.",
            .sleepDuration: "Based on your history, shorter sleep often follows days with low physical activity or late exercise.",
            .sleepDeep: "Based on your history, deep sleep decreases often correlate with higher stress or inconsistent bedtimes.",
            .vo2Max: "Based on your history, VO2 Max changes tend to follow shifts in exercise consistency over 2-4 weeks.",
            .activeCalories: "Based on your history, lower calorie burn typically follows reduced step count and exercise minutes.",
            .exerciseMinutes: "Based on your history, exercise dips often cluster with disrupted sleep patterns.",
            .bodyTemperature: "Based on your history, temperature shifts often accompany changes in sleep duration and HRV.",
            .respiratoryRate: "Based on your history, respiratory rate changes often track with sleep quality and stress levels.",
        ]

        // Only add causal hint if historical context confirms sufficient data depth
        guard let ctx = historicalContext, ctx.totalDataPoints >= 90, ctx.yearsOfData >= 1 else { return "" }

        if let hint = causalMap[metric] {
            return " " + hint
        }
        return ""
    }

    private static func formatValue(_ value: Double, metric: HealthMetric) -> String {
        metric.formatValue(value)
    }
}
