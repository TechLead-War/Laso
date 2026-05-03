import Foundation

/// Discovers temporal sequences. multi-step causal chains that unfold over days.
/// Finds precursor patterns, compounding effects, and recovery sequences that users
/// cannot figure out on their own from raw data.
final class TemporalSequenceMiner {

    /// Minimum days of data required for meaningful sequence mining
    static let minimumDays = 14

    // MARK: - Result Types

    /// A multi-step temporal sequence where event A leads to event B (and optionally C) over days
    struct TemporalSequence {
        let steps: [SequenceStep]
        let totalOccurrences: Int
        let avgConsequenceMagnitude: Double
        let confidence: Double
        let description: String
        let isCurrentlyActive: Bool
        let currentStepIndex: Int?
        let predictedOutcome: String?
        let discoveredAt: Date

        struct SequenceStep {
            let metric: HealthMetric
            let condition: StepCondition
            let dayOffset: Int
            let avgValue: Double
            let threshold: Double
        }

        enum StepCondition: String {
            case below
            case above
            case declining
            case spiking
            case sustained
        }
    }

    /// A compounding effect where consecutive days of a condition worsen a consequence metric
    struct CompoundingEffect {
        let metric: HealthMetric
        let condition: String
        let compoundingRate: Double
        let maxObservedStreak: Int
        let avgConsequence: [ConsequenceMetric]
        let description: String

        struct ConsequenceMetric {
            let metric: HealthMetric
            let avgDeltaPerDay: Double
            let peakImpactDay: Int
        }
    }

    /// A precursor warning pattern that reliably precedes bad health events
    struct PrecursorPattern {
        let warningSignals: [(metric: HealthMetric, direction: String, leadDays: Int)]
        let predictedEvent: String
        let historicalAccuracy: Double
        let occurrenceCount: Int
        let description: String
        let isCurrentlyTriggered: Bool
    }

    /// A recovery sequence tracking how metrics bounce back after a bad event
    struct RecoveryProfile {
        let triggerEvent: String
        let metricRecoveries: [MetricRecovery]
        let avgTotalRecoveryDays: Int
        let accelerators: [String]
        let description: String

        struct MetricRecovery {
            let metric: HealthMetric
            let avgRecoveryDays: Int
            let avgDepthOfDip: Double
        }
    }

    // MARK: - Public Properties

    private(set) var sequences: [TemporalSequence] = []
    private(set) var compoundingEffects: [CompoundingEffect] = []
    private(set) var precursorPatterns: [PrecursorPattern] = []
    private(set) var recoveryProfiles: [RecoveryProfile] = []

    var isReady: Bool { !sequences.isEmpty || !compoundingEffects.isEmpty || !precursorPatterns.isEmpty }

    /// Hash of input data from last run. Skip recomputation if unchanged.
    private var lastInputHash: Int = 0

    // MARK: - Internal State

    /// Metrics most likely to participate in cross-metric sequences
    private static let coreMetrics: [HealthMetric] = [
        .sleepDuration, .heartRateVariability, .restingHeartRate,
        .steps, .activeCalories, .exerciseMinutes,
        .sleepDeep, .sleepREM, .heartRate, .vo2Max, .bloodOxygen
    ]

    /// Pairs known to have physiological temporal relationships
    private static let causalPairs: [(cause: HealthMetric, effect: HealthMetric)] = [
        (.sleepDuration, .heartRateVariability),
        (.sleepDuration, .restingHeartRate),
        (.sleepDuration, .activeCalories),
        (.activeCalories, .heartRateVariability),
        (.activeCalories, .restingHeartRate),
        (.activeCalories, .sleepDuration),
        (.exerciseMinutes, .heartRateVariability),
        (.exerciseMinutes, .restingHeartRate),
        (.exerciseMinutes, .sleepDeep),
        (.steps, .sleepDuration),
        (.steps, .heartRateVariability),
        (.heartRateVariability, .restingHeartRate),
        (.sleepDeep, .heartRateVariability),
        (.sleepREM, .heartRateVariability),
    ]

    private let calendar = Date.cal
    /// Minimum support: sequence must occur at least this many times
    private let minSupport = 3
    /// Maximum lag between steps in a sequence (days)
    private let maxStepLag = 7

    // MARK: - Main Entry

    /// Discover all temporal sequences from time series data.
    /// - Parameters:
    ///   - timeSeries: Per-metric time series with daily samples
    ///   - baselines: Per-metric user baselines (mean, stddev)
    ///   - stateHistory: HMM-smoothed state history (optional, for precursor detection)
    func mine(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        stateHistory: [SmoothedHealthState] = []
    ) {
        // Skip if input data hasn't changed since last run
        let inputHash = computeInputHash(timeSeries: timeSeries)
        if inputHash == lastInputHash && isReady { return }
        lastInputHash = inputHash

        // Filter to metrics with sufficient data
        let available = timeSeries.filter { $0.value.sortedSamples.count >= Self.minimumDays }
        guard !available.isEmpty else { return }

        // Build date-aligned daily value lookup for all metrics
        let dailyValues = buildDailyLookup(timeSeries: available)
        guard dailyValues.count >= Self.minimumDays else { return }

        let sortedDates = dailyValues.keys.sorted()

        // 1. Mine sequential patterns (2-step and 3-step)
        let mined = mineSequentialPatterns(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines,
            available: available
        )
        sequences = mined

        // Bail out if device reaches critical thermal state between steps
        guard ProcessInfo.processInfo.thermalState != .critical else { return }

        // 2. Compounding effects skipped — compoundingEffects stored on MLOrchestrator
        // but never read by any ViewModel, View, or downstream system.
        compoundingEffects = []

        // 3. Detect precursor patterns
        precursorPatterns = detectPrecursorPatterns(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines,
            stateHistory: stateHistory
        )

        // Bail out if device reaches critical thermal state between steps
        guard ProcessInfo.processInfo.thermalState != .critical else { return }

        // 4. Detect recovery sequences
        recoveryProfiles = detectRecoverySequences(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines
        )
    }

    // MARK: - Daily Lookup Builder

