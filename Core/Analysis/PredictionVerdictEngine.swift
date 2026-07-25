import Foundation

// MARK: - Prediction input

/// Direction the metric is expected to move on the user's bad days.
enum PredictionDirection: String, Codable {
    case lower
    case higher
}

/// Metrics a pre-registered prediction can target. Deliberately small: only
/// metrics with an InsightConfig effect floor can be confirmed or refuted.
enum PredictionMetric: String, Codable, CaseIterable {
    /// Day value = minutes asleep per night.
    case sleepDuration
    /// Day value = mean SDNN in ms for that day.
    case heartRateVariability
    /// Day value = resting heart rate in bpm.
    case restingHeartRate

    /// Physiologically "worse" direction: less sleep and lower HRV are bad,
    /// higher resting heart rate is bad.
    var worseDirection: PredictionDirection {
        switch self {
        case .sleepDuration, .heartRateVariability: return .lower
        case .restingHeartRate: return .higher
        }
    }
}

/// The user's claim, fixed from their goal + symptom answers BEFORE any data
/// is examined, so the verdict can never be accused of curve fitting.
/// Codable so the cliffhanger branch can persist it until the data matures.
struct PreRegisteredPrediction: Codable {
    let metric: PredictionMetric
    let direction: PredictionDirection
    /// OnbV2Goal.rawValue. Stored as a string so Core never references
    /// onboarding module types.
    let userGoalKey: String?
    /// OnbV2Symptom.rawValue, same layering rule as userGoalKey.
    let userSymptomKey: String?
    /// The user's own words (their picked symptom or goal label), restated
    /// verbatim in verdict and re-permission copy.
    let userPhrase: String
}

// MARK: - Verdict output

enum VerdictZone: String {
    case confirmed
    case refuted
    case inconclusive
}

/// Rounded, banded effect size. Raw effects never leave the engine, so copy
/// cannot show false precision.
struct VerdictMagnitude: Equatable {
    enum Band: String {
        case minutes
        case roughlyAnHour
        case overAnHour
        case percent
        case bpm
    }

    let band: Band
    /// Display value already rounded to the band's grain. Hour bands keep the
    /// rounded minute count for analytics; their copy ignores it.
    let value: Int
}

/// A confirmed-level pattern found on a metric the user did NOT predict.
struct SideDiscovery: Equatable {
    let metric: PredictionMetric
    /// Calendar weekday convention, 1 = Sunday ... 7 = Saturday.
    let weekday: Int
}

struct PredictionVerdict {
    let zone: VerdictZone
    /// Weekday driving the confirmed pattern (1 = Sunday ... 7 = Saturday).
    let weekday: Int?
    /// Present only when confirmed.
    let magnitude: VerdictMagnitude?
    /// Nights of data still missing before the claim can mature. Computed as
    /// the GroupDifference bar minus distinct observed days, never a literal.
    /// nil once the data bar is met.
    let nightsRemaining: Int?
    let sideDiscoveries: [SideDiscovery]
}

/// Day-1 data richness, judged against the same InsightConfig bars the
/// verdict uses. Drives the onboarding router and analytics segmentation.
enum DataRichnessSegment: String {
    case rich
    case sparse
    /// HealthKit never reveals read denial, so "denied" is inferred from a
    /// snapshot with zero samples anywhere. A truly empty Health database is
    /// indistinguishable and lands here too, by design.
    case denied
}

// MARK: - Engine

/// Three-zone verdict on a pre-registered weekday-pattern prediction.
/// Takes plain day-level samples only — no HealthKit import, so it can be
/// driven by the onboarding snapshot, the health store, or tests alike.
struct PredictionVerdictEngine {

