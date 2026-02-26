import Foundation

/// Synthesizes analysis results into prioritized actionable insights
struct InsightGenerator {

    /// Generate insights from anomalies and trends with inflection-aware context
    static func generate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        baselines: [HealthMetric: UserBaseline],
        historicalContext: [HealthMetric: HistoricalAnalyzer.HistoricalContext] = [:]
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

            let insight = createInsight(
                metric: anomaly.metric,
                severity: effectiveSeverity,
                trend: trend,
                rateOfChange: rateOfChange,
                inflection: inflection,
                currentValue: anomaly.currentValue,
                baselineValue: anomaly.baselineValue,
                deviationPercent: anomaly.deviationPercent,
                historicalContext: historicalContext[anomaly.metric]
            )
            insights.append(insight)
        }

        // Also check for declining trends without anomalies
        for (metric, trendResult) in trends {
            guard trendResult.direction == .declining else { continue }
            guard !insights.contains(where: { $0.metric == metric }) else { continue }
            guard let baseline = baselines[metric] else { continue }

            let currentValue = baseline.mean * (1.0 + trendResult.weekOverWeekChange / 100.0)

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .declining,
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
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

            let insight = createInsight(
                metric: metric,
                severity: .info,
                trend: .improving,
                rateOfChange: trendResult.rateOfChange,
                inflection: trendResult.inflection,
                currentValue: currentValue,
                baselineValue: baseline.mean,
                deviationPercent: trendResult.weekOverWeekChange
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

        return max(0, min(100, score))
    }

    // MARK: - High-Quality Filtering

    /// Return only high-quality, actionable insights suitable for a Today/Home section.
    /// Filters to actionability score >= 40, sorted by priority, limited to maxCount.
    static func filterToActionable(_ insights: [Insight], maxCount: Int = 5) -> [Insight] {
        insights
            .filter { actionabilityScore($0) >= 40 }
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
        historicalContext: HistoricalAnalyzer.HistoricalContext? = nil
    ) -> Insight {
        let title = generateTitle(metric: metric, trend: trend, severity: severity, rateOfChange: rateOfChange, inflection: inflection)
        let summary = generateSummary(
            metric: metric,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent,
            trend: trend,
            inflection: inflection,
            historicalContext: historicalContext
        )
        let recommendation = RulesConfiguration.recommendation(for: metric, severity: severity, trend: trend)

        return Insight(
            metric: metric,
            title: title,
            summary: summary,
            recommendation: recommendation,
            severity: severity,
            trend: trend,
            currentValue: currentValue,
            baselineValue: baselineValue,
            deviationPercent: deviationPercent
        )
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
        historicalContext: HistoricalAnalyzer.HistoricalContext? = nil
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
            if let yoy = ctx.yearOverYearChange, abs(yoy) > 3 {
                let yoyAbs = String(format: "%.0f", abs(yoy))
                parts.append("\(yoy > 0 ? "up" : "down") \(yoyAbs)% vs this time last year")
            }

            // All-time percentile
            if ctx.totalDataPoints >= 180 {
                let pct = Int(ctx.allTimePercentile.rounded())
                if pct <= 10 || pct >= 90 {
                    let label = pct >= 90 ? "top \(100 - pct)%" : "bottom \(pct)%"
                    parts.append("in the \(label) of your \(ctx.yearsOfData)-year history")
                }
            }

            // Seasonal context
            if let seasonalDev = ctx.seasonalDeviation, abs(seasonalDev) > 8, ctx.yearsOfData >= 2 {
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

        switch trend {
        case .declining:
            return "Your \(metric.displayName.lowercased()) is \(absDeviation)% \(direction) your baseline (\(formattedBaseline) \(metric.unit)). Current: \(formattedCurrent) \(metric.unit).\(inflectionNote)\(causalHint)\(historyNote)"
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
