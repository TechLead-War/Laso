import Foundation

/// Evaluates whether recommendations led to measurable improvement
enum RecommendationEvaluator {

    enum Outcome: String {
        case improved
        case stable
        case worsened
    }

    /// Evaluate all pending recommendations against actual metric data
    @MainActor
    static func evaluatePending(store: HealthDataStore, timeSeries: [HealthMetric: MetricTimeSeries]) {
        let pending = store.loadPendingRecommendations()
        let now = Date()

        for rec in pending {
            guard let metric = HealthMetric(rawValue: rec.metricRawValue) else { continue }
            guard let series = timeSeries[metric] else { continue }

            // 24-hour evaluation
            if !rec.evaluated24h {
                let elapsed = now.timeIntervalSince(rec.shownDate)
                guard elapsed >= 86_400 else { continue } // 24h
                let end24h = rec.shownDate.addingTimeInterval(86_400)
                let samples = series.samples(from: rec.shownDate, to: end24h)
                if !samples.isEmpty {
                    let avg = samples.valueMean
                    let lift = rec.baselineValue != 0 ? ((avg - rec.baselineValue) / rec.baselineValue) * 100 : 0
                    rec.lift24h = lift
                    rec.evaluated24h = true
                }
            }

            // 7-day evaluation
            if !rec.evaluated7d {
                let elapsed = now.timeIntervalSince(rec.shownDate)
                guard elapsed >= 604_800 else { continue } // 7 days
                let end7d = rec.shownDate.addingTimeInterval(604_800)
                let samples = series.samples(from: rec.shownDate, to: end7d)
                if !samples.isEmpty {
                    let avg = samples.valueMean
                    let lift = rec.baselineValue != 0 ? ((avg - rec.baselineValue) / rec.baselineValue) * 100 : 0
                    rec.lift7d = lift
                    rec.evaluated7d = true

                    let outcome = classifyOutcome(lift: lift, metric: metric)
                    rec.outcomeRawValue = outcome.rawValue

                    AppAnalytics.shared.trackRecommendationOutcome(
                        category: rec.categoryRawValue,
                        metric: rec.metricRawValue,
                        severity: rec.severityRawValue,
                        lift24h: rec.lift24h,
                        lift7d: lift,
                        wasTapped: rec.tappedDate != nil,
                        outcome: outcome.rawValue
                    )
                }
            }
        }
    }

    /// Classify whether a lift represents improvement based on metric direction
    static func classifyOutcome(lift: Double, metric: HealthMetric) -> Outcome {
        let effectiveLift = metric.higherIsBetter ? lift : -lift
        if effectiveLift > 2 { return .improved }
        if effectiveLift < -2 { return .worsened }
        return .stable
    }

    /// Win rate: % of fully evaluated recommendations that improved (needs >= 5)
    @MainActor
    static func computeWinRate(store: HealthDataStore) -> Double? {
        let evaluated = store.loadEvaluatedRecommendations(days: 90)
        guard evaluated.count >= 5 else { return nil }
        let improved = evaluated.filter { $0.outcomeRawValue == Outcome.improved.rawValue }.count
        return Double(improved) / Double(evaluated.count)
    }

    /// Confidence tier for a generated proof. The view layer can use this to
    /// adjust copy emphasis or to hide proof that is still too thin to trust.
    enum ConfidenceTier: String {
        case high
        case medium
        case exploratory
    }

    /// Summary of "proof" copy shown on home action cards and their detail view.
    /// `hasProof` gates whether the view renders the grounded summary or falls
    /// back to the "still learning" copy.
    struct ActionProofSummary {
        var hasProof: Bool = false
        var cardProofLine: String? = nil
        var detailProofLine: String? = nil
        var timeframeLine: String = ""
        var confidence: ConfidenceTier = .exploratory
        /// The metric the proof is anchored to (if any). Useful for deep links
        /// from the card into the metric detail view.
        var anchorMetric: HealthMetric? = nil
        /// Raw counts the copy is derived from, surfaced for analytics and
        /// debug overlays so we never display numbers we cannot trace back.
        var improvedCount: Int = 0
        var totalCount: Int = 0
        var observationWindowDays: Int = 0
    }

    /// Minimum evaluated recommendations required before we show any proof.
    /// Smaller samples produce noisy percentages, so we stay silent instead.
    private static let minimumSampleSize = 5

