import Foundation
import Accelerate

// MARK: - Intelligence Card Model

enum IntelligenceCardType: String {
    case predictiveRisk
    case regimeShift
    case cascadeForecast
    case hiddenDriver
    case bodyClockStatus
    case allostaticLoad
    case autonomicBalance
    case recoveryDebt
    case systemCoherence
    case rhythmDeviation
}

struct IntelligenceCard: Identifiable {
    let id = UUID()
    let type: IntelligenceCardType
    let label: String
    let headline: String
    let severity: CardSeverity
    let priority: Double

    enum CardSeverity: Int, Comparable {
        case info = 0, notable = 1, warning = 2, critical = 3
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

// MARK: - Today Intelligence Engine

/// Synthesizes outputs from 10+ ML components into a daily intelligence briefing.
/// Each card generator returns nil if data is insufficient or the finding is not noteworthy.
/// Cards are ranked by priority; only the top 4 are shown.
final class TodayIntelligenceEngine {

    static let maxCardsToShow = 4

    private let calendar = Date.cal

    // MARK: - Public API

    /// Generate the daily intelligence briefing from all available ML outputs.
    func generateBriefing(
        orchestrator: MLOrchestrator,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        liveHRV: Double?,
        liveRestingHR: Double?,
        sleepHours: Double,
        deepSleepMinutes: Double,
        exerciseMinutes: Double,
        exerciseGoal: Double
    ) -> [IntelligenceCard] {
        var cards: [IntelligenceCard] = []

        // 1-5: Cards from existing ML outputs
        if let card = predictiveRiskCard(orchestrator: orchestrator) { cards.append(card) }
        if let card = regimeShiftCard(orchestrator: orchestrator) { cards.append(card) }
        if let card = cascadeForecastCard(orchestrator: orchestrator) { cards.append(card) }
        if let card = hiddenDriverCard(orchestrator: orchestrator) { cards.append(card) }
        if let card = bodyClockStatusCard(orchestrator: orchestrator) { cards.append(card) }

        // 6-10: New computation cards
        if let card = allostaticLoadCard(
            baselines: baselines,
            timeSeries: timeSeries,
            liveHRV: liveHRV,
            liveRestingHR: liveRestingHR,
            sleepHours: sleepHours,
            deepSleepMinutes: deepSleepMinutes
        ) { cards.append(card) }

        if let card = autonomicBalanceCard(
            baselines: baselines,
            liveHRV: liveHRV,
            liveRestingHR: liveRestingHR
        ) { cards.append(card) }

        if let card = recoveryDebtCard(
            baselines: baselines,
            timeSeries: timeSeries,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: exerciseGoal
        ) { cards.append(card) }

        if let card = systemCoherenceCard(orchestrator: orchestrator) { cards.append(card) }

        if let card = rhythmDeviationCard(
            timeSeries: timeSeries,
            liveHRV: liveHRV,
            liveRestingHR: liveRestingHR,
            sleepHours: sleepHours
        ) { cards.append(card) }

        // Sort by priority descending, take top N
        cards.sort { $0.priority > $1.priority }
        return Array(cards.prefix(Self.maxCardsToShow))
    }

    // MARK: - 1. Predictive Risk Card

    /// Surfaces specific risk probabilities from tomorrow's prediction and urgent health signals.
    private func predictiveRiskCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        // Check for urgent health signals first
        if let report = orchestrator.healthSignalReport {
            let urgentSignals = report.urgentSignals
            if let topSignal = urgentSignals.first, topSignal.riskLevel >= PredictiveHealthSignals.RiskLevel.moderate {
                let severity: IntelligenceCard.CardSeverity
                let priorityBase: Double

                switch topSignal.riskLevel {
                case .critical:
                    severity = .critical; priorityBase = 95
                case .high:
                    severity = .warning; priorityBase = 85
                case .moderate:
                    severity = .notable; priorityBase = 70
                default:
                    severity = .info; priorityBase = 50
                }

                return IntelligenceCard(
                    type: .predictiveRisk,
                    label: Copy.Briefing.Labels.headsUp,
                    headline: Copy.Briefing.TrendSignal.urgentHeadline(signalName: topSignal.signalName),
                    severity: severity,
                    priority: priorityBase + topSignal.score * 5
                )
            }
        }

