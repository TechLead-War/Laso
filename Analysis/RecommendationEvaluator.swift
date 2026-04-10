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
}