    /// Build a date-indexed lookup of metric values: [Date: [HealthMetric: Double]]
    private func buildDailyLookup(
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> [Date: [HealthMetric: Double]] {
        var lookup: [Date: [HealthMetric: Double]] = [:]

        for (metric, series) in timeSeries {
            // Use TimeSeriesAligner for optimized, O(N) grouping without repetitive Calendar calls
            let dailyMap = TimeSeriesAligner.dailyValueMap(series)
            for (day, value) in dailyMap {
                lookup[day, default: [:]][metric] = value
            }
        }

        return lookup
    }

    // MARK: - Sequential Pattern Mining

    /// Identify "events" (deviations > 1 sigma from baseline) and find cross-metric sequences.
    private func mineSequentialPatterns(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline],
        available: [HealthMetric: MetricTimeSeries]
    ) -> [TemporalSequence] {
        // Step 1: Identify events per metric per day
        let events = identifyEvents(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines,
            available: available
        )

        var results: [TemporalSequence] = []

        // Step 2: Find 2-step sequences across all causal pairs
        let pairsToTest = buildPairsToTest(available: available)

        for (causeMetric, effectMetric) in pairsToTest {
            guard let causeEvents = events[causeMetric],
                  let effectEvents = events[effectMetric] else { continue }

            if let seq = find2StepSequence(
                causeMetric: causeMetric,
                effectMetric: effectMetric,
                causeEvents: causeEvents,
                effectEvents: effectEvents,
                sortedDates: sortedDates,
                dailyValues: dailyValues,
                baselines: baselines
            ) {
                results.append(seq)
            }
        }

        // Step 3: Extend to 3-step sequences from strong 2-step pairs
        let strong2Step = results.filter { $0.totalOccurrences >= minSupport + 1 && $0.confidence > 0.5 }
        for twoStep in strong2Step {
            guard twoStep.steps.count == 2 else { continue }
            let secondMetric = twoStep.steps[1].metric

            // Try extending: find a third metric that follows the second
            for (_, effectMetric) in pairsToTest where effectMetric != twoStep.steps[0].metric && effectMetric != secondMetric {
                guard let effectEvents = events[effectMetric],
                      let midEvents = events[secondMetric] else { continue }

                if let threeStep = find3StepSequence(
                    baseSequence: twoStep,
                    thirdMetric: effectMetric,
                    midEvents: midEvents,
                    thirdEvents: effectEvents,
                    sortedDates: sortedDates,
                    dailyValues: dailyValues,
                    baselines: baselines
                ) {
                    results.append(threeStep)
                }
            }
        }

        // Sort by confidence * occurrences (most reliable first)
        return results.sorted { ($0.confidence * Double($0.totalOccurrences)) > ($1.confidence * Double($1.totalOccurrences)) }
    }

    /// Build pairs of metrics to test. Prefer known causal pairs, then add all available pairs.
    private func buildPairsToTest(
        available: [HealthMetric: MetricTimeSeries]
    ) -> [(cause: HealthMetric, effect: HealthMetric)] {
        var pairs: [(HealthMetric, HealthMetric)] = []
        var seen = Set<String>()

        // Add known causal pairs first (if both metrics available)
        for pair in Self.causalPairs {
            guard available[pair.cause] != nil, available[pair.effect] != nil else { continue }
            let key = "\(pair.cause.rawValue)->\(pair.effect.rawValue)"
            if seen.insert(key).inserted {
                pairs.append(pair)
            }
        }

        // Add remaining core metric pairs not already covered
        let availableCoreMetrics = Self.coreMetrics.filter { available[$0] != nil }
        for i in 0..<availableCoreMetrics.count {
            for j in 0..<availableCoreMetrics.count where i != j {
                let key = "\(availableCoreMetrics[i].rawValue)->\(availableCoreMetrics[j].rawValue)"
                if seen.insert(key).inserted {
                    pairs.append((availableCoreMetrics[i], availableCoreMetrics[j]))
                }
            }
        }

        return pairs
    }

    // MARK: - Event Identification

    /// An event: a day where a metric deviates significantly from baseline
    private struct MetricEvent {
        let date: Date
        let metric: HealthMetric
        let value: Double
        let deviation: Double        // signed: positive = above baseline, negative = below
        let deviationSigma: Double   // in units of standard deviations
        let direction: EventDirection
    }

    private enum EventDirection {
        case high   // above baseline + 1 sigma
        case low    // below baseline - 1 sigma
    }

