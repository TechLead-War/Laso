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

        // Add reversal insights. these are high-signal events worth surfacing
        for (metric, trendResult) in trends {
            guard trendResult.inflection == .reversing else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)
            let isPositiveReversal = (trendResult.direction == .improving)
            let formatted = formatValue(currentValue, metric: metric)
            let previousFormatted = formatValue(baseline.mean, metric: metric)

            let reversalContext = buildContext(
                metric: metric,
                baselines: baselines,
                historicalContext: historicalContext,
                correlations: correlations,
                timeSeries: timeSeries,
                trends: trends
            )

            let rootCauseName = reversalContext?.rootCauseMetric?.displayName
            let topFactorSampleCount = reversalContext?.correlatedFactors.first?.sampleCount

            let reversalSummary = Copy.Causation.reversalWithContext(
                metricName: metric.displayName,
                isPositive: isPositiveReversal,
                rootCauseName: rootCauseName,
                sampleCount: topFactorSampleCount
            )

            let reversalRecommendation: String
            if isPositiveReversal {
                if let cause = rootCauseName {
                    reversalRecommendation = Copy.Causation.reversalRecoveringWithCause(
                        metricName: metric.displayName, current: formatted,
                        unit: metric.unit, previous: previousFormatted, causeName: cause
                    )
                } else {
                    reversalRecommendation = Copy.Causation.reversalRecovering(
                        metricName: metric.displayName, current: formatted,
                        unit: metric.unit, previous: previousFormatted
                    )
                }
            } else {
                if let cause = rootCauseName {
                    reversalRecommendation = Copy.Causation.reversalDeclinedWithCause(
                        metricName: metric.displayName, causeName: cause
                    )
                } else {
                    reversalRecommendation = Copy.Causation.reversalDeclined(
                        metricName: metric.displayName
                    )
                }
            }

            insights.append(Insight(
                metric: metric,
                title: "\(metric.displayName) \(isPositiveReversal ? "Turning Around" : "Reversing Course")",
                summary: reversalSummary,
                recommendation: reversalRecommendation,
                severity: isPositiveReversal ? .info : .warning,
                trend: trendResult.direction,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange,
                context: reversalContext
            ))
        }

        // Sort by priority. deduplication is handled by InsightCoordinator.coordinate()
        // at the end of the full pipeline, so no intermediate dedup here.
        return insights.sorted { $0.priorityScore > $1.priorityScore }
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
            inflection: inflection,
            insightContext: insightContext
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
            if let seasonal = hist.seasonalDeviation, abs(seasonal) >= 5, hist.yearsOfData >= 1 {
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

        // Recent values (last 7 days) only flag that the metric has usable data.
        if let series = timeSeries[metric], !series.samples(lastDays: 7).isEmpty {
            hasData = true
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

            if best.map({ score > $0.score }) ?? true {
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
              let latest = timeSeries[metric]?.latestValue else { return nil }

        return baseline.deviationPercent(for: latest)
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
            deviationPercent: deviationPercent,
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
        deviationPercent: Double,
        lever: CorrelatedFactor?
    ) -> String? {
        guard severity >= .warning || trend == .declining || lever != nil else { return nil }
        let actionMetric = lever?.metric ?? metric
        let actionDeviation = lever.map { abs($0.effectPercent) } ?? abs(deviationPercent)
        let direction = deviationPercent > 0 ? "above" : "below"
        return Copy.Insights.priorityToday(actionProtocol: actionProtocol(for: actionMetric, severity: severity, deviation: actionDeviation, direction: direction))
    }

    private static func followUpSentence(severity: Severity, context: InsightContext?) -> String? {
        if let days = context?.projectedDaysToThreshold, days <= 7 {
            return Copy.Insights.recheckIn48Hours
        }
        if severity >= .warning {
            return Copy.Insights.reviewIn3Days
        }
        return nil
    }

    private static func leadTimeLabel(for dayOffset: Int) -> String {
        if dayOffset <= 0 { return Copy.Insights.sameDaySignal }
        if dayOffset == 1 { return Copy.Insights.nextDaySignal }
        return Copy.Insights.dayLeadSignal(dayOffset)
    }

    private static func evidenceLabel(context: InsightContext?, sampleCount: Int) -> String {
        let confidence = context?.confidenceLevel ?? 0
        let points = max(sampleCount, context?.dataPointCount ?? 0)
        if confidence >= 0.75 && points >= 90 { return Copy.Insights.evidenceHigh }
        if confidence >= 0.50 && points >= 45 { return Copy.Insights.evidenceMedium }
        return Copy.Insights.evidenceEarly
    }

    /// A deviation that saturated the producer bound came off a near-zero baseline, so the
    /// number carries no information and the sentence has to describe the gap in words.
    /// Both producers (TrendAnalyzer and UserBaseline) saturate at the same value.
    private static func isPercentMeaningless(_ deviationPercent: Double) -> Bool {
        abs(deviationPercent) >= TrendAnalyzer.maxPercentChange
    }

    private static func actionProtocol(for metric: HealthMetric, severity: Severity, deviation: Double, direction: String) -> String {
        if isPercentMeaningless(deviation) {
            return Copy.Insights.farFromUsual(metricName: metric.displayName.lowercased(), direction: direction)
        }
        let dev = Int(abs(deviation))
        switch metric {
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore, .sleepAwake:
            return Copy.Insights.sleepMetricsOff(dev: dev)
        case .steps, .activeCalories, .exerciseMinutes, .appleMoveTime, .distanceWalkingRunning, .standHours:
            return Copy.Insights.activityDeviation(dev: dev, direction: direction)
        case .heartRateVariability:
            return Copy.Insights.hrvTrending(direction: direction, dev: dev)
        case .restingHeartRate, .heartRate, .walkingHeartRateAverage:
            return Copy.Insights.rhrShifted(dev: dev)
        case .mindfulMinutes, .electrodermalActivity:
            return Copy.Insights.mindfulnessDeviation(dev: dev, direction: direction)
        case .timeInDaylight:
            return Copy.Insights.daylightDeviation(dev: dev, direction: direction)
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            return severity >= .warning
                ? Copy.Insights.bpOutsideRange
                : Copy.Insights.recheckSingleReading
        case .bloodOxygen, .atrialFibrillationBurden, .bodyTemperature, .respiratoryRate:
            return severity >= .warning
                ? Copy.Insights.readingOutsideRange
                : Copy.Insights.recheckMetricTrend
        case .weight, .bmi, .bodyFatPercentage, .waistCircumference:
            return Copy.Insights.bodyMetricsShifted(dev: dev)
        case .vo2Max, .heartRateRecovery:
            return Copy.Insights.vo2MaxTrending(direction: direction, dev: dev)
        case .walkingSpeed, .walkingStepLength, .walkingAsymmetry, .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance:
            return Copy.Insights.mobilityMetricsOff(dev: dev)
        default:
            return Copy.Insights.genericMetricDeviation(metricName: metric.displayName.lowercased(), dev: dev)
        }
    }

    private static func generateTitle(
        metric: HealthMetric,
        trend: TrendDirection,
        severity: Severity,
        rateOfChange: TrendAnalyzer.RateOfChange = .negligible,
        inflection: TrendAnalyzer.Inflection = .steady,
        insightContext: InsightContext? = nil
    ) -> String {
        let metricName = metric.displayName

        // Causation-style title when we know the root cause
        if let rootCause = insightContext?.rootCauseMetric {
            let rootCauseName = rootCause.displayName
            switch trend {
            case .declining:
                return Copy.Causation.causationTitle(metricName: metricName, rootCauseName: rootCauseName)
            case .stable where severity >= .warning:
                return Copy.Causation.causationTitle(metricName: metricName, rootCauseName: rootCauseName)
            case .improving:
                return Copy.Causation.improvingCausationTitle(metricName: metricName, rootCauseName: rootCauseName)
            default:
                break
            }
        }

        // Fallback to standard titles when no root cause is known
        let ratePrefix = rateOfChange >= .moderate ? "\(rateOfChange.displayLabel.capitalized) " : ""
        let inflectionSuffix: String
        switch inflection {
        case .accelerating where trend == .declining: inflectionSuffix = Copy.Insights.andAccelerating
        case .decelerating where trend == .declining: inflectionSuffix = Copy.Insights.slowing
        case .reversing: inflectionSuffix = Copy.Insights.dashReversing
        default: inflectionSuffix = ""
        }

        // "Low" vs "High" must follow the metric's direction. `.declining` means
        // "getting worse" after higherIsBetter normalization, so for a metric where
        // higher is worse (uneven walking, resting HR) the bad value is HIGH, not low.
        // Without this, walking asymmetry read "Critically Low" while actually high.
        switch (trend, severity) {
        case (.declining, .critical): return "\(metricName) \(metric.higherIsBetter ? "Critically Low" : "Critically High")\(inflectionSuffix)"
        case (.declining, .warning): return "\(metricName) \(ratePrefix)Needs Attention\(inflectionSuffix)"
        case (.declining, .info): return "\(metricName) \(ratePrefix)Declining\(inflectionSuffix)"
        case (.improving, _): return "\(metricName) \(ratePrefix)Improving\(inflection == .accelerating ? Copy.Insights.andGainingMomentum : "")"
        case (.stable, .critical): return "\(metricName) Outside Safe Range"
        case (.stable, .warning): return "\(metricName) \(metric.higherIsBetter ? "Below Usual" : "Elevated")"
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
        // Try causation-style summary first when we have rich context
        if let causationSummary = generateCausationSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend,
            inflection: inflection,
            historicalContext: historicalContext,
            insightContext: insightContext
        ) {
            return causationSummary
        }

        // Fallback to standard summary when context is insufficient
        return generateStandardSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend,
            inflection: inflection,
            historicalContext: historicalContext,
            insightContext: insightContext
        )
    }

    /// Build a WHOOP-style causation narrative from InsightContext data.
    /// Returns nil when there is not enough context to form a causation sentence.
    private static func generateCausationSummary(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        trend: TrendDirection,
        inflection: TrendAnalyzer.Inflection,
        historicalContext: HistoricalAnalyzer.HistoricalContext?,
        insightContext: InsightContext?
    ) -> String? {
        guard let ctx = insightContext else { return nil }

        var sentences: [String] = []

        // Lead sentence: "Your HRV dropped 18% because deep sleep was low yesterday."
        if let rootCause = ctx.rootCauseMetric, let rootDeviation = ctx.rootCauseDeviation {
            let bestDayOffset = ctx.correlatedFactors
                .first { $0.metric == rootCause }?.dayOffset ?? 0

            if trend == .improving {
                sentences.append(
                    Copy.Causation.improvementCauseSentence(
                        metricName: metric.displayName,
                        deviationPercent: deviationPercent,
                        rootCauseName: rootCause.displayName,
                        rootCauseDeviation: rootDeviation
                    )
                )
            } else {
                sentences.append(
                    Copy.Causation.rootCauseSentence(
                        metricName: metric.displayName,
                        deviationPercent: deviationPercent,
                        trend: trend,
                        rootCauseName: rootCause.displayName,
                        rootCauseDeviation: rootDeviation,
                        dayOffset: bestDayOffset
                    )
                )
            }

            // Pattern evidence: "The last N times that happened, HRV followed."
            if let factor = ctx.correlatedFactors.first(where: { $0.metric == rootCause }),
               factor.sampleCount >= 3 {
                let rootDirection = rootDeviation < 0 ? "low" : "high"
                let metricDirection = trend == .improving ? "improved" : "dropped"
                sentences.append(
                    Copy.Causation.patternEvidenceSentence(
                        rootCauseName: rootCause.displayName,
                        rootCauseDirection: rootDirection,
                        sampleCount: factor.sampleCount,
                        metricName: metric.displayName,
                        metricDirection: metricDirection
                    )
                )
            }
        } else if let topFactor = ctx.correlatedFactors.first,
                  topFactor.sampleCount >= 30,
                  abs(topFactor.correlation) >= 0.5 {
            // Stricter gate: claim "X and Y are linked" only with at least 30
            // paired observations (statistical significance) and a moderate-or-
            // stronger correlation (|r| >= 0.5). Weaker signals get suppressed
            // rather than presented as user-facing causation.
            sentences.append(
                Copy.Causation.correlatedFactorSentence(
                    factorName: topFactor.metric.displayName,
                    metricName: metric.displayName,
                    sampleCount: topFactor.sampleCount,
                    dayOffset: topFactor.dayOffset,
                    effectPercent: topFactor.effectPercent
                )
            )
        } else {
            // Not enough causal data to form a causation summary
            return nil
        }

        // Projection with cause if declining
        if trend == .declining, let days = ctx.projectedDaysToThreshold, days > 0, days <= 21 {
            if let rootCause = ctx.rootCauseMetric {
                sentences.append(
                    Copy.Causation.projectionWithCause(
                        metricName: metric.displayName,
                        days: days,
                        rootCauseName: rootCause.displayName
                    )
                )
            } else {
                sentences.append(
                    Copy.Causation.projectionWithoutCause(
                        metricName: metric.displayName,
                        days: days
                    )
                )
            }
        }

        // Week comparison with cause
        if let weekChange = ctx.comparisonToLastWeek, abs(weekChange) >= 3 {
            if let rootCause = ctx.rootCauseMetric {
                sentences.append(
                    Copy.Causation.weekComparisonWithCause(
                        changePercent: weekChange,
                        rootCauseName: rootCause.displayName
                    )
                )
            } else {
                sentences.append(
                    Copy.Causation.weekComparisonSimple(changePercent: weekChange)
                )
            }
        }

        // Percentile context
        if let percentile = ctx.allTimePercentile {
            let percentileText = Copy.Causation.percentileSentence(percentile: percentile)
            if !percentileText.isEmpty {
                sentences.append(percentileText)
            }
        }

        // Data depth: "Based on 45 days of your data."
        if let dataPoints = ctx.dataPointCount, dataPoints >= 14 {
            sentences.append(Copy.Causation.dataDepthSentence(dataPoints: dataPoints))
        } else if let confidence = ctx.confidenceLevel, confidence < 0.45 {
            sentences.append(Copy.Causation.lowConfidenceNote)
        }

        guard !sentences.isEmpty else { return nil }
        return sentences.joined(separator: " ")
    }

    /// Standard summary without causation context (original logic).
    private static func generateStandardSummary(
        metric: HealthMetric,
        currentValue: Double,
        baselineValue: Double,
        deviationPercent: Double,
        trend: TrendDirection,
        inflection: TrendAnalyzer.Inflection,
        historicalContext: HistoricalAnalyzer.HistoricalContext?,
        insightContext: InsightContext?
    ) -> String {
        let formattedCurrent = formatValue(currentValue, metric: metric)
        let formattedBaseline = formatValue(baselineValue, metric: metric)
        let absDeviation = String(format: "%.1f", abs(deviationPercent))
        let direction = deviationPercent > 0 ? "above" : "below"

        let inflectionNote: String
        switch inflection {
        case .accelerating: inflectionNote = Copy.Insights.accelerating
        case .decelerating: inflectionNote = Copy.Insights.decelerating
        case .reversing: inflectionNote = Copy.Insights.reversing
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
                    parts.append("in the \(label) of your history")
                }
            }

            // Seasonal context
            if let seasonalDev = ctx.seasonalDeviation, abs(seasonalDev) >= 5, ctx.yearsOfData >= 1 {
                let monthName = Date.cal.monthSymbols[Date.cal.component(.month, from: Date()) - 1]
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
            projectionNote = Copy.Insights.projectionWarning(days: days)
        } else {
            projectionNote = ""
        }

        let metricLower = metric.displayName.lowercased()
        let wordsOnly = isPercentMeaningless(deviationPercent)

        switch trend {
        case .declining:
            return wordsOnly
                ? Copy.Insights.decliningSummaryWithoutPercent(metricLower: metricLower, direction: direction, baseline: formattedBaseline, unit: metric.unit, current: formattedCurrent, inflectionNote: inflectionNote, projectionNote: projectionNote, causalHint: causalHint, historyNote: historyNote)
                : Copy.Insights.decliningSummary(metricLower: metricLower, deviation: absDeviation, direction: direction, baseline: formattedBaseline, unit: metric.unit, current: formattedCurrent, inflectionNote: inflectionNote, projectionNote: projectionNote, causalHint: causalHint, historyNote: historyNote)
        case .improving:
            return wordsOnly
                ? Copy.Insights.improvingSummaryWithoutPercent(metricLower: metricLower, current: formattedCurrent, unit: metric.unit, inflectionNote: inflectionNote, causalHint: causalHint, historyNote: historyNote)
                : Copy.Insights.improvingSummary(metricLower: metricLower, deviation: absDeviation, current: formattedCurrent, unit: metric.unit, inflectionNote: inflectionNote, causalHint: causalHint, historyNote: historyNote)
        case .stable:
            return wordsOnly
                ? Copy.Insights.stableSummaryWithoutPercent(metricLower: metricLower, direction: direction, baseline: formattedBaseline, unit: metric.unit, causalHint: causalHint, historyNote: historyNote)
                : Copy.Insights.stableSummary(metricLower: metricLower, deviation: absDeviation, direction: direction, baseline: formattedBaseline, unit: metric.unit, causalHint: causalHint, historyNote: historyNote)
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
            .heartRateVariability: Copy.Insights.causalHintHRV,
            .restingHeartRate: Copy.Insights.causalHintRHR,
            .bloodOxygen: Copy.Insights.causalHintBloodOxygen,
            .sleepDuration: Copy.Insights.causalHintSleepDuration,
            .sleepDeep: Copy.Insights.causalHintSleepDeep,
            .vo2Max: Copy.Insights.causalHintVO2Max,
            .activeCalories: Copy.Insights.causalHintActiveCalories,
            .exerciseMinutes: Copy.Insights.causalHintExercise,
            .bodyTemperature: Copy.Insights.causalHintBodyTemp,
            .respiratoryRate: Copy.Insights.causalHintRespiratoryRate,
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

// MARK: - InsightAnalyzer Conformance

extension InsightGenerator: InsightAnalyzer {
    static func generateInsights(context: AnalysisContext) -> [Insight] {
        generate(
            anomalies: context.anomalies,
            trends: context.trends,
            baselines: context.baselines,
            historicalContext: context.historicalContext,
            correlations: context.correlations,
            timeSeries: context.timeSeries
        )
    }
}
