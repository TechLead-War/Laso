import Foundation

/// Orchestrates insights from all analyzers to produce a coherent, non-contradictory set.
///
/// The coordinator solves the core problem: 20+ independent analyzers each producing
/// advice that can directly contradict each other. For example, RecoveryAnalyzer says
/// "take a rest day" while WorkoutEffectivenessAnalyzer says "exercise more consistently."
///
/// Resolution strategy:
/// 1. Infer behavioral directives for insights that don't have one explicitly set
/// 2. Detect conflicting directive pairs (rest vs exercise, reduce vs push harder)
/// 3. Resolve conflicts: safety > performance, higher severity wins, then evidence depth
/// 4. Deduplicate: max 2 insights per metric (best causal chain + best other)
/// 5. Cap total count to avoid overwhelming the user
struct InsightCoordinator {

    /// Maximum insights shown to the user after coordination
    private static let maxInsights = 15

    // MARK: - Public API

    /// Coordinate a set of insights: infer directives, resolve contradictions, deduplicate.
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

    /// Infer what behavioral direction an insight pushes the user toward.
    /// Uses category, title, recommendation text, severity, and trend as signals.
    static func inferDirective(for insight: Insight) -> InsightDirective {
        // Fast paths by category
        switch insight.category {
        case .illnessWarning:
            return .rest
        case .clinicalTrajectory:
            return insight.severity >= .warning ? .seekMedical : .informational
        case .personalRecord:
            return .maintain
        case .cyclePhase:
            return .informational
        default:
            break
        }

        let title = insight.title.lowercased()
        let rec = insight.recommendation.lowercased()

        // Medical — always check first
        if rec.contains("consult") || rec.contains("healthcare provider") || rec.contains("doctor") {
            return .seekMedical
        }

        // Recovery / rest (check before exercise — "rest day" is unambiguous)
        if title.contains("overtraining") || title.contains("rest day") ||
            title.contains("recovery day") || title.contains("rest deficit") ||
            rec.contains("rest day") || rec.contains("genuine rest") {
            return .rest
        }

        // Multi-metric compound decline → rest
        if insight.category == .multiMetricCluster && insight.severity >= .warning {
            return .rest
        }

        // Recovery category warnings → rest
        if insight.category == .recovery && insight.severity >= .warning {
            return .rest
        }

        // Cognitive/energy sub-types
        if insight.category == .cognitiveEnergy {
            if title.contains("mental fatigue") || title.contains("recovery day") { return .rest }
            if title.contains("sleep debt") || title.contains("cognitive readiness") && insight.trend == .declining {
                return .sleepMore
            }
            if title.contains("physical energy") { return .increaseActivity }
        }

        // Sleep directives
        if title.contains("sleep debt") || (rec.contains("extend") && rec.contains("sleep")) ||
            rec.contains("bedtime alarm") || rec.contains("more sleep") ||
            (rec.contains("extra hour") && rec.contains("sleep")) {
            return .sleepMore
        }
        if title.contains("sleep consistency") || rec.contains("consistent bedtime") ||
            title.contains("bedtime") {
            return .sleepBetter
        }

        // Activity push
        if title.contains("workout consistency") && insight.trend == .declining {
            return .increaseActivity
        }
        if rec.contains("20-min walk") || rec.contains("20 min walk") || rec.contains("more active") {
            return .increaseActivity
        }

        // Intensity directives
        if rec.contains("push harder") || rec.contains("increase intensity") ||
            rec.contains("progressive overload") {
            return .pushHarder
        }
        if rec.contains("lower intensity") || rec.contains("lighter sessions") ||
            rec.contains("reduce intensity") {
            return .reduceIntensity
        }

        // Improving trend info → maintain
        if insight.trend == .improving && insight.severity == .info {
            return .maintain
        }

        return .informational
    }

    // MARK: - Conflict Resolution

    /// Resolve contradicting insights by suppressing the lower-priority side.
    ///
    /// Rules:
    /// - Only resolves when at least one side is warning+ severity (info vs info coexist)
    /// - Directive resolution priority determines the winner (safety > performance)
    /// - Within the same priority, higher severity wins
    /// - Within the same severity, higher priorityScore wins
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

                // Only resolve if at least one is warning+
                guard insightA.severity >= .warning || insightB.severity >= .warning else { continue }

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