        // Fall back to tomorrow risk prediction
        guard let prediction = orchestrator.tomorrowRiskPrediction else { return nil }
        guard prediction.probability >= 0.35 else { return nil }

        let pctStr = formatPercent(prediction.probability)
        let severity: IntelligenceCard.CardSeverity

        switch prediction.probability {
        case 0.7...: severity = .critical
        case 0.5..<0.7: severity = .warning
        default: severity = .notable
        }

        return IntelligenceCard(
            type: .predictiveRisk,
            label: Copy.Briefing.Labels.headsUp,
            headline: Copy.Briefing.TrendSignal.tomorrowHeadline(probability: pctStr),
            severity: severity,
            priority: 80 + prediction.probability * 20
        )
    }

    // MARK: - 2. Regime Shift Card

    /// Surfaces recent baseline shifts with magnitude and date from ChangePointDetector.
    private func regimeShiftCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        // Find the most recent, highest-magnitude change point within the last 30 days
        let allCPs = orchestrator.changePoints
        let recentCPs = allCPs.filter { cp in
            cp.daysSinceChange <= 30 && cp.confidence >= 0.7
        }
        let sortedCPs = recentCPs.sorted { $0.magnitude > $1.magnitude }

        guard let topCP = sortedCPs.first else { return nil }

        let isIncrease = topCP.direction == ChangePointDetector.ChangePoint.ChangeDirection.increase
        let directionWord = isIncrease ? "higher" : "lower"
        let metricName = topCP.metric.displayName
        let dateStr = shortDateString(topCP.date)

        let severity: IntelligenceCard.CardSeverity

        // Is this a good or bad shift?
        let isDecrease = !isIncrease
        let isPositive = (isIncrease && topCP.metric.higherIsBetter)
            || (isDecrease && !topCP.metric.higherIsBetter)

        if isPositive {
            severity = topCP.magnitude >= 1.5 ? .notable : .info
        } else {
            severity = topCP.magnitude >= 2.0 ? .warning : .notable
        }

        let priority: Double = isPositive ? 55 + topCP.magnitude * 5 : 70 + topCP.magnitude * 5

        return IntelligenceCard(
            type: .regimeShift,
            label: Copy.Briefing.Labels.somethingChanged,
            headline: Copy.Briefing.SomethingChanged.headline(metricName: metricName, direction: directionWord, dateStr: dateStr),
            severity: severity,
            priority: priority
        )
    }

    // MARK: - 3. Cascade Forecast Card

    /// Multi-metric domino predictions from active temporal sequences and triggered precursors.
    private func cascadeForecastCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        // Highest priority: currently-triggered precursor patterns
        let triggeredPrecursors = orchestrator.precursorPatterns.filter { $0.isCurrentlyTriggered }
        if let top = triggeredPrecursors.sorted(by: { $0.historicalAccuracy > $1.historicalAccuracy }).first {
            let signalDesc = top.warningSignals.prefix(2).map { signal in
                "\(signal.metric.displayName) \(signal.direction)"
            }.joined(separator: " and ")

            return IntelligenceCard(
                type: .cascadeForecast,
                label: Copy.Briefing.Labels.cascadeAlert,
                headline: Copy.Briefing.WhatMightHappen.precursorHeadline(signalDescription: signalDesc, predictedEvent: top.predictedEvent),
                severity: .warning,
                priority: 90 + top.historicalAccuracy * 10
            )
        }

        // Fallback: currently active temporal sequences
        let activeSequences = orchestrator.temporalSequences.filter { $0.isCurrentlyActive }
        guard let topSeq = activeSequences.sorted(by: { $0.confidence > $1.confidence }).first else {
            return nil
        }

        guard topSeq.steps.count >= 2 else { return nil }

        let currentStep = topSeq.currentStepIndex ?? 0
        let remainingSteps = topSeq.steps.dropFirst(currentStep + 1)

        guard let nextStep = remainingSteps.first else { return nil }

        let outcomeStr: String
        if let predicted = topSeq.predictedOutcome {
            outcomeStr = predicted
        } else {
            let isBelowOrDeclining = nextStep.condition == TemporalSequenceMiner.TemporalSequence.StepCondition.below
                || nextStep.condition == TemporalSequenceMiner.TemporalSequence.StepCondition.declining
            let dir = isBelowOrDeclining ? "decline" : "change"
            outcomeStr = "\(nextStep.metric.displayName) \(dir) in ~\(nextStep.dayOffset - (topSeq.steps[currentStep].dayOffset))d"
        }

