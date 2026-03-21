import Foundation

/// Domain knowledge: thresholds, normal ranges, and recommendation templates
struct RulesConfiguration {

    /// Normal population ranges for each metric
    struct NormalRange {
        let low: Double
        let high: Double

        func contains(_ value: Double) -> Bool {
            value >= low && value <= high
        }
    }

    /// Critical absolute thresholds. values beyond these are medical emergencies
    /// regardless of personal baselines or z-scores.
    struct CriticalThreshold {
        /// Value below which the reading is critical (nil = no low critical threshold)
        let criticalLow: Double?
        /// Value above which the reading is critical (nil = no high critical threshold)
        let criticalHigh: Double?

        func isCritical(_ value: Double) -> Bool {
            if let low = criticalLow, value < low { return true }
            if let high = criticalHigh, value > high { return true }
            return false
        }
    }

    /// Returns the critical absolute threshold for a metric, if one exists.
    /// These represent medically dangerous values that override z-score-based severity.
    static func criticalThreshold(for metric: HealthMetric) -> CriticalThreshold? {
        switch metric {
        case .bloodOxygen:
            // SpO2 <90% is a medical emergency (severe hypoxemia)
            return CriticalThreshold(criticalLow: 90, criticalHigh: nil)
        case .heartRate:
            // HR <40 or >150 at rest is dangerous
            return CriticalThreshold(criticalLow: 40, criticalHigh: 150)
        case .bodyTemperature:
            // <35°C (hypothermia) or >40°C (hyperpyrexia)
            return CriticalThreshold(criticalLow: 35.0, criticalHigh: 40.0)
        default:
            return nil
        }
    }