    /// `history` carries one series per metric; multiple samples on the same
    /// calendar day are collapsed to their mean before analysis.
    static func evaluate(
        prediction: PreRegisteredPrediction,
        history: [PredictionMetric: [MetricSample]]
    ) -> PredictionVerdict {
        let primary = analyzeGroupDifference(
            samples: dailyMeans(history[prediction.metric] ?? []),
            metric: prediction.metric,
            direction: prediction.direction
        )

        // Side discoveries: the same check on the metrics the user did not
        // predict, in each metric's physiologically worse direction.
        let sideDiscoveries: [SideDiscovery] = PredictionMetric.allCases
            .filter { $0 != prediction.metric }
            .compactMap { metric in
                let result = analyzeGroupDifference(
                    samples: dailyMeans(history[metric] ?? []),
                    metric: metric,
                    direction: metric.worseDirection
                )
                guard result.zone == .confirmed,
                      let weekday = result.weekday,
                      result.magnitude != nil else { return nil }
                return SideDiscovery(metric: metric, weekday: weekday)
            }

        return PredictionVerdict(
            zone: primary.zone,
            weekday: primary.weekday,
            magnitude: primary.magnitude,
            nightsRemaining: primary.nightsRemaining,
            sideDiscoveries: sideDiscoveries
        )
    }

    /// Router segment: rich when the predicted metric meets the
    /// GroupDifference data bar, sparse when granted but below it, denied
    /// when there is no health data at all (see DataRichnessSegment.denied).
    static func segment(
        prediction: PreRegisteredPrediction,
        history: [PredictionMetric: [MetricSample]],
        hasAnyHealthData: Bool
    ) -> DataRichnessSegment {
        guard hasAnyHealthData else { return .denied }
        let days = dailyMeans(history[prediction.metric] ?? [])
        return meetsGroupDifferenceBar(days) ? .rich : .sparse
    }

    // MARK: - Group-difference analysis

    private struct GroupDifferenceResult {
        let zone: VerdictZone
        let weekday: Int?
        let magnitude: VerdictMagnitude?
        let nightsRemaining: Int?
    }

    private static func analyzeGroupDifference(
        samples: [MetricSample],
        metric: PredictionMetric,
        direction: PredictionDirection
    ) -> GroupDifferenceResult {
        let distinctDays = samples.count
        let missing = InsightConfig.GroupDifference.minSamples - distinctDays
        let nightsRemaining = missing > 0 ? missing : nil

        var byWeekday: [Int: [Double]] = [:]
        for sample in samples {
            byWeekday[Date.cal.component(.weekday, from: sample.date), default: []].append(sample.value)
        }
        let covered = byWeekday.filter { $0.value.count >= InsightConfig.GroupDifference.minSamplesPerWeekday }
        let barMet = distinctDays >= InsightConfig.GroupDifference.minSamples
            && covered.count >= InsightConfig.GroupDifference.minWeekdaysCovered

        let overallMean = samples.valueMean
        guard barMet, overallMean > 0 else {
            return GroupDifferenceResult(zone: .inconclusive, weekday: nil, magnitude: nil, nightsRemaining: nightsRemaining)
        }

        let weekdayMeans = covered.mapValues { $0.reduce(0, +) / Double($0.count) }
        // Split out of a ternary: the two min/max closures in one ?: expression
        // make Swift's type-checker time out (diagnostic at this site).
        let target: (key: Int, value: Double)?
        switch direction {
        case .lower: target = weekdayMeans.min { $0.value < $1.value }
        case .higher: target = weekdayMeans.max { $0.value < $1.value }
        }
        guard let target else {
            return GroupDifferenceResult(zone: .inconclusive, weekday: nil, magnitude: nil, nightsRemaining: nightsRemaining)
        }

        // Effect in the predicted direction, expressed in the metric's floor
        // units (minutes, percent of mean, bpm).
        let rawGap = direction == .lower ? overallMean - target.value : target.value - overallMean
        let effect: Double
        let floor: Double
        switch metric {
        case .sleepDuration:
            effect = rawGap
            floor = InsightConfig.GroupDifference.sleepFloorMinutes
        case .heartRateVariability:
            effect = rawGap / overallMean * 100
            floor = InsightConfig.GroupDifference.hrvFloorPercent
        case .restingHeartRate:
            effect = rawGap
            floor = InsightConfig.GroupDifference.rhrFloorBpm
        }

        if effect >= floor {
            let consistent = !InsightConfig.GroupDifference.requireMajorityWeeksConsistency
                || majorityOfWeeksHold(samples: samples, targetWeekday: target.key, direction: direction)
            if consistent {
                return GroupDifferenceResult(
                    zone: .confirmed,
                    weekday: target.key,
                    magnitude: magnitude(for: effect, metric: metric),
                    nightsRemaining: nil
                )
            }
            return GroupDifferenceResult(zone: .inconclusive, weekday: nil, magnitude: nil, nightsRemaining: nil)
        }

        // Evidence of absence needs more density than evidence of presence,
        // and the effect must sit clearly under the floor — between the two
        // bounds the honest answer is inconclusive.
        if distinctDays >= InsightConfig.Refutation.refuteDensityDays,
           effect < floor * InsightConfig.Refutation.refuteEffectFraction {
            return GroupDifferenceResult(zone: .refuted, weekday: nil, magnitude: nil, nightsRemaining: nil)
        }

        return GroupDifferenceResult(zone: .inconclusive, weekday: nil, magnitude: nil, nightsRemaining: nightsRemaining)
    }

