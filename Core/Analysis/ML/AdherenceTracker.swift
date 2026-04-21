import Foundation

/// Closed-loop learning: tracks if advice was followed, measures outcomes, learns effectiveness.
/// 8th ML component in the orchestrator.
final class AdherenceTracker {

    /// Minimum evaluated records before providing effectiveness multipliers
    static let minimumEvaluated = 15

    /// Per-category effectiveness scores (EMA, α=0.1)
    private var categoryEffectiveness: [String: Double] = [:]
    /// Total evaluated records count
    private var evaluatedCount: Int = 0

    private let emaAlpha = 0.1

    var isReady: Bool { evaluatedCount >= Self.minimumEvaluated }

    // MARK: - Record Advice

    /// Extract top actionable insights and create pending adherence records.
    /// Returns records to be saved to SwiftData.
    func recordAdvice(from insights: [Insight]) -> [StoredAdherenceRecord] {
        let actionable = insights
            .filter { $0.severity >= .warning }
            .sorted { $0.priorityScore > $1.priorityScore }
            .prefix(5)

        return actionable.map { insight in
            let direction: TargetDirection
            if insight.trend == .declining {
                direction = insight.metric.higherIsBetter ? .increase : .decrease
            } else if insight.trend == .improving {
                direction = .maintain
            } else {
                direction = insight.metric.higherIsBetter ? .increase : .decrease
            }

            return StoredAdherenceRecord(
                insightCategory: insight.category,
                insightTitle: insight.title,
                recommendation: insight.recommendation,
                targetMetric: insight.metric,
                targetDirection: direction,
                severity: insight.severity,
                givenDate: insight.generatedAt
            )
        }
    }

    // MARK: - Measure Outcomes

    /// Evaluate pending records: did metric move in advised direction? Did score improve?
    /// Modifies records in place.
    func measureOutcomes(
        pendingRecords: [StoredAdherenceRecord],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        scoreHistory: [(date: Date, score: Int)]
    ) {
        let calendar = Calendar.current

        for record in pendingRecords {
            guard record.isReadyForEvaluation,
                  let metric = record.targetMetric,
                  let direction = record.targetDirection,
                  let series = timeSeries[metric] else { continue }

            let givenDay = calendar.startOfDay(for: record.givenDate)
            let samples = series.sortedSamples

            // Get value on the day advice was given
            let beforeValue = samples.last(where: {
                calendar.startOfDay(for: $0.date) <= givenDay
            })?.value

            // Get most recent value (1-3 days later)
            let afterValue = samples.last?.value

            guard let before = beforeValue, let after = afterValue else { continue }

            let delta = after - before
            record.metricDelta = delta

            // Adherence: did the metric move in the advised direction?
            let adherence: Double
            switch direction {
            case .increase:
                adherence = delta > 0 ? min(1.0, delta / max(1, abs(before) * 0.05)) : 0
            case .decrease:
                adherence = delta < 0 ? min(1.0, abs(delta) / max(1, abs(before) * 0.05)) : 0
            case .maintain:
                let baseline = baselines[metric]
                let sd = baseline?.standardDeviation ?? abs(before) * 0.1
                adherence = abs(delta) < sd ? 1.0 : max(0, 1.0 - abs(delta) / sd)
            }
            record.adherenceScore = adherence

            // Outcome: did overall score improve?
            let scoreLookup = Dictionary(scoreHistory.map {
                (calendar.startOfDay(for: $0.date), $0.score)
            }, uniquingKeysWith: { _, last in last })

            let scoreBefore = scoreLookup[givenDay]
            let scoreAfter = scoreLookup[calendar.startOfDay(for: Date())]

            if let sb = scoreBefore, let sa = scoreAfter {
                record.outcomeScore = sa > sb ? 1.0 : sa == sb ? 0.5 : 0.0
            } else {
                record.outcomeScore = 0.5  // neutral if no score data
            }

            record.measuredDate = Date()
        }
    }

    // MARK: - Train

    /// Update per-category effectiveness using EMA from evaluated records.
    func train(evaluatedRecords: [StoredAdherenceRecord]) {
        for record in evaluatedRecords {
            guard record.isEvaluated,
                  let category = record.insightCategory,
                  let adherence = record.adherenceScore,
                  let outcome = record.outcomeScore else { continue }

            let effectiveness = (adherence * 0.4 + outcome * 0.6) // Weighted combo

            let key = category.rawValue
            if let existing = categoryEffectiveness[key] {
                categoryEffectiveness[key] = existing * (1 - emaAlpha) + effectiveness * emaAlpha
            } else {
                categoryEffectiveness[key] = effectiveness
            }

            evaluatedCount += 1
        }
    }

    // MARK: - Effectiveness Multiplier

    /// Returns a multiplier (0.5-2.0) to boost/demote insight priorities by category.
    func effectivenessMultiplier(for category: InsightCategory) -> Double {
        guard isReady else { return 1.0 }
        guard let effectiveness = categoryEffectiveness[category.rawValue] else { return 1.0 }
        // Map [0, 1] effectiveness to [0.5, 2.0] multiplier
        // 0.0 → 0.5 (demote), 0.5 → 1.0 (neutral), 1.0 → 2.0 (boost)
        return 0.5 + effectiveness * 1.5
    }

    // MARK: - Persistence

    struct Parameters: Codable {
        let categoryEffectiveness: [String: Double]
        let evaluatedCount: Int
    }

    func getParameters() -> Parameters {
        Parameters(categoryEffectiveness: categoryEffectiveness, evaluatedCount: evaluatedCount)
    }

    func restoreParameters(_ params: Parameters) {
        categoryEffectiveness = params.categoryEffectiveness
        evaluatedCount = params.evaluatedCount
    }
}