    static func normalRange(for metric: HealthMetric) -> NormalRange {
        switch metric {
        case .heartRate: return NormalRange(low: 60, high: 100)
        case .restingHeartRate: return NormalRange(low: 40, high: 80)
        case .heartRateVariability: return NormalRange(low: 20, high: 100)
        case .vo2Max: return NormalRange(low: 25, high: 60)
        case .walkingHeartRateAverage: return NormalRange(low: 80, high: 120)
        case .heartRateRecovery: return NormalRange(low: 12, high: 50)
        case .bloodOxygen: return NormalRange(low: 95, high: 100)
        case .atrialFibrillationBurden: return NormalRange(low: 0, high: 1)
        case .peripheralPerfusionIndex: return NormalRange(low: 0.5, high: 5)
        case .sleepDuration: return NormalRange(low: 7, high: 9)
        case .sleepREM: return NormalRange(low: 0.8, high: 2.5)
        case .sleepDeep: return NormalRange(low: 0.8, high: 2.0)
        case .sleepCore: return NormalRange(low: 2.0, high: 5.0)
        case .sleepAwake: return NormalRange(low: 0, high: 0.5)
        case .steps: return NormalRange(low: 5000, high: 15000)
        case .activeCalories: return NormalRange(low: 200, high: 800)
        case .basalCalories: return NormalRange(low: 1200, high: 2200)
        case .exerciseMinutes: return NormalRange(low: 20, high: 90)
        case .standHours: return NormalRange(low: 6, high: 14)
        case .distanceWalkingRunning: return NormalRange(low: 3, high: 12)
        case .flightsClimbed: return NormalRange(low: 2, high: 20)
        case .distanceCycling: return NormalRange(low: 0, high: 50)
        case .distanceSwimming: return NormalRange(low: 0, high: 5)
        case .swimmingStrokeCount: return NormalRange(low: 0, high: 3000)
        case .appleMoveTime: return NormalRange(low: 10, high: 120)
        case .walkingSpeed: return NormalRange(low: 3.5, high: 6.5)
        case .walkingStepLength: return NormalRange(low: 55, high: 85)
        case .walkingAsymmetry: return NormalRange(low: 0, high: 10)
        case .walkingDoubleSupportPercentage: return NormalRange(low: 20, high: 40)
        case .stairAscentSpeed: return NormalRange(low: 0.5, high: 2.0)
        case .stairDescentSpeed: return NormalRange(low: 0.5, high: 2.0)
        case .sixMinuteWalkTestDistance: return NormalRange(low: 400, high: 700)
        case .weight: return NormalRange(low: 45, high: 130)
        case .bmi: return NormalRange(low: 18.5, high: 25)
        case .bodyFatPercentage: return NormalRange(low: 8, high: 30)
        case .bloodPressureSystolic: return NormalRange(low: 90, high: 130)
        case .bloodPressureDiastolic: return NormalRange(low: 60, high: 80)
        case .respiratoryRate: return NormalRange(low: 12, high: 20)
        case .bodyTemperature: return NormalRange(low: 36.1, high: 37.2)
        case .appleSleepingWristTemperature: return NormalRange(low: -1.0, high: 1.0)
        case .leanBodyMass: return NormalRange(low: 35, high: 90)
        case .waistCircumference: return NormalRange(low: 60, high: 102)
        case .peakExpiratoryFlowRate: return NormalRange(low: 300, high: 700)
        case .forcedVitalCapacity: return NormalRange(low: 2.5, high: 6.0)
        case .mindfulMinutes: return NormalRange(low: 5, high: 60)
        case .timeInDaylight: return NormalRange(low: 15, high: 180)
        case .electrodermalActivity: return NormalRange(low: 0.01, high: 20)
        case .waterIntake: return NormalRange(low: 1500, high: 4000)  // mL per day
        case .caffeineIntake: return NormalRange(low: 0, high: 400)  // mg
        case .proteinIntake: return NormalRange(low: 50, high: 200)  // g
        case .fiberIntake: return NormalRange(low: 25, high: 50)  // g
        case .sugarIntake: return NormalRange(low: 0, high: 36)  // g (AHA)
        case .sodiumIntake: return NormalRange(low: 500, high: 2300)  // mg
        case .totalCaloriesIntake: return NormalRange(low: 1500, high: 3000)  // kcal
        case .carbohydrateIntake: return NormalRange(low: 200, high: 400)  // g
        case .fatIntake: return NormalRange(low: 44, high: 78)  // g
        case .bloodGlucose: return NormalRange(low: 70, high: 140)
        case .workoutCount: return NormalRange(low: 0, high: 3)
        case .workoutDuration: return NormalRange(low: 0, high: 120)
        // Hearing
        case .headphoneAudioExposure: return NormalRange(low: 40, high: 80)  // dB(A)
        case .environmentalAudioExposure: return NormalRange(low: 40, high: 80)  // dB(A)
        // Running dynamics
        case .runningPower: return NormalRange(low: 150, high: 400)  // Watts
        case .runningGroundContactTime: return NormalRange(low: 200, high: 300)  // ms
        case .runningVerticalOscillation: return NormalRange(low: 6, high: 13)  // cm
        case .runningStrideLength: return NormalRange(low: 1.0, high: 2.0)  // meters
        // Respiratory (additional)
        case .forcedExpiratoryVolume1: return NormalRange(low: 2.0, high: 5.0)  // liters
        // Sleep (additional)
        case .sleepBreathingDisturbances: return NormalRange(low: 0, high: 5)  // events/hr
        // Mobility (additional)
        case .walkingSteadiness: return NormalRange(low: 50, high: 100)  // %
        case .numberOfTimesFallen: return NormalRange(low: 0, high: 0)  // ideally zero
        // Metabolic (additional)
        case .insulinDelivery: return NormalRange(low: 0, high: 60)  // IU/day
        // Water sports
        case .underwaterDepth: return NormalRange(low: 0, high: 40)  // meters
        case .waterTemperature: return NormalRange(low: 15, high: 30)  // °C
        }
    }

    /// Warning threshold: deviation from baseline (proportion)
    static var warningDeviationThreshold: Double { RemoteConfigManager.shared.analysisWarningDeviation }

    /// Critical threshold: deviation from baseline (proportion)
    static var criticalDeviationThreshold: Double { RemoteConfigManager.shared.analysisCriticalDeviation }

    /// Trend significance: minimum absolute slope to be considered non-stable
    static var trendSlopeThreshold: Double { RemoteConfigManager.shared.analysisTrendSlopeThreshold }

    /// Score deductions
    static let anomalyWarningDeduction: Int = -20
    static let anomalyCriticalDeduction: Int = -40
    static let decliningTrendDeduction: Int = -10
    static let strongDecliningTrendDeduction: Int = -20
    static let outsideNormalRangeDeduction: Int = -15
    static let improvingTrendBonus: Int = 5

