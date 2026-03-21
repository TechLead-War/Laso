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
    let icon: String
    let label: String
    let headline: String
    let detail: String
    let severity: CardSeverity
    let confidence: Double
    let priority: Double
    let accentColor: AccentColor

    enum CardSeverity: Int, Comparable {
        case info = 0, notable = 1, warning = 2, critical = 3
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum AccentColor {
        case red, orange, yellow, green, blue, purple
    }
}

// MARK: - Today Intelligence Engine

/// Synthesizes outputs from 10+ ML components into a daily intelligence briefing.
/// Each card generator returns nil if data is insufficient or the finding is not noteworthy.
/// Cards are ranked by priority; only the top 4 are shown.
final class TodayIntelligenceEngine {

    static let maxCardsToShow = 4

    private let calendar = Calendar.current

    // MARK: - Public API

    /// Generate the daily intelligence briefing from all available ML outputs.
    func generateBriefing(
        orchestrator: MLOrchestrator,
        baselines: [HealthMetric: UserBaseline],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        liveHRV: Double?,
        liveRestingHR: Double?,
        sleepHours: Double,
        deepSleepMinutes: Double,
        exerciseMinutes: Double,
        exerciseGoal: Double,
        readinessScore: Int?
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
            baselines: baselines,
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
                let pctStr = formatPercent(topSignal.score)
                let severity: IntelligenceCard.CardSeverity
                let color: IntelligenceCard.AccentColor
                let priorityBase: Double

                switch topSignal.riskLevel {
                case .critical:
                    severity = .critical; color = .red; priorityBase = 95
                case .high:
                    severity = .warning; color = .orange; priorityBase = 85
                case .moderate:
                    severity = .notable; color = .yellow; priorityBase = 70
                default:
                    severity = .info; color = .blue; priorityBase = 50
                }

                return IntelligenceCard(
                    type: .predictiveRisk,
                    icon: "exclamationmark.triangle.fill",
                    label: "PREDICTIVE RISK",
                    headline: "\(pctStr) \(topSignal.signalName.lowercased()) risk detected",
                    detail: topSignal.explanation,
                    severity: severity,
                    confidence: topSignal.confidence,
                    priority: priorityBase + topSignal.score * 5,
                    accentColor: color
                )
            }
        }

        // Fall back to tomorrow risk prediction
        guard let prediction = orchestrator.tomorrowRiskPrediction else { return nil }
        guard prediction.probability >= 0.35 else { return nil }

        let pctStr = formatPercent(prediction.probability)
        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        switch prediction.probability {
        case 0.7...: severity = .critical; color = .red
        case 0.5..<0.7: severity = .warning; color = .orange
        default: severity = .notable; color = .yellow
        }

        let topFactorDesc: String
        if let topFactor = prediction.topFactors.first {
            topFactorDesc = "Driven primarily by \(topFactor.metric.displayName.lowercased())"
        } else {
            topFactorDesc = "Based on multi-metric analysis"
        }

        return IntelligenceCard(
            type: .predictiveRisk,
            icon: "exclamationmark.triangle.fill",
            label: "PREDICTIVE RISK",
            headline: "\(pctStr) probability of a rough day tomorrow",
            detail: topFactorDesc,
            severity: severity,
            confidence: prediction.confidence,
            priority: 80 + prediction.probability * 20,
            accentColor: color
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
        let directionWord = isIncrease ? "up" : "down"
        let delta = abs(topCP.afterMean - topCP.beforeMean)
        let metricName = topCP.metric.displayName
        let deltaStr = topCP.metric.formatWithUnit(delta)
        let dateStr = shortDateString(topCP.date)

        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        // Is this a good or bad shift?
        let isDecrease = !isIncrease
        let isPositive = (isIncrease && topCP.metric.higherIsBetter)
            || (isDecrease && !topCP.metric.higherIsBetter)

        if isPositive {
            severity = topCP.magnitude >= 1.5 ? .notable : .info
            color = .green
        } else {
            severity = topCP.magnitude >= 2.0 ? .warning : .notable
            color = topCP.magnitude >= 2.0 ? .orange : .yellow
        }

        let beforeStr = topCP.metric.formatWithUnit(topCP.beforeMean)
        let afterStr = topCP.metric.formatWithUnit(topCP.afterMean)
        var detail = "Before: \(beforeStr) \u{2192} After: \(afterStr)"
        if !topCP.coOccurringChanges.isEmpty {
            let coChanges = Array(topCP.coOccurringChanges.prefix(2))
            let coNames = coChanges.map { $0.metric.displayName }
            detail += ". Co-shifted with \(coNames.joined(separator: " and "))"
        }

        let priority: Double = isPositive ? 55 + topCP.magnitude * 5 : 70 + topCP.magnitude * 5

        return IntelligenceCard(
            type: .regimeShift,
            icon: "chart.line.uptrend.xyaxis",
            label: "REGIME SHIFT",
            headline: "Your \(metricName) baseline shifted \(directionWord) \(deltaStr) since \(dateStr)",
            detail: detail,
            severity: severity,
            confidence: topCP.confidence,
            priority: priority,
            accentColor: color
        )
    }

    // MARK: - 3. Cascade Forecast Card

    /// Multi-metric domino predictions from active temporal sequences and triggered precursors.
    private func cascadeForecastCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        // Highest priority: currently-triggered precursor patterns
        let triggeredPrecursors = orchestrator.precursorPatterns.filter { $0.isCurrentlyTriggered }
        if let top = triggeredPrecursors.sorted(by: { $0.historicalAccuracy > $1.historicalAccuracy }).first {
            let pctStr = formatPercent(top.historicalAccuracy)
            let signalDesc = top.warningSignals.prefix(2).map { signal in
                "\(signal.metric.displayName) \(signal.direction)"
            }.joined(separator: " + ")

            return IntelligenceCard(
                type: .cascadeForecast,
                icon: "arrow.triangle.branch",
                label: "CASCADE ALERT",
                headline: "\(signalDesc) \u{2192} \(top.predictedEvent) (\(pctStr) historical accuracy)",
                detail: top.description,
                severity: .warning,
                confidence: top.historicalAccuracy,
                priority: 90 + top.historicalAccuracy * 10,
                accentColor: .red
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

        let pctStr = formatPercent(topSeq.confidence)

        return IntelligenceCard(
            type: .cascadeForecast,
            icon: "arrow.triangle.branch",
            label: "CASCADE FORECAST",
            headline: "Pattern in progress \u{2192} expect \(outcomeStr) (\(pctStr) confidence)",
            detail: topSeq.description,
            severity: .notable,
            confidence: topSeq.confidence,
            priority: 75 + topSeq.confidence * 15,
            accentColor: .orange
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
        let pVal = top.grangerPValue

        let pValStr: String
        if pVal < 0.001 { pValStr = "p < 0.001" }
        else if pVal < 0.01 { pValStr = "p < 0.01" }
        else { pValStr = String(format: "p = %.3f", pVal) }

        let lagStr = lagDays == 1 ? "1-day lag" : "\(lagDays)-day lag"

        let detail: String
        if let partial = top.partialCorrelation {
            let partialStr = String(format: "%.2f", abs(partial))
            detail = "Partial r = \(partialStr) after controlling for confounders. Stability: \(formatPercent(top.stability))"
        } else {
            detail = "Based on \(top.sampleCount) paired observations. Stability: \(formatPercent(top.stability))"
        }

        return IntelligenceCard(
            type: .hiddenDriver,
            icon: "link.circle.fill",
            label: "HIDDEN DRIVER",
            headline: "\(causeMetric) \(direction) your \(effectMetric.lowercased()) with a \(lagStr) (\(pValStr))",
            detail: detail,
            severity: .notable,
            confidence: 1.0 - pVal,
            priority: 60 + top.grangerEffectSize * 20,
            accentColor: .purple
        )
    }

    // MARK: - 5. Body Clock Status Card

    /// Phase shifts and optimal timing windows from circadian analysis.
    private func bodyClockStatusCard(orchestrator: MLOrchestrator) -> IntelligenceCard? {
        guard let profile = orchestrator.circadianProfile else { return nil }
        guard profile.confidence >= 0.3 else { return nil }

        let recommendations = orchestrator.timingRecommendations
        let chronotype = profile.chronotype.rawValue

        // Find workout timing recommendation
        let workoutRec = recommendations.first { $0.activity == .workout }
        let sleepRec = recommendations.first { $0.activity == .sleep }

        var headline: String
        var detail: String

        if let workout = workoutRec {
            let startStr = formatHour(workout.optimalWindowStart)
            let endStr = formatHour(workout.optimalWindowEnd)
            headline = "Your body clock peaks for exercise at \(startStr)\u{2013}\(endStr)"
            detail = "Chronotype: \(chronotype). Activity peak at \(formatHourDecimal(profile.activityAcrophaseHour))"
        } else {
            headline = "Chronotype: \(chronotype) \u{2014} activity peaks at \(formatHourDecimal(profile.activityAcrophaseHour))"
            detail = "HR nadir at \(formatHourDecimal(profile.hrNadirHour))"
        }

        if let sleep = sleepRec {
            let sleepStart = formatHour(sleep.optimalWindowStart)
            detail += ". Optimal bedtime: \(sleepStart)"
        }

        if let hrvPeak = profile.hrvAcrophaseHour {
            detail += ". HRV peaks at \(formatHourDecimal(hrvPeak))"
        }

        return IntelligenceCard(
            type: .bodyClockStatus,
            icon: "clock.arrow.circlepath",
            label: "BODY CLOCK",
            headline: headline,
            detail: detail,
            severity: .info,
            confidence: profile.confidence,
            priority: 45 + profile.confidence * 10,
            accentColor: .blue
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

        // Compute 30-day trailing percentile using available time series
        let percentileStr = trailing30DayPercentile(
            currentScore: allostaticIndex,
            baselines: baselines,
            timeSeries: timeSeries
        )

        // Find the most stressed system
        let sortedSystems = systemScores.sorted { $0.score > $1.score }
        let worstSystem = sortedSystems.first!

        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        switch allostaticIndex {
        case 75...: severity = .critical; color = .red
        case 62..<75: severity = .warning; color = .orange
        case 55..<62: severity = .notable; color = .yellow
        default: severity = .info; color = .green
        }

        let indexStr = String(format: "%.0f", allostaticIndex)
        let headline: String
        if allostaticIndex >= 62 {
            headline = "Stress burden: \(indexStr)/100 \u{2014} \(worstSystem.name.lowercased()) system under most strain"
        } else if allostaticIndex <= 40 {
            headline = "Stress burden: \(indexStr)/100 \u{2014} your body is well-recovered"
        } else {
            headline = "Stress burden: \(indexStr)/100 \u{2014} within your normal range"
        }

        let detail: String
        if let pctStr = percentileStr {
            let systemSummary = sortedSystems.prefix(2).map { s in
                let label = s.score > 0.5 ? "elevated" : (s.score < -0.5 ? "low" : "normal")
                return "\(s.name): \(label)"
            }.joined(separator: ", ")
            detail = "\(pctStr). \(systemSummary)"
        } else {
            let systemSummary = sortedSystems.map { s in
                let label = s.score > 0.5 ? "elevated" : (s.score < -0.5 ? "low" : "normal")
                return "\(s.name): \(label)"
            }.joined(separator: ", ")
            detail = systemSummary
        }

        let priority: Double
        if allostaticIndex >= 70 { priority = 80 }
        else if allostaticIndex >= 55 { priority = 55 }
        else { priority = 35 }

        return IntelligenceCard(
            type: .allostaticLoad,
            icon: "gauge.with.dots.needle.67percent",
            label: "STRESS LOAD",
            headline: headline,
            detail: detail,
            severity: severity,
            confidence: Double(systemScores.count) / 4.0,
            priority: priority,
            accentColor: color
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

        let sigmaStr = String(format: "%.1f\u{03C3}", abs(sigma))
        let hrvStr = HealthMetric.heartRateVariability.formatWithUnit(hrv)
        let rhrStr = HealthMetric.restingHeartRate.formatWithUnit(rhr)

        let headline: String
        let detail: String
        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        if sigma > 1.0 {
            // Parasympathetic dominant = recovery mode
            headline = "Parasympathetic dominance (\(sigmaStr) above baseline) \u{2014} your body is in recovery mode"
            detail = "HRV \(hrvStr), RHR \(rhrStr). Your autonomic balance favors rest and repair."
            severity = abs(sigma) >= 2.0 ? .notable : .info
            color = .green
        } else if sigma < -1.0 {
            // Sympathetic dominant = stress/fight-or-flight
            headline = "Sympathetic dominance (\(sigmaStr) below baseline) \u{2014} your nervous system hasn't recovered"
            detail = "HRV \(hrvStr), RHR \(rhrStr). Elevated fight-or-flight tone. Consider a lighter day."
            severity = abs(sigma) >= 2.0 ? .warning : .notable
            color = abs(sigma) >= 2.0 ? .red : .orange
        } else {
            // Mild shift (0.8 - 1.0 sigma)
            let direction = sigma > 0 ? "toward recovery" : "toward stress activation"
            headline = "Autonomic balance shifting \(direction) (\(sigmaStr) from baseline)"
            detail = "HRV \(hrvStr), RHR \(rhrStr). Mild autonomic shift."
            severity = .info
            color = sigma > 0 ? .green : .yellow
        }

        let priority: Double
        if abs(sigma) >= 2.0 && sigma < 0 { priority = 75 }
        else if abs(sigma) >= 1.5 { priority = 60 }
        else { priority = 40 }

        return IntelligenceCard(
            type: .autonomicBalance,
            icon: "waveform.path.ecg",
            label: "AUTONOMIC BALANCE",
            headline: headline,
            detail: detail,
            severity: severity,
            confidence: Swift.min(1.0, Double(hrvBaseline.sampleCount) / 30.0),
            priority: priority,
            accentColor: color
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

        // Trend: compare this week's sleep deficit to last week's
        let thisWeekSleep = sleepByRecency.prefix(7)
        let lastWeekSleep = sleepByRecency.dropFirst(7).prefix(7)

        var trendDescription = ""
        if thisWeekSleep.count >= 5 && lastWeekSleep.count >= 5 {
            let thisWeekValues: [Double] = thisWeekSleep.map { $0.value }
            let lastWeekValues: [Double] = lastWeekSleep.map { $0.value }
            let thisWeekAvg = AccelerateML.mean(thisWeekValues)
            let lastWeekAvg = AccelerateML.mean(lastWeekValues)
            if thisWeekAvg > lastWeekAvg + 0.2 {
                trendDescription = " Improving from last week."
            } else if thisWeekAvg < lastWeekAvg - 0.2 {
                trendDescription = " Worsening from last week."
            }
        }

        let sleepDebtStr = String(format: "%.1fh", sleepDebtHours)

        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        switch sleepDebtHours {
        case 5...: severity = .warning; color = .red
        case 3..<5: severity = .notable; color = .orange
        default: severity = hrvDeficitScore >= 3.0 ? .notable : .info; color = .yellow
        }

        var headline: String
        if estimatedRecoveryDays > 0 {
            headline = "\(sleepDebtStr) sleep debt accumulated \u{2014} est. \(estimatedRecoveryDays) day\(estimatedRecoveryDays == 1 ? "" : "s") to recover"
        } else {
            headline = "Recovery debt building: HRV suppressed \(String(format: "%.0f", hrvDeficitScore)) of last \(hrvWindowDays) days"
        }

        var detailParts: [String] = []
        if sleepDebtHours >= 1.0 {
            detailParts.append("Sleep deficit: \(sleepDebtStr) (decay-weighted over \(sleepWindowDays) days)")
        }
        if hrvDeficitScore >= 2.0 {
            detailParts.append("HRV below baseline \(String(format: "%.0f", hrvDeficitScore)) of \(hrvWindowDays) recent days")
        }
        if activityDeficitDays >= 3 {
            detailParts.append("Exercise below goal \(activityDeficitDays) of \(activityWindowDays) days")
        }
        if !trendDescription.isEmpty {
            detailParts.append(trendDescription.trimmingCharacters(in: .whitespaces))
        }

        let detail = detailParts.joined(separator: ". ")

        let priority: Double
        if sleepDebtHours >= 5.0 { priority = 72 }
        else if sleepDebtHours >= 3.0 || hrvDeficitScore >= 4.0 { priority = 58 }
        else { priority = 42 }

        return IntelligenceCard(
            type: .recoveryDebt,
            icon: "battery.25percent",
            label: "RECOVERY DEBT",
            headline: headline,
            detail: detail,
            severity: severity,
            confidence: Swift.min(1.0, Double(recentSleep.count) / Double(sleepWindowDays)),
            priority: priority,
            accentColor: color
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

        // Find weakest link: the pair with highest stability (expected to be strong) but lowest current |r|
        // Score = stability - |pearsonR| (high score = big gap between expected and actual)
        let stablePairs = significantPairs.filter { $0.stability > 0.5 }
        let weakestLink = stablePairs.max { a, b in
            let gapA = a.stability - abs(a.pearsonR)
            let gapB = b.stability - abs(b.pearsonR)
            return gapA < gapB
        }

        // Determine if coherence is unusually low
        // Use all correlations (not just significant) to see overall coupling
        let allAbsR = correlations.map { abs($0.pearsonR) }
        _ = AccelerateML.mean(allAbsR)

        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor
        let densityPct = String(format: "%.0f%%", density * 100)
        let coherenceStr = String(format: "%.2f", coherence)

        if coherence < 0.35 || density < 0.15 {
            severity = .notable
            color = .orange
        } else if coherence > 0.55 && density > 0.3 {
            severity = .info
            color = .green
        } else {
            severity = .info
            color = .blue
        }

        var headline: String
        if meanStability > 0 && coherence < meanStability * 0.7 {
            let dropPct = String(format: "%.0f%%", (1.0 - coherence / meanStability) * 100)
            headline = "Body systems \(dropPct) less coupled than your baseline"
        } else {
            headline = "System coherence: \(coherenceStr) across \(significantPairs.count) linked metric pairs (\(densityPct) network density)"
        }

        var detail = "\(significantPairs.count) significant connections among \(n) tracked metrics."
        if let weak = weakestLink {
            let gap = String(format: "%.2f", weak.stability - abs(weak.pearsonR))
            detail += " Weakest link: \(weak.metricA.displayName)\u{2013}\(weak.metricB.displayName) (gap: \(gap))"
        }

        let priority: Double
        if coherence < 0.35 { priority = 52 }
        else { priority = 30 }

        return IntelligenceCard(
            type: .systemCoherence,
            icon: "circle.hexagonpath.fill",
            label: "SYSTEM COHERENCE",
            headline: headline,
            detail: detail,
            severity: severity,
            confidence: Swift.min(1.0, Double(correlations.count) / 15.0),
            priority: priority,
            accentColor: color
        )
    }

    // MARK: - 10. Rhythm Deviation (Mahalanobis-inspired)

    /// Computes how unusual today is compared to the same weekday's historical distribution.
    /// Combined deviation = sqrt(mean(z^2)) across all metrics with 14+ days of data.
    /// Highlights the 1-2 most deviating metrics.
    private func rhythmDeviationCard(
        baselines: [HealthMetric: UserBaseline],
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
        struct MetricDeviation {
            let metric: HealthMetric
            let zScore: Double
            let todayVal: Double
            let weekdayMean: Double
        }

        var deviations: [MetricDeviation] = []

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

            let z = (todayVal - stats.mean) / std
            deviations.append(MetricDeviation(
                metric: metric,
                zScore: z,
                todayVal: todayVal,
                weekdayMean: stats.mean
            ))
        }

        guard deviations.count >= 3 else { return nil }

        // RMS z-score across all metrics using Accelerate
        let zSquared = deviations.map { $0.zScore * $0.zScore }
        let meanZSq = AccelerateML.mean(zSquared)
        let rmsZ = meanZSq.squareRoot()

        // Not noteworthy if < 1.2
        guard rmsZ >= 1.2 else { return nil }

        // Find top 2 most deviating metrics
        let sortedByAbsZ = deviations.sorted { abs($0.zScore) > abs($1.zScore) }
        let topDeviators = Array(sortedByAbsZ.prefix(2))

        let todayDayName = dayName(for: todayWeekday)
        let rmsStr = String(format: "%.1f\u{03C3}", rmsZ)

        let severity: IntelligenceCard.CardSeverity
        let color: IntelligenceCard.AccentColor

        switch rmsZ {
        case 2.5...: severity = .warning; color = .red
        case 2.0..<2.5: severity = .notable; color = .orange
        case 1.5..<2.0: severity = .notable; color = .yellow
        default: severity = .info; color = .blue
        }

        let headline = "Today is \(rmsStr) from your typical \(todayDayName)"

        let deviatorDescriptions = topDeviators.map { dev in
            let direction = dev.zScore > 0 ? "above" : "below"
            let absZ = String(format: "%.1f\u{03C3}", abs(dev.zScore))
            return "\(dev.metric.displayName): \(dev.metric.formatWithUnit(dev.todayVal)) (\(absZ) \(direction) your \(todayDayName) avg of \(dev.metric.formatWithUnit(dev.weekdayMean)))"
        }
        let detail = "Biggest outliers: " + deviatorDescriptions.joined(separator: "; ")

        let priority: Double
        if rmsZ >= 2.5 { priority = 68 }
        else if rmsZ >= 2.0 { priority = 55 }
        else { priority = 38 }

        return IntelligenceCard(
            type: .rhythmDeviation,
            icon: "waveform.badge.exclamationmark",
            label: "RHYTHM CHECK",
            headline: headline,
            detail: detail,
            severity: severity,
            confidence: Swift.min(1.0, Double(deviations.count) / 8.0),
            priority: priority,
            accentColor: color
        )
    }

    // MARK: - Helpers

    /// Compute trailing 30-day allostatic percentile using time series data.
    /// Returns a human-readable percentile string, or nil if insufficient history.
    private func trailing30DayPercentile(
        currentScore: Double,
        baselines: [HealthMetric: UserBaseline],
        timeSeries: [HealthMetric: MetricTimeSeries]
    ) -> String? {
        // We need at least restingHeartRate and HRV time series to do a historical comparison
        guard let rhrSeries = timeSeries[.restingHeartRate],
              let hrvSeries = timeSeries[.heartRateVariability],
              let rhrBaseline = baselines[.restingHeartRate],
              let hrvBaseline = baselines[.heartRateVariability],
              rhrBaseline.standardDeviation > 0,
              hrvBaseline.standardDeviation > 0 else { return nil }

        let rhrSamples = rhrSeries.samples(lastDays: 30)
        let hrvSamples = hrvSeries.samples(lastDays: 30)
        guard rhrSamples.count >= 14, hrvSamples.count >= 14 else { return nil }

        // Compute daily composite z-score for each of the past 30 days using available core metrics
        var dailyScores: [Double] = []

        // Build date-indexed lookup for both metrics
        var rhrByDate: [Date: Double] = [:]
        for s in rhrSamples {
            rhrByDate[calendar.startOfDay(for: s.date)] = s.value
        }
        var hrvByDate: [Date: Double] = [:]
        for s in hrvSamples {
            hrvByDate[calendar.startOfDay(for: s.date)] = s.value
        }

        let today = calendar.startOfDay(for: Date())
        for daysAgo in 1...30 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: date)

            var zScores: [Double] = []

            if let rhr = rhrByDate[dayStart] {
                var z = (rhr - rhrBaseline.mean) / rhrBaseline.standardDeviation
                if HealthMetric.restingHeartRate.higherIsBetter { z = -z }
                zScores.append(Swift.max(-3, Swift.min(3, z)))
            }
            if let hrv = hrvByDate[dayStart] {
                var z = (hrv - hrvBaseline.mean) / hrvBaseline.standardDeviation
                if HealthMetric.heartRateVariability.higherIsBetter { z = -z }
                zScores.append(Swift.max(-3, Swift.min(3, z)))
            }

            guard zScores.count >= 2 else { continue }

            let dayZ = AccelerateML.mean(zScores)
            let dayScore = Swift.max(0, Swift.min(100, (dayZ + 3.0) / 6.0 * 100.0))
            dailyScores.append(dayScore)
        }

        guard dailyScores.count >= 10 else { return nil }

        // Percentile: what fraction of the 30 days had a lower score?
        let countBelow = dailyScores.filter { $0 < currentScore }.count
        let percentile = Int(round(Double(countBelow) / Double(dailyScores.count) * 100))

        if percentile >= 85 {
            return "Highest in \(dailyScores.count) days (top \(100 - percentile)%)"
        } else if percentile <= 15 {
            return "Lowest in \(dailyScores.count) days (bottom \(percentile)%)"
        } else {
            return "\(ordinal(percentile)) percentile over the last \(dailyScores.count) days"
        }
    }

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

    /// Short date string: "Mar 3" format.
    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Day name from weekday number (1=Sun, 7=Sat).
    private func dayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "day"
        }
    }

    /// Ordinal suffix for a number (1st, 2nd, 3rd, 4th...).
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let tens = n % 100
        if tens >= 11 && tens <= 13 {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}