    /// Observation window used to aggregate evaluated recommendations. Matches
    /// the pruning window in `HealthDataStore.pruneOldRecommendations` (60d)
    /// but keeps the surface short so copy feels recent.
    private static let observationWindowDays = 30

    /// Build an evidence summary from the user's own evaluation history.
    ///
    /// This looks at recommendations that were shown, measured 7 days later,
    /// and classified as improved / stable / worsened by `evaluate7d`. Because
    /// the `StoredRecommendation` model is the only place where "followed
    /// advice -> measured outcome" is grounded in real data, we source proof
    /// exclusively from there. No metric is fabricated.
    ///
    /// Returns an `ActionProofSummary` with `hasProof == false` when the user
    /// does not yet have enough evaluated history. Callers render the
    /// "still learning" copy in that case.
    @MainActor
    static func buildActionProof(store: HealthDataStore) -> ActionProofSummary {
        let evaluated = store.loadEvaluatedRecommendations(days: observationWindowDays)

        // Minimum-sample-size guard: keep quiet until we have real history.
        guard evaluated.count >= minimumSampleSize else {
            return ActionProofSummary(
                hasProof: false,
                cardProofLine: nil,
                detailProofLine: nil,
                timeframeLine: "",
                confidence: .exploratory,
                anchorMetric: nil,
                improvedCount: 0,
                totalCount: evaluated.count,
                observationWindowDays: observationWindowDays
            )
        }

        // Group by metric so we can anchor the proof to the strongest signal
        // (the metric with the most measured improvements).
        var improvedByMetric: [HealthMetric: Int] = [:]
        var totalByMetric: [HealthMetric: Int] = [:]
        for rec in evaluated {
            guard let metric = HealthMetric(rawValue: rec.metricRawValue) else { continue }
            totalByMetric[metric, default: 0] += 1
            if rec.outcomeRawValue == Outcome.improved.rawValue {
                improvedByMetric[metric, default: 0] += 1
            }
        }

        // Pick the metric with the highest improved count, tie-breaking on
        // total samples so we prefer well-sampled metrics.
        let ranked = totalByMetric.keys.sorted { lhs, rhs in
            let lImproved = improvedByMetric[lhs, default: 0]
            let rImproved = improvedByMetric[rhs, default: 0]
            if lImproved != rImproved { return lImproved > rImproved }
            return totalByMetric[lhs, default: 0] > totalByMetric[rhs, default: 0]
        }

        guard let anchor = ranked.first else {
            return ActionProofSummary(
                hasProof: false,
                confidence: .exploratory,
                totalCount: evaluated.count,
                observationWindowDays: observationWindowDays
            )
        }

        let improved = improvedByMetric[anchor, default: 0]
        let total = totalByMetric[anchor, default: 0]
        let metricName = anchor.displayName

        // Confidence tiers: we need at least 3 measured improvements on the
        // same metric before we call the proof "medium" confidence, and a
        // meaningful win rate plus enough samples to call it "high".
        let winRate = total > 0 ? Double(improved) / Double(total) : 0
        let confidence: ConfidenceTier
        if improved >= 5 && winRate >= 0.6 && total >= 7 {
            confidence = .high
        } else if improved >= 3 && winRate >= 0.5 {
            confidence = .medium
        } else {
            confidence = .exploratory
        }

        // If the anchor metric has fewer than 3 improvements we don't have
        // enough grounded evidence to make a specific claim. Fall back to a
        // neutral card line that only references the overall sample size.
        guard improved >= 3 else {
            return ActionProofSummary(
                hasProof: false,
                cardProofLine: nil,
                detailProofLine: nil,
                timeframeLine: Copy.Home.ActionProof.trackingWindow(days: observationWindowDays),
                confidence: .exploratory,
                anchorMetric: anchor,
                improvedCount: improved,
                totalCount: total,
                observationWindowDays: observationWindowDays
            )
        }

        let cardLine = Copy.Home.ActionProof.followedAdviceImproved(
            count: improved,
            metric: metricName
        )
        let detailLine = Copy.Home.ActionProof.pastOutcomeSummary(
            improved: improved,
            total: total,
            metric: metricName
        )
        let timeframe = Copy.Home.ActionProof.trackingWindow(days: observationWindowDays)

        return ActionProofSummary(
            hasProof: true,
            cardProofLine: cardLine,
            detailProofLine: detailLine,
            timeframeLine: timeframe,
            confidence: confidence,
            anchorMetric: anchor,
            improvedCount: improved,
            totalCount: total,
            observationWindowDays: observationWindowDays
        )
    }
}