    /// Recommendation templates. base version (no context)
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection) -> String {
        recommendation(for: metric, severity: severity, trend: trend, currentValue: nil, deviationPercent: nil, context: nil)
    }

    /// Enhanced recommendation with actual values
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, deviationPercent: Double?) -> String {
        recommendation(for: metric, severity: severity, trend: trend, currentValue: currentValue, deviationPercent: deviationPercent, context: nil)
    }

    // MARK: - Context-Aware Helpers

    /// "Based on current trends, this may approach warning level within ~8 days."
    static func projectionSentence(context: InsightContext?, trend: TrendDirection) -> String {
        guard trend == .declining, let days = context?.projectedDaysToThreshold, days > 0, days <= 21 else { return "" }
        return " Based on current trends, this may approach warning level within ~\(days) days."
    }

    /// "This appears connected to your sleep duration dropping 18%."
    static func rootCauseSentence(context: InsightContext?) -> String {
        guard let ctx = context, let rootMetric = ctx.rootCauseMetric, let rootDev = ctx.rootCauseDeviation else { return "" }
        return " This appears connected to your \(rootMetric.displayName.lowercased()) shifting \(String(format: "%.0f", abs(rootDev)))%."
    }

    /// "This puts you in the bottom 12% of your history. This is 15% below your typical February."
    static func historicalPositionSentence(context: InsightContext?) -> String {
        guard let ctx = context else { return "" }
        var parts: [String] = []
        if let pct = ctx.allTimePercentile, pct <= 20 || pct >= 80 {
            let label = pct >= 80 ? "top \(Int(100 - pct))%" : "bottom \(Int(pct))%"
            parts.append("in the \(label) of your history")
        }
        if let seasonal = ctx.seasonalDeviation, abs(seasonal) >= 5 {
            let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
            parts.append("\(String(format: "%.0f", abs(seasonal)))% \(seasonal > 0 ? "above" : "below") your typical \(monthName)")
        }
        if let yoy = ctx.yearOverYearChange, abs(yoy) > 2 {
            parts.append("\(String(format: "%.0f", abs(yoy)))% \(yoy > 0 ? "better" : "worse") than this time last year")
        }
        guard !parts.isEmpty else { return "" }
        return " Historically: " + parts.joined(separator: "; ") + "."
    }

    /// "Your data shows that improving sleep by 1hr typically raises your HRV by ~12ms."
    static func correlationActionSentence(context: InsightContext?, metric: HealthMetric) -> String {
        guard let ctx = context, let top = ctx.correlatedFactors.first else { return "" }
        return " Your data shows that improving \(top.metric.displayName.lowercased()) raises your \(metric.displayName.lowercased()) by ~\(String(format: "%.0f", top.effectPercent))%."
    }

    // MARK: - Context-Aware Recommendation

    /// Full context-aware recommendation. uses context data when available, falls back to templates
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, deviationPercent: Double?, context: InsightContext?) -> String {
        let devStr = deviationPercent.map { String(format: "%.0f", abs($0)) + "% " } ?? ""
        let valStr = currentValue.map { metric.formatValue($0) + " " + metric.unit + " \u{2014} " } ?? ""

        // Build context suffix that applies to any metric
        let projection = projectionSentence(context: context, trend: trend)
        let rootCause = rootCauseSentence(context: context)
        let historical = historicalPositionSentence(context: context)
        let correlationAction = correlationActionSentence(context: context, metric: metric)

        // Use the strongest correlated factor for the recommendation action when available
        let topLever: String? = context?.correlatedFactors.first.map { factor in
            "Your #1 lever: improve \(factor.metric.displayName.lowercased()) (\(String(format: "%.0f", factor.effectPercent))% impact on \(metric.displayName.lowercased()))."
        }

        switch metric {
        case .heartRate, .restingHeartRate:
            if severity >= .warning {
                let base = "\(valStr)Your resting HR is \(devStr)above your baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Check for recent changes in sleep, stress, or caffeine intake." + projection + historical
            }
            return trend == .improving
                ? "\(valStr)Resting HR is trending down from your recent average." + historical
                : "\(valStr)Resting HR is consistent with your 30-day average." + correlationAction + historical

        case .heartRateVariability:
            if trend == .declining {
                let base = "\(valStr)HRV is down \(devStr)from your baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Check recent changes in sleep or recovery patterns." + projection + historical
            }
            return "\(valStr)HRV is consistent with your 30-day average." + correlationAction + historical

        case .vo2Max:
            if trend == .improving {
                return "\(valStr)VO2 Max is up \(devStr)from your baseline \u{2014} your cardiovascular fitness is improving." + historical
            }
            return "\(valStr)VO2 Max has been flat or declining \(devStr)compared to your baseline." + projection + historical

        case .bloodOxygen:
            // SpO2 <90% is a medical emergency. escalate with urgent language
            if severity == .critical, let value = currentValue, value < 90 {
                return "\(valStr)Blood oxygen is critically low, below the 90% emergency threshold. This level of hypoxemia requires immediate attention. If you experience shortness of breath, confusion, bluish lips or fingertips, or chest pain, seek emergency medical care. Retake the reading to confirm, and if it remains below 90%, contact a healthcare provider urgently."
            }
            if severity >= .warning {
                return "\(valStr)Blood oxygen has dropped \(devStr)below your typical level." + rootCause + projection
            }
            return "\(valStr)Blood oxygen is tracking at your typical level." + historical

        case .atrialFibrillationBurden:
            if severity >= .warning {
                return "\(valStr)AFib burden is elevated \(devStr)compared to your baseline." + projection
            }
            return "\(valStr)AFib burden is tracking at your typical level." + historical

        case .peripheralPerfusionIndex:
            if severity >= .warning {
                return "\(valStr)Perfusion index is \(devStr)outside your typical range." + rootCause
            }
            return "\(valStr)Peripheral perfusion is tracking at your typical level."

        case .sleepDuration:
            if severity >= .warning || trend == .declining {
                let base = "\(valStr)Sleep duration is \(devStr)below your baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + projection + historical
            }
            return "\(valStr)Sleep duration is consistent with your baseline." + correlationAction + historical

        case .sleepREM, .sleepDeep:
            let stageName = metric == .sleepDeep ? "deep" : "REM"
            let base = "\(valStr)\(stageName.capitalized) sleep is \(devStr)\(trend == .declining ? "below" : "above") your baseline."
            if let lever = topLever {
                return base + rootCause + " " + lever + projection + historical
            }
            return base + rootCause + projection + historical

        case .sleepCore:
            return "\(valStr)Core sleep is tracking at your typical level." + historical

        case .sleepAwake:
            if severity >= .warning {
                return "\(valStr)Nighttime wake time is \(devStr)above your typical level." + rootCause + projection
            }
            return "\(valStr)Nighttime awake periods are tracking at your typical level." + historical

        case .steps:
            if trend == .declining {
                let base = "\(valStr)Step count is down \(devStr)from your baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + projection + historical
            }
            return trend == .improving
                ? "\(valStr)Step count is up \(devStr)from your baseline." + historical
                : "\(valStr)Step count is consistent with your baseline." + correlationAction + historical

        case .activeCalories:
            if trend == .declining {
                return "\(valStr)Active calorie burn is down \(devStr)from your baseline." + rootCause + projection + historical
            }
            return "\(valStr)Active calorie burn is tracking above your baseline." + correlationAction + historical

        case .exerciseMinutes:
            if trend == .declining {
                return "\(valStr)Exercise time has dropped \(devStr)from your recent average." + rootCause + projection + historical
            }
            return "\(valStr)Exercise time is consistent with your recent average." + historical

        case .distanceCycling:
            return trend == .declining
                ? "\(valStr)Cycling distance is down \(devStr)from your baseline." + projection + historical
                : "\(valStr)Cycling distance is consistent with your baseline." + historical

        case .distanceSwimming, .swimmingStrokeCount:
            return trend == .declining
                ? "\(valStr)Swimming activity has declined \(devStr)from your baseline." + projection
                : "\(valStr)Swimming activity is consistent with your baseline." + historical

        case .appleMoveTime:
            return trend == .declining
                ? "\(valStr)Move time is down \(devStr)from your baseline." + projection
                : "\(valStr)Move time is consistent with your baseline." + historical

        case .weight, .bmi, .bodyFatPercentage:
            if trend == .declining && !metric.higherIsBetter {
                return "\(valStr)Trending up \(devStr)from your baseline." + rootCause + projection + historical
            }
            return "\(valStr)Body composition is consistent with your recent trend." + historical

        case .leanBodyMass:
            return trend == .declining
                ? "\(valStr)Lean body mass is down \(devStr)from your baseline." + projection + historical
                : "\(valStr)Lean body mass is consistent with your baseline." + historical

        case .waistCircumference:
            if severity >= .warning {
                return "\(valStr)Waist circumference is \(devStr)above your baseline." + projection + historical
            }
            return "\(valStr)Waist circumference is consistent with your baseline." + historical

        case .appleSleepingWristTemperature:
            if severity >= .warning {
                return "\(valStr)Wrist temperature has deviated \(devStr)from your typical range." + rootCause
            }
            return "\(valStr)Sleeping wrist temperature is tracking at your typical level."

        case .bloodPressureSystolic, .bloodPressureDiastolic:
            if severity >= .warning {
                return "\(valStr)Blood pressure is \(devStr)above your baseline." + rootCause + projection
            }
            return "\(valStr)Blood pressure is consistent with your baseline." + historical

        case .respiratoryRate:
            if severity >= .warning {
                return "\(valStr)Respiratory rate is elevated \(devStr)above your baseline." + rootCause + projection
            }
            return "\(valStr)Respiratory rate is tracking at your typical level." + historical

        case .peakExpiratoryFlowRate:
            if severity >= .warning {
                return "\(valStr)Peak flow rate has dropped \(devStr)below your baseline." + projection
            }
            return "\(valStr)Peak expiratory flow rate is tracking at your typical level."

        case .forcedVitalCapacity:
            if severity >= .warning {
                return "\(valStr)Forced vital capacity is down \(devStr)from your baseline." + projection
            }
            return "\(valStr)Lung capacity is tracking at your typical level."

        case .bodyTemperature:
            if severity >= .warning {
                return "\(valStr)Body temperature is \(devStr)outside your typical range." + rootCause
            }
            return "\(valStr)Body temperature is tracking at your typical level."

        case .mindfulMinutes:
            if trend == .declining {
                return "\(valStr)Mindfulness time has dropped \(devStr)from your baseline." + correlationAction + projection
            }
            return "\(valStr)Mindfulness time is consistent with your baseline." + correlationAction + historical

        case .timeInDaylight:
            if trend == .declining {
                return "\(valStr)Daylight exposure is down \(devStr)from your baseline." + correlationAction + projection
            }
            return "\(valStr)Daylight exposure is consistent with your baseline." + historical

        case .electrodermalActivity:
            if severity >= .warning {
                return "\(valStr)Electrodermal activity is elevated \(devStr)above your baseline." + rootCause
            }
            return "\(valStr)Electrodermal activity is tracking at your typical level."

        case .walkingSpeed:
            return trend == .declining
                ? "\(valStr)Walking speed is down \(devStr)from your baseline." + projection + historical
                : "\(valStr)Walking speed is consistent with your baseline." + historical

        case .walkingStepLength:
            return trend == .declining
                ? "\(valStr)Step length has shortened \(devStr)from your baseline." + projection + historical
                : "\(valStr)Step length is consistent with your baseline." + historical

        case .walkingAsymmetry:
            if severity >= .warning {
                return "\(valStr)Walking asymmetry is elevated \(devStr)above your typical level." + projection
            }
            return "\(valStr)Walking symmetry is consistent with your baseline." + historical

        case .walkingDoubleSupportPercentage:
            if severity >= .warning {
                return "\(valStr)Double support time is elevated \(devStr)above your typical level." + projection
            }
            return "\(valStr)Double support percentage is tracking at your typical level."

        case .stairAscentSpeed, .stairDescentSpeed:
            return trend == .declining
                ? "\(valStr)Stair speed is down \(devStr)from your baseline." + projection + historical
                : "\(valStr)Stair speed is consistent with your baseline." + historical

        case .sixMinuteWalkTestDistance:
            return trend == .declining
                ? "\(valStr)Six-minute walk distance is down \(devStr)from your baseline." + projection + historical
                : "\(valStr)Six-minute walk distance is consistent with your baseline." + historical

        default:
            if trend == .declining {
                return "\(valStr)\(metric.displayName) is declining \(devStr)from your baseline." + rootCause + projection + historical
            }
            return "\(valStr)\(metric.displayName) is tracking at your typical level." + historical
        }
    }
}