        return IntelligenceCard(
            type: .cascadeForecast,
            label: Copy.Briefing.Labels.cascadeForecast,
            headline: Copy.Briefing.WhatMightHappen.sequenceHeadline(outcome: outcomeStr),
            severity: .notable,
            priority: 75 + topSeq.confidence * 15
        )
    }

    // MARK: - 4. Hidden Driver Card

    /// Surfaces Granger-causal relationships that survived FDR correction -- relationships users cannot see.
    private func hiddenDriverCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        // Find the strongest causal relationship
        let causalCorrelations = orchestrator.mlCorrelations
            .filter { $0.grangerCausal && $0.survivedFDR && $0.grangerPValue < 0.05 }
            .sorted { $0.grangerEffectSize > $1.grangerEffectSize }

        guard let top = causalCorrelations.first else { return nil }

        let causeMetric = top.metricA.displayName
        let effectMetric = top.metricB.displayName
        let lagDays = top.grangerOptimalLag
        let direction = top.pearsonR > 0 ? "drives" : "inversely drives"

        return IntelligenceCard(
            type: .hiddenDriver,
            label: Copy.Briefing.Labels.whyThisIsHappening,
            headline: Copy.Briefing.WhyThisIsHappening.headline(causeMetric: causeMetric, effectMetric: effectMetric, lagDays: lagDays, direction: direction),
            severity: .notable,
            priority: 60 + top.grangerEffectSize * 20
        )
    }

    // MARK: - 5. Body Clock Status Card

    /// Phase shifts and optimal timing windows from circadian analysis.
    private func bodyClockStatusCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        guard let profile = orchestrator.circadianProfile else { return nil }
        guard profile.confidence >= 0.3 else { return nil }

        let recommendations = orchestrator.timingRecommendations

        // Find workout timing recommendation
        let workoutRec = recommendations.first { $0.activity == .workout }

        let headline: String
        if let workout = workoutRec {
            let startStr = formatHour(workout.optimalWindowStart)
            let endStr = formatHour(workout.optimalWindowEnd)
            headline = Copy.Briefing.YourBodyClock.workoutTimingHeadline(startTime: startStr, endTime: endStr)
        } else {
            headline = Copy.Briefing.YourBodyClock.generalHeadline(peakTime: formatHourDecimal(profile.activityAcrophaseHour))
        }

        return IntelligenceCard(
            type: .bodyClockStatus,
            label: Copy.Briefing.Labels.yourBodyClock,
            headline: headline,
            severity: .info,
            priority: 45 + profile.confidence * 10
        )
    }

    // MARK: - 6. Allostatic Load Index (McEwen, 1998)

    /// Multi-system physiological stress score. Each system contributes a z-score derived from
    /// (current - baseline_mean) / baseline_std, with sign flipped for higher-is-better metrics.
    /// Systems: cardiac (RHR up, HRV down), sleep (duration down, deep down),
    /// respiratory (rate up, SpO2 down), activity (steps down).
    private func allostaticLoadCard(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        liveHRV: Double?,
        liveRestingHR: Double?,
        sleepHours: Double,
        deepSleepMinutes: Double
    ) -> IntelligenceCard? {
        // Define systems and their constituent metrics
        struct SystemDef {
            let name: String
            let metrics: [HealthMetric]
        }

        let systems: [SystemDef] = [
            SystemDef(name: "Cardiac", metrics: [.restingHeartRate, .heartRateVariability]),
            SystemDef(name: "Sleep", metrics: [.sleepDuration, .sleepDeep]),
            SystemDef(name: "Respiratory", metrics: [.respiratoryRate, .bloodOxygen]),
            SystemDef(name: "Activity", metrics: [.steps, .exerciseMinutes])
        ]

        // Resolve current values: prefer live data, fall back to latest time series
        func currentValue(for metric: HealthMetric) -> Double? {
            switch metric {
            case .heartRateVariability: return liveHRV
            case .restingHeartRate: return liveRestingHR
            case .sleepDuration: return sleepHours > 0 ? sleepHours : nil
            case .sleepDeep: return deepSleepMinutes > 0 ? deepSleepMinutes / 60.0 : nil
            default:
                return timeSeries[metric]?.samples(lastDays: 1).last?.value
            }
        }

        var systemScores: [(name: String, score: Double)] = []

        for system in systems {
            var zScores: [Double] = []

            for metric in system.metrics {
                guard let baseline = baselines[metric],
                      baseline.standardDeviation > 0,
                      let value = currentValue(for: metric) else { continue }

                // z = (current - mean) / std
                var z = (value - baseline.mean) / baseline.standardDeviation

                // For higherIsBetter metrics, flip sign so that a LOWER value = MORE stress (positive z)
                if metric.higherIsBetter { z = -z }

                // Cap at [-3, 3] to prevent outlier domination
                z = Swift.max(-3.0, Swift.min(3.0, z))
                zScores.append(z)
            }

            // Only count system if 2+ metrics available
            guard zScores.count >= 2 else { continue }

            let systemScore = AccelerateML.mean(zScores)
            systemScores.append((name: system.name, score: systemScore))
        }

        // Need at least 2 systems to be meaningful
        guard systemScores.count >= 2 else { return nil }

        // Overall allostatic load = mean of system scores, mapped to 0-100
        // z-score range [-3, 3] maps to [0, 100] with 50 = baseline
        let rawScores = systemScores.map(\.score)
        let overallZ = AccelerateML.mean(rawScores)
        let allostaticIndex = Swift.max(0, Swift.min(100, (overallZ + 3.0) / 6.0 * 100.0))

        // Find the most stressed system
        let sortedSystems = systemScores.sorted { $0.score > $1.score }
        guard let worstSystem = sortedSystems.first else { return nil }

        let severity: IntelligenceCard.CardSeverity

        switch allostaticIndex {
        case 75...: severity = .critical
        case 62..<75: severity = .warning
        case 55..<62: severity = .notable
        default: severity = .info
        }

        let headline: String
        if allostaticIndex >= 62 {
            headline = Copy.Briefing.StressAndRecovery.highStressHeadline(worstSystem: worstSystem.name)
        } else if allostaticIndex <= 40 {
            headline = Copy.Briefing.StressAndRecovery.lowStressHeadline
        } else {
            headline = Copy.Briefing.StressAndRecovery.normalStressHeadline
        }

        let priority: Double
        if allostaticIndex >= 70 { priority = 80 }
        else if allostaticIndex >= 55 { priority = 55 }
        else { priority = 35 }

        return IntelligenceCard(
            type: .allostaticLoad,
            label: Copy.Briefing.Labels.stressAndRecovery,
            headline: headline,
            severity: severity,
            priority: priority
        )
    }

    // MARK: - 7. Autonomic Balance (Task Force, 1996)

    /// Sympatho-vagal balance indicator using ln(HRV+1) / (RHR/60).
    /// Deviations from personal baseline indicate autonomic dominance shifts.
    private func autonomicBalanceCard(
        baselines: [HealthMetric: UserBaseline],
        liveHRV: Double?,
        liveRestingHR: Double?
    ) -> IntelligenceCard? {
        guard let hrv = liveHRV, hrv > 0,
              let rhr = liveRestingHR, rhr > 0 else { return nil }

        guard let hrvBaseline = baselines[.heartRateVariability],
              hrvBaseline.standardDeviation > 0,
              let rhrBaseline = baselines[.restingHeartRate],
              rhrBaseline.standardDeviation > 0 else { return nil }

        // Current ratio: ln(HRV + 1) / (RHR / 60)
        let currentRatio = log(hrv + 1.0) / (rhr / 60.0)

        // Baseline ratio using baseline means
        let hrvMean = hrvBaseline.mean
        let rhrMean = rhrBaseline.mean
        let rhrNorm = rhrMean / 60.0
        let baselineRatio = log(hrvMean + 1.0) / rhrNorm

        // Estimate standard deviation of the ratio via delta method:
        // Var(f(X,Y)) ~ (df/dx)^2 * Var(X) + (df/dy)^2 * Var(Y)
        let dfdx = 1.0 / ((hrvMean + 1.0) * rhrNorm)
        let lnHrvTerm = log(hrvMean + 1.0)
        let dfdy = -lnHrvTerm * 60.0 / (rhrMean * rhrMean)
        let hrvVar = hrvBaseline.standardDeviation * hrvBaseline.standardDeviation
        let rhrVar = rhrBaseline.standardDeviation * rhrBaseline.standardDeviation
        let ratioVariance = dfdx * dfdx * hrvVar + dfdy * dfdy * rhrVar
        let ratioStd = ratioVariance.squareRoot()

        guard ratioStd > 0 else { return nil }

        let sigma = (currentRatio - baselineRatio) / ratioStd

        // Not noteworthy if within +/- 0.8 sigma
        guard abs(sigma) >= 0.8 else { return nil }

        let headline: String
        let severity: IntelligenceCard.CardSeverity

        if sigma > 1.0 {
            // Recovery mode
            headline = Copy.Briefing.NervousSystem.recoveryModeHeadline
            severity = abs(sigma) >= 2.0 ? .notable : .info
        } else if sigma < -1.0 {
            // Stress mode
            headline = Copy.Briefing.NervousSystem.stressModeHeadline
            severity = abs(sigma) >= 2.0 ? .warning : .notable
        } else {
            // Mild shift (0.8 - 1.0 sigma)
            let direction = sigma > 0 ? "toward recovery" : "toward stress"
            headline = Copy.Briefing.NervousSystem.mildShiftHeadline(direction: direction)
            severity = .info
        }

        let priority: Double
        if abs(sigma) >= 2.0 && sigma < 0 { priority = 75 }
        else if abs(sigma) >= 1.5 { priority = 60 }
        else { priority = 40 }

        return IntelligenceCard(
            type: .autonomicBalance,
            label: Copy.Briefing.Labels.nervousSystem,
            headline: headline,
            severity: severity,
            priority: priority
        )
    }

    // MARK: - 8. Recovery Debt

    /// Cumulative deficit tracking with exponential decay.
    /// Sleep debt: sum of max(0, baseline - actual) * 0.85^(days_ago) over last 14 days.
    /// HRV deficit: count of days HRV < baseline - 0.5*std, weighted by recency.
    /// Activity deficit: below-goal exercise days in the last 7.
    private func recoveryDebtCard(
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries],
        exerciseMinutes: Double,
        exerciseGoal: Double
    ) -> IntelligenceCard? {
        let decay = 0.85
        let sleepWindowDays = 14
        let hrvWindowDays = 14
        let activityWindowDays = 7

        // --- Sleep Debt ---
        guard let sleepBaseline = baselines[.sleepDuration],
              let sleepSeries = timeSeries[.sleepDuration] else { return nil }

        let recentSleep = sleepSeries.samples(lastDays: sleepWindowDays)
        guard recentSleep.count >= 5 else { return nil }

        // Sort by date descending so day 0 = most recent
        let sleepByRecency = recentSleep.sorted { $0.date > $1.date }

        // Compute sleep debt with exponential decay
        var sleepDebtWeights: [Double] = []
        var sleepDeficits: [Double] = []

        for (i, sample) in sleepByRecency.enumerated() {
            let deficit = Swift.max(0, sleepBaseline.mean - sample.value)
            let weight = pow(decay, Double(i))
            sleepDeficits.append(deficit)
            sleepDebtWeights.append(weight)
        }

        let sleepDebtHours: Double
        if !sleepDeficits.isEmpty {
            sleepDebtHours = AccelerateML.dotProduct(sleepDeficits, sleepDebtWeights)
        } else {
            sleepDebtHours = 0
        }

        // --- HRV Deficit ---
        var hrvDeficitScore = 0.0
        if let hrvBaseline = baselines[.heartRateVariability],
           let hrvSeries = timeSeries[.heartRateVariability] {
            let recentHRV = hrvSeries.samples(lastDays: hrvWindowDays).sorted { $0.date > $1.date }
            let threshold = hrvBaseline.mean - 0.5 * hrvBaseline.standardDeviation

            for (i, sample) in recentHRV.enumerated() {
                if sample.value < threshold {
                    hrvDeficitScore += pow(decay, Double(i))
                }
            }
        }

        // --- Activity Deficit ---
        var activityDeficitDays = 0
        if let exerciseSeries = timeSeries[.exerciseMinutes] {
            let recentExercise = exerciseSeries.samples(lastDays: activityWindowDays)
            for sample in recentExercise {
                if sample.value < exerciseGoal * 0.5 {
                    activityDeficitDays += 1
                }
            }
        }
        // Include today if below goal
        if exerciseMinutes < exerciseGoal * 0.5 {
            activityDeficitDays += 1
        }

        // Estimated recovery days = sleep debt / 1.5 (recover ~1.5h extra per night)
        let estimatedRecoveryDays = sleepDebtHours > 0.5 ? Int(ceil(sleepDebtHours / 1.5)) : 0

        // Check if this is noteworthy
        let isSignificant = sleepDebtHours >= 2.0 || hrvDeficitScore >= 3.0 || activityDeficitDays >= 4
        guard isSignificant else { return nil }

        let sleepDebtStr = String(format: "%.1fh", sleepDebtHours)

        let severity: IntelligenceCard.CardSeverity

        switch sleepDebtHours {
        case 5...: severity = .warning
        case 3..<5: severity = .notable
        default: severity = hrvDeficitScore >= 3.0 ? .notable : .info
        }

        let headline: String
        if estimatedRecoveryDays > 0 {
            headline = Copy.Briefing.SleepDebt.headlineWithRecovery(debtHours: sleepDebtStr, recoveryDays: estimatedRecoveryDays)
        } else {
            headline = Copy.Briefing.SleepDebt.headlineHRVSuppressed
        }

        let priority: Double
        if sleepDebtHours >= 5.0 { priority = 72 }
        else if sleepDebtHours >= 3.0 || hrvDeficitScore >= 4.0 { priority = 58 }
        else { priority = 42 }

        return IntelligenceCard(
            type: .recoveryDebt,
            label: Copy.Briefing.Labels.sleepDebt,
            headline: headline,
            severity: severity,
            priority: priority
        )
    }

    // MARK: - 9. System Coherence (Physiological Network Analysis)

    /// Builds an adjacency matrix of significant metric correlations and measures network density
    /// and mean coupling strength. Identifies the weakest link (pair with expected strong correlation
    /// that has decayed the most).
    private func systemCoherenceCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        let correlations = orchestrator.mlCorrelations
        guard correlations.count >= 5 else { return nil }

        // Filter significant pairs: |pearsonR| > 0.3 AND survivedFDR
        let significantPairs = correlations.filter { abs($0.pearsonR) > 0.3 && $0.survivedFDR }
        guard !significantPairs.isEmpty else { return nil }

        // Count total possible pairs from all unique metrics
        var uniqueMetrics: Set<HealthMetric> = []
        for corr in correlations {
            uniqueMetrics.insert(corr.metricA)
            uniqueMetrics.insert(corr.metricB)
        }
        let n = uniqueMetrics.count
        guard n >= 3 else { return nil }
        let totalPossibleEdges = n * (n - 1) / 2

        // Network density = significant edges / total possible edges
        let density = Double(significantPairs.count) / Double(totalPossibleEdges)

        // Mean |pearsonR| of significant pairs using Accelerate
        let absCorrelations = significantPairs.map { abs($0.pearsonR) }
        let coherence = AccelerateML.mean(absCorrelations)

        // Mean stability as a proxy for healthy coupling baseline
        let stabilityValues: [Double] = significantPairs.map { $0.stability }
        let meanStability = AccelerateML.mean(stabilityValues)

        let severity: IntelligenceCard.CardSeverity = (coherence < 0.35 || density < 0.15) ? .notable : .info

        let headline: String
        if meanStability > 0 && coherence < meanStability * 0.7 {
            headline = Copy.Briefing.BodySystems.decoupledHeadline
        } else if coherence > 0.55 && density > 0.3 {
            headline = Copy.Briefing.BodySystems.alignedHeadline
        } else {
            headline = Copy.Briefing.BodySystems.normalHeadline
        }

        let priority: Double
        if coherence < 0.35 { priority = 52 }
        else { priority = 30 }

        let cardLabel = (coherence > 0.55 && density > 0.3) ? Copy.Briefing.Labels.everythingLooksGood : Copy.Briefing.Labels.stressAndRecovery

        return IntelligenceCard(
            type: .systemCoherence,
            label: cardLabel,
            headline: headline,
            severity: severity,
            priority: priority
        )
    }

    // MARK: - 10. Rhythm Deviation (Mahalanobis-inspired)

    /// Computes how unusual today is compared to the same weekday's historical distribution.
    /// Combined deviation = sqrt(mean(z^2)) across all metrics with 14+ days of data.
    private func rhythmDeviationCard(
        timeSeries: [HealthMetric: MetricTimeSeries],
        liveHRV: Double?,
        liveRestingHR: Double?,
        sleepHours: Double
    ) -> IntelligenceCard? {
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)

        // Resolve today's known values
        func todayValue(for metric: HealthMetric) -> Double? {
            switch metric {
            case .heartRateVariability: return liveHRV
            case .restingHeartRate: return liveRestingHR
            case .sleepDuration: return sleepHours > 0 ? sleepHours : nil
            default:
                return timeSeries[metric]?.samples(lastDays: 1).last?.value
            }
        }

        // For each metric with 14+ days, compute same-weekday z-score
        var zScores: [Double] = []

        for (metric, series) in timeSeries {
            guard let todayVal = todayValue(for: metric) else { continue }
            guard series.daysOfData >= 14 else { continue }

            // Get same-weekday historical values
            let sameWeekdaySamples = series.samples.filter {
                calendar.component(.weekday, from: $0.date) == todayWeekday
            }
            guard sameWeekdaySamples.count >= 3 else { continue }

            let weekdayValues: [Double] = sameWeekdaySamples.map { $0.value }
            let stats = AccelerateML.welfordVariance(weekdayValues)
            let std = stats.variance.squareRoot()

            guard std > 1e-10 else { continue }

            zScores.append((todayVal - stats.mean) / std)
        }

        guard zScores.count >= 3 else { return nil }

        // RMS z-score across all metrics using Accelerate
        let zSquared = zScores.map { $0 * $0 }
        let meanZSq = AccelerateML.mean(zSquared)
        let rmsZ = meanZSq.squareRoot()

        // Not noteworthy if < 1.2
        guard rmsZ >= 1.2 else { return nil }

        let todayDayName = dayName(for: todayWeekday)

        let severity: IntelligenceCard.CardSeverity

        switch rmsZ {
        case 2.5...: severity = .warning
        case 1.5..<2.5: severity = .notable
        default: severity = .info
        }

        let headline = Copy.Briefing.UnusualDay.headline(dayName: todayDayName)

        let priority: Double
        if rmsZ >= 2.5 { priority = 68 }
        else if rmsZ >= 2.0 { priority = 55 }
        else { priority = 38 }

        return IntelligenceCard(
            type: .rhythmDeviation,
            label: Copy.Briefing.Labels.unusualDay,
            headline: headline,
            severity: severity,
            priority: priority
        )
    }

    // MARK: - Helpers

    /// Format a probability (0-1) as a rounded percentage string like "68%".
    private func formatPercent(_ value: Double) -> String {
        "\(Int(round(value * 100)))%"
    }

    /// Format an integer hour (0-23) into a 12-hour time string like "10:00 AM".
    private func formatHour(_ hour: Int) -> String {
        let h = ((hour - 1) % 12) + 1
        let ampm = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour == 12 ? 12 : h)
        return "\(displayHour):00 \(ampm)"
    }

    /// Format a decimal hour (e.g. 14.5) into "2:30 PM".
    private func formatHourDecimal(_ hour: Double) -> String {
        let totalMinutes = Int(round(hour * 60))
        let h24 = (totalMinutes / 60) % 24
        let m = totalMinutes % 60
        let ampm = h24 < 12 ? "AM" : "PM"
        let h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
        return String(format: "%d:%02d %@", h12, m, ampm)
    }

    // Short date appears inside a user-visible IntelligenceCard
    // narrative, so it must localize the month name + day order
    // ("Mar 3" en-US, "3 mars" fr-FR, "3 Mar" en-GB). `.dateTime.day().month()`
    // reads `Locale.current` automatically. Foundation caches the underlying
    // formatter, so the previous explicit POSIX cache is no longer required.
    private func shortDateString(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Day name from weekday number (1=Sun, 7=Sat).
    private func dayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return Copy.Insights.daySunday
        case 2: return Copy.Insights.dayMonday
        case 3: return Copy.Insights.dayTuesday
        case 4: return Copy.Insights.dayWednesday
        case 5: return Copy.Insights.dayThursday
        case 6: return Copy.Insights.dayFriday
        case 7: return Copy.Insights.daySaturday
        default: return "day"
        }
    }
}
