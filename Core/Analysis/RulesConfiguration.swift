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

    /// Population range usable as a verdict band. Nil when the table has no spread for the metric,
    /// for example falls, where the only healthy value is zero and "0 to 0" would read as nonsense.
    /// Callers show no verdict at all rather than inventing bounds.
    static func verdictPopulationRange(for metric: HealthMetric) -> NormalRange? {
        let range = normalRange(for: metric)
        guard range.high > range.low else { return nil }
        return range
    }

    /// Half width of the personal normal band, in standard deviations around the user's baseline mean.
    /// Same threshold AnomalyDetector uses to raise a warning, so the verdict can never call a value
    /// normal while the anomaly badge on the same screen calls it a warning.
    static let personalNormalBandDeviations: Double = 1.5

    /// Days of the user's own data required before the personal band replaces the population table.
    /// BaselineCalculator refuses to build a baseline below this count for the same reason.
    static let minimumDaysForPersonalBand: Int = 7

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
        return Copy.Analysis.RulesEngine.projection(days: days)
    }

    /// "This appears connected to your sleep duration dropping 18%."
    static func rootCauseSentence(context: InsightContext?) -> String {
        guard let ctx = context, let rootMetric = ctx.rootCauseMetric, let rootDev = ctx.rootCauseDeviation else { return "" }
        return Copy.Analysis.RulesEngine.rootCause(metric: rootMetric.displayName.lowercased(), percent: String(format: "%.0f", abs(rootDev)))
    }

    /// "This puts you in the bottom 12% of your history. This is 15% below your typical February."
    static func historicalPositionSentence(context: InsightContext?) -> String {
        guard let ctx = context else { return "" }
        var parts: [String] = []
        if let pct = ctx.allTimePercentile, pct <= 20 || pct >= 80 {
            let label = pct >= 80 ? "top \(Int(100 - pct))%" : "bottom \(Int(pct))%"
            parts.append(Copy.Analysis.RulesEngine.historicalPercentile(label: label))
        }
        if let seasonal = ctx.seasonalDeviation, abs(seasonal) >= 5 {
            let monthName = Date.cal.monthSymbols[Date.cal.component(.month, from: Date()) - 1]
            parts.append(Copy.Analysis.RulesEngine.historicalSeasonal(percent: String(format: "%.0f", abs(seasonal)), direction: seasonal > 0 ? "above" : "below", month: monthName))
        }
        if let yoy = ctx.yearOverYearChange, abs(yoy) > 2 {
            parts.append(Copy.Analysis.RulesEngine.historicalYoY(percent: String(format: "%.0f", abs(yoy)), direction: yoy > 0 ? "better" : "worse"))
        }
        guard !parts.isEmpty else { return "" }
        return Copy.Analysis.RulesEngine.historicalIntro(parts: parts.joined(separator: "; "))
    }

    /// "Your data shows that improving sleep by 1hr typically raises your HRV by ~12ms."
    static func correlationActionSentence(context: InsightContext?, metric: HealthMetric) -> String {
        guard let ctx = context, let top = ctx.correlatedFactors.first else { return "" }
        return Copy.Analysis.RulesEngine.correlationAction(factor: top.metric.displayName.lowercased(), metric: metric.displayName.lowercased(), percent: String(format: "%.0f", top.effectPercent))
    }

    // MARK: - Context-Aware Recommendation

    /// Full context-aware recommendation. uses context data when available, falls back to templates
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, deviationPercent: Double?, context: InsightContext?) -> String {
        let parts = RecommendationParts(
            devStr: deviationPercent.map { String(format: "%.0f", abs($0)) + "% " } ?? "",
            valStr: currentValue.map { metric.formatValue($0) + " " + metric.unit + " \u{2014} " } ?? "",
            projection: projectionSentence(context: context, trend: trend),
            rootCause: rootCauseSentence(context: context),
            historical: historicalPositionSentence(context: context),
            correlationAction: correlationActionSentence(context: context, metric: metric),
            topLever: context?.correlatedFactors.first.map { factor in
                Copy.Analysis.RulesEngine.topLever(factor: factor.metric.displayName.lowercased(), percent: String(format: "%.0f", factor.effectPercent), metric: metric.displayName.lowercased())
            }
        )

        switch metric {
        case .heartRate, .restingHeartRate, .heartRateVariability, .vo2Max,
             .bloodOxygen, .atrialFibrillationBurden, .peripheralPerfusionIndex:
            return cardioRecommendation(metric: metric, severity: severity, trend: trend, currentValue: currentValue, parts: parts)

        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return sleepRecommendation(metric: metric, severity: severity, trend: trend, parts: parts)

        case .steps, .activeCalories, .exerciseMinutes, .distanceCycling,
             .distanceSwimming, .swimmingStrokeCount, .appleMoveTime,
             .walkingSpeed, .walkingStepLength, .walkingAsymmetry,
             .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed,
             .sixMinuteWalkTestDistance:
            return activityRecommendation(metric: metric, severity: severity, trend: trend, parts: parts)

        case .weight, .bmi, .bodyFatPercentage, .leanBodyMass, .waistCircumference,
             .appleSleepingWristTemperature, .bloodPressureSystolic, .bloodPressureDiastolic,
             .respiratoryRate, .peakExpiratoryFlowRate, .forcedVitalCapacity,
             .bodyTemperature, .mindfulMinutes, .timeInDaylight, .electrodermalActivity:
            return bodyAndVitalsRecommendation(metric: metric, severity: severity, trend: trend, parts: parts)

        default:
            return defaultRecommendation(metric: metric, trend: trend, parts: parts)
        }
    }

    // MARK: - Recommendation helpers

    /// Bundles precomputed copy fragments shared across recommendation helpers
    private struct RecommendationParts {
        let devStr: String
        let valStr: String
        let projection: String
        let rootCause: String
        let historical: String
        let correlationAction: String
        let topLever: String?
    }

    private static func cardioRecommendation(metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, parts: RecommendationParts) -> String {
        let valStr = parts.valStr, devStr = parts.devStr
        let projection = parts.projection, rootCause = parts.rootCause
        let historical = parts.historical, correlationAction = parts.correlationAction
        let topLever = parts.topLever

        switch metric {
        case .heartRate, .restingHeartRate:
            if severity >= .warning {
                let base = Copy.Analysis.RulesEngine.rhrAboveBaseline(valStr: valStr, devStr: devStr)
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + Copy.Analysis.RulesEngine.rhrCheckChanges + projection + historical
            }
            return trend == .improving
                ? Copy.Analysis.RulesEngine.rhrTrendingDown(valStr: valStr) + historical
                : Copy.Analysis.RulesEngine.rhrConsistent(valStr: valStr) + correlationAction + historical

        case .heartRateVariability:
            if trend == .declining {
                let base = Copy.Analysis.RulesEngine.hrvDownBaseline(valStr: valStr, devStr: devStr)
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + Copy.Analysis.RulesEngine.hrvCheckChanges + projection + historical
            }
            return Copy.Analysis.RulesEngine.hrvConsistent(valStr: valStr) + correlationAction + historical

        case .vo2Max:
            if trend == .improving {
                return Copy.Analysis.RulesEngine.vo2Improving(valStr: valStr, devStr: devStr) + historical
            }
            return Copy.Analysis.RulesEngine.vo2Flat(valStr: valStr, devStr: devStr) + projection + historical

        case .bloodOxygen:
            // SpO2 <90% is a medical emergency. escalate with urgent language
            if severity == .critical, let value = currentValue, value < 90 {
                return Copy.Analysis.RulesEngine.bloodOxygenCritical(valStr: valStr)
            }
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.bloodOxygenDropped(valStr: valStr, devStr: devStr) + rootCause + projection
            }
            return Copy.Analysis.RulesEngine.bloodOxygenTypical(valStr: valStr) + historical

        case .atrialFibrillationBurden:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.afibElevated(valStr: valStr, devStr: devStr) + projection
            }
            return Copy.Analysis.RulesEngine.afibTypical(valStr: valStr) + historical

        case .peripheralPerfusionIndex:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.perfusionElevated(valStr: valStr, devStr: devStr) + rootCause
            }
            return Copy.Analysis.RulesEngine.perfusionTypical(valStr: valStr)

        default:
            preconditionFailure("cardioRecommendation called with non-cardio metric: \(metric)")
        }
    }

    private static func sleepRecommendation(metric: HealthMetric, severity: Severity, trend: TrendDirection, parts: RecommendationParts) -> String {
        let valStr = parts.valStr, devStr = parts.devStr
        let projection = parts.projection, rootCause = parts.rootCause
        let historical = parts.historical, correlationAction = parts.correlationAction
        let topLever = parts.topLever

        switch metric {
        case .sleepDuration:
            if severity >= .warning || trend == .declining {
                let base = Copy.Analysis.RulesEngine.sleepDurationBelow(valStr: valStr, devStr: devStr)
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + projection + historical
            }
            return Copy.Analysis.RulesEngine.sleepDurationConsistent(valStr: valStr) + correlationAction + historical

        case .sleepREM, .sleepDeep:
            let stageName = metric == .sleepDeep ? "Deep" : "REM"
            let direction = trend == .declining ? "below" : "above"
            let base = Copy.Analysis.RulesEngine.sleepStage(valStr: valStr, stage: stageName, devStr: devStr, direction: direction)
            if let lever = topLever {
                return base + rootCause + " " + lever + projection + historical
            }
            return base + rootCause + projection + historical

        case .sleepCore:
            return Copy.Analysis.RulesEngine.sleepCoreTypical(valStr: valStr) + historical

        case .sleepAwake:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.sleepAwakeAbove(valStr: valStr, devStr: devStr) + rootCause + projection
            }
            return Copy.Analysis.RulesEngine.sleepAwakeTypical(valStr: valStr) + historical

        default:
            preconditionFailure("sleepRecommendation called with non-sleep metric: \(metric)")
        }
    }

    private static func activityRecommendation(metric: HealthMetric, severity: Severity, trend: TrendDirection, parts: RecommendationParts) -> String {
        let valStr = parts.valStr, devStr = parts.devStr
        let projection = parts.projection, rootCause = parts.rootCause
        let historical = parts.historical, correlationAction = parts.correlationAction
        let topLever = parts.topLever
        _ = severity

        switch metric {
        case .steps:
            if trend == .declining {
                let base = Copy.Analysis.RulesEngine.stepsDown(valStr: valStr, devStr: devStr)
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + projection + historical
            }
            return trend == .improving
                ? Copy.Analysis.RulesEngine.stepsUp(valStr: valStr, devStr: devStr) + historical
                : Copy.Analysis.RulesEngine.stepsConsistent(valStr: valStr) + correlationAction + historical

        case .activeCalories:
            if trend == .declining {
                return Copy.Analysis.RulesEngine.activeCaloriesDown(valStr: valStr, devStr: devStr) + rootCause + projection + historical
            }
            return Copy.Analysis.RulesEngine.activeCaloriesAbove(valStr: valStr) + correlationAction + historical

        case .exerciseMinutes:
            if trend == .declining {
                return Copy.Analysis.RulesEngine.exerciseDown(valStr: valStr, devStr: devStr) + rootCause + projection + historical
            }
            return Copy.Analysis.RulesEngine.exerciseConsistent(valStr: valStr) + historical

        case .distanceCycling:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.cyclingDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.cyclingConsistent(valStr: valStr) + historical

        case .distanceSwimming, .swimmingStrokeCount:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.swimmingDown(valStr: valStr, devStr: devStr) + projection
                : Copy.Analysis.RulesEngine.swimmingConsistent(valStr: valStr) + historical

        case .appleMoveTime:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.moveTimeDown(valStr: valStr, devStr: devStr) + projection
                : Copy.Analysis.RulesEngine.moveTimeConsistent(valStr: valStr) + historical

        case .walkingSpeed:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.walkingSpeedDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.walkingSpeedConsistent(valStr: valStr) + historical

        case .walkingStepLength:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.stepLengthDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.stepLengthConsistent(valStr: valStr) + historical

        case .walkingAsymmetry:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.walkingAsymmetryElevated(valStr: valStr, devStr: devStr) + projection
            }
            return Copy.Analysis.RulesEngine.walkingSymmetryConsistent(valStr: valStr) + historical

        case .walkingDoubleSupportPercentage:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.doubleSupportElevated(valStr: valStr, devStr: devStr) + projection
            }
            return Copy.Analysis.RulesEngine.doubleSupportTypical(valStr: valStr)

        case .stairAscentSpeed, .stairDescentSpeed:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.stairSpeedDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.stairSpeedConsistent(valStr: valStr) + historical

        case .sixMinuteWalkTestDistance:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.sixMinuteWalkDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.sixMinuteWalkConsistent(valStr: valStr) + historical

        default:
            preconditionFailure("activityRecommendation called with non-activity metric: \(metric)")
        }
    }

    private static func bodyAndVitalsRecommendation(metric: HealthMetric, severity: Severity, trend: TrendDirection, parts: RecommendationParts) -> String {
        let valStr = parts.valStr, devStr = parts.devStr
        let projection = parts.projection, rootCause = parts.rootCause
        let historical = parts.historical, correlationAction = parts.correlationAction

        switch metric {
        case .weight, .bmi, .bodyFatPercentage:
            if trend == .declining && !metric.higherIsBetter {
                return Copy.Analysis.RulesEngine.bodyCompTrendingUp(valStr: valStr, devStr: devStr) + rootCause + projection + historical
            }
            return Copy.Analysis.RulesEngine.bodyCompConsistent(valStr: valStr) + historical

        case .leanBodyMass:
            return trend == .declining
                ? Copy.Analysis.RulesEngine.leanMassDown(valStr: valStr, devStr: devStr) + projection + historical
                : Copy.Analysis.RulesEngine.leanMassConsistent(valStr: valStr) + historical

        case .waistCircumference:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.waistAbove(valStr: valStr, devStr: devStr) + projection + historical
            }
            return Copy.Analysis.RulesEngine.waistConsistent(valStr: valStr) + historical

        case .appleSleepingWristTemperature:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.wristTempDeviated(valStr: valStr, devStr: devStr) + rootCause
            }
            return Copy.Analysis.RulesEngine.wristTempTypical(valStr: valStr)

        case .bloodPressureSystolic, .bloodPressureDiastolic:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.bpAbove(valStr: valStr, devStr: devStr) + rootCause + projection
            }
            return Copy.Analysis.RulesEngine.bpConsistent(valStr: valStr) + historical

        case .respiratoryRate:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.respiratoryElevated(valStr: valStr, devStr: devStr) + rootCause + projection
            }
            return Copy.Analysis.RulesEngine.respiratoryTypical(valStr: valStr) + historical

        case .peakExpiratoryFlowRate:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.peakFlowDown(valStr: valStr, devStr: devStr) + projection
            }
            return Copy.Analysis.RulesEngine.peakFlowTypical(valStr: valStr)

        case .forcedVitalCapacity:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.forcedVitalDown(valStr: valStr, devStr: devStr) + projection
            }
            return Copy.Analysis.RulesEngine.lungCapacityTypical(valStr: valStr)

        case .bodyTemperature:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.bodyTempOutside(valStr: valStr, devStr: devStr) + rootCause
            }
            return Copy.Analysis.RulesEngine.bodyTempTypical(valStr: valStr)

        case .mindfulMinutes:
            if trend == .declining {
                return Copy.Analysis.RulesEngine.mindfulnessDown(valStr: valStr, devStr: devStr) + correlationAction + projection
            }
            return Copy.Analysis.RulesEngine.mindfulnessConsistent(valStr: valStr) + correlationAction + historical

        case .timeInDaylight:
            if trend == .declining {
                return Copy.Analysis.RulesEngine.daylightDown(valStr: valStr, devStr: devStr) + correlationAction + projection
            }
            return Copy.Analysis.RulesEngine.daylightConsistent(valStr: valStr) + historical

        case .electrodermalActivity:
            if severity >= .warning {
                return Copy.Analysis.RulesEngine.edaElevated(valStr: valStr, devStr: devStr) + rootCause
            }
            return Copy.Analysis.RulesEngine.edaTypical(valStr: valStr)

        default:
            preconditionFailure("bodyAndVitalsRecommendation called with non-body metric: \(metric)")
        }
    }

    private static func defaultRecommendation(metric: HealthMetric, trend: TrendDirection, parts: RecommendationParts) -> String {
        let valStr = parts.valStr, devStr = parts.devStr
        let projection = parts.projection, rootCause = parts.rootCause
        let historical = parts.historical

        if trend == .declining {
            return Copy.Analysis.RulesEngine.defaultDeclining(valStr: valStr, metricName: metric.displayName, devStr: devStr) + rootCause + projection + historical
        }
        return Copy.Analysis.RulesEngine.defaultTypical(valStr: valStr, metricName: metric.displayName) + historical
    }
}