    /// Identify days where each metric deviates > 1 sigma from baseline.
    private func identifyEvents(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline],
        available: [HealthMetric: MetricTimeSeries]
    ) -> [HealthMetric: [MetricEvent]] {
        var events: [HealthMetric: [MetricEvent]] = [:]

        for metric in available.keys {
            // Derive threshold from baseline or from time series stats
            let mean: Double
            let sd: Double
            if let baseline = baselines[metric], baseline.standardDeviation > 0 {
                mean = baseline.mean
                sd = baseline.standardDeviation
            } else if let series = available[metric] {
                mean = series.mean
                sd = series.standardDeviation
                guard sd > 0 else { continue }
            } else {
                continue
            }
            guard sd > 0 else { continue }

            var metricEvents: [MetricEvent] = []
            for date in sortedDates {
                guard let value = dailyValues[date]?[metric] else { continue }
                let deviation = value - mean
                let sigma = deviation / sd

                if sigma > 1.0 {
                    metricEvents.append(MetricEvent(
                        date: date, metric: metric, value: value,
                        deviation: deviation, deviationSigma: sigma, direction: .high
                    ))
                } else if sigma < -1.0 {
                    metricEvents.append(MetricEvent(
                        date: date, metric: metric, value: value,
                        deviation: deviation, deviationSigma: sigma, direction: .low
                    ))
                }
            }
            if !metricEvents.isEmpty {
                events[metric] = metricEvents
            }
        }

        return events
    }

    // MARK: - 2-Step Sequence Detection

    /// Find a 2-step sequence: cause event followed by effect event within maxStepLag days.
    /// Uses a binomial test to check if the co-occurrence rate exceeds chance.
    private func find2StepSequence(
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        causeEvents: [MetricEvent],
        effectEvents: [MetricEvent],
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]],
        baselines: [HealthMetric: UserBaseline]
    ) -> TemporalSequence? {
        let effectDateSet = Set(effectEvents.map { calendar.startOfDay(for: $0.date) })

        // For each cause event, check if an effect event follows within maxStepLag days
        var hits: [(causeEvent: MetricEvent, effectEvent: MetricEvent, lag: Int)] = []
        var misses = 0

        for causeEvent in causeEvents {
            var foundEffect = false
            for lag in 1...maxStepLag {
                guard let futureDate = calendar.date(byAdding: .day, value: lag, to: causeEvent.date) else { continue }
                let futureDay = calendar.startOfDay(for: futureDate)
                if effectDateSet.contains(futureDay) {
                    // Find the matching effect event
                    if let effectEvent = effectEvents.first(where: { calendar.isDate($0.date, inSameDayAs: futureDay) }) {
                        hits.append((causeEvent, effectEvent, lag))
                        foundEffect = true
                        break
                    }
                }
            }
            if !foundEffect {
                misses += 1
            }
        }

        let totalTrials = hits.count + misses
        guard hits.count >= minSupport, totalTrials >= minSupport else { return nil }

        // Base rate: how often effect events occur on any given day
        let totalDays = sortedDates.count
        let effectRate = Double(effectEvents.count) / Double(totalDays)
        // Expected co-occurrence rate over maxStepLag-day window
        let expectedRate = 1.0 - pow(1.0 - effectRate, Double(maxStepLag))

        let observedRate = Double(hits.count) / Double(totalTrials)

        // Binomial test: is observed rate significantly higher than expected?
        let pValue = binomialTestPValue(
            successes: hits.count,
            trials: totalTrials,
            expectedRate: expectedRate
        )
        guard pValue < 0.05 else { return nil }

        // Compute average lag and consequence magnitude
        let avgLag = hits.map(\.lag).mean(of: { Double($0) })
        let avgEffectMagnitude = hits.map { abs($0.effectEvent.deviation) }.mean
        let avgCauseValue = hits.map(\.causeEvent.value).mean
        let avgEffectValue = hits.map(\.effectEvent.value).mean

        // Determine condition types from direction
        let causeCondition = dominantCondition(events: hits.map(\.causeEvent))
        let effectCondition = dominantCondition(events: hits.map(\.effectEvent))

        // Determine thresholds
        let causeThreshold = thresholdForCondition(
            condition: causeCondition,
            metric: causeMetric,
            baselines: baselines
        )
        let effectThreshold = thresholdForCondition(
            condition: effectCondition,
            metric: effectMetric,
            baselines: baselines
        )

        // Check if currently active
        let (isActive, currentStep) = checkCurrentlyActive2Step(
            causeMetric: causeMetric,
            effectMetric: effectMetric,
            causeCondition: causeCondition,
            causeThreshold: causeThreshold,
            sortedDates: sortedDates,
            dailyValues: dailyValues
        )

        let roundedLag = Int(avgLag.rounded())
        let description = generateSequenceDescription(
            causeMetric: causeMetric,
            effectMetric: effectMetric,
            causeCondition: causeCondition,
            effectCondition: effectCondition,
            causeThreshold: causeThreshold,
            avgEffectMagnitude: avgEffectMagnitude,
            avgLag: roundedLag,
            hits: hits.count,
            trials: totalTrials,
            isActive: isActive,
            baselines: baselines
        )

        let predictedOutcome: String?
        if isActive {
            predictedOutcome = generatePrediction(
                effectMetric: effectMetric,
                effectCondition: effectCondition,
                avgEffectMagnitude: avgEffectMagnitude,
                avgLag: roundedLag,
                baselines: baselines
            )
        } else {
            predictedOutcome = nil
        }

        return TemporalSequence(
            steps: [
                TemporalSequence.SequenceStep(
                    metric: causeMetric,
                    condition: causeCondition,
                    dayOffset: 0,
                    avgValue: avgCauseValue,
                    threshold: causeThreshold
                ),
                TemporalSequence.SequenceStep(
                    metric: effectMetric,
                    condition: effectCondition,
                    dayOffset: roundedLag,
                    avgValue: avgEffectValue,
                    threshold: effectThreshold
                )
            ],
            totalOccurrences: hits.count,
            avgConsequenceMagnitude: avgEffectMagnitude,
            confidence: observedRate,
            description: description,
            isCurrentlyActive: isActive,
            currentStepIndex: currentStep,
            predictedOutcome: predictedOutcome,
            discoveredAt: Date()
        )
    }

    // MARK: - 3-Step Sequence Detection

    /// Extend a 2-step sequence to 3 steps: A -> B -> C
    private func find3StepSequence(
        baseSequence: TemporalSequence,
        thirdMetric: HealthMetric,
        midEvents: [MetricEvent],
        thirdEvents: [MetricEvent],
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]],
        baselines: [HealthMetric: UserBaseline]
    ) -> TemporalSequence? {
        guard baseSequence.steps.count == 2 else { return nil }

        let midStep = baseSequence.steps[1]
        let thirdDateSet = Set(thirdEvents.map { calendar.startOfDay(for: $0.date) })

        // For each mid-event, check if third event follows
        var hits: [(midEvent: MetricEvent, thirdEvent: MetricEvent, lag: Int)] = []
        var misses = 0

        for midEvent in midEvents {
            var found = false
            for lag in 1...maxStepLag {
                guard let futureDate = calendar.date(byAdding: .day, value: lag, to: midEvent.date) else { continue }
                let futureDay = calendar.startOfDay(for: futureDate)
                if thirdDateSet.contains(futureDay) {
                    if let thirdEvent = thirdEvents.first(where: { calendar.isDate($0.date, inSameDayAs: futureDay) }) {
                        hits.append((midEvent, thirdEvent, lag))
                        found = true
                        break
                    }
                }
            }
            if !found { misses += 1 }
        }

        let totalTrials = hits.count + misses
        guard hits.count >= minSupport, totalTrials >= minSupport else { return nil }

        let effectRate = Double(thirdEvents.count) / Double(sortedDates.count)
        let expectedRate = 1.0 - pow(1.0 - effectRate, Double(maxStepLag))
        let observedRate = Double(hits.count) / Double(totalTrials)

        let pValue = binomialTestPValue(
            successes: hits.count,
            trials: totalTrials,
            expectedRate: expectedRate
        )
        guard pValue < 0.05 else { return nil }

        let avgLag3 = hits.map(\.lag).mean(of: { Double($0) })
        let avgThirdValue = hits.map(\.thirdEvent.value).mean
        let avgThirdMagnitude = hits.map { abs($0.thirdEvent.deviation) }.mean
        let thirdCondition = dominantCondition(events: hits.map(\.thirdEvent))
        let thirdThreshold = thresholdForCondition(
            condition: thirdCondition,
            metric: thirdMetric,
            baselines: baselines
        )

        let totalLag = midStep.dayOffset + Int(avgLag3.rounded())
        let combinedConfidence = baseSequence.confidence * observedRate

        let firstMetric = baseSequence.steps[0].metric
        let secondMetric = midStep.metric

        let description = "The sequence \(firstMetric.displayName) \(conditionVerb(baseSequence.steps[0].condition)) → \(secondMetric.displayName) \(conditionVerb(midStep.condition)) → \(thirdMetric.displayName) \(conditionVerb(thirdCondition)) has occurred \(hits.count) times over \(sortedDates.count) days (total span: ~\(totalLag) days)"

        // Check if currently active
        let (isActive, currentStep) = checkCurrentlyActive3Step(
            steps: baseSequence.steps,
            thirdMetric: thirdMetric,
            thirdCondition: thirdCondition,
            thirdThreshold: thirdThreshold,
            sortedDates: sortedDates,
            dailyValues: dailyValues
        )

        let predictedOutcome: String?
        if isActive, let step = currentStep {
            let remaining = 3 - step - 1
            predictedOutcome = "Based on \(hits.count) past occurrences, \(thirdMetric.displayName) may \(conditionVerb(thirdCondition)) within \(remaining) day\(remaining == 1 ? "" : "s")"
        } else {
            predictedOutcome = nil
        }

        return TemporalSequence(
            steps: [
                baseSequence.steps[0],
                baseSequence.steps[1],
                TemporalSequence.SequenceStep(
                    metric: thirdMetric,
                    condition: thirdCondition,
                    dayOffset: totalLag,
                    avgValue: avgThirdValue,
                    threshold: thirdThreshold
                )
            ],
            totalOccurrences: hits.count,
            avgConsequenceMagnitude: avgThirdMagnitude,
            confidence: combinedConfidence,
            description: description,
            isCurrentlyActive: isActive,
            currentStepIndex: currentStep,
            predictedOutcome: predictedOutcome,
            discoveredAt: Date()
        )
    }

    // MARK: - Compounding Effect Detection

    /// Detect how consecutive days of a condition worsen consequence metrics.
    private func detectCompoundingEffects(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline],
        available: [HealthMetric: MetricTimeSeries]
    ) -> [CompoundingEffect] {
        var effects: [CompoundingEffect] = []

        // Metrics that can compound: sleep, activity, exercise
        let compoundableMetrics: [HealthMetric] = [
            .sleepDuration, .steps, .exerciseMinutes, .activeCalories
        ].filter { available[$0] != nil }

        // Consequence metrics to measure impact on
        let consequenceMetrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration,
            .sleepDeep, .activeCalories, .steps
        ].filter { available[$0] != nil }

        for compoundMetric in compoundableMetrics {
            guard let baseline = baselines[compoundMetric] ?? computeBaseline(for: compoundMetric, from: available) else { continue }
            guard baseline.standardDeviation > 0 else { continue }

            // Determine the "bad" direction: below baseline for higherIsBetter, above for lowerIsBetter
            let isBelowBad = compoundMetric.higherIsBetter
            let threshold = isBelowBad
                ? baseline.mean - baseline.standardDeviation
                : baseline.mean + baseline.standardDeviation

            // Find streaks of consecutive days where metric is on the bad side
            let streaks = findConsecutiveStreaks(
                metric: compoundMetric,
                threshold: threshold,
                isBelowBad: isBelowBad,
                sortedDates: sortedDates,
                dailyValues: dailyValues
            )

            guard !streaks.isEmpty else { continue }

            // For each consequence metric, measure how it changes with streak length
            var consequences: [CompoundingEffect.ConsequenceMetric] = []

            for consequenceMetric in consequenceMetrics where consequenceMetric != compoundMetric {
                guard let cBaseline = baselines[consequenceMetric] ?? computeBaseline(for: consequenceMetric, from: available) else { continue }

                if let consequence = measureCompounding(
                    streaks: streaks,
                    consequenceMetric: consequenceMetric,
                    consequenceBaseline: cBaseline,
                    dailyValues: dailyValues
                ) {
                    consequences.append(consequence)
                }
            }

            guard !consequences.isEmpty else { continue }

            let maxStreak = streaks.map(\.count).max() ?? 0
            let bestConsequence = consequences.max(by: { abs($0.avgDeltaPerDay) < abs($1.avgDeltaPerDay) })
            let rate = bestConsequence?.avgDeltaPerDay ?? 0

            let conditionDesc = formatThreshold(
                metric: compoundMetric,
                threshold: threshold,
                isBelowBad: isBelowBad
            )

            let description = generateCompoundingDescription(
                metric: compoundMetric,
                conditionDesc: conditionDesc,
                consequences: consequences,
                maxStreak: maxStreak,
                baselines: baselines
            )

            effects.append(CompoundingEffect(
                metric: compoundMetric,
                condition: conditionDesc,
                compoundingRate: rate,
                maxObservedStreak: maxStreak,
                avgConsequence: consequences,
                description: description
            ))
        }

        return effects.sorted { abs($0.compoundingRate) > abs($1.compoundingRate) }
    }

    /// Find consecutive-day streaks where a metric is on the "bad" side of its threshold.
    private func findConsecutiveStreaks(
        metric: HealthMetric,
        threshold: Double,
        isBelowBad: Bool,
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> [[Date]] {
        var streaks: [[Date]] = []
        var currentStreak: [Date] = []

        for i in 0..<sortedDates.count {
            let date = sortedDates[i]
            guard let value = dailyValues[date]?[metric] else {
                if currentStreak.count >= 2 { streaks.append(currentStreak) }
                currentStreak = []
                continue
            }

            let isBad = isBelowBad ? value < threshold : value > threshold

            if isBad {
                // Check consecutive: if there's a gap > 1 day, start new streak
                if let lastDate = currentStreak.last {
                    let gap = calendar.dateComponents([.day], from: lastDate, to: date).day ?? 0
                    if gap > 1 {
                        if currentStreak.count >= 2 { streaks.append(currentStreak) }
                        currentStreak = [date]
                    } else {
                        currentStreak.append(date)
                    }
                } else {
                    currentStreak = [date]
                }
            } else {
                if currentStreak.count >= 2 { streaks.append(currentStreak) }
                currentStreak = []
            }
        }
        if currentStreak.count >= 2 { streaks.append(currentStreak) }

        return streaks
    }

    /// Measure how a consequence metric changes with streak length using linear regression.
    private func measureCompounding(
        streaks: [[Date]],
        consequenceMetric: HealthMetric,
        consequenceBaseline: UserBaseline,
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> CompoundingEffect.ConsequenceMetric? {
        guard consequenceBaseline.standardDeviation > 0 else { return nil }

        // Collect (streakDay, consequenceDeviation) pairs
        var streakDayValues: [Int: [Double]] = [:] // streakDay -> [deviations]

        for streak in streaks {
            for (dayIndex, date) in streak.enumerated() {
                let streakDay = dayIndex + 1
                // Look at consequence metric on this day and the next day
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: date),
                   let value = dailyValues[calendar.startOfDay(for: nextDate)]?[consequenceMetric] {
                    let deviation = value - consequenceBaseline.mean
                    streakDayValues[streakDay, default: []].append(deviation)
                }
            }
        }

        // Need at least 2 different streak lengths to fit regression
        let validDays = streakDayValues.filter { $0.value.count >= 2 }
        guard validDays.count >= 2 else { return nil }

        // Build regression: y = consequence_deviation, x = streak_day
        var xValues: [Double] = []
        var yValues: [Double] = []
        for (day, deviations) in validDays {
            let avgDev = deviations.mean
            xValues.append(Double(day))
            yValues.append(avgDev)
        }

        let regression = linearRegressionFit(x: xValues, y: yValues)

        // Check significance: slope must be meaningfully large relative to baseline
        let slopeAsPercent = abs(regression.slope) / consequenceBaseline.mean * 100
        guard slopeAsPercent > 1.0 else { return nil } // At least 1% change per day

        // Find peak impact day
        let peakDay: Int
        if let maxEntry = validDays.max(by: { abs($0.value.mean) < abs($1.value.mean) }) {
            peakDay = maxEntry.key
        } else {
            peakDay = validDays.keys.max() ?? 1
        }

        return CompoundingEffect.ConsequenceMetric(
            metric: consequenceMetric,
            avgDeltaPerDay: regression.slope,
            peakImpactDay: peakDay
        )
    }

    // MARK: - Precursor Pattern Detection

    /// Detect metric patterns that reliably precede bad health events.
    private func detectPrecursorPatterns(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline],
        stateHistory: [SmoothedHealthState]
    ) -> [PrecursorPattern] {
        // Define "bad events": days where HRV drops > 1.5 sigma OR RHR spikes > 1.5 sigma
        let badEventDates = identifyBadEvents(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines,
            stateHistory: stateHistory
        )
        guard badEventDates.count >= minSupport else { return [] }

        // Identify good/normal days for contrast (not within 3 days of a bad event)
        let nearBadDates = expandDates(badEventDates, radius: 3)
        let goodDates = sortedDates.filter { !nearBadDates.contains($0) }
        guard goodDates.count >= minSupport else { return [] }

        // For each metric, check if it reliably deviates before bad events
        var patterns: [PrecursorPattern] = []
        let metricsToCheck = baselines.keys.filter { Self.coreMetrics.contains($0) }

        // Look for single-metric precursors
        for metric in metricsToCheck {
            guard let baseline = baselines[metric], baseline.standardDeviation > 0 else { continue }

            for leadDays in 1...5 {
                let precursorResult = checkPrecursor(
                    metric: metric,
                    baseline: baseline,
                    leadDays: leadDays,
                    badEventDates: badEventDates,
                    goodDates: goodDates,
                    dailyValues: dailyValues
                )
                guard let result = precursorResult else { continue }

                // Check if currently triggered
                let isTriggered = checkPrecursorCurrentlyTriggered(
                    metric: metric,
                    direction: result.direction,
                    threshold: result.threshold,
                    leadDays: leadDays,
                    sortedDates: sortedDates,
                    dailyValues: dailyValues
                )

                let directionText = result.direction == "declining" ? "declining" : (result.direction == "low" ? "low" : "elevated")

                let description = "\(metric.displayName) \(directionText) (\(metric.formatValue(result.avgPrecursorValue)) \(metric.unit)) \(leadDays) day\(leadDays == 1 ? "" : "s") before bad days. accurate \(Int(result.accuracy * 100))% of the time (\(result.hitCount)/\(result.totalChecked))"

                let pattern = PrecursorPattern(
                    warningSignals: [(metric: metric, direction: directionText, leadDays: leadDays)],
                    predictedEvent: "health dip (HRV drop or RHR spike)",
                    historicalAccuracy: result.accuracy,
                    occurrenceCount: result.hitCount,
                    description: description,
                    isCurrentlyTriggered: isTriggered
                )
                patterns.append(pattern)
            }
        }

        // Deduplicate: keep best lead-day per metric
        var bestByMetric: [HealthMetric: PrecursorPattern] = [:]
        for pattern in patterns {
            guard let signal = pattern.warningSignals.first else { continue }
            let metric = signal.metric
            if let existing = bestByMetric[metric] {
                if pattern.historicalAccuracy > existing.historicalAccuracy {
                    bestByMetric[metric] = pattern
                }
            } else {
                bestByMetric[metric] = pattern
            }
        }

        return Array(bestByMetric.values)
            .filter { $0.historicalAccuracy >= 0.6 && $0.occurrenceCount >= minSupport }
            .sorted { $0.historicalAccuracy > $1.historicalAccuracy }
    }

    /// Identify "bad event" dates: significant drops in key health metrics.
    private func identifyBadEvents(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline],
        stateHistory: [SmoothedHealthState]
    ) -> [Date] {
        var badDates = Set<Date>()

        // HRV dropping > 1.5 sigma below baseline
        if let hrvBaseline = baselines[.heartRateVariability], hrvBaseline.standardDeviation > 0 {
            let threshold = hrvBaseline.mean - 1.5 * hrvBaseline.standardDeviation
            for date in sortedDates {
                if let hrv = dailyValues[date]?[.heartRateVariability], hrv < threshold {
                    badDates.insert(date)
                }
            }
        }

        // RHR spiking > 1.5 sigma above baseline
        if let rhrBaseline = baselines[.restingHeartRate], rhrBaseline.standardDeviation > 0 {
            let threshold = rhrBaseline.mean + 1.5 * rhrBaseline.standardDeviation
            for date in sortedDates {
                if let rhr = dailyValues[date]?[.restingHeartRate], rhr > threshold {
                    badDates.insert(date)
                }
            }
        }

        // State transitions to "stressed" or "recovery" states (from HMM)
        for state in stateHistory {
            if state.isTransitionDay {
                let label = state.assignedState.label.lowercased()
                if label.contains("stress") || label.contains("fatig") || label.contains("decline") {
                    badDates.insert(calendar.startOfDay(for: state.date))
                }
            }
        }

        return Array(badDates).sorted()
    }

    private struct PrecursorResult {
        let accuracy: Double
        let hitCount: Int
        let totalChecked: Int
        let direction: String
        let threshold: Double
        let avgPrecursorValue: Double
    }

    /// Check if a single metric reliably deviates N days before bad events.
    private func checkPrecursor(
        metric: HealthMetric,
        baseline: UserBaseline,
        leadDays: Int,
        badEventDates: [Date],
        goodDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> PrecursorResult? {
        // Collect metric values N days before bad events
        var preBadValues: [Double] = []
        for badDate in badEventDates {
            guard let preDate = calendar.date(byAdding: .day, value: -leadDays, to: badDate) else { continue }
            let preDay = calendar.startOfDay(for: preDate)
            if let value = dailyValues[preDay]?[metric] {
                preBadValues.append(value)
            }
        }

        // Collect metric values N days before good days (control)
        var preGoodValues: [Double] = []
        let sampleCount = min(goodDates.count, badEventDates.count * 3) // Don't oversample
        let sampledGood = Array(goodDates.shuffled().prefix(sampleCount))
        for goodDate in sampledGood {
            guard let preDate = calendar.date(byAdding: .day, value: -leadDays, to: goodDate) else { continue }
            let preDay = calendar.startOfDay(for: preDate)
            if let value = dailyValues[preDay]?[metric] {
                preGoodValues.append(value)
            }
        }

        guard preBadValues.count >= minSupport, preGoodValues.count >= minSupport else { return nil }

        let preBadMean = preBadValues.mean
        let preGoodMean = preGoodValues.mean

        // Determine direction of deviation
        let diff = preBadMean - preGoodMean
        let direction: String
        let threshold: Double

        if metric.higherIsBetter {
            // For HRV, sleep, etc.: lower before bad events is concerning
            if diff < -0.5 * baseline.standardDeviation {
                direction = "low"
                threshold = baseline.mean - 0.5 * baseline.standardDeviation
            } else {
                return nil
            }
        } else {
            // For RHR, etc.: higher before bad events is concerning
            if diff > 0.5 * baseline.standardDeviation {
                direction = "elevated"
                threshold = baseline.mean + 0.5 * baseline.standardDeviation
            } else {
                return nil
            }
        }

        // Count how many bad events had the precursor signal
        var hitCount = 0
        for value in preBadValues {
            let triggered = metric.higherIsBetter ? value < threshold : value > threshold
            if triggered { hitCount += 1 }
        }

        // Count false alarm rate on good days
        var falseAlarms = 0
        for value in preGoodValues {
            let triggered = metric.higherIsBetter ? value < threshold : value > threshold
            if triggered { falseAlarms += 1 }
        }

        let accuracy = Double(hitCount) / Double(preBadValues.count)
        let falseAlarmRate = Double(falseAlarms) / Double(preGoodValues.count)

        // Must have significantly better detection than false alarm rate
        guard accuracy > falseAlarmRate + 0.15 else { return nil }

        return PrecursorResult(
            accuracy: accuracy,
            hitCount: hitCount,
            totalChecked: preBadValues.count,
            direction: direction,
            threshold: threshold,
            avgPrecursorValue: preBadMean
        )
    }

    // MARK: - Recovery Sequence Detection

    /// Track how metrics recover after bad events and what accelerates recovery.
    private func detectRecoverySequences(
        dailyValues: [Date: [HealthMetric: Double]],
        sortedDates: [Date],
        baselines: [HealthMetric: UserBaseline]
    ) -> [RecoveryProfile] {
        let badEventDates = identifyBadEvents(
            dailyValues: dailyValues,
            sortedDates: sortedDates,
            baselines: baselines,
            stateHistory: []
        )
        guard badEventDates.count >= minSupport else { return [] }

        let recoveryMetrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration, .sleepDeep
        ]

        var metricRecoveries: [RecoveryProfile.MetricRecovery] = []
        var allRecoveryDays: [Int] = []

        for metric in recoveryMetrics {
            guard let baseline = baselines[metric], baseline.standardDeviation > 0 else { continue }

            var recoveryTimes: [Int] = []
            var dipDepths: [Double] = []

            for badDate in badEventDates {
                guard let badValue = dailyValues[badDate]?[metric] else { continue }
                let dip = abs(badValue - baseline.mean) / baseline.standardDeviation

                // Track how many days until metric returns to within 0.5 sigma of baseline
                var recoveredDay = 0
                for offset in 1...14 {
                    guard let futureDate = calendar.date(byAdding: .day, value: offset, to: badDate) else { break }
                    let futureDay = calendar.startOfDay(for: futureDate)
                    if let futureValue = dailyValues[futureDay]?[metric] {
                        let deviation = abs(futureValue - baseline.mean) / baseline.standardDeviation
                        if deviation < 0.5 {
                            recoveredDay = offset
                            break
                        }
                    }
                }

                if recoveredDay > 0 {
                    recoveryTimes.append(recoveredDay)
                    dipDepths.append(dip)
                }
            }

            guard recoveryTimes.count >= 2 else { continue }

            let avgRecovery = Int(recoveryTimes.map { Double($0) }.mean.rounded())
            let avgDip = dipDepths.mean

            metricRecoveries.append(RecoveryProfile.MetricRecovery(
                metric: metric,
                avgRecoveryDays: avgRecovery,
                avgDepthOfDip: avgDip
            ))
            allRecoveryDays.append(contentsOf: recoveryTimes)
        }

        guard !metricRecoveries.isEmpty else { return [] }

        // Detect accelerators: check if rest days (low active cal) speed recovery
        let accelerators = detectRecoveryAccelerators(
            badEventDates: badEventDates,
            dailyValues: dailyValues,
            baselines: baselines,
            sortedDates: sortedDates
        )

        let avgTotal = allRecoveryDays.isEmpty ? 0 : Int(allRecoveryDays.map { Double($0) }.mean.rounded())

        let recoveryDesc = metricRecoveries.map { recovery in
            "\(recovery.metric.displayName): ~\(recovery.avgRecoveryDays) days"
        }.joined(separator: ", ")

        let description = "After health dips, average recovery: \(recoveryDesc). Total recovery ~\(avgTotal) days." + (accelerators.isEmpty ? "" : " Recovery is faster when: \(accelerators.joined(separator: "; "))")

        return [RecoveryProfile(
            triggerEvent: "health dip (HRV drop or RHR spike)",
            metricRecoveries: metricRecoveries,
            avgTotalRecoveryDays: avgTotal,
            accelerators: accelerators,
            description: description
        )]
    }

    /// Check what behaviors accelerate recovery after bad events.
    private func detectRecoveryAccelerators(
        badEventDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]],
        baselines: [HealthMetric: UserBaseline],
        sortedDates: [Date]
    ) -> [String] {
        var accelerators: [String] = []

        // Check if lower activity the day after a bad event speeds HRV recovery
        guard let hrvBaseline = baselines[.heartRateVariability],
              let calBaseline = baselines[.activeCalories] else { return [] }

        var restRecoveryDays: [Int] = []
        var activeRecoveryDays: [Int] = []

        for badDate in badEventDates {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: badDate) else { continue }
            let nextDayStart = calendar.startOfDay(for: nextDay)
            guard let nextDayCal = dailyValues[nextDayStart]?[.activeCalories] else { continue }

            let isRestDay = nextDayCal < calBaseline.mean - 0.5 * calBaseline.standardDeviation

            // Measure how fast HRV recovers
            var recoveredDay = 14 // default to max if no recovery
            for offset in 2...14 {
                guard let futureDate = calendar.date(byAdding: .day, value: offset, to: badDate) else { break }
                let futureDay = calendar.startOfDay(for: futureDate)
                if let hrvValue = dailyValues[futureDay]?[.heartRateVariability] {
                    if abs(hrvValue - hrvBaseline.mean) < 0.5 * hrvBaseline.standardDeviation {
                        recoveredDay = offset
                        break
                    }
                }
            }

            if isRestDay {
                restRecoveryDays.append(recoveredDay)
            } else {
                activeRecoveryDays.append(recoveredDay)
            }
        }

        if restRecoveryDays.count >= 2 && activeRecoveryDays.count >= 2 {
            let restAvg = restRecoveryDays.map { Double($0) }.mean
            let activeAvg = activeRecoveryDays.map { Double($0) }.mean
            let diff = activeAvg - restAvg

            if diff >= 1.0 {
                accelerators.append("taking a rest day speeds recovery by ~\(Int(diff.rounded())) day\(diff >= 1.5 ? "s" : "")")
            }
        }

        return accelerators
    }

    // MARK: - Active Pattern Matching

    /// Check if a 2-step sequence is currently in progress.
    private func checkCurrentlyActive2Step(
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        causeCondition: TemporalSequence.StepCondition,
        causeThreshold: Double,
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> (isActive: Bool, currentStep: Int?) {
        // Check last maxStepLag days for the cause condition
        let recentDays = Array(sortedDates.suffix(maxStepLag))
        guard !recentDays.isEmpty else { return (false, nil) }

        for date in recentDays.reversed() {
            guard let value = dailyValues[date]?[causeMetric] else { continue }
            if meetsCondition(value: value, condition: causeCondition, threshold: causeThreshold) {
                // Step 1 is active. we're between cause and expected effect
                return (true, 0)
            }
        }

        return (false, nil)
    }

    /// Check if a 3-step sequence is currently in progress.
    private func checkCurrentlyActive3Step(
        steps: [TemporalSequence.SequenceStep],
        thirdMetric: HealthMetric,
        thirdCondition: TemporalSequence.StepCondition,
        thirdThreshold: Double,
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> (isActive: Bool, currentStep: Int?) {
        guard steps.count >= 2 else { return (false, nil) }

        let recentDays = Array(sortedDates.suffix(maxStepLag * 2))
        guard !recentDays.isEmpty else { return (false, nil) }

        // Check if step 2 happened recently (meaning step 3 might be coming)
        for date in recentDays.reversed() {
            guard let value = dailyValues[date]?[steps[1].metric] else { continue }
            if meetsCondition(value: value, condition: steps[1].condition, threshold: steps[1].threshold) {
                return (true, 1)
            }
        }

        // Check if step 1 happened recently
        for date in recentDays.reversed() {
            guard let value = dailyValues[date]?[steps[0].metric] else { continue }
            if meetsCondition(value: value, condition: steps[0].condition, threshold: steps[0].threshold) {
                return (true, 0)
            }
        }

        return (false, nil)
    }

    /// Check if a precursor signal is currently triggered.
    private func checkPrecursorCurrentlyTriggered(
        metric: HealthMetric,
        direction: String,
        threshold: Double,
        leadDays: Int,
        sortedDates: [Date],
        dailyValues: [Date: [HealthMetric: Double]]
    ) -> Bool {
        // Check last `leadDays` of data
        let recentDays = Array(sortedDates.suffix(leadDays))
        guard !recentDays.isEmpty else { return false }

        var triggeredCount = 0
        for date in recentDays {
            guard let value = dailyValues[date]?[metric] else { continue }
            let triggered: Bool
            switch direction {
            case "low", "declining":
                triggered = value < threshold
            case "elevated":
                triggered = value > threshold
            default:
                triggered = false
            }
            if triggered { triggeredCount += 1 }
        }

        // At least half of recent days must show the signal
        return triggeredCount > recentDays.count / 2
    }

    // MARK: - Statistical Helpers

    /// One-sided binomial test p-value using normal approximation.
    /// Tests H1: true rate > expectedRate.
    private func binomialTestPValue(successes: Int, trials: Int, expectedRate: Double) -> Double {
        guard trials > 0, expectedRate > 0, expectedRate < 1 else { return 1.0 }

        let n = Double(trials)
        let k = Double(successes)
        let p = expectedRate

        let mean = n * p
        let variance = n * p * (1.0 - p)
        guard variance > 0 else { return 1.0 }
        let sd = variance.squareRoot()

        // Continuity-corrected z-score
        let z = (k - 0.5 - mean) / sd
        guard z > 0 else { return 1.0 }

        // Approximate upper tail of standard normal using rational approximation
        return normalSurvival(z)
    }

    /// Approximate P(Z > z) for z > 0 using Abramowitz & Stegun rational approximation (26.2.17).
    private func normalSurvival(_ z: Double) -> Double {
        guard z > 0 else { return 1.0 }
        let p = 0.2316419
        let b1 = 0.319381530
        let b2 = -0.356563782
        let b3 = 1.781477937
        let b4 = -1.821255978
        let b5 = 1.330274429

        let t = 1.0 / (1.0 + p * z)
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t

        let phi = exp(-0.5 * z * z) / (2.0 * .pi).squareRoot()
        let survival = phi * (b1 * t + b2 * t2 + b3 * t3 + b4 * t4 + b5 * t5)
        return max(0, min(1, survival))
    }

    /// Simple linear regression: y = slope * x + intercept
    private func linearRegressionFit(x: [Double], y: [Double]) -> (slope: Double, intercept: Double) {
        Array<Double>.linearRegression(x: x, y: y)
    }

    // MARK: - Condition Helpers

    /// Determine dominant condition from a set of events.
    private func dominantCondition(events: [MetricEvent]) -> TemporalSequence.StepCondition {
        let lowCount = events.filter { $0.direction == .low }.count
        let highCount = events.filter { $0.direction == .high }.count
        return lowCount > highCount ? .below : .above
    }

    /// Derive a threshold from the condition type and baseline.
    private func thresholdForCondition(
        condition: TemporalSequence.StepCondition,
        metric: HealthMetric,
        baselines: [HealthMetric: UserBaseline]
    ) -> Double {
        guard let baseline = baselines[metric] else { return 0 }
        switch condition {
        case .below, .declining:
            return baseline.mean - baseline.standardDeviation
        case .above, .spiking:
            return baseline.mean + baseline.standardDeviation
        case .sustained:
            return baseline.mean
        }
    }

    /// Check if a value meets a condition relative to a threshold.
    private func meetsCondition(
        value: Double,
        condition: TemporalSequence.StepCondition,
        threshold: Double
    ) -> Bool {
        switch condition {
        case .below, .declining:
            return value < threshold
        case .above, .spiking:
            return value > threshold
        case .sustained:
            return true
        }
    }

    /// Compute a baseline from the time series when no UserBaseline exists.
    private func computeBaseline(
        for metric: HealthMetric,
        from available: [HealthMetric: MetricTimeSeries]
    ) -> UserBaseline? {
        guard let series = available[metric], series.sortedSamples.count >= 7 else { return nil }
        let values = series.values
        return UserBaseline(
            metric: metric,
            mean: values.mean,
            standardDeviation: values.standardDeviation,
            median: values.median,
            sampleCount: values.count
        )
    }

    /// Expand a list of dates by a radius (include surrounding days).
    private func expandDates(_ dates: [Date], radius: Int) -> Set<Date> {
        var expanded = Set<Date>()
        for date in dates {
            for offset in -radius...radius {
                if let d = calendar.date(byAdding: .day, value: offset, to: date) {
                    expanded.insert(calendar.startOfDay(for: d))
                }
            }
        }
        return expanded
    }

    /// Convert a StepCondition to a verb phrase.
    private func conditionVerb(_ condition: TemporalSequence.StepCondition) -> String {
        switch condition {
        case .below: return "drops"
        case .above: return "spikes"
        case .declining: return "declines"
        case .spiking: return "surges"
        case .sustained: return "stays off"
        }
    }

    /// Format a threshold as a human-readable condition string.
    private func formatThreshold(
        metric: HealthMetric,
        threshold: Double,
        isBelowBad: Bool
    ) -> String {
        let formattedValue = metric.formatValue(threshold)
        let direction = isBelowBad ? "below" : "above"
        return "\(direction) \(formattedValue)\(metric.unit)"
    }

    // MARK: - Natural Language Generation

    /// Generate a specific, data-driven description for a 2-step sequence.
    private func generateSequenceDescription(
        causeMetric: HealthMetric,
        effectMetric: HealthMetric,
        causeCondition: TemporalSequence.StepCondition,
        effectCondition: TemporalSequence.StepCondition,
        causeThreshold: Double,
        avgEffectMagnitude: Double,
        avgLag: Int,
        hits: Int,
        trials: Int,
        isActive: Bool,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        let causeDesc = "\(causeMetric.displayName) \(conditionVerb(causeCondition)) \(causeCondition == .below || causeCondition == .declining ? "below" : "above") \(causeMetric.formatValue(causeThreshold)) \(causeMetric.unit)"

        // Effect magnitude as percentage of baseline if available
        let effectDesc: String
        if let effectBaseline = baselines[effectMetric], effectBaseline.mean > 0 {
            let pctChange = (avgEffectMagnitude / effectBaseline.mean) * 100
            effectDesc = "\(effectMetric.displayName) \(conditionVerb(effectCondition)) by \(String(format: "%.0f", pctChange))%"
        } else {
            effectDesc = "\(effectMetric.displayName) \(conditionVerb(effectCondition)) by \(effectMetric.formatValue(avgEffectMagnitude)) \(effectMetric.unit)"
        }

        var text = "When your \(causeDesc), your \(effectDesc) within \(avgLag) day\(avgLag == 1 ? "" : "s") (happened \(hits)/\(trials) times)"

        if isActive {
            text += ". you're currently showing this pattern"
        }

        return text
    }

    /// Generate a prediction for what happens if a currently active sequence continues.
    private func generatePrediction(
        effectMetric: HealthMetric,
        effectCondition: TemporalSequence.StepCondition,
        avgEffectMagnitude: Double,
        avgLag: Int,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        let verb = conditionVerb(effectCondition)

        if let baseline = baselines[effectMetric], baseline.mean > 0 {
            let pctChange = (avgEffectMagnitude / baseline.mean) * 100
            return "Your \(effectMetric.displayName) may \(verb) by ~\(String(format: "%.0f", pctChange))% within \(avgLag) day\(avgLag == 1 ? "" : "s")"
        }

        return "Your \(effectMetric.displayName) may \(verb) by \(effectMetric.formatValue(avgEffectMagnitude)) \(effectMetric.unit) within \(avgLag) day\(avgLag == 1 ? "" : "s")"
    }

    /// Generate a specific description for a compounding effect.
    private func generateCompoundingDescription(
        metric: HealthMetric,
        conditionDesc: String,
        consequences: [CompoundingEffect.ConsequenceMetric],
        maxStreak: Int,
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        guard let strongest = consequences.max(by: { abs($0.avgDeltaPerDay) < abs($1.avgDeltaPerDay) }) else {
            return "Consecutive days of \(metric.displayName) \(conditionDesc) have compounding effects"
        }

        let directionWord = strongest.avgDeltaPerDay > 0 ? "increases" : "decreases"

        // Express rate relative to baseline
        let rateDesc: String
        if let baseline = baselines[strongest.metric], baseline.mean > 0 {
            let pctPerDay = abs(strongest.avgDeltaPerDay / baseline.mean) * 100
            rateDesc = "\(String(format: "%.1f", pctPerDay))% per consecutive day"
        } else {
            rateDesc = "\(strongest.metric.formatValue(abs(strongest.avgDeltaPerDay)))\(strongest.metric.unit) per consecutive day"
        }

        return "Each consecutive day of \(metric.displayName) \(conditionDesc) \(directionWord) your \(strongest.metric.displayName) by \(rateDesc) (peak impact on day \(strongest.peakImpactDay), max observed streak: \(maxStreak) days)"
    }

    // MARK: - Query API

    /// Get sequences that are currently active (pattern in progress).
    var activeSequences: [TemporalSequence] {
        sequences.filter(\.isCurrentlyActive)
    }

    /// Get precursor patterns that are currently triggered.
    var activeWarnings: [PrecursorPattern] {
        precursorPatterns.filter(\.isCurrentlyTriggered)
    }

    /// Get the top N most confident sequences.
    func topSequences(_ count: Int = 5) -> [TemporalSequence] {
        Array(sequences.prefix(count))
    }

    /// Get sequences involving a specific metric (as cause or effect).
    func sequences(involving metric: HealthMetric) -> [TemporalSequence] {
        sequences.filter { seq in seq.steps.contains { $0.metric == metric } }
    }

    /// Get compounding effects for a specific metric.
    func compoundingEffects(for metric: HealthMetric) -> [CompoundingEffect] {
        compoundingEffects.filter { $0.metric == metric }
    }

    /// Lightweight hash of input data to skip recomputation when unchanged.
    private func computeInputHash(timeSeries: [HealthMetric: MetricTimeSeries]) -> Int {
        var hasher = Hasher()
        for (metric, series) in timeSeries.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(metric.rawValue)
            hasher.combine(series.samples.count)
            if let last = series.samples.last {
                hasher.combine(last.value)
                hasher.combine(last.date.timeIntervalSinceReferenceDate)
            }
        }
        return hasher.finalize()
    }
}