    private static func meetsGroupDifferenceBar(_ samples: [MetricSample]) -> Bool {
        guard samples.count >= InsightConfig.GroupDifference.minSamples else { return false }
        var weekdayCounts: [Int: Int] = [:]
        for sample in samples {
            weekdayCounts[Date.cal.component(.weekday, from: sample.date), default: 0] += 1
        }
        let covered = weekdayCounts.values.filter { $0 >= InsightConfig.GroupDifference.minSamplesPerWeekday }
        return covered.count >= InsightConfig.GroupDifference.minWeekdaysCovered
    }

    /// True when, in more than half of the weeks containing both the target
    /// weekday and at least one other day, the target weekday sits on the
    /// predicted side of that week's other-day mean.
    private static func majorityOfWeeksHold(
        samples: [MetricSample],
        targetWeekday: Int,
        direction: PredictionDirection
    ) -> Bool {
        var byWeek: [Date: [MetricSample]] = [:]
        for sample in samples {
            let comps = Date.cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: sample.date)
            guard let weekStart = Date.cal.date(from: comps) else { continue }
            byWeek[weekStart, default: []].append(sample)
        }

        var coveredWeeks = 0
        var holdingWeeks = 0
        for (_, weekSamples) in byWeek {
            let targetValues = weekSamples
                .filter { Date.cal.component(.weekday, from: $0.date) == targetWeekday }
                .map(\.value)
            let otherValues = weekSamples
                .filter { Date.cal.component(.weekday, from: $0.date) != targetWeekday }
                .map(\.value)
            guard !targetValues.isEmpty, !otherValues.isEmpty else { continue }

            coveredWeeks += 1
            let targetMean = targetValues.reduce(0, +) / Double(targetValues.count)
            let othersMean = otherValues.reduce(0, +) / Double(otherValues.count)
            let holds = direction == .lower ? targetMean < othersMean : targetMean > othersMean
            if holds { holdingWeeks += 1 }
        }

        guard coveredWeeks > 0 else { return false }
        return Double(holdingWeeks) > Double(coveredWeeks) / 2
    }

    // MARK: - Magnitude banding

    private static func magnitude(for effect: Double, metric: PredictionMetric) -> VerdictMagnitude {
        switch metric {
        case .sleepDuration:
            let grain = InsightConfig.Banding.minutesRoundingGrain
            let rounded = (effect / grain).rounded() * grain
            if rounded > InsightConfig.Banding.roughlyAnHourUpperMinutes {
                return VerdictMagnitude(band: .overAnHour, value: Int(rounded))
            }
            if rounded >= InsightConfig.Banding.roughlyAnHourLowerMinutes {
                return VerdictMagnitude(band: .roughlyAnHour, value: Int(rounded))
            }
            return VerdictMagnitude(band: .minutes, value: Int(rounded))
        case .heartRateVariability:
            return VerdictMagnitude(band: .percent, value: Int(effect.rounded()))
        case .restingHeartRate:
            return VerdictMagnitude(band: .bpm, value: Int(effect.rounded()))
        }
    }

    // MARK: - Input normalization

    /// Collapses arbitrary samples to one mean value per calendar day so
    /// density counts and weekday groups are day-based, not sample-based.
    private static func dailyMeans(_ samples: [MetricSample]) -> [MetricSample] {
        guard !samples.isEmpty else { return [] }
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            byDay[Date.cal.startOfDay(for: sample.date), default: []].append(sample.value)
        }
        return byDay
            .map { day, values in
                MetricSample(date: day, value: values.reduce(0, +) / Double(values.count))
            }
            .sorted { $0.date < $1.date }
    }
}
