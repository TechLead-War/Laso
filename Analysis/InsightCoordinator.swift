import Foundation

/// Resolves contradictions, deduplicates, and caps insights from 20+ independent analyzers.
/// Resolution order: safety > severity > evidence depth.
struct InsightCoordinator {

    private static let maxInsights = 15

    static func coordinate(_ insights: [Insight]) -> [Insight] {
        guard !insights.isEmpty else { return [] }

        // Step 1: Infer directives for any insight still tagged .informational
        var tagged = insights.map { insight -> Insight in
            var copy = insight
            if copy.directive == .informational {
                copy.directive = inferDirective(for: copy)
            }
            return copy
        }

        // Step 2: Resolve contradictions
        tagged = resolveConflicts(tagged)

        // Step 3: Deduplicate (max 2 per metric)
        tagged = deduplicateByMetric(tagged)

        // Step 4: Sort by priority and cap
        tagged.sort { $0.priorityScore > $1.priorityScore }
        return Array(tagged.prefix(maxInsights))
    }

    // MARK: - Directive Inference

    static func inferDirective(for insight: Insight) -> InsightDirective {
        // Category-level fast paths
        switch insight.category {
        case .illnessWarning: return .rest
        case .clinicalTrajectory: return insight.severity >= .warning ? .seekMedical : .informational
        case .personalRecord: return .maintain
        case .cyclePhase: return .informational
        case .multiMetricCluster where insight.severity >= .warning: return .rest
        case .recovery where insight.severity >= .warning: return .rest
        default: break
        }

        // Cognitive/energy sub-types
        if insight.category == .cognitiveEnergy {
            if let d = cognitiveDirective(for: insight) { return d }
        }

        let title = insight.title.lowercased()
        let rec = insight.recommendation.lowercased()

        // Text-based rules (ordered by priority: medical > rest > sleep > activity > intensity)
        for rule in Self.textRules {
            if rule.matches(title: title, rec: rec, trend: insight.trend) {
                return rule.directive
            }
        }

        if insight.trend == .improving && insight.severity == .info { return .maintain }
        return .informational
    }

    // MARK: - Text Rule Table

    private struct TextRule {
        let directive: InsightDirective
        let titleKeywords: [String]
        let recKeywords: [String]
        let requiredTrend: TrendDirection?

        func matches(title: String, rec: String, trend: TrendDirection?) -> Bool {
            let titleMatch = titleKeywords.isEmpty || titleKeywords.contains(where: { title.contains($0) })
            let recMatch = recKeywords.isEmpty || recKeywords.contains(where: { rec.contains($0) })
            let trendMatch = requiredTrend == nil || trend == requiredTrend
            return (titleKeywords.isEmpty ? recMatch : recKeywords.isEmpty ? titleMatch : titleMatch || recMatch) && trendMatch
        }
    }

    private static let textRules: [TextRule] = [
        TextRule(directive: .seekMedical, titleKeywords: [], recKeywords: ["consult", "healthcare provider", "doctor"], requiredTrend: nil),
        TextRule(directive: .rest, titleKeywords: ["overtraining", "rest day", "recovery day", "rest deficit"], recKeywords: ["rest day", "genuine rest"], requiredTrend: nil),
        TextRule(directive: .sleepMore, titleKeywords: ["sleep debt"], recKeywords: ["bedtime alarm", "more sleep"], requiredTrend: nil),
        TextRule(directive: .sleepBetter, titleKeywords: ["sleep consistency", "bedtime"], recKeywords: ["consistent bedtime"], requiredTrend: nil),
        TextRule(directive: .increaseActivity, titleKeywords: ["workout consistency"], recKeywords: [], requiredTrend: .declining),
        TextRule(directive: .increaseActivity, titleKeywords: [], recKeywords: ["20-min walk", "20 min walk", "more active"], requiredTrend: nil),
        TextRule(directive: .pushHarder, titleKeywords: [], recKeywords: ["push harder", "increase intensity", "progressive overload"], requiredTrend: nil),
        TextRule(directive: .reduceIntensity, titleKeywords: [], recKeywords: ["lower intensity", "lighter sessions", "reduce intensity"], requiredTrend: nil),
    ]

    private static func cognitiveDirective(for insight: Insight) -> InsightDirective? {
        let title = insight.title.lowercased()
        if title.contains("mental fatigue") || title.contains("recovery day") { return .rest }
        if (title.contains("sleep debt") || title.contains("cognitive readiness")) && insight.trend == .declining { return .sleepMore }
        if title.contains("physical energy") { return .increaseActivity }
        return nil
    }

    // MARK: - Conflict Resolution

    private static func resolveConflicts(_ insights: [Insight]) -> [Insight] {
        var suppressed = Set<UUID>()

        // Build directive lookup
        let directiveMap: [UUID: InsightDirective] = Dictionary(
            uniqueKeysWithValues: insights.map { ($0.id, $0.directive) }
        )

        for insightA in insights {
            guard !suppressed.contains(insightA.id) else { continue }
            let directiveA = directiveMap[insightA.id] ?? .informational
            guard !directiveA.conflicts.isEmpty else { continue }

            for insightB in insights {
                guard insightA.id != insightB.id else { continue }
                guard !suppressed.contains(insightB.id) else { continue }
                let directiveB = directiveMap[insightB.id] ?? .informational
                guard directiveA.conflicts.contains(directiveB) else { continue }

                // Determine winner
                let aWins: Bool
                if directiveA.resolutionPriority != directiveB.resolutionPriority {
                    aWins = directiveA.resolutionPriority > directiveB.resolutionPriority
                } else if insightA.severity != insightB.severity {
                    aWins = insightA.severity > insightB.severity
                } else {
                    aWins = insightA.priorityScore >= insightB.priorityScore
                }

                suppressed.insert(aWins ? insightB.id : insightA.id)

                // If A lost, stop checking A against others
                if !aWins { break }
            }
        }

        return insights.filter { !suppressed.contains($0.id) }
    }

    // MARK: - Deduplication

    /// Remove duplicate insights about the same metric across all analyzers.
    /// Keeps max 2 per metric: best causal-chain + best other (by priority score).
    private static func deduplicateByMetric(_ insights: [Insight]) -> [Insight] {
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

            let causalChains = metricInsights.filter { $0.category == .causalChain }
            let others = metricInsights.filter { $0.category != .causalChain }

            // Keep the best causal chain if any
            if let bestCausal = causalChains.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestCausal)
            }

            // Keep the single best non-causal insight
            if let bestOther = others.max(by: { $0.priorityScore < $1.priorityScore }) {
                result.append(bestOther)
            }
        }

        return result
    }
}
